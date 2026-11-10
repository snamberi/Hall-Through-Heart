class_name Enemy
extends CharacterBody2D
## A melee enemy: wanders, chases the player, winds up, then lunges.
##
## The wind-up is the player's cue to dodge. Tune a new enemy type by
## changing the exported numbers on its scene.

signal died(enemy: Enemy)

enum State { WANDER, CHASE, WINDUP, LUNGE, RECOVER, STAGGER, DEAD }

@export_group("Movement")
@export var move_speed := 48.0
## Roughly how wide the enemy is; used for hits and for spacing from others.
@export var body_radius := 6.0

@export_group("Rewards")
## Experience given to the player when this enemy dies.
@export var xp_reward := 8

@export_group("Senses")
## The enemy notices the player inside this distance, in pixels.
@export var aggro_radius := 120.0
## The enemy gives up once the player is this far away.
@export var leash_radius := 230.0

@export_group("Attack")
@export var contact_damage := 10.0
## The enemy starts its wind-up when the player is this close.
@export var attack_range := 34.0
@export var windup_time := 0.45
@export var lunge_speed := 210.0
@export var lunge_time := 0.22
@export var recover_time := 0.7

var target: Player
var state := State.WANDER

var _state_time_left := 0.0
var _direction := Vector2.ZERO
var _has_hit := false
var _flash_tween: Tween

@onready var health: Health = $Health
@onready var _visual: Node2D = $Visual


func _ready() -> void:
	add_to_group("enemies")
	health.died.connect(_on_died)
	_pick_wander()


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_state_time_left = maxf(_state_time_left - delta, 0.0)
	var has_target := target != null and not target.is_dead()
	var to_target := target.global_position - global_position if has_target else Vector2.ZERO

	match state:
		State.WANDER:
			velocity = _direction * move_speed * 0.4
			if has_target and to_target.length() < aggro_radius:
				state = State.CHASE
			elif _state_time_left == 0.0:
				_pick_wander()
		State.CHASE:
			if not has_target or to_target.length() > leash_radius:
				_pick_wander()
			elif to_target.length() < attack_range:
				_enter(State.WINDUP, windup_time)
				velocity = Vector2.ZERO
				_visual.modulate = Color(1.6, 0.6, 0.6)
			else:
				velocity = to_target.normalized() * move_speed + _separation()
		State.WINDUP:
			velocity = Vector2.ZERO
			if has_target:
				_direction = to_target.normalized()
			if _state_time_left == 0.0:
				_enter(State.LUNGE, lunge_time)
				_has_hit = false
				_visual.modulate = Color.WHITE
		State.LUNGE:
			velocity = _direction * lunge_speed
			if has_target and not _has_hit and to_target.length() < body_radius + 6.0:
				_has_hit = true
				target.take_damage(contact_damage, global_position)
			if _state_time_left == 0.0:
				_enter(State.RECOVER, recover_time)
		State.RECOVER:
			velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
			if _state_time_left == 0.0:
				state = State.CHASE
		State.STAGGER:
			velocity = velocity.move_toward(Vector2.ZERO, 700.0 * delta)
			if _state_time_left == 0.0:
				state = State.CHASE

	if absf(velocity.x) > 1.0:
		_visual.scale.x = signf(velocity.x)
	move_and_slide()


func take_damage(amount: float, knockback: Vector2, critical: bool = false) -> void:
	if state == State.DEAD:
		return
	var color := Color(1.0, 0.8, 0.25) if critical else Color(0.95, 0.9, 0.75)
	DamageNumber.spawn(get_parent(), global_position, amount, color, critical)
	health.take_damage(amount)
	if health.is_dead():
		return
	_enter(State.STAGGER, 0.22)
	velocity = knockback
	_flash()


func _enter(new_state: State, duration: float) -> void:
	state = new_state
	_state_time_left = duration


func _pick_wander() -> void:
	_enter(State.WANDER, randf_range(1.2, 3.0))
	# Stand still about a third of the time.
	_direction = Vector2.ZERO if randf() < 0.35 else Vector2.from_angle(randf() * TAU)


## Small push away from nearby enemies so a pack does not stack on one spot.
func _separation() -> Vector2:
	var push := Vector2.ZERO
	for node in get_tree().get_nodes_in_group("enemies"):
		var other := node as Enemy
		if other == null or other == self:
			continue
		var offset := global_position - other.global_position
		var spacing := body_radius + other.body_radius + 4.0
		if offset.length() < spacing and offset.length() > 0.01:
			push += offset.normalized() * (spacing - offset.length()) * 6.0
	return push


func _flash() -> void:
	if _flash_tween:
		_flash_tween.kill()
	_visual.modulate = Color(4.0, 4.0, 4.0)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_visual, "modulate", Color.WHITE, 0.15)


func _on_died() -> void:
	state = State.DEAD
	remove_from_group("enemies")
	velocity = Vector2.ZERO
	$Collision.set_deferred("disabled", true)
	died.emit(self)
	if _flash_tween:
		_flash_tween.kill()
	_visual.modulate = Color(4.0, 4.0, 4.0)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.35)
	tween.tween_callback(queue_free)
