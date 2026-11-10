class_name EnemyProjectile
extends Node2D
## A shot fired at the player. It flies straight, so it can be sidestepped
## or dodged through.

const SHEET: Texture2D = preload("res://assets/effects/projectiles.png")
const RANGE := 620.0

var _target: Player
var _direction := Vector2.RIGHT
var _speed := 400.0
var _damage := 5.0
var _level := 1
var _status: Dictionary = {}
var _owner_enemy: Enemy
var _flying := false
var _travelled := 0.0


static func fire(from: Enemy, target: Player, attack: Dictionary, damage: float) -> void:
	var shot := EnemyProjectile.new()
	shot._target = target
	shot._owner_enemy = from
	shot._speed = attack["speed"]
	shot._damage = damage
	shot._level = from.level
	shot._status = attack.get("status", {})
	shot.position = from.global_position + Vector2(0, -16)
	shot._direction = shot.position.direction_to(target.global_position + Vector2(0, -14))
	shot.rotation = shot._direction.angle()
	shot.z_index = 30
	var sprite := Sprite2D.new()
	sprite.texture = SHEET
	sprite.hframes = 4
	sprite.frame = attack["sprite"]
	sprite.modulate = attack.get("color", Color.WHITE)
	shot.add_child(sprite)
	from.get_parent().add_child(shot)


func _physics_process(delta: float) -> void:
	position += _direction * _speed * delta
	_travelled += _speed * delta
	if _travelled > RANGE or _touches_wall():
		HitSpark.spawn(get_parent(), global_position, Color(0.8, 0.8, 0.8))
		queue_free()
		return
	if not is_instance_valid(_target) or _target.is_dead():
		return
	if global_position.distance_to(_target.global_position + Vector2(0, -14)) < 16.0:
		var hurt := _target.take_damage(_damage, global_position - _direction * 10.0, _level)
		if hurt:
			if not _status.is_empty():
				_target.apply_status(_status["status"], _status["duration"], _status["power"] * _damage if _status["status"] != "chill" else _status["power"])
			if is_instance_valid(_owner_enemy):
				_owner_enemy.on_dealt_damage(_damage)
		queue_free()


func _touches_wall() -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = global_position + Vector2(0, 14)
	query.collision_mask = 1
	return not get_world_2d().direct_space_state.intersect_point(query, 1).is_empty()
