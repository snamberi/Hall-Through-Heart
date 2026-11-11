class_name NpcSpawner
extends Node2D
## Nobody waits at the Sanctuary: the player wakes alone. Merchants and
## wardens live in villages (see Villages) and at camps on the road.

const REGION := 96
const SANCTUARY := {}

var _world: World
var _by_chunk: Dictionary = {}


func setup(world: World) -> void:
	_world = world
	world.chunk_built.connect(_on_chunk_built)
	world.chunk_freed.connect(_on_chunk_freed)


## The camp tile for the region containing a tile, or null if that region
## has none (the camp fell on water or rock, or it is the Sanctuary's region).
func camp_cell(region: Vector2i) -> Variant:
	if region == Vector2i.ZERO or region == Vector2i(-1, 0) or region == Vector2i(0, -1) or region == Vector2i(-1, -1):
		return null
	var random := RandomNumberGenerator.new()
	random.seed = hash(Vector3i(region.x, region.y, _world.generator.world_seed + 77))
	var cell := region * REGION + Vector2i(random.randi_range(16, REGION - 16), random.randi_range(16, REGION - 16))
	for offset: Vector2i in [Vector2i.ZERO, Vector2i(4, 0), Vector2i(2, 0)]:
		if not _world.generator.is_walkable(cell + offset):
			return null
	return cell


func _on_chunk_built(chunk: Vector2i) -> void:
	var placed: Array = []
	var origin := chunk * World.CHUNK_SIZE
	var bounds := Rect2i(origin, Vector2i(World.CHUNK_SIZE, World.CHUNK_SIZE))
	for kind: String in SANCTUARY:
		if bounds.has_point(SANCTUARY[kind]):
			placed.append(_place(kind, SANCTUARY[kind]))
	_by_chunk[chunk] = placed


func _place(kind: String, cell: Vector2i) -> Npc:
	var npc := Npc.create(kind, _world.cell_to_world(cell))
	add_child(npc)
	return npc


func _on_chunk_freed(chunk: Vector2i) -> void:
	for npc: Variant in _by_chunk.get(chunk, []):
		if is_instance_valid(npc):
			npc.queue_free()
	_by_chunk.erase(chunk)
