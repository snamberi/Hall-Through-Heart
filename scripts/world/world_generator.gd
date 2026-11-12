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
## Villages: at most one per VILLAGE_REGION square of tiles, on cleared land
## VILLAGE_RADIUS tiles across with roads through the middle. One always
## stands about FIRST_VILLAGE_DISTANCE tiles from the start.
const VILLAGE_REGION := 190
const VILLAGE_CHANCE := 0.55
const VILLAGE_RADIUS := 15.0
const FIRST_VILLAGE_DISTANCE := 300.0

var world_seed: int

var _elevation := FastNoiseLite.new()
var _moisture := FastNoiseLite.new()
var _temperature := FastNoiseLite.new()
var _weird := FastNoiseLite.new()
var _danger := FastNoiseLite.new()
var _warp := FastNoiseLite.new()
var _islands := FastNoiseLite.new()
var _cache: Dictionary = {}


func _init(p_seed: int) -> void:
	world_seed = p_seed
	# Low frequencies make broad regions: a biome is often a few hundred
	# tiles across.
	_setup(_elevation, p_seed, 0.0034, 5)
	_setup(_moisture, p_seed + 1013, 0.0021, 3)
	_setup(_temperature, p_seed + 4051, 0.0009, 2)
	_setup(_weird, p_seed + 6007, 0.0017, 2)
	_setup(_danger, p_seed + 2027, 0.004, 1)
	_setup(_warp, p_seed + 9001, 0.08, 1)
	_setup(_islands, p_seed + 7717, 0.03, 2)


## Enemy level for an area. Rises with distance from the start, with pockets
## of extra danger and harsher biomes mixed in so it is not distance alone.
## Roughly: level 10 at 360 tiles out, 50 at 2,000, 200 at 8,000.
func enemy_level_at(cell: Vector2i) -> int:
	var distance := maxf(Vector2(cell).length() - SANCTUARY_OUTER, 0.0)
	var level := 1.0 + distance / LEVEL_DISTANCE_TILES
	level *= 1.0 + maxf(_danger.get_noise_2d(cell.x, cell.y), 0.0) * 0.8
	level *= DANGER.get(tile_type_at(cell), 1.0)
	if is_island(cell):
		level += 5.0
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
## Whether a cliff face stands on this tile: higher ground lies just north.
func is_cliff_base(cell: Vector2i) -> bool:
	return CliffFaces.level(tile_type_at(cell + Vector2i.UP)) > CliffFaces.level(tile_type_at(cell)) and not TerrainTiles.is_water(tile_type_at(cell))


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


## The middle of the village in a region, or null if it has none.
func village_center(region: Vector2i) -> Variant:
	var first := first_village()
	if Vector2i((Vector2(first) / VILLAGE_REGION).floor()) == region:
		return first
	if region == Vector2i.ZERO or region == Vector2i(-1, 0) or region == Vector2i(0, -1) or region == Vector2i(-1, -1):
		return null
	var random := RandomNumberGenerator.new()
	random.seed = hash(Vector3i(region.x, region.y, world_seed + 515))
	if random.randf() > VILLAGE_CHANCE:
		return null
	var center := region * VILLAGE_REGION + Vector2i(random.randi_range(30, VILLAGE_REGION - 30), random.randi_range(30, VILLAGE_REGION - 30))
	# Not in the middle of a lake or on a peak.
	if _base_elevation(center) < -0.2 or _base_elevation(center) > 0.4:
		return null
	return center


## The village everyone can find: a set distance from the start in a
## direction picked by the seed.
func first_village() -> Vector2i:
	var angle := float(posmod(world_seed, 3600)) / 3600.0 * TAU
	return Vector2i(Vector2.from_angle(angle) * FIRST_VILLAGE_DISTANCE)


## The village a tile belongs to, or null.
func village_near(cell: Vector2i) -> Variant:
	var region := Vector2i((Vector2(cell) / VILLAGE_REGION).floor())
	var center: Variant = village_center(region)
	if center != null and Vector2(cell - center).length() <= VILLAGE_RADIUS + 2.0:
		return center
	return null


