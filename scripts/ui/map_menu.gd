class_name MapMenu
extends GameMenu
## The world map. A heading row names the land you stand in and the zoom;
## the map itself (drag to move, scroll to zoom, click a marker to see what
## it is, right-click to set a waypoint) has a compass and fog over what is
## unexplored; beside it, a legend whose groups can be hidden, and the
## chosen marker or spot with its distance and direction. Only places the
## player has seen are shown.

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

## Marker kinds by group, for the legend and its filters.
const GROUPS := [
	["places", "Settlements", ["village", "temple", "home", "farmstead"]],
	["travel", "Travel", ["waystone", "portal", "checkpoint"]],
	["danger", "Danger", ["lair", "boss", "bounty", "dungeon", "graveyard"]],
	["treasure", "Treasure and trade", ["treasure", "shipwreck", "merchant", "altar"]],
	["sights", "Ruins and sights", ["ruin", "shrine", "cave", "camp", "obelisk", "watchtower", "henge", "library"]],
	["life", "Creatures and people", ["monster", "animal", "npc", "pet"]],
]
const VIEW := Vector2(870.0, 492.0)
const SIDE := 290.0

## Legend groups the player has hidden.
static var hidden_groups: Dictionary = {}
## The player's waypoint in world pixels, or null: shown here and on the minimap.
static var waypoint: Variant = null

var _view: Control
var _hover: Label
var _minimap: CheckBox
var _region: Label
var _zoom_label: Label
var _pick_name: Label
var _pick_text: Label
var _pick_distance: Label
var _waypoint_button: Button
## What was clicked: {"tile": Vector2i, "name": String, "kind": String}.
var _picked: Dictionary = {}
var _press_at := Vector2.ZERO
var _moved := false
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
## A place another screen asked to see: [tile, name], drawn ringed.
var _marker: Array = []

## Waiting for the map's next opening: [world position, name], or empty.
static var _focus: Array = []


## Asks the map to open on a place, marked with its name (the Magic screen
## uses this for the Altar of Magic).
static func focus_on(world_position: Vector2, place: String) -> void:
	_focus = [world_position, place]


func _build() -> void:
	# The waypoint and the legend's filters belong to this world.
	waypoint = null
	hidden_groups = {}
	SaveGame.register("map", self)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	content.add_child(head)
	head.add_child(UITheme.heading("MAP", 30))
	_region = UITheme.label("", 16, UITheme.TEXT)
	_region.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_region.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_region)
	head.add_child(_small_button("-", func() -> void: _zoom_by(-1)))
	_zoom_label = UITheme.strong("", 15, UITheme.TEXT)
	_zoom_label.custom_minimum_size.x = 84.0
	_zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zoom_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_zoom_label)
	head.add_child(_small_button("+", func() -> void: _zoom_by(1)))
	head.add_child(UITheme.button("Find me", func() -> void:
		_center_on_player()
		_dirty = true
		_view.queue_redraw()
	, 110.0))
	_minimap = CheckBox.new()
	_minimap.text = "Minimap"
	_minimap.toggled.connect(func(on: bool) -> void: GameSettings.set_value("show_minimap", on))
	head.add_child(_minimap)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	content.add_child(row)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 4)
	row.add_child(left)
	_view = Control.new()
	_view.custom_minimum_size = VIEW
	_view.clip_contents = true
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.gui_input.connect(_on_view_input)
	_view.draw.connect(_draw_view)
	left.add_child(_view)
	_hover = UITheme.label("", 15)
	_hover.custom_minimum_size.x = VIEW.x
	_hover.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_hover.clip_text = true
	left.add_child(_hover)

	var side := PanelContainer.new()
	side.add_theme_stylebox_override("panel", UITheme.card("card", 12))
	side.custom_minimum_size.x = SIDE
	row.add_child(side)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	side.add_child(box)
	box.add_child(UITheme.label("Legend", 16, UITheme.HEADING))
	for group: Array in GROUPS:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 4)
		box.add_child(line)
		var check := CheckBox.new()
		check.text = group[1]
		check.button_pressed = not hidden_groups.has(group[0])
		check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		check.tooltip_text = "Show or hide: " + ", ".join((group[2] as Array).map(func(kind: String) -> String: return str(ICONS[kind][1]) if ICONS.has(kind) else kind.capitalize()))
		check.toggled.connect(func(on: bool) -> void:
			if on:
				hidden_groups.erase(group[0])
			else:
				hidden_groups[group[0]] = true
			SaveGame.request_save()
			_view.queue_redraw()
		)
		line.add_child(check)
		var icons := Control.new()
		icons.custom_minimum_size = Vector2(76, 24)
		icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icons.draw.connect(func() -> void:
			for index in mini(4, group[2].size()):
				MapIcons.draw(icons, Vector2(10 + index * 19, 12), group[2][index], 17.0)
		)
		line.add_child(icons)
	var fog := HBoxContainer.new()
	fog.add_theme_constant_override("separation", 8)
	box.add_child(fog)
	var swatch := ColorRect.new()
	swatch.color = Color(0.08, 0.085, 0.1)
	swatch.custom_minimum_size = Vector2(22, 16)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fog.add_child(swatch)
	fog.add_child(UITheme.label("Unexplored: walk there to reveal it", 14, UITheme.DIM))
	box.add_child(UITheme.rule())
	box.add_child(UITheme.label("Selected", 16, UITheme.HEADING))
	_pick_name = UITheme.strong("", 17, UITheme.GOLD)
	_pick_name.autowrap_mode = TextServer.AUTOWRAP_WORD
	_pick_name.custom_minimum_size.x = SIDE - 24.0
	box.add_child(_pick_name)
	_pick_text = UITheme.paragraph("", SIDE - 24.0, 14, UITheme.DIM)
	box.add_child(_pick_text)
	_pick_distance = UITheme.label("", 15, UITheme.TEXT)
	box.add_child(_pick_distance)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(fill)
	_waypoint_button = UITheme.primary_button("Set waypoint", _toggle_waypoint, SIDE - 24.0)
	box.add_child(_waypoint_button)
	box.add_child(UITheme.label("Click: select   Right-click: waypoint", 14, UITheme.DIM))
	box.add_child(UITheme.label("Drag: move   Scroll: zoom", 14, UITheme.DIM))


