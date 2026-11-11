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

enum State { MOVE, ATTACK, DODGE, DEAD, REVIVING, ABILITY, GATHER }

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
## The level the class was chosen at, and ranks learned in its tree.
var class_chosen_at := 10
var class_ranks: Dictionary = {}
## Seconds until another potion can be drunk.
var potion_cooldown_left := 0.0
## The node being gathered from, how long it takes, and how far along.
var gather_target: ResourceNode
var gather_seconds := 0.0
var gather_progress := 0.0
## True while in deep water: slow, and unable to fight or gather.
var swimming := false
## True while choosing where to set something down; clicks place it
## instead of attacking.
var placing := false
## True in deep water: slower still.
var deep_water := false
## Seconds since the player was last hurt; health returns by itself after 5.
var since_hurt := 99.0
var _height_zoom := 2.0
var _unstick_left := 0.0
## True inside a house, cave, or other place off the world map.
var indoors := false
## Share of normal speed the ground underfoot allows.
var _ground_speed := 1.0
var _world: World
## Consecutive basic attacks, for the mastery combo finisher.
var _combo_count := 0
var _combo_left := 0.0
## status id -> {"time", "power", "tick"} for damage over time on the player.
var _afflictions: Dictionary = {}
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
var hotbar: Hotbar
@onready var talents: Talents = $Talents
@onready var professions: Professions = $Professions
@onready var quests: QuestLog = $Quests
@onready var camera: Camera2D = $Camera
@onready var _visual: Node2D = $Visual
@onready var _animator: PlayerAnimator = $Visual/Sprite
@onready var _slash: SlashEffect = $Slash


func _ready() -> void:
	SaveGame.register("character", self)
	stats.setup(attributes, mastery)
	buffs.setup(stats)
	StatusFX.attach(self, active_statuses, 44.0, 12.0)
	var uniques := Uniques.new()
	uniques.name = "Uniques"
	add_child(uniques)
	uniques.setup(self)
	hotbar = Hotbar.new()
	hotbar.name = "Hotbar"
	add_child(hotbar)
	talents.setup(leveling, stats)
	_apply_class()
	equipment.setup(inventory, leveling, attributes)
	if not inventory.starter_given:
		# A new character starts with nothing in hand; the first sword waits
		# in a chest at the Sanctuary.
		inventory.starter_given = true
	if not inventory.tools_given:
		# Older saves get the gathering tools too.
		inventory.tools_given = true
		for tool_id: String in ["worn_pickaxe", "worn_hatchet", "fishing_rod"]:
			inventory.add(Item.create(tool_id))
	mastery.changed.connect(_apply_mastery_passive)
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
	potion_cooldown_left = maxf(potion_cooldown_left - delta, 0.0)
	_combo_left = maxf(_combo_left - delta, 0.0)
	_read_ground()
	since_hurt += delta
	# Natural healing starts once the player has gone 5 seconds unhurt.
	var undying := talents.has("undying")
	if since_hurt > (2.0 if undying else 5.0):
		health.heal((health.max_health * (0.04 if undying else 0.02) + stats.get_stat("health_regen")) * delta)
	if state == State.MOVE or state == State.ATTACK:
		camera.zoom = camera.zoom.lerp(Vector2(_height_zoom, _height_zoom), 1.5 * delta)
	_unstick(delta)
	if not _afflictions.is_empty():
		_process_afflictions(delta)
		if state == State.DEAD:
			return

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
		State.GATHER:
			_process_gather(delta)

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
	Audio.play("swing", -6.0)
	# With enough mastery, every third attack in a row is a finisher.
	var multiplier := 1.0
	var reach: float = weapon["range"]
	if mastery.has_combo(weapon_type):
		_combo_count = _combo_count + 1 if _combo_left > 0.0 else 1
		_combo_left = _attack_cooldown_left + 0.6
		if _combo_count >= 3:
			_combo_count = 0
			multiplier = WeaponMastery.COMBO_DAMAGE
			reach *= 1.25
			shake_camera(4.0)
	if weapon.has("projectile"):
		var config: Dictionary = weapon["projectile"].duplicate()
		config["knockback"] = weapon["knockback"]
		Projectile.fire(self, direction, config, _weapon_multiplier() * multiplier)
		var extra := Uniques.extra_projectiles(self)
		for index in extra:
			var spread := deg_to_rad(12.0) * (1 if index % 2 == 0 else -1) * (index / 2 + 1)
			Projectile.fire(self, direction.rotated(spread), config, _weapon_multiplier() * multiplier * 0.6)
		return
	show_slash(direction, reach, weapon["arc"] * (1.2 if multiplier > 1.0 else 1.0))
	strike_arc(direction, reach, weapon["arc"], multiplier, weapon["knockback"])


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
	if not GameSettings.screen_shake:
		return
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
	if talents.has("executioner") and enemy.health.current < enemy.health.max_health * 0.3:
		damage *= 1.4
	var type := weapon_type
	var dealt := enemy.take_damage(damage, knockback, critical, type)
	if dealt <= 0.0:
		return
	# Elemental damage rides on top of the blow, against the monster's
	# weaknesses and resistances.
	for element in Elements.LIST:
		var extra := stats.get_stat(element + "_damage")
		if extra <= 0.0 or enemy.health.is_dead():
			continue
		extra *= multiplier * (stats.get_stat("critical_damage") if critical else 1.0) * Elements.multiplier(enemy.enemy_id, element)
		dealt += enemy.take_damage(extra, Vector2.ZERO, critical, type, element)
	Uniques.on_hit(self, enemy, damage)
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


