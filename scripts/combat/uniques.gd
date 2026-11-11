class_name Uniques
extends Node2D
## The special powers of unique items. The player calls the hooks below;
## each checks whether something worn has that power.

const TEXT := {
	"chain_lightning": "Hits have a 25% chance to arc lightning to 3 more foes for 40% damage.",
	"split_arrows": "Every shot splits into three arrows.",
	"wisp": "A wisp circles you and shoots the nearest foe for 50% damage.",
	"bloodthirst": "Kills heal 4% of your health and quicken your attacks for 4 seconds.",
	"freeze": "Hits have a 12% chance to freeze a foe solid for 1.2 seconds.",
	"sun_pillar": "Every fifth hit calls down a pillar of light for 200% damage around the target.",
	"fire_nova": "When struck, bursts into flame, burning foes around you (once every 4 seconds).",
	"phoenix": "A killing blow instead leaves you at 40% health, once every 10 minutes.",
	"void_rift": "Dodging tears a rift that damages foes where you started and stopped.",
	"spirit_bolt": "Kills have a 30% chance to loose a spirit bolt at the nearest foe and return 5 mana.",
}
const STORM := Color(0.6, 0.85, 1.0)
const PHOENIX_COOLDOWN := 600.0

static var _busy := false


static func has(player: Player, effect: String) -> bool:
	return effect in player.equipment.unique_effects()


static func _cooldown_ready(player: Player, key: String, seconds: float) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	if now < float(player.get_meta("cd_" + key, 0.0)):
		return false
	player.set_meta("cd_" + key, now + seconds)
	return true


static func _nearest(player: Player, from: Vector2, reach: float, skip: Array) -> Enemy:
	var best: Enemy = null
	var best_distance := reach
	for node in player.get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy in skip or enemy.health.is_dead():
			continue
		var distance := enemy.global_position.distance_to(from)
		if distance < best_distance:
			best_distance = distance
			best = enemy
	return best


## After a blow lands on an enemy.
static func on_hit(player: Player, enemy: Enemy, damage: float) -> void:
	if _busy:
		return
	_busy = true
	var effects := player.equipment.unique_effects()
	if "chain_lightning" in effects and randf() < 0.25:
		var chain: Array = [enemy]
		var from := enemy.global_position
		for i in 3:
			var next := _nearest(player, from, 180.0, chain)
			if next == null:
				break
			_bolt(player, from, next.global_position, STORM)
			next.take_damage(damage * 0.4, Vector2.ZERO, false, player.weapon_type, "storm")
			chain.append(next)
			from = next.global_position
	if "freeze" in effects and randf() < 0.12 and not enemy.health.is_dead():
		enemy.stun(1.2)
		RingBurst.spawn(player.get_parent(), enemy.global_position + Vector2(0, -14), Color(0.7, 0.92, 1.0), 40.0)
	if "sun_pillar" in effects:
		var count := int(player.get_meta("sun_hits", 0)) + 1
		player.set_meta("sun_hits", count)
		if count % 5 == 0:
			LightPillar.spawn(player.get_parent(), enemy.global_position, Color(1.0, 0.9, 0.5))
			player.strike_circle(enemy.global_position, 80.0, 2.0, 200.0)
	_busy = false


## Called with the damage about to be taken; returns what is actually taken.
static func on_hurt(player: Player, amount: float) -> float:
	var effects := player.equipment.unique_effects()
	if "fire_nova" in effects and _cooldown_ready(player, "nova", 4.0):
		RingBurst.spawn(player.get_parent(), player.global_position + Vector2(0, -14), Elements.color("fire"), 100.0)
		_busy = true
		for node in player.get_tree().get_nodes_in_group("enemies"):
			var enemy := node as Enemy
			if enemy and enemy.global_position.distance_to(player.global_position) < 100.0:
				enemy.take_damage(player.stats.get_stat("physical_damage") * 0.8, Vector2.ZERO, false, "", "fire")
				enemy.apply_status("burn", 3.0, player.stats.get_stat("physical_damage") * 0.2)
		_busy = false
	if "phoenix" in effects and amount >= player.health.current and _cooldown_ready(player, "phoenix", PHOENIX_COOLDOWN):
		player.health.heal(player.health.max_health * 0.4)
		LightPillar.spawn(player.get_parent(), player.global_position, Color(1.0, 0.6, 0.25))
		DamageNumber.spawn_text(player.get_parent(), player.global_position + Vector2(0, -50), "Reborn in flame", Color(1.0, 0.6, 0.25), 15)
		return 0.0
	return amount


