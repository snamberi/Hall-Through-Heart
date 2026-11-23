extends Node2D
## A shot in flight, drawn a whole pixel at a time along the way it flies
## (never a turned picture): an arrow with its steel head, barbs, shaft and
## fletching and a streak of air behind it; or an orb of magic with a
## flickering white core, a coloured body and dark rim, and a trail of
## shrinking motes and sparks where it has been. (Loaded by path.)
##
## `kind` is the old sheet column: 0 arrow, 1 arcane, 2 fire, 3 frost.

const PALETTES := {
	1: [Color("f4e8ff"), Color("b88aff"), Color("6a4ad0"), Color("2a1a5a")],
	2: [Color("fff2c0"), Color("ffb040"), Color("e05a1e"), Color("6a2210")],
	3: [Color("ffffff"), Color("a8ecff"), Color("4ab0e8"), Color("1a4a7a")],
}

var kind := 0
var direction := Vector2.RIGHT
## A colour cast over the whole (monsters' shots in their own colour).
var tint := Color.WHITE
var _time := 0.0
## Where the shot has been, in world space, newest first.
var _trail: Array[Vector2] = []
var _sparks: Array = []


func _ready() -> void:
	z_index = 1


func _process(delta: float) -> void:
	_time += delta
	_trail.push_front(global_position)
	if _trail.size() > 9:
		_trail.pop_back()
	if kind != 0 and randf() < delta * 30.0:
		var side := Vector2(-direction.y, direction.x) * randf_range(-4.0, 4.0)
		_sparks.append([global_position + side, 0.0])
	for spark: Array in _sparks:
		spark[1] += delta
	_sparks = _sparks.filter(func(s: Array) -> bool: return s[1] < 0.3)
	queue_redraw()


func _px(at: Vector2, c: Color, size: int = 1) -> void:
	draw_rect(Rect2(at.floor() - Vector2(size / 2, size / 2), Vector2(size, size)), c * tint)


func _draw() -> void:
	if kind == 0:
		_draw_arrow()
	else:
		_draw_orb()


func _draw_arrow() -> void:
	var dir := direction.normalized()
	var side := Vector2(-dir.y, dir.x).round()
	# A streak of air behind it.
	for k in range(9, 18):
		if k % 2 == 0:
			_px(-dir * k, Color(1, 1, 1, 0.35 * (1.0 - (k - 9) / 9.0)))
	# The shaft.
	for k in range(-7, 4):
		_px(dir * k, Color("8a6440") if k % 3 else Color("6e4e30"))
	# The steel head and its barbs.
	for k in range(4, 7):
		_px(dir * k, Color("e8eef4") if k < 6 else Color("ffffff"))
	_px(dir * 4 + side, Color("9aa4b0"))
	_px(dir * 4 - side, Color("9aa4b0"))
	# Red fletching at the back.
	for k in range(-8, -5):
		_px(dir * k + side, Color("c84a4a"))
		_px(dir * k - side, Color("a83a3a"))


func _draw_orb() -> void:
	var colours: Array = PALETTES.get(kind, PALETTES[1])
	# The trail: motes shrinking and fading where it has been.
	for i in range(1, _trail.size()):
		var at := _trail[i] - global_position
		var share := 1.0 - float(i) / _trail.size()
		var c: Color = colours[1] if i < 3 else colours[2]
		_px(at, Color(c, 0.75 * share), 3 if i < 3 else 2 if i < 6 else 1)
	for spark: Array in _sparks:
		var fade := 1.0 - float(spark[1]) / 0.3
		_px((spark[0] as Vector2) - global_position, Color(colours[0], fade))
	# The orb: a dark rim, a coloured body, a flickering white heart.
	var r := 4 if int(_time * 14.0) % 2 == 0 else 3
	for y in range(-r - 1, r + 2):
		for x in range(-r - 1, r + 2):
			var d := x * x + y * y
			if d <= r * r:
				var c: Color = colours[0] if d <= 1 else colours[1] if d <= (r - 1) * (r - 1) else colours[2]
				# Lit from the upper left.
				if x + y < -r and d > 1:
					c = colours[0]
				_px(Vector2(x, y), c)
			elif d <= (r + 1) * (r + 1):
				_px(Vector2(x, y), Color(colours[3], 0.85))
