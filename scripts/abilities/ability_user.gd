class_name AbilityUser
extends Node
## The player's abilities: which are known, the eight on the bar (two sets
## of four, switched with a key), and using them with keys 1-4.
##
## Weapon abilities are known through mastery and only work with that kind
## of weapon in hand; class abilities are learned in the class tree.
## Cooldowns are tracked per ability, so they keep running while unequipped.

signal changed

## ability id -> seconds left
var cooldowns: Dictionary[String, float] = {}
## What sits in each of the eight slots ("" for empty).
var loadout: Array[String] = []
## Which set of four the keys use: 0 or 1.
var active_set := 0

@onready var _player: Player = get_parent()


func _ready() -> void:
	loadout.resize(AbilityDB.SLOTS)
	loadout.fill("")
	SaveGame.register("abilities", self)
	Events.mastery_level_up.connect(func(_type: String, _level: int) -> void:
		_fill_empty_slots()
		changed.emit()
	)
	changed.connect(_fill_empty_slots)


func _physics_process(delta: float) -> void:
	for id: String in cooldowns.keys():
		cooldowns[id] -= delta
		if cooldowns[id] <= 0.0:
			cooldowns.erase(id)


## Every ability the player has: weapon abilities their mastery has reached
## (for any weapon), and class abilities learned in their tree.
func known() -> Array[String]:
	var ids: Array[String] = []
	for id: String in AbilityDB.ABILITIES:
		var ability: Dictionary = AbilityDB.ABILITIES[id]
		if ability.has("class"):
			if ability["class"] == _player.class_id and _player.has_class_node(id):
				ids.append(id)
		elif rank(id) > 0:
			ids.append(id)
	return ids


## The four abilities the keys use right now.
func slots() -> Array[String]:
	return loadout.slice(active_set * AbilityDB.SET_SIZE, (active_set + 1) * AbilityDB.SET_SIZE)


func switch_set() -> void:
	active_set = (active_set + 1) % AbilityDB.SETS
	changed.emit()


## Puts an ability in a slot (0-7), moving it if it was already elsewhere.
func assign(slot: int, id: String) -> void:
	var previous := loadout.find(id)
	if previous != -1:
		loadout[previous] = loadout[slot]
	loadout[slot] = id
	changed.emit()
	SaveGame.request_save()


func clear_slot(slot: int) -> void:
	loadout[slot] = ""
	changed.emit()
	SaveGame.request_save()


func rank(id: String) -> int:
	var ability: Dictionary = AbilityDB.ABILITIES[id]
	if ability.has("class"):
		if ability["class"] != _player.class_id or not _player.has_class_node(id):
			return 0
		return AbilityDB.rank(id, _player.leveling.level)
	return AbilityDB.rank(id, _player.mastery.levels.get(ability["weapon"], 1))


func stamina_cost(id: String) -> float:
	return AbilityDB.ABILITIES[id].get("stamina", 0.0) * _player.stats.get_stat("stamina_cost_multiplier")


func mana_cost(id: String) -> float:
	return AbilityDB.ABILITIES[id].get("mana", 0.0)


## Why an ability cannot be used right now, or "" if it can.
func blocked_reason(id: String) -> String:
	if id == "":
		return "empty"
	if rank(id) == 0:
		return "locked"
	var ability: Dictionary = AbilityDB.ABILITIES[id]
	if ability.has("weapon") and ability["weapon"] != _player.weapon_type:
		return "weapon"
	if cooldowns.has(id):
		return "cooldown"
	if _player.stamina.current < stamina_cost(id):
		return "stamina"
	if _player.mana.current < mana_cost(id):
		return "mana"
	return ""


## Called by the player each frame while free to act. Uses the ability whose
## key was just pressed, or switches set; returns whether one started.
func try_use_pressed() -> bool:
	if Input.is_action_just_pressed("ability_swap"):
		switch_set()
		return false
	var ids := slots()
	for index in ids.size():
		var action := "ability_%d" % (index + 1)
		if InputMap.has_action(action) and Input.is_action_just_pressed(action):
			return use(ids[index])
	return false


func save_data() -> Dictionary:
	return {"loadout": loadout.duplicate(), "active_set": active_set}


func load_data(data: Dictionary) -> void:
	var saved: Variant = data.get("loadout", [])
	if saved is Array:
		for index in mini(saved.size(), AbilityDB.SLOTS):
			var id := str(saved[index])
			loadout[index] = id if AbilityDB.ABILITIES.has(id) else ""
	active_set = clampi(int(data.get("active_set", 0)), 0, AbilityDB.SETS - 1)


## New abilities go into the first free slots by themselves.
func _fill_empty_slots() -> void:
	if loadout.is_empty() or _player == null or not _player.is_node_ready():
		return
	for id in known():
		if id in loadout:
			continue
		var free := loadout.find("")
		if free == -1:
			return
		loadout[free] = id


func use(id: String) -> bool:
	if id == "" or _player.state != Player.State.MOVE or blocked_reason(id) != "":
		return false
	var ability: Dictionary = AbilityDB.ABILITIES[id]
	_player.stamina.spend(stamina_cost(id))
	_player.mana.spend(mana_cost(id))
	cooldowns[id] = ability["cooldown"]
	changed.emit()
	Events.codex_event.emit("abilities_used", 1)
	_run(id, ability)
	return true