func refresh() -> void:
	if _world == null:
		_world = player.get_parent().get_node("World")
		_exploration = player.get_parent().get_node("Exploration")
	_minimap.set_pressed_no_signal(GameSettings.show_minimap)
	_center_on_player()
	_marker = []
	_picked = {}
	if not _focus.is_empty():
		var tile := _world.world_to_cell(_focus[0])
		_marker = [tile, _focus[1]]
		_center = Vector2(tile) / Exploration.CELL
		_picked = {"tile": tile, "name": _focus[1], "kind": ""}
		_focus = []
	elif waypoint != null:
		_picked = {"tile": _world.world_to_cell(waypoint), "name": "Your waypoint", "kind": ""}
	var here := _player_tile()
	_region.text = "%s  ·  area level %d" % [TerrainTiles.display_name(_world.generator.tile_type_at(here)), _world.generator.enemy_level_at(here)]
	_show_picked()
	_dirty = true
	_view.queue_redraw()


func _player_tile() -> Vector2i:
	return _world.world_to_cell(player.global_position if not player.indoors else player.get_parent().get_node("Instances").return_position())


func _zoom_by(step: int) -> void:
	_zoom_index = clampi(_zoom_index + step, 0, ZOOMS.size() - 1)
	_dirty = true
	_view.queue_redraw()


static func _small_button(text: String, action: Callable) -> Button:
	var button := UITheme.button(text, action, 34.0)
	button.custom_minimum_size = Vector2(34, 34)
	return button


## Fills the Selected part of the side panel.
func _show_picked() -> void:
	_zoom_label.text = "Zoom %d / %d" % [_zoom_index + 1, ZOOMS.size()]
	if _picked.is_empty():
		_pick_name.text = "Nothing selected"
		_pick_text.text = "Click a marker or a spot on the map to see what it is and how far."
		_pick_distance.text = ""
		_waypoint_button.text = "Clear waypoint" if waypoint != null else "Set waypoint"
		_waypoint_button.disabled = waypoint == null
		return
	var tile: Vector2i = _picked["tile"]
	_pick_name.text = _picked["name"]
	var seen := _exploration.is_tile_seen(tile)
	_pick_text.text = "%s, area level %d  ·  %d, %d" % [TerrainTiles.display_name(_world.generator.tile_type_at(tile)), _world.generator.enemy_level_at(tile), tile.x, tile.y] if seen else "Not explored yet."
	var offset := Vector2(tile - _player_tile())
	var tiles := roundi(offset.length())
	_pick_distance.text = "You are here." if tiles < 2 else "%s tiles to the %s" % [InventoryMenu._thousands(tiles), MagicMenu._compass(offset)]
	if _picked.get("kind", "") in ["village", "merchant"]:
		_pick_text.text += "\nMerchants bring new wares in %d min." % ceili(Npc.restock_in() / 60.0)
	var on_it := waypoint != null and _world.world_to_cell(waypoint) == tile
	_waypoint_button.text = "Clear waypoint" if on_it else "Set waypoint here"
	_waypoint_button.disabled = false


