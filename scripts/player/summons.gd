class_name Summons
extends Node2D
## What the player has called up to fight: a Necromancer's dead (weak
## zombies clawing out of the ground, skeleton archers) and a
## Spellcaster's familiars (small wisps of arcana). Each kind has a limit
## at once (raising more than that crumbles the oldest); every minion lasts
## LIFETIME seconds, flickering in its last ten, then falls to dust.
##
## Minions keep near the player and go for whatever comes close: zombies in
## claw's reach, archers and familiars from a little way off, their shots
## flying as small arrows or motes of light.

const LIFETIME := 180.0
const KINDS := {
	"zombie": {"name": "Risen Dead", "species": "risen_dead", "tint": Color.WHITE, "power": 0.6, "speed": 120.0, "gap": 1.3,
		"reach": 34.0, "ranged": false, "rise": true},
	"skeleton_archer": {"name": "Bound Archer", "species": "bound_archer", "tint": Color.WHITE, "power": 0.8, "speed": 105.0, "gap": 1.6,
		"reach": 280.0, "ranged": true, "rise": true, "shot": Color(0.82, 0.62, 1.0)},
	"familiar": {"name": "Familiar", "species": "familiar", "tint": Color.WHITE, "power": 0.9, "speed": 170.0, "gap": 1.2,
		"reach": 260.0, "ranged": true, "rise": false, "shot": Color(0.72, 0.94, 1.0)},
}
## How far from the player minions go looking for a fight.
const LEASH := 420.0

var minions: Array = []
var _player: Player


func setup(player: Player) -> void:
	_player = player


## How many of a kind may stand at once: the ability's own limit, more for
## a Necromancer's Horde ranks.
func limit(kind: String, base: int) -> int:
	var extra := int(_player.class_ranks.get("necro_horde", 0)) if kind == "zombie" else 0
	return base + extra


func count(kind: String) -> int:
	return minions.filter(func(m: Variant) -> bool: return is_instance_valid(m) and (m as Minion).kind == kind).size()


## Calls up `spec` = {"kind", "count", "limit"} round the player.
func summon(spec: Dictionary, colour: Color) -> void:
	var kind: String = spec.get("kind", "zombie")
	if not KINDS.has(kind):
		return
	minions = minions.filter(func(m: Variant) -> bool: return is_instance_valid(m))
	var most := limit(kind, int(spec.get("limit", 3)))
	for i in int(spec.get("count", 1)):
		# Too many of a kind: the oldest crumbles to make room.
		while count(kind) >= most:
			for minion: Variant in minions:
				if is_instance_valid(minion) and (minion as Minion).kind == kind:
					(minion as Minion).crumble()
					minions.erase(minion)
					break
		var minion := Minion.new()
		minion.setup(self, kind, colour)
		minion.position = _player.global_position + Vector2.from_angle(TAU * i / maxf(float(spec.get("count", 1)), 1.0) + randf()) * randf_range(40.0, 70.0)
		_player.get_parent().add_child(minion)
		minions.append(minion)
	Events.codex_event.emit("summons", int(spec.get("count", 1)))


func damage_of(kind: String) -> float:
	var level_part := 6.0 + 2.4 * _player.leveling.level
	return level_part * float(KINDS[kind]["power"]) * _player.stats.get_stat("magic_power") * (1.0 + 0.04 * _player.class_level)


func dismiss_all() -> void:
	for minion: Variant in minions:
		if is_instance_valid(minion):
			(minion as Minion).crumble()
	minions.clear()


