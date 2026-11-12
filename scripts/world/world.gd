class_name World
extends Node2D
## Streams the endless world in chunks around a target (the player).
##
## Chunks near the target are built a few per frame; chunks left far behind
## are freed. Each chunk is its own TileMapLayer, with border-blending
## layers on top.

signal chunk_built(chunk: Vector2i)
signal chunk_freed(chunk: Vector2i)

## The four sides of a tile, clockwise from the top, and the turn that
## points a top-edge fringe (or top-right corner) at each.
const SIDES: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const TURNS: Array[int] = [
	0,
	TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_H,
	TileSetAtlasSource.TRANSFORM_FLIP_H | TileSetAtlasSource.TRANSFORM_FLIP_V,
	TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_V,
]

## Chunk width and height, in tiles.
const CHUNK_SIZE := 16

## How many chunks to keep loaded in every direction from the target.
@export_range(1, 6) var load_radius := 2
## Chunks built per frame while catching up. Higher loads faster but can stutter.
@export_range(1, 8) var chunks_per_frame := 1

var generator: WorldGenerator
var target: Node2D

var _tile_set: TileSet
var _chunks: Dictionary[Vector2i, TileMapLayer] = {}
## Called with a tile; true where a structure or village has levelled the
## ground, so cliffs do not cut through it. Set by the game before chunks load.
var levelled: Callable
var _queue: Array[Vector2i] = []
var _center := Vector2i.MAX


func _ready() -> void:
	add_to_group("world")


func setup(world_seed: int) -> void:
	generator = WorldGenerator.new(world_seed)
	_tile_set = TerrainTiles.build_tileset()


func world_to_cell(world_position: Vector2) -> Vector2i:
	return Vector2i((world_position / TerrainTiles.TILE_SIZE).floor())


## World position of the centre of a tile.
func cell_to_world(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * TerrainTiles.TILE_SIZE


func cell_to_chunk(cell: Vector2i) -> Vector2i:
	return Vector2i((Vector2(cell) / CHUNK_SIZE).floor())


func tile_type_at_position(world_position: Vector2) -> int:
	return generator.tile_type_at(world_to_cell(world_position))


func tile_set() -> TileSet:
	return _tile_set


func loaded_chunk_count() -> int:
	return _chunks.size()


## Builds every chunk around a position immediately. Use after teleporting
## so the target never stands on missing ground.
func load_around_now(world_position: Vector2) -> void:
	_recenter(cell_to_chunk(world_to_cell(world_position)))
	for chunk in _queue:
		_build_chunk(chunk)
	_queue.clear()


func _process(_delta: float) -> void:
	if generator == null or target == null:
		return
	var center := cell_to_chunk(world_to_cell(target.global_position))
	if center != _center:
		_recenter(center)
	for i in chunks_per_frame:
		if _queue.is_empty():
			break
		_build_chunk(_queue.pop_front())


func _recenter(center: Vector2i) -> void:
	_center = center

	# Free chunks one ring beyond the load radius, so walking back and forth
	# over a chunk border does not rebuild the same chunks repeatedly.
	for chunk: Vector2i in _chunks.keys():
		if _chunk_distance(chunk, center) > load_radius + 1:
			_chunks[chunk].queue_free()
			_chunks.erase(chunk)
			chunk_freed.emit(chunk)

	_queue.clear()
	for y in range(-load_radius, load_radius + 1):
		for x in range(-load_radius, load_radius + 1):
			var chunk := center + Vector2i(x, y)
			if not _chunks.has(chunk):
				_queue.append(chunk)
	_queue.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (a - center).length_squared() < (b - center).length_squared()
	)


func _chunk_distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


## Redraws the ground of the chunks holding these cells (and their edges)
## after the player has changed it, without disturbing what stands there.
func refresh_cells(cells: Array) -> void:
	var chunks := {}
	for cell: Vector2i in cells:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				chunks[cell_to_chunk(cell + Vector2i(dx, dy))] = true
	for chunk: Vector2i in chunks:
		if not _chunks.has(chunk):
			continue
		(_chunks[chunk] as Node).queue_free()
		_chunks.erase(chunk)
		_build_chunk(chunk, false)


