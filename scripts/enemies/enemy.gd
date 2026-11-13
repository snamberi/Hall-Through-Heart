class_name Enemy
extends CharacterBody2D
## Any monster. What kind it is, how it attacks, and its buffs all come from
## its entry in EnemyDB; this script plays that entry out.
##
## Every attack has a wind-up the player can read: a red tint, and for area
## attacks a circle on the ground showing where it will land.

signal died(enemy: Enemy)

enum State { WANDER, CHASE, WINDUP, LUNGE, RECOVER, STAGGER, DEAD }
enum Rank { NORMAL, ELITE, CHAMPION, MINIBOSS, BOSS }

## How each rank changes an enemy. "xp" 3.75 makes an Elite Husk worth 30.
## "modifiers" is how many random modifiers the rank rolls.
const RANK_DATA := {
	Rank.NORMAL: {"id": "normal", "title": "", "health": 1.0, "damage": 1.0, "xp": 1.0, "size": 1.0, "tint": Color.WHITE, "modifiers": 0},
	Rank.ELITE: {"id": "elite", "title": "Elite ", "health": 3.2, "damage": 1.4, "xp": 3.75, "size": 1.3, "tint": Color(1.0, 0.8, 0.55), "modifiers": 1},
	Rank.CHAMPION: {"id": "champion", "title": "Champion ", "health": 6.0, "damage": 1.7, "xp": 9.0, "size": 1.5, "tint": Color(0.85, 0.65, 1.0), "modifiers": 2},
	Rank.MINIBOSS: {"id": "miniboss", "title": "Ancient ", "health": 14.0, "damage": 2.0, "xp": 30.0, "size": 1.9, "tint": Color(1.0, 0.72, 0.6), "modifiers": 2},
	Rank.BOSS: {"id": "boss", "title": "", "health": 70.0, "damage": 2.3, "xp": 120.0, "size": 1.0, "tint": Color.WHITE, "modifiers": 0},
}
## Random modifiers for Elites and Champions. Each changes how the enemy
## fights, not just its numbers, and each adds REWARD_PER_MODIFIER to its XP.
##   "traits"  standing buffs it gains (see EnemyDB.TRAITS)
##   "touch"   status its hits inflict
## Swift, Frozen Aura, Explosive, Poisonous, and Summoner have their own
## handling in this script.
const MODIFIERS := {
	"burning": {"name": "Burning", "color": Color(1.0, 0.55, 0.2), "touch": {"status": "burn", "duration": 3.0, "power": 0.3}},
	"frozen_aura": {"name": "Frozen", "color": Color(0.6, 0.9, 1.0)},
	"vampiric": {"name": "Vampiric", "color": Color(0.8, 0.2, 0.3), "traits": ["lifesteal"]},
	"armored": {"name": "Armored", "color": Color(0.7, 0.75, 0.8), "traits": ["armored"]},
	"swift": {"name": "Swift", "color": Color(0.6, 1.0, 0.6)},
	"explosive": {"name": "Explosive", "color": Color(1.0, 0.75, 0.3)},
	"poisonous": {"name": "Poisonous", "color": Color(0.6, 0.95, 0.4), "touch": {"status": "poison", "duration": 4.0, "power": 0.3}},
	"regenerating": {"name": "Regenerating", "color": Color(0.5, 0.9, 0.6), "traits": ["regen"]},
	"summoner": {"name": "Summoner", "color": Color(0.75, 0.55, 1.0)},
	"berserker": {"name": "Berserker", "color": Color(1.0, 0.3, 0.3), "traits": ["enrage"]},
	"shielded": {"name": "Shielded", "color": Color(0.55, 0.8, 1.0)},
	"thorns": {"name": "Thorned", "color": Color(0.75, 0.6, 0.35)},
	"evasive": {"name": "Evasive", "color": Color(0.85, 0.85, 0.95)},
	"giant": {"name": "Giant", "color": Color(0.9, 0.7, 0.5)},
	"splitting": {"name": "Splitting", "color": Color(0.5, 0.95, 0.7), "traits": ["split"]},
	"teleporting": {"name": "Phasing", "color": Color(0.65, 0.75, 1.0), "traits": ["blink"]},
	"molten": {"name": "Molten", "color": Color(1.0, 0.4, 0.15)},
	"bloodletter": {"name": "Bloodletter", "color": Color(0.9, 0.15, 0.2), "touch": {"status": "bleed", "duration": 4.0, "power": 0.35}},
}
## Shielded enemies carry a barrier worth this share of their health, which
## comes back after a while without being hit.
const SHIELD_SHARE := 0.35
const SHIELD_REGEN_DELAY := 5.0
const THORNS_SHARE := 0.15
const EVADE_CHANCE := 0.22
const REWARD_PER_MODIFIER := 0.25
## How much of a blow's shove each rank takes.
const POISE: Array[float] = [0.6, 0.35, 0.2, 0.08, 0.0]
const FROZEN_AURA_RADIUS := 170.0
const SUMMON_SECONDS := 8.0
const SUMMON_LIMIT := 3
## How much tougher monsters are than their listed health (wild animals
## keep theirs): a fair fight takes several blows, not one.
const TOUGHNESS := 2.5
## Extra health and damage per level above 1, as a share of the base value.
const HEALTH_PER_LEVEL := 0.25
const DAMAGE_PER_LEVEL := 0.12
## Experience grows with level to this power.
const XP_LEVEL_EXPONENT := 1.25
const AGGRO_RADIUS := 290.0
const LEASH_RADIUS := 560.0
## Seconds a monster takes, at the least, to heal from nothing to full.
const WOUNDS_LAST := 180.0

