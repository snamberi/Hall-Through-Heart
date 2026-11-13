class_name AmbientLife
extends Node2D
## Small life that fills the world and asks nothing of the player: bees
## and butterflies over the grass by day, flies above mire and rot,
## fireflies glowing in the dark, birds pecking at the ground that take
## wing when someone comes close, flocks passing overhead, and vultures
## turning over the desert. None of it can be touched or fought.

const T := TerrainTiles.Type
const GREEN: Array[int] = [T.DARK_GRASS, T.DEAD_GRASS, T.THORN, T.PATH]
const ROT: Array[int] = [T.BOG, T.MUD, T.TAR, T.FUNGAL, T.CRIMSON]
const GLOW_LANDS: Array[int] = [T.DARK_GRASS, T.DEAD_GRASS, T.BOG, T.FROSTPINE, T.THORN, T.FUNGAL, T.PATH, T.MUD]
## Most of each kind about at once.
const LIMITS := {"bee": 5, "butterfly": 4, "fly": 12, "firefly": 22, "perched": 4, "vulture": 2}
const BUTTERFLY_COLOURS: Array[Color] = [Color("f0d050"), Color("f08a40"), Color("e8e8f0"), Color("70b0f0"), Color("e070b0")]

var _player: Player
var _world: World
var _day_night: DayNight
var _critters: Array[Dictionary] = []
var _glow: Node2D
var _check := 0.0
var _flock_in := 8.0
var _time := 0.0


func setup(player: Player, world: World, day_night: DayNight) -> void:
	_player = player
	_world = world
	_day_night = day_night
	z_index = 6
	# Fireflies shine through the night, so they sit on a layer of their
	# own above the darkened world.
	var layer := CanvasLayer.new()
	layer.layer = 1
	layer.follow_viewport_enabled = true
	add_child(layer)
	_glow = Node2D.new()
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = additive
	_glow.draw.connect(_draw_glow)
	layer.add_child(_glow)


func _process(delta: float) -> void:
	if _player == null:
		return
	_time += delta
	_check -= delta
	if _check <= 0.0:
		_check = 0.6
		_populate()
	for critter in _critters:
		_move(critter, delta)
	_critters = _critters.filter(func(c: Dictionary) -> bool: return not c.get("gone", false))
	queue_redraw()
	_glow.queue_redraw()


func _count(kind: String) -> int:
	return _critters.filter(func(c: Dictionary) -> bool: return c["kind"] == kind).size()


## Brings in what belongs where the player stands, and lets go of what is
## left behind.
func _populate() -> void:
	var center := _player.global_position
	for critter in _critters:
		if (critter["pos"] as Vector2).distance_to(center) > 900.0:
			critter["gone"] = true
	if _player.indoors or _player.is_dead():
		for critter in _critters:
			critter["gone"] = true
		return
	var tile := _world.tile_type_at_position(center)
	var night := _day_night.is_night()
	var fair := Atmosphere.weather in ["", "Fog", "Mist"]
	var wanted := {}
	if not night and fair and tile in GREEN:
		wanted["bee"] = LIMITS["bee"]
		wanted["butterfly"] = LIMITS["butterfly"]
		wanted["perched"] = LIMITS["perched"]
	if tile in ROT or _near_rot(center):
		wanted["fly"] = LIMITS["fly"]
	if night and tile in GLOW_LANDS and Atmosphere.weather in ["", "Fog", "Mist", "Rain"]:
		wanted["firefly"] = LIMITS["firefly"]
	if not night and tile in [T.SAND, T.ASH, T.SALT]:
		wanted["vulture"] = LIMITS["vulture"]
		wanted["perched"] = 2
	# What no longer belongs here drifts away (bees at nightfall and so on).
	for critter in _critters:
		if LIMITS.has(critter["kind"]) and not wanted.has(critter["kind"]) and randf() < 0.35:
			if critter["kind"] == "perched" and critter["state"] == "ground":
				critter["state"] = "away"
				critter["vel"] = Vector2.from_angle(randf() * TAU) * 140.0
				critter["life"] = 4.0
			elif critter["kind"] != "perched":
				critter["gone"] = true
	for kind: String in wanted:
		var missing: int = wanted[kind] - _count(kind)
		for i in mini(missing, 3):
			_spawn(kind, center)
	# Now and then a flock crosses the sky.
	_flock_in -= 0.6
	if _flock_in <= 0.0 and not night and fair and not tile in [T.VOIDSCAR, T.DEEP_WATER]:
		_flock_in = randf_range(14.0, 34.0)
		_spawn_flock(center, tile)


