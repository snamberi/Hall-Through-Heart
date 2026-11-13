class_name HandFX
extends Node2D
## What the hands show. With magic in hand the casting hand takes on the
## school: fire licks up from it, lightning crackles round it, frost mists
## and sparkles, light glows and throws rays, and dark magic wraps the
## whole body in a creeping aura. Fighting bare with a combat style, both
## fists carry its element (flames, water droplets, shadow wisps, stone
## dust, sparks, swirling wind).

var _player: Player
var _time := 0.0
var _motes: Array[Dictionary] = []
var _spawn := 0.0


func setup(player: Player) -> void:
	_player = player
	z_index = 3


func _look() -> Dictionary:
	if _player.is_dead():
		return {}
	if _player.holding_magic():
		var school := _player.magic_school
		return {"kind": school, "color": MagicDB.SCHOOLS[school]["color"], "hands": 1, "aura": school == "dark"}
	if _player.fighting_bare() and _player.styles and _player.styles.equipped != "fist":
		var style := _player.styles.data()
		var kind: String = {"fire_fist": "fire", "water_karate": "water", "dark_step": "dark", "stone_palm": "stone", "storm_kick": "lightning", "wind_crane": "wind"}.get(_player.styles.equipped, "")
		return {"kind": kind, "color": style["color"], "hands": 2, "aura": _player.styles.equipped == "dark_step"}
	return {}


## Where the hands are, for the way the player faces: worked out from the
## body sprite's centre and size (the rig is 44 units across a 96px frame,
## hands at the ends of the arms, a little below the middle).
func _hands(count: int) -> Array[Vector2]:
	var sprite := _player.get_node_or_null("Visual/Sprite") as Node2D
	var unit := 1.6
	var center := Vector2(0, -23)
	if sprite:
		unit = 96.0 / 44.0 * absf(sprite.scale.x)
		center = sprite.global_position - _player.global_position
	var reach := _player.facing * 4.0 * unit if _player.state == Player.State.ATTACK else Vector2.ZERO
	if absf(_player.facing.y) > absf(_player.facing.x):
		# Facing toward or away from us: a hand at each side.
		var hands: Array[Vector2] = [center + Vector2(8.5 * unit, 9.5 * unit) + reach, center + Vector2(-8.5 * unit, 9.5 * unit) + reach]
		return hands.slice(0, count)
	var side := 1.0 if _player.facing.x >= 0.0 else -1.0
	var both: Array[Vector2] = [center + Vector2(9.0 * unit * side, 9.0 * unit) + reach, center + Vector2(-4.0 * unit * side, 8.0 * unit) + reach * 0.5]
	return both.slice(0, count)


func _process(delta: float) -> void:
	_time += delta
	var look := _look()
	visible = not look.is_empty() or not _motes.is_empty()
	if not look.is_empty():
		_spawn -= delta
		if _spawn <= 0.0:
			_spawn = 0.05
			for hand in _hands(look["hands"]):
				_emit(look, hand)
			if look.get("aura", false):
				_motes.append({"pos": Vector2(randf_range(-12.0, 12.0), randf_range(-36.0, 0.0)), "vel": Vector2(randf_range(-6.0, 6.0), -randf_range(10.0, 26.0)),
					"life": 0.9, "age": 0.0, "color": look["color"].darkened(0.4), "size": randf_range(2.0, 3.5), "kind": "wisp"})
	for mote in _motes:
		mote["age"] += delta
		mote["pos"] += mote["vel"] * delta
	_motes = _motes.filter(func(mote: Dictionary) -> bool: return mote["age"] < mote["life"])
	if visible:
		queue_redraw()


