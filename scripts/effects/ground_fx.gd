class_name GroundFX
extends Node2D
## Life on the ground around the player: foam lapping at every shore, sun
## glinting and small waves moving on open water, rain splashing, and snow
## that settles in drifts during snowfall and melts away after.

## Half the size of the area kept up to date around the player, in tiles.
const WINDOW := Vector2i(17, 11)
const MAX_GLINTS := 46
const MAX_WAVES := 36
const MAX_SPLASHES := 120
const SNOW_SHADER := """
shader_type canvas_item;
uniform sampler2D noise : repeat_enable, filter_linear;
uniform float cover = 0.0;
// One texel per tile: white on land, black on water. Filtered, so shores blend.
uniform sampler2D land_mask : filter_linear;
uniform vec2 mask_origin = vec2(0.0);
uniform vec2 mask_size = vec2(1.0);
varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	// Snapped to the game's 2px pixel grid, so drifts have hard pixel edges.
	vec2 px = floor(world / 2.0) * 2.0;
	float n = texture(noise, px / 520.0).r * 0.65 + texture(noise, px / 120.0 + vec2(0.37, 0.71)).r * 0.35;
	float edge = 1.0 - cover;
	float land = texture(land_mask, (px - mask_origin) / mask_size).r;
	float dot_noise = fract(sin(dot(floor(world / 2.0), vec2(12.9898, 78.233))) * 43758.5453);
	// Drifts, with a dithered fringe round them, and only on land.
	float solid = step(edge, n);
	float fringe = step(edge - 0.035, n) * step(dot_noise, 0.45);
	float on_land = step(0.55, land + (n - 0.5) * 0.4);
	float a = max(solid, fringe) * on_land;
	// Single flakes lying in the grass between the drifts.
	a = max(a, step(0.988, dot_noise) * step(edge - 0.22, n) * step(0.55, land));
	// Two tones: a cool shaded rim and bright snow inside.
	vec3 snow = mix(vec3(0.78, 0.84, 0.94), vec3(0.96, 0.97, 1.0), step(edge + 0.05, n));
	COLOR = vec4(snow, a * 0.95);
}
"""

## How deep the snow lies, 0 to 1. Shared so the minimap or others can ask.
static var snow := 0.0
## How much ash has settled on things during ashfall, 0 to 1.
static var ash := 0.0

var _player: Player
var _world: World
var _day_night: DayNight
var _center := Vector2i(999999, 999999)
var _tiles: Dictionary = {}
## [rect, side, phase] for each water tile edge that meets land.
var _foam: Array = []
var _water: Array[Vector2i] = []
var _land: Array[Vector2i] = []
## [position, age, life, size]
var _glints: Array = []
## [position, age, life, size]
var _waves: Array = []
## [position, age, on water]
var _splashes: Array = []
## Cloud shadows drifting over the land: [start offset, radius, speed scale].
var _clouds: Array = []
const CLOUD_FIELD := Vector2(2600.0, 1700.0)
var _snow_layer: Node2D
var _snow_material: ShaderMaterial
var _snow_drawn := false
var _mask: ImageTexture
var _mask_rect := Rect2()


func setup(player: Player, world: World, day_night: DayNight) -> void:
	_player = player
	_world = world
	_day_night = day_night
	z_as_relative = false
	z_index = -8
	for k in 7:
		_clouds.append([Vector2(randf() * CLOUD_FIELD.x, randf() * CLOUD_FIELD.y), randf_range(190.0, 380.0), randf_range(0.7, 1.3)])
	var noise := FastNoiseLite.new()
	noise.frequency = 0.02
	noise.fractal_octaves = 3
	var texture := NoiseTexture2D.new()
	texture.noise = noise
	texture.seamless = true
	texture.width = 256
	texture.height = 256
	var shader := Shader.new()
	shader.code = SNOW_SHADER
	_snow_material = ShaderMaterial.new()
	_snow_material.shader = shader
	_snow_material.set_shader_parameter("noise", texture)
	_snow_layer = Node2D.new()
	_snow_layer.material = _snow_material
	_snow_layer.z_as_relative = false
	_snow_layer.z_index = -9
	_snow_layer.draw.connect(_draw_snow)
	add_child(_snow_layer)


func _tile(cell: Vector2i) -> int:
	if not _tiles.has(cell):
		if _tiles.size() > 6000:
			_tiles.clear()
		_tiles[cell] = _world.generator.tile_type_at(cell)
	return _tiles[cell]


