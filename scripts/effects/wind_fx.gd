class_name WindFX
extends Node2D
## The wind made visible, and the year turning:
##
##   Gusts sweep across the land every few seconds (Wind leans the trees
##   and grass as each passes); with each, a few streaks of air run ahead,
##   curling at their heads, and whatever lies loose is carried along:
##   leaves in the woods, snow on the frost, sand in the desert, ash in the
##   burnt lands.
##
##   Leaves fall from the broadleaf trees round the player as the season
##   asks (petals from blossom in spring, a few in summer, a shower in
##   autumn, none in bare winter), drift down swaying, and lie a while on
##   the ground before they fade.
##
##   The seasons themselves are kept here: the leafy materials, the
##   grass's tint and winter's frost follow the day and hour.

const GUST_SPEED := 300.0
const SPACING := 0.0026
const MAX_STREAKS := 26
const MAX_FLYING := 70
const MAX_LYING := 140
const LEAF_LIE := Vector2(7.0, 13.0)

## How hard gusts blow, by weather.
const POWER := {"": 3.0, "Rain": 4.0, "Thunderstorm": 6.0, "Snowfall": 3.5, "Blizzard": 6.0, "Sandstorm": 6.0, "Ash storm": 5.5}

## Leaves of each season, [shade, light].
const LEAVES := {
	"spring": [[Color8(88, 146, 52), Color8(132, 190, 70)], [Color8(232, 176, 198), Color8(255, 232, 242)]],
	"summer": [[Color8(74, 122, 58), Color8(106, 154, 74)]],
	"autumn": [[Color8(208, 148, 36), Color8(240, 194, 64)], [Color8(192, 106, 42), Color8(232, 152, 58)], [Color8(176, 42, 52), Color8(220, 74, 76)], [Color8(146, 84, 40), Color8(186, 120, 56)]],
}
const SNOW := [[Color8(214, 226, 240), Color8(250, 252, 255)]]
const SAND := [[Color8(176, 146, 96), Color8(220, 196, 140)]]
const ASH := [[Color8(96, 90, 92), Color8(140, 134, 136)], [Color8(200, 96, 40), Color8(250, 170, 80)]]

var _player: Player
var _world: World
var _day_night: DayNight
var _gust_time := 0.0
var _direction := Vector2(0.98, 0.18).normalized()
## [position, age, life, length, phase, curl]
var _streaks: Array = []
## Leaves in the air: [position, velocity, age, colours, ground_y, sway]
var _flying: Array = []
## Leaves on the ground: [position, age, life, colours, shape]
var _lying: Array = []
var _drew_air := false
var _drew_ground := false
var _ground_left := 0.0
var _ground: Node2D
var _drop_left := 0.0
var _gust_was := 0.0
var _trees: Array = []
var _trees_left := 0.0


func setup(player: Player, world: World, day_night: DayNight) -> void:
	_player = player
	_world = world
	_day_night = day_night
	z_as_relative = false
	z_index = 20
	_ground = Node2D.new()
	_ground.z_as_relative = false
	_ground.z_index = -8
	_ground.draw.connect(_draw_ground)
	add_child(_ground)
	Seasons.update(_day_night.day, _day_night.time)


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	Seasons.update(_day_night.day, _day_night.time)
	TerrainTiles.set_season(_day_night.day, _day_night.time)
	_gust_time = fmod(_gust_time + delta, 2417.0 / GUST_SPEED * 50.0)
	var power: float = POWER.get(Atmosphere.weather, 3.6)
	Wind.set_gust(_gust_time, _direction, power)
	var outside := not _player.indoors
	visible = outside
	_ground.visible = outside
	if not outside:
		return
	var gust := Wind.gust_at(_player.global_position)
	if gust > 0.25 and GameSettings.weather_fx > 0:
		_blow(delta, gust)
	_gust_was = gust
	_fall(delta)
	_age(delta)
	# Redraw only what has something on it: streaks and flying leaves move
	# every frame; leaves lying on the ground only fade, so ten times a
	# second is plenty. (Empty layers cost nothing to leave alone.)
	if not _streaks.is_empty() or not _flying.is_empty() or _drew_air:
		queue_redraw()
	_drew_air = not _streaks.is_empty() or not _flying.is_empty()
	_ground_left -= delta
	if _ground_left <= 0.0 and (not _lying.is_empty() or _drew_ground):
		_ground_left = 0.1
		_ground.queue_redraw()
		_drew_ground = not _lying.is_empty()