## Uses a consumable from the bag. Returns "" on success or why it failed.
func use_item(item: Item) -> String:
	if not is_dead() and item.is_placeable() and item in inventory.items:
		if swimming:
			return "You cannot build while swimming."
		Events.placement_requested.emit(item)
		return ""
	if is_dead() or not item.is_consumable() or not item in inventory.items:
		return "This cannot be used."
	var use: Dictionary = item.definition()["use"]
	if not use.has("buff"):
		if potion_cooldown_left > 0.0:
			return "Wait %.0fs before another potion." % ceilf(potion_cooldown_left)
		potion_cooldown_left = 8.0
	if use.has("heal"):
		health.heal(health.max_health * use["heal"])
	if use.has("mana"):
		mana.current = minf(mana.current + mana.max_value * use["mana"], mana.max_value)
		mana.changed.emit(mana.current, mana.max_value)
	if use.has("stamina"):
		stamina.current = minf(stamina.current + stamina.max_value * use["stamina"], stamina.max_value)
		stamina.changed.emit(stamina.current, stamina.max_value)
	if use.has("buff"):
		buffs.add(use["buff"], use["name"], use["duration"], use["mods"])
	inventory.take(item.id, 1)
	RingBurst.spawn(get_parent(), global_position + Vector2(0, -14), item.tint(), 50.0)
	return ""


## Drinks a health potion if there is one (the quick-use key).
func quick_potion() -> void:
	for item in inventory.items:
		if item.id == "health_potion":
			use_item(item)
			return


## Looks at the tile underfoot: how fast it lets the player go, and whether
## they are swimming.
func _read_ground() -> void:
	if _world == null:
		_world = get_parent().get_node_or_null("World")
	if _world == null or _world.generator == null or indoors:
		_ground_speed = 1.0
		swimming = false
		return
	var tile := _world.tile_type_at_position(global_position)
	_ground_speed = TerrainTiles.speed(tile)
	var was_swimming := swimming
	swimming = TerrainTiles.is_water(tile)
	deep_water = tile == TerrainTiles.Type.DEEP_WATER
	if swimming != was_swimming:
		Events.splash.emit(global_position)
	# Climbing gives a wider view.
	_height_zoom = 1.7 if tile == TerrainTiles.Type.PEAK else 1.82 if tile == TerrainTiles.Type.ROCK else 2.0


