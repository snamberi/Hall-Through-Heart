class_name BuffBar
extends Control
## The buffs on the player as a row of small framed icons, each with the
## time it has left, a ring that empties as it runs down, and a frame
## coloured by its kind: gold for a meal, blue for a drink, pink for a
## treat, green for a potion. Point at one for its name and what it does.

const CHIP := 30.0
const GAP := 6.0
const KIND_COLORS := {"meal": Color("e0b050"), "drink": Color("7aa8ff"), "treat": Color("e07aa8"), "potion": Color("7ae08a")}

var _player: Player
var _font: Font
var _hover := ""


func setup(player: Player) -> void:
	_player = player
	_font = UITheme.get_theme().default_font
	mouse_filter = Control.MOUSE_FILTER_PASS
	size = Vector2(8 * (CHIP + GAP), CHIP + 18.0)
	mouse_exited.connect(func() -> void: _hover = "")


func _process(_delta: float) -> void:
	if _player == null:
		return
	var count := _player.buffs.active.size()
	size = Vector2(maxf(count, 1) * (CHIP + GAP), CHIP + 18.0)
	var mouse := get_local_mouse_position()
	_hover = ""
	var index := 0
	for id: String in _player.buffs.active:
		if Rect2(index * (CHIP + GAP), 0, CHIP, CHIP).has_point(mouse):
			_hover = id
		index += 1
	queue_redraw()


func _draw() -> void:
	if _player == null:
		return
	var index := 0
	for id: String in _player.buffs.active:
		var buff: Dictionary = _player.buffs.active[id]
		var rect := Rect2(index * (CHIP + GAP), 0, CHIP, CHIP)
		var color: Color = KIND_COLORS.get(buff.get("kind", ""), Color(0.75, 0.72, 0.65))
		draw_style_box(UITheme.slot("slot"), rect.grow(2.0))
		var icon: Texture2D = buff.get("icon")
		if icon:
			draw_texture_rect(icon, rect.grow(-3.0), false)
		else:
			draw_string(_font, rect.position + Vector2(0, 20), str(buff["name"]).left(1), HORIZONTAL_ALIGNMENT_CENTER, CHIP, 16, color)
		# A ring of time left round the frame, emptying clockwise.
		var share := clampf(float(buff["time"]) / maxf(float(buff.get("total", buff["time"])), 0.01), 0.0, 1.0)
		draw_rect(rect, Color(color, 0.35), false, 2.0)
		_draw_share(rect, share, color)
		var seconds := ceili(float(buff["time"]))
		var words := "%d:%02d" % [seconds / 60, seconds % 60] if seconds >= 60 else "%ds" % seconds
		var low := seconds <= 15
		draw_string_outline(_font, Vector2(rect.position.x - 4.0, rect.end.y + 13.0), words, HORIZONTAL_ALIGNMENT_CENTER, CHIP + 8.0, 13, 3, Color(0, 0, 0, 0.8))
		draw_string(_font, Vector2(rect.position.x - 4.0, rect.end.y + 13.0), words, HORIZONTAL_ALIGNMENT_CENTER, CHIP + 8.0, 13, UITheme.BAD if low else UITheme.TEXT)
		index += 1
	if _hover != "" and _player.buffs.active.has(_hover):
		_draw_detail(_player.buffs.active[_hover])


## The frame lit along its length in proportion to the time left.
func _draw_share(rect: Rect2, share: float, color: Color) -> void:
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y), rect.position]
	var total := rect.size.x * 4.0
	var left := total * share
	for k in 4:
		if left <= 0.0:
			break
		var a: Vector2 = corners[k]
		var b: Vector2 = corners[k + 1]
		var length := a.distance_to(b)
		draw_line(a, a.lerp(b, minf(1.0, left / length)), color, 2.0)
		left -= length


func _draw_detail(buff: Dictionary) -> void:
	var lines: PackedStringArray = [str(buff["name"])]
	var mods: Dictionary = buff.get("mods", {})
	for stat: String in mods:
		for kind: String in mods[stat]:
			lines.append(ItemDB.describe_modifier({"stat": stat, "kind": kind, "value": float(mods[stat][kind])}))
	var course: String = ItemDB.COURSE_NAMES.get(buff.get("kind", ""), "")
	if course != "":
		lines.append("%s - one at a time" % course)
	var width := 40.0
	for line in lines:
		width = maxf(width, _font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x)
	var box := Rect2(Vector2(0, CHIP + 22.0), Vector2(width + 16.0, lines.size() * 18.0 + 10.0))
	draw_style_box(UITheme.tooltip_box(), box)
	for k in lines.size():
		draw_string(_font, box.position + Vector2(8, 20 + k * 18.0), lines[k], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UITheme.HEADING if k == 0 else UITheme.TEXT)