func _view_rect() -> Rect2:
	var camera := get_viewport().get_camera_2d()
	var zoom := camera.zoom.x if camera else 1.0
	var size := get_viewport_rect().size / zoom
	var centre := camera.get_screen_center_position() if camera else _player.global_position
	return Rect2(centre - size / 2.0, size)


## What the wind carries here: leaves, snow, sand or ash.
func _carried() -> Array:
	var tile := _world.tile_type_at_position(_player.global_position)
	var T := TerrainTiles.Type
	if tile in [T.SNOW, T.FROSTPINE, T.PEAK, T.SALT] or Seasons.index(_day_night.day, _day_night.time) == 3:
		return SNOW
	if tile in [T.SAND]:
		return SAND
	if tile in [T.ASH, T.CINDER, T.TAR]:
		return ASH
	return LEAVES[["spring", "summer", "autumn", "autumn"][Seasons.index(_day_night.day, _day_night.time)]]


func _blow(delta: float, gust: float) -> void:
	var view := _view_rect()
	# Streaks of air, starting off the upwind side of the view.
	if _streaks.size() < MAX_STREAKS and randf() < gust * 20.0 * delta * maxf(GameSettings.particles, 0.5):
		var start := Vector2(view.position.x + randf_range(-0.1, 0.7) * view.size.x, view.position.y + randf() * view.size.y)
		_streaks.append([start, 0.0, randf_range(0.7, 1.1), float(randi_range(7, 15)) * 2.0, randf() * TAU, randf() < 0.55])
	# Loose things carried along.
	if _flying.size() < MAX_FLYING and randf() < gust * 30.0 * delta * maxf(GameSettings.particles, 0.5):
		var colours: Array = _carried()[randi() % _carried().size()]
		var start := Vector2(view.position.x - 10.0 + randf() * view.size.x * 0.6, view.position.y + randf() * view.size.y)
		_flying.append([start, _direction * randf_range(160.0, 260.0) + Vector2(0, randf_range(-12, 12)), 0.0, colours, start.y + randf_range(20.0, 90.0), randf() * TAU, false])


## Leaves dropping from the trees as the season asks.
func _fall(delta: float) -> void:
	_trees_left -= delta
	if _trees_left <= 0.0:
		_trees_left = 1.0
		_trees.clear()
		var view := _view_rect().grow(60.0)
		for node in get_tree().get_nodes_in_group("leafy_trees"):
			var tree := node as Node2D
			if tree and view.has_point(tree.global_position):
				_trees.append(tree)
	if _trees.is_empty():
		return
	var season := Seasons.index(_day_night.day, _day_night.time)
	var rate: float = [0.6, 0.25, 2.4, 0.0][season] * GameSettings.particles
	if Seasons.turning(_day_night.day, _day_night.time) > 0.0 and season == 2:
		rate *= 0.5
	_drop_left -= delta * rate * minf(float(_trees.size()), 12.0)
	while _drop_left <= 0.0 and rate > 0.0:
		_drop_left += 1.0
		var picked: Variant = _trees[randi() % _trees.size()]
		# Trees go when their chunk is unloaded.
		if not is_instance_valid(picked) or _flying.size() >= MAX_FLYING:
			continue
		var tree := picked as Node2D
		var tall := int(tree.get_meta("tall", -1))
		var colours: Array
		match season:
			0:
				# Petals from blossom, else a fresh leaf now and then.
				colours = LEAVES["spring"][1] if tall == Flora.Tall.CHERRY or randf() < 0.3 else LEAVES["spring"][0]
			1:
				colours = LEAVES["summer"][0]
			_:
				colours = LEAVES["autumn"][randi() % LEAVES["autumn"].size()]
		var at := tree.global_position + Vector2(randf_range(-22.0, 22.0), randf_range(-74.0, -40.0))
		_flying.append([at, Vector2(randf_range(-6.0, 6.0), randf_range(14.0, 22.0)), 0.0, colours, tree.global_position.y + randf_range(-4.0, 22.0), randf() * TAU, true])


