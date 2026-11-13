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
## The school of magic taken up at the Altar of Magic ("" for none), and
## every school the player has learned there (they may switch among these
## at the altar).
var magic_school := ""
var magic_schools: Array[String] = []
## Race evolution (EvolutionDB): the path chosen (-1 for none yet) and the
## stage reached on it (0-4).
var evolution_path := -1
var evolution_stage := 0
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
## Speed of a relic surge while it lasts (0 for an ordinary dodge).
var _surge_speed := 0.0
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
## The view pulls back a little in build mode (1 is normal).
var view_zoom := 1.0
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
## Parry: a short window in which a blow is turned aside and its attacker
## left open to a finisher.
const PARRY_WINDOW := 0.28
const PARRY_COOLDOWN := 0.9
const PARRY_STAMINA := 12.0
const EXPOSE_SECONDS := 2.0
const FINISHER_DAMAGE := 3.0
var parry_left := 0.0
var _parry_cooldown := 0.0

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
## Pride from beating stronger foes; it saps damage and speed (see Ego).
var ego: Ego
## The relic bag and the relics worn (see Relics).
var relics: Relics
## Combat styles known and the one in use (see StyleBook).
var styles: StyleBook
var hotbar: Hotbar
## Skin tone, hair, clothes, trousers and look (see Appearance).
var appearance: Dictionary = Appearance.DEFAULT.duplicate()
## The mount being ridden (Mount.MOUNTS id), or "".
var mount_id := ""
## What last hurt the player: an element, a status, or "blow". Shapes the
## words on the death screen.
var last_harm := "blow"
## Shift toggles between walking and sprinting; sprinting burns stamina.
var sprinting := false
const SPRINT_SPEED := 1.4
const SPRINT_STAMINA := 7.0
var _mount: Mount
var pets: Pets
## Sailing a rowboat: water is crossed quickly and dry.
var boating := false
const BOAT_SPEED := 1.35
@onready var talents: Talents = $Talents
@onready var professions: Professions = $Professions
@onready var quests: QuestLog = $Quests
@onready var camera: Camera2D = $Camera
@onready var _visual: Node2D = $Visual
@onready var _animator: PlayerAnimator = $Visual/Sprite
@onready var _slash: SlashEffect = $Slash


