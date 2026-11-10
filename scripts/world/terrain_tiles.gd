class_name TerrainTiles
extends RefCounted
## Terrain tile definitions and the placeholder tileset.
##
## The tileset is painted in code so the game runs with no art files.
## To use real art later, replace build_tileset() with a TileSet resource
## that keeps the same layout: one row per Type, one column per variant.

const TILE_SIZE := 16
const VARIANTS := 4

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

const COLORS: Array[Color] = [
	Color("10141d"),
	Color("1d2a38"),
	Color("3a3229"),
	Color("5b554e"),
	Color("4b4f33"),
	Color("26382a"),
	Color("2c3327"),
	Color("24232b"),
]

## Tiles the player cannot walk through.
const SOLID: Array[bool] = [true, false, false, false, false, false, false, true]


static func display_name(type: Type) -> String:
	return NAMES[type]


static func is_solid(type: Type) -> bool:
	return SOLID[type]


static func build_atlas_image() -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7411
	var image := Image.create(
		VARIANTS * TILE_SIZE, Type.size() * TILE_SIZE, false, Image.FORMAT_RGBA8
	)
	for type in Type.size():
		var base: Color = COLORS[type]
		for variant in VARIANTS:
			for y in TILE_SIZE:
				for x in TILE_SIZE:
					var shade := rng.randf_range(-0.035, 0.035)
					# A few stronger flecks give each variant its own grain.
					if rng.randf() < 0.06:
						shade += rng.randf_range(-0.09, 0.09)
					var color := Color(
						clampf(base.r + shade, 0.0, 1.0),
						clampf(base.g + shade, 0.0, 1.0),
						clampf(base.b + shade, 0.0, 1.0)
					)
					image.set_pixel(variant * TILE_SIZE + x, type * TILE_SIZE + y, color)
	return image


static func build_tileset() -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(0, 1)
	tile_set.set_physics_layer_collision_mask(0, 0)

	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(build_atlas_image())
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
