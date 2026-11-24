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
var _highland := FastNoiseLite.new()
var _cache: Dictionary = {}
## Ground the player has laid or dug (paths, decking, turf, ponds...):
## cell -> terrain type, over whatever the world would have there.
var overrides: Dictionary = {}
var _altar := Vector2i.ZERO
var _altar_found := false


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
	_setup(_highland, p_seed + 3301, 0.012, 2)


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
	var forced: Variant = overrides.get(cell)
	if forced != null:
		return forced
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
	return TerrainTiles.pick_variant(hash(Vector3i(cell.x, cell.y, world_seed)))


func is_walkable(cell: Vector2i) -> bool:
	return not TerrainTiles.is_solid(tile_type_at(cell))


## Dry, open ground: where things can be placed and monsters can appear.
func is_dry_land(cell: Vector2i) -> bool:
	var type := tile_type_at(cell)
	return not TerrainTiles.is_solid(type) and not TerrainTiles.is_water(type)


## Nearest dry tile to `cell`, searching outward in square rings.
## Whether a cliff face stands on this tile: higher ground lies just north.
func is_cliff_base(cell: Vector2i) -> bool:
	return height_at(cell + Vector2i.UP) > height_at(cell) and not TerrainTiles.is_water(tile_type_at(cell))


## Land on which raised ground (a plateau of its own ground, an earthen
## face along its south side) can stand. Wet and low places stay low.
## Ground that rises into plateaus: grass, snow and woods, whose banks read
## as earth. Sand, salt, ash and cinder stay flat: their banks were the same
## colour top and bottom and read as stray rectangles on the ground.
const RAISABLE: Array[int] = [T.DEAD_GRASS, T.DARK_GRASS, T.SNOW, T.FROSTPINE, T.THORN, T.CRIMSON, T.FUNGAL]


## How many steps up the ground stands here: mountains by their rock (1)
## and peaks (2); out in the open country, plateaus of grass, snow or sand
## one step up. Never near the Sanctuary, in villages, on islands or water.
func height_at(cell: Vector2i) -> int:
	var type := tile_type_at(cell)
	var base := CliffFaces.level(type)
	if base > 0 or not type in RAISABLE:
		return base
	if Vector2(cell).length() < SANCTUARY_OUTER + 30.0 or village_near(cell) != null:
		return 0
	if _highland.get_noise_2d(cell.x, cell.y) <= 0.3 or is_island(cell):
		return 0
	return 1 if _broad_highland(cell) else 0


## Whether the high ground here is part of a broad rise: most of the tiles
## round it are high too. Thin spurs, single raised tiles and one-tile notches
## are smoothed away, so a plateau's edge runs in long curves, not in steps.
var _broad: Dictionary = {}


func _broad_highland(cell: Vector2i) -> bool:
	if _broad.has(cell):
		return _broad[cell]
	if _broad.size() > 20000:
		_broad.clear()
	var around := 0
	for offset: Vector2i in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]:
		var near := cell + offset
		if _highland.get_noise_2d(near.x, near.y) > 0.3 and tile_type_at(near) in RAISABLE:
			around += 1
	_broad[cell] = around >= 5
	return _broad[cell]


## Where a cliff face has steps cut into it, so the high ground can be
## climbed there: wherever a road meets it, and now and then along a long
## face (both neighbours faces too).
func is_stairs(cell: Vector2i) -> bool:
	if not is_cliff_base(cell) or CliffFaces.level(tile_type_at(cell + Vector2i.UP)) > 0:
		return false
	if tile_type_at(cell) == T.PATH or tile_type_at(cell + Vector2i.UP) == T.PATH:
		return true
	return posmod(hash(Vector3i(cell.x, cell.y, world_seed + 5)), 9) == 0 and is_cliff_base(cell + Vector2i.LEFT) and is_cliff_base(cell + Vector2i.RIGHT)