func _build_chunk(chunk: Vector2i, announce: bool = true) -> void:
	if _chunks.has(chunk):
		return
	var layer := TileMapLayer.new()
	layer.name = "Chunk_%d_%d" % [chunk.x, chunk.y]
	layer.tile_set = _tile_set
	layer.position = Vector2(chunk * CHUNK_SIZE * TerrainTiles.TILE_SIZE)
	layer.material = TerrainTiles.ground_material()
	# Four more layers hold the ragged strips that blend each terrain over
	# its neighbours, one layer per side.
	var fringes: Array[TileMapLayer] = []
	for side in 5:
		var fringe := TileMapLayer.new()
		fringe.tile_set = _tile_set
		fringe.collision_enabled = false
		fringe.use_parent_material = true
		layer.add_child(fringe)
		fringes.append(fringe)

	# Terrain for the chunk plus a one-tile border, looked up once.
	var origin := chunk * CHUNK_SIZE
	var span := CHUNK_SIZE + 2
	var types: PackedInt32Array = []
	types.resize(span * span)
	for y in span:
		for x in span:
			types[y * span + x] = generator.tile_type_at(origin + Vector2i(x - 1, y - 1))

	# A skirt of the neighbours' edge tiles, drawn underneath, so no hairline
	# of background ever shows where two chunks meet.
	var skirt := TileMapLayer.new()
	skirt.tile_set = _tile_set
	skirt.collision_enabled = false
	skirt.z_index = -1
	skirt.use_parent_material = true
	layer.add_child(skirt)
	for y in span:
		for x in span:
			if x == 0 or y == 0 or x == span - 1 or y == span - 1:
				var ring := Vector2i(x - 1, y - 1)
				skirt.set_cell(ring, TerrainTiles.TERRAIN_SOURCE, TerrainTiles.atlas_coords(types[y * span + x], generator.variant_at(origin + ring)))

	for y in CHUNK_SIZE:
		for x in CHUNK_SIZE:
			var here := Vector2i(x, y)
			var type := types[(y + 1) * span + x + 1]
			layer.set_cell(here, TerrainTiles.TERRAIN_SOURCE, TerrainTiles.atlas_coords(type, generator.variant_at(origin + here)))
			var rank := TerrainTiles.priority(type)
			var spills: Array[bool] = [false, false, false, false]
			for side in 4:
				var beside: Vector2i = SIDES[side]
				var other := types[(y + 1 + beside.y) * span + x + 1 + beside.x]
				if TerrainTiles.priority(other) > rank:
					spills[side] = true
					fringes[side].set_cell(here, TerrainTiles.FRINGE_SOURCE, Vector2i(0, other), TURNS[side])
			# A corner piece where only the diagonal neighbour spills over.
			for side in 4:
				if spills[side] or spills[(side + 1) % 4]:
					continue
				var diagonal: Vector2i = SIDES[side] + SIDES[(side + 1) % 4]
				var other := types[(y + 1 + diagonal.y) * span + x + 1 + diagonal.x]
				if TerrainTiles.priority(other) > rank:
					fringes[side].set_cell(here, TerrainTiles.FRINGE_SOURCE, Vector2i(1, other), TURNS[side])
	# Cliffs: the faces, edges and shadows where high ground drops away.
	var has_high := false
	for type in types:
		if type in TerrainTiles.HIGH:
			has_high = true
			break
	if has_high:
		var cliffs := CliffFaces.new()
		cliffs.types = types
		cliffs.span = span
		cliffs.origin = origin
		cliffs.levelled = levelled
		layer.add_child(cliffs)
	add_child(layer)
	_chunks[chunk] = layer
	if announce:
		chunk_built.emit(chunk)
