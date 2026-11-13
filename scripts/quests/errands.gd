class_name Errands
extends Node
## Small jobs villagers ask for: bring them something, or clear out some
## monsters. Each villager has one a day. Bringing things means coming back
## to hand them over; monsters count as you kill them and pay at once.
## Helping someone makes them a friend, and friends pay a little better.

signal changed

const MAX_TAKEN := 3

## Errands taken: villager key -> errand (see make).
var taken: Dictionary = {}
## Day each villager's errand was last finished: key -> day.
var finished: Dictionary = {}
## How many times each villager has been helped: key -> count.
var helped: Dictionary = {}

var _player: Player


func _ready() -> void:
	SaveGame.register("errands", self)
	Events.enemy_killed.connect(_on_enemy_killed)


func setup(player: Player) -> void:
	_player = player


func _day() -> int:
	var night: DayNight = _player.get_parent().get_node_or_null("DayNight")
	return night.day if night else 1


## The errand a villager has today, made fresh from who they are, the day
## and the player's level; or {} if theirs is already done today.
func offer_for(npc: Npc) -> Dictionary:
	if taken.has(npc.villager_key):
		return taken[npc.villager_key]
	if int(finished.get(npc.villager_key, -1)) == _day():
		return {}
	return make(npc.villager_key, npc.job, npc.villager_name, _player.leveling.level, _day(), int(helped.get(npc.villager_key, 0)))


static func make(key: String, job: String, giver: String, level: int, day: int, friendship: int) -> Dictionary:
	var random := RandomNumberGenerator.new()
	random.seed = hash("%s:%d" % [key, day])
	var data: Dictionary = VillagerLife.JOBS[job]
	var errand := {"key": key, "giver": giver, "job": job, "have": 0}
	if data.get("cull", false) and random.randf() < 0.55:
		var options: Array[String] = []
		for id: String in EnemyDB.ENEMIES:
			var monster: Dictionary = EnemyDB.ENEMIES[id]
			if monster["min_level"] <= maxi(floori(level * 0.7), 1) and not monster.has("wild") and not monster.get("passive", false):
				options.append(id)
		if options.is_empty():
			options.append("husk")
		var monster_id: String = options[random.randi() % options.size()]
		var count := random.randi_range(4, 8)
		errand.merge({"kind": "cull", "target": monster_id, "need": count,
			"title": "%s's Trouble" % giver,
			"text": "%s wants %d %s gone from round the village." % [giver, count, EnemyDB.ENEMIES[monster_id]["name"]],
			"goal_text": "Defeat %s" % EnemyDB.ENEMIES[monster_id]["name"]})
	else:
		var fetch: Array = data["fetch"][random.randi() % (data["fetch"] as Array).size()]
		var count: int = int(fetch[1]) + random.randi_range(0, 2)
		errand.merge({"kind": "fetch", "target": fetch[0], "need": count,
			"title": "%s's Request" % giver,
			"text": "%s needs %d %s. Bring them back here." % [giver, count, ItemDB.ITEMS[fetch[0]]["name"]],
			"goal_text": "Bring %s to %s" % [ItemDB.ITEMS[fetch[0]]["name"], giver]})
	var pays: Array = data["pays"][random.randi() % (data["pays"] as Array).size()]
	var bonus := mini(friendship, 5)
	errand["gold"] = 8 * level + 20 + bonus * 10
	errand["xp"] = roundi(Leveling.xp_required(level) * 0.12)
	if pays[0] == "@gear":
		errand["gear"] = mini(int(pays[1]) + (1 if bonus >= 3 else 0), 4)
		errand["items"] = []
	else:
		errand["items"] = [[pays[0], int(pays[1]) + bonus / 2]]
	errand["reward_text"] = reward_text(errand)
	return errand


static func reward_text(errand: Dictionary) -> String:
	var parts: PackedStringArray = ["%d gold" % errand["gold"]]
	for entry: Array in errand["items"]:
		parts.append("%s x%d" % [ItemDB.ITEMS[entry[0]]["name"], entry[1]])
	if errand.has("gear"):
		parts.append("%s gear" % ItemDB.RARITIES[int(errand["gear"])]["name"])
	return ", ".join(parts)


