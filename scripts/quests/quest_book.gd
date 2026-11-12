class_name QuestBook
extends Node
## Tracks the Quest Book: which quests are done, which are open, and how far
## along each objective is. Progress is read from the game itself (the
## Codex's counts, the bag, levels and so on), so quests can never fall out
## of step with what the player has done. A quest that is open and has all
## its objectives met completes at once and pays its reward.

signal changed
signal completed(id: String)

const MAX_TRACKED := 3

var done: Dictionary = {}
var tracked: Array[String] = []

var _player: Player
var _check_left := 2.0


func _ready() -> void:
	SaveGame.register("quest_book", self)


func setup(player: Player) -> void:
	_player = player


func is_done(id: String) -> bool:
	return done.has(id)


func is_open(id: String) -> bool:
	if done.has(id):
		return false
	for need: String in QuestBookDB.find(id).get("requires", []):
		if not done.has(need):
			return false
	return true


func state(id: String) -> String:
	return "done" if done.has(id) else "open" if is_open(id) else "locked"


func count_done(chapter: String = "") -> int:
	var total := 0
	for quest in QuestBookDB.all():
		if done.has(quest["id"]) and (chapter == "" or quest["chapter"] == chapter):
			total += 1
	return total


func count_all(chapter: String = "") -> int:
	if chapter == "":
		return QuestBookDB.all().size()
	return QuestBookDB.all().filter(func(q: Dictionary) -> bool: return q["chapter"] == chapter).size()


func toggle_track(id: String) -> void:
	if id in tracked:
		tracked.erase(id)
	else:
		tracked.append(id)
		while tracked.size() > MAX_TRACKED:
			tracked.pop_front()
	changed.emit()
	SaveGame.request_save()


func _physics_process(delta: float) -> void:
	if _player == null:
		return
	_check_left -= delta
	if _check_left > 0.0:
		return
	_check_left = 1.0
	var finished: Array[Dictionary] = []
	# Quests can open each other in one pass, so repeat until nothing moves.
	for pass_index in 4:
		var any := false
		for quest in QuestBookDB.all():
			if is_open(quest["id"]) and objectives_met(quest):
				done[quest["id"]] = true
				finished.append(quest)
				any = true
		if not any:
			break
	if finished.is_empty():
		return
	for quest in finished:
		_reward(quest)
		tracked.erase(quest["id"])
		completed.emit(quest["id"])
	if finished.size() == 1:
		Events.announcement.emit("QUEST COMPLETE", "%s  -  %s" % [finished[0]["title"], describe_rewards(finished[0]["rewards"])])
	else:
		Events.announcement.emit("%d QUESTS COMPLETE" % finished.size(), "Open the Quest Book (J) to see them")
	Audio.play("level_up", -6.0, 0.0)
	Events.codex_event.emit("quests", finished.size())
	changed.emit()
	SaveGame.request_save()


func objectives_met(quest: Dictionary) -> bool:
	for objective: Dictionary in quest["objectives"]:
		if progress(objective) < goal(objective):
			return false
	return true


func goal(objective: Dictionary) -> int:
	match objective["type"]:
		"level":
			return objective["level"]
		"mastery", "profession", "upgrade", "gear_level":
			return objective["level"]
		"biome", "class", "home", "settler", "own", "own_any", "own_set", "equip_slot", "equip_rarity":
			return 1
	return int(objective.get("count", 1))


## How far along an objective is, capped at its goal.
func progress(objective: Dictionary) -> int:
	return mini(_raw(objective), goal(objective))


func _raw(objective: Dictionary) -> int:
	var parent := _player.get_parent()
	var codex: Codex = parent.get_node("Codex")
	match objective["type"]:
		"stat":
			return int(codex.stats.get(objective["stat"], 0))
		"kill":
			return codex.kills_of(objective["monster"])
		"kill_wild":
			var total := 0
			for id: String in EnemyDB.ENEMIES:
				if EnemyDB.ENEMIES[id].has("wild"):
					total += codex.kills_of(id)
			return total
		"boss":
			return int(codex.boss_kills.get(objective["boss"], 0))
		"gather":
			return int(codex.gathered.get(objective["resource"], 0))
		"caught":
			return int(codex.caught.get(objective["item"], 0))
		"craft":
			return int(codex.crafted.get(objective["item"], 0))
		"craft_any":
			var total := 0
			for item: String in objective["items"]:
				total += int(codex.crafted.get(item, 0))
			return total
		"have":
			return _player.inventory.count_of(objective["item"])
		"own":
			return 1 if _owns(objective["item"]) else 0
		"own_any":
			for item: String in objective["items"]:
				if _owns(item):
					return 1
			return 0
		"own_set":
			for item in _all_items():
				if item.set_id == objective["set"]:
					return 1
			return 0
		"level":
			return _player.leveling.level
		"mastery":
			return int(_player.mastery.levels.get(objective["weapon"], 0))
		"profession":
			return _player.professions.level(objective["profession"])
		"biome":
			return 1 if objective["name"] in codex.biomes else 0
		"class":
			return 1 if _player.class_id != "adventurer" else 0
		"class_nodes":
			var total := 0
			for id: String in _player.class_ranks:
				total += int(_player.class_ranks[id])
			return total
		"talents":
			return _player.talents.spent_points()
		"attribute":
			return int(_player.attributes.points.get(objective["attribute"], 0))
		"abilities_known":
			return _player.abilities.known().size()
		"equip_slot":
			return 1 if _player.equipment.get_item(objective["slot"]) != null else 0
		"equip_rarity":
			for item: Item in _player.equipment.counted():
				if item.rarity >= objective["rarity"]:
					return 1
			return 0
		"gear_level":
			var best := 0
			for item: Item in _player.equipment.counted():
				best = maxi(best, item.level)
			return best
		"upgrade":
			var best := 0
			for item in _all_items():
				best = maxi(best, item.upgrade)
			return best
		"set_worn":
			var best := 0
			for count: int in _player.equipment.named_set_counts().values():
				best = maxi(best, count)
			return best
		"house_tier":
			var best := 0
			for record in (parent.get_node("Buildings") as Buildings).records:
				if record["kind"] == "house":
					best = maxi(best, int(record.get("tier", 1)))
			return best
		"place":
			return (parent.get_node("Buildings") as Buildings).records.filter(func(r: Dictionary) -> bool: return r["kind"] == objective["kind"]).size()
		"home":
			return 0 if (parent.get_node("Buildings") as Buildings).home.is_empty() else 1
		"settler":
			var settlers: Settlers = parent.get_node("Settlers")
			return 1 if settlers.settlers.any(func(s: Dictionary) -> bool: return s["role"] == objective["role"]) else 0
		"pet_level":
			var best := 0
			for pet: Dictionary in _player.pets.pets:
				best = maxi(best, int(pet["level"]))
			return best
		"gold":
			return _player.inventory.gold
		"wardens":
			return _player.quests.completed.filter(func(id: String) -> bool: return not QuestDB.STORY.has(id)).size()
		"achievements":
			return codex.done.size()
	return 0


