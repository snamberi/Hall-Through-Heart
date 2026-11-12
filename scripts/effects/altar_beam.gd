class_name AltarBeam
extends Node2D
## A soft column of violet light standing over the Altar of Magic, pulsing
## slowly, with motes drifting up it, so the altar can be seen from afar.

const HEIGHT := 520.0
var color := Color(0.75, 0.5, 1.0)
var _motes: Array = []


func _ready() -> void:
	z_index = 30
	for k in 14:
		_motes.append([randf_range(-10.0, 10.0), randf() * HEIGHT, randf_range(30.0, 70.0)])


func _process(delta: float) -> void:
	for mote: Array in _motes:
		mote[1] = fmod(mote[1] + mote[2] * delta, HEIGHT)
	queue_redraw()


func _draw() -> void:
	var pulse := 0.8 + 0.2 * sin(Time.get_ticks_msec() / 700.0)
	var clear := Color(color, 0.0)
	for layer: Array in [[22.0, 0.12], [12.0, 0.18], [4.0, 0.3]]:
		var half: float = layer[0] * pulse
		var solid := Color(color, layer[1])
		draw_polygon(PackedVector2Array([Vector2(-half, 0), Vector2(half, 0), Vector2(half * 0.6, -HEIGHT), Vector2(-half * 0.6, -HEIGHT)]),
			PackedColorArray([solid, solid, clear, clear]))
	for mote: Array in _motes:
		var fade: float = 1.0 - mote[1] / HEIGHT
		draw_rect(Rect2(Vector2(mote[0], -mote[1]) - Vector2(1.5, 1.5), Vector2(3, 3)), Color(color.lightened(0.4), 0.7 * fade))