var enemy_id := "husk"
var display_name := "Husk"
var level := 1
var rank := Rank.NORMAL
var target: Player
var state := State.WANDER
## Roughly how wide the enemy is; used for hits and for spacing from others.
var body_radius := 13.0
## Shorter names for the animator.
var windup_time := 0.45
var lunge_time := 0.22
## Smaller copies made by the "split" trait do not split again.
var is_fragment := false
## Ids from MODIFIERS. Rolled for Elites and Champions unless set beforehand.
var modifiers: Array[String] = []
## Mini-bosses guard a spot and walk back to it rather than chase forever.
var lair_home := Vector2.INF
## Set before adding to the tree to make this a world boss (BossDB id).
var boss_id := ""
## A named miniboss (MinibossDB), or "".
var named_id := ""
## A name of its own (bounty marks), shown instead of its kind's.
var custom_name := ""
## Seconds left in which a hit is a finisher (after being parried).
var exposed_left := 0.0
var _nameplate: Label
var _plate_check := 0.0
var brain: BossBrain
## Asks whoever spawned this enemy for a minion (the Summoner modifier).
signal wants_minion(enemy: Enemy)

var _data: Dictionary
var _attack: Dictionary
var _traits: Array = []
var _state_time_left := 0.0
var _direction := Vector2.ZERO
var _has_hit := false
var _flash_tween: Tween
var _damage := 0.0
var _speed := 100.0
var _tint := Color.WHITE
var _last_weapon_type := ""
var _since_hurt := 99.0
var _blink_left := 3.0
var _aura_left := 0.0
## Seconds until a hit can interrupt this enemy again.
var _stagger_cooldown := 0.0
## Walkers slow down in water; the ground is checked a few times a second.
var _ground_speed := 1.0
var _ground_left := 0.0
var in_water := false
## Chasing but not getting anywhere: try a way round.
var _stuck_time := 0.0
var _detour := Vector2.ZERO
var _detour_left := 0.0
## The Shielded modifier's barrier, used up before health.
var shield := 0.0
var shield_max := 0.0
var _molten_left := 0.0
var _summon_left := SUMMON_SECONDS
var _minions := 0
var _weave := 0.0
## Swipes left in a combo; the pounce's start, end and progress; a charge
## that hit a wall.
var _combo_left := 0
var _pounce_from := Vector2.ZERO
var _pounce_to := Vector2.ZERO
var _pouncing := false
## status id -> {"time": seconds left, "power": float, "tick": seconds to next tick}
var _statuses: Dictionary = {}

@onready var health: Health = $Health
@onready var _visual: Node2D = $Visual
@onready var _animator: EnemyAnimator = $Visual/Sprite


## Sets what this is. Call before adding the enemy to the scene.
func configure(p_level: int, p_rank: Rank = Rank.NORMAL, p_id: String = "husk") -> void:
	level = maxi(p_level, 1)
	rank = p_rank
	enemy_id = p_id if EnemyDB.ENEMIES.has(p_id) else "husk"


