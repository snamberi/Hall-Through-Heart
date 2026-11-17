class_name OverlayHUD
extends CanvasLayer
## Things drawn over the game screen at its own pixel size, apart from the
## HUD panels:
##   - arrows at the screen's edge toward the waypoint, a tracked pin, where
##     you last fell, active bounties and treasure (each with how far);
##   - a card of what a monster is when the mouse rests on it: level, rank,
##     health, faction and what it expects, weaknesses, wards and traits;
##   - an optional damage-per-second meter over the last few seconds.

## How far in from each edge the arrows sit: clear of the bars at the top
## and the hotbar at the bottom.
const EDGE := 40.0
const EDGE_TOP := 132.0
const EDGE_BOTTOM := 122.0
## Seconds of hits the damage meter averages over.
const WINDOW := 5.0

var _player: Player
var _canvas: Control
## [time, amount] of each blow dealt lately.
var _hits: Array = []
var _peak := 0.0
## The monster the mouse rests on (kept a moment after it moves off).
var _hovered: Variant = null


func setup(player: Player) -> void:
	_player = player
	layer = 4
	_canvas = Control.new()
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_all)
	add_child(_canvas)
	Events.damage_dealt.connect(_on_damage)


func _on_damage(_kind: String, amount: float) -> void:
	_hits.append([Time.get_ticks_msec() / 1000.0, amount])


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	while not _hits.is_empty() and now - float(_hits[0][0]) > WINDOW:
		_hits.pop_front()
	# Forget where the player fell once they have been back there.
	if MapMenu.last_death != null and not _player.indoors and _player.global_position.distance_to(MapMenu.last_death) < 90.0:
		MapMenu.last_death = null
	_hovered = _monster_under_mouse()
	_canvas.queue_redraw()


func _menus_open() -> bool:
	var menus: Node = _player.get_parent().get_node_or_null("Menus")
	return menus != null and menus.is_open()


func _draw_all() -> void:
	if _player == null or _player.is_dead() or _menus_open():
		return
	if GameSettings.quest_arrows and not _player.indoors:
		for target: Array in _targets():
			_draw_arrow(target[0], target[1], target[2])
	if GameSettings.enemy_info and _hovered != null and is_instance_valid(_hovered):
		_draw_enemy_card(_hovered)
	if GameSettings.dps_meter:
		_draw_meter()


## Where the arrows point: [world position, colour, label].
func _targets() -> Array:
	var out: Array = []
	var world: Node = _player.get_parent()
	if MapMenu.waypoint != null:
		out.append([MapMenu.waypoint, UITheme.GOLD, "Waypoint"])
	var pinned := MapMenu.tracked_pin()
	if pinned >= 0:
		var pin: Dictionary = MapMenu.pins[pinned]
		var spot := (Vector2(float(pin["tile"][0]), float(pin["tile"][1])) + Vector2(0.5, 0.5)) * TerrainTiles.TILE_SIZE
		out.append([spot, MapMenu.PIN_STYLES[int(pin["style"])][1], str(pin["name"])])
	if MapMenu.last_death != null:
		out.append([MapMenu.last_death, Color("ece4d2"), "Where you fell"])
	var bounties: Node = world.get_node_or_null("Bounties")
	if bounties:
		for bounty: Dictionary in bounties.active:
			out.append([(Vector2(bounties.cell_of(bounty)) + Vector2(0.5, 0.5)) * TerrainTiles.TILE_SIZE, Color("e0524a"), str(bounty.get("name", "Bounty"))])
	var hunts: Node = world.get_node_or_null("TreasureMaps")
	if hunts:
		for spot: Dictionary in hunts.spots:
			out.append([(Vector2(hunts.cell_of(spot)) + Vector2(0.5, 0.5)) * TerrainTiles.TILE_SIZE, Color("e8b85a"), "Treasure"])
	return out


## An arrow at the edge of the screen pointing toward a place off it, with
## its name and distance; nothing when the place is in view.
func _draw_arrow(target: Vector2, color: Color, label: String) -> void:
	var view := _canvas.size
	var screen := _player.get_viewport().get_canvas_transform() * target
	var inner := Rect2(Vector2(EDGE, EDGE_TOP), view - Vector2(EDGE * 2.0, EDGE_TOP + EDGE_BOTTOM))
	if inner.has_point(screen):
		return
	var middle := inner.get_center()
	var way := screen - middle
	if way.length() < 1.0:
		return
	var reach := minf(absf((inner.size.x / 2.0) / way.x) if way.x != 0.0 else INF, absf((inner.size.y / 2.0) / way.y) if way.y != 0.0 else INF)
	var at := (middle + way * reach).round()
	var dir := way.normalized()
	var side := dir.orthogonal()
	# A chevron with a dark edge, bobbing a little toward where it points.
	var bob := dir * (2.0 + 2.0 * sin(Time.get_ticks_msec() / 220.0))
	var tip := at + dir * 12.0 + bob
	var shape := PackedVector2Array([tip, at - dir * 4.0 + side * 10.0 + bob, at + dir * 1.0 + bob, at - dir * 4.0 - side * 10.0 + bob])
	var outline := PackedVector2Array([tip + dir * 3.0, at - dir * 6.0 + side * 13.0 + bob, at + dir * 0.0 + bob, at - dir * 6.0 - side * 13.0 + bob])
	_canvas.draw_colored_polygon(outline, Color(0.02, 0.02, 0.05, 0.85))
	_canvas.draw_colored_polygon(shape, color)
	var tiles := roundi(_player.global_position.distance_to(target) / TerrainTiles.TILE_SIZE)
	var font := UITheme.body_bold()
	var words := "%s  %d" % [label, tiles]
	var width := font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	var text_at := at - dir * 26.0 - Vector2(width / 2.0, -4.0)
	text_at.x = clampf(text_at.x, 6.0, view.x - width - 6.0)
	text_at.y = clampf(text_at.y, 16.0, view.y - 6.0)
	_canvas.draw_string_outline(font, text_at, words, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0, 0, 0, 0.9))
	_canvas.draw_string(font, text_at, words, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color)


