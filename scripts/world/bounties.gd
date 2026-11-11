class_name Bounties
extends Node
## Bounties posted in villages: a named, dangerous monster somewhere out in
## the wilds. Take one from a village's bounty board, find the mark on the
## map, and bring it down for gold, experience, and a fine piece of gear.

const MAX_ACTIVE := 3
const NAMES_FIRST: Array[String] = ["Grim", "Rot", "Ash", "Bone", "Blood", "Gloom", "Thorn", "Hollow", "Grave", "Mire", "Cinder", "Frost"]
const NAMES_LAST: Array[String] = ["fang", "maw", "hide", "claw", "eye", "heart", "tooth", "skull", "spine", "veil", "brand", "howl"]
## How close the player must come before the mark shows itself.
const WAKE_DISTANCE := 900.0

signal changed

## [{"id", "monster", "name", "level", "cell": [x, y], "gold", "xp"}]
var active: Array = []

var _world: World
var _player: Player
var _spawner: EnemySpawner
var _spawned: Dictionary = {}
var _check_left := 0.0


func _ready() -> void:
	SaveGame.register("bounties", self)


func setup(world: World, player: Player, spawner: EnemySpawner) -> void:
	_world = world
	_player = player
	_spawner = spawner


## The three bounties a village posts today.
func offers_at(village: Vector2i, day: int) -> Array:
	var random := RandomNumberGenerator.new()
	random.seed = hash(Vector3i(village.x, village.y, day * 31 + _world.generator.world_seed))
	var result: Array = []
	for index in 3:
		var angle := random.randf() * TAU
		var cell := village + Vector2i(Vector2.from_angle(angle) * random.randf_range(55.0, 130.0))
		cell = _world.generator.find_walkable_near(cell, 24)
		var level := _world.generator.enemy_level_at(cell) + 2
		var monster := EnemyDB.pick(_world.generator.tile_type_at(cell), level, true)
		if monster == "":
			monster = "husk"
		var title := "%s%s" % [NAMES_FIRST[random.randi_range(0, NAMES_FIRST.size() - 1)], NAMES_LAST[random.randi_range(0, NAMES_LAST.size() - 1)]]
		result.append({
			"id": "%d,%d:%d:%d" % [village.x, village.y, day, index],
			"monster": monster,
			"name": "%s the %s" % [title, EnemyDB.ENEMIES[monster]["name"]],
			"level": level,
			"cell": [cell.x, cell.y],
			"gold": roundi(40.0 * pow(level, 1.05)),
			"xp": roundi(60.0 * pow(level, 1.3)),
		})
	return result


func is_active(id: String) -> bool:
	return active.any(func(b: Dictionary) -> bool: return b["id"] == id)


func accept(bounty: Dictionary) -> String:
	if active.size() >= MAX_ACTIVE:
		return "You can hunt %d marks at once." % MAX_ACTIVE
	if is_active(bounty["id"]):
		return "You already hunt this one."
	active.append(bounty.duplicate(true))
	changed.emit()
	SaveGame.request_save()
	return ""


func abandon(id: String) -> void:
	active = active.filter(func(b: Dictionary) -> bool: return b["id"] != id)
	if _spawned.has(id) and is_instance_valid(_spawned[id]):
		_spawned[id].queue_free()
	_spawned.erase(id)
	changed.emit()
	SaveGame.request_save()


func cell_of(bounty: Dictionary) -> Vector2i:
	return Vector2i(int(bounty["cell"][0]), int(bounty["cell"][1]))


## Which way and how far a mark is, for the board and the tracker.
func direction_text(bounty: Dictionary) -> String:
	var offset := Vector2(cell_of(bounty)) - Vector2(_world.world_to_cell(_player.global_position))
	var names: Array[String] = ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"]
	var index := posmod(roundi(offset.angle() / (PI / 4.0)), 8)
	return "%d tiles %s" % [roundi(offset.length()), names[index]]


func _physics_process(delta: float) -> void:
	if _player == null or _player.indoors:
		return
	_check_left -= delta
	if _check_left > 0.0:
		return
	_check_left = 1.0
	for bounty: Dictionary in active:
		var id: String = bounty["id"]
		var at := _world.cell_to_world(cell_of(bounty))
		var distance := at.distance_to(_player.global_position)
		if _spawned.has(id) and is_instance_valid(_spawned[id]):
			# Too far behind: it goes back to its den, to be found again later.
			if distance > WAKE_DISTANCE * 2.0:
				_spawned[id].queue_free()
				_spawned.erase(id)
			continue
		if distance < WAKE_DISTANCE:
			_wake(bounty, at)


func _wake(bounty: Dictionary, at: Vector2) -> void:
	var enemy: Enemy = _spawner.enemy_scene.instantiate()
	enemy.custom_name = bounty["name"]
	enemy.position = at
	enemy.target = _player
	enemy.configure(int(bounty["level"]), Enemy.Rank.CHAMPION, bounty["monster"])
	enemy.lair_home = at
	enemy.wants_minion.connect(func(from: Enemy) -> void:
		_spawner.spawn_at(from.global_position + Vector2.from_angle(randf() * TAU) * 50.0, from.level, Enemy.Rank.NORMAL, from.enemy_id)
	)
	_spawner.add_child(enemy)
	enemy.add_to_group("bosses")
	_spawned[bounty["id"]] = enemy
	enemy.died.connect(func(_e: Enemy) -> void: _collect(bounty))
	Events.announcement.emit("BOUNTY SIGHTED", bounty["name"])


func _collect(bounty: Dictionary) -> void:
	_spawned.erase(bounty["id"])
	active = active.filter(func(b: Dictionary) -> bool: return b["id"] != bounty["id"])
	_player.inventory.add_gold(int(bounty["gold"]))
	_player.leveling.add_xp(int(bounty["xp"]), "bounty")
	var prize := LootGenerator.roll_special(int(bounty["level"]), "champion", 1.0, 2.0)
	if prize == null:
		prize = LootGenerator.make_equipment(int(bounty["level"]), maxi(LootGenerator.roll_rarity(0.0, 4.0), 2))
	_player.inventory.add(prize)
	Events.announcement.emit("BOUNTY COLLECTED", "%d gold, %d XP, %s" % [bounty["gold"], bounty["xp"], prize.display_name()])
	changed.emit()
	SaveGame.request_save()


func save_data() -> Dictionary:
	return {"active": active.duplicate(true)}


func load_data(data: Dictionary) -> void:
	active.clear()
	for saved: Variant in data.get("active", []):
		if saved is Dictionary and EnemyDB.ENEMIES.has(str(saved.get("monster", ""))):
			active.append(saved)
