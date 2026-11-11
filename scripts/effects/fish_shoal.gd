class_name FishShoal
extends Node2D
## Dark fish circling under the surface at a fishing spot, now and then one
## breaking the water.

## Per fish: [orbit radius, speed (signed), phase, size, wobble phase].
var _fish: Array = []
var _jump_left := 0.0
var _ring_age := 9.0
var _ring_at := Vector2.ZERO


func _ready() -> void:
	z_as_relative = false
	z_index = -8
	_jump_left = randf_range(2.0, 7.0)
	for k in randi_range(2, 4):
		_fish.append([randf_range(9.0, 24.0), randf_range(0.45, 1.0) * (1.0 if randf() < 0.7 else -1.0), randf() * TAU, randf_range(0.8, 1.2), randf() * TAU])


func _process(delta: float) -> void:
	_jump_left -= delta
	_ring_age += delta
	if _jump_left <= 0.0:
		_jump_left = randf_range(4.0, 10.0)
		_ring_age = 0.0
		_ring_at = Vector2.from_angle(randf() * TAU) * Vector2(18.0, 10.0)
	queue_redraw()


func _draw() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for fish: Array in _fish:
		var angle: float = fish[2] + t * fish[1]
		var radius: float = fish[0] + sin(t * 0.7 + fish[4]) * 4.0
		var at := Vector2(cos(angle) * radius, sin(angle) * radius * 0.55)
		var heading := Vector2(-sin(angle), cos(angle) * 0.55).normalized() * signf(fish[1])
		var size: float = fish[3]
		draw_set_transform(at, heading.angle(), Vector2(size, size))
		var wag := sin(t * 9.0 + fish[4]) * 1.6
		var body := PackedVector2Array()
		for k in 12:
			var a := k * TAU / 12.0
			body.append(Vector2(cos(a) * 6.0, sin(a) * 2.2))
		var shade := Color(0.02, 0.05, 0.09, 0.6)
		draw_colored_polygon(body, shade)
		draw_colored_polygon(PackedVector2Array([Vector2(-5, 0), Vector2(-10, -3 + wag), Vector2(-10, 3 + wag)]), shade)
	draw_set_transform(Vector2.ZERO)
	if _ring_age < 0.9:
		var share := _ring_age / 0.9
		draw_set_transform(_ring_at, 0.0, Vector2(1.0, 0.5))
		draw_arc(Vector2.ZERO, 3.0 + share * 16.0, 0.0, TAU, 24, Color(0.85, 0.95, 1.0, 0.7 * (1.0 - share)), 1.5)
		if share < 0.3:
			draw_circle(Vector2(0, -6.0 - share * 20.0), 1.5, Color(0.9, 0.97, 1.0, 0.8))
		draw_set_transform(Vector2.ZERO)