func _run(id: String, ability: Dictionary) -> void:
	var direction := _player.aim_direction()
	var damage := AbilityDB.damage(id, rank(id))
	if ability.get("magic", false):
		damage *= _player.stats.get_stat("magic_power")
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
		"shot":
			await _shot(ability, direction, damage)
		"chain":
			await _chain(ability, direction, damage)
		"buff":
			_buff(id, ability)
	_player.end_ability()


func _arc(ability: Dictionary, direction: Vector2, damage: float, weapon: Dictionary) -> void:
	_player.begin_ability()
	_player.play_attack_animation(0.4, true)
	if not await _wait(0.18):
		return
	var reach: float = weapon["range"] * ability["reach"]
	_player.velocity = direction * 160.0
	_player.show_slash(direction, reach, ability["arc"], 0.32, _color(ability))
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
		_player.show_slash(Vector2.RIGHT.rotated(i * 2.1), ability["radius"], 340.0, 0.24, _color(ability))
		RingBurst.spawn(_player.get_parent(), _player.global_position + Vector2(0, -14), _color(ability), ability["radius"])
		var hit: Array = []
		_player.strike_circle(_player.global_position, ability["radius"], damage, ability["knockback"], hit)
		_apply_status(ability, hit, damage)
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


func _shot(ability: Dictionary, direction: Vector2, damage: float) -> void:
	_player.begin_ability()
	_player.play_attack_animation(0.3)
	if not await _wait(0.12):
		return
	var count: int = ability["count"]
	for i in count:
		var offset := 0.0 if count == 1 else lerpf(-0.5, 0.5, i / float(count - 1)) * deg_to_rad(ability["spread"])
		Projectile.fire(_player, direction.rotated(offset), ability["projectile"], damage)
	await _wait(0.16)


func _chain(ability: Dictionary, direction: Vector2, damage: float) -> void:
	_player.begin_ability()
	_player.play_attack_animation(0.3)
	if not await _wait(0.12):
		return
	var from := _player.global_position + Vector2(0, -14)
	var search: Vector2 = _player.global_position + direction * ability["reach"] * 0.5
	var reach: float = ability["reach"] * 0.6
	var struck: Array = []
	var points := PackedVector2Array([from])
	for i: int in ability["targets"]:
		var next := _nearest_enemy(search, reach, struck)
		if next == null:
			break
		struck.append(next)
		points.append(next.global_position + Vector2(0, -14))
		search = next.global_position
		reach = ability["jump"]
	if struck.is_empty():
		points.append(from + direction * ability["reach"] * 0.5)
	_draw_lightning(points, _color(ability))
	for enemy: Enemy in struck:
		_player.hit_enemy(enemy, damage, Vector2.ZERO)
		HitSpark.spawn(_player.get_parent(), enemy.global_position + Vector2(0, -14), _color(ability))
	await _wait(0.2)


func _buff(id: String, ability: Dictionary) -> void:
	_player.buffs.add(id, ability["name"], ability["duration"], ability["mods"])
	RingBurst.spawn(_player.get_parent(), _player.global_position + Vector2(0, -14), _color(ability), 80.0)
	RingBurst.spawn(_player.get_parent(), _player.global_position + Vector2(0, -14), Color.WHITE, 44.0)


func _nearest_enemy(point: Vector2, reach: float, excluding: Array) -> Enemy:
	var best: Enemy = null
	var best_distance := reach
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy in excluding:
			continue
		var distance := enemy.global_position.distance_to(point)
		if distance < best_distance:
			best_distance = distance
			best = enemy
	return best


## A jagged bolt through the given points that flickers out.
func _draw_lightning(points: PackedVector2Array, color: Color) -> void:
	var line := Line2D.new()
	line.width = 4.0
	line.default_color = color
	line.z_index = 60
	for i in points.size() - 1:
		line.add_point(points[i])
		for step in 3:
			var along := points[i].lerp(points[i + 1], (step + 1) / 4.0)
			line.add_point(along + Vector2(randf_range(-9, 9), randf_range(-9, 9)))
	line.add_point(points[-1])
	_player.get_parent().add_child(line)
	var tween := line.create_tween()
	tween.tween_property(line, "width", 1.0, 0.22)
	tween.parallel().tween_property(line, "modulate:a", 0.0, 0.22)
	tween.tween_callback(line.queue_free)


func _color(ability: Dictionary) -> Color:
	return ability.get("color", _player.weapon_color())


## A ground blast: ring, shake, and damage around a point.
func _blast(center: Vector2, ability: Dictionary, damage: float) -> void:
	RingBurst.spawn(_player.get_parent(), center, _color(ability), ability["radius"])
	RingBurst.spawn(_player.get_parent(), center, Color(0.9, 0.85, 0.7), ability["radius"] * 0.6)
	HitSpark.spawn(_player.get_parent(), center, _color(ability), true)
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
			var power: float = effect["power"] if effect["status"] == "chill" else effect["power"] * hit_damage
			enemy.apply_status(effect["status"], effect["duration"], power, _player.weapon_type)


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
