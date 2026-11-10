class_name Player
extends CharacterBody2D
## The player character: movement, attacking, dodging, and taking damage.
##
## Progression lives in the child modules (Leveling, Attributes, Mastery,
## Stats); this script only reads the numbers they produce.

signal died(xp_lost: int)
## The rebirth animation has ended and the player can move again.
signal rebirth_finished
signal class_changed

enum State { MOVE, ATTACK, DODGE, DEAD, REVIVING, ABILITY }

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
## Whether a worn helmet is drawn on the character.
var show_helmet := true:
	set(value):
		show_helmet = value
		if is_node_ready():
			_on_equipment_changed()
			SaveGame.request_save()
## Last direction the player moved or attacked in.
var facing := Vector2.DOWN
var state := State.MOVE

var _state_time_left := 0.0
var _attack_cooldown_left := 0.0
var _dodge_cooldown_left := 0.0
var _invulnerable_left := 0.0
var _dodge_direction := Vector2.ZERO
## Seconds until the Unbreakable talent can save the player again.
var _unbreakable_left := 0.0

@onready var health: Health = $Health
@onready var stamina: ResourcePool = $Stamina
@onready var mana: ResourcePool = $Mana
@onready var leveling: Leveling = $Leveling
@onready var attributes: Attributes = $Attributes
@onready var mastery: WeaponMastery = $Mastery
@onready var stats: CharacterStats = $Stats
@onready var inventory: Inventory = $Inventory
@onready var equipment: Equipment = $Equipment
@onready var abilities: AbilityUser = $Abilities
@onready var buffs: Buffs = $Buffs
@onready var talents: Talents = $Talents
@onready var camera: Camera2D = $Camera
@onready var _visual: Node2D = $Visual
@onready var _animator: PlayerAnimator = $Visual/Sprite
@onready var _slash: SlashEffect = $Slash


func _ready() -> void:
	SaveGame.register("character", self)
	stats.setup(attributes, mastery)
	buffs.setup(stats)
	talents.setup(leveling, stats)
	_apply_class()
	equipment.setup(inventory, leveling, attributes)
	if not inventory.starter_given:
		# A new character starts empty-handed with a sword in the bag.
		inventory.starter_given = true
		inventory.add(LootGenerator.make_equipment(1, 0, "sword"))
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
	_unbreakable_left = maxf(_unbreakable_left - delta, 0.0)
	health.heal(stats.get_stat("health_regen") * delta)

	match state:
		State.MOVE:
			_process_move(delta)
		State.ATTACK:
			velocity = velocity.move_toward(Vector2.ZERO, acceleration * delta)
			if _state_time_left == 0.0:
				state = State.MOVE
		State.DODGE:
			velocity = _dodge_direction * dodge_speed * stats.get_stat("dodge_distance")
			if _state_time_left == 0.0:
				state = State.MOVE
		State.ABILITY:
			# AbilityUser steers the player and ends this state.
			pass

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
	_attack_cooldown_left = weapon["cooldown"] / stats.get_stat("attack_speed")
	velocity = direction * 130.0
	# The swing animation fills the gap until the next swing is ready.
	_animator.play_attack(clampf(_attack_cooldown_left, attack_duration, 0.4))
	if weapon.has("projectile"):
		var config: Dictionary = weapon["projectile"].duplicate()
		config["knockback"] = weapon["knockback"]
		Projectile.fire(self, direction, config, _weapon_multiplier())
		return
	show_slash(direction, weapon["range"], weapon["arc"])
	strike_arc(direction, weapon["range"], weapon["arc"], 1.0, weapon["knockback"])


## Damages every enemy in a cone in front of the player. `multiplier` scales
## the player's physical damage. Returns how many enemies were hit.
func strike_arc(
	direction: Vector2, reach: float, arc_degrees: float, multiplier: float, knockback: float,
	already_hit: Variant = null
) -> int:
	# Pass an array to collect who was hit and to skip anyone already in it.
	if already_hit == null:
		already_hit = []
	var half_arc := deg_to_rad(arc_degrees) / 2.0
	var hits := 0
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy in already_hit:
			continue
		var offset := enemy.global_position - global_position
		if offset.length() > reach + enemy.body_radius:
			continue
		# Enemies standing right on top of the player are hit from any side.
		if offset.length() > enemy.body_radius and absf(direction.angle_to(offset)) > half_arc:
			continue
		hit_enemy(enemy, multiplier, direction * knockback)
		already_hit.append(enemy)
		hits += 1
	return hits