func _ready() -> void:
	add_to_group("enemies")
	SunShadow.follow(_animator)
	if boss_id != "":
		rank = Rank.BOSS
		brain = BossBrain.new(self, boss_id)
		enemy_id = BossDB.BOSSES[boss_id]["monster"]
	if EnemyDB.ENEMIES.get(enemy_id, {}).has("wild"):
		# Animals are just animals: never Elites, never bosses.
		rank = Rank.NORMAL
		modifiers.clear()
	if rank >= Rank.MINIBOSS:
		add_to_group("bosses")
	_data = EnemyDB.ENEMIES[enemy_id]
	_attack = _data["attack"]
	_traits = _data["traits"].duplicate() if boss_id == "" else []
	display_name = _data["name"] if boss_id == "" else BossDB.BOSSES[boss_id]["name"]
	if named_id != "":
		display_name = MinibossDB.NAMED[named_id]["name"]
	if custom_name != "":
		display_name = custom_name
	var rolls: int = RANK_DATA[rank]["modifiers"]
	if modifiers.is_empty() and rolls > 0 and not is_fragment:
		var pool: Array = MODIFIERS.keys()
		pool.shuffle()
		for index in rolls:
			modifiers.append(pool[index])
	for modifier in modifiers:
		_traits.append_array(MODIFIERS[modifier].get("traits", []))
	windup_time = _attack["windup"] * (0.75 if "swift" in modifiers else 1.0)
	lunge_time = _attack.get("time", 0.25)
	var rank_data: Dictionary = RANK_DATA[rank]
	var giant := "giant" in modifiers
	var size: float = rank_data["size"] * _data["size"] * (0.62 if is_fragment else 1.0) * (1.3 if giant else 1.0)
	if boss_id != "":
		size = BossDB.BOSSES[boss_id]["size"]
	elif named_id != "":
		size *= float(MinibossDB.NAMED[named_id]["size"])
	health.max_health = _data["health"] * rank_data["health"] * (1.0 + HEALTH_PER_LEVEL * (level - 1)) * (0.35 if is_fragment else 1.0) * Difficulty.value("health") * (1.6 if giant else 1.0)
	if not _data.has("wild"):
		health.max_health *= TOUGHNESS
	health.current = health.max_health
	_damage = _data["damage"] * rank_data["damage"] * (1.0 + DAMAGE_PER_LEVEL * (level - 1)) * (0.6 if is_fragment else 1.0)
	_speed = _data["speed"] * (1.4 if "swift" in modifiers else 1.0) * (0.85 if giant else 1.0) * Difficulty.value("speed")
	if giant:
		_damage *= 1.3
	if "shielded" in modifiers:
		shield_max = health.max_health * SHIELD_SHARE
		shield = shield_max
	_tint = rank_data["tint"] if boss_id == "" else BossDB.BOSSES[boss_id]["tint"]
	if named_id != "":
		_tint = MinibossDB.NAMED[named_id]["tint"]
	if boss_id != "":
		health.max_health *= BossDB.BOSSES[boss_id]["health"]
		health.current = health.max_health
	body_radius = _data["radius"] * size
	_visual.scale = Vector2(size, size)
	_visual.modulate = _tint
	_animator.sheet = EnemyDB.sheet(enemy_id)
	_animator.rebuild()
	# Walkers are stopped by walls; fliers by nothing.
	collision_mask = 0 if _data.get("flying", false) else TerrainTiles.WALL_COLLISION
	_add_nameplate(rank_data, size)
	StatusFX.attach(self, func() -> Array: return _statuses.keys(), 40.0 * size, body_radius)
	health.died.connect(_on_died)
	_pick_wander()


## Experience this enemy is worth at its level and rank.
func xp_value() -> int:
	var value: float = _data["xp"] * RANK_DATA[rank]["xp"] * pow(level, XP_LEVEL_EXPONENT) * (1.0 + REWARD_PER_MODIFIER * modifiers.size())
	return maxi(roundi(value * (0.3 if is_fragment else 1.0) * Difficulty.value("xp") * (1.5 if DayNight.blood_moon else 1.0)), 1)


func has_trait(id: String) -> bool:
	return id in _traits


