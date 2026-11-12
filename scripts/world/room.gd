class_name Room
extends Node2D
## A place off the world map: a cave, a void arena, the inside of a house.
## It is built far from the playable world and surrounded by blackness.

## Where rooms are built: well away from where the player was standing, but
## near enough to the origin that positions stay exact. (Far out, positions
## round to sixteenths of a pixel, and the physics wedges bodies into walls.)
static var ORIGIN := Vector2(0, -90000)
const FAR := 90000.0


## Picks where the next room goes, given where the player is in the world.
## Call before making a Room.
static func choose_origin(from: Vector2) -> void:
	ORIGIN = Vector2(0, -FAR) if from.y > 0.0 or from.distance_to(Vector2(0, -FAR)) >= FAR else Vector2(0, FAR)


## Whether a position is inside the space set aside for the current room.
static func holds(at: Vector2) -> bool:
	return at.distance_to(ORIGIN) < 30000.0

var title := ""
## Tile types by cell; anything not in here is solid black.
var cells: Dictionary[Vector2i, int] = {}
var entry := Vector2i.ZERO
## Enemies that belong to this room, so they can be cleared with it.
var enemies: Array = []
## How the walls' faces look: "rock", "stone", "wood" or "void".
var wall_style := "rock"
## How dark it is inside: 0 for a lit house, near 1 for a cave.
var gloom := 0.0

var _layer: TileMapLayer
var _faces: WallFaces


func _init() -> void:
	position = ORIGIN
	y_sort_enabled = true


## Lays the tiles and the darkness. Call once `cells` is filled in.
func build(tile_set: TileSet) -> void:
	var dark := Polygon2D.new()
	dark.color = Color.BLACK
	dark.polygon = PackedVector2Array([Vector2(-6000, -6000), Vector2(6000, -6000), Vector2(6000, 6000), Vector2(-6000, 6000)])
	dark.z_index = -12
	add_child(dark)
	_layer = TileMapLayer.new()
	_layer.tile_set = tile_set
	_layer.material = TerrainTiles.ground_material()
	_layer.z_index = -10
	add_child(_layer)
	for cell in cells:
		_layer.set_cell(cell, TerrainTiles.TERRAIN_SOURCE, TerrainTiles.atlas_coords(cells[cell], TerrainTiles.pick_variant(hash(cell))))
	_faces = WallFaces.new()
	_faces.room = self
	_faces.style = wall_style
	add_child(_faces)
	_add_void_glows()


## Voidscar floors hold glowing deposits; the brightest few of them light
## the dark around them faintly, so the hollow glimmers.
func _add_void_glows() -> void:
	var spots: Array[Vector2i] = []
	for cell in cells:
		if cells[cell] != TerrainTiles.Type.VOIDSCAR:
			continue
		var variant := TerrainTiles.pick_variant(hash(cell))
		# Deposits, lit cracks and rifts (see tools/generate_art.py).
		if variant in [TerrainTiles.PLAIN_VARIANTS + 1, TerrainTiles.PLAIN_VARIANTS + 2, TerrainTiles.PLAIN_VARIANTS + 5]:
			spots.append(cell)
	spots.shuffle()
	for cell in spots.slice(0, 12):
		var glow := PointLight2D.new()
		glow.texture = Prop.LIGHT
		glow.color = Color(0.62, 0.42, 1.0)
		glow.energy = 0.55
		glow.texture_scale = 0.9
		glow.position = cell_position(cell) - ORIGIN + Vector2(0, 4)
		add_child(glow)


## World position of the middle of a room cell.
func cell_position(cell: Vector2i) -> Vector2:
	return ORIGIN + (Vector2(cell) + Vector2(0.5, 0.5)) * TerrainTiles.TILE_SIZE


## Changes one tile after the room is built.
func set_tile(cell: Vector2i, type: int) -> void:
	cells[cell] = type
	if _layer:
		_layer.set_cell(cell, TerrainTiles.TERRAIN_SOURCE, TerrainTiles.atlas_coords(type, TerrainTiles.pick_variant(hash(cell))))
	if _faces:
		_faces.queue_redraw()


func is_floor(cell: Vector2i) -> bool:
	return cells.has(cell) and not TerrainTiles.is_solid(cells[cell])


## Floor cells, farthest from the entry first.
func floor_by_distance() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in cells:
		if is_floor(cell):
			result.append(cell)
	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return (a - entry).length_squared() > (b - entry).length_squared())
	return result


## Adds something placed at a world position (as cell_position gives).
func add_prop(node: Node2D) -> Node2D:
	node.position -= position
	add_child(node)
	return node


func living_enemies() -> int:
	var count := 0
	for enemy: Variant in enemies:
		if is_instance_valid(enemy) and not enemy.health.is_dead():
			count += 1
	return count


func clear_enemies() -> void:
	for enemy: Variant in enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	enemies.clear()