func _ready() -> void:
	SaveGame.register("character", self)
	if not SaveGame.get_section("character").has("appearance"):
		# A new world: the look and the class chosen when it was made.
		var meta := SaveGame.get_section("meta")
		var chosen: Variant = meta.get("appearance", {})
		if chosen is Dictionary:
			appearance.merge(chosen, true)
		var chosen_class := str(meta.get("class_id", "adventurer"))
		if HeroClasses.CLASSES.has(chosen_class) and chosen_class != "adventurer":
			class_id = chosen_class
			# Class points start to come at the level a class used to be chosen.
			class_chosen_at = HeroClasses.CHOICE_LEVEL
	_animator.apply_appearance(appearance)
	stats.setup(attributes, mastery)
	stats.set_modifiers_quietly("race", Appearance.race_mods(appearance))
	stats.set_modifiers_quietly("evolution", EvolutionDB.mods(race(), evolution_path, evolution_stage))
	buffs.setup(stats)
	StatusFX.attach(self, active_statuses, 44.0, 12.0)
	var uniques := Uniques.new()
	uniques.name = "Uniques"
	add_child(uniques)
	uniques.setup(self)
	ego = Ego.new()
	ego.name = "Ego"
	add_child(ego)
	relics = Relics.new()
	relics.name = "Relics"
	add_child(relics)
	styles = StyleBook.new()
	styles.name = "Styles"
	add_child(styles)
	styles.changed.connect(_on_equipment_changed)
	var hands := HandFX.new()
	hands.setup(self)
	add_child(hands)
	var aura := EgoAura.new()
	aura.setup(self)
	add_child(aura)
	_mount = Mount.new()
	_mount.name = "Mount"
	add_child(_mount)
	_mount.setup(self)
	SunShadow.follow(_mount)
	SunShadow.follow(_animator)
	var fader := OcclusionFader.new()
	add_child(fader)
	fader.setup(self)
	var boat := Boat.new()
	boat.name = "Boat"
	add_child(boat)
	boat.setup(self)
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
		equipment.stow_loose_tools()
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
	_confirm_break_left = maxf(_confirm_break_left - delta, 0.0)
	_invulnerable_left = maxf(_invulnerable_left - delta, 0.0)
	_state_time_left = maxf(_state_time_left - delta, 0.0)
	_unbreakable_left = maxf(_unbreakable_left - delta, 0.0)
	parry_left = maxf(parry_left - delta, 0.0)
	_parry_cooldown = maxf(_parry_cooldown - delta, 0.0)
	potion_cooldown_left = maxf(potion_cooldown_left - delta, 0.0)
	_combo_left = maxf(_combo_left - delta, 0.0)
	_read_ground()
	since_hurt += delta
	# Natural healing starts once the player has gone 5 seconds unhurt.
	var undying := talents.has("undying")
	if since_hurt > (2.0 if undying else 5.0):
		health.heal((health.max_health * (0.04 if undying else 0.02) + stats.get_stat("health_regen")) * delta)
	if state == State.MOVE or state == State.ATTACK:
		var zoom := _height_zoom / GameSettings.ui_scale * view_zoom
		camera.zoom = camera.zoom.lerp(Vector2(zoom, zoom), 1.5 * delta)
		# Settle exactly on the target: at these zooms tile and chunk edges
		# land on whole pixels, so no seams show between chunks.
		if absf(camera.zoom.x - zoom) < 0.01:
			camera.zoom = Vector2(zoom, zoom)
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
			velocity = _dodge_direction * (_surge_speed if _surge_speed > 0.0 else dodge_speed * stats.get_stat("dodge_distance"))
			if _state_time_left == 0.0:
				state = State.MOVE
				_surge_speed = 0.0
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
	if holding_magic() and not mana.spend(MagicDB.BOLT_MANA):
		DamageNumber.spawn_text(get_parent(), global_position + Vector2(0, -50), "Out of mana", Color(0.5, 0.7, 1.0), 12)
		return
	if fighting_bare():
		_style_strike(direction, reach, multiplier)
		return
	if weapon.has("projectile"):
		var config: Dictionary = weapon["projectile"].duplicate()
		config["knockback"] = weapon["knockback"]
		Projectile.fire(self, direction, config, _weapon_multiplier() * multiplier)
		var extra := Uniques.extra_projectiles(self)
		for index in extra:
			var spread := deg_to_rad(12.0) * (1 if index % 2 == 0 else -1) * (index / 2 + 1)
			Projectile.fire(self, direction.rotated(spread), config, _weapon_multiplier() * multiplier * 0.6)
		return
	# Each kind of weapon swings in its own way, trailing its element.
	_slash.play_weapon(str(weapon["type"]), SlashEffect.element_of(equipment.weapon()), direction, reach,
		deg_to_rad(weapon["arc"] * (1.2 if multiplier > 1.0 else 1.0)), 0.24, weapon_color())
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
		# No hitting through walls.
		if not has_line_to(enemy.global_position):
			continue
		hit_enemy(enemy, multiplier, direction * knockback)
		already_hit.append(enemy)
		hits += 1
	# Crates and barrels in the swing break open.
	for node in get_tree().get_nodes_in_group("breakables"):
		var prop := node as Prop
		if prop == null:
			continue
		var to_prop := prop.global_position - global_position
		if to_prop.length() > reach + 14.0:
			continue
		if to_prop.length() > 14.0 and absf(direction.angle_to(to_prop)) > half_arc:
			continue
		if not has_line_to(prop.global_position):
			continue
		prop.take_hit(self)
	return hits


