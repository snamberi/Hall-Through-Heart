class_name Enemy
extends CharacterBody2D
## A melee enemy: wanders, chases the player, winds up, then lunges.
##
## The wind-up is the player's cue to dodge. Tune a new enemy type by
## changing the exported numbers on its scene.

signal died(enemy: Enemy)

enum State { WANDER, CHASE, WINDUP, LUNGE, RECOVER, STAGGER, DEAD }
enum Rank { NORMAL, ELITE }

## How each rank changes an enemy. "xp" 3.75 makes an Elite Husk worth 30.
const RANK_DATA := {
	Rank.NORMAL: {"id": "normal", "title": "", "health": 1.0, "damage": 1.0, "xp": 1.0, "size": 1.0, "tint": Color.WHITE},
	Rank.ELITE: {"id": "elite", "title": "Elite ", "health": 3.0, "damage": 1.4, "xp": 3.75, "size": 1.3, "tint": Color(1.0, 0.8, 0.55)},
}
## Extra health and damage per level above 1, as a share of the base value.
const HEALTH_PER_LEVEL := 0.25
const DAMAGE_PER_LEVEL := 0.12
## Experience grows with level to this power.
const XP_LEVEL_EXPONENT := 1.25

@export_group("Identity")
## Stable id used by saves, quests, and loot tables. Never rename it.
@export var enemy_id := "husk"
@export var display_name := "Husk"

@export_group("Movement")
@export var move_speed := 105.0
## Roughly how wide the enemy is; used for hits and for spacing from others.
@export var body_radius := 13.0

@export_group("Rewards")
## Experience a level 1 normal enemy of this type gives.
@export var base_xp := 8

@export_group("Senses")
## The enemy notices the player inside this distance, in pixels.
@export var aggro_radius := 270.0
## The enemy gives up once the player is this far away.
@export var leash_radius := 520.0

@export_group("Attack")
@export var contact_damage := 10.0
## The enemy starts its wind-up when the player is this close.
@export var attack_range := 76.0
@export var windup_time := 0.45
@export var lunge_speed := 470.0
@export var lunge_time := 0.22
@export var recover_time := 0.7

var target: Player
var state := State.WANDER
var level := 1
var rank := Rank.NORMAL

var _state_time_left := 0.0
var _direction := Vector2.ZERO
var _has_hit := false
var _flash_tween: Tween
var _damage := 0.0
var _tint := Color.WHITE
var _last_weapon_type := ""
## status id -> {"time": seconds left, "power": float, "tick": seconds to next tick}
var _statuses: Dictionary = {}

@onready var health: Health = $Health
@onready var _visual: Node2D = $Visual
@onready var _animator: EnemyAnimator = $Visual/Sprite


## Sets level and rank. Call before adding the enemy to the scene.
func configure(p_level: int, p_rank: Rank = Rank.NORMAL) -> void:
	level = maxi(p_level, 1)
	rank = p_rank


func _ready() -> void:
	add_to_group("enemies")
	var data: Dictionary = RANK_DATA[rank]
	health.max_health *= data["health"] * (1.0 + HEALTH_PER_LEVEL * (level - 1))
	health.current = health.max_health
	_damage = contact_damage * data["damage"] * (1.0 + DAMAGE_PER_LEVEL * (level - 1))
	_tint = data["tint"]
	_visual.scale *= data["size"]
	_visual.modulate = _tint
	body_radius *= data["size"]
	_add_nameplate(data)
	health.died.connect(_on_died)
	_pick_wander()


## Experience this enemy is worth at its level and rank.
func xp_value() -> int:
	return roundi(base_xp * RANK_DATA[rank]["xp"] * pow(level, XP_LEVEL_EXPONENT))


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_state_time_left = maxf(_state_time_left - delta, 0.0)
	_update_statuses(delta)
	if state == State.DEAD:
		return
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
				_visual.modulate = Color(1.8, 0.5, 0.5)
			else:
				velocity = to_target.normalized() * move_speed + _separation()
		State.WINDUP:
			velocity = Vector2.ZERO
			if has_target:
				_direction = to_target.normalized()
			if _state_time_left == 0.0:
				_enter(State.LUNGE, lunge_time)
				_has_hit = false
				_visual.modulate = _tint
		State.LUNGE:
			velocity = _direction * lunge_speed
			if has_target and not _has_hit and to_target.length() < body_radius + 13.0:
				_has_hit = true
				target.take_damage(_damage, global_position, level)
			if _state_time_left == 0.0:
				_enter(State.RECOVER, recover_time)
		State.RECOVER:
			velocity = velocity.move_toward(Vector2.ZERO, 2000.0 * delta)
			if _state_time_left == 0.0:
				state = State.CHASE
		State.STAGGER:
			velocity = velocity.move_toward(Vector2.ZERO, 1600.0 * delta)
			if _state_time_left == 0.0:
				state = State.CHASE

	if absf(velocity.x) > 1.0:
		_visual.scale.x = absf(_visual.scale.x) * signf(velocity.x)
	if _statuses.has("chill"):
		velocity *= 1.0 - _statuses["chill"]["power"]
	move_and_slide()