## True while a wind-up will end in an area attack (for the ground marker).
func is_area_attack() -> bool:
	return _attack["kind"] in ["slam", "cloud", "explode", "spin", "burrow"]


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_state_time_left = maxf(_state_time_left - delta, 0.0)
	_since_hurt += delta
	_stagger_cooldown = maxf(_stagger_cooldown - delta, 0.0)
	_plate_check -= delta
	if _plate_check <= 0.0 and _nameplate:
		_plate_check = 0.15
		_update_nameplate()
	if exposed_left > 0.0:
		exposed_left = maxf(exposed_left - delta, 0.0)
		queue_redraw()
	_read_ground(delta)
	_update_statuses(delta)
	if state == State.DEAD:
		return
	if shield_max > 0.0 and _since_hurt > SHIELD_REGEN_DELAY and shield < shield_max:
		shield = minf(shield + shield_max * 0.25 * delta, shield_max)
		queue_redraw()
	if has_trait("regen") and _since_hurt > 2.0:
		health.heal(health.max_health / WOUNDS_LAST * delta)
	if not modifiers.is_empty():
		_update_modifiers(delta)
	if brain and state != State.STAGGER:
		brain.physics(delta)
		if absf(velocity.x) > 1.0:
			_visual.scale.x = absf(_visual.scale.x) * signf(velocity.x)
		move_and_slide()
		return
	var has_target := target != null and not target.is_dead()
	var to_target := target.global_position - global_position if has_target else Vector2.ZERO
	var distance := to_target.length()
	if is_wild() and _wild_turn(delta, has_target, to_target, distance):
		if absf(velocity.x) > 1.0:
			_visual.scale.x = absf(_visual.scale.x) * signf(velocity.x)
		move_and_slide()
		return

	# Back above ground if a burrow was cut short.
	if state != State.WINDUP and _visual.modulate.a < 1.0 and _attack["kind"] == "burrow":
		_visual.modulate.a = 1.0
	match state:
		State.WANDER:
			velocity = _direction * _speed * 0.4 * _ground_speed
			if has_target and distance < AGGRO_RADIUS and (not Difficulty.monsters_passive() or _since_hurt < 30.0):
				state = State.CHASE
			elif _state_time_left == 0.0:
				_pick_wander()
		State.CHASE:
			if not has_target or distance > LEASH_RADIUS:
				_pick_wander()
			elif lair_home != Vector2.INF and global_position.distance_to(lair_home) > 520.0:
				# Too far from the lair: give up the chase and head back, still wounded.
				_pick_wander()
				_direction = global_position.direction_to(lair_home)
				_state_time_left = 2.5
			elif _in_attack_range(distance):
				_enter(State.WINDUP, windup_time)
				velocity = Vector2.ZERO
				_visual.modulate = Color(1.8, 0.5, 0.5)
			else:
				velocity = _chase_velocity(to_target, distance, delta) * _ground_speed
				_avoid_getting_stuck(delta)
				_try_blink(delta, to_target, distance)
		State.WINDUP:
			velocity = Vector2.ZERO
			if has_target:
				_direction = to_target.normalized()
			if _attack["kind"] == "burrow" and has_target:
				# Under the ground, sliding in beneath the player.
				velocity = to_target.normalized() * minf(_speed * 1.8, distance / maxf(_state_time_left, 0.05))
				_visual.modulate.a = 0.25
			if _attack["kind"] == "charge":
				# Pawing the ground before the rush.
				_visual.position.x = sin(Time.get_ticks_msec() / 30.0) * 1.5
			if is_area_attack():
				queue_redraw()
			if _state_time_left == 0.0:
				_visual.modulate = _tint
				_visual.position.x = 0.0
				_has_hit = false
				_strike(has_target)
		State.LUNGE:
			if _pouncing:
				# A leap in an arc onto where the player stood.
				var total: float = _attack.get("time", 0.4)
				var t := 1.0 - _state_time_left / total
				velocity = (_pounce_to - _pounce_from) / total
				_visual.position.y = -sin(t * PI) * 26.0
				if _state_time_left == 0.0:
					_pouncing = false
					_visual.position.y = 0.0
					_blast(_attack.get("radius", 48.0))
					_enter(State.RECOVER, _attack["recover"])
			else:
				velocity = _direction * _attack.get("speed", 400.0) * _speed_multiplier() * _ground_speed
				if has_target and not _has_hit and distance < body_radius + 13.0:
					_has_hit = true
					if _hit_target(_current_damage()) and _attack.has("knockback"):
						target.velocity = _direction * _attack["knockback"]
						target.shake_camera(5.0)
				if _attack["kind"] == "charge" and is_on_wall():
					# Ran headlong into a wall: dazed for a moment.
					HitSpark.spawn(get_parent(), global_position + Vector2(0, -16), Color(1, 1, 0.8), true)
					_enter(State.STAGGER, 1.4)
				elif _state_time_left == 0.0:
					if _attack["kind"] == "swoop":
						# Off and away again after the pass.
						velocity = -_direction * _attack.get("speed", 400.0) * 0.5
					_enter(State.RECOVER, _attack["recover"])
		State.RECOVER:
			velocity = velocity.move_toward(Vector2.ZERO, (500.0 if _attack["kind"] == "swoop" else 2000.0) * delta)
			if _state_time_left == 0.0:
				state = State.CHASE
		State.STAGGER:
			velocity = velocity.move_toward(Vector2.ZERO, 1600.0 * delta)
			if _state_time_left == 0.0:
				state = State.CHASE

	if absf(velocity.x) > 1.0:
		_visual.scale.x = absf(_visual.scale.x) * signf(velocity.x)
	elif state == State.WINDUP and absf(_direction.x) > 0.1:
		_visual.scale.x = absf(_visual.scale.x) * signf(_direction.x)
	if _statuses.has("chill"):
		velocity *= 1.0 - _statuses["chill"]["power"]
	move_and_slide()


func _draw() -> void:
	if exposed_left > 0.0 and state != State.DEAD:
		# Open to a finisher: a golden mark over the head.
		var bob := sin(Time.get_ticks_msec() / 90.0) * 2.0
		var top := Vector2(0, -52.0 * _visual.scale.y - 18.0 + bob)
		draw_colored_polygon(PackedVector2Array([top + Vector2(-6, -12), top + Vector2(6, -12), top + Vector2(2, 2), top + Vector2(-2, 2)]), Color(1.0, 0.8, 0.3))
		draw_circle(top + Vector2(0, 6), 2.5, Color(1.0, 0.8, 0.3))
		draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.45))
		draw_arc(Vector2.ZERO, body_radius + 14.0, 0.0, TAU, 32, Color(1.0, 0.8, 0.3, 0.9), 2.5)
		draw_set_transform(Vector2.ZERO)
	# A ring in each modifier's colour marks an Elite or Champion.
	if state != State.DEAD:
		for index in modifiers.size():
			var ring: Color = MODIFIERS[modifiers[index]]["color"]
			draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.45))
			draw_arc(Vector2.ZERO, body_radius + 9.0 + index * 5.0, 0.0, TAU, 28, Color(ring, 0.9), 2.0)
			if modifiers[index] == "shielded" and shield > 0.0:
				draw_set_transform(Vector2(0, -body_radius), 0.0, Vector2.ONE)
				draw_arc(Vector2.ZERO, body_radius + 14.0, 0.0, TAU, 32, Color(ring, 0.35 + 0.45 * shield / shield_max), 2.5)
				draw_circle(Vector2.ZERO, body_radius + 13.0, Color(ring, 0.07))
			if modifiers[index] == "frozen_aura":
				draw_arc(Vector2.ZERO, FROZEN_AURA_RADIUS, 0.0, TAU, 48, Color(ring, 0.25), 1.5)
			draw_set_transform(Vector2.ZERO)
	if brain and state != State.DEAD:
		brain.draw()
		return
	# The ground marker for an area attack, filling in as the wind-up runs out.
	if state != State.WINDUP or not is_area_attack():
		return
	var radius: float = _attack["radius"]
	var progress := 1.0 - _state_time_left / windup_time
	var color: Color = _attack.get("color", Color(1.0, 0.4, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.75))
	draw_circle(Vector2.ZERO, radius * progress, Color(color, 0.22))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(color, 0.85), 2.0)
	draw_set_transform(Vector2.ZERO)


