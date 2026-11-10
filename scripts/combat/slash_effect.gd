class_name SlashEffect
extends Node2D
## Brief arc drawn where a melee swing lands.

var _radius := 24.0
var _arc := PI / 2.0
var _tween: Tween
var _color := Color(0.95, 0.9, 0.8)


func _ready() -> void:
	modulate.a = 0.0


func play(
	direction: Vector2, radius: float, arc_radians: float, duration: float,
	color: Color = Color(0.95, 0.9, 0.8)
) -> void:
	_color = color
	_radius = radius
	_arc = arc_radians
	rotation = direction.angle()
	modulate.a = 1.0
	queue_redraw()
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, duration)


func _draw() -> void:
	draw_arc(Vector2.ZERO, _radius * 0.8, -_arc / 2.0, _arc / 2.0, 16, _color, 6.0)
	draw_arc(Vector2.ZERO, _radius * 0.6, -_arc / 2.5, _arc / 2.5, 12, Color(_color, 0.4), 4.0)
