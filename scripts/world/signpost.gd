class_name Signpost
extends Node2D
## A wooden signpost by the road. Each arm points toward one of the nearest
## places (one to three of them), and walking up to it shows their names,
## which way they lie and how far.

const SHOW_DISTANCE := 120.0
const WOOD := Color("8a5a34")
const WOOD_DARK := Color("4e3220")
const WOOD_LIGHT := Color("b07a48")

var cell := Vector2i.ZERO
var structures: Structures
## Places to point at: [{"name", "kind", "direction": Vector2, "distance": float}].
var targets: Array = []
var _label: Label
var _check := 0.0
var _looked := false


static func create(at: Vector2, p_cell: Vector2i, p_structures: Structures) -> Signpost:
	var sign := Signpost.new()
	sign.position = at
	sign.cell = p_cell
	sign.structures = p_structures
	return sign


func _ready() -> void:
	z_index = 0
	y_sort_enabled = false
	_label = Label.new()
	_label.add_theme_font_override("font", UITheme.get_theme().default_font)
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.78))
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.1, 0.08, 0.07, 0.85)
	box.border_color = WOOD
	box.set_border_width_all(2)
	box.set_corner_radius_all(4)
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	_label.add_theme_stylebox_override("normal", box)
	_label.scale = Vector2.ONE / 2.0
	_label.z_index = 30
	_label.visible = false
	add_child(_label)


func _process(delta: float) -> void:
	_check -= delta
	if _check > 0.0:
		return
	_check = 0.25
	var player: Player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var distance := player.global_position.distance_to(global_position)
	if not _looked and distance < 600.0 and structures:
		# Read the land only once someone comes near.
		_looked = true
		_read_the_land()
	_label.visible = distance < SHOW_DISTANCE and not targets.is_empty()


func _read_the_land() -> void:
	targets.clear()
	# Places in plain sight need no sign: point further afield.
	for site: Dictionary in structures.nearest_sites(cell, 3, 7, [], 14.0):
		var step := Vector2(site["cell"] - cell)
		targets.append({"name": site["name"], "kind": site["kind"], "direction": step.normalized(), "distance": step.length()})
	var lines: PackedStringArray = []
	for target: Dictionary in targets:
		lines.append("%s  %s   %d m" % [_short(target["direction"]), target["name"], roundi(target["distance"] * 2.0)])
	_label.text = "\n".join(lines)
	_label.reset_size()
	_label.position = Vector2(-_label.get_minimum_size().x / 4.0, -58.0 - _label.get_minimum_size().y / 2.0)
	queue_redraw()


static func _short(direction: Vector2) -> String:
	var names: Array[String] = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
	return names[posmod(roundi(direction.angle() / (PI / 4.0)), 8)]


func _draw() -> void:
	# A shadow, a post with a cap, and a plank arm for each place.
	draw_set_transform(Vector2(0, 1), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 9.0, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(-3, -40, 6, 41), WOOD_DARK)
	draw_rect(Rect2(-2, -40, 4, 40), WOOD)
	draw_rect(Rect2(-2, -40, 1, 40), WOOD_LIGHT)
	draw_rect(Rect2(-4, -43, 8, 4), WOOD_DARK)
	draw_rect(Rect2(-3, -42, 6, 2), WOOD_LIGHT)
	var arms := targets if not targets.is_empty() else [{"direction": Vector2.RIGHT}]
	for index in mini(arms.size(), 3):
		var direction: Vector2 = arms[index]["direction"]
		var side := 1.0 if direction.x >= 0.0 else -1.0
		# Seen from above, an arm leans up or down the way its place lies.
		var tilt := clampf(direction.y, -0.8, 0.8) * 0.35
		var y := -36.0 + index * 8.0
		_draw_arm(Vector2(0, y), side, tilt)


func _draw_arm(root: Vector2, side: float, tilt: float) -> void:
	var length := 17.0
	var along := Vector2(side, tilt).normalized()
	var up := Vector2(0, -1)
	var tip := root + along * length
	var outline := PackedVector2Array([
		root + up * 3.0, root + along * (length - 4.0) + up * 3.0, tip, root + along * (length - 4.0) - up * 3.0, root - up * 3.0])
	draw_colored_polygon(outline, WOOD_DARK)
	var inner := PackedVector2Array([
		root + up * 2.0 + along * 1.0, root + along * (length - 4.5) + up * 2.0, tip - along * 1.6, root + along * (length - 4.5) - up * 2.0, root - up * 2.0 + along * 1.0])
	draw_colored_polygon(inner, WOOD)
	draw_line(root + up * 1.5 + along * 2.0, root + along * (length - 6.0) + up * 1.5, WOOD_LIGHT, 1.0)
	# Painted letters, too small to read: a few dark dashes.
	for i in 3:
		var at := root + along * (4.0 + i * 3.5)
		draw_line(at, at + along * 2.0, Color(0.2, 0.13, 0.08), 1.0)
