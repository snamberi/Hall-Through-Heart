class_name AbilityUser
extends Node
## Lets the player use the abilities of the weapon in hand (keys 1-4).
##
## The bar always holds the abilities for the current weapon type, in unlock
## order. Cooldowns are tracked per ability, so they keep running while a
## different weapon is out.

signal changed

## ability id -> seconds left
var cooldowns: Dictionary[String, float] = {}

@onready var _player: Player = get_parent()


func _ready() -> void:
	Events.mastery_level_up.connect(func(_type: String, _level: int) -> void: changed.emit())


func _physics_process(delta: float) -> void:
	for id: String in cooldowns.keys():
		cooldowns[id] -= delta
		if cooldowns[id] <= 0.0:
			cooldowns.erase(id)


## Ability ids on the bar right now, one per slot.
func slots() -> Array[String]:
	var ids := AbilityDB.for_weapon(_player.weapon_type)
	return ids.slice(0, AbilityDB.SLOTS)


func rank(id: String) -> int:
	var weapon_type: String = AbilityDB.ABILITIES[id]["weapon"]
	return AbilityDB.rank(id, _player.mastery.levels.get(weapon_type, 1))


func stamina_cost(id: String) -> float:
	return AbilityDB.ABILITIES[id]["stamina"] * _player.stats.get_stat("stamina_cost_multiplier")


## Why an ability cannot be used right now, or "" if it can.
func blocked_reason(id: String) -> String:
	if rank(id) == 0:
		return "locked"
	if cooldowns.has(id):
		return "cooldown"
	if _player.stamina.current < stamina_cost(id):
		return "stamina"
	return ""


## Called by the player each frame while free to act. Uses the first ability
## whose key was just pressed; returns whether one started.
func try_use_pressed() -> bool:
	var ids := slots()
	for index in ids.size():
		if Input.is_action_just_pressed("ability_%d" % (index + 1)):
			return use(ids[index])
	return false


func use(id: String) -> bool:
	if _player.state != Player.State.MOVE or blocked_reason(id) != "":
		return false
	var ability: Dictionary = AbilityDB.ABILITIES[id]
	_player.stamina.spend(stamina_cost(id))
	cooldowns[id] = ability["cooldown"]
	changed.emit()
	_run(id, ability)
	return true


func _run(id: String, ability: Dictionary) -> void:
	var direction := _player.aim_direction()
	var damage := AbilityDB.damage(id, rank(id))
	var weapon := _player.equipment.weapon_profile()
	_player.face(direction)
	match ability["shape"]:
		"arc":
			await _arc(ability, direction, damage, weapon)
		"flurry":
			await _flurry(ability, direction, damage, weapon)
		"spin":
			await _spin(ability, damage)
		"slam":
			await _slam(ability, direction, damage)
		"dash":
			await _dash(ability, direction, damage)
		"leap":
			await _leap(ability, direction, damage)
	_player.end_ability()


func _arc(ability: Dictionary, direction: Vector2, damage: float, weapon: Dictionary) -> void:
	_player.begin_ability()
	_player.play_attack_animation(0.4, true)
	if not await _wait(0.18):
		return
	var reach: float = weapon["range"] * ability["reach"]
	_player.velocity = direction * 160.0
	_player.show_slash(direction, reach, ability["arc"], 0.32)
	var hit: Array = []
	if _player.strike_arc(direction, reach, ability["arc"], damage, ability["knockback"], hit) > 0:
		_player.shake_camera(5.0)
	_apply_status(ability, hit, damage)
	await _wait(0.2)


func _flurry(ability: Dictionary, direction: Vector2, damage: float, weapon: Dictionary) -> void:
	_player.begin_ability()
	var reach: float = weapon["range"] * ability["reach"]
	for i: int in ability["hits"]:
		_player.play_attack_animation(0.1)
		# Fan the swings a little so the flurry reads as separate strikes.
		var swing := direction.rotated(deg_to_rad(randf_range(-18.0, 18.0)))
		_player.show_slash(swing, reach, ability["arc"] * 0.6, 0.12)
		_player.strike_arc(direction, reach, ability["arc"], damage, ability["knockback"])
		_player.velocity = direction * 60.0
		if not await _wait(0.085):
			return


