class_name MapMenu
extends GameMenu
## The world map, filling the screen. Drag to move around, scroll to zoom,
## hover to see the land under the mouse. Only places the player has seen
## are shown, with icons for villages and structures found there.

## Screen pixels per map cell at each zoom step.
const ZOOMS: Array[float] = [1.0, 2.0, 3.0, 5.0, 8.0, 12.0]
const ICONS := {
	"village": [Color("f0cf6a"), "Village"], "ruin": [Color("c8c4b8"), "Ruin"], "shrine": [Color("c08cff"), "Shrine"],
	"cave": [Color("8a8794"), "Cave"], "lair": [Color("e05a5a"), "Lair"], "portal": [Color("9a6cf0"), "Void portal"],
	"camp": [Color("c0a080"), "Abandoned camp"], "waystone": [Color("8fe0ff"), "Waystone"], "obelisk": [Color("d0b0ff"), "Obelisk"],
	"merchant": [Color("ffd060"), "Wandering merchant"], "shipwreck": [Color("a08060"), "Shipwreck"], "treasure": [Color("ff4030"), "Buried treasure"],
	"boss": [Color("ff4d4d"), "World boss"], "altar": [Color("c08cff"), "Altar of Magic"], "dungeon": [Color("b0a0d0"), "Crypt"], "bounty": [Color("ff8a3a"), "Bounty target"],
	"temple": [Color("ffe8a0"), "The Sanctuary"], "home": [Color("8fd66a"), "Home"], "checkpoint": [Color("ffb060"), "Resting place"],
	"watchtower": [Color("b0acb8"), "Ruined watchtower"], "graveyard": [Color("a0a8b8"), "Graveyard"], "henge": [Color("9ad0c0"), "Standing stones"],
	"farmstead": [Color("d8b070"), "Abandoned farmstead"], "library": [Color("c8a070"), "Ruined library"],
}

var _view: Control
var _hover: Label
var _minimap: CheckBox
var _world: World
var _exploration: Exploration
## The map cell at the middle of the view.
var _center := Vector2.ZERO
var _zoom_index := 2
var _dragging := false
var _image: Image
var _texture: ImageTexture
var _dirty := true
var _icons: Array = []
var _colors: Dictionary = {}


func _build() -> void:
	_view = Control.new()
	# Nearly the whole screen, leaving room for the frame and the bar below.
	_view.custom_minimum_size = Vector2(1180, 540)
	_view.clip_contents = true
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.gui_input.connect(_on_view_input)
	_view.draw.connect(_draw_view)
	content.add_child(_view)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 18)
	content.add_child(bar)
	_hover = UITheme.label("", 16)
	_hover.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(_hover)
	bar.add_child(UITheme.label("Drag to move   Scroll to zoom", 14, UITheme.DIM))
	bar.add_child(UITheme.button("Find me", func() -> void:
		_center_on_player()
		_dirty = true
		_view.queue_redraw()
	, 120.0))
	_minimap = CheckBox.new()
	_minimap.text = "Minimap"
	_minimap.toggled.connect(func(on: bool) -> void: GameSettings.set_value("show_minimap", on))
	bar.add_child(_minimap)


func refresh() -> void:
	if _world == null:
		_world = player.get_parent().get_node("World")
		_exploration = player.get_parent().get_node("Exploration")
	_minimap.set_pressed_no_signal(GameSettings.show_minimap)
	_center_on_player()
	_dirty = true
	_view.queue_redraw()


func _center_on_player() -> void:
	var tile := _world.world_to_cell(player.global_position if not player.indoors else player.get_parent().get_node("Instances").return_position())
	_center = Vector2(tile) / Exploration.CELL


func _scale() -> float:
	return ZOOMS[_zoom_index]