## Where the Altar of Magic stands: about MagicDB.ALTAR_DISTANCE tiles out
## from the temple, in a direction the world's seed chooses, on the nearest
## open dry ground.
func magic_altar_cell() -> Vector2i:
	if _altar_found:
		return _altar
	var random := RandomNumberGenerator.new()
	random.seed = world_seed + 7177
	var target := Vector2i(Vector2.from_angle(random.randf() * TAU) * MagicDB.ALTAR_DISTANCE)
	_altar = target
	for radius in 120:
		var found := false
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				if maxi(absi(x), absi(y)) != radius:
					continue
				var cell := target + Vector2i(x, y)
				if is_dry_land(cell) and not tile_type_at(cell) in TerrainTiles.HIGH and is_dry_land(cell + Vector2i(0, 2)) and is_dry_land(cell + Vector2i(0, -2)):
					_altar = cell
					found = true
					break
			if found:
				break
		if found:
			break
	_altar_found = true
	return _altar


## Where the Sky Shrine stands, the way into Puzzlementson and the Trial of
## Panic: far out (about SKY_SHRINE_DISTANCE tiles), in a direction the
## seed chooses, on open dry ground. Found, not shown, on the map.
const SKY_SHRINE_DISTANCE := 900.0
var _sky_shrine := Vector2i.ZERO
var _sky_shrine_found := false


func sky_shrine_cell() -> Vector2i:
	if _sky_shrine_found:
		return _sky_shrine
	var random := RandomNumberGenerator.new()
	random.seed = world_seed + 9091
	var target := Vector2i(Vector2.from_angle(random.randf() * TAU) * SKY_SHRINE_DISTANCE)
	_sky_shrine = target
	for radius in 120:
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				if maxi(absi(x), absi(y)) != radius:
					continue
				var cell := target + Vector2i(x, y)
				if is_dry_land(cell) and height_at(cell) == 0 and is_dry_land(cell + Vector2i(0, 2)) and is_dry_land(cell + Vector2i(0, -2)):
					_sky_shrine = cell
					_sky_shrine_found = true
					return _sky_shrine
	_sky_shrine_found = true
	return _sky_shrine


var _landmarks: Dictionary = {}

## Saint Lull's House (see SaintLull): where it stands and how far its
## grounds reach. Its ground is laid here: a dark lawn inside the wall, a
## path from the front gate to the door, and withered wheat-land round it.
const LULL_HOUSE := [7313, 320.0, 15]
var _lull_home := Vector2i.MAX
var _finding_lull := false


func lull_house_cell() -> Vector2i:
	if _lull_home == Vector2i.MAX:
		_finding_lull = true
		_lull_home = landmark_cell(LULL_HOUSE[0], LULL_HOUSE[1], LULL_HOUSE[2])
		_finding_lull = false
		# Ground worked out during the search is the bare land: forget it.
		for y in range(-LULL_HOUSE[2], LULL_HOUSE[2] + 1):
			for x in range(-LULL_HOUSE[2], LULL_HOUSE[2] + 1):
				_cache.erase(_lull_home + Vector2i(x, y))
	return _lull_home


func _house_ground(cell: Vector2i) -> int:
	if _finding_lull:
		return -1
	var at := cell - lull_house_cell()
	var reach: int = LULL_HOUSE[2] - 1
	if absi(at.x) > reach or absi(at.y) > reach:
		return -1
	# Ragged at the edge, so the wheat-land fades into whatever is round it.
	if maxi(absi(at.x), absi(at.y)) >= reach - 1 and posmod(hash(Vector3i(cell.x, cell.y, world_seed + 77)), 3) == 0:
		return -1
	if absi(at.x) <= 1 and at.y >= 0 and at.y <= 7:
		return T.PATH
	if absi(at.x) <= 6 and absi(at.y) <= 6:
		return T.DARK_GRASS
	return T.DEAD_GRASS


## A fixed place for a landmark of this world: about `distance` tiles out
## from the temple in a direction `seed_offset` chooses, on the nearest
## open dry ground with room around it (`room` tiles every way), away from
## villages. The same for a world; worked out once.
func landmark_cell(seed_offset: int, distance: float, room: int = 4) -> Vector2i:
	var key := Vector3i(seed_offset, roundi(distance), room)
	if _landmarks.has(key):
		return _landmarks[key]
	var random := RandomNumberGenerator.new()
	random.seed = world_seed + seed_offset
	var target := Vector2i(Vector2.from_angle(random.randf() * TAU) * distance)
	var found := _open_ground_near(target, room, 150)
	_landmarks[key] = found
	return found