## Returns the health actually removed, so callers can reward real damage only.
func take_damage(
	amount: float, knockback: Vector2, critical: bool = false, weapon_type: String = "", element: String = ""
) -> float:
	if state == State.DEAD:
		return 0.0
	if element != "":
		# Elemental damage riding on a blow: its own coloured number, and no
		# extra shove, dodge, or thorns.
		if shield > 0.0:
			var soaked := minf(shield, amount)
			shield -= soaked
			amount -= soaked
		if amount <= 0.0:
			return 0.0
		DamageNumber.spawn(get_parent(), global_position + Vector2(randf_range(-10, 10), -12), amount, Elements.color(element), critical)
		_since_hurt = 0.0
		return health.take_damage(amount)
	if has_trait("armored"):
		amount *= 0.65
	if "evasive" in modifiers and state != State.WINDUP and randf() < EVADE_CHANCE:
		DamageNumber.spawn_text(get_parent(), global_position + Vector2(0, -30), "Evaded", Color(0.85, 0.85, 0.95), 13)
		velocity = knockback.normalized().rotated(PI / 2.0 * (1 if randf() < 0.5 else -1)) * 260.0
		return 0.0
	if "thorns" in modifiers and target and not target.is_dead() and weapon_type not in ["bows", "staves"]:
		target.take_damage(amount * THORNS_SHARE, global_position, level)
	if shield > 0.0:
		var absorbed := minf(shield, amount)
		shield -= absorbed
		amount -= absorbed
		_since_hurt = 0.0
		HitSpark.spawn(get_parent(), global_position + Vector2(0, -16), MODIFIERS["shielded"]["color"], shield <= 0.0)
		if shield <= 0.0:
			RingBurst.spawn(get_parent(), global_position + Vector2(0, -14), MODIFIERS["shielded"]["color"], 50.0)
		queue_redraw()
		if amount <= 0.0:
			DamageNumber.spawn(get_parent(), global_position, absorbed, MODIFIERS["shielded"]["color"])
			return 0.0
	var color := Color(1.0, 0.8, 0.25) if critical else Color(0.95, 0.9, 0.75)
	DamageNumber.spawn(get_parent(), global_position, amount, color, critical)
	_last_weapon_type = weapon_type
	_since_hurt = 0.0
	Audio.play("hit", -4.0)
	HitSpark.spawn(get_parent(), global_position + Vector2(0, -16), Color(1.0, 0.85, 0.4) if critical else Color(1.0, 0.95, 0.85), critical)
	var dealt := health.take_damage(amount)
	Gore.spray(get_parent(), global_position, enemy_id, knockback.normalized(), 9 if health.is_dead() else (6 if critical else 3), health.is_dead() or critical)
	_animator.scale = Vector2(1.18, 0.84)
	if health.is_dead():
		return dealt
	# Poise: a blow only interrupts an enemy that is not mid-attack and has
	# not just been staggered, and big or armoured enemies shrug off most of
	# the shove. Without this, quick swings could lock an enemy in place.
	var resist: float = POISE[rank] * (0.5 if has_trait("armored") else 1.0)
	var shove := knockback * resist
	var attacking := state == State.WINDUP or state == State.LUNGE
	if not attacking and _stagger_cooldown == 0.0 and shove.length() > 110.0:
		_enter(State.STAGGER, 0.18)
		_stagger_cooldown = 1.1
		_visual.modulate = _tint
		velocity = shove * 0.6
		queue_redraw()
	elif not attacking:
		velocity += shove * 0.15
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


static var _tops: Dictionary = {}


## How far above the feet the top of a creature's art is (at size 1).
static func _art_top(sheet: Texture2D) -> float:
	if not _tops.has(sheet):
		var top := -52.0
		var image := sheet.get_image() if sheet else null
		if image:
			var used := image.get_region(Rect2i(0, 0, 96, 96)).get_used_rect()
			# The sprite's centre sits 23px above the feet.
			top = -23.0 + (used.position.y - 48.0)
		_tops[sheet] = top
	return _tops[sheet]


## Names show for the strong, the recently hurt, and whatever the mouse is
## over; the rank and file stay unlabelled so a crowd is readable.
func _update_nameplate() -> void:
	var near_mouse := get_global_mouse_position().distance_to(global_position + Vector2(0, -20)) < 36.0
	var show := rank > Rank.NORMAL or _since_hurt < 4.0 or near_mouse or custom_name != ""
	var target_alpha := 1.0 if show else 0.0
	_nameplate.modulate.a = move_toward(_nameplate.modulate.a, target_alpha, 0.35)


