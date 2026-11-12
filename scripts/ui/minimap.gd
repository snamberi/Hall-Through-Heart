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
var _exploration: Exploration
## Places near enough to show: [world position, kind].
var _places: Array = []


func setup(player: Player, world: World) -> void:
	_player = player
	_world = world
	_day_night = world.get_parent().get_node_or_null("DayNight")
	_exploration = world.get_parent().get_node_or_null("Exploration")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	custom_minimum_size = Vector2.ONE * ((RADIUS * 2 + 1) * SCALE + 8.0)
	GameSettings.changed.connect(func() -> void: visible = GameSettings.show_minimap)
	visible = GameSettings.show_minimap


func _process(delta: float) -> void:
	if _player == null:
		return
	# There is no map of caves and interiors.
	visible = GameSettings.show_minimap and not _player.indoors and not BuildPalette.on
	if not visible:
		return
	_refresh_left -= delta
	var cell := _world.world_to_cell(_player.global_position)
	if cell != _drawn_cell and _refresh_left <= 0.0:
		_refresh_left = REFRESH_SECONDS
		_drawn_cell = cell
		_render(cell)
		_find_places(cell)
	queue_redraw()


func _render(center: Vector2i) -> void:
	var generator := _world.generator
	var side := RADIUS * 2 + 1
	var image := Image.create(side, side, false, Image.FORMAT_RGB8)
	for y in side:
		for x in side:
			var tile := center + Vector2i(x - RADIUS, y - RADIUS)
			if _exploration and not _exploration.is_tile_seen(tile):
				image.set_pixel(x, y, Color(0.07, 0.075, 0.09))
				continue
			image.set_pixel(x, y, TerrainTiles.COLORS[generator.tile_type_at(tile)].lightened(0.16))
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
	# Places close by, as on the big map.
	for place: Array in _places:
		_icon(inner, middle, (place[0] as Vector2) - origin, place[1], 13.0)
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.health.is_dead():
			continue
		if enemy.is_wild():
			_icon(inner, middle, enemy.global_position - origin, "animal", 10.0)
		elif enemy.rank >= Enemy.Rank.MINIBOSS:
			_icon(inner, middle, enemy.global_position - origin, "lair", 12.0)
		else:
			_icon(inner, middle, enemy.global_position - origin, "monster", 8.0)
	for node in get_tree().get_nodes_in_group("npcs"):
		_icon(inner, middle, (node as Node2D).global_position - origin, "npc", 10.0)
	if _player.pets and _player.pets.active >= 0:
		_icon(inner, middle, _player.pets.global_position - origin, "pet", 9.0)
	_icon(inner, middle, -origin, "temple", 12.0)
	MapIcons.draw_player(self, middle, _player.facing, 14.0)
	# The day count and time of day, just under the map.
	if _day_night:
		var font := UITheme.get_theme().default_font
		var text := "Day %d  -  %s" % [_day_night.day, _day_night.phase()]
		draw_string_outline(font, Vector2(0, size.y + 16.0), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, 4, Color.BLACK)
		draw_string(font, Vector2(0, size.y + 16.0), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, UITheme.HEADING)
		# Weather and blood moons, in a line of their own over the map.
		var sky := Atmosphere.weather
		if DayNight.blood_moon:
			sky = "Blood Moon" if sky == "" else sky + "  -  Blood Moon"
		if sky != "":
			var color := Color(1.0, 0.45, 0.4) if DayNight.blood_moon else Color(0.75, 0.88, 1.0)
			draw_string_outline(font, Vector2(-40, -5.0), sky, HORIZONTAL_ALIGNMENT_RIGHT, size.x + 40.0, 13, 4, Color.BLACK)
			draw_string(font, Vector2(-40, -5.0), sky, HORIZONTAL_ALIGNMENT_RIGHT, size.x + 40.0, 13, color)


## Draws a map icon for something `offset` world pixels from the player.
func _icon(inner: Rect2, middle: Vector2, offset: Vector2, kind: String, icon_size: float) -> void:
	var point := middle + offset / TerrainTiles.TILE_SIZE * SCALE
	if inner.grow(-icon_size * 0.4).has_point(point):
		MapIcons.draw(self, point, kind, icon_size)


## Villages and structures within the minimap's reach that the player has
## seen: [world position, kind].
func _find_places(center: Vector2i) -> void:
	_places.clear()
	var structures: Structures = _world.get_parent().get_node_or_null("Structures")
	var chunk := _world.cell_to_chunk(center)
	var reach := ceili(float(RADIUS) / World.CHUNK_SIZE) + 1
	if structures:
		for cy in range(chunk.y - reach, chunk.y + reach + 1):
			for cx in range(chunk.x - reach, chunk.x + reach + 1):
				var site := structures.site_for(Vector2i(cx, cy))
				if not site.is_empty() and (_exploration == null or _exploration.is_tile_seen(site["cell"])):
					_places.append([_world.cell_to_world(site["cell"]), site["kind"]])
	var region := Vector2i((Vector2(center) / WorldGenerator.VILLAGE_REGION).floor())
	for ry in range(region.y - 1, region.y + 2):
		for rx in range(region.x - 1, region.x + 2):
			var village: Variant = _world.generator.village_center(Vector2i(rx, ry))
			if village != null and (_exploration == null or _exploration.is_tile_seen(village)):
				_places.append([_world.cell_to_world(village), "village"])


## Draws a dot for something `offset` world pixels from the player.
func _dot(inner: Rect2, middle: Vector2, offset: Vector2, color: Color, radius: float) -> void:
	var point := middle + offset / TerrainTiles.TILE_SIZE * SCALE
	if inner.grow(-radius).has_point(point):
		draw_circle(point, radius, color)