## Rot draws flies: monster corpses and graveyards nearby.
func _near_rot(center: Vector2) -> bool:
	for node in get_tree().get_nodes_in_group("graveyards"):
		if (node as Node2D).global_position.distance_to(center) < 400.0:
			return true
	return false


func _view_half() -> Vector2:
	var zoom := _player.camera.zoom if _player.camera else Vector2(2, 2)
	return get_viewport_rect().size / zoom / 2.0


func _spawn(kind: String, center: Vector2) -> void:
	var half := _view_half()
	var spot := center + Vector2(randf_range(-half.x, half.x), randf_range(-half.y, half.y)) * 1.15
	var tile := _world.tile_type_at_position(spot)
	if TerrainTiles.is_water(tile) or TerrainTiles.is_solid(tile):
		return
	var critter := {"kind": kind, "pos": spot, "anchor": spot, "height": 12.0, "vel": Vector2.ZERO, "phase": randf() * TAU, "turn": 0.0}
	match kind:
		"bee":
			critter["height"] = randf_range(8.0, 16.0)
		"butterfly":
			critter["height"] = randf_range(14.0, 26.0)
			critter["color"] = BUTTERFLY_COLOURS.pick_random()
		"fly":
			critter["height"] = randf_range(6.0, 20.0)
			# Flies come in a little cloud round one spot.
			for i in randi_range(2, 4):
				var friend := critter.duplicate()
				friend["phase"] = randf() * TAU
				_critters.append(friend)
		"firefly":
			critter["height"] = randf_range(6.0, 34.0)
			critter["vel"] = Vector2.from_angle(randf() * TAU) * 8.0
		"perched":
			critter["height"] = 0.0
			critter["state"] = "ground"
			critter["color"] = Color("2a2830") if tile in [T.ASH, T.DEAD_GRASS, T.SAND, T.SALT] else Color("8a6a48")
			critter["hop"] = randf_range(0.5, 2.0)
		"vulture":
			critter["height"] = randf_range(120.0, 170.0)
			critter["radius"] = randf_range(60.0, 110.0)
			critter["color"] = Color("2c2426")
	_critters.append(critter)


func _spawn_flock(center: Vector2, tile: int) -> void:
	var half := _view_half()
	var heading := Vector2.from_angle(randf() * TAU)
	var start := center - heading * (half.length() + 60.0) + heading.orthogonal() * randf_range(-half.y, half.y) * 0.6
	var colour := Color("e8e8ec") if tile in [T.SAND, T.SALT, T.SHALLOW_WATER] else Color("2a2830") if tile in [T.ASH, T.DEAD_GRASS, T.CRIMSON] else Color("4a3a30")
	var size := randi_range(3, 7)
	var speed := randf_range(90.0, 130.0)
	for i in size:
		# A loose V.
		var row := (i + 1) / 2
		var side := 1.0 if i % 2 == 0 else -1.0
		var spot := start - heading * row * 16.0 + heading.orthogonal() * side * row * 13.0
		_critters.append({"kind": "flyer", "pos": spot, "anchor": spot, "height": randf_range(70.0, 110.0), "vel": heading * speed,
			"phase": randf() * TAU, "color": colour, "life": (half.length() * 2.0 + 300.0) / speed})
	if randf() < 0.5:
		Audio.play("bird", -20.0, 0.3)


