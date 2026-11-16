class_name Footsteps
extends Node2D
## The player's feet on the ground: a footfall that suits what is underfoot
## (grass, stone, snow, sand, shallows), prints left behind in soft ground,
## dust kicked up at a run, and breath that shows in the cold.

const STRIDE := 36.0
## Ground that takes a print, and the colour of the pressed-in print.
const SOFT := {"snow": Color(0.34, 0.42, 0.62, 0.75), "sand": Color(0.42, 0.3, 0.16, 0.65), "mud": Color(0.1, 0.07, 0.04, 0.65), "ash": Color(0.12, 0.12, 0.14, 0.65)}
const PRINT_LIFE := 12.0
const MOST_PRINTS := 220
## Prints as pixel stencils, drawn for walking north ("#" pressed in);
## other ways turn them in exact quarter turns.
const STENCILS := {
	"boot": [".##.", "####", "####", ".##.", "....", ".##.", ".##."],
	"hoof": ["#.#", "#.#", "..."],
	"paw": ["#.#.#", ".....", ".###.", ".###."],
	"big_paw": ["#.#.#.#", ".......", ".#####.", ".#####.", "..###.."],
	"claw": ["#.#.#", ".#.#.", "..#..", "..#.."],
	"dots": ["#..#", "....", ".#.."],
	"drag": ["#", "#", "#", "#", "#"],
	"blob": [".##.", "####", "####", ".##."],
}
## What each creature's feet leave ("" for those that fly or float).
const CREATURE_FEET := {
	"husk": "drag", "rot_hound": "paw", "bone_archer": "boot", "bog_slime": "blob", "carrion_bat": "", "thorn_stalker": "claw",
	"spore_shambler": "blob", "rot_cultist": "boot", "ember_wisp": "", "ash_wraith": "", "crag_golem": "big_paw", "deer": "hoof",
	"wild_hare": "dots", "wild_pig": "hoof", "mountain_goat": "hoof", "pheasant": "claw", "desert_lizard": "claw", "snow_fox": "paw",
	"shore_crab": "dots", "marsh_toad": "blob", "sheep": "hoof", "cow": "hoof", "chicken": "claw", "bear": "big_paw", "grey_wolf": "paw",
	"giant_spider": "dots", "web_spider": "dots", "frost_wolf": "paw", "frost_troll": "big_paw", "dire_boar": "hoof", "treant": "big_paw",
	"sand_scorpion": "dots", "dune_mummy": "drag", "void_stalker": "paw", "void_eye": "", "crimson_fiend": "claw", "veinheart": "blob",
	"heartsworn_knight": "boot", "rotten_corpse": "drag", "ghost": "", "magma_slime": "blob", "cinder_imp": "claw", "bog_lurker": "blob",
	"storm_harpy": "",
}

## The player's footsteps, which also draw every print near them.
static var _current: Footsteps

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
	_current = self
	z_index = 3
	# Prints lie on the ground, in the world, not on the player.
	_prints = Node2D.new()
	_prints.z_as_relative = false
	_prints.z_index = -8
	_prints.top_level = true
	_prints.draw.connect(_draw_prints)
	add_child(_prints)


## What the ground under the player sounds like.
func _ground() -> String:
	return ground_at(_player.global_position)


## What the ground at a position sounds like: "grass", "stone", "snow",
## "sand", "mud", "ash" or "water".
func ground_at(at: Vector2) -> String:
	var T := TerrainTiles.Type
	if _player.indoors:
		return "stone"
	var tile := _world.tile_type_at_position(at)
	if TerrainTiles.is_water(tile):
		return "water"
	if tile in [T.SNOW, T.FROSTPINE, T.PEAK]:
		return "snow"
	if tile in [T.MUD, T.TAR, T.BOG]:
		return "mud"
	if tile in [T.ASH]:
		return "ash"
	if tile in [T.SAND, T.SALT]:
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
	_marks = _marks.filter(func(m: Array) -> bool: return m[1] < PRINT_LIFE)
	if not _marks.is_empty():
		_prints.queue_redraw()
	_breathe(delta)


func _step() -> void:
	var ground := _ground()
	_left_foot = not _left_foot
	var mounted := _player.mount_id != ""
	var sound: String = {"mud": "sand", "ash": "sand"}.get(ground, ground)
	if mounted:
		# Hooves: a clop, softer in snow and sand.
		Audio.play_creature("deer", "step", _player.global_position, -10.0 if SOFT.has(ground) else -6.0, 0.8)
	else:
		Audio.play("step_" + sound, -19.0, 0.18)
	var forward := _player.velocity.normalized()
	var side := forward.orthogonal() * (4.0 if _left_foot else -4.0)
	var at := _player.global_position + side + Vector2(0, 2)
	if SOFT.has(ground) and not _player.indoors:
		_add_print(at, forward, "hoof" if mounted else "boot", ground)
	# A run on dry ground kicks up dust.
	if _player.sprinting and ground in ["sand", "stone", "grass"] and _left_foot:
		Gore.spray(_player.get_parent(), _player.global_position - forward * 6.0, "_dust", -forward, 2, false)


## A print from a creature's feet, if it walks on soft ground near enough
## to be seen. Called by creatures as they step.
static func print_for(creature: String, at: Vector2, velocity: Vector2) -> void:
	var feet: String = CREATURE_FEET.get(creature, "")
	if feet == "" or _current == null or not is_instance_valid(_current) or _current._player == null:
		return
	if at.distance_squared_to(_current._player.global_position) > 640.0 * 640.0:
		return
	var ground := _current.ground_at(at)
	if SOFT.has(ground):
		_current._add_print(at + Vector2(0, 2), velocity.normalized(), feet, ground)


## [position, age, colour, quarter turns, stencil]
func _add_print(at: Vector2, forward: Vector2, stencil: String, ground: String) -> void:
	_marks.append([at.round(), 0.0, SOFT[ground], _quarter(forward), stencil])
	if _marks.size() > MOST_PRINTS:
		_marks.pop_front()


## The quarter turn nearest a direction: 0 north, 1 east, 2 south, 3 west.
static func _quarter(forward: Vector2) -> int:
	if forward == Vector2.ZERO:
		return 2
	if absf(forward.x) > absf(forward.y):
		return 1 if forward.x > 0.0 else 3
	return 2 if forward.y > 0.0 else 0


func _draw_prints() -> void:
	for mark: Array in _marks:
		var fade: float = 1.0 - clampf((mark[1] - PRINT_LIFE * 0.55) / (PRINT_LIFE * 0.45), 0.0, 1.0)
		var color: Color = mark[2]
		color.a *= fade
		var rows: Array = STENCILS.get(mark[4] if mark.size() > 4 else "boot", STENCILS["boot"])
		var height := rows.size()
		var width := String(rows[0]).length()
		for y in height:
			var row: String = rows[y]
			for x in width:
				if row[x] != "#":
					continue
				# Cell in the stencil, turned by whole quarter turns about its middle.
				var cell := Vector2i(x - width / 2, y - height / 2)
				match int(mark[3]):
					1:
						cell = Vector2i(-cell.y, cell.x)
					2:
						cell = Vector2i(-cell.x, -cell.y)
					3:
						cell = Vector2i(cell.y, -cell.x)
				_prints.draw_rect(Rect2(mark[0] + Vector2(cell), Vector2.ONE), color)


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