## How many extra arrows a shot splits into, and their spread.
static func extra_projectiles(player: Player) -> int:
	return 2 if has(player, "split_arrows") else 0


static func on_kill(player: Player, at: Vector2) -> void:
	var effects := player.equipment.unique_effects()
	if "bloodthirst" in effects:
		player.health.heal(player.health.max_health * 0.04)
		player.buffs.add("bloodthirst", "Bloodthirst", 4.0, {"attack_speed": {"percent": 0.2}})
	if "spirit_bolt" in effects and randf() < 0.3:
		player.mana.current = minf(player.mana.current + 5.0, player.mana.max_value)
		var target := _nearest(player, at, 400.0, [])
		if target:
			var config := {"sprite": 1, "speed": 520.0, "radius": 12.0, "range": 480.0, "color": Color(0.55, 1.0, 0.7), "knockback": 120.0}
			Projectile.fire(player, (target.global_position - player.global_position).normalized(), config, 1.0)


static func on_dodge(player: Player, start: Vector2, end: Vector2) -> void:
	if not has(player, "void_rift"):
		return
	for point: Vector2 in [start, end]:
		RingBurst.spawn(player.get_parent(), point + Vector2(0, -10), Elements.color("shadow"), 64.0)
		_busy = true
		for node in player.get_tree().get_nodes_in_group("enemies"):
			var enemy := node as Enemy
			if enemy and enemy.global_position.distance_to(point) < 64.0:
				enemy.take_damage(player.stats.get_stat("physical_damage") * 0.7, Vector2.ZERO, false, "", "shadow")
		_busy = false


## A jagged line of light between two points that fades out.
static func _bolt(player: Player, from: Vector2, to: Vector2, color: Color) -> void:
	var line := Line2D.new()
	line.width = 3.0
	line.default_color = color
	line.z_index = 40
	var points := PackedVector2Array([from + Vector2(0, -16)])
	for k in range(1, 6):
		points.append(from.lerp(to, k / 6.0) + Vector2(randf_range(-9, 9), randf_range(-9, 9)) + Vector2(0, -16))
	points.append(to + Vector2(0, -16))
	line.points = points
	player.get_parent().add_child(line)
	var tween := line.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.25)
	tween.tween_callback(line.queue_free)


# --- the wisp that circles a Wispkeeper's bearer

var _player: Player
var _angle := 0.0
var _shot_left := 1.4


func setup(player: Player) -> void:
	_player = player
	z_index = 30
	Events.enemy_killed.connect(func(info: Dictionary) -> void:
		if is_instance_valid(_player) and not _player.is_dead():
			on_kill(_player, info.get("position", _player.global_position))
	)


func _process(delta: float) -> void:
	queue_redraw()
	if _player == null or _player.is_dead() or not has(_player, "wisp"):
		return
	_angle += delta * 2.2
	_shot_left -= delta
	if _shot_left <= 0.0:
		_shot_left = 1.4
		var target := _nearest(_player, _player.global_position, 420.0, [])
		if target:
			var config := {"sprite": 1, "speed": 600.0, "radius": 10.0, "range": 460.0, "color": Color(0.55, 1.0, 0.95), "knockback": 80.0}
			Projectile.fire(_player, (target.global_position - _player.global_position).normalized(), config, 0.5)


func _draw() -> void:
	if _player == null or _player.is_dead() or not has(_player, "wisp"):
		return
	var at := Vector2(cos(_angle), sin(_angle) * 0.5) * 30.0 + Vector2(0, -30)
	draw_circle(at, 7.0, Color(0.55, 1.0, 0.95, 0.25))
	draw_circle(at, 3.5, Color(0.8, 1.0, 1.0))