## Damages every enemy within `radius` of a point, pushing them away from it.
func strike_circle(
	center: Vector2, radius: float, multiplier: float, knockback: float, already_hit: Variant = null
) -> int:
	if already_hit == null:
		already_hit = []
	var hits := 0
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy in already_hit:
			continue
		var offset := enemy.global_position - center
		if offset.length() > radius + enemy.body_radius:
			continue
		var push := offset.normalized() if offset.length() > 1.0 else facing
		hit_enemy(enemy, multiplier, push * knockback)
		already_hit.append(enemy)
		hits += 1
	return hits


func show_slash(
	direction: Vector2, reach: float, arc_degrees: float, duration: float = 0.24,
	color: Color = Color.TRANSPARENT
) -> void:
	_slash.play(direction, reach, deg_to_rad(arc_degrees), duration, color if color.a > 0.0 else weapon_color())


## Tint of the weapon in hand, for swings and ability effects.
func weapon_color() -> Color:
	var weapon := equipment.get_item("main_hand")
	return weapon.definition().get("slash", Color(0.95, 0.9, 0.8)) if weapon else Color(0.95, 0.9, 0.8)


## Short camera jolt for heavy impacts.
func shake_camera(strength: float = 6.0) -> void:
	var tween := create_tween()
	for i in 5:
		var offset := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength * (1.0 - i / 5.0)
		tween.tween_property(camera, "offset", offset, 0.035)
	tween.tween_property(camera, "offset", Vector2.ZERO, 0.035)


## Hands control to an ability: the player ignores input until end_ability().
func begin_ability(invulnerable_for: float = 0.0) -> void:
	state = State.ABILITY
	velocity = Vector2.ZERO
	_invulnerable_left = maxf(_invulnerable_left, invulnerable_for)


func end_ability() -> void:
	if state == State.ABILITY:
		state = State.MOVE
		velocity = Vector2.ZERO


## Direction from the player to the mouse, or the facing if the mouse is on them.
func aim_direction() -> Vector2:
	var aim := get_global_mouse_position() - global_position
	return aim.normalized() if aim.length() > 1.0 else facing


func face(direction: Vector2) -> void:
	facing = direction
	_face_visual(direction.x)


func play_attack_animation(duration: float, heavy: bool = false) -> void:
	_animator.play_attack(duration, heavy)


## One blow against one enemy: rolls a critical, deals the damage, and
## applies the weapon's effects, life steal, and mastery credit.
func hit_enemy(enemy: Enemy, multiplier: float, knockback: Vector2) -> void:
	var critical := randf() < stats.get_stat("critical_chance")
	var damage := stats.get_stat("physical_damage") * multiplier
	if critical:
		damage *= stats.get_stat("critical_damage")
	if talents.has("berserker") and health.current < health.max_health * 0.35:
		damage *= 1.4
	var type := weapon_type
	var dealt := enemy.take_damage(damage, knockback, critical, type)
	if dealt <= 0.0:
		return
	Events.damage_dealt.emit(type, dealt)
	var weapon := equipment.get_item("main_hand")
	var def: Dictionary = weapon.definition() if weapon else {}
	if def.has("on_hit"):
		var effect: Dictionary = def["on_hit"]
		var power: float = effect["power"] if effect["status"] == "chill" else effect["power"] * damage
		enemy.apply_status(effect["status"], effect["duration"], power, type)
	var life_steal: float = stats.get_stat("life_steal") + def.get("life_steal", 0.0)
	if life_steal > 0.0:
		# Capped so one enormous hit cannot refill the health bar.
		health.heal(minf(dealt * life_steal, health.max_health * 0.05))