func _move(critter: Dictionary, delta: float) -> void:
	var t := _time + float(critter["phase"])
	match critter["kind"]:
		"bee":
			# Darts about a flower, then moves on to the next.
			critter["turn"] = float(critter["turn"]) - delta
			if float(critter["turn"]) <= 0.0:
				critter["turn"] = randf_range(1.5, 4.0)
				critter["anchor"] = (critter["pos"] as Vector2) + Vector2.from_angle(randf() * TAU) * randf_range(20.0, 60.0)
			var target: Vector2 = critter["anchor"] + Vector2(sin(t * 7.0) * 6.0, cos(t * 5.3) * 4.0)
			critter["pos"] = (critter["pos"] as Vector2).lerp(target, delta * 3.0)
			if randf() < delta * 0.05 and (critter["pos"] as Vector2).distance_to(_player.global_position) < 60.0:
				Audio.play("buzz", -24.0, 0.15)
		"butterfly":
			critter["turn"] = float(critter["turn"]) - delta
			if float(critter["turn"]) <= 0.0:
				critter["turn"] = randf_range(2.0, 5.0)
				critter["anchor"] = (critter["pos"] as Vector2) + Vector2.from_angle(randf() * TAU) * randf_range(40.0, 100.0)
			var drift: Vector2 = ((critter["anchor"] as Vector2) - (critter["pos"] as Vector2)).limit_length(18.0)
			critter["pos"] = (critter["pos"] as Vector2) + (drift + Vector2(sin(t * 2.2) * 10.0, cos(t * 1.7) * 6.0)) * delta
		"fly":
			critter["pos"] = (critter["anchor"] as Vector2) + Vector2(sin(t * 11.0) * 9.0 + sin(t * 23.0) * 3.0, cos(t * 13.0) * 6.0)
		"firefly":
			var wander := Vector2.from_angle(sin(t * 0.5) * PI + float(critter["phase"])) * 9.0
			critter["pos"] = (critter["pos"] as Vector2) + wander * delta
			critter["height"] = 20.0 + sin(t * 0.8) * 12.0
		"perched":
			_move_perched(critter, delta)
		"flyer":
			critter["pos"] = (critter["pos"] as Vector2) + (critter["vel"] as Vector2) * delta
			critter["life"] = float(critter["life"]) - delta
			if float(critter["life"]) <= 0.0:
				critter["gone"] = true
		"vulture":
			var radius: float = critter["radius"]
			critter["pos"] = (critter["anchor"] as Vector2) + Vector2(cos(t * 0.35), sin(t * 0.35) * 0.6) * radius


## Hops and pecks until someone comes close, then flies off and away.
func _move_perched(critter: Dictionary, delta: float) -> void:
	if critter["state"] == "ground":
		if (critter["pos"] as Vector2).distance_to(_player.global_position) < 75.0:
			critter["state"] = "away"
			var away := ((critter["pos"] as Vector2) - _player.global_position).normalized().rotated(randf_range(-0.6, 0.6))
			critter["vel"] = away * randf_range(130.0, 170.0)
			critter["life"] = 4.0
			Audio.play("flutter", -16.0, 0.2)
			return
		critter["hop"] = float(critter["hop"]) - delta
		if float(critter["hop"]) <= 0.0:
			critter["hop"] = randf_range(0.6, 2.2)
			critter["anchor"] = (critter["pos"] as Vector2) + Vector2(randf_range(-14.0, 14.0), randf_range(-8.0, 8.0))
			critter["jump"] = 0.25
		critter["jump"] = maxf(float(critter.get("jump", 0.0)) - delta, 0.0)
		critter["pos"] = (critter["pos"] as Vector2).move_toward(critter["anchor"], 50.0 * delta)
		critter["height"] = sin(float(critter["jump"]) / 0.25 * PI) * 4.0
	else:
		critter["pos"] = (critter["pos"] as Vector2) + (critter["vel"] as Vector2) * delta
		critter["height"] = minf(float(critter["height"]) + 60.0 * delta, 90.0)
		critter["life"] = float(critter["life"]) - delta
		if float(critter["life"]) <= 0.0:
			critter["gone"] = true


