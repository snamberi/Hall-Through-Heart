class_name RootTendril
extends Node2D
## A living root creeping across the ground from a root-tech machine to
## what it works: it grows out along a wandering curve, its tip glowing,
## writhes while it works, and draws back, carrying the harvest home.

var from := Vector2.ZERO
var to := Vector2.ZERO
var color := Color(0.55, 1.0, 0.45)
## How much of the way out the root reaches (0..1).
var _reach := 0.0
var _time := 0.0
var _seed := 0.0
var _carried: Texture2D
var _carried_tint := Color.WHITE


func _ready() -> void:
	# It creeps along the ground: over the soil and flat things, under
	# anyone standing on it.
	z_index = -4
	_seed = randf() * 10.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


## A point along the root's path (t from 0 at the machine to 1 at the tip).
func _point(t: float) -> Vector2:
	var line := to - from
	var side := line.orthogonal().normalized()
	var bow := sin(t * PI) * minf(line.length() * 0.18, 40.0)
	var wriggle := sin(t * 9.0 + _time * 3.0 + _seed) * 4.0 * sin(t * PI)
	return from + line * t + side * (bow + wriggle)


func _draw() -> void:
	if _reach <= 0.0:
		return
	var steps := 24
	var points := PackedVector2Array()
	for step in steps + 1:
		points.append(_point(_reach * step / float(steps)) - global_position)
	var bark := Color(0.32, 0.22, 0.14)
	var light := Color(0.55, 0.4, 0.26)
	# Thick at the base, thin at the tip.
	for index in steps:
		var width := lerpf(7.0, 2.0, index / float(steps))
		draw_line(points[index], points[index + 1], bark, width + 2.0)
	for index in steps:
		var width := lerpf(5.0, 1.0, index / float(steps))
		draw_line(points[index], points[index + 1], light, width)
	# A thread of sap-light running along it, and a glowing tip.
	var pulse := fmod(_time * 1.5, 1.0)
	for index in steps:
		if absf(index / float(steps) - pulse) < 0.12:
			draw_line(points[index], points[index + 1], color, 2.0)
	# Little side rootlets.
	for index in range(4, steps, 5):
		var at := points[index]
		var out := (points[index + 1] - points[index]).orthogonal().normalized() * (5.0 if index % 2 else -5.0)
		draw_line(at, at + out + (points[index + 1] - at) * 0.6, bark, 2.0)
	var tip := points[points.size() - 1]
	draw_circle(tip, 4.0 + sin(_time * 8.0), Color(color, 0.35))
	draw_circle(tip, 2.0, color.lightened(0.4))
	if _carried:
		var size := Vector2(18, 18)
		draw_texture_rect(_carried, Rect2(tip - size / 2.0 - Vector2(0, 6), size), false, _carried_tint)


func grow(seconds: float) -> void:
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "_reach", 1.0, seconds)
	await tween.finished


func carry(icon: Texture2D, tint: Color) -> void:
	_carried = icon
	_carried_tint = tint


func retract(seconds: float) -> void:
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "_reach", 0.0, seconds)
	await tween.finished
	queue_free()