## Whether a straight line from the player to `point` is clear of walls:
## terrain walls, stone walls, palisades and buildings block it; small
## props on the same physics layer (crates, chests, statues) do not.
func has_line_to(point: Vector2) -> bool:
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, point, TerrainTiles.WALL_COLLISION)
	var skip: Array[RID] = []
	for attempt in 6:
		query.exclude = skip
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			return true
		var collider := hit["collider"] as Node
		if collider is StaticBody2D and collider.get_parent() is Prop and collider.get_child_count() > 0:
			var shape := (collider.get_child(0) as CollisionShape2D).shape as CircleShape2D
			if shape != null and shape.radius < 20.0:
				skip.append(hit["rid"])
				continue
		return false
	return true


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
	if enemy.exposed_left > 0.0:
		# A finisher on a reeling foe: a sure, crushing blow, and the end of
		# anything ordinary that is already badly hurt.
		enemy.exposed_left = 0.0
		critical = true
		multiplier *= FINISHER_DAMAGE
		if enemy.rank < Enemy.Rank.MINIBOSS and enemy.health.current < enemy.health.max_health * 0.3:
			multiplier = maxf(multiplier, enemy.health.current / maxf(stats.get_stat("physical_damage"), 1.0) * 2.0)
		DamageNumber.spawn_text(get_parent(), enemy.global_position + Vector2(0, -60), "FINISHER", Color(1.0, 0.6, 0.3), 17)
		Events.codex_event.emit("finishers", 1)
		HitSpark.spawn(get_parent(), enemy.global_position + Vector2(0, -16), Color(1.0, 0.7, 0.3), true)
		RingBurst.spawn(get_parent(), enemy.global_position + Vector2(0, -14), Color(1.0, 0.6, 0.3), 70.0)
		shake_camera(9.0)
		slow_motion(0.25, 0.1)
	var damage := stats.get_stat("physical_damage") * multiplier
	var codex_node: Node = get_parent().get_node_or_null("Codex")
	if codex_node:
		# The Hunter's Mark: well-studied prey takes a little more.
		damage *= codex_node.damage_bonus(enemy.enemy_id)
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
	# Hit-stop: a blink of stillness on solid blows gives them weight.
	if critical:
		FeelFX.crit(enemy.global_position)
	if critical or multiplier >= 1.5:
		hit_stop(0.06)
	elif state == State.ATTACK:
		hit_stop(0.025)
	Events.damage_dealt.emit(type, dealt)
	var weapon := equipment.get_item("main_hand")
	var def: Dictionary = weapon.definition() if weapon else {}
	if weapon == null and fighting_bare() and styles.data().has("on_hit"):
		def = {"on_hit": styles.data()["on_hit"]}
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
	if item.definition().has("boat") and item in inventory.items:
		return board_boat()
	if item.definition().has("mount") and item in inventory.items:
		if mount_id == item.definition()["mount"]:
			dismount()
			return ""
		return ride(item.definition()["mount"])
	if item.id == "taming_treat" and item in inventory.items and pets:
		var problem := pets.tame(self)
		if problem == "":
			inventory.take(item.id, 1)
		return problem
	if Crops.by_seed(item.id) != "" and item in inventory.items:
		# Sow the nearest empty plot.
		var buildings: Buildings = get_parent().get_node("Buildings")
		var best: Dictionary = {}
		var best_distance := 90.0
		for record in buildings.records:
			if record["kind"] == "plot" and record.get("crop", "") == "" and record["where"] == "world":
				var distance := Vector2(record["x"], record["y"]).distance_to(global_position)
				if distance < best_distance:
					best_distance = distance
					best = record
		if best.is_empty():
			return "Stand by an empty farm plot to sow."
		return buildings.tend_plot(self, best, item.id)
	if item.definition().has("treasure_map") and item in inventory.items:
		var hunts: Node = get_parent().get_node_or_null("TreasureMaps")
		if hunts == null:
			return "This cannot be used here."
		var problem: String = hunts.read_map(self)
		if problem == "":
			inventory.take(item.id, 1)
		return problem
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
		var buff_id: String = use["buff"]
		var mods: Dictionary = use["mods"]
		var duration: float = use["duration"]
		var course := ItemDB.course_of(item.id)
		if course != "":
			# Food: one buff per course, made stronger and longer by the
			# eater's own cooking skill.
			buff_id = "food_" + course
			var skill := food_potency()
			duration *= 1.0 + (skill - 1.0) * 0.8
			var scaled := {}
			for stat: String in mods:
				scaled[stat] = {}
				for kind: String in mods[stat]:
					scaled[stat][kind] = float(mods[stat][kind]) * skill
			mods = scaled
		buffs.add(buff_id, use["name"], duration, mods, item.icon(), course if course != "" else "potion")
	Events.codex_event.emit("meals" if int(item.definition().get("icon", 0)) == 48 else "potions", 1)
	inventory.take(item.id, 1)
	RingBurst.spawn(get_parent(), global_position + Vector2(0, -14), item.tint(), 50.0)
	return ""


## How much more a meal does in this player's hands: +0.4% per level of
## cooking (up to +40%).
func food_potency() -> float:
	return 1.0 + professions.level("cooking") * 0.004


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
	if Atmosphere.weather in ["Rain", "Thunderstorm"] and tile in [TerrainTiles.Type.MUD, TerrainTiles.Type.BOG, TerrainTiles.Type.TAR, TerrainTiles.Type.DEAD_GRASS]:
		# Rain turns soft ground to mire.
		_ground_speed *= 0.8
	if mount_id != "":
		var steed: Dictionary = Mount.MOUNTS[mount_id]
		if TerrainTiles.is_water(tile) or indoors:
			dismount()
		else:
			if (steed.get("snow", false) and tile in [TerrainTiles.Type.SNOW, TerrainTiles.Type.FROSTPINE, TerrainTiles.Type.PEAK]) \
					or (steed.get("sand", false) and tile in [TerrainTiles.Type.SAND, TerrainTiles.Type.SALT]):
				_ground_speed = maxf(_ground_speed, 1.0)
			_ground_speed *= steed["speed"]
	if boating:
		if TerrainTiles.is_water(tile):
			_ground_speed = BOAT_SPEED
			swimming = false
			deep_water = false
			return
		# Run aground: step out, and the boat goes back in the pack.
		boating = false
		Events.splash.emit(global_position)
	var was_swimming := swimming
	swimming = TerrainTiles.is_water(tile)
	deep_water = tile == TerrainTiles.Type.DEEP_WATER
	if swimming and buffs.has("tidestride"):
		# The Tidewalker's relic: water is no slower than land.
		_ground_speed = maxf(_ground_speed, 1.0)
	if swimming != was_swimming:
		Events.splash.emit(global_position)
	# Climbing gives a wider view.
	_height_zoom = 1.5 if tile == TerrainTiles.Type.PEAK else 1.75 if tile == TerrainTiles.Type.ROCK else 2.0


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
	if parry_left > 0.0:
		_parried(source_position)
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
	last_harm = element if element != "" else "blow"
	health.take_damage(amount)
	DamageNumber.spawn(get_parent(), global_position, amount, Color(0.95, 0.3, 0.3))
	if health.is_dead():
		_die()
		return true
	_invulnerable_left = maxf(_invulnerable_left, hurt_invulnerability)
	if mount_id != "" and not Mount.MOUNTS[mount_id].get("steady", false):
		dismount()
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
			last_harm = id
			health.take_damage(amount)
			since_hurt = 0.0
			if health.is_dead():
				_die()
				return
		if affliction["time"] <= 0.0:
			_afflictions.erase(id)


