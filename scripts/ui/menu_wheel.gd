class_name MenuWheel
extends Control
## The radial menu: a ring of wedges, one per screen. Hover to highlight,
## click to open. The centre shows the name of the wedge under the mouse.

signal chosen(id: String)

const OUTER := 236.0
const INNER := 100.0

## [{"id", "title", "icon"}], clockwise from the top.
var entries: Array[Dictionary] = []

var _hovered := -1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var index := _index_at(event.position)
		if index != _hovered:
			_hovered = index
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var index := _index_at(event.position)
		if index >= 0:
			chosen.emit(entries[index]["id"])


## The wedge under a point, or -1 over the centre or outside the ring.
func _index_at(point: Vector2) -> int:
	var offset := point - size / 2.0
	if offset.length() < INNER or offset.length() > OUTER:
		return -1
	var step := TAU / entries.size()
	# Wedge 0 is centred on straight up.
	var angle := fposmod(offset.angle() + PI / 2.0 + step / 2.0, TAU)
	return int(angle / step) % entries.size()


func _draw() -> void:
	var center := size / 2.0
	var count := entries.size()
	var step := TAU / count
	var font := UITheme.get_theme().default_font
	for index in count:
		var middle := -PI / 2.0 + index * step
		var hovered := index == _hovered
		draw_colored_polygon(_wedge(center, middle - step / 2.0, middle + step / 2.0), Color("3d3421") if hovered else Color(0.15, 0.17, 0.23, 0.96))
		var spot := center + Vector2.from_angle(middle) * (INNER + OUTER) / 2.0
		var icon_size := 56.0 if hovered else 48.0
		draw_texture_rect(ItemDB.icon(entries[index]["icon"]), Rect2(spot - Vector2(icon_size / 2.0, icon_size / 2.0 + 10.0), Vector2(icon_size, icon_size)), false)
		draw_string(font, spot + Vector2(-70.0, 38.0), entries[index]["title"], HORIZONTAL_ALIGNMENT_CENTER, 140.0, 16, UITheme.GOLD if hovered else UITheme.TEXT)
	# Spokes between wedges, then the rims and the dark centre.
	for index in count:
		var angle := -PI / 2.0 + (index + 0.5) * step
		draw_line(center + Vector2.from_angle(angle) * INNER, center + Vector2.from_angle(angle) * OUTER, Color(0.78, 0.72, 0.6, 0.55), 1.5)
	draw_arc(center, OUTER, 0.0, TAU, 96, Color("403020"), 5.0)
	draw_arc(center, OUTER - 3.0, 0.0, TAU, 96, Color("8a683a"), 1.5)
	draw_circle(center, INNER, Color("0c0f18"))
	draw_arc(center, INNER, 0.0, TAU, 64, Color("8a683a"), 2.0)
	if _hovered >= 0:
		var middle := -PI / 2.0 + _hovered * step
		draw_arc(center, OUTER - 3.0, middle - step / 2.0, middle + step / 2.0, 24, UITheme.GOLD, 3.0)
		draw_string(UITheme.bold(), center + Vector2(-INNER, 2.0), entries[_hovered]["title"], HORIZONTAL_ALIGNMENT_CENTER, INNER * 2.0, 22, UITheme.HEADING)
		draw_string(font, center + Vector2(-INNER, 26.0), "click to open", HORIZONTAL_ALIGNMENT_CENTER, INNER * 2.0, 13, UITheme.DIM)
	else:
		draw_string(UITheme.bold(), center + Vector2(-INNER, 8.0), "Menu", HORIZONTAL_ALIGNMENT_CENTER, INNER * 2.0, 24, UITheme.HEADING)


func _wedge(center: Vector2, from: float, to: float) -> PackedVector2Array:
	var points: PackedVector2Array = []
	for i in 13:
		points.append(center + Vector2.from_angle(lerpf(from, to, i / 12.0)) * OUTER)
	for i in 13:
		points.append(center + Vector2.from_angle(lerpf(to, from, i / 12.0)) * INNER)
	return points