func _on_view_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			# Zoom about the point under the mouse.
			var before := _map_at(event.position)
			_zoom_index = clampi(_zoom_index + (1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1), 0, ZOOMS.size() - 1)
			_center += before - _map_at(event.position)
			_dirty = true
			_view.queue_redraw()
	elif event is InputEventMouseMotion:
		if _dragging:
			_center -= event.relative / _scale()
			_dirty = true
			_view.queue_redraw()
		_describe(event.position)


## The map cell (fractional) under a point in the view.
func _map_at(point: Vector2) -> Vector2:
	return _center + (point - _view.size / 2.0) / _scale()


func _describe(point: Vector2) -> void:
	var map_cell := Vector2i(_map_at(point).floor())
	var tile := map_cell * Exploration.CELL + Vector2i(2, 2)
	if not _exploration.is_seen(map_cell):
		_hover.text = "Unexplored"
		return
	var text := "%s   -   area level %d   -   %d, %d" % [TerrainTiles.display_name(_world.generator.tile_type_at(tile)), _world.generator.enemy_level_at(tile), tile.x, tile.y]
	for icon: Array in _icons:
		if (icon[0] as Vector2).distance_to(point) < 12.0:
			text = "%s   -   %s" % [ICONS[icon[1]][1], text]
	_hover.text = text


func _draw_view() -> void:
	var scale := _scale()
	var cells := Vector2i((_view.size / scale).ceil()) + Vector2i(2, 2)
	var origin := Vector2i((_center - Vector2(cells) / 2.0).floor())
	if _dirty:
		_dirty = false
		_render(origin, cells)
	var offset := (Vector2(origin) - _center) * scale + _view.size / 2.0
	_view.draw_rect(Rect2(Vector2.ZERO, _view.size), Color("07080c"))
	_view.draw_texture_rect(_texture, Rect2(offset, Vector2(cells) * scale), false)
	_collect_icons(origin, cells, offset, scale)
	for icon: Array in _icons:
		_draw_icon(icon[0], icon[1])
	# The player, pointing the way they face.
	var tile := _world.world_to_cell(player.global_position if not player.indoors else player.get_parent().get_node("Instances").return_position())
	var at := (Vector2(tile) / Exploration.CELL - _center) * scale + _view.size / 2.0
	# Living things near the player: beasts, monsters, companions, people.
	if not player.indoors:
		var to_map := func(world_position: Vector2) -> Vector2:
			return (world_position / TerrainTiles.TILE_SIZE / Exploration.CELL - _center) * scale + _view.size / 2.0
		for node in get_tree().get_nodes_in_group("enemies"):
			var enemy := node as Enemy
			if enemy and not enemy.health.is_dead():
				MapIcons.draw(_view, to_map.call(enemy.global_position), "animal" if enemy.is_wild() else "monster", 14.0 if enemy.is_wild() else 12.0)
		for node in get_tree().get_nodes_in_group("npcs"):
			MapIcons.draw(_view, to_map.call((node as Node2D).global_position), "npc", 14.0)
		if player.pets and player.pets.active >= 0:
			MapIcons.draw(_view, to_map.call(player.pets.global_position), "pet", 13.0)
	MapIcons.draw_player(_view, at, player.facing, 22.0)
	# A frame around the map.
	_view.draw_rect(Rect2(Vector2.ZERO, _view.size), Color("402f1c"), false, 4.0)
	_view.draw_rect(Rect2(Vector2(2, 2), _view.size - Vector2(4, 4)), Color("8a683a"), false, 1.5)


func _render(origin: Vector2i, cells: Vector2i) -> void:
	_image = Image.create(cells.x, cells.y, false, Image.FORMAT_RGBA8)
	var generator := _world.generator
	for y in cells.y:
		for x in cells.x:
			var map_cell := origin + Vector2i(x, y)
			if not _exploration.is_seen(map_cell):
				# Unexplored: dark, with a faint texture so it reads as fog.
				var shade := 0.07 + 0.02 * float(posmod(hash(map_cell), 3))
				_image.set_pixel(x, y, Color(shade, shade * 1.05, shade * 1.25))
				continue
			var color: Variant = _colors.get(map_cell)
			if color == null:
				var tile := map_cell * Exploration.CELL + Vector2i(2, 2)
				color = TerrainTiles.COLORS[generator.tile_type_at(tile)].lightened(0.12)
				_colors[map_cell] = color
			_image.set_pixel(x, y, color)
	if _texture == null or _texture.get_size() != Vector2(cells):
		_texture = ImageTexture.create_from_image(_image)
	else:
		_texture.update(_image)