func _age(delta: float) -> void:
	var view := _view_rect().grow(140.0)
	for index in range(_streaks.size() - 1, -1, -1):
		var streak: Array = _streaks[index]
		streak[1] += delta
		streak[0] += _direction * 360.0 * delta
		if streak[1] >= streak[2]:
			_streaks.remove_at(index)
	for index in range(_flying.size() - 1, -1, -1):
		var leaf: Array = _flying[index]
		leaf[2] += delta
		var push := Wind.gust_at(leaf[0]) * 200.0
		var velocity: Vector2 = leaf[1]
		if leaf[6]:
			# Falling: a gentle drift down, swaying, pushed by any gust.
			var sway := sin(leaf[2] * 2.6 + leaf[5]) * 12.0
			leaf[0] += Vector2(sway + velocity.x + push * _direction.x, velocity.y) * delta
		else:
			# Carried: on the wind, settling as it dies down.
			leaf[0] += (velocity * (0.35 + Wind.gust_at(leaf[0])) + Vector2(0, 10.0 + sin(leaf[2] * 5.0 + leaf[5]) * 18.0)) * delta
		var landed: bool = (leaf[0] as Vector2).y >= float(leaf[4]) and float(leaf[2]) > 0.6
		if landed or not view.has_point(leaf[0]) or leaf[2] > 9.0:
			_flying.remove_at(index)
			if landed and view.has_point(leaf[0]) and not TerrainTiles.is_water(_world.tile_type_at_position(leaf[0])):
				if _lying.size() >= MAX_LYING:
					_lying.pop_front()
				_lying.append([leaf[0], 0.0, randf_range(LEAF_LIE.x, LEAF_LIE.y), leaf[3], randi() % 3])
	for index in range(_lying.size() - 1, -1, -1):
		var leaf: Array = _lying[index]
		leaf[1] += delta
		# A gust lifts what lies loose and carries it off again.
		if Wind.gust_at(leaf[0]) > 0.7 and randf() < delta * 2.0:
			_flying.append([leaf[0], _direction * 180.0, 0.0, leaf[3], (leaf[0] as Vector2).y + randf_range(30.0, 80.0), randf() * TAU, false])
			_lying.remove_at(index)
			continue
		if leaf[1] >= leaf[2] or not view.has_point(leaf[0]):
			_lying.remove_at(index)


static func _snap(at: Vector2) -> Vector2:
	return at.floor()


func _draw() -> void:
	var night := _day_night.darkness()
	# Streaks of wind: a wavering line of single pixels, curling at its head.
	for streak: Array in _streaks:
		var share: float = streak[1] / streak[2]
		var alpha := sin(share * PI) * (0.55 - night * 0.25)
		var colour := Color(0.94, 0.97, 1.0, alpha)
		var head := _snap(streak[0])
		var length: float = streak[3]
		var slope := _direction.y / _direction.x
		for k in int(length):
			var x := -float(k)
			var y := roundf(x * slope + sin((x + streak[4] * 6.0) * 0.28) * 1.2)
			var fade := 1.0 - float(k) / length
			draw_rect(Rect2(head + Vector2(x, y), Vector2(1, 1)), Color(colour, alpha * (0.35 + 0.65 * fade)))
		if streak[5]:
			# The curl: three-quarters of a little loop.
			for step in 9:
				var angle := -PI / 2.0 + step * PI * 1.5 / 8.0
				var spot := (head + Vector2(cos(angle), sin(angle)) * 3.0 + Vector2(-1.0, 3.0)).round()
				draw_rect(Rect2(spot, Vector2(1, 1)), colour)
	for leaf: Array in _flying:
		_leaf(self, leaf[0], leaf[3], int(leaf[2] * 8.0 + leaf[5] * 3.0) % 3, 1.0)


func _draw_ground() -> void:
	for leaf: Array in _lying:
		var fade := clampf((leaf[2] - leaf[1]) / 2.0, 0.0, 1.0)
		_leaf(_ground, leaf[0], leaf[3], leaf[4], fade * 0.9)


## A leaf (or flake) of whole pixels, tumbling through three shapes.
static func _leaf(canvas: CanvasItem, at: Vector2, colours: Array, shape: int, alpha: float) -> void:
	var p := at.floor()
	var shade := Color(colours[0], alpha)
	var light := Color(colours[1], alpha)
	match shape:
		0:
			canvas.draw_rect(Rect2(p, Vector2(2, 1)), shade)
			canvas.draw_rect(Rect2(p + Vector2(1, -1), Vector2(1, 1)), light)
		1:
			canvas.draw_rect(Rect2(p, Vector2(1, 2)), shade)
			canvas.draw_rect(Rect2(p + Vector2(0, -1), Vector2(1, 1)), light)
		_:
			canvas.draw_rect(Rect2(p, Vector2(2, 2)), shade)
			canvas.draw_rect(Rect2(p, Vector2(1, 1)), light)
