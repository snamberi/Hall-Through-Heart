class_name ResourceSpawner
extends Node2D
## Places gatherable nodes as chunks load, the same way for a given seed.
##
## Gathered nodes stay gone for REGROW_SECONDS, tracked only while the game
## is running.

const REGROW_SECONDS := 240.0
## Nothing grows this close to the world origin, in tiles.
const CLEAR_RADIUS := 4.0

var _world: World
## chunk -> nodes placed for it
var _by_chunk: Dictionary = {}
## cell -> time it was gathered (seconds since start)
var _gathered: Dictionary = {}


func setup(world: World) -> void:
	_world = world
	world.chunk_built.connect(_on_chunk_built)
	world.chunk_freed.connect(_on_chunk_freed)


func _on_chunk_built(chunk: Vector2i) -> void:
	var generator := _world.generator
	var random := RandomNumberGenerator.new()
	random.seed = hash(Vector3i(chunk.x, chunk.y, generator.world_seed))
	var placed: Array = []
	var used := {}
	for kind: String in GatherDB.PER_CHUNK:
		for attempt: int in GatherDB.PER_CHUNK[kind]:
			var cell := chunk * World.CHUNK_SIZE + Vector2i(random.randi_range(0, World.CHUNK_SIZE - 1), random.randi_range(0, World.CHUNK_SIZE - 1))
			var id := GatherDB.pick(kind, generator.tile_type_at(cell), generator.enemy_level_at(cell), random)
			if id == "" or used.has(cell) or Vector2(cell).length() < CLEAR_RADIUS:
				continue
			used[cell] = true
			if _gathered.has(cell) and _now() - _gathered[cell] < REGROW_SECONDS:
				continue
			var node := ResourceNode.create(id, cell, _world.cell_to_world(cell))
			node.harvested.connect(func(gone: ResourceNode) -> void: _gathered[gone.cell] = _now())
			add_child(node)
			placed.append(node)
	_by_chunk[chunk] = placed


func _on_chunk_freed(chunk: Vector2i) -> void:
	for node: Variant in _by_chunk.get(chunk, []):
		if is_instance_valid(node):
			node.queue_free()
	_by_chunk.erase(chunk)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