func _emit(look: Dictionary, hand: Vector2) -> void:
	var color: Color = look["color"]
	match str(look["kind"]):
		"fire":
			_motes.append({"pos": hand + Vector2(randf_range(-2.0, 2.0), 0), "vel": Vector2(randf_range(-6.0, 6.0), -randf_range(26.0, 44.0)), "life": 0.45, "age": 0.0,
				"color": [Color(1.0, 0.9, 0.4), color, Color(1.0, 0.35, 0.1)][randi() % 3], "size": randf_range(1.5, 2.6), "kind": "ember"})
		"water":
			var angle := _time * 6.0 + randf() * TAU
			_motes.append({"pos": hand + Vector2.from_angle(angle) * 5.0, "vel": Vector2.from_angle(angle + PI / 2.0) * 18.0 + Vector2(0, 14), "life": 0.5, "age": 0.0,
				"color": color.lightened(0.3), "size": 1.6, "kind": "drop"})
		"frost":
			_motes.append({"pos": hand + Vector2(randf_range(-4.0, 4.0), randf_range(-3.0, 3.0)), "vel": Vector2(randf_range(-8.0, 8.0), randf_range(-8.0, 4.0)), "life": 0.7, "age": 0.0,
				"color": Color(0.85, 0.95, 1.0, 0.8), "size": randf_range(1.2, 2.4), "kind": "mist"})
		"lightning":
			if randf() < 0.5:
				_motes.append({"pos": hand, "vel": Vector2.ZERO, "life": 0.08, "age": 0.0, "color": Color(0.9, 0.95, 1.0), "size": 1.0, "kind": "spark",
					"to": hand + Vector2.from_angle(randf() * TAU) * randf_range(6.0, 11.0)})
		"light":
			_motes.append({"pos": hand + Vector2(randf_range(-3.0, 3.0), 0), "vel": Vector2(0, -randf_range(8.0, 16.0)), "life": 0.6, "age": 0.0,
				"color": Color(1.0, 0.95, 0.7), "size": 1.4, "kind": "mote"})
		"dark":
			_motes.append({"pos": hand + Vector2(randf_range(-3.0, 3.0), 0), "vel": Vector2(randf_range(-10.0, 10.0), -randf_range(10.0, 22.0)), "life": 0.6, "age": 0.0,
				"color": color, "size": randf_range(1.6, 2.6), "kind": "wisp"})
		"stone":
			if randf() < 0.35:
				_motes.append({"pos": hand + Vector2(randf_range(-4.0, 4.0), 2), "vel": Vector2(randf_range(-6.0, 6.0), randf_range(14.0, 24.0)), "life": 0.5, "age": 0.0,
					"color": color.darkened(randf() * 0.3), "size": 1.4, "kind": "mote"})
		"wind":
			var turn := _time * 9.0 + randf() * TAU
			_motes.append({"pos": hand + Vector2.from_angle(turn) * 7.0, "vel": Vector2.from_angle(turn + PI / 2.0) * 30.0, "life": 0.3, "age": 0.0,
				"color": Color(color, 0.7), "size": 1.0, "kind": "streak"})


func _draw() -> void:
	var look := _look()
	if not look.is_empty():
		var color: Color = look["color"]
		var pulse := 0.5 + 0.5 * sin(_time * 7.0)
		if look.get("aura", false):
			draw_circle(Vector2(0, -18), 20.0 + pulse * 2.0, Color(color.darkened(0.5), 0.16))
			draw_circle(Vector2(0, -18), 14.0, Color(color.darkened(0.6), 0.12))
		for hand in _hands(look["hands"]):
			draw_circle(hand, 6.0 + pulse * 1.5, Color(color, 0.18))
			draw_circle(hand, 3.0, Color(color.lightened(0.3), 0.45))
			if look["kind"] == "fire":
				for k in 3:
					var x := (k - 1) * 2.2
					var tall := 5.0 + 3.0 * sin(_time * 14.0 + k * 2.0)
					draw_colored_polygon(PackedVector2Array([hand + Vector2(x - 1.6, 1), hand + Vector2(x, -tall), hand + Vector2(x + 1.6, 1)]), Color(1.0, 0.75, 0.3, 0.85))
			elif look["kind"] == "light":
				for k in 6:
					var dir := Vector2.from_angle(k * TAU / 6.0 + _time)
					draw_line(hand + dir * 4.0, hand + dir * (8.0 + pulse * 3.0), Color(1.0, 0.95, 0.7, 0.6), 1.0)
	for mote in _motes:
		var fade: float = 1.0 - mote["age"] / mote["life"]
		var color: Color = mote["color"]
		match str(mote["kind"]):
			"spark":
				var line := PackedVector2Array([mote["pos"], (mote["pos"] + mote["to"]) / 2.0 + Vector2(randf_range(-2, 2), randf_range(-2, 2)), mote["to"]])
				draw_polyline(line, Color(color, fade), 1.0)
			"streak":
				draw_line(mote["pos"], mote["pos"] - (mote["vel"] as Vector2).normalized() * 4.0, Color(color, color.a * fade), 1.0)
			"wisp", "mist":
				draw_circle(mote["pos"], mote["size"] * (1.0 + (1.0 - fade)), Color(color, color.a * fade * 0.7))
			_:
				draw_circle(mote["pos"], mote["size"], Color(color, fade))
