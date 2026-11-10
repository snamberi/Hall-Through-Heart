class_name WorldGenerator
extends RefCounted
## Decides what terrain is at any tile of the endless world.
##
## Everything here is a pure function of the seed and the tile position, so a
## chunk can be thrown away and rebuilt identically at any time.
## Hand-made areas (boss arenas, ruins) will hook in here later by overriding
## the generated terrain inside their footprint.

## Tiles around the origin that are always open ground, so the start is safe.
const SANCTUARY_INNER := 8.0
const SANCTUARY_OUTER := 26.0

var world_seed: int

var _elevation := FastNoiseLite.new()
var _moisture := FastNoiseLite.new()


func _init(p_seed: int) -> void:
	world_seed = p_seed

	_elevation.seed = p_seed
	_elevation.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_elevation.frequency = 0.006
	_elevation.fractal_type = FastNoiseLite.FRACTAL_FBM
	_elevation.fractal_octaves = 5

	_moisture.seed = p_seed + 1013
	_moisture.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_moisture.frequency = 0.004
	_moisture.fractal_type = FastNoiseLite.FRACTAL_FBM
	_moisture.fractal_octaves = 3


func tile_type_at(cell: Vector2i) -> TerrainTiles.Type:
	var elevation := _elevation.get_noise_2d(cell.x, cell.y)
	var distance := Vector2(cell).length()
	if distance < SANCTUARY_OUTER:
		var blend := smoothstep(SANCTUARY_INNER, SANCTUARY_OUTER, distance)
		elevation = lerpf(0.05, elevation, blend)

	if elevation < -0.38:
		return TerrainTiles.Type.DEEP_WATER
	if elevation < -0.28:
		return TerrainTiles.Type.SHALLOW_WATER
	if elevation < -0.23:
		return TerrainTiles.Type.MUD
	if elevation > 0.45:
		return TerrainTiles.Type.ROCK

	var moisture := _moisture.get_noise_2d(cell.x, cell.y)
	if moisture < -0.18:
		return TerrainTiles.Type.ASH
	if moisture < 0.08:
		return TerrainTiles.Type.DEAD_GRASS
	if moisture < 0.30:
		return TerrainTiles.Type.DARK_GRASS
	return TerrainTiles.Type.BOG


## Which of the look-alike tile variants to draw at this tile.
func variant_at(cell: Vector2i) -> int:
	return posmod(hash(Vector3i(cell.x, cell.y, world_seed)), TerrainTiles.VARIANTS)


func is_walkable(cell: Vector2i) -> bool:
	return not TerrainTiles.is_solid(tile_type_at(cell))


## Nearest walkable tile to `cell`, searching outward in square rings.
func find_walkable_near(cell: Vector2i, max_radius: int = 64) -> Vector2i:
	for radius in max_radius + 1:
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				if maxi(absi(x), absi(y)) != radius:
					continue
				var candidate := cell + Vector2i(x, y)
				if is_walkable(candidate):
					return candidate
	return cell
