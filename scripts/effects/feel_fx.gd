class_name FeelFX
extends Node2D
const PX := preload("res://scripts/effects/pixel_draw.gd")
## Small effects that make moments feel like something happened:
##  - soul motes stream out of a defeated foe and home in on the player,
##    more of them, and richer in colour, the stronger the foe;
##  - a level up raises a pillar of gold light with rings and sparks
##    spiralling up round the player;
##  - a real heal (not regeneration ticking) blooms green motes;
##  - a critical hit flashes a white four-point star where it lands;
##  - every other blow that lands sparks there: a bright core and cross,
##    an X of spikes, a broken ring, then flecks thrown away from the
##    striker, four whole-pixel frames in a seventh of a second.
## Everything is drawn here in world space, from plain lists.

static var instance: FeelFX

const RANK_MOTES := {"normal": 3, "elite": 6, "champion": 9, "miniboss": 14, "boss": 24}
const RANK_COLOR := {"normal": Color(0.75, 0.9, 1.0), "elite": Color(1.0, 0.85, 0.4), "champion": Color(0.85, 0.6, 1.0),
	"miniboss": Color(1.0, 0.6, 0.45), "boss": Color(1.0, 0.35, 0.4)}

var _player: Player
var _motes: Array[Dictionary] = []
var _stars: Array[Dictionary] = []
var _impacts: Array[Dictionary] = []
const IMPACT_SECONDS := 0.14
var _blooms: Array[Dictionary] = []
var _pillars: Array[Dictionary] = []
var _last_health := -1.0


func setup(player: Player) -> void:
	instance = self
	_player = player
	z_index = 60
	Events.enemy_killed.connect(_on_kill)
	Events.level_up.connect(func(_level: int) -> void: level_up())
	player.health.changed.connect(_on_health)


func _on_kill(info: Dictionary) -> void:
	if info.get("fragment", false):
		return
	var rank := str(info.get("rank", "normal"))
	var color: Color = RANK_COLOR.get(rank, RANK_COLOR["normal"])
	var at: Vector2 = info.get("position", Vector2.ZERO) + Vector2(0, -16)
	for i in RANK_MOTES.get(rank, 3):
		_motes.append({"pos": at, "vel": Vector2.from_angle(randf() * TAU) * randf_range(60.0, 170.0) + Vector2(0, -60), "color": color,
			"age": 0.0, "delay": randf_range(0.25, 0.55), "trail": PackedVector2Array(), "size": randf_range(1.6, 2.6)})


func level_up() -> void:
	_pillars.append({"age": 0.0})
	for i in 26:
		_motes.append({"pos": _player.global_position + Vector2.from_angle(TAU * i / 26.0) * 34.0, "vel": Vector2(0, -randf_range(40.0, 120.0)),
			"color": Color(1.0, 0.85, 0.4), "age": 0.0, "delay": 99.0, "life": randf_range(0.8, 1.4), "spin": i, "trail": PackedVector2Array(), "size": 2.0})


func _on_health(current: float, maximum: float) -> void:
	if _last_health >= 0.0 and current - _last_health >= maximum * 0.04:
		for i in 12:
			_blooms.append({"pos": Vector2(randf_range(-18.0, 18.0), randf_range(-36.0, 0.0)), "age": -randf() * 0.3, "life": randf_range(0.7, 1.1)})
	_last_health = current


## A white star at a critical hit.
static func crit(at: Vector2) -> void:
	if instance:
		instance._stars.append({"pos": at + Vector2(0, -18), "age": 0.0, "angle": randf() * 0.6})


## Sparks where a blow lands: `away` is the way it was struck (from the
## striker toward the struck), `tint` the colour of its rim.
static func impact(at: Vector2, away: Vector2, tint: Color = Color(1.0, 0.82, 0.45)) -> void:
	if instance:
		instance._impacts.append({"pos": at.floor(), "away": away.normalized() if away != Vector2.ZERO else Vector2.RIGHT, "age": 0.0, "tint": tint})


func _process(delta: float) -> void:
	if _player == null:
		return
	for spark in _impacts:
		spark["age"] += delta
	_impacts = _impacts.filter(func(spark: Dictionary) -> bool: return spark["age"] < IMPACT_SECONDS)
	var home := _player.global_position + Vector2(0, -20)
	for mote in _motes:
		mote["age"] += delta
		var pos: Vector2 = mote["pos"]
		var vel: Vector2 = mote["vel"]
		var age: float = mote["age"]
		var delay: float = mote["delay"]
		if age > delay:
			# Homing: steer harder the longer it flies.
			var want: Vector2 = (home - pos).normalized() * (260.0 + 500.0 * (age - delay))
			vel = vel.lerp(want, minf(delta * 6.0, 1.0))
		elif mote.has("spin"):
			vel = vel.rotated(delta * 3.0) * 0.98
			pos += (home + Vector2(0, 20) - pos).orthogonal().normalized() * delta * 30.0
		else:
			vel *= 0.9
		pos += vel * delta
		mote["pos"] = pos
		mote["vel"] = vel
		var trail: PackedVector2Array = mote["trail"]
		trail.append(pos)
		if trail.size() > 7:
			trail.remove_at(0)
		mote["trail"] = trail
	_motes = _motes.filter(func(mote: Dictionary) -> bool:
		if mote.has("life"):
			return mote["age"] < mote["life"]
		var arrived: bool = mote["age"] > mote["delay"] and (mote["pos"] as Vector2).distance_to(home) < 14.0
		return not arrived and mote["age"] < 3.0
	)
	for star in _stars:
		star["age"] += delta
	_stars = _stars.filter(func(star: Dictionary) -> bool: return star["age"] < 0.28)
	for bloom in _blooms:
		bloom["age"] += delta
	_blooms = _blooms.filter(func(bloom: Dictionary) -> bool: return bloom["age"] < bloom["life"])
	for pillar in _pillars:
		pillar["age"] += delta
	_pillars = _pillars.filter(func(pillar: Dictionary) -> bool: return pillar["age"] < 1.4)
	queue_redraw()