func _spin(ability: Dictionary, damage: float) -> void:
	_player.begin_ability()
	var hits: int = ability["hits"]
	for i in hits:
		_player.play_attack_animation(0.22)
		_player.show_slash(Vector2.RIGHT.rotated(i * 2.1), ability["radius"], 340.0, 0.24)
		RingBurst.spawn(_player.get_parent(), _player.global_position + Vector2(0, -14), _player.weapon_color(), ability["radius"])
		_player.strike_circle(_player.global_position, ability["radius"], damage, ability["knockback"])
		if not await _wait(0.2):
			return
	await _wait(0.08)


func _slam(ability: Dictionary, direction: Vector2, damage: float) -> void:
	_player.begin_ability()
	_player.play_attack_animation(0.55, true)
	if not await _wait(0.3):
		return
	_blast(_player.global_position + direction * ability["distance"], ability, damage)
	await _wait(0.25)


func _dash(ability: Dictionary, direction: Vector2, damage: float) -> void:
	var duration := 0.18
	_player.begin_ability(duration + 0.05)
	_player.play_attack_animation(duration)
	var hit: Array = []
	var elapsed := 0.0
	while elapsed < duration:
		_player.velocity = direction * ability["distance"] / duration
		_player.strike_circle(_player.global_position, ability["radius"], damage, ability["knockback"], hit)
		_spawn_trail()
		if not await _wait(0.03):
			return
		elapsed += 0.03
	_player.velocity = Vector2.ZERO
	await _wait(0.06)


func _leap(ability: Dictionary, direction: Vector2, damage: float) -> void:
	var duration := 0.3
	_player.begin_ability(duration)
	_player.play_attack_animation(duration + 0.2, true)
	var elapsed := 0.0
	while elapsed < duration:
		_player.velocity = direction * ability["distance"] / duration
		_spawn_trail()
		if not await _wait(0.03):
			return
		elapsed += 0.03
	_player.velocity = Vector2.ZERO
	_blast(_player.global_position, ability, damage)
	await _wait(0.22)


## A ground blast: ring, shake, and damage around a point.
func _blast(center: Vector2, ability: Dictionary, damage: float) -> void:
	RingBurst.spawn(_player.get_parent(), center, _player.weapon_color(), ability["radius"])
	RingBurst.spawn(_player.get_parent(), center, Color(0.9, 0.85, 0.7), ability["radius"] * 0.6)
	_player.shake_camera(9.0)
	var hit: Array = []
	_player.strike_circle(center, ability["radius"], damage, ability["knockback"], hit)
	_apply_status(ability, hit, damage)


func _apply_status(ability: Dictionary, enemies: Array, damage: float) -> void:
	if not ability.has("status"):
		return
	var effect: Dictionary = ability["status"]
	var hit_damage := _player.stats.get_stat("physical_damage") * damage
	for enemy: Enemy in enemies:
		if is_instance_valid(enemy):
			enemy.apply_status(effect["status"], effect["duration"], effect["power"] * hit_damage, _player.weapon_type)


func _spawn_trail() -> void:
	var sprite: AnimatedSprite2D = _player.get_node("Visual/Sprite")
	var ghost := Sprite2D.new()
	ghost.texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	ghost.global_position = sprite.global_position
	ghost.scale = sprite.global_scale
	ghost.modulate = Color(_player.weapon_color(), 0.45)
	_player.get_parent().add_child(ghost)
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.25)
	tween.tween_callback(ghost.queue_free)


## Waits, then reports whether the ability should carry on (false if the
## player died or was otherwise pulled out of it).
func _wait(seconds: float) -> bool:
	await get_tree().create_timer(seconds, false, true).timeout
	return _player.state == Player.State.ABILITY
