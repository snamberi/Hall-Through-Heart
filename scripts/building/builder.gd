class_name Builder
extends Node2D
## Placement mode: the item is held in the player's hand and a glowing
## blueprint of it follows the mouse, blue where it can go and red where it
## cannot. Left-click sets it down (and keeps going while more are in the
## bag; hold the button to lay a run of walls or ground); T mirrors it;
## right-click or Esc puts it away.

const BLUEPRINT := """
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(0.35, 0.75, 1.0, 1.0);
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 px = TEXTURE_PIXEL_SIZE;
	float around = texture(TEXTURE, UV + vec2(px.x, 0.0)).a + texture(TEXTURE, UV - vec2(px.x, 0.0)).a
		+ texture(TEXTURE, UV + vec2(0.0, px.y)).a + texture(TEXTURE, UV - vec2(0.0, px.y)).a;
	float edge = (c.a > 0.5 && around < 3.5) ? 1.0 : 0.0;
	float shade = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	float scan = 0.5 + 0.5 * sin(FRAGCOORD.y * 0.9 - TIME * 7.0);
	float sweep = smoothstep(0.0, 0.08, 0.08 - abs(fract(UV.y * 2.0 - TIME * 0.5) - 0.5));
	vec3 body = tint.rgb * (0.35 + shade * 0.7) + sweep * 0.25;
	COLOR.rgb = mix(body, vec3(0.9, 0.98, 1.0) * tint.rgb + 0.3, edge);
	COLOR.a = c.a * (0.42 + 0.12 * scan) + edge * 0.45;
}
"""

var _buildings: Buildings
var _player: Player
var _item: Item
var _item_id := ""
var _kind := ""
var _ghost: Sprite2D
var _problem := ""
var _material: ShaderMaterial
var _flip := false
## While the button is held over walls or ground, each new tile is laid.
var _painting := false


func setup(buildings: Buildings, player: Player) -> void:
	_buildings = buildings
	_player = player
	z_index = 80
	add_to_group("builder")
	Events.placement_requested.connect(begin)
	_material = ShaderMaterial.new()
	_material.shader = Shader.new()
	_material.shader.code = BLUEPRINT
	_ghost = Sprite2D.new()
	_ghost.texture = Prop.SHEET
	_ghost.hframes = Prop.FRAMES
	_ghost.material = _material
	_ghost.visible = false
	add_child(_ghost)


func is_active() -> bool:
	return _item != null


## The id of what is in hand while placing.
func held_id() -> String:
	return _item_id if _item != null else ""


func begin(item: Item) -> void:
	_item = item
	_item_id = item.id
	_kind = item.definition()["place"]
	var kind: Dictionary = Buildings.KINDS[_kind]
	_ghost.texture = Prop.DECOR if kind.has("decor") else Prop.SHEET
	_ghost.hframes = Prop.DECOR_FRAMES if kind.has("decor") else Prop.FRAMES
	_ghost.frame = kind.get("decor", kind.get("art", 0))
	_ghost.scale = Vector2(2.0, 2.0) if _kind == "house" else Vector2.ONE
	_ghost.visible = not _kind in ["floor", "ground", "wall"]
	_ghost.flip_h = _flip
	_player.placing = true


func cancel() -> void:
	_item = null
	_ghost.visible = false
	_player.placing = false
	queue_redraw()


func _process(_delta: float) -> void:
	if _item == null:
		return
	if _player.is_dead() or not _item in _player.inventory.items:
		cancel()
		return
	var at := _snapped(get_global_mouse_position())
	_problem = _buildings.placement_problem(_kind, at)
	# Dragging lays a run of walls or ground, one tile at a time.
	if _painting and _kind in ["ground", "wall"]:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_painting = false
		elif _problem == "":
			confirm(at)
			if _item == null:
				return
	_ghost.global_position = at + Vector2(0, -50.0 if _kind == "house" else -22.0)
	_material.set_shader_parameter("tint", Color(0.4, 0.8, 1.0) if _problem == "" else Color(1.0, 0.35, 0.3))
	queue_redraw()


