class_name Room
extends Node2D
## A place off the world map: a cave, a void arena, the inside of a house.
## It is built far from the playable world and surrounded by blackness.

## Where rooms are built, well away from anything the world generates.
const ORIGIN := Vector2(0, -900000)

var title := ""
## Tile types by cell; anything not in here is solid black.
var cells: Dictionary[Vector2i, int] = {}
var entry := Vector2i.ZERO
## Enemies that belong to this room, so they can be cleared with it.
var enemies: Array = []

var _layer: TileMapLayer


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
	_layer.z_index = -10
	add_child(_layer)
	for cell in cells:
		_layer.set_cell(cell, TerrainTiles.TERRAIN_SOURCE, TerrainTiles.atlas_coords(cells[cell], posmod(hash(cell), 8)))


## World position of the middle of a room cell.
func cell_position(cell: Vector2i) -> Vector2:
	return ORIGIN + (Vector2(cell) + Vector2(0.5, 0.5)) * TerrainTiles.TILE_SIZE


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