func _draw() -> void:
	for critter in _critters:
		var ground: Vector2 = critter["pos"]
		var height: float = critter["height"]
		var at := ground - Vector2(0, height)
		var t := _time + float(critter["phase"])
		match critter["kind"]:
			"bee":
				_shadow(ground, 2.0, 0.18)
				var flap := absf(sin(t * 60.0))
				draw_rect(Rect2(at + Vector2(-2, -1), Vector2(4, 3)), Color("f0c030"))
				draw_rect(Rect2(at + Vector2(-0.5, -1), Vector2(1, 3)), Color("1a1410"))
				draw_rect(Rect2(at + Vector2(-1.5, -2.5 - flap), Vector2(3, 1.5)), Color(1, 1, 1, 0.75))
			"butterfly":
				_shadow(ground, 3.0, 0.12)
				var open := absf(sin(t * 9.0))
				var colour: Color = critter["color"]
				draw_rect(Rect2(at + Vector2(-0.5, -2), Vector2(1, 4)), Color("2a2020"))
				draw_rect(Rect2(at + Vector2(-0.5 - 3.5 * open, -2.5), Vector2(3.5 * open, 3)), colour)
				draw_rect(Rect2(at + Vector2(0.5, -2.5), Vector2(3.5 * open, 3)), colour)
				draw_rect(Rect2(at + Vector2(-0.5 - 2.5 * open, 0.5), Vector2(2.5 * open, 2)), colour.darkened(0.2))
				draw_rect(Rect2(at + Vector2(0.5, 0.5), Vector2(2.5 * open, 2)), colour.darkened(0.2))
			"fly":
				draw_rect(Rect2(at, Vector2(1.5, 1.5)), Color(0.08, 0.08, 0.08, 0.9))
			"firefly":
				# The body by day-light; the glow is drawn on the layer above.
				draw_rect(Rect2(at, Vector2(1, 1)), Color(0.2, 0.25, 0.1))
			"perched":
				_shadow(ground, 3.0, 0.25)
				_draw_bird(at, critter["color"], critter["state"] != "ground", t, (critter["vel"] as Vector2).x if critter["state"] != "ground" else sin(t))
			"flyer", "vulture":
				_shadow(ground, 3.5, 0.12)
				_draw_bird(at, critter["color"], true, t * (0.4 if critter["kind"] == "vulture" else 1.0), (critter["vel"] as Vector2).x if critter["kind"] == "flyer" else 1.0, 1.6 if critter["kind"] == "vulture" else 1.0)


func _shadow(ground: Vector2, radius: float, alpha: float) -> void:
	draw_set_transform(ground, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, radius, Color(0, 0, 0, alpha))
	draw_set_transform(Vector2.ZERO)


## A small bird: on the ground a round body with a beak, a bob of the head;
## in the air two beating wings.
func _draw_bird(at: Vector2, colour: Color, flying: bool, t: float, facing: float, size: float = 1.0) -> void:
	var side := 1.0 if facing >= 0.0 else -1.0
	if not flying:
		draw_rect(Rect2(at + Vector2(-2.5, -3), Vector2(5, 3)), colour)
		draw_rect(Rect2(at + Vector2(-2.5 * side + (1.5 if side > 0 else -0.5), -5 + absf(sin(t * 3.0))), Vector2(2.5, 2.5)), colour.lightened(0.1))
		draw_rect(Rect2(at + Vector2(2.5 * side - (0.0 if side > 0 else 1.0), -4 + absf(sin(t * 3.0))), Vector2(1.5, 1)), Color("e0a040"))
		draw_rect(Rect2(at + Vector2(-0.5, 0), Vector2(1, 1)), Color("3a2a20"))
		return
	var beat := sin(t * 14.0)
	var wing := Vector2(5.0 * size, -3.0 * size * beat)
	draw_line(at, at + Vector2(-wing.x, wing.y), colour, 1.2 * size)
	draw_line(at, at + Vector2(wing.x, wing.y), colour, 1.2 * size)
	draw_rect(Rect2(at + Vector2(-1, -1) * size, Vector2(2, 2) * size), colour)


func _draw_glow() -> void:
	for critter in _critters:
		if critter["kind"] != "firefly":
			continue
		var at: Vector2 = (critter["pos"] as Vector2) - Vector2(0, critter["height"])
		var pulse := 0.5 + 0.5 * sin((_time + float(critter["phase"])) * 2.3)
		if pulse < 0.15:
			continue
		var glow := Color(0.75, 1.0, 0.35, 0.10 * pulse)
		_glow.draw_circle(at, 7.0, glow)
		_glow.draw_circle(at, 3.5, Color(glow, 0.22 * pulse))
		_glow.draw_rect(Rect2(at - Vector2(0.75, 0.75), Vector2(1.5, 1.5)), Color(0.95, 1.0, 0.6, 0.9 * pulse))
