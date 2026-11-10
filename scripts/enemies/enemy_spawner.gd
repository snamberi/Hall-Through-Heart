class_name EnemySpawner
extends Node2D
## Keeps a handful of enemies alive around the player, just off screen.
##
## Nothing spawns near the world origin, so the starting area stays safe.

@export var enemy_scene: PackedScene
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
	enemy.configure(level, rank, enemy_id)
	enemy.died.connect(_on_enemy_died)
	add_child(enemy)
	return enemy


## Slimes (and anything else with the "split" trait) burst into two smaller copies.
func _on_enemy_died(enemy: Enemy) -> void:
	if not enemy.has_trait("split") or enemy.is_fragment:
		return
	for side: float in [-1.0, 1.0]:
		var piece := spawn_at(enemy.global_position + Vector2(18.0 * side, randf_range(-8.0, 8.0)), enemy.level, Enemy.Rank.NORMAL, enemy.enemy_id, true)
		piece.velocity = Vector2(160.0 * side, 0.0)


func _physics_process(delta: float) -> void:
	if _world == null or _player.is_dead():
		return
	_time_left -= delta
	if _time_left > 0.0:
		return
	_time_left = spawn_interval

	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy.global_position.distance_to(_player.global_position) > despawn_distance:
			enemy.queue_free()

	if alive_count() < max_alive:
		_try_spawn()


func _try_spawn() -> void:
	var angle := randf() * TAU
	var distance := randf_range(min_spawn_distance, max_spawn_distance)
	var spawn_position := _player.global_position + Vector2.from_angle(angle) * distance
	var cell := _world.world_to_cell(spawn_position)
	if Vector2(cell).length() < safe_radius_tiles:
		return
	# Deep water and rock stay empty; fliers and swimmers pick from the rest.
	if not _world.generator.is_walkable(cell):
		return
	var level := maxi(_world.generator.enemy_level_at(cell) + randi_range(-1, 1), 1)
	var rank := Enemy.Rank.ELITE if randf() < elite_chance else Enemy.Rank.NORMAL
	var area_level := _world.generator.enemy_level_at(cell)
	spawn_at(_world.cell_to_world(cell), level, rank, EnemyDB.pick(_world.generator.tile_type_at(cell), area_level))