## Mounts a steed: `id` from Mount.MOUNTS, or "" for the best whistle in the bag.
func ride(id: String) -> String:
	if id == "":
		var best := 0.0
		for item in inventory.items:
			if item and item.definition().has("mount"):
				var speed: float = Mount.MOUNTS[item.definition()["mount"]]["speed"]
				if speed > best:
					best = speed
					id = item.definition()["mount"]
		if id == "":
			return "You have no mount. Buy a whistle from a merchant."
	if indoors or swimming or boating or is_dead() or state != State.MOVE:
		return "You cannot ride here."
	mount_id = id
	_mount.ride(id)
	_visual.position.y = -Mount.SEAT
	RingBurst.spawn(get_parent(), global_position, Color(0.9, 0.85, 0.7), 40.0)
	Events.codex_event.emit("mounts", 1)
	return ""


func dismount() -> void:
	if mount_id == "":
		return
	mount_id = ""
	_mount.put_away()
	_visual.position.y = 0.0


## Puts the rowboat in the water beside the player and climbs in.
func board_boat() -> String:
	if boating:
		return "You are already afloat."
	if indoors or _world == null or is_dead() or state != State.MOVE:
		return "You cannot launch a boat here."
	var here := _world.world_to_cell(global_position)
	var best := Vector2i(999999, 0)
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var cell := here + Vector2i(dx, dy)
			if TerrainTiles.is_water(_world.generator.tile_type_at(cell)) and Vector2(cell - here).length() < Vector2(best - here).length():
				best = cell
	if best.x == 999999:
		return "Stand at the water's edge to launch the boat."
	global_position = _world.cell_to_world(best)
	boating = true
	swimming = false
	Events.splash.emit(global_position)
	Events.codex_event.emit("boats", 1)
	return ""


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


## Whether the school of magic is what the hand holds.
func holding_magic() -> bool:
	return equipment.active_slot == "weapon_1" and magic_school != "" and equipment.working_tool == null


## Whether the hand fights with the combat style.
func fighting_bare() -> bool:
	return equipment.active_slot == "combat" and equipment.working_tool == null


## Brief immunity, for moves that vanish or step out of harm's way.
func grant_invulnerability(seconds: float) -> void:
	_invulnerable_left = maxf(_invulnerable_left, seconds)


func race() -> String:
	return str(appearance.get("race", "human"))


## Why the next stage of a race path cannot be taken now, or "".
func evolution_blocked(path: int) -> String:
	if evolution_path != -1 and path != evolution_path:
		return "You have already taken another path."
	if evolution_stage >= 4:
		return "You have gone as far as this path goes."
	var need := EvolutionDB.cost(race(), path, evolution_stage + 1)
	if leveling.level < int(need["level"]):
		return "Reach level %d." % need["level"]
	var codex: Node = get_parent().get_node_or_null("Codex")
	var bosses: int = int(codex.stats.get("bosses", 0)) if codex else 0
	if bosses < int(need["bosses"]):
		return "Beat %d world boss%s (%d so far)." % [need["bosses"], "" if int(need["bosses"]) == 1 else "es", bosses]
	for id: String in need["items"]:
		if inventory.count_of(id) < int(need["items"][id]):
			return "Bring %d %s." % [need["items"][id], ItemDB.ITEMS[id]["name"]]
	return ""


## Takes the next stage of a race path: gives up the offering, changes for
## good, and takes the new gifts. Returns "" or why not.
func evolve(path: int) -> String:
	var problem := evolution_blocked(path)
	if problem != "":
		return problem
	var need := EvolutionDB.cost(race(), path, evolution_stage + 1)
	for id: String in need["items"]:
		inventory.take(id, int(need["items"][id]))
	evolution_path = path
	evolution_stage += 1
	_apply_evolution()
	var data: Dictionary = EvolutionDB.paths(race())[path]
	# From the second stage the path may change how the character looks.
	if evolution_stage >= 2 and data.has("look"):
		set_appearance(data["look"])
	Events.codex_event.emit("evolutions", 1)
	SaveGame.request_save()
	return ""


