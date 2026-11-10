class_name HazardZone
extends Node2D
## A patch of ground that hurts the player while they stand in it (a spore
## cloud, burning ground). It fades after a few seconds.

var _target: Player
var _radius := 100.0
var _color := Color.WHITE
var _status: Dictionary = {}
var _damage := 1.0
var _time_left := 3.0
var _lifetime := 3.0
var _tick_left := 0.0


static func spawn(parent: Node, at: Vector2, target: Player, radius: float, seconds: float, color: Color, status: Dictionary, damage: float) -> void:
	var zone := HazardZone.new()
	zone._target = target
	zone._radius = radius
	zone._color = color
	zone._status = status
	zone._damage = damage
	zone._time_left = seconds
	zone._lifetime = seconds
	zone.position = at
	zone.z_index = -1
	parent.add_child(zone)


func _physics_process(delta: float) -> void:
	_time_left -= delta
	_tick_left -= delta
	queue_redraw()
	if _time_left <= 0.0:
		queue_free()
		return
	if _tick_left <= 0.0 and is_instance_valid(_target) and not _target.is_dead():
		_tick_left = 0.5
		if _target.global_position.distance_to(global_position) < _radius and not _status.is_empty():
			var power: float = _status["power"] if _status["status"] == "chill" else _status["power"] * _damage
			_target.apply_status(_status["status"], _status["duration"], power)


func _draw() -> void:
	var fade := clampf(_time_left / _lifetime * 2.0, 0.0, 1.0)
	var pulse := 0.9 + 0.1 * sin(_time_left * 6.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.7))
	draw_circle(Vector2.ZERO, _radius * pulse, Color(_color, 0.16 * fade))
	draw_circle(Vector2.ZERO, _radius * 0.6 * pulse, Color(_color, 0.14 * fade))
	draw_arc(Vector2.ZERO, _radius * pulse, 0.0, TAU, 40, Color(_color, 0.5 * fade), 2.0)
	draw_set_transform(Vector2.ZERO)
