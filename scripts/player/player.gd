class_name Player
extends CharacterBody2D
## The player character: movement, attacking, dodging, and taking damage.
##
## Progression lives in the child modules (Leveling, Attributes, Mastery,
## Stats); this script only reads the numbers they produce.

signal died(xp_lost: int)
## The rebirth animation has ended and the player can move again.
signal rebirth_finished

enum State { MOVE, ATTACK, DODGE, DEAD, REVIVING }

@export_group("Movement")
## How quickly the player reaches full speed and stops, in pixels/second².
@export var acceleration := 2200.0

@export_group("Attack")
## How long the player is committed to a swing. Reach, arc, speed, and
## knockback come from the weapon in hand (see ItemDB).
@export var attack_duration := 0.16

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
var weapon_type: String:
	get:
		return equipment.weapon_profile()["type"]
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
@onready var inventory: Inventory = $Inventory
@onready var equipment: Equipment = $Equipment
@onready var camera: Camera2D = $Camera
@onready var _visual: Node2D = $Visual
@onready var _animator: PlayerAnimator = $Visual/Sprite
@onready var _slash: SlashEffect = $Slash


func _ready() -> void:
	SaveGame.register("character", self)
	stats.setup(attributes, mastery)
	equipment.setup(inventory, leveling, attributes)
	if not inventory.starter_given:
		inventory.starter_given = true
		equipment.equip_directly(LootGenerator.make_equipment(1, 0, "sword"))
	equipment.changed.connect(_on_equipment_changed)
	stats.changed.connect(_apply_stats)
	leveling.leveled_up.connect(_on_leveled_up)
	_on_equipment_changed()
	_apply_stats()
	_restore_all()


func _physics_process(delta: float) -> void:
	if state == State.DEAD or state == State.REVIVING:
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


## True while dead and while rising again; enemies ignore the player.
func is_dead() -> bool:
	return state == State.DEAD or state == State.REVIVING


## Swings at everything in an arc in front of the player.
func attack(direction: Vector2) -> void:
	facing = direction
	_face_visual(direction.x)
	state = State.ATTACK
	_state_time_left = attack_duration
	var weapon := equipment.weapon_profile()
	var attack_range: float = weapon["range"]
	var attack_arc: float = weapon["arc"]
	_attack_cooldown_left = weapon["cooldown"] / stats.get_stat("attack_speed")
	velocity = direction * 130.0
	# The swing animation fills the gap until the next swing is ready.
	_animator.play_attack(clampf(_attack_cooldown_left, attack_duration, 0.4))
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
		var dealt := enemy.take_damage(damage, direction * weapon["knockback"], critical, weapon_type)
		if dealt > 0.0:
			Events.damage_dealt.emit(weapon_type, dealt)


func take_damage(amount: float, source_position: Vector2, attacker_level: int = 1) -> void:
	if is_dead() or _invulnerable_left > 0.0:
		return
	amount = maxf(amount * (1.0 - stats.damage_reduction(attacker_level)), 1.0)
	health.take_damage(amount)
	DamageNumber.spawn(get_parent(), global_position, amount, Color(0.95, 0.3, 0.3))
	if health.is_dead():
		state = State.DEAD
		velocity = Vector2.ZERO
		_visual.modulate.a = 1.0
		_animator.play_death()
		var xp_lost := leveling.apply_death_penalty()
		died.emit(xp_lost)
		Events.player_died.emit(xp_lost)
		return
	_invulnerable_left = hurt_invulnerability
	var resistance := stats.get_stat("knockback_resistance")
	velocity = source_position.direction_to(global_position) * 300.0 * (1.0 - resistance)


## Starts rising from the ground at full health. Call after moving the
## player to where they wake; rebirth_finished fires when they can move.
func begin_rebirth() -> void:
	state = State.REVIVING
	_restore_all()
	velocity = Vector2.ZERO
	_visual.modulate.a = 1.0
	_animator.play_rebirth()
	await _animator.rebirth_finished
	state = State.MOVE
	_invulnerable_left = 1.5
	rebirth_finished.emit()


func save_data() -> Dictionary:
	return {"class_id": class_id}


func load_data(data: Dictionary) -> void:
	class_id = str(data.get("class_id", class_id))


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


func _on_equipment_changed() -> void:
	stats.weapon_type = weapon_type
	stats.set_modifiers("equipment", equipment.modifiers())


func _restore_all() -> void:
	health.heal_full()
	stamina.fill()
	mana.fill()


func _on_leveled_up(_level: int) -> void:
	attributes.grant_points(Leveling.STAT_POINTS_PER_LEVEL)
	if not is_dead():
		_restore_all()
	RingBurst.spawn(get_parent(), global_position + Vector2(0, -16), Color(1.0, 0.82, 0.3))


func _face_visual(x: float) -> void:
	if absf(x) > 0.1:
		_visual.scale.x = signf(x)