## A wild animal rather than a monster.
func is_wild() -> bool:
	return _data.get("wild", "") != ""


## Wild animals graze and wander, start at anything that comes close, and
## bolt when hurt; those that "defend" turn and fight once struck. Returns
## true when it has decided the animal's move this frame.
func _wild_turn(delta: float, has_target: bool, to_target: Vector2, distance: float) -> bool:
	var hurt := _since_hurt < 5.0
	if _data["wild"] == "defend" and hurt:
		return false
	if state in [State.STAGGER, State.DEAD]:
		return false
	var scared := has_target and (hurt or (distance < 90.0 and target.velocity.length() > 160.0))
	if scared:
		state = State.CHASE
		velocity = -to_target.normalized() * _speed * (1.25 if hurt else 0.9) * _ground_speed
		_avoid_getting_stuck(delta)
		return true
	if state != State.WANDER:
		_pick_wander()
	velocity = _direction * _speed * 0.3 * _ground_speed
	if _state_time_left == 0.0:
		_pick_wander()
	return true


## Parried: reeling and open to a finisher for a moment.
func expose(seconds: float) -> void:
	if state == State.DEAD:
		return
	exposed_left = seconds * (0.6 if rank >= Rank.MINIBOSS else 1.0)
	stun(seconds * 0.8)
	queue_redraw()


## Freezes the enemy in place. Bosses shake it off sooner.
func stun(seconds: float) -> void:
	if state == State.DEAD:
		return
	_enter(State.STAGGER, seconds * (0.4 if rank >= Rank.MINIBOSS else 1.0))
	velocity = Vector2.ZERO
	_visual.modulate = Color(0.7, 0.9, 1.3)
	var tween := create_tween()
	tween.tween_interval(seconds)
	tween.tween_callback(func() -> void: _visual.modulate = _tint)


func has_status(id: String) -> bool:
	return _statuses.has(id)


## Called when this enemy's attack has hurt the player.
func on_dealt_damage(amount: float) -> void:
	if has_trait("lifesteal") and state != State.DEAD:
		health.heal(amount * 0.5)


# --- attacks

func _in_attack_range(distance: float) -> bool:
	return distance < _attack["range"]


## Carries out the attack once the wind-up ends.
func _strike(has_target: bool) -> void:
	match _attack["kind"]:
		"lunge", "charge", "swoop":
			_enter(State.LUNGE, _attack.get("time", lunge_time))
		"swipe", "thrust":
			_swipe(_attack.get("arc", 110.0))
			_enter(State.RECOVER, _attack["recover"])
		"combo":
			# Several quick swipes, each with a short wind-up of its own.
			if _combo_left <= 0:
				_combo_left = int(_attack.get("count", 3))
			_combo_left -= 1
			_swipe(_attack.get("arc", 100.0))
			velocity = _direction * 120.0
			if _combo_left > 0:
				_enter(State.WINDUP, _attack.get("gap", 0.16))
				_visual.modulate = Color(1.5, 0.7, 0.6)
			else:
				_enter(State.RECOVER, _attack["recover"])
		"pounce":
			if has_target:
				_pounce_from = global_position
				var reach: float = _attack["range"] * 1.15
				_pounce_to = global_position + (target.global_position - global_position).limit_length(reach)
				_pouncing = true
			_enter(State.LUNGE, _attack.get("time", 0.4))
		"spit":
			if has_target:
				var shots: int = _attack.get("count", 3)
				var spread := deg_to_rad(_attack.get("spread", 30.0))
				var aim := global_position.direction_to(target.global_position)
				for i in shots:
					var angle := -spread / 2.0 + spread * i / maxf(shots - 1, 1)
					EnemyProjectile.fire(self, target, _attack, _current_damage() * 0.7, aim.rotated(angle))
			_enter(State.RECOVER, _attack["recover"])
		"spin":
			_blast()
			var spin := create_tween()
			spin.tween_property(_visual, "rotation", TAU, 0.3)
			spin.tween_callback(func() -> void: _visual.rotation = 0.0)
			_enter(State.RECOVER, _attack["recover"])
		"burrow":
			_visual.modulate.a = 1.0
			_blast()
			if target and not target.is_dead() and target.global_position.distance_to(global_position) < _attack["radius"]:
				target.velocity = Vector2(0, -1).rotated(randf_range(-1.0, 1.0)) * 260.0
			_enter(State.RECOVER, _attack["recover"])
		"shoot":
			if has_target:
				EnemyProjectile.fire(self, target, _attack, _current_damage())
			_enter(State.RECOVER, _attack["recover"])
		"slam", "cloud":
			_blast()
			if _attack["kind"] == "cloud":
				HazardZone.spawn(get_parent(), global_position, target, _attack["radius"], _attack["linger"], _attack["color"], _attack["status"], _current_damage())
			_enter(State.RECOVER, _attack["recover"])
		"explode":
			_blast()
			health.take_damage(health.current)
	queue_redraw()


