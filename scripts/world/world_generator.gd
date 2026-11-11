class_name WorldGenerator
extends RefCounted
## Decides what terrain is at any tile of the endless world.
##
## Everything here is a pure function of the seed and the tile position, so a
## chunk can be thrown away and rebuilt identically at any time.
##
## Height makes water, shores, and crags. On dry land, temperature picks a
## climate band and moisture picks the biome inside it. Sampling positions
## are nudged by fine noise so borders come out ragged rather than smooth.

const T := TerrainTiles.Type
## Tiles around the origin that are always open ground, so the start is safe.
const SANCTUARY_INNER := 5.0
const SANCTUARY_OUTER := 14.0
## Inside this many tiles of the origin the climate is always temperate.
const HOME_CLIMATE_RADIUS := 70.0
## Tiles of travel away from the start per enemy level.
const LEVEL_DISTANCE_TILES := 40.0
## The Voidscar only opens up this far out.
const VOIDSCAR_MIN_DISTANCE := 150.0
## Climate bands, coldest first: [upper temperature, [[upper moisture, type], ...]].
const CLIMATES: Array[Array] = [
	[-0.24, [[-0.12, T.SALT], [0.16, T.SNOW], [9.0, T.FROSTPINE]]],
	[0.06, [[-0.18, T.ASH], [0.08, T.DEAD_GRASS], [0.3, T.DARK_GRASS], [9.0, T.BOG]]],
	[0.34, [[-0.14, T.THORN], [0.08, T.CRIMSON], [0.28, T.FUNGAL], [9.0, T.TAR]]],
	[9.0, [[0.02, T.SAND], [9.0, T.CINDER]]],
]
## How much tougher enemies are on harsh ground.
const DANGER := {T.ASH: 1.15, T.BOG: 1.1, T.SALT: 1.1, T.SNOW: 1.1, T.FROSTPINE: 1.1, T.THORN: 1.15, T.CRIMSON: 1.2,
	T.FUNGAL: 1.2, T.TAR: 1.2, T.SAND: 1.15, T.CINDER: 1.3, T.VOIDSCAR: 1.6}
const CACHE_LIMIT := 120000

var world_seed: int

var _elevation := FastNoiseLite.new()
var _moisture := FastNoiseLite.new()
var _temperature := FastNoiseLite.new()
var _weird := FastNoiseLite.new()
var _danger := FastNoiseLite.new()
var _warp := FastNoiseLite.new()
var _cache: Dictionary = {}


func _init(p_seed: int) -> void:
	world_seed = p_seed
	_setup(_elevation, p_seed, 0.009, 5)
	_setup(_moisture, p_seed + 1013, 0.006, 3)
	_setup(_temperature, p_seed + 4051, 0.0022, 2)
	_setup(_weird, p_seed + 6007, 0.004, 2)
	_setup(_danger, p_seed + 2027, 0.004, 1)
	_setup(_warp, p_seed + 9001, 0.11, 1)


## Enemy level for an area. Rises with distance from the start, with pockets
## of extra danger and harsher biomes mixed in so it is not distance alone.
## Roughly: level 10 at 360 tiles out, 50 at 2,000, 200 at 8,000.
func enemy_level_at(cell: Vector2i) -> int:
	var distance := maxf(Vector2(cell).length() - SANCTUARY_OUTER, 0.0)
	var level := 1.0 + distance / LEVEL_DISTANCE_TILES
	level *= 1.0 + maxf(_danger.get_noise_2d(cell.x, cell.y), 0.0) * 0.8
	level *= DANGER.get(tile_type_at(cell), 1.0)
	return maxi(roundi(level), 1)


func tile_type_at(cell: Vector2i) -> int:
	var cached: Variant = _cache.get(cell)
	if cached != null:
		return cached
	if _cache.size() > CACHE_LIMIT:
		_cache.clear()
	var type := _compute(cell)
	_cache[cell] = type
	return type


## Which of the look-alike tile variants to draw at this tile.
func variant_at(cell: Vector2i) -> int:
	return posmod(hash(Vector3i(cell.x, cell.y, world_seed)), 8)


func is_walkable(cell: Vector2i) -> bool:
	return not TerrainTiles.is_solid(tile_type_at(cell))


## Dry, open ground: where things can be placed and monsters can appear.
func is_dry_land(cell: Vector2i) -> bool:
	var type := tile_type_at(cell)
	return not TerrainTiles.is_solid(type) and not TerrainTiles.is_water(type)


## Nearest dry tile to `cell`, searching outward in square rings.
func find_walkable_near(cell: Vector2i, max_radius: int = 64) -> Vector2i:
	for radius in max_radius + 1:
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				if maxi(absi(x), absi(y)) != radius:
					continue
				var candidate := cell + Vector2i(x, y)
				if is_dry_land(candidate):
					return candidate
	return cell


func _compute(cell: Vector2i) -> int:
	# Nudge where we sample so borders wander by a tile or two.
	var x := cell.x + _warp.get_noise_2d(cell.x, cell.y) * 2.2
	var y := cell.y + _warp.get_noise_2d(cell.x + 500.0, cell.y - 500.0) * 2.2
	var distance := Vector2(cell).length()
	var elevation := _elevation.get_noise_2d(x, y)
	if distance < SANCTUARY_OUTER:
		elevation = lerpf(0.05, elevation, smoothstep(SANCTUARY_INNER, SANCTUARY_OUTER, distance))
	var temperature := _temperature.get_noise_2d(x, y)
	if distance < HOME_CLIMATE_RADIUS:
		temperature = lerpf(-0.05, temperature, smoothstep(HOME_CLIMATE_RADIUS * 0.5, HOME_CLIMATE_RADIUS, distance))

	if elevation < -0.38:
		return T.DEEP_WATER
	if elevation < -0.28:
		return T.SHALLOW_WATER
	if elevation < -0.23:
		# The shore takes after the climate.
		return T.SNOW if temperature < -0.24 else T.SAND if temperature > 0.34 else T.MUD
	if elevation > 0.45:
		return T.ROCK
	if distance > VOIDSCAR_MIN_DISTANCE and _weird.get_noise_2d(x, y) > 0.62:
		return T.VOIDSCAR
	var moisture := _moisture.get_noise_2d(x, y)
	for climate in CLIMATES:
		if temperature < climate[0]:
			for band: Array in climate[1]:
				if moisture < band[0]:
					return band[1]
	return T.DEAD_GRASS


func _setup(noise: FastNoiseLite, noise_seed: int, frequency: float, octaves: int) -> void:
	noise.seed = noise_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = frequency
	if octaves > 1:
		noise.fractal_type = FastNoiseLite.FRACTAL_FBM
		noise.fractal_octaves = octaves
	else:
		noise.fractal_type = FastNoiseLite.FRACTAL_NONE
