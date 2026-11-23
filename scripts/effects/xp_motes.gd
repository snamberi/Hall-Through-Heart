extends Node2D
## Experience from a kill, seen: sparks of gold burst from the fallen,
## hang a breath, then stream to the player in curving flights, a whole
## pixel at a time with a short tail; when the last lands, "+N XP" rises
## over the player and the bar flashes (Events.xp_gained). (Loaded by path.)

var _player: Node2D
var _xp := 0
## Each mote: [position, velocity, age, landed].
var _motes: Array = []
var _landed := 0


static func burst(parent: Node, from: Vector2, player: Node2D, xp: int) -> void:
	if parent == null or player == null or xp <= 0:
		return
	var fx: Node2D = load("res://scripts/effects/xp_motes.gd").new()
	fx._player = player
	fx._xp = xp
	fx.z_index = 60
	var count := clampi(2 + xp / 5, 3, 14)
	for k in count:
		var angle := TAU * k / count + randf_range(-0.4, 0.4)
		fx._motes.append([from + Vector2(0, -16), Vector2.from_angle(angle) * randf_range(70.0, 140.0) + Vector2(0, -40), -k * 0.03, false])
	parent.add_child(fx)


func _process(delta: float) -> void:
	if not is_instance_valid(_player):
		queue_free()
		return
	var target := _player.global_position + Vector2(0, -20)
	for mote: Array in _motes:
		if mote[3]:
			continue
		mote[2] += delta
		var age: float = mote[2]
		if age < 0.0:
			continue
		var at: Vector2 = mote[0]
		var velocity: Vector2 = mote[1]
		if age < 0.28:
			# The burst: flung out, slowing.
			velocity *= pow(0.02, delta)
		else:
			# Drawn to the player, faster and faster, curving in.
			var to := target - at
			var pull := 900.0 + age * 1800.0
			velocity += to.normalized() * pull * delta
			velocity = velocity.limit_length(220.0 + age * 520.0)
			if to.length() < 12.0:
				mote[3] = true
				_landed += 1
				continue
		mote[0] = at + velocity * delta
		mote[1] = velocity
	if _landed >= _motes.size():
		DamageNumber.spawn_text(get_parent(), _player.global_position + Vector2(0, -44), "+%d XP" % _xp, Color(0.98, 0.82, 0.38), 13)
		Audio.play("pickup", -16.0, 0.05)
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	for mote: Array in _motes:
		if mote[3] or float(mote[2]) < 0.0:
			continue
		var at: Vector2 = (mote[0] as Vector2).floor()
		var velocity: Vector2 = mote[1]
		var tail := (velocity.normalized() * -1.0).round()
		draw_rect(Rect2(at + tail * 2.0, Vector2.ONE), Color(0.95, 0.62, 0.2, 0.45))
		draw_rect(Rect2(at + tail, Vector2.ONE), Color(0.98, 0.76, 0.3, 0.8))
		draw_rect(Rect2(at, Vector2(2, 2)), Color(1.0, 0.86, 0.42))
		draw_rect(Rect2(at, Vector2.ONE), Color(1, 1, 0.92))
