class_name TransformFX
extends Node2D
## What gathers around the player while they hold the key to transform:
## the world dims at the edges, motes spiral inward, rings close in and a
## pillar of light grows, faster and brighter as the moment nears.

var color := Color(0.9, 0.4, 0.3)
var seconds := 4.0

var _time := 0.0
var _ending := 0.0
var _burst := false
## [angle, radius share, speed, size]
var _motes: Array = []


func _ready() -> void:
	z_index = 30
	for k in 46:
		_motes.append([randf() * TAU, randf_range(0.35, 1.0), randf_range(0.6, 1.6), randf_range(1.5, 3.2)])


## The key was let go: fade away.
func cancel() -> void:
	if _ending == 0.0:
		_ending = 0.001


## The change happened: one bright beat, then gone.
func burst() -> void:
	_burst = true
	_ending = 0.001


func _process(delta: float) -> void:
	_time += delta
	if _ending > 0.0:
		_ending += delta
		if _ending > 0.35:
			queue_free()
	queue_redraw()


func _draw() -> void:
	var share := clampf(_time / seconds, 0.0, 1.0)
	var fade := 1.0 - clampf(_ending / 0.35, 0.0, 1.0)
	# The world darkens toward the edges, drawing the eye in.
	draw_arc(Vector2(0, -16), 640.0, 0.0, TAU, 64, Color(0.0, 0.0, 0.03, 0.55 * share * fade), 840.0)
	draw_arc(Vector2(0, -16), 300.0 - share * 60.0, 0.0, TAU, 64, Color(0.0, 0.0, 0.03, 0.22 * share * fade), 160.0)
	if _burst:
		draw_circle(Vector2(0, -16), 40.0 + _ending * 600.0, Color(1, 1, 1, 0.5 * fade))
	# Rings closing in on the ground.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	for k in 3:
		var phase := fposmod(_time * (0.6 + share * 1.4) + k / 3.0, 1.0)
		draw_arc(Vector2.ZERO, 120.0 * (1.0 - phase) + 14.0, 0.0, TAU, 48, Color(color, phase * 0.75 * fade), 2.0 + share * 2.0)
	draw_arc(Vector2.ZERO, 26.0, 0.0, TAU * share, 40, Color(1, 1, 1, 0.9 * fade), 3.0)
	draw_set_transform(Vector2.ZERO)
	# A pillar of light rising.
	var height := 30.0 + share * 220.0
	var width := 6.0 + share * 18.0
	draw_rect(Rect2(-width / 2.0, -height, width, height), Color(color, 0.16 * fade + 0.18 * share * fade))
	draw_rect(Rect2(-width / 6.0, -height, width / 3.0, height), Color(1, 1, 1, 0.25 * share * fade))
	# Motes spiralling in.
	for mote: Array in _motes:
		var travel := fposmod(_time * mote[2] * (0.5 + share), 1.0)
		var radius: float = 150.0 * mote[1] * (1.0 - travel) + 8.0
		var angle: float = mote[0] + _time * (1.5 + share * 3.0) * mote[2]
		var at := Vector2(cos(angle) * radius, sin(angle) * radius * 0.55 - 16.0 - travel * 26.0)
		var bright := Color(color.lerp(Color.WHITE, travel * 0.7), (0.3 + 0.7 * travel) * fade * (0.4 + 0.6 * share))
		draw_rect(Rect2(at - Vector2(mote[3], mote[3]) / 2.0, Vector2(mote[3], mote[3])), bright)
