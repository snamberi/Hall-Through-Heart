class_name MenuWheel
extends Control
## The radial menu: a riveted bronze ring of eight wedges (pixel art from
## tools/generate_ui.py), one per main screen, each with its icon in a
## socket. Hover to light a wedge gold, click to open. The hub shows what
## the hovered screen is for, and wedges carry a badge when something there
## is waiting (points to spend, say).

signal chosen(id: String)

const ART: Texture2D = preload("res://assets/ui/wheel.png")
const LIT: Texture2D = preload("res://assets/ui/wheel_lit.png")
## Radii of the ring and hub, and where the icon sockets sit, in pixels.
const OUTER := 268.0
const INNER := 104.0
const SOCKETS := 176.0
const SOCKET_RISE := 12.0

## [{"id", "title", "icon", "text"}], clockwise from the top.
var entries: Array[Dictionary] = []
## Called with a screen id; returns how many things wait there.
var badge_for: Callable
## Lines for the hub when nothing is hovered: [title, detail].
var hub_text: Callable

var _hovered := -1
## How far each wedge has slid out, 0 to 1.
var _lift: Array[float] = []
var _opened := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	resized.connect(queue_redraw)
	visibility_changed.connect(func() -> void:
		if visible:
			_opened = 0.0
			_hovered = -1
	)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_lift.resize(entries.size())
	_opened = minf(_opened + delta * 7.0, 1.0)
	for index in entries.size():
		_lift[index] = move_toward(_lift[index], 1.0 if index == _hovered else 0.0, delta * 9.0)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var index := _index_at(event.position)
		if index != _hovered:
			_hovered = index
			if index >= 0:
				Audio.play("ui_hover", -16.0, 0.03)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var index := _index_at(event.position)
		if index >= 0:
			Audio.play("ui_click", -10.0, 0.05)
			chosen.emit(entries[index]["id"])


## The wedge under a point, or -1 over the hub or outside the ring.
func _index_at(point: Vector2) -> int:
	var offset := point - size / 2.0
	if offset.length() < INNER or offset.length() > OUTER + 4.0:
		return -1
	var step := TAU / entries.size()
	# Wedge 0 is centred on straight up.
	var angle := fposmod(offset.angle() + PI / 2.0 + step / 2.0, TAU)
	return int(angle / step) % entries.size()


func _draw() -> void:
	var center := (size / 2.0).floor()
	var count := entries.size()
	if count == 0:
		return
	var step := TAU / count
	var font := UITheme.get_theme().default_font
	var fade := _opened
	var art := Vector2(ART.get_width(), ART.get_height())
	var corner := center - art / 2.0
	# A soft dark halo so the wheel stands off the world behind it.
	for ring in 5:
		draw_arc(center, OUTER + 10.0 + ring * 8.0, 0.0, TAU, 96, Color(0, 0, 0, 0.18 * fade * (1.0 - ring / 5.0)), 9.0)
	draw_texture(ART, corner, Color(1, 1, 1, fade))
	if _hovered >= 0 and _hovered < count:
		draw_texture_rect_region(LIT, Rect2(corner, art), Rect2(Vector2(_hovered * art.x, 0), art), Color(1, 1, 1, fade))
	for index in count:
		var middle := -PI / 2.0 + index * step
		var lift: float = _lift[index] if index < _lift.size() else 0.0
		var spot := center + Vector2.from_angle(middle) * SOCKETS - Vector2(0, SOCKET_RISE)
		var icon_size := 44.0
		draw_texture_rect(MenuIcons.icon(entries[index]["id"]), Rect2((spot - Vector2(icon_size, icon_size) / 2.0).floor(), Vector2(icon_size, icon_size)), false, Color(1, 1, 1, fade))
		var title: String = entries[index]["title"]
		var title_font: Font = UITheme.bold() if lift > 0.5 else font
		draw_string_outline(title_font, spot + Vector2(-70.0, 58.0), title, HORIZONTAL_ALIGNMENT_CENTER, 140.0, 16, 4, Color(0, 0, 0, 0.9 * fade))
		draw_string(title_font, spot + Vector2(-70.0, 58.0), title, HORIZONTAL_ALIGNMENT_CENTER, 140.0, 16, Color(UITheme.TEXT.lerp(UITheme.GOLD, lift), fade))
		# Something waiting here.
		var waiting: int = badge_for.call(entries[index]["id"]) if badge_for.is_valid() else 0
		if waiting > 0:
			var at := (spot + Vector2(28.0, -28.0)).floor()
			draw_rect(Rect2(at - Vector2(11, 11), Vector2(22, 22)), Color(0.08, 0.02, 0.02, fade))
			draw_rect(Rect2(at - Vector2(9, 9), Vector2(18, 18)), Color(0.78, 0.16, 0.16, fade))
			draw_rect(Rect2(at - Vector2(9, 9), Vector2(18, 4)), Color(0.92, 0.32, 0.28, fade))
			draw_string(UITheme.bold(), at + Vector2(-10.0, 5.0), str(mini(waiting, 99)), HORIZONTAL_ALIGNMENT_CENTER, 20.0, 13, Color(1, 1, 1, fade))
	var width := (INNER - 14.0) * 2.0
	if _hovered >= 0 and _hovered < count:
		var entry: Dictionary = entries[_hovered]
		# The name large and bright; what it is for smaller and quieter below a rule.
		draw_string(UITheme.bold(), center + Vector2(-width / 2.0, -14.0), entry["title"], HORIZONTAL_ALIGNMENT_CENTER, width, 25, Color(UITheme.GOLD, fade))
		draw_rect(Rect2(center + Vector2(-30, -6), Vector2(60, 2)), Color(0.54, 0.41, 0.23, fade))
		draw_multiline_string(font, center + Vector2(-width / 2.0, 12.0), entry.get("text", ""), HORIZONTAL_ALIGNMENT_CENTER, width, 14, 3, Color(UITheme.DIM, fade))
		var waiting: int = badge_for.call(entry["id"]) if badge_for.is_valid() else 0
		if waiting > 0:
			draw_string(font, center + Vector2(-width / 2.0, 58.0), "%d waiting" % waiting, HORIZONTAL_ALIGNMENT_CENTER, width, 14, Color(1.0, 0.55, 0.45, fade))
	else:
		var lines: Array = hub_text.call() if hub_text.is_valid() else ["Menu", ""]
		draw_string(UITheme.bold(), center + Vector2(-width / 2.0, -6.0), lines[0], HORIZONTAL_ALIGNMENT_CENTER, width, 24, Color(UITheme.HEADING, fade))
		draw_multiline_string(font, center + Vector2(-width / 2.0, 18.0), lines[1], HORIZONTAL_ALIGNMENT_CENTER, width, 14, 3, Color(UITheme.DIM, fade))


func _arc_line(center: Vector2, radius: float, from: float, to: float, color: Color, width: float) -> void:
	draw_arc(center, radius, from, to, 16, color, width)


func _wedge(center: Vector2, from: float, to: float, inner: float, outer: float) -> PackedVector2Array:
	var points: PackedVector2Array = []
	for i in 13:
		points.append(center + Vector2.from_angle(lerpf(from, to, i / 12.0)) * outer)
	for i in 13:
		points.append(center + Vector2.from_angle(lerpf(to, from, i / 12.0)) * inner)
	return points