## One summoned creature.
class Minion:
	extends Node2D

	var kind := "zombie"
	var life := Summons.LIFETIME
	var _summons: Summons
	var _data: Dictionary
	var _colour := Color.WHITE
	var _sprite: AnimatedSprite2D
	var _rise := 0.0
	var _strike_left := 0.6
	var _target: Enemy = null
	var _home := 0.0
	var _going := false

	func setup(summons: Summons, minion_kind: String, colour: Color) -> void:
		_summons = summons
		kind = minion_kind
		_data = Summons.KINDS[kind]
		_colour = colour
		_home = randf() * TAU

	func _ready() -> void:
		add_to_group("summons")
		_sprite = AnimatedSprite2D.new()
		_sprite.sprite_frames = SheetAnimations.build(EnemyDB.sheet(str(_data["species"])), 96, EnemyAnimator.ROWS)
		_sprite.modulate = _data["tint"]
		_sprite.play("idle")
		add_child(_sprite)
		_rise = 0.0 if _data["rise"] else 1.0
		_place_sprite()
		RingBurst.spawn(get_parent(), global_position, _colour, 46.0)

	func _place_sprite() -> void:
		# Rising out of the ground: the figure climbs up from below its feet.
		var climbed := clampf(_rise, 0.0, 1.0)
		_sprite.position = Vector2(0, roundf(lerpf(14.0, -23.0, climbed)))
		_sprite.modulate.a = 1.0 if _data["rise"] else climbed

	func crumble() -> void:
		RingBurst.spawn(get_parent(), global_position + Vector2(0, -10), Color(0.55, 0.5, 0.45), 34.0)
		for k in 6:
			HitSpark.spawn(get_parent(), global_position + Vector2(randf_range(-10, 10), randf_range(-30, 0)), Color(0.6, 0.55, 0.48), false)
		queue_free()

	func _physics_process(delta: float) -> void:
		var player := _summons._player
		if player == null or not is_instance_valid(player):
			return
		life -= delta
		if life <= 0.0:
			crumble()
			return
		if _rise < 1.0:
			_rise += delta / 0.7
			_place_sprite()
			queue_redraw()
			return
		_strike_left -= delta
		if _target == null or not is_instance_valid(_target) or _target.state == Enemy.State.DEAD or _target.global_position.distance_to(player.global_position) > Summons.LEASH:
			_target = _pick_target(player)
		var reach: float = _data["reach"]
		var goal := player.global_position + Vector2.from_angle(_home + life * 0.05) * 64.0
		if _target:
			var away := global_position - _target.global_position
			var keep := reach * 0.75 if _data["ranged"] else _target.body_radius + 16.0
			goal = _target.global_position + (away.normalized() if away.length() > 1.0 else Vector2.RIGHT) * keep
		var way := goal - global_position
		if way.length() > 6.0:
			global_position += way.normalized() * minf(way.length(), float(_data["speed"]) * delta)
			_sprite.flip_h = way.x < 0.0
			if _sprite.animation != "walk" and _sprite.sprite_frames.has_animation("walk"):
				_sprite.play("walk")
		elif _sprite.animation != "idle":
			_sprite.play("idle")
		if global_position.distance_to(player.global_position) > 1400.0:
			global_position = player.global_position + Vector2.from_angle(randf() * TAU) * 60.0
		if _target and _strike_left <= 0.0 and global_position.distance_to(_target.global_position) <= reach + _target.body_radius:
			_strike_left = float(_data["gap"])
			_sprite.flip_h = _target.global_position.x < global_position.x
			if _data["ranged"]:
				var shot := Shot.new()
				shot.setup(_target, _summons.damage_of(kind), _data["shot"], kind == "skeleton_archer")
				shot.position = global_position + Vector2(0, -20)
				get_parent().add_child(shot)
			else:
				_target.take_damage(_summons.damage_of(kind), (_target.global_position - global_position).normalized() * 120.0)
				HitSpark.spawn(get_parent(), _target.global_position + Vector2(0, -16), _data["tint"], false)
		queue_redraw()

	func _pick_target(player: Player) -> Enemy:
		var best: Enemy = null
		var best_distance := 360.0
		for node in get_tree().get_nodes_in_group("enemies"):
			var enemy := node as Enemy
			if enemy == null or enemy.state == Enemy.State.DEAD or enemy.is_wild():
				continue
			var distance := enemy.global_position.distance_to(player.global_position)
			if distance < best_distance:
				best_distance = distance
				best = enemy
		return best

	func _draw() -> void:
		var t := Time.get_ticks_msec() / 1000.0
		if _rise < 1.0 and _data["rise"]:
			# Dirt thrown up as it climbs out.
			for k in 8:
				var spread := float(k) / 7.0 * 2.0 - 1.0
				var at := Vector2(roundf(spread * 14.0), roundf(-sin(_rise * PI) * (6.0 + absf(spread) * 8.0)))
				draw_rect(Rect2(at, Vector2(2, 2)), Color(0.36, 0.27, 0.18))
			draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.45))
			draw_circle(Vector2.ZERO, 14.0, Color(0.16, 0.11, 0.07, 0.8))
			draw_set_transform(Vector2.ZERO)
			return
		# Its shadow, and a ring showing how long it has left.
		draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.45))
		draw_circle(Vector2.ZERO, 12.0, Color(0, 0, 0, 0.22))
		var share := clampf(life / Summons.LIFETIME, 0.0, 1.0)
		var fading := life < 10.0 and fmod(t * 4.0, 1.0) < 0.5
		draw_arc(Vector2.ZERO, 15.0, -PI / 2.0, -PI / 2.0 + TAU * share, 24, Color(_colour, 0.35 if fading else 0.7), 1.5)
		draw_set_transform(Vector2.ZERO)
		if life < 10.0:
			_sprite.modulate.a = 0.45 if fading else 1.0


## A minion's shot: a small arrow or a mote of light flying to its mark.
class Shot:
	extends Node2D

	var _target: Enemy
	var _damage := 0.0
	var _colour := Color.WHITE
	var _arrow := false
	var _life := 2.0

	func setup(target: Enemy, damage: float, colour: Color, arrow: bool) -> void:
		_target = target
		_damage = damage
		_colour = colour
		_arrow = arrow

	func _physics_process(delta: float) -> void:
		_life -= delta
		if _life <= 0.0 or _target == null or not is_instance_valid(_target) or _target.state == Enemy.State.DEAD:
			queue_free()
			return
		var aim := _target.global_position + Vector2(0, -16)
		var way := aim - global_position
		if way.length() < 12.0:
			_target.take_damage(_damage, way.normalized() * 100.0)
			HitSpark.spawn(get_parent(), aim, _colour, false)
			queue_free()
			return
		global_position += way.normalized() * minf(way.length(), 620.0 * delta)
		rotation = way.angle()
		queue_redraw()

	func _draw() -> void:
		if _arrow:
			draw_rect(Rect2(-8, 0, 10, 1), Color(0.55, 0.42, 0.28))
			draw_rect(Rect2(2, -1, 3, 3), _colour)
			draw_rect(Rect2(-9, -1, 2, 1), Color(0.8, 0.8, 0.85))
			draw_rect(Rect2(-9, 1, 2, 1), Color(0.8, 0.8, 0.85))
		else:
			draw_rect(Rect2(-2, -2, 4, 4), _colour)
			draw_rect(Rect2(-1, -1, 2, 2), Color.WHITE)
			draw_rect(Rect2(-6, -1, 3, 2), Color(_colour, 0.5))