## A safety net: if the player ever ends up inside a wall (a cave edge,
## say), put them on the nearest open floor.
func _unstick(delta: float) -> void:
	_unstick_left -= delta
	if _unstick_left > 0.0 or not indoors:
		return
	_unstick_left = 0.25
	var instances: Instances = get_parent().get_node_or_null("Instances")
	if instances == null or not instances.is_inside():
		return
	var room := instances.room
	var cell := Vector2i(((global_position - Room.ORIGIN) / TerrainTiles.TILE_SIZE).floor())
	if room.is_floor(cell):
		return
	var best := room.entry
	for candidate in room.cells:
		if room.is_floor(candidate) and (candidate - cell).length_squared() < (best - cell).length_squared():
			best = candidate
	global_position = room.cell_position(best)
	velocity = Vector2.ZERO


## The gatherable node closest to the player and in reach, or null.
func nearest_resource() -> ResourceNode:
	var best: ResourceNode = null
	var best_distance := ResourceNode.REACH
	for node in get_tree().get_nodes_in_group("resource_nodes"):
		var distance: float = node.global_position.distance_to(global_position)
		if distance < best_distance:
			best_distance = distance
			best = node
	return best


## Chooses a class, for good. Returns "" on success or why it was refused.
func choose_class(id: String) -> String:
	if not HeroClasses.CLASSES.has(id) or id == "adventurer":
		return "Unknown class."
	if leveling.level < HeroClasses.CHOICE_LEVEL:
		return "Requires level %d." % HeroClasses.CHOICE_LEVEL
	if class_id != "adventurer":
		return "Your path is already chosen."
	class_id = id
	class_chosen_at = leveling.level
	_apply_class()
	_on_equipment_changed()
	class_changed.emit()
	abilities.changed.emit()
	SaveGame.request_save()
	return ""


## Class points earned so far: one on choosing, then one every few levels.
func class_points_total() -> int:
	if class_id == "adventurer":
		return 0
	return 1 + maxi(leveling.level - class_chosen_at, 0) / HeroClasses.CLASS_POINT_LEVELS


func class_points_free() -> int:
	var spent := 0
	for id: String in class_ranks:
		spent += class_ranks[id]
	return class_points_total() - spent


## Whether a class ability or passive has been learned.
func has_class_node(id: String) -> bool:
	return class_ranks.get(id, 0) > 0


## Why a class tree node cannot be learned now, or "".
func class_node_problem(id: String) -> String:
	if class_id == "adventurer":
		return "Choose a class first."
	var tree: Dictionary = HeroClasses.TREES[class_id]
	for column: String in ["abilities", "passives"]:
		var entries: Array = tree[column]
		for index in entries.size():
			var entry: Array = entries[index]
			if entry[0] != id:
				continue
			var max_rank: int = 1 if column == "abilities" else entry[2]
			if class_ranks.get(id, 0) >= max_rank:
				return "Fully learned."
			if index > 0 and not has_class_node(entries[index - 1][0]):
				return "Learn the one above first."
			if column == "abilities" and leveling.level < entry[1]:
				return "Requires level %d." % entry[1]
			if class_points_free() <= 0:
				return "No class points."
			return ""
	return "Not part of your class."


func learn_class_node(id: String) -> bool:
	if class_node_problem(id) != "":
		return false
	class_ranks[id] = class_ranks.get(id, 0) + 1
	_apply_class()
	abilities.changed.emit()
	class_changed.emit()
	SaveGame.request_save()
	return true


## Hurts the player. Returns whether the blow landed (false if it was
## dodged or the player cannot be hurt right now).
func take_damage(amount: float, source_position: Vector2, attacker_level: int = 1, element: String = "") -> bool:
	if is_dead():
		return false
	if _invulnerable_left > 0.0:
		if state == State.DODGE and talents.has("perfect_dodge"):
			buffs.add("perfect_dodge", "Perfect Dodge", 5.0, {"critical_chance": {"flat": 0.3}})
		return false
	if element != "":
		# Part of the blow is the attacker's element; resistance turns it away.
		amount *= 1.0 - Elements.ATTACK_SHARE * Elements.resistance(stats, element)
	amount = maxf(amount * (1.0 - stats.damage_reduction(attacker_level)) * stats.get_stat("damage_taken") * Difficulty.damage_to_player(), 1.0)
	amount = Uniques.on_hurt(self, amount)
	if talents.has("last_stand") and health.current < health.max_health * 0.3:
		amount *= 0.7
	since_hurt = 0.0
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
		_die()
		return true
	_invulnerable_left = maxf(_invulnerable_left, hurt_invulnerability)
	if state == State.GATHER:
		_stop_gathering()
	if state == State.MOVE:
		_animator.play_hurt()
	var resistance := stats.get_stat("knockback_resistance")
	velocity = source_position.direction_to(global_position) * 300.0 * (1.0 - resistance)
	return true


