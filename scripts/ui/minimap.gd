extends Control
## A small live map in the corner of the screen. Turn it on or off from the
## Map screen or the pause menu.

## Tiles shown in each direction from the player.
const RADIUS := 34
## Screen pixels per tile.
const SCALE := 2.0
const REFRESH_SECONDS := 0.3
const DOT := {"ore": Color("c8c8d0"), "tree": Color("4fae5a"), "herb": Color("a8e070"), "fish": Color("6fc0ff")}

var _player: Player
var _world: World
var _texture: ImageTexture
var _drawn_cell := Vector2i.MAX
var _refresh_left := 0.0
var _day_night: DayNight


func setup(player: Player, world: World) -> void:
	_player = player
	_world = world
	_day_night = world.get_parent().get_node_or_null("DayNight")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	custom_minimum_size = Vector2.ONE * ((RADIUS * 2 + 1) * SCALE + 8.0)
	GameSettings.changed.connect(func() -> void: visible = GameSettings.show_minimap)
	visible = GameSettings.show_minimap


func _process(delta: float) -> void:
	if _player == null:
		return
	# There is no map of caves and interiors.
	visible = GameSettings.show_minimap and not _player.indoors
	if not visible:
		return
	_refresh_left -= delta
	var cell := _world.world_to_cell(_player.global_position)
	if cell != _drawn_cell and _refresh_left <= 0.0:
		_refresh_left = REFRESH_SECONDS
		_drawn_cell = cell
		_render(cell)
	queue_redraw()


func _render(center: Vector2i) -> void:
	var generator := _world.generator
	var side := RADIUS * 2 + 1
	var image := Image.create(side, side, false, Image.FORMAT_RGB8)
	for y in side:
		for x in side:
			var type := generator.tile_type_at(center + Vector2i(x - RADIUS, y - RADIUS))
			image.set_pixel(x, y, TerrainTiles.COLORS[type].lightened(0.16))
	if _texture == null:
		_texture = ImageTexture.create_from_image(image)
	else:
		_texture.update(image)


func _draw() -> void:
	var inner := Rect2(Vector2(4, 4), size - Vector2(8, 8))
	draw_rect(Rect2(Vector2.ZERO, size), Color("402f1c"))
	draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), Color("8a683a"), false, 1.0)
	if _texture:
		draw_texture_rect(_texture, inner, false)
	var middle := size / 2.0
	var origin := _player.global_position
	for node in get_tree().get_nodes_in_group("resource_nodes"):
		_dot(inner, middle, node.global_position - origin, DOT[node.kind()], 1.5)
	for pickup in get_tree().get_nodes_in_group("pickups"):
		_dot(inner, middle, pickup.global_position - origin, UITheme.GOLD, 1.5)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		_dot(inner, middle, enemy.global_position - origin, Color("ff5050"), 2.5)
	_dot(inner, middle, -origin, UITheme.GOLD, 3.0)
	draw_circle(middle, 3.0, Color.BLACK)
	draw_circle(middle, 2.0, Color.WHITE)
	# The day count and time of day, just under the map.
	if _day_night:
		var font := UITheme.get_theme().default_font
		var text := "Day %d  -  %s" % [_day_night.day, _day_night.phase()]
		draw_string_outline(font, Vector2(0, size.y + 16.0), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, 4, Color.BLACK)
		draw_string(font, Vector2(0, size.y + 16.0), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, UITheme.HEADING)


## Draws a dot for something `offset` world pixels from the player.
func _dot(inner: Rect2, middle: Vector2, offset: Vector2, color: Color, radius: float) -> void:
	var point := middle + offset / TerrainTiles.TILE_SIZE * SCALE
	if inner.grow(-radius).has_point(point):
		draw_circle(point, radius, color)
