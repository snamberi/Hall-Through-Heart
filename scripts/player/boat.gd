class_name Boat
extends Node2D
## The rowboat under the player while sailing: a wooden hull with planks,
## oars that dip as it moves, and a wake behind it.

var _player: Player
var _time := 0.0


func setup(player: Player) -> void:
	_player = player
	z_index = -1
	visible = false


func _process(delta: float) -> void:
	visible = _player.boating
	if not visible:
		return
	_time += delta * (1.0 + _player.velocity.length() / 80.0)
	scale.x = -1.0 if _player.facing.x < -0.1 else 1.0 if _player.facing.x > 0.1 else scale.x
	queue_redraw()


func _draw() -> void:
	var bob := sin(_time * 2.0) * 1.2
	var hull := PackedVector2Array([Vector2(-30, -4 + bob), Vector2(30, -6 + bob), Vector2(24, 6 + bob), Vector2(-24, 8 + bob)])
	# Wake.
	if _player.velocity.length() > 20.0:
		for k in 3:
			var back := -_player.velocity.normalized() * (36.0 + k * 14.0) * Vector2(scale.x, 1.0)
			draw_arc(back + Vector2(0, 4), 8.0 + k * 5.0, 0.0, TAU, 16, Color(0.85, 0.92, 1.0, 0.35 - k * 0.1), 1.5)
	draw_colored_polygon(PackedVector2Array([Vector2(-32, -2 + bob), Vector2(32, -4 + bob), Vector2(26, 10 + bob), Vector2(-26, 12 + bob)]), Color(0.05, 0.04, 0.04))
	draw_colored_polygon(hull, Color(0.55, 0.38, 0.24))
	draw_line(Vector2(-28, -1 + bob), Vector2(28, -3 + bob), Color(0.7, 0.5, 0.32), 2.0)
	draw_line(Vector2(-25, 3 + bob), Vector2(25, 1 + bob), Color(0.42, 0.28, 0.18), 1.0)
	draw_line(Vector2(-23, 6 + bob), Vector2(23, 5 + bob), Color(0.42, 0.28, 0.18), 1.0)
	# Oars, dipping in turn.
	var dip := sin(_time * 4.0) * 6.0
	draw_line(Vector2(-6, -2 + bob), Vector2(-20 + dip, 14 + bob), Color(0.75, 0.6, 0.4), 2.0)
	draw_line(Vector2(6, -3 + bob), Vector2(20 - dip, 13 + bob), Color(0.75, 0.6, 0.4), 2.0)
