class_name Footsteps
extends Node2D
## The player's feet on the ground: a footfall that suits what is underfoot
## (grass, stone, snow, sand, shallows), prints left behind in soft ground,
## dust kicked up at a run, and breath that shows in the cold.

const STRIDE := 36.0
const SOFT := {"snow": Color(0.62, 0.68, 0.8, 0.5), "sand": Color(0.45, 0.36, 0.22, 0.4)}

var _player: Player
var _world: World
var _walked := 0.0
var _left_foot := false
var _prints: Node2D
## [position, age, colour, angle]
var _marks: Array = []
## [offset, age]
var _breath: Array = []
var _breath_left := 1.5


func setup(player: Player, world: World) -> void:
	_player = player
	_world = world
	z_index = 3
	# Prints lie on the ground, in the world, not on the player.
	_prints = Node2D.new()
	_prints.z_as_relative = false
	_prints.z_index = -8
	_prints.top_level = true
	_prints.draw.connect(_draw_prints)
	add_child(_prints)


## What the ground under a position sounds like.
func _ground() -> String:
	var T := TerrainTiles.Type
	if _player.indoors:
		return "stone"
	var tile := _world.tile_type_at_position(_player.global_position)
	if TerrainTiles.is_water(tile):
		return "water"
	if tile in [T.SNOW, T.FROSTPINE, T.PEAK]:
		return "snow"
	if tile in [T.SAND, T.SALT, T.ASH, T.MUD, T.TAR]:
		return "sand"
	if tile in [T.ROCK, T.PATH, T.CAVE_FLOOR, T.PLANK, T.CINDER, T.VOIDSCAR]:
		return "stone"
	return "grass"


func _physics_process(delta: float) -> void:
	if _player == null or _player.is_dead():
		return
	var speed := _player.velocity.length()
	var on_foot := _player.state in [Player.State.MOVE, Player.State.ATTACK] and not _player.boating and not _player.deep_water
	if on_foot and speed > 40.0:
		_walked += speed * delta
		if _walked >= STRIDE * (1.25 if _player.mount_id != "" else 1.0):
			_walked = 0.0
			_step()
	for mark: Array in _marks:
		mark[1] += delta
	_marks = _marks.filter(func(m: Array) -> bool: return m[1] < 9.0)
	if not _marks.is_empty():
		_prints.queue_redraw()
	_breathe(delta)


func _step() -> void:
	var ground := _ground()
	_left_foot = not _left_foot
	var mounted := _player.mount_id != ""
	Audio.play("step_" + ("stone" if mounted and ground == "grass" else ground), -19.0 if not mounted else -15.0, 0.18)
	var forward := _player.velocity.normalized()
	var side := forward.orthogonal() * (4.0 if _left_foot else -4.0)
	var at := _player.global_position + side + Vector2(0, 2)
	if SOFT.has(ground) and not _player.indoors:
		_marks.append([at, 0.0, SOFT[ground], forward.angle()])
		if _marks.size() > 70:
			_marks.pop_front()
	# A run on dry ground kicks up dust.
	if _player.sprinting and ground in ["sand", "stone", "grass"] and _left_foot:
		Gore.spray(_player.get_parent(), _player.global_position - forward * 6.0, "_dust", -forward, 2, false)


func _draw_prints() -> void:
	for mark: Array in _marks:
		var fade: float = 1.0 - clampf((mark[1] - 5.0) / 4.0, 0.0, 1.0)
		var color: Color = mark[2]
		_prints.draw_set_transform(mark[0], mark[3], Vector2.ONE)
		_prints.draw_rect(Rect2(-3.5, -2.0, 7.0, 4.0), Color(color, color.a * fade))
		_prints.draw_rect(Rect2(-5.0, -1.5, 1.5, 3.0), Color(color, color.a * fade * 0.8))
	_prints.draw_set_transform(Vector2.ZERO)


## Breath hangs in cold air.
func _breathe(delta: float) -> void:
	for puff: Array in _breath:
		puff[1] += delta
	_breath = _breath.filter(func(p: Array) -> bool: return p[1] < 1.4)
	_breath_left -= delta
	var T := TerrainTiles.Type
	var cold: bool = not _player.indoors and (_world.tile_type_at_position(_player.global_position) in [T.SNOW, T.FROSTPINE, T.PEAK] or Atmosphere.weather in ["Snowfall", "Blizzard"])
	if cold and _breath_left <= 0.0 and not _player.deep_water:
		# Faster when the heart is.
		_breath_left = lerpf(2.6, 0.9, Heartbeat.tension)
		_breath.append([Vector2(7.0 * signf(_player.facing.x if _player.facing.x != 0.0 else 1.0), -28.0), 0.0])
	if not _breath.is_empty() or cold:
		queue_redraw()


func _draw() -> void:
	for puff: Array in _breath:
		var share: float = puff[1] / 1.4
		var at: Vector2 = puff[0] + Vector2(share * 8.0 * signf(puff[0].x), -share * 9.0)
		draw_circle(at, 2.5 + share * 5.0, Color(0.92, 0.95, 1.0, 0.3 * (1.0 - share)))
		draw_circle(at + Vector2(3.0 * signf(puff[0].x), -2.0), 1.5 + share * 3.5, Color(0.92, 0.95, 1.0, 0.22 * (1.0 - share)))
