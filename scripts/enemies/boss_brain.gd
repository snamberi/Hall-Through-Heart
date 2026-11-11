class_name BossBrain
extends RefCounted
## How a world boss fights: it walks at the player and picks a move from its
## list, each with a clear warning drawn on the ground first. At two thirds
## and one third of its health it gains new moves and grows faster.

var boss_id := ""
var data: Dictionary
var phase := 1
var moves: Array = []

var _enemy: Enemy
var _move := ""
## "telegraph" (warning drawn), "act" (the move plays out), "rest", "walk".
var _stage := "walk"
var _time := 0.0
var _rest := 1.5
var _aim := Vector2.ZERO
var _target_point := Vector2.ZERO
var _meteors: Array = []
var _spiral_angle := 0.0
var _shots_left := 0
var _shot_timer := 0.0
var _hit_done := false


func _init(enemy: Enemy, id: String) -> void:
	_enemy = enemy
	boss_id = id
	data = BossDB.BOSSES[id]
	moves = (data["attacks"] as Array).duplicate()


func speed_scale() -> float:
	return 1.0 + 0.2 * (phase - 1)


func physics(delta: float) -> void:
	var e := _enemy
	var target := e.target
	var has_target := target != null and not target.is_dead()
	_check_phase()
	if not has_target or e.global_position.distance_to(target.global_position) > 900.0:
		e.velocity = e.velocity.move_toward(Vector2.ZERO, 800.0 * delta)
		return
	var to_target := target.global_position - e.global_position
	_time -= delta * speed_scale()
	match _stage:
		"walk":
			e.velocity = to_target.normalized() * e._speed * 0.75 * speed_scale() if to_target.length() > 70.0 else Vector2.ZERO
			_rest -= delta * speed_scale()
			if _rest <= 0.0:
				_begin(moves.pick_random(), to_target)
		"telegraph":
			e.velocity = Vector2.ZERO
			if _time <= 0.0:
				_act(to_target)
		"act":
			_play(delta, to_target)
		"rest":
			e.velocity = e.velocity.move_toward(Vector2.ZERO, 1200.0 * delta)
			if _time <= 0.0:
				_stage = "walk"
				_rest = randf_range(0.6, 1.4) / speed_scale()
	_update_meteors(delta)
	e.queue_redraw()


func _check_phase() -> void:
	var share := _enemy.health.current / _enemy.health.max_health
	var wanted := 3 if share < 0.34 else 2 if share < 0.67 else 1
	if wanted > phase:
		phase = wanted
		moves.append_array(data.get("phase%d" % phase, []))
		Events.announcement.emit(data["name"].to_upper(), "grows furious" if phase == 2 else "is desperate")
		RingBurst.spawn(_enemy.get_parent(), _enemy.global_position + Vector2(0, -20), data["color"], 160.0)
		_enemy.target.shake_camera(8.0)


func _begin(move: String, to_target: Vector2) -> void:
	_move = move
	_stage = "telegraph"
	_aim = to_target.normalized()
	_target_point = _enemy.target.global_position
	_hit_done = false
	_time = {"slam": 0.9, "charge": 0.75, "summon": 0.8, "volley": 0.6, "spiral": 0.6, "meteor": 0.5, "pools": 0.6, "nova": 1.2, "teleport": 0.5}.get(move, 0.7)
	_enemy._visual.modulate = Color(1.6, 0.7, 0.7)


func _act(to_target: Vector2) -> void:
	var e := _enemy
	e._visual.modulate = e._tint
	_stage = "act"
	match _move:
		"slam":
			_ring_damage(e.global_position, 0.0, 140.0, 1.4)
			e.target.shake_camera(7.0)
			_finish(0.8)
		"charge":
			_time = 0.55
			e.velocity = _aim * 760.0
		"summon":
			for i in 2 + phase:
				e.wants_minion.emit(e)
			RingBurst.spawn(e.get_parent(), e.global_position, data["color"], 120.0)
			_finish(1.0)
		"volley":
			var count := 10 + 4 * phase
			for i in count:
				_shoot(Vector2.from_angle(TAU * i / count + randf() * 0.2))
			_finish(0.9)
		"spiral":
			_shots_left = 18 + 6 * phase
			_shot_timer = 0.0
		"meteor":
			for i in 2 + 2 * phase:
				var spot := e.target.global_position + (Vector2.from_angle(randf() * TAU) * randf_range(0.0, 120.0) if i > 0 else Vector2.ZERO)
				_meteors.append({"at": spot, "time": 1.1})
			_finish(0.6)
		"pools":
			for i in 3:
				var spot := e.target.global_position + Vector2.from_angle(randf() * TAU) * randf_range(0.0, 90.0)
				HazardZone.spawn(e.get_parent(), spot, e.target, 60.0, 6.0, data["color"], {"status": "poison", "duration": 3.0, "power": 0.3}, e._damage * 0.6)
			_finish(0.8)
		"nova":
			# Everything outside a small ring round the boss is struck: get close.
			_ring_damage(e.global_position, 90.0, 300.0, 1.2)
			RingBurst.spawn(e.get_parent(), e.global_position, data["color"], 300.0)
			_finish(1.0)
		"teleport":
			RingBurst.spawn(e.get_parent(), e.global_position + Vector2(0, -20), data["color"], 60.0)
			e.global_position = e.target.global_position - to_target.normalized() * 110.0
			RingBurst.spawn(e.get_parent(), e.global_position + Vector2(0, -20), data["color"], 60.0)
			_move = "slam"
			_stage = "telegraph"
			_time = 0.45
			_target_point = e.target.global_position