## The nearest open ground to a cell, for something that belongs beside
## another landmark (a hatch by the house).
func landmark_near(target: Vector2i, seed_offset: int, room: int = 2) -> Vector2i:
	var key := Vector3i(target.x * 7 + seed_offset, target.y, room)
	if _landmarks.has(key):
		return _landmarks[key]
	var found := _open_ground_near(target, room, 60)
	_landmarks[key] = found
	return found


## Searches out in square rings (every other ring, every other cell, to
## stay quick) for a cell whose surroundings are dry and away from villages.
func _open_ground_near(target: Vector2i, room: int, max_radius: int) -> Vector2i:
	for radius in range(0, max_radius, 2):
		for y in range(-radius, radius + 1, 2 if radius > 0 else 1):
			for x in range(-radius, radius + 1, 2 if radius > 0 else 1):
				if maxi(absi(x), absi(y)) != radius:
					continue
				var cell := target + Vector2i(x, y)
				if _has_room(cell, room):
					return cell
	return find_walkable_near(target)


func _has_room(cell: Vector2i, room: int) -> bool:
	if village_near(cell) != null or Vector2(cell).length() < SANCTUARY_OUTER + 30.0:
		return false
	var step := maxi(room / 3, 1)
	for y in range(-room, room + 1, step):
		for x in range(-room, room + 1, step):
			if not is_dry_land(cell + Vector2i(x, y)):
				return false
	return village_near(cell + Vector2i(room, room)) == null and village_near(cell - Vector2i(room, room)) == null


## Drops a cell's remembered terrain, so it is worked out afresh.
func forget(cell: Vector2i) -> void:
	_cache.erase(cell)


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
	if center != null and Vector2(cell - center).length() <= village_radius(center) + 2.0:
		return center
	return null


## Capitals are bigger: more houses on a wider clearing.
const CAPITAL_RADIUS := 22.0
const CAPITAL_CHANCE := 0.18
const CASTLE_CHANCE := 0.10


func _village_roll(center: Vector2i, salt: int) -> float:
	var random := RandomNumberGenerator.new()
	random.seed = hash(Vector4i(center.x, center.y, world_seed, salt))
	return random.randf()


## Who built a village: "human", "elf" (in the deep woods) or "dwarf" (up
## in the high, rocky ground). The first village anyone finds is human.
func village_culture(center: Vector2i) -> String:
	if center == first_village():
		return "human"
	var roll := _village_roll(center, 1)
	var high := _base_elevation(center) > 0.2
	var tile := _natural(center)
	var wooded := tile in [T.DARK_GRASS, T.FUNGAL, T.THORN, T.FROSTPINE, T.BOG]
	if high:
		return "dwarf" if roll < 0.7 else "human"
	if wooded:
		return "elf" if roll < 0.6 else "human"
	return "elf" if roll < 0.18 else "dwarf" if roll < 0.3 else "human"


## A capital: the biggest village of its people for miles around.
func is_capital(center: Vector2i) -> bool:
	return center != first_village() and _village_roll(center, 2) < CAPITAL_CHANCE


## One village in ten has a castle where the king sometimes stays.
func has_castle(center: Vector2i) -> bool:
	return village_culture(center) == "human" and _village_roll(center, 3) < CASTLE_CHANCE / 0.62


func village_radius(center: Vector2i) -> float:
	return CAPITAL_RADIUS if is_capital(center) or has_castle(center) else VILLAGE_RADIUS


const NAME_PARTS := {
	"human": [["Ash", "Briar", "Corn", "Dun", "Elder", "Fair", "Gold", "Hollow", "Ivy", "Kings", "Lark", "Mill", "Oak", "Red", "Stone", "Thorn", "Wey", "Wil"],
		["ford", "bury", "field", "wick", "stead", "brook", "haven", "ham", "mere", "gate", "cross", "dale"]],
	"elf": [["Sil", "Ael", "Lor", "Ith", "Fae", "Cael", "Elu", "Nym", "Thal", "Ver", "Ys", "Mir"],
		["varen", "aneth", "dorel", "ithil", "wyn", "lasse", "oriel", "athae", "enor", "iel"]],
	"dwarf": [["Khaz", "Dur", "Bar", "Grom", "Thor", "Kar", "Bel", "Dun", "Mor", "Az", "Gund", "Oth"],
		["-Dorran", "-Haldur", "grim", "dak", "rund", "-Bakar", "mar", "zul", "-Karak", "hold"]],
}