func _all_items() -> Array[Item]:
	var items: Array[Item] = []
	for item in _player.inventory.items:
		if item:
			items.append(item)
	for item: Item in _player.equipment.counted():
		items.append(item)
	return items


func _owns(item_id: String) -> bool:
	for item in _all_items():
		if item.id == item_id:
			return true
	return false


## Words for an objective, like "Defeat 10 of the Frost Wolf".
func describe(objective: Dictionary) -> String:
	if objective.has("label"):
		return objective["label"]
	match objective["type"]:
		"kill":
			return "Defeat %s" % EnemyDB.ENEMIES[objective["monster"]]["name"]
		"kill_wild":
			return "Hunt wild animals"
		"boss":
			return "Defeat %s" % BossDB.BOSSES[objective["boss"]]["name"]
		"gather":
			return "Gather %s" % GatherDB.display_name(objective["resource"])
		"caught":
			return "Catch %s" % ItemDB.ITEMS[objective["item"]]["name"]
		"craft":
			var recipe := RecipeDB.find(objective["item"])
			var made: String = recipe.get("item", recipe.get("equipment", objective["item"]))
			return "Craft %s" % ItemDB.ITEMS.get(made, {}).get("name", made.capitalize())
		"have":
			return "Gather %s" % ItemDB.ITEMS[objective["item"]]["name"]
		"own":
			return "Own %s" % ItemDB.ITEMS[objective["item"]]["name"]
		"own_set":
			return "Find a %s piece" % ItemDB.ITEM_SETS[objective["set"]]["name"]
		"level":
			return "Reach level %d" % objective["level"]
		"mastery":
			return "%s mastery" % WeaponMastery.NAMES[objective["weapon"]]
		"profession":
			return "%s level" % Professions.NAMES[objective["profession"]]
		"biome":
			return "Discover %s" % objective["name"]
		"class":
			return "Choose a class"
		"class_nodes":
			return "Learn class ranks"
		"talents":
			return "Spend talent points"
		"attribute":
			return Attributes.NAMES[objective["attribute"]]
		"abilities_known":
			return "Know abilities"
		"equip_slot":
			return "Wear %s" % ItemDB.SLOT_NAMES[objective["slot"]].to_lower()
		"equip_rarity":
			return "Wear %s gear" % ItemDB.RARITIES[objective["rarity"]]["name"].to_lower()
		"gear_level":
			return "Item level of gear worn"
		"upgrade":
			return "Upgrade level"
		"set_worn":
			return "Pieces of one set worn"
		"house_tier":
			return "House tier"
		"place":
			return "Place %s" % Buildings.KINDS[objective["kind"]].get("item", objective["kind"]).replace("_", " ")
		"home":
			return "Sleep in a bed to make a home"
		"settler":
			return "%s at home" % Settlers.ROLES[objective["role"]]["title"]
		"pet_level":
			return "Pet level"
		"gold":
			return "Gold held"
		"wardens":
			return "Warden jobs done"
		"achievements":
			return "Achievements earned"
	return objective["type"]


static func describe_rewards(rewards: Dictionary) -> String:
	var parts: PackedStringArray = ["%d XP" % rewards["xp"], "%d gold" % rewards["gold"]]
	for entry: Array in rewards.get("items", []):
		parts.append("%s x%d" % [ItemDB.ITEMS[entry[0]]["name"], entry[1]])
	return ", ".join(parts)


func _reward(quest: Dictionary) -> void:
	var rewards: Dictionary = quest["rewards"]
	_player.leveling.add_xp(int(rewards["xp"]), "quest")
	_player.inventory.add_gold(int(rewards["gold"]))
	for entry: Array in rewards.get("items", []):
		_player.inventory.add(Item.create(entry[0], entry[1]))


func save_data() -> Dictionary:
	return {"done": done.keys(), "tracked": tracked.duplicate()}


func load_data(data: Dictionary) -> void:
	done.clear()
	for id: Variant in data.get("done", []):
		done[str(id)] = true
	tracked.clear()
	for id: Variant in data.get("tracked", []):
		tracked.append(str(id))