func _toggle_waypoint() -> void:
	if _picked.is_empty() or (waypoint != null and _world.world_to_cell(waypoint) == _picked["tile"]):
		waypoint = null
	else:
		waypoint = _world.cell_to_world(_picked["tile"])
	SaveGame.request_save()
	_show_picked()
	_view.queue_redraw()


func _center_on_player() -> void:
	var tile := _world.world_to_cell(player.global_position if not player.indoors else player.get_parent().get_node("Instances").return_position())
	_center = Vector2(tile) / Exploration.CELL


func _scale() -> float:
	return ZOOMS[_zoom_index]


func _on_view_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_dragging = true
				_moved = false
				_press_at = event.position
			else:
				_dragging = false
				if not _moved:
					_select_at(event.position)
		elif event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			_select_at(event.position)
			_toggle_waypoint()
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			# Zoom about the point under the mouse.
			var before := _map_at(event.position)
			_zoom_index = clampi(_zoom_index + (1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1), 0, ZOOMS.size() - 1)
			_center += before - _map_at(event.position)
			_zoom_label.text = "Zoom %d / %d" % [_zoom_index + 1, ZOOMS.size()]
			_dirty = true
			_view.queue_redraw()
	elif event is InputEventMouseMotion:
		if _dragging and (_moved or event.position.distance_to(_press_at) > 4.0):
			_moved = true
			_center -= event.relative / _scale()
			_dirty = true
			_view.queue_redraw()
		_describe(event.position)


func save_data() -> Dictionary:
	return {"waypoint": [waypoint.x, waypoint.y] if waypoint != null else [], "hidden": hidden_groups.keys()}


func load_data(data: Dictionary) -> void:
	var spot: Variant = data.get("waypoint", [])
	waypoint = Vector2(float(spot[0]), float(spot[1])) if spot is Array and spot.size() == 2 else null
	hidden_groups = {}
	var hidden: Variant = data.get("hidden", [])
	if hidden is Array:
		for group: Variant in hidden:
			hidden_groups[str(group)] = true


## Picks the marker under a point, or else the spot itself.
func _select_at(point: Vector2) -> void:
	var best: Array = []
	var best_distance := 14.0
	for icon: Array in _icons:
		var distance := (icon[0] as Vector2).distance_to(point)
		if distance < best_distance:
			best_distance = distance
			best = icon
	if not best.is_empty():
		_picked = {"tile": best[2], "name": ICONS[best[1]][1], "kind": best[1]}
	else:
		var tile := Vector2i((_map_at(point) * Exploration.CELL).floor())
		_picked = {"tile": tile, "name": TerrainTiles.display_name(_world.generator.tile_type_at(tile)) if _exploration.is_tile_seen(tile) else "Unexplored", "kind": ""}
	_show_picked()
	_view.queue_redraw()


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
	if not player.indoors and not hidden_groups.has("life"):
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
	var tile_to_view := func(spot_tile: Vector2i) -> Vector2:
		return (Vector2(spot_tile) / Exploration.CELL - _center) * scale + _view.size / 2.0
	# The waypoint: a dashed line from you, a flag and how far.
	if waypoint != null:
		var flag: Vector2 = tile_to_view.call(_world.world_to_cell(waypoint))
		var line := flag - at
		var dashes := int(line.length() / 12.0)
		for index in dashes:
			if index % 2 == 0:
				_view.draw_line(at + line * (float(index) / dashes), at + line * (float(index + 1) / dashes), Color(UITheme.GOLD, 0.8), 2.0)
		_view.draw_colored_polygon(PackedVector2Array([flag + Vector2(0, -10), flag + Vector2(8, 0), flag + Vector2(0, 10), flag + Vector2(-8, 0)]), Color(0, 0, 0, 0.7))
		_view.draw_colored_polygon(PackedVector2Array([flag + Vector2(0, -7), flag + Vector2(5.5, 0), flag + Vector2(0, 7), flag + Vector2(-5.5, 0)]), UITheme.GOLD)
	# What is selected: a white ring.
	if not _picked.is_empty():
		var ring: Vector2 = tile_to_view.call(_picked["tile"])
		_view.draw_arc(ring, 15.0, 0.0, TAU, 28, Color(0, 0, 0, 0.6), 4.0)
		_view.draw_arc(ring, 15.0, 0.0, TAU, 28, Color.WHITE, 2.0)
	MapIcons.draw_player(_view, at, player.facing, 22.0)
	_draw_compass(Vector2(_view.size.x - 36.0, 46.0))
	if not _marker.is_empty():
		var spot := (Vector2(_marker[0]) / Exploration.CELL - _center) * scale + _view.size / 2.0
		_view.draw_arc(spot, 20.0, 0.0, TAU, 32, Color(0, 0, 0, 0.6), 5.0)
		_view.draw_arc(spot, 20.0, 0.0, TAU, 32, UITheme.GOLD, 2.5)
		var font := UITheme.body_bold()
		var words: String = _marker[1]
		var width := font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		_view.draw_rect(Rect2(spot + Vector2(-width / 2.0 - 6.0, -50.0), Vector2(width + 12.0, 24.0)), Color(0.04, 0.05, 0.08, 0.85))
		_view.draw_string(font, spot + Vector2(-width / 2.0, -32.0), words, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UITheme.GOLD)
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
					_add_icon(to_view, site["cell"], site["kind"])
	var first_region := Vector2i((Vector2(first_tile) / WorldGenerator.VILLAGE_REGION).floor())
	var last_region := Vector2i((Vector2(last_tile) / WorldGenerator.VILLAGE_REGION).ceil())
	for ry in range(first_region.y, last_region.y + 1):
		for rx in range(first_region.x, last_region.x + 1):
			var center: Variant = generator.village_center(Vector2i(rx, ry))
			if center != null and _exploration.is_tile_seen(center):
				_add_icon(to_view, center, "village")
	if _exploration.is_tile_seen(Vector2i.ZERO):
		_add_icon(to_view, Vector2i.ZERO, "temple")
	# The Altar of Magic is known by rumour from the start.
	_add_icon(to_view, generator.magic_altar_cell(), "altar")
	var hunts: TreasureMaps = player.get_parent().get_node_or_null("TreasureMaps")
	if hunts:
		for spot: Dictionary in hunts.spots:
			_add_icon(to_view, hunts.cell_of(spot), "treasure")
	var stones: Waystones = player.get_parent().get_node_or_null("Waystones")
	if stones:
		for key: String in stones.known:
			if not key.begins_with("waystone:"):
				continue
			_add_icon(to_view, stones.cell_of(key), "waystone")
	var bounties: Bounties = player.get_parent().get_node_or_null("Bounties")
	if bounties:
		for bounty: Dictionary in bounties.active:
			_add_icon(to_view, bounties.cell_of(bounty), "bounty")
	var buildings: Buildings = player.get_parent().get_node("Buildings")
	if not buildings.home.is_empty():
		_add_icon(to_view, _world.world_to_cell(Vector2(buildings.home["position"][0], buildings.home["position"][1])), "home")


