class_name Projectile
extends Node2D
## An arrow or bolt in flight. Damages the first enemy it touches (or every
## enemy, if it pierces) and stops at walls.
##
## Config keys (all optional except "sprite"):
##   sprite     column in assets/effects/projectiles.png
##   speed      pixels/second            range    pixels before it fades
##   radius     how close counts as a hit
##   pierce     keep going through enemies
##   explode    blast radius on impact (0 for none)
##   knockback  shove on hit
##   status     {"status", "duration", "power"} applied to enemies hit
##   color      tint for the impact effects

const SHEET: Texture2D = preload("res://assets/effects/projectiles.png")

var _player: Player
var _direction := Vector2.RIGHT
var _config: Dictionary = {}
var _multiplier := 1.0
var _travelled := 0.0
var _hit: Array = []


static func fire(player: Player, direction: Vector2, config: Dictionary, multiplier: float) -> Projectile:
	var projectile := Projectile.new()
	projectile._player = player
	projectile._direction = direction
	projectile._config = config
	projectile._multiplier = multiplier
	projectile.position = player.global_position + Vector2(0, -14) + direction * 18.0
	projectile.rotation = direction.angle()
	projectile.z_index = 30
	player.get_parent().add_child(projectile)
	return projectile


func _ready() -> void:
	var sprite := Sprite2D.new()
	sprite.texture = SHEET
	sprite.hframes = 4
	sprite.frame = _config["sprite"]
	add_child(sprite)


func _physics_process(delta: float) -> void:
	var step: float = _config.get("speed", 600.0) * delta
	position += _direction * step
	_travelled += step
	if _travelled > _config.get("range", 520.0) or _touches_wall():
		_finish()
		return
	var radius: float = _config.get("radius", 10.0)
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy in _hit:
			continue
		# Aim for the body, not the feet.
		var body := enemy.global_position + Vector2(0, -14)
		if body.distance_to(global_position) > radius + enemy.body_radius:
			continue
		_strike(enemy)
		if not _config.get("pierce", false):
			_finish()
			return


func _strike(enemy: Enemy) -> void:
	_hit.append(enemy)
	_player.hit_enemy(enemy, _multiplier, _direction * _config.get("knockback", 200.0))
	_apply_status(enemy)


func _apply_status(enemy: Enemy) -> void:
	if not _config.has("status") or not is_instance_valid(enemy):
		return
	var effect: Dictionary = _config["status"]
	var power: float = effect["power"]
	if effect["status"] != "chill":
		power *= _player.stats.get_stat("physical_damage") * _multiplier
	enemy.apply_status(effect["status"], effect["duration"], power, _player.weapon_type)


func _finish() -> void:
	var color: Color = _config.get("color", Color(1.0, 0.95, 0.8))
	var blast: float = _config.get("explode", 0.0)
	if blast > 0.0:
		RingBurst.spawn(get_parent(), global_position, color, blast)
		_player.shake_camera(6.0)
		var caught: Array = _hit.duplicate()
		_player.strike_circle(global_position, blast, _multiplier, _config.get("knockback", 200.0), caught)
		for enemy: Variant in caught:
			if not enemy in _hit:
				_apply_status(enemy)
	HitSpark.spawn(get_parent(), global_position, color, blast > 0.0)
	queue_free()


func _touches_wall() -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = global_position + Vector2(0, 14)
	query.collision_mask = 1
	return not get_world_2d().direct_space_state.intersect_point(query, 1).is_empty()