## Chooses a class. Returns "" on success or why it was refused.
func choose_class(id: String) -> String:
	if not HeroClasses.CLASSES.has(id) or id == "adventurer":
		return "Unknown class."
	if leveling.level < HeroClasses.CHOICE_LEVEL:
		return "Requires level %d." % HeroClasses.CHOICE_LEVEL
	if class_id != "adventurer":
		var cost := class_change_cost()
		if inventory.gold < cost:
			return "Changing class costs %d gold." % cost
		inventory.add_gold(-cost)
	class_id = id
	_apply_class()
	_on_equipment_changed()
	class_changed.emit()
	abilities.changed.emit()
	SaveGame.request_save()
	return ""


func class_change_cost() -> int:
	return HeroClasses.RESET_COST_PER_LEVEL * leveling.level


func take_damage(amount: float, source_position: Vector2, attacker_level: int = 1) -> void:
	if is_dead():
		return
	if _invulnerable_left > 0.0:
		if state == State.DODGE and talents.has("perfect_dodge"):
			buffs.add("perfect_dodge", "Perfect Dodge", 5.0, {"critical_chance": {"flat": 0.3}})
		return
	amount = maxf(amount * (1.0 - stats.damage_reduction(attacker_level)) * stats.get_stat("damage_taken"), 1.0)
	if amount >= health.current and talents.has("unbreakable") and _unbreakable_left == 0.0:
		# The killing blow is turned into a near miss.
		_unbreakable_left = 120.0
		amount = health.current - 1.0
		_invulnerable_left = 2.0
		DamageNumber.spawn_text(get_parent(), global_position + Vector2(0, -40), "Unbreakable", UITheme.GOLD, 14)
	HitSpark.spawn(get_parent(), global_position + Vector2(0, -16), Color(0.95, 0.3, 0.3))
	health.take_damage(amount)
	DamageNumber.spawn(get_parent(), global_position, amount, Color(0.95, 0.3, 0.3))
	if health.is_dead():
		state = State.DEAD
		velocity = Vector2.ZERO
		camera.offset = Vector2.ZERO
		buffs.clear_all()
		_visual.modulate.a = 1.0
		_animator.play_death()
		var xp_lost := leveling.apply_death_penalty()
		died.emit(xp_lost)
		Events.player_died.emit(xp_lost)
		return
	_invulnerable_left = maxf(_invulnerable_left, hurt_invulnerability)
	if state == State.MOVE:
		_animator.play_hurt()
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
	return {"class_id": class_id, "show_helmet": show_helmet}


func load_data(data: Dictionary) -> void:
	class_id = str(data.get("class_id", class_id))
	show_helmet = bool(data.get("show_helmet", true))


func _process_move(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input != Vector2.ZERO:
		facing = input.normalized()
		_face_visual(input.x)
	velocity = velocity.move_toward(input * stats.get_stat("move_speed"), acceleration * delta)

	if Input.is_action_just_pressed("dodge") and _dodge_cooldown_left == 0.0:
		_try_dodge()
	elif abilities.try_use_pressed():
		pass
	elif Input.is_action_pressed("attack") and _attack_cooldown_left == 0.0:
		attack(aim_direction())


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
	stamina.regen_per_second = stats.get_stat("stamina_regen")
	mana.set_max(stats.get_stat("max_mana"))
	mana.regen_per_second = stats.get_stat("mana_regen")


func _on_equipment_changed() -> void:
	_animator.update_equipment(equipment, show_helmet)
	stats.weapon_type = weapon_type
	stats.set_modifiers("equipment", equipment.modifiers())
	# A class hits harder with the weapon types it favours.
	var favoured: Array = HeroClasses.CLASSES[class_id]["weapons"]
	if weapon_type in favoured:
		stats.set_modifiers("class_weapon", {"physical_damage": {"percent": HeroClasses.WEAPON_BONUS}})
	else:
		stats.clear_modifiers("class_weapon")
	abilities.changed.emit()


func _apply_class() -> void:
	if not HeroClasses.CLASSES.has(class_id):
		class_id = "adventurer"
	stats.set_modifiers("class", HeroClasses.CLASSES[class_id]["mods"])


## Extra scaling for the weapon in hand: magic weapons use magic damage.
func _weapon_multiplier() -> float:
	var weapon := equipment.get_item("main_hand")
	if weapon and weapon.definition().get("magic", false):
		return stats.get_stat("magic_power")
	return 1.0


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