## A small compass rose: north is up.
func _draw_compass(middle: Vector2) -> void:
	_view.draw_circle(middle, 22.0, Color(0.03, 0.04, 0.07, 0.8))
	_view.draw_arc(middle, 22.0, 0.0, TAU, 32, Color("8a683a"), 1.5)
	_view.draw_colored_polygon(PackedVector2Array([middle + Vector2(0, -16), middle + Vector2(5, 0), middle + Vector2(-5, 0)]), UITheme.BAD)
	_view.draw_colored_polygon(PackedVector2Array([middle + Vector2(0, 16), middle + Vector2(5, 0), middle + Vector2(-5, 0)]), Color(0.8, 0.8, 0.85))
	var font := UITheme.body_bold()
	_view.draw_string_outline(font, middle + Vector2(-5, -24), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color.BLACK)
	_view.draw_string(font, middle + Vector2(-5, -24), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UITheme.GOLD)


## Keeps a marker for drawing and clicking, unless its group is hidden.
func _add_icon(to_view: Callable, tile: Vector2i, kind: String) -> void:
	if hidden_groups.has(group_of(kind)):
		return
	_icons.append([to_view.call(tile), kind, tile])


static func group_of(kind: String) -> String:
	for group: Array in GROUPS:
		if kind in group[2]:
			return group[0]
	return "sights"


func _draw_icon(at: Vector2, kind: String) -> void:
	# A dark pad under each picture keeps it clear of the land's colours.
	var size := 24.0 if kind in ["village", "temple", "boss", "home"] else 20.0
	_view.draw_circle(at + Vector2(0, 1), size * 0.5, Color(0, 0, 0, 0.45))
	MapIcons.draw(_view, at, kind, size)
	# Where merchants trade, a small tag: minutes until new wares.
	if kind in ["village", "merchant"] and _scale() >= 3.0:
		var words := "%dm" % ceili(Npc.restock_in() / 60.0)
		var font := UITheme.body_bold()
		var spot := at + Vector2(size * 0.45, size * 0.55)
		_view.draw_rect(Rect2(spot + Vector2(-2, -12), Vector2(font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 4, 15)), Color(0.04, 0.05, 0.08, 0.85))
		_view.draw_string(font, spot, words, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UITheme.GOLD)