## A swipe in front: claw marks sweep across, and the player is hit if
## inside its reach and angle.
func _swipe(arc_degrees: float) -> void:
	var reach: float = _attack.get("reach", _attack["range"])
	var claws := 1 if _attack["kind"] == "thrust" else int(_attack.get("claws", 3))
	ClawSwipe.spawn(get_parent(), global_position, _direction, reach, arc_degrees, _attack.get("color", Color(1.0, 0.92, 0.8)), claws)
	Audio.play("swing", -10.0, 0.2)
	if target == null or target.is_dead():
		return
	var offset := target.global_position - global_position
	if offset.length() > reach + 12.0:
		return
	if offset.length() > body_radius + 8.0 and absf(_direction.angle_to(offset)) > deg_to_rad(arc_degrees) / 2.0:
		return
	if _hit_target(_current_damage()) and _attack.has("knockback"):
		target.velocity = _direction * _attack["knockback"]


## An area attack centred on this enemy.
func _blast(radius: float = -1.0) -> void:
	if radius < 0.0:
		radius = _attack["radius"]
	var color: Color = _attack.get("color", Color(1.0, 0.6, 0.3))
	RingBurst.spawn(get_parent(), global_position, color, radius)
	HitSpark.spawn(get_parent(), global_position + Vector2(0, -10), color, true)
	if target and not target.is_dead() and target.global_position.distance_to(global_position) < radius:
		if _hit_target(_current_damage()):
			target.shake_camera(7.0)
			if _attack.has("knockback"):
				target.velocity = global_position.direction_to(target.global_position) * _attack["knockback"]


## Damages the player and applies this enemy's on-hit status. Returns whether
## the blow landed (it may have been dodged).
func _hit_target(amount: float) -> bool:
	if not target.take_damage(amount, global_position, level, Elements.attack_element(enemy_id)):
		return false
	on_dealt_damage(amount)
	var effects: Array = [_data.get("touch", {}), _attack.get("status", {}) if not _attack["kind"] in ["shoot", "spit"] else {}]
	for modifier in modifiers:
		effects.append(MODIFIERS[modifier].get("touch", {}))
	for effect: Dictionary in effects:
		if not effect.is_empty():
			var power: float = effect["power"] if effect["status"] == "chill" else effect["power"] * amount
			target.apply_status(effect["status"], effect["duration"], power)
	return true


# --- buffs

func _current_damage() -> float:
	var damage := _damage
	if has_trait("enrage") and health.current < health.max_health * 0.4:
		damage *= 1.3
	if has_trait("pack"):
		damage *= 1.0 + 0.08 * _allies_near(180.0, 3)
	return damage


func _speed_multiplier() -> float:
	var multiplier := 1.0
	if has_trait("enrage") and health.current < health.max_health * 0.4:
		multiplier *= 1.4
	if has_trait("pack"):
		multiplier *= 1.0 + 0.08 * _allies_near(180.0, 3)
	if _inspired():
		multiplier *= 1.25
	return multiplier


func _allies_near(reach: float, most: int) -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group("enemies"):
		if node != self and node.global_position.distance_to(global_position) < reach:
			count += 1
	return mini(count, most)


## Whether an ally with the "inspire" trait is close by.
func _inspired() -> bool:
	for node in get_tree().get_nodes_in_group("enemies"):
		var other := node as Enemy
		if other and other != self and other.has_trait("inspire") and other.global_position.distance_to(global_position) < 220.0:
			return true
	return false


func _chase_velocity(to_target: Vector2, distance: float, delta: float) -> Vector2:
	var heading := to_target.normalized()
	# Ranged enemies back away when the player gets too close.
	if _attack["kind"] in ["shoot", "spit"] and distance < _attack["range"] * 0.45:
		heading = -heading
	if has_trait("erratic"):
		_weave += delta * 7.0
		heading = heading.rotated(sin(_weave) * 0.9)
	return heading * _speed * _speed_multiplier() + _separation()


func _try_blink(delta: float, to_target: Vector2, distance: float) -> void:
	if not has_trait("blink"):
		return
	_blink_left -= delta
	if _blink_left > 0.0 or distance < 140.0:
		return
	_blink_left = randf_range(3.5, 5.5)
	RingBurst.spawn(get_parent(), global_position + Vector2(0, -14), Color(0.7, 0.9, 1.0), 40.0)
	global_position = target.global_position - to_target.normalized().rotated(randf_range(-1.2, 1.2)) * 150.0
	RingBurst.spawn(get_parent(), global_position + Vector2(0, -14), Color(0.7, 0.9, 1.0), 40.0)