## Statuses on the player now, for the effects drawn around them.
func active_statuses() -> Array:
	var ids: Array = _afflictions.keys()
	if buffs.active.has("chill"):
		ids.append("chill")
	return ids


## Inflicts a status on the player. Burn, poison, and bleed deal `power`
## damage per second; chill slows movement by `power` (0 to 1).
func apply_status(id: String, duration: float, power: float) -> void:
	if is_dead():
		return
	var info: Dictionary = ItemDB.STATUSES[id]
	if id == "chill":
		buffs.add("chill", "Chilled", duration, {"move_speed": {"percent": -minf(power, 0.8)}})
		return
	var current: Dictionary = _afflictions.get(id, {})
	_afflictions[id] = {"time": maxf(duration, current.get("time", 0.0)), "power": maxf(power, current.get("power", 0.0)), "tick": current.get("tick", 0.5)}
	buffs.add(id, info["name"], duration, {})


func _die() -> void:
	state = State.DEAD
	velocity = Vector2.ZERO
	camera.offset = Vector2.ZERO
	gather_target = null
	_afflictions.clear()
	buffs.clear_all()
	_visual.modulate.a = 1.0
	_animator.play_death()
	var xp_lost := leveling.apply_death_penalty()
	died.emit(xp_lost)
	Events.player_died.emit(xp_lost)


## Burn, poison, and bleed tick here; they ignore armour and dodging.
func _process_afflictions(delta: float) -> void:
	for id: String in _afflictions.keys():
		var affliction: Dictionary = _afflictions[id]
		affliction["time"] -= delta
		affliction["tick"] -= delta
		if affliction["tick"] <= 0.0:
			affliction["tick"] += 0.5
			var amount: float = maxf(affliction["power"] * 0.5, 1.0)
			DamageNumber.spawn(get_parent(), global_position, amount, ItemDB.STATUSES[id]["color"])
			health.take_damage(amount)
			since_hurt = 0.0
			if health.is_dead():
				_die()
				return
		if affliction["time"] <= 0.0:
			_afflictions.erase(id)


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
	return {"class_id": class_id, "show_helmet": show_helmet, "class_chosen_at": class_chosen_at, "class_ranks": class_ranks.duplicate()}


func load_data(data: Dictionary) -> void:
	class_id = str(data.get("class_id", class_id))
	class_chosen_at = int(data.get("class_chosen_at", HeroClasses.CHOICE_LEVEL))
	var saved_ranks: Variant = data.get("class_ranks", {})
	class_ranks.clear()
	if saved_ranks is Dictionary:
		for id: String in saved_ranks:
			class_ranks[id] = int(saved_ranks[id])
	# Classes chosen before trees existed keep their two abilities.
	if class_id != "adventurer" and class_ranks.is_empty() and not data.has("class_ranks"):
		for entry: Array in HeroClasses.TREES[class_id]["abilities"].slice(0, 2):
			class_ranks[entry[0]] = 1
	show_helmet = bool(data.get("show_helmet", true))