func accept(npc: Npc) -> String:
	if taken.size() >= MAX_TAKEN:
		return "You have promised %d people already. Finish one first." % MAX_TAKEN
	var errand := offer_for(npc)
	if errand.is_empty():
		return "%s has nothing more for you today." % npc.villager_name
	taken[npc.villager_key] = errand
	changed.emit()
	SaveGame.request_save()
	return ""


## Whether the player has what a fetch errand asks.
func can_hand_over(npc: Npc) -> bool:
	var errand: Dictionary = taken.get(npc.villager_key, {})
	return not errand.is_empty() and errand["kind"] == "fetch" and _player.inventory.count_of(errand["target"]) >= int(errand["need"])


func hand_over(npc: Npc) -> String:
	if not can_hand_over(npc):
		return "You do not have what %s asked for." % npc.villager_name
	var errand: Dictionary = taken[npc.villager_key]
	_player.inventory.take(errand["target"], int(errand["need"]))
	_pay(errand)
	return ""


func abandon(key: String) -> void:
	taken.erase(key)
	changed.emit()
	SaveGame.request_save()


func _on_enemy_killed(info: Dictionary) -> void:
	if _player == null:
		return
	for key: String in taken.keys():
		var errand: Dictionary = taken[key]
		if errand["kind"] == "cull" and errand["target"] == info.get("id", ""):
			errand["have"] = int(errand["have"]) + 1
			if int(errand["have"]) >= int(errand["need"]):
				_pay(errand)
			else:
				changed.emit()


func _pay(errand: Dictionary) -> void:
	var key: String = errand["key"]
	taken.erase(key)
	finished[key] = _day()
	helped[key] = int(helped.get(key, 0)) + 1
	_player.inventory.add_gold(int(errand["gold"]))
	_player.leveling.add_xp(int(errand["xp"]), "quest")
	var given: Array = []
	for entry: Array in errand["items"]:
		var item := Item.create(entry[0], int(entry[1]))
		given.append(item)
		_player.inventory.add(item)
	if errand.has("gear"):
		var gear := LootGenerator.make_equipment(_player.leveling.level, int(errand["gear"]))
		given.append(gear)
		_player.inventory.add(gear)
	Events.rewards_given.emit("ERRAND DONE", "%s thanks you" % errand["giver"], int(errand["xp"]), int(errand["gold"]), given)
	Events.codex_event.emit("errands", 1)
	changed.emit()
	SaveGame.request_save()


## For the Quest Book: every errand taken, with how far along it is.
func active_list() -> Array:
	var result: Array = []
	for errand: Dictionary in taken.values():
		var have := int(errand["have"]) if errand["kind"] == "cull" else mini(_player.inventory.count_of(errand["target"]), int(errand["need"]))
		result.append({"title": errand["title"], "giver": "%s the %s" % [errand["giver"], VillagerLife.JOBS[errand["job"]]["title"]],
			"goal_text": errand["goal_text"], "have": have, "need": errand["need"], "reward_text": errand["reward_text"]})
	return result


func save_data() -> Dictionary:
	return {"taken": taken.duplicate(true), "finished": finished.duplicate(), "helped": helped.duplicate()}


func load_data(data: Dictionary) -> void:
	taken.clear()
	finished.clear()
	helped.clear()
	for key: String in data.get("taken", {}):
		var errand: Dictionary = data["taken"][key]
		if not errand.has("kind") or not VillagerLife.JOBS.has(errand.get("job", "")):
			continue
		errand["need"] = int(errand["need"])
		errand["have"] = int(errand.get("have", 0))
		errand["gold"] = int(errand["gold"])
		errand["xp"] = int(errand["xp"])
		if errand.has("gear"):
			errand["gear"] = int(errand["gear"])
		taken[key] = errand
	for key: String in data.get("finished", {}):
		finished[key] = int(data["finished"][key])
	for key: String in data.get("helped", {}):
		helped[key] = int(data["helped"][key])
