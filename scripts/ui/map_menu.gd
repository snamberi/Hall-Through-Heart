class_name MapMenu
extends GameMenu
## A map of the land around the player, drawn from the world generator.

## Tiles shown in each direction from the player.
const RADIUS := 100
## Screen pixels per tile.
const SCALE := 2

var _map: TextureRect
var _where: Label
var _world: World


func _build() -> void:
	content.add_child(UITheme.heading("Map", 28))
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 28)
	content.add_child(columns)

	var frame := UITheme.inset_panel()
	columns.add_child(frame)
	_map = TextureRect.new()
	_map.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_map.custom_minimum_size = Vector2.ONE * (RADIUS * 2 + 1) * SCALE
	_map.stretch_mode = TextureRect.STRETCH_SCALE
	frame.add_child(_map)

	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 6)
	columns.add_child(side)
	_where = UITheme.label("", 16)
	side.add_child(_where)
	side.add_child(UITheme.label("White: you      Gold: the Sanctuary", 14, UITheme.DIM))
	side.add_child(UITheme.heading("Terrain", 18))
	for type in TerrainTiles.Type.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var swatch := ColorRect.new()
		swatch.color = _map_color(type)
		swatch.custom_minimum_size = Vector2(16, 16)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(swatch)
		row.add_child(UITheme.label(TerrainTiles.NAMES[type], 14))
		side.add_child(row)


func refresh() -> void:
	if _world == null:
		_world = player.get_parent().get_node("World")
	var generator := _world.generator
	var center := _world.world_to_cell(player.global_position)
	var size := RADIUS * 2 + 1
	var image := Image.create(size, size, false, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			var cell := center + Vector2i(x - RADIUS, y - RADIUS)
			image.set_pixel(x, y, _map_color(generator.tile_type_at(cell)))
	_mark(image, Vector2i(RADIUS, RADIUS) - center, UITheme.GOLD)
	_mark(image, Vector2i(RADIUS, RADIUS), Color.WHITE)
	_map.texture = ImageTexture.create_from_image(image)
	_where.text = "Tile %d, %d\n%s\nArea level %d" % [
		center.x, center.y,
		TerrainTiles.display_name(generator.tile_type_at(center)),
		generator.enemy_level_at(center),
	]


func _map_color(type: int) -> Color:
	return TerrainTiles.COLORS[type].lightened(0.18)


## Draws a small cross, if it falls inside the image.
func _mark(image: Image, at: Vector2i, color: Color) -> void:
	for offset: Vector2i in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var point := at + offset
		if point.x >= 0 and point.y >= 0 and point.x < image.get_width() and point.y < image.get_height():
			image.set_pixelv(point, color)
