class_name Player
extends CharacterBody2D
## The player character: movement, attacking, dodging, and taking damage.
##
## Progression lives in the child modules (Leveling, Attributes, Mastery,
## Stats); this script only reads the numbers they produce.

signal died(xp_lost: int)

enum State { MOVE, ATTACK, DODGE, DEAD }

@export_group("Movement")
## How quickly the player reaches full speed and stops, in pixels/second².
@export var acceleration := 2200.0

@export_group("Attack")
## How far the swing reaches, in pixels.
@export var attack_range := 64.0
## Width of the swing, in degrees.
@export var attack_arc := 120.0
## How long the player is committed to a swing.
@export var attack_duration := 0.16
## Seconds between swings at 100% attack speed.
@export var attack_cooldown := 0.34
## How hard a hit shoves an enemy back, in pixels/second.
@export var attack_knockback := 380.0

@export_group("Dodge")
@export var dodge_speed := 560.0
## The player cannot be hurt for the length of the dodge.
@export var dodge_duration := 0.22
@export var dodge_cooldown := 0.6
@export var dodge_stamina_cost := 25.0

@export_group("Defence")
## Seconds of safety after being hit, so one enemy cannot chain hits.
@export var hurt_invulnerability := 0.6

## Stable id of the current class. Everyone starts as an Adventurer.
var class_id := "adventurer"
## Weapon category in hand; decides which mastery is trained.
var weapon_type := "swords"
## Last direction the player moved or attacked in.
var facing := Vector2.DOWN
var state := State.MOVE

var _state_time_left := 0.0
var _attack_cooldown_left := 0.0
var _dodge_cooldown_left := 0.0
var _invulnerable_left := 0.0
var _dodge_direction := Vector2.ZERO

@onready var health: Health = $Health
@onready var stamina: ResourcePool = $Stamina
@onready var mana: ResourcePool = $Mana
@onready var leveling: Leveling = $Leveling
@onready var attributes: Attributes = $Attributes
@onready var mastery: WeaponMastery = $Mastery
@onready var stats: CharacterStats = $Stats
@onready var camera: Camera2D = $Camera
@onready var _visual: Node2D = $Visual
@onready var _slash: SlashEffect = $Slash


func _ready() -> void:
	SaveGame.register("character", self)
	stats.weapon_type = weapon_type
	stats.setup(attributes, mastery)
	stats.changed.connect(_apply_stats)
	leveling.leveled_up.connect(_on_leveled_up)
	_apply_stats()
	_restore_all()


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_attack_cooldown_left = maxf(_attack_cooldown_left - delta, 0.0)
	_dodge_cooldown_left = maxf(_dodge_cooldown_left - delta, 0.0)
	_invulnerable_left = maxf(_invulnerable_left - delta, 0.0)
	_state_time_left = maxf(_state_time_left - delta, 0.0)
	health.heal(stats.get_stat("health_regen") * delta)

	match state:
		State.MOVE:
			_process_move(delta)
		State.ATTACK:
			velocity = velocity.move_toward(Vector2.ZERO, acceleration * delta)
			if _state_time_left == 0.0:
				state = State.MOVE
		State.DODGE:
			velocity = _dodge_direction * dodge_speed
			if _state_time_left == 0.0:
				state = State.MOVE

	_visual.modulate.a = 0.45 if _invulnerable_left > 0.0 else 1.0
	move_and_slide()


func is_dead() -> bool:
	return state == State.DEAD


## Swings at everything in an arc in front of the player.
func attack(direction: Vector2) -> void:
	facing = direction
	_face_visual(direction.x)
	state = State.ATTACK
	_state_time_left = attack_duration
	_attack_cooldown_left = attack_cooldown / stats.get_stat("attack_speed")
	velocity = direction * 130.0
	_slash.play(direction, attack_range, deg_to_rad(attack_arc), attack_duration + 0.08)

	var half_arc := deg_to_rad(attack_arc) / 2.0
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null:
			continue
		var offset := enemy.global_position - global_position
		if offset.length() > attack_range + enemy.body_radius:
			continue
		# Enemies standing right on top of the player are hit from any side.
		if offset.length() > enemy.body_radius and absf(direction.angle_to(offset)) > half_arc:
			continue
		var critical := randf() < stats.get_stat("critical_chance")
		var damage := stats.get_stat("physical_damage")
		if critical:
			damage *= stats.get_stat("critical_damage")
		var dealt := enemy.take_damage(damage, direction * attack_knockback, critical, weapon_type)
		if dealt > 0.0:
			Events.damage_dealt.emit(weapon_type, dealt)


func take_damage(amount: float, source_position: Vector2) -> void:
	if state == State.DEAD or _invulnerable_left > 0.0:
		return
	health.take_damage(amount)
	DamageNumber.spawn(get_parent(), global_position, amount, Color(0.95, 0.3, 0.3))
	if health.is_dead():
		state = State.DEAD
		velocity = Vector2.ZERO
		_visual.modulate.a = 0.0
		var xp_lost := leveling.apply_death_penalty()
		died.emit(xp_lost)
		Events.player_died.emit(xp_lost)
		return
	_invulnerable_left = hurt_invulnerability
	var resistance := stats.get_stat("knockback_resistance")
	velocity = source_position.direction_to(global_position) * 300.0 * (1.0 - resistance)


## Brings the player back at full health. Main calls this after moving them.
func revive() -> void:
	_restore_all()
	state = State.MOVE
	velocity = Vector2.ZERO
	_invulnerable_left = 1.5
	_visual.modulate.a = 1.0


func save_data() -> Dictionary:
	return {"class_id": class_id, "weapon_type": weapon_type}


func load_data(data: Dictionary) -> void:
	class_id = str(data.get("class_id", class_id))
	weapon_type = str(data.get("weapon_type", weapon_type))


func _process_move(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input != Vector2.ZERO:
		facing = input.normalized()
		_face_visual(input.x)
	velocity = velocity.move_toward(input * stats.get_stat("move_speed"), acceleration * delta)

	if Input.is_action_just_pressed("dodge") and _dodge_cooldown_left == 0.0:
		_try_dodge()
	elif Input.is_action_pressed("attack") and _attack_cooldown_left == 0.0:
		var aim := get_global_mouse_position() - global_position
		attack(aim.normalized() if aim.length() > 1.0 else facing)


func _try_dodge() -> void:
	var cost := dodge_stamina_cost * stats.get_stat("stamina_cost_multiplier")
	if not stamina.spend(cost):
		return
	_dodge_direction = facing
	state = State.DODGE
	_state_time_left = dodge_duration
	_dodge_cooldown_left = dodge_cooldown / stats.get_stat("dodge_efficiency")
	_invulnerable_left = maxf(_invulnerable_left, dodge_duration)


func _apply_stats() -> void:
	health.set_max_health(stats.get_stat("max_health"))
	stamina.set_max(stats.get_stat("max_stamina"))
	mana.set_max(stats.get_stat("max_mana"))


func _restore_all() -> void:
	health.heal_full()
	stamina.fill()
	mana.fill()


func _on_leveled_up(_level: int) -> void:
	attributes.grant_points(Leveling.STAT_POINTS_PER_LEVEL)
	if state != State.DEAD:
		_restore_all()
	RingBurst.spawn(get_parent(), global_position + Vector2(0, -16), Color(1.0, 0.82, 0.3))


func _face_visual(x: float) -> void:
	if absf(x) > 0.1:
		_visual.scale.x = signf(x)
