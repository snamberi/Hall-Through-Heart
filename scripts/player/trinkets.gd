extends Node
## The trinkets the player wears (TrinketDB): it counts what each is about
## as the player does it (monsters slain, ground walked, potions drunk...),
## raises a trinket a level when it has done enough, gives their strengths,
## and answers whether a power is had ("night_eyes", "waterwalker"...).
## A child of the Player, made in its _ready.

const DB := preload("res://scripts/items/trinket_db.gd")

signal changed

var _player: Player
var _last_position := Vector2.INF
## Moments the player last regained health by Second Wind, in seconds.
var _second_wind_at := -999.0


func setup(player: Player) -> void:
	_player = player
	Events.enemy_killed.connect(func(_info: Dictionary) -> void: add("kills", 1.0))
	Events.item_crafted.connect(func(_recipe: String) -> void: add("crafted", 1.0))
	Events.resource_gathered.connect(_on_gathered)
	Events.codex_event.connect(_on_codex)
	player.equipment.changed.connect(apply)
	player.health.damaged.connect(_on_damaged)
	apply()


## Each worn trinket: slot -> Item.
func worn() -> Dictionary:
	var out := {}
	if _player == null or _player.equipment == null:
		return out
	for slot: String in DB.SLOTS:
		var item: Item = _player.equipment.equipped.get(slot)
		if item and DB.is_trinket(item.id):
			out[slot] = item
	return out


## Whether a worn trinket at level 3 gives this power.
func has_power(power: String) -> bool:
	for item: Item in worn().values():
		if item.trinket_level >= DB.MAX_LEVEL and DB.TRINKETS[item.id]["power"] == power:
			return true
	return false


## A level-2 gift that is not a plain stat: whether it is had.
func has_gift(trinket_id: String) -> bool:
	for item: Item in worn().values():
		if item.id == trinket_id and item.trinket_level >= 2:
			return true
	return false


## Puts the worn trinkets' strengths on the player.
func apply() -> void:
	if _player == null:
		return
	var totals := {}
	for item: Item in worn().values():
		var mods: Dictionary = DB.mods(item.id, item.trinket_level)
		for stat: String in mods:
			if not totals.has(stat):
				totals[stat] = {"flat": 0.0, "percent": 0.0}
			for kind: String in mods[stat]:
				totals[stat][kind] += float(mods[stat][kind])
	_player.stats.set_modifiers("trinkets", totals)
	changed.emit()


## Some of an activity done: every worn trinket that is about it grows.
func add(activity: String, amount: float) -> void:
	for item: Item in worn().values():
		var data: Dictionary = DB.TRINKETS[item.id]
		if data["activity"] != activity or item.trinket_level >= DB.MAX_LEVEL:
			continue
		item.trinket_progress += amount
		var need := DB.goal(item.id, item.trinket_level)
		if need > 0 and item.trinket_progress >= need:
			raise(item)


## A trinket up a level (the Orb of Awakening raises it to the top).
func raise(item: Item, to_top: bool = false) -> void:
	if item.trinket_level >= DB.MAX_LEVEL:
		return
	item.trinket_level = DB.MAX_LEVEL if to_top else item.trinket_level + 1
	item.trinket_progress = 0.0
	var data: Dictionary = DB.TRINKETS[item.id]
	var what := "%s: %s" % [data["power_name"], data["power_text"]] if item.trinket_level >= DB.MAX_LEVEL else "%s, %s" % [DB.words(data["l2"]), data["gift"]]
	Events.announcement.emit("%s  ·  LEVEL %d" % [str(data["name"]).to_upper(), item.trinket_level], what)
	if _player:
		RingBurst.spawn(_player.get_parent(), _player.global_position + Vector2(0, -14), Color(0.95, 0.8, 0.45), 60.0)
	Audio.play("level_up", -8.0, 0.1)
	apply()
	SaveGame.request_save()


## Uses an Orb of Awakening on a trinket: straight to level 3.
func awaken(item: Item) -> String:
	if item == null or not DB.is_trinket(item.id):
		return "Only a trinket can be awakened."
	if item.trinket_level >= DB.MAX_LEVEL:
		return "It is already fully awakened."
	if not _player.inventory.take(DB.ORB, 1):
		return "You have no Orb of Awakening."
	raise(item, true)
	return ""


func _on_gathered(info: Dictionary) -> void:
	match str(info.get("kind", "")):
		"tree":
			add("felled", 1.0)
		"ore", "stone", "rock":
			add("mined", float(info.get("count", 1)))


func _on_codex(stat: String, amount: int) -> void:
	match stat:
		"spells_cast":
			add("spells", amount)
		"meals":
			add("meals", amount)
			if has_power("hearty"):
				_player.health.heal(_player.health.max_health * 0.2)
		"potions":
			add("potions", amount)
			if has_power("distiller"):
				_player.buffs.add("distiller", "Distiller", 8.0, {"health_regen": {"flat": _player.health.max_health * 0.02}})
		"dashes":
			add("dashes", amount)
		"parries":
			add("parries", amount)
			if has_power("riposte"):
				_player.health.heal(_player.health.max_health * 0.1)
		"abilities_used":
			add("abilities", amount)


func _on_damaged(_amount: float) -> void:
	if not has_power("second_wind") or _player.is_dead():
		return
	var now := Time.get_ticks_msec() / 1000.0
	if _player.health.current < _player.health.max_health * 0.25 and now - _second_wind_at > 60.0:
		_second_wind_at = now
		_player.health.heal(_player.health.max_health * 0.2)
		Events.announcement.emit("SECOND WIND", "")


func _physics_process(_delta: float) -> void:
	if _player == null or worn().is_empty():
		_last_position = Vector2.INF
		return
	# Ground walked and water swum, in tiles.
	var here := _player.global_position
	if _last_position != Vector2.INF and not _player.indoors and _player.mount_id == "":
		var moved := here.distance_to(_last_position)
		if moved < 40.0:
			add("swum" if _player.swimming else "walked", moved / TerrainTiles.TILE_SIZE)
	_last_position = here
