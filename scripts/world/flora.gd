class_name Flora
extends RefCounted
## What grows where: trees, bushes, ground cover, and wildlife for each kind
## of terrain, and the sprite sheets they come from (tools/generate_flora.py).

const T := TerrainTiles.Type
const TALL: Texture2D = preload("res://assets/sprites/flora_tall.png")
const SMALL: Texture2D = preload("res://assets/sprites/flora_small.png")
const TALL_SIZE := Vector2(64, 96)
const SMALL_SIZE := Vector2(32, 32)
## Tall sheet indices.
enum Tall { OAK, OAK_2, DEAD, PINE, SNOW_PINE, THORN, CRIMSON, MUSHROOM, BONE, CHARRED, CRYSTAL, SALT, WILLOW, CACTUS,
	BUSH, BERRY_BUSH, SNOW_BUSH, THORN_BUSH, DRY_SHRUB, FUNGAL_BUSH }
## Trees that give wood when chopped; the rest are scenery.
const WOODEN: Array[int] = [Tall.OAK, Tall.OAK_2, Tall.DEAD, Tall.PINE, Tall.SNOW_PINE, Tall.THORN, Tall.CRIMSON, Tall.CHARRED, Tall.WILLOW]

## Per terrain:
##   "trees"   tall sheet indices for trees, picked at random
##   "bushes"  tall sheet indices for bushes
##   "ground"  small sheet indices for ground cover
##   "forest"  how thick woods grow where the forest noise allows (0 = never)
##   "cover"   how much ground cover per tile
##   "critters" kinds of wildlife (see Critter)
const BIOMES := {
	T.DEAD_GRASS: {"decals": [42, 46, 51, 45], "trees": [Tall.OAK, Tall.OAK_2, Tall.DEAD], "bushes": [Tall.BUSH, Tall.BERRY_BUSH, Tall.DRY_SHRUB], "ground": [0, 4, 6, 7, 9, 9, 13, 34, 35, 40], "forest": 0.32, "cover": 0.55, "critters": ["rabbit", "bird", "butterfly"]},
	T.DARK_GRASS: {"decals": [44, 45, 45, 50, 43], "trees": [Tall.OAK, Tall.OAK_2, Tall.OAK], "bushes": [Tall.BUSH, Tall.BERRY_BUSH, Tall.BUSH], "ground": [0, 1, 2, 3, 6, 7, 8, 11, 31, 32, 33, 35, 36], "forest": 0.55, "cover": 0.7, "critters": ["rabbit", "bird", "butterfly"]},
	T.BOG: {"decals": [43, 43, 50, 44], "trees": [Tall.WILLOW, Tall.DEAD], "bushes": [Tall.BUSH], "ground": [8, 8, 11, 6, 2, 39, 39], "forest": 0.3, "cover": 0.55, "critters": ["frog", "bird"]},
	T.MUD: {"decals": [43, 51, 42, 46], "trees": [Tall.DEAD], "bushes": [Tall.DRY_SHRUB], "ground": [13, 9, 8], "forest": 0.08, "cover": 0.3, "critters": ["frog"]},
	T.ASH: {"decals": [49, 49, 42, 46], "trees": [Tall.CHARRED, Tall.DEAD], "bushes": [Tall.DRY_SHRUB], "ground": [13, 13, 17, 9, 14], "forest": 0.12, "cover": 0.3, "critters": []},
	T.SNOW: {"decals": [48, 48, 51, 46], "trees": [Tall.SNOW_PINE], "bushes": [Tall.SNOW_BUSH], "ground": [10, 10, 13, 24, 37], "forest": 0.2, "cover": 0.3, "critters": ["rabbit"]},
	T.FROSTPINE: {"decals": [48, 45, 44], "trees": [Tall.SNOW_PINE, Tall.PINE], "bushes": [Tall.SNOW_BUSH], "ground": [10, 6, 13, 24, 37, 36], "forest": 0.6, "cover": 0.45, "critters": ["rabbit", "bird"]},
	T.SALT: {"decals": [42, 42, 46], "trees": [Tall.SALT], "bushes": [Tall.DRY_SHRUB], "ground": [16, 16, 13, 30], "forest": 0.06, "cover": 0.35, "critters": []},
	T.THORN: {"decals": [44, 42, 45], "trees": [Tall.THORN, Tall.DEAD], "bushes": [Tall.THORN_BUSH, Tall.THORN_BUSH], "ground": [18, 18, 9, 4, 5, 32], "forest": 0.38, "cover": 0.55, "critters": ["bird", "butterfly"]},
	T.CRIMSON: {"decals": [42, 44, 49], "trees": [Tall.CRIMSON], "bushes": [Tall.BUSH, Tall.THORN_BUSH], "ground": [19, 19, 5, 25, 1, 38, 35], "forest": 0.4, "cover": 0.6, "critters": ["bird"]},
	T.FUNGAL: {"decals": [50, 43, 44], "trees": [Tall.MUSHROOM], "bushes": [Tall.FUNGAL_BUSH], "ground": [11, 12, 12, 26, 3, 33], "forest": 0.45, "cover": 0.65, "critters": ["frog"]},
	T.TAR: {"decals": [43, 49, 42], "trees": [Tall.DEAD, Tall.CHARRED], "bushes": [Tall.DRY_SHRUB], "ground": [13, 17, 8], "forest": 0.1, "cover": 0.25, "critters": []},
	T.SAND: {"decals": [47, 47, 46, 51], "trees": [Tall.CACTUS, Tall.BONE], "bushes": [Tall.DRY_SHRUB], "ground": [9, 13, 17, 27, 40], "forest": 0.05, "cover": 0.25, "critters": ["rabbit"]},
	T.CINDER: {"decals": [49, 42, 46], "trees": [Tall.CHARRED], "bushes": [Tall.DRY_SHRUB], "ground": [14, 14, 13, 28, 41], "forest": 0.1, "cover": 0.35, "critters": []},
	T.VOIDSCAR: {"decals": [42, 49], "trees": [Tall.CRYSTAL], "bushes": [], "ground": [15, 15, 29, 13, 38], "forest": 0.12, "cover": 0.4, "critters": []},
	T.ROCK: {"decals": [46, 46, 42, 50], "trees": [Tall.PINE], "bushes": [Tall.DRY_SHRUB], "ground": [13, 13, 6, 36, 33], "forest": 0.18, "cover": 0.3, "critters": ["bird"]},
	T.PEAK: {"decals": [48, 46, 42], "trees": [Tall.SNOW_PINE], "bushes": [], "ground": [13, 10], "forest": 0.06, "cover": 0.25, "critters": []},
	T.SHALLOW_WATER: {"trees": [], "bushes": [], "ground": [8], "forest": 0.0, "cover": 0.06, "critters": []},
}


static func tall_region(index: int) -> Rect2:
	return Rect2(Vector2(index * TALL_SIZE.x, 0), TALL_SIZE)


static func small_region(index: int) -> Rect2:
	return Rect2(Vector2(index * SMALL_SIZE.x, 0), SMALL_SIZE)


## A small sheet picture as a texture of its own (item icons use these).
static func small_texture(index: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = SMALL
	atlas.region = small_region(index)
	return atlas


## The tree that grows on a tile, for a choppable tree's look.
static func tree_for(tile: int, random: RandomNumberGenerator) -> int:
	var options: Array = BIOMES.get(tile, BIOMES[T.DEAD_GRASS])["trees"]
	var wooden := options.filter(func(index: int) -> bool: return index in WOODEN)
	return wooden[random.randi_range(0, wooden.size() - 1)] if not wooden.is_empty() else Tall.OAK