func _play(delta: float, _to_target: Vector2) -> void:
	var e := _enemy
	match _move:
		"charge":
			e.velocity = _aim * 760.0
			if not _hit_done and e.global_position.distance_to(e.target.global_position) < e.body_radius + 20.0:
				_hit_done = true
				e._hit_target(e._current_damage() * 1.3)
			if _time <= 0.0:
				_finish(0.9)
		"spiral":
			e.velocity = Vector2.ZERO
			_shot_timer -= delta
			while _shot_timer <= 0.0 and _shots_left > 0:
				_shot_timer += 0.06
				_shots_left -= 1
				_spiral_angle += 0.45
				_shoot(Vector2.from_angle(_spiral_angle))
				_shoot(Vector2.from_angle(_spiral_angle + PI))
			if _shots_left <= 0:
				_finish(0.8)
		_:
			_finish(0.6)


func _finish(rest: float) -> void:
	_stage = "rest"
	_time = rest


func _shoot(direction: Vector2) -> void:
	var attack := {"speed": 300.0, "sprite": 2, "color": data["color"]}
	EnemyProjectile.fire(_enemy, _enemy.target, attack, _enemy._current_damage() * 0.6, direction)


## Hurts the player if they stand between two radii of a point.
func _ring_damage(center: Vector2, inner: float, outer: float, multiplier: float) -> void:
	var distance := _enemy.target.global_position.distance_to(center)
	if distance >= inner and distance <= outer:
		_enemy._hit_target(_enemy._current_damage() * multiplier)


func _update_meteors(delta: float) -> void:
	for meteor: Dictionary in _meteors:
		meteor["time"] -= delta
		if meteor["time"] <= 0.0:
			RingBurst.spawn(_enemy.get_parent(), meteor["at"], data["color"], 70.0)
			HitSpark.spawn(_enemy.get_parent(), meteor["at"] + Vector2(0, -8), data["color"], true)
			if _enemy.target.global_position.distance_to(meteor["at"]) < 64.0:
				_enemy._hit_target(_enemy._current_damage() * 1.1)
	_meteors = _meteors.filter(func(m: Dictionary) -> bool: return m["time"] > 0.0)


## Warnings on the ground, in the enemy's own space.
func draw() -> void:
	var e := _enemy
	var color: Color = data["color"]
	# A smouldering aura under the boss, brighter as it grows desperate.
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 220.0)
	e.draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.42))
	e.draw_circle(Vector2.ZERO, e.body_radius + 26.0, Color(color, 0.08 + 0.05 * phase + 0.05 * pulse))
	e.draw_arc(Vector2.ZERO, e.body_radius + 26.0 + 4.0 * pulse, 0.0, TAU, 40, Color(color, 0.55), 2.0)
	for k in 6:
		var angle := Time.get_ticks_msec() / 900.0 + TAU * k / 6.0
		e.draw_circle(Vector2.from_angle(angle) * (e.body_radius + 26.0), 3.0, Color(color, 0.8))
	e.draw_set_transform(Vector2.ZERO)
	for meteor: Dictionary in _meteors:
		var at: Vector2 = e.to_local(meteor["at"])
		var fill: float = 1.0 - meteor["time"] / 1.1
		e.draw_set_transform(at, 0.0, Vector2(1.0, 0.7))
		e.draw_circle(Vector2.ZERO, 64.0 * fill, Color(color, 0.25))
		e.draw_arc(Vector2.ZERO, 64.0, 0.0, TAU, 32, Color(color, 0.9), 2.0)
		e.draw_set_transform(Vector2.ZERO)
	if _stage != "telegraph":
		return
	match _move:
		"slam":
			e.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.7))
			e.draw_circle(Vector2.ZERO, 140.0, Color(color, 0.18))
			e.draw_arc(Vector2.ZERO, 140.0, 0.0, TAU, 40, Color(color, 0.9), 2.5)
			e.draw_set_transform(Vector2.ZERO)
		"charge":
			var end := _aim * 420.0
			var side := _aim.orthogonal() * 22.0
			e.draw_colored_polygon(PackedVector2Array([side, end + side, end - side, -side]), Color(color, 0.22))
			e.draw_line(Vector2.ZERO, end, Color(color, 0.9), 2.0)
		"nova":
			e.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.7))
			e.draw_arc(Vector2.ZERO, 300.0, 0.0, TAU, 64, Color(color, 0.9), 3.0)
			e.draw_arc(Vector2.ZERO, 90.0, 0.0, TAU, 32, Color(0.6, 1.0, 0.6, 0.9), 2.5)
			e.draw_circle(Vector2.ZERO, 90.0, Color(0.6, 1.0, 0.6, 0.12))
			e.draw_set_transform(Vector2.ZERO)
		_:
			e.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.7))
			e.draw_arc(Vector2.ZERO, e.body_radius + 20.0, 0.0, TAU * (1.0 - _time), 32, Color(color, 0.9), 3.0)
			e.draw_set_transform(Vector2.ZERO)