## Returns the health actually removed, so callers can reward real damage only.
func take_damage(
	amount: float, knockback: Vector2, critical: bool = false, weapon_type: String = ""
) -> float:
	if state == State.DEAD:
		return 0.0
	var color := Color(1.0, 0.8, 0.25) if critical else Color(0.95, 0.9, 0.75)
	DamageNumber.spawn(get_parent(), global_position, amount, color, critical)
	_last_weapon_type = weapon_type
	var dealt := health.take_damage(amount)
	if health.is_dead():
		return dealt
	_enter(State.STAGGER, 0.22)
	velocity = knockback
	_flash()
	return dealt


## Inflicts a status (see ItemDB.STATUSES), or refreshes it if stronger.
## For burn, poison, and bleed, `power` is damage per second.
func apply_status(id: String, duration: float, power: float, weapon_type: String = "") -> void:
	if state == State.DEAD:
		return
	var current: Dictionary = _statuses.get(id, {})
	_statuses[id] = {
		"time": maxf(duration, current.get("time", 0.0)),
		"power": maxf(power, current.get("power", 0.0)),
		"tick": current.get("tick", 0.5),
	}
	if weapon_type != "":
		_last_weapon_type = weapon_type
	_refresh_status_tint()


func has_status(id: String) -> bool:
	return _statuses.has(id)


func _update_statuses(delta: float) -> void:
	if _statuses.is_empty():
		return
	for id: String in _statuses.keys():
		var status: Dictionary = _statuses[id]
		status["time"] -= delta
		if id != "chill":
			status["tick"] -= delta
			if status["tick"] <= 0.0:
				status["tick"] += 0.5
				var amount: float = maxf(status["power"] * 0.5, 1.0)
				DamageNumber.spawn(get_parent(), global_position, amount, ItemDB.STATUSES[id]["color"])
				health.take_damage(amount)
				if health.is_dead():
					return
		if status["time"] <= 0.0:
			_statuses.erase(id)
	_refresh_status_tint()


## Tints the whole enemy toward the colour of the status it suffers.
func _refresh_status_tint() -> void:
	var tint := Color.WHITE
	for id: String in _statuses:
		tint = tint.lerp(ItemDB.STATUSES[id]["color"], 0.45)
	modulate = Color(tint, modulate.a)


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
		var spacing := body_radius + other.body_radius + 8.0
		if offset.length() < spacing and offset.length() > 0.01:
			push += offset.normalized() * (spacing - offset.length()) * 6.0
	return push


func _flash() -> void:
	if _flash_tween:
		_flash_tween.kill()
	_visual.modulate = Color(4.0, 4.0, 4.0)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_visual, "modulate", _tint, 0.15)


func _on_died() -> void:
	state = State.DEAD
	_statuses.clear()
	_refresh_status_tint()
	remove_from_group("enemies")
	velocity = Vector2.ZERO
	$Collision.set_deferred("disabled", true)
	var xp := xp_value()
	DamageNumber.spawn_text(
		get_parent(), global_position + Vector2(0, -24), "+%d XP" % xp, Color(0.45, 0.7, 1.0), 12
	)
	died.emit(self)
	Events.enemy_killed.emit({
		"id": enemy_id,
		"name": display_name,
		"level": level,
		"rank": RANK_DATA[rank]["id"],
		"xp": xp,
		"xp_multiplier": RANK_DATA[rank]["xp"],
		"position": global_position,
		"weapon_type": _last_weapon_type,
	})
	if _flash_tween:
		_flash_tween.kill()
	$HealthBar.visible = false
	_visual.modulate = Color(4.0, 4.0, 4.0)
	var tween := create_tween()
	tween.tween_property(_visual, "modulate", _tint, 0.15)
	# Let the collapse play, lie still a moment, then fade away.
	tween.tween_interval(_animator.death_seconds() + 0.25)
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)


func _add_nameplate(data: Dictionary) -> void:
	var label := Label.new()
	label.text = "Lv %d %s%s" % [level, data["title"], display_name]
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.4) if rank != Rank.NORMAL else Color(0.82, 0.8, 0.74))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	# The camera zooms in 2x; shrink so the text stays small and sharp.
	label.scale = Vector2.ONE / 2.0
	label.position = Vector2(-label.get_minimum_size().x / 4.0, -50.0 * data["size"] - 14.0)
	label.z_index = 10
	add_child(label)
	$HealthBar.position.y = -50.0 * data["size"]