## Finds villages and structures in view that the player has seen.
func _collect_icons(origin: Vector2i, cells: Vector2i, offset: Vector2, scale: float) -> void:
	_icons.clear()
	var to_view := func(tile: Vector2i) -> Vector2:
		return (Vector2(tile) / Exploration.CELL - Vector2(origin)) * scale + offset
	var first_tile := origin * Exploration.CELL
	var last_tile := (origin + cells) * Exploration.CELL
	var structures: Structures = player.get_parent().get_node("Structures")
	var generator := _world.generator
	# Only look for structures when zoomed in enough to see them apart.
	if scale >= 2.0:
		var first_chunk := Vector2i((Vector2(first_tile) / World.CHUNK_SIZE).floor())
		var last_chunk := Vector2i((Vector2(last_tile) / World.CHUNK_SIZE).ceil())
		for cy in range(first_chunk.y, last_chunk.y + 1):
			for cx in range(first_chunk.x, last_chunk.x + 1):
				var site := structures.site_for(Vector2i(cx, cy))
				if not site.is_empty() and site["kind"] != "altar" and _exploration.is_tile_seen(site["cell"]):
					_icons.append([to_view.call(site["cell"]), site["kind"]])
	var first_region := Vector2i((Vector2(first_tile) / WorldGenerator.VILLAGE_REGION).floor())
	var last_region := Vector2i((Vector2(last_tile) / WorldGenerator.VILLAGE_REGION).ceil())
	for ry in range(first_region.y, last_region.y + 1):
		for rx in range(first_region.x, last_region.x + 1):
			var center: Variant = generator.village_center(Vector2i(rx, ry))
			if center != null and _exploration.is_tile_seen(center):
				_icons.append([to_view.call(center), "village"])
	if _exploration.is_tile_seen(Vector2i.ZERO):
		_icons.append([to_view.call(Vector2i.ZERO), "temple"])
	# The Altar of Magic is known by rumour from the start.
	_icons.append([to_view.call(generator.magic_altar_cell()), "altar"])
	var hunts: TreasureMaps = player.get_parent().get_node_or_null("TreasureMaps")
	if hunts:
		for spot: Dictionary in hunts.spots:
			_icons.append([to_view.call(hunts.cell_of(spot)), "treasure"])
	var stones: Waystones = player.get_parent().get_node_or_null("Waystones")
	if stones:
		for key: String in stones.known:
			if not key.begins_with("waystone:"):
				continue
			_icons.append([to_view.call(stones.cell_of(key)), "waystone"])
	var bounties: Bounties = player.get_parent().get_node_or_null("Bounties")
	if bounties:
		for bounty: Dictionary in bounties.active:
			_icons.append([to_view.call(bounties.cell_of(bounty)), "bounty"])
	var buildings: Buildings = player.get_parent().get_node("Buildings")
	if not buildings.home.is_empty():
		_icons.append([to_view.call(_world.world_to_cell(Vector2(buildings.home["position"][0], buildings.home["position"][1]))), "home"])


func _draw_icon(at: Vector2, kind: String) -> void:
	# A dark pad under each picture keeps it clear of the land's colours.
	var size := 24.0 if kind in ["village", "temple", "boss", "home"] else 20.0
	_view.draw_circle(at + Vector2(0, 1), size * 0.5, Color(0, 0, 0, 0.45))
	MapIcons.draw(_view, at, kind, size)