func _rescan() -> void:
	_foam.clear()
	_water.clear()
	_land.clear()
	var size := float(TerrainTiles.TILE_SIZE)
	var sides: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	for y in range(_center.y - WINDOW.y, _center.y + WINDOW.y + 1):
		for x in range(_center.x - WINDOW.x, _center.x + WINDOW.x + 1):
			var cell := Vector2i(x, y)
			if not TerrainTiles.is_water(_tile(cell)):
				if not TerrainTiles.is_solid(_tile(cell)):
					_land.append(cell)
				continue
			_water.append(cell)
			var rect := Rect2(Vector2(cell) * size, Vector2(size, size))
			for side in 4:
				if not TerrainTiles.is_water(_tile(cell + sides[side])):
					_foam.append([rect, side, absi(hash(cell * 7 + Vector2i(side, 0))) % 628 / 100.0])
	# The land mask the snow shader reads.
	var span := WINDOW * 2 + Vector2i.ONE
	var image := Image.create(span.x, span.y, false, Image.FORMAT_L8)
	var corner := _center - WINDOW
	for cell in _land:
		image.set_pixel(cell.x - corner.x, cell.y - corner.y, Color.WHITE)
	if _mask == null:
		_mask = ImageTexture.create_from_image(image)
		_snow_material.set_shader_parameter("land_mask", _mask)
	else:
		_mask.update(image)
	_mask_rect = Rect2(Vector2(corner) * size, Vector2(span) * size)
	_snow_material.set_shader_parameter("mask_origin", _mask_rect.position)
	_snow_material.set_shader_parameter("mask_size", _mask_rect.size)
	_snow_drawn = false


func _process(delta: float) -> void:
	if _player == null:
		return
	visible = not _player.indoors
	if _player.indoors:
		return
	var here := _world.world_to_cell(_player.global_position)
	if absi(here.x - _center.x) > 2 or absi(here.y - _center.y) > 2:
		_center = here
		_rescan()
	_settle_snow(delta)
	var daylight := 1.0 - _day_night.darkness()
	var size := float(TerrainTiles.TILE_SIZE)
	# Sun (or moon) glinting on the water.
	if not _water.is_empty():
		var rate := 0.35 + daylight * 0.65
		if _glints.size() < MAX_GLINTS * rate and randf() < 0.75:
			var cell: Vector2i = _water[randi() % _water.size()]
			_glints.append([(Vector2(cell) + Vector2(randf(), randf())) * size, 0.0, randf_range(0.5, 1.1), randf_range(1.5, 3.0)])
		if _waves.size() < MAX_WAVES and randf() < 0.35:
			var cell: Vector2i = _water[randi() % _water.size()]
			_waves.append([(Vector2(cell) + Vector2(randf(), randf())) * size, 0.0, randf_range(1.4, 2.4), randf_range(4.0, 7.0)])
	# Rain hitting the ground.
	if Atmosphere.weather in ["Rain", "Thunderstorm"]:
		var count := 3 if Atmosphere.weather == "Rain" else 6
		var view := get_viewport_rect().size / maxf(_zoom(), 0.1)
		for k in count:
			if _splashes.size() >= MAX_SPLASHES:
				break
			var at := _player.global_position + Vector2(randf_range(-0.55, 0.55) * view.x, randf_range(-0.55, 0.55) * view.y)
			_splashes.append([at, 0.0, TerrainTiles.is_water(_tile(_world.world_to_cell(at)))])
	_age(_glints, delta)
	_age(_waves, delta)
	for splash: Array in _splashes:
		splash[1] += delta
	_splashes = _splashes.filter(func(s: Array) -> bool: return s[1] < 0.32)
	queue_redraw()


func _zoom() -> float:
	var camera := get_viewport().get_camera_2d()
	return camera.zoom.x if camera else 1.0


func _age(list: Array, delta: float) -> void:
	for index in range(list.size() - 1, -1, -1):
		list[index][1] += delta
		if list[index][1] >= list[index][2]:
			list.remove_at(index)


func _settle_snow(delta: float) -> void:
	var before := snow
	match Atmosphere.weather:
		# Settled snow stays patchy, so the ground can still be read.
		"Snowfall":
			snow = minf(snow + delta * 0.006, 0.3)
		"Blizzard":
			snow = minf(snow + delta * 0.015, 0.45)
		_:
			snow = maxf(snow - delta * (0.004 + 0.008 * (1.0 - _day_night.darkness())), 0.0)
	match Atmosphere.weather:
		"Ashfall":
			ash = minf(ash + delta * 0.01, 0.6)
		"Ash storm":
			ash = minf(ash + delta * 0.025, 0.85)
		_:
			ash = maxf(ash - delta * 0.006, 0.0)
	# What has settled shows along the tops of trees, bushes and props.
	if snow >= ash:
		Wind.set_dusting(Color(0.94, 0.96, 1.0), minf(snow * 1.4, 1.0))
	else:
		Wind.set_dusting(Color(0.76, 0.74, 0.72), minf(ash * 1.3, 1.0))
	_snow_layer.visible = snow > 0.005
	if _snow_layer.visible:
		_snow_material.set_shader_parameter("cover", snow)
		if not _snow_drawn:
			_snow_drawn = true
			_snow_layer.queue_redraw()
	elif before > 0.0 and snow == 0.0:
		_snow_drawn = false