func _apply_evolution() -> void:
	stats.set_modifiers("evolution", EvolutionDB.mods(race(), evolution_path, evolution_stage))


## Takes up a school of magic (at the altar). Returns "" or why not.
func take_up_magic(school: String) -> String:
	if not MagicDB.SCHOOLS.has(school):
		return "No such magic."
	if not school in magic_schools:
		magic_schools.append(school)
	magic_school = school
	_on_equipment_changed()
	abilities.changed.emit()
	Events.codex_event.emit("magic", 1)
	SaveGame.request_save()
	return ""


func save_data() -> Dictionary:
	return {"evolution_path": evolution_path, "evolution_stage": evolution_stage, "magic_school": magic_school, "magic_schools": magic_schools.duplicate(), "class_id": class_id, "show_helmet": show_helmet, "class_chosen_at": class_chosen_at, "class_ranks": class_ranks.duplicate(), "appearance": appearance.duplicate()}


## Changes how the player looks and redraws them.
func set_appearance(changes: Dictionary) -> void:
	appearance.merge(changes, true)
	_animator.apply_appearance(appearance)
	stats.set_modifiers("race", Appearance.race_mods(appearance))
	SaveGame.request_save()


func load_data(data: Dictionary) -> void:
	class_id = str(data.get("class_id", class_id))
	magic_school = str(data.get("magic_school", ""))
	if not MagicDB.SCHOOLS.has(magic_school):
		magic_school = ""
	magic_schools.clear()
	for school: Variant in data.get("magic_schools", []):
		if MagicDB.SCHOOLS.has(str(school)):
			magic_schools.append(str(school))
	evolution_path = clampi(int(data.get("evolution_path", -1)), -1, 2)
	evolution_stage = clampi(int(data.get("evolution_stage", 0)), 0, 4) if evolution_path != -1 else 0
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
	var saved_look: Variant = data.get("appearance", SaveGame.get_section("meta").get("appearance", {}))
	if saved_look is Dictionary:
		appearance = Appearance.DEFAULT.duplicate()
		appearance.merge(saved_look, true)
	if is_node_ready():
		_animator.apply_appearance(appearance)
		stats.set_modifiers("race", Appearance.race_mods(appearance))
		_apply_evolution()


