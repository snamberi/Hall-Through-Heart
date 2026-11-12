class_name FlameFX
extends Node2D
## A living fire: tongues of flame that lean and leap, sparks that rise and
## wink out, and a thread of smoke. Sits on anything that burns (campfires,
## braziers, torches, candles, the altar), over its painted flame.

## Overall size; 1 is a brazier's flame.
var size := 1.0
var smoke := true

var _phase := randf() * 100.0


func _ready() -> void:
	# So the ambience can find the nearest fire and let it crackle.
	add_to_group("fires")

## [position, age, life, drift]
var _sparks: Array = []
## [position, age, life, size]
var _smoke: Array = []


func _process(delta: float) -> void:
	# Only burn where someone can see it.
	var camera := get_viewport().get_camera_2d()
	if camera and camera.get_screen_center_position().distance_to(global_position) > 900.0:
		return
	if randf() < delta * 5.0 * size and _sparks.size() < 8:
		_sparks.append([Vector2(randf_range(-4.0, 4.0) * size, -6.0 * size), 0.0, randf_range(0.5, 1.1), randf_range(-12.0, 12.0)])
	if smoke and randf() < delta * 2.2 and _smoke.size() < 6:
		_smoke.append([Vector2(randf_range(-2.0, 2.0), -16.0 * size), 0.0, randf_range(1.2, 2.0), randf_range(2.0, 3.5) * size])
	for spark: Array in _sparks:
		spark[1] += delta
		spark[0] += Vector2(spark[3], -34.0) * delta
	for puff: Array in _smoke:
		puff[1] += delta
		puff[0] += Vector2(6.0, -16.0) * delta
	_sparks = _sparks.filter(func(s: Array) -> bool: return s[1] < s[2])
	_smoke = _smoke.filter(func(s: Array) -> bool: return s[1] < s[2])
	queue_redraw()


func _draw() -> void:
	var t := Time.get_ticks_msec() / 1000.0 + _phase
	for puff: Array in _smoke:
		var share: float = puff[1] / puff[2]
		draw_circle(puff[0], puff[3] * (1.0 + share), Color(0.25, 0.24, 0.26, 0.28 * (1.0 - share)))
	# Three tongues, each inside the last: red-orange, orange, yellow-white.
	var sway := sin(t * 5.3) * 1.6 + sin(t * 11.7) * 0.8
	var leap := 1.0 + sin(t * 7.1) * 0.12 + sin(t * 17.3) * 0.07
	_tongue(11.0 * size, 20.0 * size * leap, sway * size, Color(0.93, 0.33, 0.12, 0.92), t)
	_tongue(7.5 * size, 15.0 * size * leap, sway * 0.8 * size, Color(1.0, 0.62, 0.16, 0.95), t + 1.7)
	_tongue(4.0 * size, 9.0 * size * leap, sway * 0.5 * size, Color(1.0, 0.92, 0.55, 0.98), t + 3.1)
	for spark: Array in _sparks:
		var share: float = spark[1] / spark[2]
		draw_rect(Rect2(spark[0] - Vector2(0.75, 0.75), Vector2(1.5, 1.5)), Color(1.0, 0.8 - share * 0.4, 0.3, 1.0 - share))


## One tongue of flame: a teardrop whose tip wanders.
func _tongue(width: float, height: float, lean: float, color: Color, t: float) -> void:
	var points := PackedVector2Array()
	var half := width / 2.0
	points.append(Vector2(-half, 0))
	points.append(Vector2(-half * 1.05, -height * 0.25))
	points.append(Vector2(-half * 0.7 + lean * 0.3, -height * 0.55 + sin(t * 9.0) * 0.8))
	points.append(Vector2(lean + sin(t * 13.0) * 1.2, -height))
	points.append(Vector2(half * 0.7 + lean * 0.3, -height * 0.5 + cos(t * 8.0) * 0.8))
	points.append(Vector2(half * 1.05, -height * 0.22))
	points.append(Vector2(half, 0))
	draw_colored_polygon(points, color)
