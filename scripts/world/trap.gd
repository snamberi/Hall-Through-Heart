class_name Trap
extends Node2D
## A dungeon trap.
##   "spikes"  spikes in the floor rise and fall; standing on them when they
##             rise hurts.
##   "flame"   a vent glows, then bursts into a ring of fire.
##   "arrows"  a slot in the wall looses an arrow along a line every so often.

var kind := "spikes"
var damage := 10.0
var level := 1
## For arrows: which way they fly, and how far.
var direction := Vector2.RIGHT
var reach := 400.0

var _player: Player
var _time := 0.0
var _hit_this_cycle := false
var _arrows: Array = []

const CYCLE := {"spikes": 2.4, "flame": 3.2, "arrows": 2.2}


static func create(p_kind: String, at: Vector2, player: Player, p_damage: float, p_level: int) -> Trap:
	var trap := Trap.new()
	trap.kind = p_kind
	trap.position = at
	trap._player = player
	trap.damage = p_damage
	trap.level = p_level
	trap.z_index = -6 if p_kind != "arrows" else 5
	trap._time = randf() * CYCLE[p_kind]
	return trap


func _physics_process(delta: float) -> void:
	_time += delta
	var cycle: float = CYCLE[kind]
	if _time >= cycle:
		_time -= cycle
		_hit_this_cycle = false
		if kind == "arrows":
			_arrows.append(0.0)
	var near := is_instance_valid(_player) and not _player.is_dead()
	match kind:
		"spikes":
			if _raised() and near and not _hit_this_cycle and _player.global_position.distance_to(global_position) < 22.0:
				_hit_this_cycle = true
				_player.take_damage(damage, global_position, level)
				_player.apply_status("bleed", 3.0, damage * 0.15)
		"flame":
			if _time > 2.2 and _time < 2.6 and near and not _hit_this_cycle and _player.global_position.distance_to(global_position) < 56.0:
				_hit_this_cycle = true
				_player.take_damage(damage * 1.3, global_position, level, "fire")
				_player.apply_status("burn", 3.0, damage * 0.2)
			if _time > 2.2 and _time - delta <= 2.2:
				RingBurst.spawn(get_parent(), global_position, Elements.color("fire"), 56.0)
	for index in _arrows.size():
		_arrows[index] += delta * 520.0
		var tip: Vector2 = global_position + direction * _arrows[index]
		if near and _player.global_position.distance_to(tip) < 16.0:
			_player.take_damage(damage, tip, level)
			_arrows[index] = reach + 1.0
	_arrows = _arrows.filter(func(d: float) -> bool: return d < reach)
	queue_redraw()


func _raised() -> bool:
	return _time > CYCLE["spikes"] - 0.8


func _draw() -> void:
	match kind:
		"spikes":
			draw_rect(Rect2(-18, -18, 36, 36), Color(0.15, 0.13, 0.16))
			draw_rect(Rect2(-18, -18, 36, 36), Color(0.05, 0.05, 0.07), false, 2.0)
			var up := _raised()
			var warn := _time > CYCLE["spikes"] - 1.2 and not up
			for x in [-10, 0, 10]:
				for y in [-10, 0, 10]:
					var base := Vector2(x, y + 4)
					if up:
						draw_colored_polygon(PackedVector2Array([base + Vector2(-3, 0), base + Vector2(0, -10), base + Vector2(3, 0)]), Color(0.85, 0.85, 0.9))
						draw_line(base + Vector2(0, -10), base + Vector2(1, -4), Color(0.6, 0.1, 0.1), 1.0)
					else:
						draw_circle(base, 1.6, Color(0.9, 0.3, 0.2) if warn else Color(0.05, 0.05, 0.07))
		"flame":
			var glow := clampf((_time - 1.2) / 1.0, 0.0, 1.0)
			draw_circle(Vector2.ZERO, 12.0, Color(0.12, 0.1, 0.1))
			draw_circle(Vector2.ZERO, 8.0, Color(1.0, 0.45, 0.15, 0.25 + 0.75 * glow))
			if _time > 1.4 and _time < 2.2:
				draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.7))
				draw_arc(Vector2.ZERO, 56.0, 0.0, TAU, 32, Color(1.0, 0.5, 0.2, 0.7), 2.0)
				draw_set_transform(Vector2.ZERO)
			if _time > 2.2 and _time < 2.7:
				var share := (_time - 2.2) / 0.5
				draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.7))
				draw_circle(Vector2.ZERO, 56.0 * share, Color(1.0, 0.55, 0.2, 0.55 * (1.0 - share)))
				draw_set_transform(Vector2.ZERO)
		"arrows":
			draw_rect(Rect2(-6, -6, 12, 12), Color(0.1, 0.09, 0.1))
			draw_rect(Rect2(-4, -2, 8, 4), Color(0.8, 0.3, 0.2) if _time > CYCLE["arrows"] - 0.5 else Color(0.03, 0.03, 0.05))
			for distance: float in _arrows:
				var tip := direction * distance
				draw_line(tip - direction * 16.0, tip, Color(0.75, 0.6, 0.4), 2.0)
				draw_colored_polygon(PackedVector2Array([tip + direction * 4.0, tip + direction.orthogonal() * 3.0, tip - direction.orthogonal() * 3.0]), Color(0.85, 0.85, 0.9))