func _draw_snow() -> void:
	# One sheet over the whole area; the land mask keeps it off the water.
	_snow_layer.draw_rect(_mask_rect, Color.WHITE)


func _draw() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var daylight := 1.0 - _day_night.darkness()
	# Shadows of clouds crossing the land on a fair day.
	if daylight > 0.25 and Atmosphere.weather == "":
		var here := _player.global_position
		for cloud: Array in _clouds:
			var drifted: Vector2 = cloud[0] + Vector2(14.0, 5.0) * t * cloud[2]
			var at := here + Vector2(wrapf(drifted.x - here.x, -CLOUD_FIELD.x / 2.0, CLOUD_FIELD.x / 2.0), wrapf(drifted.y - here.y, -CLOUD_FIELD.y / 2.0, CLOUD_FIELD.y / 2.0))
			var radius: float = cloud[1]
			draw_texture_rect(Prop.LIGHT, Rect2(at - Vector2(radius * 1.5, radius), Vector2(radius * 3.0, radius * 2.0)), false, Color(0.0, 0.0, 0.05, 0.3 * daylight))
	# Foam lapping in and out along each shore.
	for edge: Array in _foam:
		var rect: Rect2 = edge[0]
		var phase: float = edge[2]
		var reach := 7.0 + sin(t * 1.4 + phase) * 3.0
		_foam_line(rect, edge[1], reach, phase, t, Color(0.93, 0.97, 1.0, 0.62), 2.0)
		_foam_line(rect, edge[1], reach + 6.0 + sin(t * 1.1 + phase * 2.0) * 1.5, phase + 1.7, t, Color(0.85, 0.94, 1.0, 0.26), 1.5)
	# Small wave crests drifting with the current.
	for wave: Array in _waves:
		var share: float = wave[1] / wave[2]
		var alpha := sin(share * PI) * 0.32
		var at: Vector2 = wave[0] + Vector2(share * 6.0, 0.0)
		draw_arc(at, wave[3], PI * 1.15, PI * 1.85, 8, Color(0.86, 0.94, 1.0, alpha), 1.5)
	# Glints of light.
	var glint_color := Color(1.0, 0.98, 0.88) if daylight > 0.4 else Color(0.75, 0.85, 1.0)
	for glint: Array in _glints:
		var share: float = glint[1] / glint[2]
		var power := sin(share * PI)
		var reach: float = glint[3] * power
		var color := Color(glint_color, power * (0.45 + daylight * 0.5))
		var at: Vector2 = glint[0]
		draw_line(at - Vector2(reach, 0), at + Vector2(reach, 0), color, 1.0)
		draw_line(at - Vector2(0, reach * 0.7), at + Vector2(0, reach * 0.7), color, 1.0)
		draw_rect(Rect2(at - Vector2(0.5, 0.5), Vector2(1.5, 1.5)), color)
	# Raindrops striking the ground.
	for splash: Array in _splashes:
		var share: float = splash[1] / 0.32
		var at: Vector2 = splash[0]
		var color := Color(0.8, 0.88, 1.0, 0.55 * (1.0 - share))
		var radius := 1.0 + share * (6.0 if splash[2] else 4.0)
		draw_set_transform(at, 0.0, Vector2(1.0, 0.45))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 12, color, 1.0)
		draw_set_transform(Vector2.ZERO)
		if share < 0.5 and not splash[2]:
			draw_rect(Rect2(at + Vector2(-3.0, -2.0 - share * 8.0), Vector2(1, 1)), color)
			draw_rect(Rect2(at + Vector2(2.0, -1.0 - share * 7.0), Vector2(1, 1)), color)


## A broken, wavy line of foam parallel to one side of a water tile,
## `reach` in from it: bright where the wave breaks, gone in the gaps.
func _foam_line(rect: Rect2, side: int, reach: float, phase: float, t: float, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	for k in 9:
		var along := k / 8.0
		var wobble := sin(along * 9.0 + phase * 3.0 + t * 0.8) * 1.5
		match side:
			0:
				points.append(Vector2(rect.position.x + along * rect.size.x, rect.position.y + reach + wobble))
			1:
				points.append(Vector2(rect.end.x - reach - wobble, rect.position.y + along * rect.size.y))
			2:
				points.append(Vector2(rect.position.x + along * rect.size.x, rect.end.y - reach - wobble))
			_:
				points.append(Vector2(rect.position.x + reach + wobble, rect.position.y + along * rect.size.y))
	for k in points.size() - 1:
		var strength := 0.5 + 0.5 * sin(k * 1.9 + phase * 2.3 + t * 1.2)
		if strength > 0.22:
			draw_line(points[k], points[k + 1], Color(color, color.a * strength), width)
