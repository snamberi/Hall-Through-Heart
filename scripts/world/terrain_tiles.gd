class_name TerrainTiles
extends RefCounted
## Terrain tile definitions and the tileset built from the terrain atlas.
##
## The atlas image has one row per Type (in enum order) and one column per
## look-alike variant. Replace the PNG with new art of the same layout to
## reskin the world.

const TILE_SIZE := 44
const VARIANTS := 8
const ATLAS: Texture2D = preload("res://assets/tiles/terrain.png")

enum Type {
	DEEP_WATER,
	SHALLOW_WATER,
	MUD,
	ASH,
	DEAD_GRASS,
	DARK_GRASS,
	BOG,
	ROCK,
}

const NAMES: Array[String] = [
	"Black Water",
	"Shallows",
	"Mudflats",
	"Ashen Waste",
	"Withered Fields",
	"Gloomwood",
	"Rotmire",
	"Cragstone",
]

## Flat colour for each type, for maps and previews.
const COLORS: Array[Color] = [
	Color("141b2b"),
	Color("23364a"),
	Color("3d342c"),
	Color("4b4a4e"),
	Color("4a4d32"),
	Color("26382c"),
	Color("2e3528"),
	Color("3a3944"),
]

## Tiles the player cannot walk through.
const SOLID: Array[bool] = [true, false, false, false, false, false, false, true]


static func display_name(type: Type) -> String:
	return NAMES[type]


static func is_solid(type: Type) -> bool:
	return SOLID[type]


static func build_tileset() -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(0, 1)
	tile_set.set_physics_layer_collision_mask(0, 0)

	var source := TileSetAtlasSource.new()
	source.texture = ATLAS
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	tile_set.add_source(source, 0)

	var half := TILE_SIZE / 2.0
	var square := PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half),
	])
	for type in Type.size():
		for variant in VARIANTS:
			var coords := Vector2i(variant, type)
			source.create_tile(coords)
			if SOLID[type]:
				var data := source.get_tile_data(coords, 0)
				data.add_collision_polygon(0)
				data.set_collision_polygon_points(0, 0, square)
	return tile_set