func _base_elevation(cell: Vector2i) -> float:
	return _elevation.get_noise_2d(cell.x, cell.y)


func _compute(cell: Vector2i) -> int:
	var village: Variant = village_near(cell)
	if village != null:
		return _village_tile(cell, village)
	return _natural(cell)


## Inside a village: roads crossing the middle, and the land's own ground,
## never water or mountain.
func _village_tile(cell: Vector2i, center: Vector2i) -> int:
	var offset := cell - center
	var distance := Vector2(offset).length()
	if distance <= VILLAGE_RADIUS and (absi(offset.x) <= 1 or absi(offset.y) <= 1 or (distance > 5.5 and distance < 7.0)):
		return T.PATH
	var natural := _natural(cell)
	if TerrainTiles.is_water(natural) or natural in TerrainTiles.HIGH or natural == T.VOIDSCAR:
		var temperature := _temperature.get_noise_2d(cell.x, cell.y)
		return T.SNOW if temperature < -0.24 else T.SAND if temperature > 0.34 else T.DEAD_GRASS
	return natural


func _natural(cell: Vector2i) -> int:
	# Nudge where we sample so borders wander by a tile or two.
	var x := cell.x + _warp.get_noise_2d(cell.x, cell.y) * 3.0
	var y := cell.y + _warp.get_noise_2d(cell.x + 500.0, cell.y - 500.0) * 3.0
	var distance := Vector2(cell).length()
	var elevation := _elevation.get_noise_2d(x, y)
	if distance < SANCTUARY_OUTER:
		elevation = lerpf(0.05, elevation, smoothstep(SANCTUARY_INNER, SANCTUARY_OUTER, distance))
	var temperature := _temperature.get_noise_2d(x, y)
	if distance < HOME_CLIMATE_RADIUS:
		temperature = lerpf(-0.05, temperature, smoothstep(HOME_CLIMATE_RADIUS * 0.5, HOME_CLIMATE_RADIUS, distance))

	if elevation < -0.38:
		# Out in deep water, islands rise here and there.
		var island := _island_height(x, y, elevation)
		if island > 0.1:
			return _island_tile(x, y, island, temperature)
		if island > 0.0:
			return T.SHALLOW_WATER
		return T.DEEP_WATER
	if elevation < -0.28:
		return T.SHALLOW_WATER
	if elevation < -0.23:
		# The shore takes after the climate.
		return T.SNOW if temperature < -0.24 else T.SAND if temperature > 0.34 else T.MUD
	if elevation > 0.56:
		return T.PEAK
	if elevation > 0.42:
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


## How far above the sea an island stands at a point (0 or less: none).
## Islands only rise well out in deep water.
func _island_height(x: float, y: float, elevation: float) -> float:
	var depth := clampf((-0.38 - elevation) / 0.08, 0.0, 1.0)
	return (_islands.get_noise_2d(x, y) - 0.42) * 2.5 * depth


func _island_tile(x: float, y: float, height: float, temperature: float) -> int:
	if height < 0.25:
		return T.SNOW if temperature < -0.24 else T.SAND
	var moisture := _moisture.get_noise_2d(x * 3.0, y * 3.0)
	if temperature < -0.24:
		return T.FROSTPINE
	if moisture > 0.25:
		return T.FUNGAL
	if moisture < -0.25:
		return T.CRIMSON
	return T.DARK_GRASS


## Whether a tile is on an island out at sea.
func is_island(cell: Vector2i) -> bool:
	var x := cell.x + _warp.get_noise_2d(cell.x, cell.y) * 3.0
	var y := cell.y + _warp.get_noise_2d(cell.x + 500.0, cell.y - 500.0) * 3.0
	var elevation := _elevation.get_noise_2d(x, y)
	return elevation < -0.38 and _island_height(x, y, elevation) > 0.1


func _setup(noise: FastNoiseLite, noise_seed: int, frequency: float, octaves: int) -> void:
	noise.seed = noise_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = frequency
	if octaves > 1:
		noise.fractal_type = FastNoiseLite.FRACTAL_FBM
		noise.fractal_octaves = octaves
	else:
		noise.fractal_type = FastNoiseLite.FRACTAL_NONE