func _draw() -> void:
	if _player == null:
		return
	var feet := _player.global_position
	for pillar in _pillars:
		var t: float = pillar["age"] / 1.4
		var fade: float = 1.0 - t
		var width := 26.0 * (1.0 - t * 0.5)
		draw_rect(Rect2(feet + Vector2(-width / 2.0, -160.0), Vector2(width, 160.0)), Color(1.0, 0.85, 0.45, 0.22 * fade))
		draw_rect(Rect2(feet + Vector2(-width / 5.0, -160.0), Vector2(width / 2.5, 160.0)), Color(1.0, 0.95, 0.75, 0.35 * fade))
		for k in 3:
			var r := 20.0 + (t + k * 0.25) * 70.0
			PX.arc(self, feet, r, 0.0, TAU, 40, Color(1.0, 0.85, 0.4, fade * 0.6), 2.0)
	for mote in _motes:
		var color: Color = mote["color"]
		var trail: PackedVector2Array = mote["trail"]
		for i in range(1, trail.size()):
			PX.line(self, trail[i - 1], trail[i], Color(color, 0.12 + 0.5 * i / trail.size()), mote["size"] * (0.5 + 0.5 * i / trail.size()))
		PX.disc(self, mote["pos"], mote["size"] + 2.0, Color(color, 0.25))
		PX.disc(self, mote["pos"], mote["size"], color.lightened(0.4))
	for bloom in _blooms:
		if bloom["age"] < 0.0:
			continue
		var t: float = bloom["age"] / bloom["life"]
		var at: Vector2 = feet + bloom["pos"] + Vector2(0, -30.0 * t)
		var color := Color(0.55, 1.0, 0.6, 1.0 - t)
		draw_rect(Rect2(at + Vector2(-3, -1), Vector2(6, 2)), color)
		draw_rect(Rect2(at + Vector2(-1, -3), Vector2(2, 6)), color)
	for spark in _impacts:
		_draw_impact(spark)
	for star in _stars:
		var t: float = star["age"] / 0.28
		var size := 10.0 + 22.0 * t
		var color := Color(1, 1, 1, 1.0 - t)
		var center: Vector2 = star["pos"]
		for k in 4:
			var dir := Vector2.from_angle(star["angle"] + k * PI / 2.0)
			var side := dir.orthogonal() * size * 0.16
			PX.poly(self, PackedVector2Array([center + side, center + dir * size, center - side]), color)
		PX.disc(self, center, size * 0.25, Color(1.0, 0.95, 0.7, 1.0 - t))


## One impact spark, by its frame (0 to 3).
func _draw_impact(spark: Dictionary) -> void:
	var frame := mini(int(float(spark["age"]) / IMPACT_SECONDS * 4.0), 3)
	var c: Vector2 = spark["pos"]
	var away: Vector2 = spark["away"]
	var tint: Color = spark["tint"]
	var core := Color(1.0, 0.98, 0.88)
	match frame:
		0:
			draw_rect(Rect2(c - Vector2(1, 1), Vector2(3, 3)), core)
			for way: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
				draw_rect(Rect2(c + way * 2, Vector2.ONE), core)
				draw_rect(Rect2(c + way * 3, Vector2.ONE), tint)
		1:
			draw_rect(Rect2(c, Vector2.ONE), core)
			for k in range(2, 5):
				for way: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
					draw_rect(Rect2(c + way * k, Vector2.ONE), core if k < 4 else tint)
			for way: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
				draw_rect(Rect2(c + way * 3, Vector2.ONE), tint)
		2:
			for k in 8:
				if k % 3 == 1:
					continue
				var p := (c + Vector2.from_angle(k * TAU / 8.0) * 5.0).floor()
				draw_rect(Rect2(p, Vector2.ONE), Color(tint, 0.9))
		3:
			# Flecks thrown on past the blow.
			for k in 4:
				var spread := away.rotated((k - 1.5) * 0.45)
				var p := (c + spread * (6.0 + (k % 2) * 2.0)).floor()
				draw_rect(Rect2(p, Vector2.ONE), Color(tint, 0.7))

