class_name TerrainTiles
extends RefCounted
## Terrain tile definitions and the tileset built from the terrain atlas.
##
## The atlas has one row per Type, in enum order. Land rows hold eight
## look-alike variants; water rows hold two variants of four animation frames.
## A second image, fringes.png, holds each terrain cut to a ragged strip and
## corner, which the world lays over neighbouring tiles so borders blend.
## Saves store Type numbers, so only ever append to the enum.

const TILE_SIZE := 44
const ATLAS: Texture2D = preload("res://assets/tiles/terrain.png")
const FRINGES: Texture2D = preload("res://assets/tiles/fringes.png")
const TERRAIN_SOURCE := 0
const FRINGE_SOURCE := 1
## Physics layers: walls stop everyone; deep water stops walkers only.
const WALL_COLLISION := 1
const WATER_COLLISION := 8

enum Type {
	DEEP_WATER, SHALLOW_WATER, MUD, ASH, DEAD_GRASS, DARK_GRASS, BOG, ROCK,
	SNOW, FROSTPINE, SALT, THORN, CRIMSON, FUNGAL, TAR, SAND, CINDER, VOIDSCAR,
	PLANK, WALL, CAVE_FLOOR, PEAK,
}

const NAMES: Array[String] = [
	"Black Water", "Shallows", "Mudflats", "Ashen Waste", "Withered Fields", "Gloomwood", "Rotmire", "Mountains",
	"Frostfields", "Frostpine", "Pale Flats", "Thornheath", "Crimson Moor", "Sporewood", "Tar Mire", "Bone Desert",
	"Cinderlands", "Voidscar", "Floorboards", "Stone Wall", "Cavern", "High Peaks",
]

## Flat colour for each type, for maps and previews.
const COLORS: Array[Color] = [
	Color("141b2b"), Color("23364a"), Color("3d342c"), Color("4b4a4e"), Color("4a4d32"), Color("26382c"), Color("2e3528"), Color("5a5560"),
	Color("c8d0d8"), Color("3d5a58"), Color("8c8a84"), Color("4a4030"), Color("4a2830"), Color("3a2c4a"), Color("1c1a1e"), Color("8a7650"),
	Color("3a2a28"), Color("1a1428"), Color("6b4f36"), Color("2a2630"), Color("34323a"), Color("8a8794"),
]

## Tiles nothing can pass through. Only walls inside buildings and caves:
## out in the world, mountains are climbed rather than walked around.
const SOLID: Array[int] = [Type.WALL]
## High ground: drawn with a cliff face on its lower edge.
const HIGH: Array[int] = [Type.ROCK, Type.PEAK]
const WATER: Array[int] = [Type.DEEP_WATER, Type.SHALLOW_WATER]
## Types that only exist indoors and underground, never in the open world.
const INTERIOR: Array[int] = [Type.PLANK, Type.WALL, Type.CAVE_FLOOR]
## How fast the player moves on a tile, as a share of normal speed.
const SPEED := {Type.DEEP_WATER: 0.5, Type.SHALLOW_WATER: 0.7, Type.TAR: 0.6, Type.SNOW: 0.92, Type.BOG: 0.92,
	Type.ROCK: 0.82, Type.PEAK: 0.68}
## Where two terrains meet, the one later in this list spills over the other.
const OVERLAP_ORDER: Array[int] = [
	Type.DEEP_WATER, Type.SHALLOW_WATER, Type.TAR, Type.MUD, Type.SAND, Type.SALT, Type.ASH, Type.CINDER, Type.VOIDSCAR,
	Type.BOG, Type.DEAD_GRASS, Type.THORN, Type.CRIMSON, Type.FUNGAL, Type.DARK_GRASS, Type.FROSTPINE, Type.SNOW,
	Type.CAVE_FLOOR, Type.PLANK, Type.ROCK, Type.PEAK, Type.WALL,
]
const WATER_FRAMES := 4
const WATER_FRAME_SECONDS := 0.4

static var _priority: Array[int] = []


static func display_name(type: int) -> String:
	return NAMES[type]


static func is_solid(type: int) -> bool:
	return type in SOLID


static func is_water(type: int) -> bool:
	return type in WATER


static func speed(type: int) -> float:
	return SPEED.get(type, 1.0)


## Higher numbers spill over lower ones where they touch.
static func priority(type: int) -> int:
	if _priority.is_empty():
		_priority.resize(Type.size())
		for index in OVERLAP_ORDER.size():
			_priority[OVERLAP_ORDER[index]] = index
	return _priority[type]


## Atlas cell for a type and a variant number (any non-negative integer).
static func atlas_coords(type: int, variant: int) -> Vector2i:
	if is_water(type):
		return Vector2i((variant % 2) * WATER_FRAMES, type)
	return Vector2i(variant % 8, type)


static func build_tileset() -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for collision: int in [WALL_COLLISION, WATER_COLLISION]:
		tile_set.add_physics_layer()
		var layer := tile_set.get_physics_layers_count() - 1
		tile_set.set_physics_layer_collision_layer(layer, collision)
		tile_set.set_physics_layer_collision_mask(layer, 0)

	var half := TILE_SIZE / 2.0
	var square := PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half),
	])
	var source := TileSetAtlasSource.new()
	source.texture = ATLAS
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	tile_set.add_source(source, TERRAIN_SOURCE)
	for type in Type.size():
		for variant in (2 if is_water(type) else 8):
			var coords := atlas_coords(type, variant)
			source.create_tile(coords)
			if is_water(type):
				source.set_tile_animation_columns(coords, WATER_FRAMES)
				source.set_tile_animation_frames_count(coords, WATER_FRAMES)
				for frame in WATER_FRAMES:
					source.set_tile_animation_frame_duration(coords, frame, WATER_FRAME_SECONDS)
			var physics_layer := 0 if is_solid(type) else -1
			if physics_layer >= 0:
				var data := source.get_tile_data(coords, 0)
				data.add_collision_polygon(physics_layer)
				data.set_collision_polygon_points(physics_layer, 0, square)

	var fringes := TileSetAtlasSource.new()
	fringes.texture = FRINGES
	fringes.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	tile_set.add_source(fringes, FRINGE_SOURCE)
	for type in Type.size():
		fringes.create_tile(Vector2i(0, type))
		fringes.create_tile(Vector2i(1, type))
		if type in HIGH:
			fringes.create_tile(Vector2i(2, type))
	return tile_set