## What a village is called, after the people who built it.
func village_name(center: Vector2i) -> String:
	var parts: Array = NAME_PARTS[village_culture(center)]
	var random := RandomNumberGenerator.new()
	random.seed = hash(Vector4i(center.x, center.y, world_seed, 4))
	return str((parts[0] as Array)[random.randi() % (parts[0] as Array).size()]) + str((parts[1] as Array)[random.randi() % (parts[1] as Array).size()])


func _base_elevation(cell: Vector2i) -> float:
	return _elevation.get_noise_2d(cell.x, cell.y)


func _compute(cell: Vector2i) -> int:
	var village: Variant = village_near(cell)
	if village != null:
		return _village_tile(cell, village)
	var grounds := _house_ground(cell)
	if grounds >= 0:
		return grounds
	var natural := _natural(cell)
	if on_road(cell):
		# Roads cut through hills and cross shallows on planks; deep water
		# stops them.
		if natural == T.DEEP_WATER:
			return natural
		return T.PLANK if natural == T.SHALLOW_WATER else T.PATH
	return natural


# --- roads

## Villages further apart than this have no road between them.
const ROAD_REACH := 340.0
## Roads that pass through each village region: region -> [[from, to, phase]].
var _roads: Dictionary = {}


## Whether a tile lies on a road: a wandering track two tiles wide between
## neighbouring villages, and one from the Sanctuary to the first village.
func on_road(cell: Vector2i) -> bool:
	var point := Vector2(cell)
	for road: Array in roads_near(Vector2i((point / VILLAGE_REGION).floor())):
		var from: Vector2 = road[0]
		var to: Vector2 = road[1]
		var length := from.distance_to(to)
		var direction := (to - from) / length
		var t := (point - from).dot(direction) / length
		if t < 0.0 or t > 1.0:
			continue
		if absf(direction.cross(point - from) - road_bend(road, t)) <= 1.05:
			return true
	return false


## How far a road strays to one side of the straight line, partway along.
static func road_bend(road: Array, t: float) -> float:
	var length: float = (road[0] as Vector2).distance_to(road[1])
	return (sin(t * length / 29.0 + road[2]) * 5.0 + sin(t * length / 11.0 + road[2] * 2.0) * 1.6) * sin(PI * t)


## A point on a road, partway along it, in tiles.
static func road_point(road: Array, t: float) -> Vector2:
	var from: Vector2 = road[0]
	var to: Vector2 = road[1]
	var direction := (to - from).normalized()
	return from.lerp(to, t) + direction.orthogonal() * -road_bend(road, t)


## Every road that passes through a village region.
func roads_near(region: Vector2i) -> Array:
	if _roads.has(region):
		return _roads[region]
	var area := Rect2(Vector2(region * VILLAGE_REGION), Vector2(VILLAGE_REGION, VILLAGE_REGION)).grow(10.0)
	var found: Array = []
	var candidates: Array = []
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			candidates.append_array(roads_from(region + Vector2i(dx, dy)))
	var first := Vector2(first_village())
	candidates.append([first.normalized() * 12.0, first, 0.7])
	for road: Array in candidates:
		if Rect2(road[0], Vector2.ZERO).expand(road[1]).grow(10.0).intersects(area):
			found.append(road)
	_roads[region] = found
	return found


## The roads leading out of the village in a region toward its neighbours
## east and south (each pair of villages shares one road).
func roads_from(region: Vector2i) -> Array:
	var center: Variant = village_center(region)
	if center == null:
		return []
	var result: Array = []
	for step: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]:
		var other: Variant = village_center(region + step)
		if other != null and Vector2(other - center).length() < ROAD_REACH:
			result.append([Vector2(center), Vector2(other), float(posmod(hash(Vector3i(region.x, region.y, step.x * 3 + step.y)), 1000)) / 100.0])
	return result


## Inside a village: roads crossing the middle, and the land's own ground,
## never water or mountain.
func _village_tile(cell: Vector2i, center: Vector2i) -> int:
	var offset := cell - center
	var distance := Vector2(offset).length()
	var reach := village_radius(center)
	if distance <= reach and (absi(offset.x) <= 1 or absi(offset.y) <= 1 or (distance > 5.5 and distance < 7.0) or (reach > VILLAGE_RADIUS and distance > 13.5 and distance < 15.0)):
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
