class_name PickupFeed
extends Control
## What you just picked up, as a short column of lines on the right above
## the hotbar. Picking up more of the same thing while its line is showing
## adds to it ("+12 Oak Wood") rather than adding a new line, so gathering
## a pile reads as one message. Lines fade after a few seconds.

const LINES := 6
const SHOW_FOR := 3.2
const FADE := 0.8
const LINE_HEIGHT := 22.0

## Each line: {"key", "name", "count", "color", "age"}.
var _lines: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = -300.0
	offset_right = -20.0
	offset_top = -120.0 - LINES * LINE_HEIGHT
	offset_bottom = -120.0
	Events.pickup_noted.connect(note)


## Adds `count` of something to the feed, merging with a showing line.
func note(name: String, count: int, color: Color) -> void:
	for line: Dictionary in _lines:
		if line["key"] == name and float(line["age"]) < SHOW_FOR:
			line["count"] = int(line["count"]) + count
			line["age"] = 0.0
			line["bump"] = 0.25
			queue_redraw()
			return
	_lines.append({"key": name, "name": name, "count": count, "color": color, "age": 0.0, "bump": 0.25})
	while _lines.size() > LINES:
		_lines.pop_front()
	queue_redraw()


func _process(delta: float) -> void:
	if _lines.is_empty():
		return
	for line: Dictionary in _lines:
		line["age"] = float(line["age"]) + delta
		line["bump"] = maxf(float(line["bump"]) - delta, 0.0)
	_lines = _lines.filter(func(line: Dictionary) -> bool: return float(line["age"]) < SHOW_FOR + FADE)
	queue_redraw()


func _draw() -> void:
	var font := UITheme.body_bold()
	var count := _lines.size()
	for index in count:
		var line: Dictionary = _lines[index]
		var fade := clampf(1.0 - (float(line["age"]) - SHOW_FOR) / FADE, 0.0, 1.0)
		var words := ("+%s  %s" % [InventoryMenu._thousands(int(line["count"])), line["name"]]) if int(line["count"]) > 0 else str(line["name"])
		var font_size := 15 + (2 if float(line["bump"]) > 0.0 else 0)
		var width := font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var y := size.y - (count - index - 1) * LINE_HEIGHT - 6.0
		var x := size.x - width - 6.0
		draw_rect(Rect2(x - 6.0, y - 16.0, width + 12.0, 20.0), Color(0.03, 0.04, 0.07, 0.6 * fade))
		var color: Color = line["color"]
		draw_string_outline(font, Vector2(x, y), words, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0, 0, 0, 0.85 * fade))
		draw_string(font, Vector2(x, y), words, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(color, fade))
