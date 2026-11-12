class_name MenuWheel
extends Control
## The radial menu: a ring of wedges, one per screen. Hover to highlight,
## click to open. The hub shows what the hovered screen is for, and wedges
## carry a badge when something there is waiting (points to spend, say).

signal chosen(id: String)

const OUTER := 262.0
const INNER := 108.0
const PLATE := 31.0

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
	if offset.length() < INNER or offset.length() > OUTER + 14.0:
		return -1
	var step := TAU / entries.size()
	# Wedge 0 is centred on straight up.
	var angle := fposmod(offset.angle() + PI / 2.0 + step / 2.0, TAU)
	return int(angle / step) % entries.size()


func _draw() -> void:
	var center := size / 2.0
	var count := entries.size()
	if count == 0:
		return
	var step := TAU / count
	var font := UITheme.get_theme().default_font
	var grow := 0.86 + 0.14 * ease(_opened, 0.4)
	var outer := OUTER * grow
	var inner := INNER * grow
	var fade := _opened
	# A soft dark halo so the wheel stands off the world behind it.
	for ring in 6:
		draw_arc(center, outer + 10.0 + ring * 7.0, 0.0, TAU, 96, Color(0, 0, 0, 0.16 * fade * (1.0 - ring / 6.0)), 8.0)
	for index in count:
		var middle := -PI / 2.0 + index * step
		var lift: float = _lift[index] if index < _lift.size() else 0.0
		var push := Vector2.from_angle(middle) * lift * 9.0
		var from := middle - step / 2.0 + 0.012
		var to := middle + step / 2.0 - 0.012
		# The wedge: a dark body, a lighter outer band, and gold when lifted.
		var body := Color(0.105, 0.12, 0.175).lerp(Color(0.27, 0.215, 0.12), lift)
		var band := Color(0.15, 0.17, 0.24).lerp(Color(0.42, 0.32, 0.15), lift)
		draw_colored_polygon(_wedge(center + push, from, to, inner, outer), Color(body, 0.97 * fade))
		draw_colored_polygon(_wedge(center + push, from, to, outer - 26.0, outer), Color(band, 0.97 * fade))
		draw_colored_polygon(_wedge(center + push, from, to, inner, inner + 5.0), Color(0.05, 0.06, 0.09, 0.9 * fade))
		_arc_line(center + push, outer, from, to, Color(UITheme.GOLD, fade) if lift > 0.5 else Color(0.54, 0.41, 0.23, fade), 2.0 + lift)
		# The icon on a round plate.
		var spot := center + push + Vector2.from_angle(middle) * ((inner + outer) / 2.0 - 6.0)
		var plate := PLATE + lift * 4.0
		draw_circle(spot + Vector2(0, -8), plate + 2.0, Color(0.03, 0.035, 0.055, 0.95 * fade))
		draw_circle(spot + Vector2(0, -8), plate, Color(0.14, 0.16, 0.22, fade).lerp(Color(0.24, 0.2, 0.12, fade), lift))
		draw_arc(spot + Vector2(0, -8), plate, 0.0, TAU, 40, Color(0.54, 0.41, 0.23, fade).lerp(Color(UITheme.GOLD, fade), lift), 1.5)
		var icon_size := 46.0 + lift * 8.0
		draw_texture_rect(ItemDB.icon(entries[index]["icon"]), Rect2(spot - Vector2(icon_size / 2.0, icon_size / 2.0 + 8.0), Vector2(icon_size, icon_size)), false, Color(1, 1, 1, fade))
	# Names and badges go on last, so no plate ever covers a neighbour's name.
	for index in count:
		var middle := -PI / 2.0 + index * step
		var lift: float = _lift[index] if index < _lift.size() else 0.0
		var push := Vector2.from_angle(middle) * lift * 9.0
		var spot := center + push + Vector2.from_angle(middle) * ((inner + outer) / 2.0 - 6.0)
		var plate := PLATE + lift * 4.0
		var title: String = entries[index]["title"]
		var title_font: Font = UITheme.bold() if lift > 0.5 else font
		draw_string_outline(title_font, spot + Vector2(-70.0, plate + 9.0), title, HORIZONTAL_ALIGNMENT_CENTER, 140.0, 15, 4, Color(0, 0, 0, 0.85 * fade))
		draw_string(title_font, spot + Vector2(-70.0, plate + 9.0), title, HORIZONTAL_ALIGNMENT_CENTER, 140.0, 15, Color(UITheme.TEXT.lerp(UITheme.GOLD, lift), fade))
		# Something waiting here.
		var waiting: int = badge_for.call(entries[index]["id"]) if badge_for.is_valid() else 0
		if waiting > 0:
			var at := spot + Vector2(plate * 0.72, -8.0 - plate * 0.72)
			var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 220.0)
			draw_circle(at, 12.0 + pulse * 2.0, Color(0.95, 0.3, 0.25, 0.25 * fade))
			draw_circle(at, 10.0, Color(0.78, 0.16, 0.16, fade))
			draw_arc(at, 10.0, 0.0, TAU, 20, Color(1.0, 0.85, 0.6, fade), 1.5)
			draw_string(UITheme.bold(), at + Vector2(-10.0, 5.0), str(mini(waiting, 99)), HORIZONTAL_ALIGNMENT_CENTER, 20.0, 13, Color(1, 1, 1, fade))
	# The outer rim with studs, and the hub.
	draw_arc(center, outer + 5.0, 0.0, TAU, 128, Color(0.25, 0.19, 0.125, fade), 5.0)
	draw_arc(center, outer + 8.0, 0.0, TAU, 128, Color(0.54, 0.41, 0.23, fade), 1.5)
	for index in count:
		var angle := -PI / 2.0 + (index + 0.5) * step
		draw_circle(center + Vector2.from_angle(angle) * (outer + 5.0), 3.5, Color(0.85, 0.7, 0.42, fade))
	draw_circle(center, inner - 3.0, Color(0.047, 0.059, 0.094, 0.98 * fade))
	draw_arc(center, inner - 3.0, 0.0, TAU, 72, Color(0.54, 0.41, 0.23, fade), 2.5)
	draw_arc(center, inner - 9.0, 0.0, TAU, 72, Color(0.25, 0.19, 0.125, fade), 1.0)
	var width := (inner - 16.0) * 2.0
	if _hovered >= 0 and _hovered < count:
		var entry: Dictionary = entries[_hovered]
		# The name large and bright; what it is for smaller and quieter below a rule.
		draw_string(UITheme.bold(), center + Vector2(-width / 2.0, -16.0), entry["title"], HORIZONTAL_ALIGNMENT_CENTER, width, 27, Color(UITheme.GOLD, fade))
		draw_line(center + Vector2(-34, -6), center + Vector2(34, -6), Color(0.54, 0.41, 0.23, fade), 1.0)
		draw_multiline_string(font, center + Vector2(-width / 2.0, 12.0), entry.get("text", ""), HORIZONTAL_ALIGNMENT_CENTER, width, 14, 3, Color(UITheme.DIM, fade))
		var waiting: int = badge_for.call(entry["id"]) if badge_for.is_valid() else 0
		if waiting > 0:
			draw_string(font, center + Vector2(-width / 2.0, 62.0), "%d waiting" % waiting, HORIZONTAL_ALIGNMENT_CENTER, width, 14, Color(1.0, 0.55, 0.45, fade))
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
