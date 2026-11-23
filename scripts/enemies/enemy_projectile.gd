class_name EnemyProjectile
extends Node2D
## A shot fired at the player. It flies straight, so it can be sidestepped
## or dodged through.

## Loaded by path, so a game whose script cache predates these still runs.
const SharedWorld := preload("res://scripts/net/net_world.gd")

const SHEET: Texture2D = preload("res://assets/effects/projectiles.png")
const RANGE := 620.0

var _target: Player
var _direction := Vector2.RIGHT
var _speed := 400.0
var _damage := 5.0
var _level := 1
var _status: Dictionary = {}
var _owner_enemy: Enemy
var _element := ""
var _flying := false
var _travelled := 0.0


static func fire(from: Enemy, target: Player, attack: Dictionary, damage: float, direction: Vector2 = Vector2.ZERO) -> void:
	var shot := EnemyProjectile.new()
	shot._target = target
	shot._owner_enemy = from
	shot._speed = attack["speed"]
	shot._damage = damage
	shot._level = from.level
	shot._status = attack.get("status", {})
	shot._element = Elements.attack_element(from.enemy_id)
	shot.position = from.global_position + Vector2(0, -16)
	shot._direction = direction.normalized() if direction != Vector2.ZERO else shot.position.direction_to(target.global_position + Vector2(0, -14))
	shot._dress(int(attack["sprite"]), attack.get("color", Color.WHITE))
	from.get_parent().add_child(shot)
	# Everyone near sees it fly, and it can hit them too.
	if SharedWorld.current:
		SharedWorld.current.share_shot(from, shot.position, shot._direction, shot._speed, damage, attack)


## The same shot in another player's game, aimed at nobody in particular:
## it hurts this game's player if it reaches them.
static func fire_copy(parent: Node, at: Vector2, direction: Vector2, target: Player, speed: float, damage: float, level: int,
		status: Dictionary, sprite: int, color: Color, element: String) -> void:
	var shot := EnemyProjectile.new()
	shot._target = target
	shot._speed = speed
	shot._damage = damage
	shot._level = level
	shot._status = status
	shot._element = element
	shot.position = at
	shot._direction = direction.normalized()
	shot._dress(sprite, color)
	parent.add_child(shot)


func _dress(frame: int, color: Color) -> void:
	rotation = _direction.angle()
	z_index = 30
	var sprite := Sprite2D.new()
	sprite.texture = SHEET
	sprite.hframes = 4
	sprite.frame = frame
	sprite.modulate = color
	add_child(sprite)


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
		var hurt := _target.take_damage(_damage, global_position - _direction * 10.0, _level, _element)
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
