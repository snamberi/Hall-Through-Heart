class_name EnemySpawner
extends Node2D
## Keeps a handful of enemies alive around the player, just off screen.
##
## Nothing spawns near the world origin, so the starting area stays safe.

## Loaded by path, so a game whose script cache predates these still runs.
const SharedWorld := preload("res://scripts/net/net_world.gd")

@export var enemy_scene: PackedScene
## Modifiers every new enemy gets while they are set (a Heart Rift's affixes).
var forced_modifiers: Array[String] = []
@export var max_alive := 8
## Seconds between spawn attempts.
@export var spawn_interval := 1.0
## Enemies appear between these distances from the player, in pixels.
## The minimum must stay larger than half the screen diagonal (about 370).
@export var min_spawn_distance := 410.0
@export var max_spawn_distance := 640.0
## Enemies further than this from the player are removed.
@export var despawn_distance := 1000.0
## No spawns within this many tiles of the world origin.
@export var safe_radius_tiles := 16.0
## Chance that a spawn is an Elite.
@export_range(0.0, 1.0) var elite_chance := 0.08
## Chance that a spawn is a Champion, once the area level allows them.
@export_range(0.0, 1.0) var champion_chance := 0.015
@export var champion_min_area_level := 4

var _world: World
var _player: Player
var _time_left := 0.0


func setup(world: World, player: Player) -> void:
	_world = world
	_player = player


func alive_count() -> int:
	return get_tree().get_nodes_in_group("enemies").size()


func spawn_at(
	world_position: Vector2, level: int = 1, rank: Enemy.Rank = Enemy.Rank.NORMAL,
	enemy_id: String = "husk", fragment: bool = false
) -> Enemy:
	var enemy: Enemy = enemy_scene.instantiate()
	enemy.position = world_position
	enemy.target = _player
	enemy.is_fragment = fragment
	enemy.extra_modifiers = forced_modifiers.duplicate()
	enemy.configure(level, rank, enemy_id)
	# It comes ready for what its faction has learned of the player.
	var factions: Factions = get_tree().get_first_node_in_group("factions")
	if factions:
		factions.adapt(enemy)
	enemy.died.connect(_on_enemy_died)
	enemy.wants_minion.connect(_on_wants_minion)
	add_child(enemy)
	return enemy


## A Summoner calls a normal enemy of its own kind to its side.
func _on_wants_minion(enemy: Enemy) -> void:
	spawn_at(enemy.global_position + Vector2.from_angle(randf() * TAU) * 50.0, enemy.level, Enemy.Rank.NORMAL, enemy.enemy_id)


## Slimes (and anything else with the "split" trait) burst into two smaller copies.
func _on_enemy_died(enemy: Enemy) -> void:
	if not enemy.has_trait("split") or enemy.is_fragment:
		return
	for side: float in [-1.0, 1.0]:
		var piece := spawn_at(enemy.global_position + Vector2(18.0 * side, randf_range(-8.0, 8.0)), enemy.level, Enemy.Rank.NORMAL, enemy.enemy_id, true)
		piece.velocity = Vector2(160.0 * side, 0.0)


func _physics_process(delta: float) -> void:
	# Rooms off the map are stocked by whoever built them.
	if _world == null or _player.is_dead() or _player.indoors:
		return
	_time_left -= delta
	if _time_left > 0.0:
		return
	_time_left = spawn_interval

	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		# Copies of other players' monsters come and go with the news.
		if enemy.net_puppet:
			continue
		# Lair guardians stay put; their structure removes them with its chunk.
		# A wounded monster lingers for a few minutes so the player can come
		# back and finish it, rather than meeting a fresh one at full health.
		var far := enemy.global_position.distance_to(_player.global_position)
		var wounded := enemy.health.current < enemy.health.max_health and enemy._since_hurt < Enemy.WOUNDS_LAST
		if enemy.lair_home == Vector2.INF and far > despawn_distance and (not wounded or far > despawn_distance * 2.6):
			# Left behind alive, it carries what it learned back to its faction.
			enemy.escape()
			enemy.queue_free()

	# More things stir after dark.
	var night: DayNight = get_parent().get_node_or_null("DayNight")
	var limit := roundi(max_alive * (1.5 if night and night.is_night() else 0.6) * (1.8 if DayNight.blood_moon else 1.0) * _violence())
	if alive_count() < limit:
		_try_spawn()


func _try_spawn() -> void:
	var angle := randf() * TAU
	var distance := randf_range(min_spawn_distance, max_spawn_distance)
	var spawn_position := _player.global_position + Vector2.from_angle(angle) * distance
	var cell := _world.world_to_cell(spawn_position)
	if Vector2(cell).length() < safe_radius_tiles:
		return
	# In a shared world, the nearest player's game stirs the monsters there
	# (so two friends together do not get twice as many).
	if SharedWorld.current and not SharedWorld.current.nearest_to(spawn_position):
		return
	# Nothing appears in water or inside rock.
	if not _world.generator.is_dry_land(cell):
		return
	var level := maxi(_world.generator.enemy_level_at(cell) + randi_range(-1, 1), 1)
	var rank := Enemy.Rank.NORMAL
	var roll := randf()
	var elites: float = Difficulty.value("elites") * (3.0 if DayNight.blood_moon else 1.0)
	if roll < champion_chance * elites and _world.generator.enemy_level_at(cell) >= champion_min_area_level:
		rank = Enemy.Rank.CHAMPION
	elif roll < (champion_chance + elite_chance) * elites:
		rank = Enemy.Rank.ELITE
	var area_level := _world.generator.enemy_level_at(cell)
	var night: DayNight = get_parent().get_node_or_null("DayNight")
	var enemy_id := EnemyDB.pick(_world.generator.tile_type_at(cell), area_level, night == null or night.is_night())
	if enemy_id == "":
		return
	if EnemyDB.ENEMIES[enemy_id].get("wild", "") != "":
		rank = Enemy.Rank.NORMAL
	# Now and then a named miniboss of these lands turns up instead.
	if randf() < MinibossDB.CHANCE * (2.0 if DayNight.blood_moon else 1.0) and not _named_about():
		var named := MinibossDB.pick(_world.generator.tile_type_at(cell), area_level)
		if named != "":
			_spawn_named(named, _world.cell_to_world(cell), level + 2)
			return
	var enemy := spawn_at(_world.cell_to_world(cell), level, rank, enemy_id)
	# Where much magic was cast, the air still hums, and monsters born there
	# hear the player from further off.
	var memory: WorldMemory = get_parent().get_node_or_null("WorldMemory")
	if memory and enemy:
		enemy.senses = memory.harmonics(cell)


## Monsters are drawn to places where much blood has been spilled.
func _violence() -> float:
	var memory: WorldMemory = get_parent().get_node_or_null("WorldMemory")
	return memory.violence(_world.world_to_cell(_player.global_position)) if memory and not _player.indoors else 1.0


func _named_about() -> bool:
	for node in get_tree().get_nodes_in_group("enemies"):
		if (node as Enemy).named_id != "":
			return true
	return false


func _spawn_named(named: String, at: Vector2, level: int) -> Enemy:
	var data: Dictionary = MinibossDB.NAMED[named]
	var enemy: Enemy = enemy_scene.instantiate()
	enemy.position = at
	enemy.target = _player
	enemy.named_id = named
	enemy.configure(level, Enemy.Rank.MINIBOSS, data["monster"])
	enemy.died.connect(_on_enemy_died)
	enemy.wants_minion.connect(_on_wants_minion)
	add_child(enemy)
	Events.announcement.emit(str(data["name"]).to_upper(), "roams nearby")
	return enemy