## The modifiers that act on their own over time.
func _update_modifiers(delta: float) -> void:
	var has_target := target != null and not target.is_dead()
	if "frozen_aura" in modifiers and has_target:
		_aura_left -= delta
		if _aura_left <= 0.0:
			_aura_left = 0.5
			if target.global_position.distance_to(global_position) < FROZEN_AURA_RADIUS:
				target.apply_status("chill", 1.0, 0.3)
	if "molten" in modifiers and has_target and velocity.length() > 20.0:
		_molten_left -= delta
		if _molten_left <= 0.0:
			_molten_left = 0.7
			HazardZone.spawn(get_parent(), global_position, target, 34.0, 3.0, MODIFIERS["molten"]["color"], {"status": "burn", "duration": 2.0, "power": 0.25}, _damage * 0.5)
	if "summoner" in modifiers and has_target and state == State.CHASE:
		_summon_left -= delta
		if _summon_left <= 0.0 and _minions < SUMMON_LIMIT:
			_summon_left = SUMMON_SECONDS
			_minions += 1
			RingBurst.spawn(get_parent(), global_position, MODIFIERS["summoner"]["color"], 60.0)
			wants_minion.emit(self)


## What some modifiers leave behind when the enemy dies.
func _death_effects() -> void:
	if "explosive" in modifiers:
		var color: Color = MODIFIERS["explosive"]["color"]
		RingBurst.spawn(get_parent(), global_position, color, 110.0)
		HitSpark.spawn(get_parent(), global_position + Vector2(0, -10), color, true)
		if target and not target.is_dead() and target.global_position.distance_to(global_position) < 110.0:
			target.take_damage(_damage * 1.5, global_position, level)
	if "poisonous" in modifiers and target:
		HazardZone.spawn(get_parent(), global_position, target, 100.0, 5.0, MODIFIERS["poisonous"]["color"], {"status": "poison", "duration": 3.0, "power": 0.3}, _damage)


## Water slows walkers to a wade; fliers do not care.
func _read_ground(delta: float) -> void:
	_ground_left -= delta
	if _ground_left > 0.0:
		return
	_ground_left = 0.25
	var world: World = get_tree().get_first_node_in_group("world")
	# Rooms off the map are far above the world; their ground is never water.
	if world == null or _data.get("flying", false) or Room.holds(global_position):
		_ground_speed = 1.0
		in_water = false
		return
	var tile := world.tile_type_at_position(global_position)
	in_water = TerrainTiles.is_water(tile)
	_ground_speed = 0.55 if in_water else 1.0
	_visual.position.y = 10.0 if in_water else 0.0


## If chasing has not moved the enemy for a while, it heads off sideways
## for a moment to get around whatever is in the way.
func _avoid_getting_stuck(delta: float) -> void:
	if _detour_left > 0.0:
		_detour_left -= delta
		velocity = _detour * _speed * _ground_speed
		return
	if velocity.length() > 20.0 and get_real_velocity().length() < 6.0:
		_stuck_time += delta
	else:
		_stuck_time = 0.0
	if _stuck_time > 0.5:
		_stuck_time = 0.0
		_detour = velocity.normalized().rotated(PI / 2.0 * (1.0 if randf() < 0.5 else -1.0))
		_detour_left = 0.7


# --- internals

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
	var back := _visual.modulate if state == State.WINDUP else _tint
	_visual.modulate = Color(4.0, 4.0, 4.0)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_visual, "modulate", back, 0.15)


func _on_died() -> void:
	state = State.DEAD
	_statuses.clear()
	_refresh_status_tint()
	remove_from_group("enemies")
	remove_from_group("bosses")
	velocity = Vector2.ZERO
	queue_redraw()
	$Collision.set_deferred("disabled", true)
	_death_effects()
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
		"fragment": is_fragment,
		"modifiers": modifiers.size(),
		"named": named_id,
	})
	if _flash_tween:
		_flash_tween.kill()
	$HealthBar.visible = false
	_visual.modulate = Color(4.0, 4.0, 4.0)
	var tween := create_tween()
	tween.tween_property(_visual, "modulate", _tint, 0.15)
	# Let the collapse play, lie still a moment, then fade away.
	tween.tween_interval(_animator.death_seconds() + 3.5)
	tween.tween_property(self, "modulate:a", 0.0, 1.2)
	tween.tween_callback(queue_free)


func _add_nameplate(rank_data: Dictionary, size: float) -> void:
	var label := Label.new()
	var prefix := ""
	for modifier in modifiers:
		prefix += MODIFIERS[modifier]["name"] + " "
	label.text = "Lv %d %s%s%s" % [level, prefix, rank_data["title"] if named_id == "" else "", display_name]
	label.add_theme_font_override("font", UITheme.get_theme().default_font)
	label.add_theme_font_size_override("font_size", 13)
	var plate_colors: Array[Color] = [Color(0.82, 0.8, 0.74), Color(1.0, 0.82, 0.4), Color(0.85, 0.6, 1.0), Color(1.0, 0.45, 0.4), Color(1.0, 0.3, 0.25)]
	label.add_theme_color_override("font_color", plate_colors[rank])
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	# The camera zooms in 2x; shrink so the text stays small and sharp.
	label.scale = Vector2.ONE / 2.0
	var top := _art_top(EnemyDB.sheet(enemy_id)) * size - (8.0 if _data.get("flying", false) else 2.0)
	label.position = Vector2(-label.get_minimum_size().x / 4.0, top - 14.0)
	label.z_index = 10
	add_child(label)
	_nameplate = label
	$HealthBar.position.y = top
