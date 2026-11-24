extends Node2D
## Experience from a kill, seen: sparks of gold burst from the fallen,
## hang a breath, then each flies one smooth curve into the player and
## lands on time (no circling, however fast the player runs). Every spark
## that lands makes the player glint; when the last one lands, a ring of
## gold closes on them and "+N XP" rises. Drawn pixel by pixel, snapped to
## whole pixels. (Loaded by path.)

var _player: Node2D
var _xp := 0
## Each mote: {from, burst (where the fling ends), bend (sideways sway of
## the flight), delay, flight (seconds in the air), landed}.
var _motes: Array[Dictionary] = []
var _age := 0.0
var _landed := 0
## Seconds since the last landing, for the glint on the player.
var _glint := 9.0
## Seconds since the last mote landed (the closing ring), or -1 before.
var _ring := -1.0

const FLING := 0.26
const HANG := 0.12
const GOLD := Color(1.0, 0.86, 0.42)
const PALE := Color(1.0, 1.0, 0.9)
const EMBER := Color(0.95, 0.62, 0.2)


## Bursts `xp` worth of sparks at `from` toward `player` (or whoever plays
## here, if the killing blow came from no one: a burn, an arrow, a summon).
static func burst(parent: Node, from: Vector2, player: Node2D, xp: int) -> void:
	if parent == null or xp <= 0:
		return
	if player == null or not player.is_in_group("player"):
		player = parent.get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var fx: Node2D = load("res://scripts/effects/xp_motes.gd").new()
	fx._player = player
	fx._xp = xp
	fx.z_index = 60
	fx.top_level = true
	var count := clampi(3 + xp / 6, 4, 16)
	for k in count:
		var angle := TAU * k / count + randf_range(-0.35, 0.35)
		var reach := randf_range(14.0, 30.0)
		fx._motes.append({
			"from": from + Vector2(0, -14),
			"burst": from + Vector2(0, -14) + Vector2.from_angle(angle) * reach + Vector2(0, -10),
			"bend": randf_range(-40.0, 40.0),
			"delay": k * 0.035,
			"flight": randf_range(0.42, 0.6),
			"landed": false,
		})
	parent.add_child(fx)


func _process(delta: float) -> void:
	if not is_instance_valid(_player):
		queue_free()
		return
	_age += delta
	_glint += delta
	for mote: Dictionary in _motes:
		if mote["landed"]:
			continue
		if _age - float(mote["delay"]) >= FLING + HANG + float(mote["flight"]):
			mote["landed"] = true
			_landed += 1
			_glint = 0.0
	if _landed >= _motes.size():
		if _ring < 0.0:
			_ring = 0.0
			DamageNumber.spawn_text(get_parent(), _player.global_position + Vector2(0, -44), "+%d XP" % _xp, Color(0.98, 0.82, 0.38), 13)
			Audio.play("pickup", -16.0, 0.05)
		_ring += delta
		if _ring > 0.3:
			queue_free()
			return
	queue_redraw()


func _target() -> Vector2:
	return _player.global_position + Vector2(0, -20)


## Where a mote is `t` seconds into its life.
func _at(mote: Dictionary, t: float) -> Vector2:
	var from: Vector2 = mote["from"]
	var burst_at: Vector2 = mote["burst"]
	if t < FLING:
		# Flung out, slowing to a stop.
		var k := t / FLING
		return from.lerp(burst_at, 1.0 - (1.0 - k) * (1.0 - k))
	if t < FLING + HANG:
		# Hanging a breath, bobbing up a pixel.
		return burst_at + Vector2(0, -1.0 * sin((t - FLING) / HANG * PI))
	# One curve home, gathering speed: a quadratic path whose middle point
	# swings to the side, ending exactly on the player wherever they are.
	var k := clampf((t - FLING - HANG) / float(mote["flight"]), 0.0, 1.0)
	k = k * k
	var target := _target()
	var middle := burst_at.lerp(target, 0.5) + (target - burst_at).orthogonal().normalized() * float(mote["bend"])
	return burst_at.lerp(middle, k).lerp(middle.lerp(target, k), k)


func _draw() -> void:
	for mote: Dictionary in _motes:
		var t := _age - float(mote["delay"])
		if mote["landed"] or t < 0.0:
			continue
		var at := _at(mote, t).floor()
		var before := _at(mote, maxf(t - 0.03, 0.0)).floor()
		var tail := (before - at)
		# A short tail behind it in flight, longer the faster it goes.
		var steps := mini(int(tail.length()), 5)
		for s in range(steps, 0, -1):
			var p := (at + tail.normalized() * s).floor()
			var fade := 1.0 - float(s) / float(steps + 1)
			draw_rect(Rect2(p, Vector2.ONE), Color(EMBER, 0.25 + 0.5 * fade))
		# A small orb: a dim halo round a gold plus with a pale heart.
		for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			draw_rect(Rect2(at + corner, Vector2.ONE), Color(EMBER, 0.45))
		for arm: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			draw_rect(Rect2(at + arm, Vector2.ONE), GOLD)
		draw_rect(Rect2(at, Vector2.ONE), PALE)
	# Where it fell: a ring of gold spreading out as the sparks fly.
	if _age < FLING + 0.1 and not _motes.is_empty():
		var origin: Vector2 = (_motes[0]["from"] as Vector2).floor()
		var spread := _age / (FLING + 0.1)
		var radius := lerpf(4.0, 22.0, spread)
		for k in 20:
			var p := (origin + Vector2.from_angle(TAU * k / 20.0) * Vector2(radius, radius * 0.6)).floor()
			draw_rect(Rect2(p, Vector2.ONE), Color(GOLD, 1.0 - spread))
	var target := _target().floor()
	# Each landing makes the player glint: a small gold cross.
	if _glint < 0.12:
		var arm := 3 if _glint < 0.06 else 2
		for d in range(1, arm + 1):
			for way: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
				draw_rect(Rect2(target + way * d, Vector2.ONE), Color(GOLD, 1.0 - float(d) / (arm + 1)))
		draw_rect(Rect2(target, Vector2.ONE), PALE)
	# The last one in: a ring of gold closing on them.
	if _ring >= 0.0:
		var radius := lerpf(18.0, 6.0, _ring / 0.3)
		var dots := 16
		for k in dots:
			var p := (target + Vector2.from_angle(TAU * k / dots) * radius).floor()
			draw_rect(Rect2(p, Vector2.ONE), Color(GOLD, 1.0 - _ring / 0.3))