func _process_move(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input != Vector2.ZERO:
		facing = input.normalized()
		_face_visual(input.x)
	if Input.is_action_just_pressed("sprint"):
		sprinting = not sprinting
		DamageNumber.spawn_text(get_parent(), global_position + Vector2(0, -50), "Sprinting" if sprinting else "Walking", UITheme.DIM, 12)
	var pace := 1.0
	if sprinting and input != Vector2.ZERO and not swimming and mount_id == "" and parry_left == 0.0:
		# Out of breath: drop back to a walk until stamina returns.
		if stamina.current < 1.0:
			sprinting = false
		else:
			stamina.spend(SPRINT_STAMINA * stats.get_stat("stamina_cost_multiplier") * delta)
			pace = SPRINT_SPEED
	velocity = velocity.move_toward(input * stats.get_stat("move_speed") * _ground_speed * pace, acceleration * delta)
	if deep_water:
		# Both hands are busy keeping afloat.
		return

	if parry_left > 0.0:
		velocity *= 0.3
	if mount_id != "" and (Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("parry") \
			or Input.is_action_just_pressed("ability_1") or Input.is_action_just_pressed("ability_2") or Input.is_action_just_pressed("ability_3") or Input.is_action_just_pressed("ability_4")):
		dismount()
	if Input.is_action_just_pressed("mount"):
		if mount_id != "":
			dismount()
		else:
			var problem := ride("")
			if problem != "":
				DamageNumber.spawn_text(get_parent(), global_position + Vector2(0, -50), problem, UITheme.BAD, 13)
	_update_hover()
	if Input.is_action_just_pressed("dodge") and _dodge_cooldown_left == 0.0 and (not swimming or buffs.has("tidestride")):
		_try_dodge()
	elif abilities.try_use_pressed():
		pass
	elif Input.is_action_just_pressed("quick_use"):
		var problem := hotbar.use_quick()
		if problem != "":
			DamageNumber.spawn_text(get_parent(), global_position + Vector2(0, -50), problem, UITheme.BAD, 13)
	elif Input.is_action_just_pressed("interact") and _try_interact(not Input.is_action_just_pressed("parry")):
		pass
	elif Input.is_action_just_pressed("parry") and _parry_cooldown == 0.0 and not placing and not swimming:
		_start_parry()
	elif Input.is_action_just_pressed("recall_home"):
		Events.recall_requested.emit()
	elif Input.is_action_just_pressed("attack") and not placing and not HudMenuButton.hovered and _try_work():
		pass
	elif Input.is_action_pressed("attack") and _attack_cooldown_left == 0.0 and not placing and not HudMenuButton.hovered:
		attack(aim_direction())


func _start_parry() -> void:
	if not stamina.spend(PARRY_STAMINA * stats.get_stat("stamina_cost_multiplier")):
		return
	parry_left = PARRY_WINDOW
	_parry_cooldown = PARRY_COOLDOWN
	var direction := aim_direction()
	face(direction)
	_animator.play_attack(0.22, false)
	show_slash(direction, 38.0, 150.0, 0.2, Color(1.0, 0.95, 0.7))


## A blow caught in the parry window: no damage, and the attacker reels.
func _parried(source_position: Vector2) -> void:
	parry_left = 0.0
	_parry_cooldown = 0.15
	stamina.current = minf(stamina.current + PARRY_STAMINA, stamina.max_value)
	var attacker: Enemy = null
	var best := 170.0
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy and not enemy.health.is_dead():
			var distance := enemy.global_position.distance_to(source_position) + enemy.global_position.distance_to(global_position) * 0.5
			if distance < best:
				best = distance
				attacker = enemy
	if attacker:
		attacker.expose(EXPOSE_SECONDS)
	HitSpark.spawn(get_parent(), global_position + facing * 16.0 + Vector2(0, -16), Color(1.0, 0.95, 0.6), true)
	RingBurst.spawn(get_parent(), global_position + Vector2(0, -14), Color(1.0, 0.9, 0.5), 50.0)
	DamageNumber.spawn_text(get_parent(), global_position + Vector2(0, -46), "Parry!", UITheme.GOLD, 15)
	Events.codex_event.emit("parries", 1)
	Audio.play("hit", -2.0, 0.0)
	shake_camera(4.0)
	slow_motion(0.35, 0.12)


var _hit_stop_ready := 0.0


## A very short freeze of the whole game when a blow lands.
func hit_stop(seconds: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now < _hit_stop_ready or Engine.time_scale < 1.0:
		return
	_hit_stop_ready = now + 0.12
	slow_motion(0.08, seconds)


## Briefly slows the whole game for weight on a big moment.
func slow_motion(scale: float, seconds: float) -> void:
	Engine.time_scale = scale
	get_tree().create_timer(seconds, true, false, true).timeout.connect(func() -> void: Engine.time_scale = 1.0)


func _try_dodge() -> void:
	var cost := dodge_stamina_cost * stats.get_stat("stamina_cost_multiplier")
	if not stamina.spend(cost):
		return
	_dodge_direction = facing
	var start := global_position
	Gore.spray(get_parent(), global_position + Vector2(0, 14), "_dust", -facing, 7, false)
	get_tree().create_timer(dodge_duration).timeout.connect(func() -> void:
		if is_instance_valid(self):
			Uniques.on_dodge(self, start, global_position)
	)
	state = State.DODGE
	_state_time_left = dodge_duration
	_dodge_cooldown_left = dodge_cooldown / stats.get_stat("dodge_efficiency")
	_invulnerable_left = maxf(_invulnerable_left, dodge_duration)


## A rush in a direction that cannot be hit, for relic powers.
func surge(direction: Vector2, speed: float, seconds: float) -> void:
	if is_dead():
		return
	_dodge_direction = direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT
	state = State.DODGE
	_state_time_left = seconds
	_invulnerable_left = maxf(_invulnerable_left, seconds)
	velocity = _dodge_direction * speed
	_surge_speed = speed


func _apply_stats() -> void:
	health.set_max_health(stats.get_stat("max_health"))
	stamina.set_max(stats.get_stat("max_stamina"))
	stamina.regen_per_second = stats.get_stat("stamina_regen")
	mana.set_max(stats.get_stat("max_mana"))
	mana.regen_per_second = stats.get_stat("mana_regen")


func _on_equipment_changed() -> void:
	equipment.set_hand(styles.equipped if styles else "fist", magic_school)
	# A combat style's bonuses count only while fighting with it.
	if styles and fighting_bare():
		stats.set_modifiers_quietly("combat_style", styles.data().get("mods", {}))
	else:
		stats.set_modifiers_quietly("combat_style", {})
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
		if not node.visible:
			continue
		var distance: float = node.global_position.distance_to(global_position)
		if distance < best_distance:
			best_distance = distance
			best = node
	return best


## A farm animal (wild or your own) close enough to feed, or null.
func nearest_farm_animal() -> Node2D:
	var best: Node2D = null
	var best_distance := 70.0
	for node in get_tree().get_nodes_in_group("livestock") + get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy and (not Livestock.is_farm_animal(enemy.enemy_id) or enemy.state == Enemy.State.DEAD):
			continue
		var species: String = enemy.enemy_id if enemy else (node as Livestock).species
		if not (Livestock.SPECIES[species]["food"] as Array).any(func(food: String) -> bool: return inventory.count_of(food) > 0):
			continue
		var distance: float = node.global_position.distance_to(global_position)
		if distance < best_distance:
			best_distance = distance
			best = node
	return best


## Feeds a farm animal; a wild one is won over and becomes livestock.
func feed_animal(animal: Node2D) -> String:
	var tame := animal as Livestock
	if tame == null:
		var wild := animal as Enemy
		var food_ok := false
		for id: String in Livestock.SPECIES[wild.enemy_id]["food"]:
			food_ok = food_ok or inventory.count_of(id) > 0
		if not food_ok:
			return "It wants %s." % ItemDB.ITEMS[Livestock.SPECIES[wild.enemy_id]["food"][0]]["name"].to_lower()
		tame = Livestock.new().setup(wild.enemy_id, {"baby": false, "age": 0.0})
		tame.position = wild.global_position
		get_parent().get_node("Buildings").add_child(tame)
		wild.queue_free()
	return tame.feed(self)


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


## How near the mouse must be to a thing to count as pointing at it.
const POINT_RADIUS := 30.0

## The resource node the mouse is on (and the player can reach), lit up so
## it is clear what a click will do.
var hover_node: ResourceNode
## One of the player's own placed things under the mouse, for breaking.
var hover_record: Dictionary = {}
## The placed thing being broken down, while state is GATHER.
var break_record: Dictionary = {}
var _swing_left := 0.0
var _confirm_break_id := -1
var _confirm_break_left := 0.0


## Finds what the mouse is pointing at, each frame the player is free.
func _update_hover() -> void:
	var mouse := get_global_mouse_position()
	var found: ResourceNode = null
	var best := POINT_RADIUS
	for node: ResourceNode in get_tree().get_nodes_in_group("resource_nodes"):
		if node.global_position.distance_to(global_position) > ResourceNode.REACH + 14.0:
			continue
		# Trees are tall: point anywhere on the trunk or crown.
		var distance := minf(node.global_position.distance_to(mouse), (node.global_position + Vector2(0, -36)).distance_to(mouse) if node.is_tall() else INF)
		if distance < best:
			best = distance
			found = node
	if found != hover_node:
		if is_instance_valid(hover_node):
			hover_node.set_lit(false)
		hover_node = found
		if found:
			found.set_lit(true)
	hover_record = {}
	if found == null:
		var buildings: Buildings = get_parent().get_node_or_null("Buildings")
		if buildings:
			hover_record = buildings.record_at(mouse, global_position)


## Left click on something to work on: gather a node, or break down
## something of the player's own. Returns whether work began.
func _try_work() -> bool:
	if is_instance_valid(hover_node):
		_start_gathering(hover_node)
		return true
	if not hover_record.is_empty():
		var buildings: Buildings = get_parent().get_node("Buildings")
		var problem := buildings.take_down_problem(hover_record)
		if problem != "":
			DamageNumber.spawn_text(get_parent(), global_position + Vector2(0, -40), problem, UITheme.BAD, 12)
			return true
		# A house is not knocked down by one stray click.
		if hover_record["kind"] == "house" and (_confirm_break_id != hover_record["id"] or _confirm_break_left <= 0.0):
			_confirm_break_id = hover_record["id"]
			_confirm_break_left = 4.0
			Events.announcement.emit("TAKE DOWN YOUR HOUSE?", "Click it again to pack it up. Floors and upgrades are lost.")
			return true
		break_record = hover_record
		gather_target = null
		gather_seconds = 1.6 if hover_record["kind"] == "house" else 0.7
		gather_progress = 0.0
		_swing_left = 0.0
		state = State.GATHER
		velocity = Vector2.ZERO
		_take_tool("hatchet")
		return true
	return false


## Right click (or the interact key): talk, open, use. With the mouse it is
## whatever is pointed at; with the key, whatever is nearest. Returns
## whether there was something to do.
func _try_interact(by_key: bool) -> bool:
	var npc := nearest_npc()
	var prop := nearest_prop()
	if not by_key:
		var mouse := get_global_mouse_position()
		if npc and (npc.global_position + Vector2(0, -20)).distance_to(mouse) > 46.0:
			npc = null
		if prop and (prop.global_position + Vector2(0, -20)).distance_to(mouse) > maxf(46.0, prop.reach * 0.6):
			prop = null
	if npc:
		velocity = Vector2.ZERO
		Events.npc_interacted.emit(npc)
		return true
	var animal := nearest_farm_animal()
	# Feeding wins only with food in the bag, and over a building only when
	# the animal is the nearer of the two.
	if animal and prop and prop.global_position.distance_to(global_position) < animal.global_position.distance_to(global_position):
		animal = null
	if animal and (by_key or (animal.global_position + Vector2(0, -16)).distance_to(get_global_mouse_position()) < 40.0):
		DamageNumber.spawn_text(get_parent(), animal.global_position + Vector2(0, -56), feed_animal(animal), Color(1.0, 0.85, 0.9), 12)
		return true
	if prop:
		velocity = Vector2.ZERO
		prop.interact(self)
		return true
	if by_key:
		var node := nearest_resource()
		if node:
			_start_gathering(node)
			return true
	return false


func _start_gathering(node: ResourceNode) -> void:
	var reason := node.blocked_reason(self)
	if reason != "":
		DamageNumber.spawn_text(get_parent(), global_position + Vector2(0, -30), reason, UITheme.BAD, 12)
		return
	break_record = {}
	gather_target = node
	gather_seconds = node.gather_seconds(self)
	gather_progress = 0.0
	_swing_left = 0.0
	state = State.GATHER
	velocity = Vector2.ZERO
	_face_visual(node.global_position.x - global_position.x)
	_take_tool(node.tool_kind())


## Shows the right tool in hand for a job; "" for bare hands.
func _take_tool(kind: String) -> void:
	equipment.working_tool = equipment.tool(kind) if kind != "" else null
	_animator.update_equipment(equipment, show_helmet)


func _process_gather(delta: float) -> void:
	velocity = Vector2.ZERO
	var moving := Input.get_vector("move_left", "move_right", "move_up", "move_down") != Vector2.ZERO
	if moving or (break_record.is_empty() and not is_instance_valid(gather_target)):
		_stop_gathering()
		return
	# Swing the tool: each blow lands with a sound and a spray of chips.
	_swing_left -= delta
	if _swing_left <= 0.0:
		_swing_left = 0.5
		_animator.play_attack(0.38, false)
		get_tree().create_timer(0.2).timeout.connect(_work_blow)
	gather_progress += delta
	if gather_progress >= gather_seconds:
		if not break_record.is_empty():
			var record := break_record
			_stop_gathering()
			var problem: String = (get_parent().get_node("Buildings") as Buildings).take_down(record)
			if problem != "":
				DamageNumber.spawn_text(get_parent(), global_position + Vector2(0, -40), problem, UITheme.BAD, 12)
			return
		var node := gather_target
		_stop_gathering()
		node.harvest(self)


## One blow of the tool landing on what is being worked.
func _work_blow() -> void:
	if state != State.GATHER:
		return
	if not break_record.is_empty():
		Audio.play("chop", -6.0, 0.15)
		Gore.spray(get_parent(), Vector2(break_record["x"], break_record["y"]) if break_record["where"] == "world" else global_position + facing * 20.0, "_dust", Vector2.UP, 5, false)
		return
	if not is_instance_valid(gather_target):
		return
	match gather_target.kind():
		"tree":
			Audio.play("chop", -5.0, 0.15)
		"ore":
			Audio.play("mine", -7.0, 0.12)
		"fish":
			return
		_:
			Audio.play("pickup", -14.0, 0.2)
	gather_target.take_blow(global_position)


func _stop_gathering() -> void:
	gather_target = null
	break_record = {}
	gather_progress = 0.0
	if equipment.working_tool:
		equipment.working_tool = null
		_animator.update_equipment(equipment, show_helmet)
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
	if (weapon and weapon.definition().get("magic", false)) or holding_magic():
		return stats.get_stat("magic_power")
	return 1.0


## A plain attack with the combat style: each style lands its blows its own
## way (quick jabs, wide palms that push, a blink to the side, slow heavy
## blows that shake the ground, darting kicks, sweeping turns).
func _style_strike(direction: Vector2, reach: float, multiplier: float) -> void:
	var info := styles.data()
	var profile: Dictionary = info["profile"]
	var color: Color = info["color"]
	var arc: float = profile["arc"]
	var knockback: float = profile["knockback"]
	var element: String = info.get("element", "")
	match str(info.get("strike", "jab")):
		"palm":
			reach *= 1.1
			RingBurst.spawn(get_parent(), global_position + direction * reach * 0.6 + Vector2(0, -14), color, 26.0)
		"blink":
			# Step a little way through the dark before the blow lands.
			var hop := direction * 34.0
			if has_line_to(global_position + hop):
				global_position += hop
				HitSpark.spawn(get_parent(), global_position + Vector2(0, -16), color)
		"heavy":
			multiplier *= 1.15
			shake_camera(2.5)
			RingBurst.spawn(get_parent(), global_position + direction * reach * 0.7, color, 34.0)
		"kick":
			reach *= 1.15
			velocity = direction * 220.0
		"sweep":
			arc = minf(arc + 40.0, 340.0)
	_slash.play_weapon("unarmed", element, direction, reach, deg_to_rad(arc), 0.2, color)
	strike_arc(direction, reach, arc, multiplier, knockback)


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