func _monster_under_mouse() -> Variant:
	if not GameSettings.enemy_info or _player.is_dead():
		return null
	var mouse := _player.get_global_mouse_position()
	var best: Variant = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.state == Enemy.State.DEAD:
			continue
		var body := enemy.global_position + Vector2(0, -enemy.body_radius)
		var distance := body.distance_to(mouse)
		if distance < enemy.body_radius + 12.0 and distance < best_distance:
			best_distance = distance
			best = enemy
	return best


## The card for a monster under the mouse.
func _draw_enemy_card(enemy: Enemy) -> void:
	var lines: Array = []
	var rank_title: String = Enemy.RANK_DATA[enemy.rank]["title"]
	lines.append([("Lv %d %s%s" % [enemy.level, rank_title, enemy.display_name]).strip_edges(), UITheme.HEADING, 16])
	lines.append(["Health %s / %s" % [InventoryMenu._thousands(roundi(enemy.health.current)), InventoryMenu._thousands(roundi(enemy.health.max_health))], UITheme.TEXT, 14])
	if enemy.shield > 0.0:
		lines.append(["Ward %d" % roundi(enemy.shield), Color(0.6, 0.85, 1.0), 14])
	if enemy.faction != "":
		var data: Dictionary = Factions.LIST[enemy.faction]
		var expects := "  ·  expects %s" % Factions.BELIEF[enemy.expected] if enemy.expected != "" else ""
		lines.append([str(data["name"]) + expects, data["color"], 14])
	var weak: PackedStringArray = []
	var hardy: PackedStringArray = []
	for element: String in Elements.LIST:
		var factor := Elements.multiplier(enemy.enemy_id, element)
		if factor > 1.0:
			weak.append(element.capitalize())
		elif factor < 1.0:
			hardy.append(element.capitalize())
	for ward: String in enemy.wards:
		if float(enemy.wards[ward]) > 0.0:
			hardy.append("%s (warded)" % ward.capitalize())
	if not weak.is_empty():
		lines.append(["Weak to " + ", ".join(weak), UITheme.GOOD, 14])
	if not hardy.is_empty():
		lines.append(["Resists " + ", ".join(hardy), Color(0.9, 0.7, 0.45), 14])
	var traits: PackedStringArray = []
	for id: String in enemy._traits:
		if EnemyDB.TRAITS.has(id) and not id.capitalize() in traits:
			traits.append(id.capitalize())
	if not traits.is_empty():
		lines.append([", ".join(traits), UITheme.DIM, 13])
	var font := UITheme.body_bold()
	var width := 0.0
	for line: Array in lines:
		width = maxf(width, font.get_string_size(line[0], HORIZONTAL_ALIGNMENT_LEFT, -1, line[2]).x)
	var height := 10.0 + lines.size() * 19.0
	var mouse := _canvas.get_local_mouse_position()
	var box := Rect2(mouse + Vector2(18, 14), Vector2(width + 20.0, height))
	box.position.x = minf(box.position.x, _canvas.size.x - box.size.x - 6.0)
	box.position.y = minf(box.position.y, _canvas.size.y - box.size.y - 6.0)
	_canvas.draw_style_box(UITheme.tooltip_box(), box)
	var y := box.position.y + 20.0
	for line: Array in lines:
		_canvas.draw_string(font, Vector2(box.position.x + 10.0, y), line[0], HORIZONTAL_ALIGNMENT_LEFT, -1, line[2], line[1])
		y += 19.0


## Damage per second over the last few seconds, and the best yet.
func _draw_meter() -> void:
	if _hits.is_empty():
		return
	var total := 0.0
	for hit: Array in _hits:
		total += float(hit[1])
	var span := clampf(Time.get_ticks_msec() / 1000.0 - float(_hits[0][0]), 1.0, WINDOW)
	var dps := total / span
	_peak = maxf(_peak, dps)
	var font := UITheme.body_bold()
	var words := "DPS %s   best %s" % [InventoryMenu._thousands(roundi(dps)), InventoryMenu._thousands(roundi(_peak))]
	var width := font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	var box := Rect2(Vector2(_canvas.size.x - width - 34.0, _canvas.size.y - 150.0), Vector2(width + 20.0, 28.0))
	_canvas.draw_style_box(UITheme.tooltip_box(), box)
	_canvas.draw_string(font, box.position + Vector2(10, 19), words, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UITheme.GOLD)