func _process_move(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input != Vector2.ZERO:
		facing = input.normalized()
		_face_visual(input.x)
	velocity = velocity.move_toward(input * stats.get_stat("move_speed") * _ground_speed, acceleration * delta)
	if deep_water:
		# Both hands are busy keeping afloat.
		return

	if Input.is_action_just_pressed("dodge") and _dodge_cooldown_left == 0.0 and not swimming:
		_try_dodge()
	elif abilities.try_use_pressed():
		pass
	elif Input.is_action_just_pressed("quick_potion"):
		quick_potion()
	elif Input.is_action_just_pressed("interact"):
		_start_gathering()
	elif Input.is_action_just_pressed("recall_home"):
		Events.recall_requested.emit()
	elif Input.is_action_just_pressed("dismantle"):
		Events.dismantle_requested.emit()
	elif Input.is_action_pressed("attack") and _attack_cooldown_left == 0.0 and not placing:
		attack(aim_direction())


func _try_dodge() -> void:
	var cost := dodge_stamina_cost * stats.get_stat("stamina_cost_multiplier")
	if not stamina.spend(cost):
		return
	_dodge_direction = facing
	var start := global_position
	get_tree().create_timer(dodge_duration).timeout.connect(func() -> void:
		if is_instance_valid(self):
			Uniques.on_dodge(self, start, global_position)
	)
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
	stats.set_modifiers_quietly("mastery_passive", mastery.passive_modifiers(weapon_type))
	stats.set_modifiers("equipment", equipment.modifiers())
	# A class hits harder with the weapon types it favours.
	var favoured: Array = HeroClasses.CLASSES[class_id]["weapons"]
	if weapon_type in favoured:
		stats.set_modifiers("class_weapon", {"physical_damage": {"percent": HeroClasses.WEAPON_BONUS}})
	else:
		stats.clear_modifiers("class_weapon")
	abilities.changed.emit()


## Bonuses earned through mastery of the weapon type in hand.
func _apply_mastery_passive() -> void:
	stats.set_modifiers_quietly("mastery_passive", mastery.passive_modifiers(weapon_type))


## The person closest to the player and in reach, or null.
func nearest_npc() -> Npc:
	var best: Npc = null
	var best_distance := Npc.REACH
	for node in get_tree().get_nodes_in_group("npcs"):
		var distance: float = node.global_position.distance_to(global_position)
		if distance < best_distance:
			best_distance = distance
			best = node
	return best


## Whether a crafting table is close enough to work at.
func near_crafting_table() -> bool:
	for table in get_tree().get_nodes_in_group("crafting_tables"):
		if table.global_position.distance_to(global_position) < 150.0:
			return true
	return false


## The usable prop closest to the player and in reach, or null.
func nearest_prop() -> Prop:
	var best: Prop = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group("props"):
		var distance: float = node.global_position.distance_to(global_position)
		if distance < node.reach and distance < best_distance:
			best_distance = distance
			best = node
	return best


func _start_gathering() -> void:
	var npc := nearest_npc()
	if npc:
		velocity = Vector2.ZERO
		Events.npc_interacted.emit(npc)
		return
	var prop := nearest_prop()
	if prop:
		velocity = Vector2.ZERO
		prop.interact(self)
		return
	var node := nearest_resource()
	if node == null:
		return
	var reason := node.blocked_reason(self)
	if reason != "":
		DamageNumber.spawn_text(get_parent(), global_position + Vector2(0, -30), reason, UITheme.BAD, 12)
		return
	gather_target = node
	gather_seconds = node.gather_seconds(self)
	gather_progress = 0.0
	state = State.GATHER
	velocity = Vector2.ZERO
	_face_visual(node.global_position.x - global_position.x)


func _process_gather(delta: float) -> void:
	velocity = Vector2.ZERO
	var moving := Input.get_vector("move_left", "move_right", "move_up", "move_down") != Vector2.ZERO
	if moving or not is_instance_valid(gather_target):
		_stop_gathering()
		return
	gather_progress += delta
	if gather_progress >= gather_seconds:
		var node := gather_target
		_stop_gathering()
		node.harvest(self)


func _stop_gathering() -> void:
	gather_target = null
	gather_progress = 0.0
	if state == State.GATHER:
		state = State.MOVE


func _apply_class() -> void:
	if not HeroClasses.CLASSES.has(class_id):
		class_id = "adventurer"
	stats.set_modifiers("class", HeroClasses.CLASSES[class_id]["mods"])
	# Passives learned in the class tree.
	var totals := {}
	if HeroClasses.TREES.has(class_id):
		for entry: Array in HeroClasses.TREES[class_id]["passives"]:
			var ranks: int = class_ranks.get(entry[0], 0)
			for stat: String in entry[3]:
				if not totals.has(stat):
					totals[stat] = {"flat": 0.0, "percent": 0.0}
				for kind: String in entry[3][stat]:
					totals[stat][kind] += entry[3][stat][kind] * ranks
	stats.set_modifiers("class_tree", totals)


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