func _draw() -> void:
	if _item == null:
		return
	var at := to_local(_snapped(get_global_mouse_position()))
	var tile := float(TerrainTiles.TILE_SIZE)
	var half := tile * (1.5 if _kind == "house" else 0.5)
	var color := Color(0.45, 0.85, 1.0) if _problem == "" else UITheme.BAD
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 180.0)
	# A faint grid of the tiles around the cursor.
	for gx in range(-3, 4):
		for gy in range(-3, 4):
			var cell := Rect2(at + Vector2(gx, gy) * tile - Vector2(tile, tile) / 2.0, Vector2(tile, tile))
			var fade := 1.0 - Vector2(gx, gy).length() / 4.2
			if fade > 0.0:
				draw_rect(cell, Color(color, 0.12 * fade), false, 1.0)
	# The footprint with its own grid, and corner brackets.
	var rect := Rect2(at - Vector2(half, half), Vector2(half, half) * 2.0)
	draw_rect(rect, Color(color, 0.12 + 0.06 * pulse))
	var steps := int(round(half * 2.0 / tile))
	for line in range(1, steps):
		draw_line(rect.position + Vector2(line * tile, 0), rect.position + Vector2(line * tile, rect.size.y), Color(color, 0.35), 1.0)
		draw_line(rect.position + Vector2(0, line * tile), rect.position + Vector2(rect.size.x, line * tile), Color(color, 0.35), 1.0)
	var arm := minf(12.0, half)
	for corner: Vector2 in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		var sx := 1.0 if corner.x == rect.position.x else -1.0
		var sy := 1.0 if corner.y == rect.position.y else -1.0
		draw_line(corner, corner + Vector2(arm * sx, 0), color, 2.0)
		draw_line(corner, corner + Vector2(0, arm * sy), color, 2.0)
	if _kind in ["floor", "ground"]:
		var tile_type: int = _item.definition()["floor" if _kind == "floor" else "ground"]
		draw_rect(rect.grow(-3.0), Color(TerrainTiles.COLORS[tile_type], 0.55))
	elif _kind == "wall":
		var look: Dictionary = StoneWall.STYLES.get(str(_item.definition()["wall"]), StoneWall.STYLES["wood"])
		var height: float = look["height"]
		draw_rect(Rect2(at.x - tile / 2.0, at.y + StoneWall.THICK / 2.0 - height, tile, height), Color(look["face"], 0.7))
		draw_rect(Rect2(at.x - tile / 2.0, at.y + StoneWall.THICK / 2.0 - height - 4.0, tile, 4.0), Color(look["top"], 0.8))
	# The item held in the hand.
	var hand := to_local(_player.global_position + Vector2(9.0 * signf(_player.aim_direction().x if _player.aim_direction().x != 0.0 else 1.0), -18.0 + 2.0 * sin(Time.get_ticks_msec() / 220.0)))
	draw_texture_rect(_item.icon(), Rect2(hand - Vector2(9, 9), Vector2(18, 18)), false)
	var left := _player.inventory.count_of(_item_id)
	var how := "hold and drag to lay a run" if _kind in ["ground", "wall"] else "T to mirror"
	var text := "Left-click to place (%d left)  -  %s  -  right-click to put away" % [left, how] if _problem == "" else _problem
	var font := UITheme.get_theme().default_font
	draw_string_outline(font, at + Vector2(-170, half + 22.0), text, HORIZONTAL_ALIGNMENT_CENTER, 340.0, 13, 4, Color.BLACK)
	draw_string(font, at + Vector2(-170, half + 22.0), text, HORIZONTAL_ALIGNMENT_CENTER, 340.0, 13, color)


func _unhandled_input(event: InputEvent) -> void:
	if _item == null:
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
		cancel()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		confirm(_snapped(get_global_mouse_position()))
		_painting = _kind in ["ground", "wall"]
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_T:
		_flip = not _flip
		_ghost.flip_h = _flip
		get_viewport().set_input_as_handled()


## Places the item at a position if it is allowed there. Returns whether it
## was. With more of the same item in the bag, it stays in hand.
func confirm(at: Vector2) -> bool:
	if _item == null or _buildings.placement_problem(_kind, at) != "":
		return false
	_player.inventory.take(_item_id, 1)
	_buildings.place(_kind, at, _item_id, _flip)
	Audio.play("hit", -8.0)
	RingBurst.spawn(get_parent(), at, Color(0.5, 0.85, 1.0), 26.0)
	var more: Item = null
	for item in _player.inventory.items:
		if item and item.id == _item_id:
			more = item
			break
	if more and _kind != "house":
		begin(more)
	else:
		cancel()
	return true


## The middle of the tile under a point.
func _snapped(at: Vector2) -> Vector2:
	var size := float(TerrainTiles.TILE_SIZE)
	return (at / size).floor() * size + Vector2(size, size) / 2.0
