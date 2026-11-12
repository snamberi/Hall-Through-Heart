class_name MinibossDB
extends RefCounted
## Named minibosses: old, notorious monsters that roam their own lands. Now
## and then one turns up in the wild where its land meets its level. Each
## is a Mini-boss of its kind with its own name and look, and it leaves
## better treasure than any common beast.
##
##   "monster"   the kind it is      "tiles" where it roams
##   "min_level" the area level it needs        "tint", "size" its look

const T := TerrainTiles.Type
const NAMED := {
	"grimtooth": {"name": "Grimtooth, Pack Leader", "monster": "rot_hound", "tint": Color(1.0, 0.7, 0.62), "size": 1.15, "tiles": [T.DEAD_GRASS, T.MUD, T.DARK_GRASS], "min_level": 3},
	"gorehide": {"name": "Gorehide the Tusked", "monster": "dire_boar", "tint": Color(0.95, 0.72, 0.6), "size": 1.2, "tiles": [T.DEAD_GRASS, T.DARK_GRASS, T.THORN], "min_level": 4},
	"gloomwing": {"name": "Gloomwing", "monster": "carrion_bat", "tint": Color(0.8, 0.7, 1.0), "size": 1.3, "tiles": [T.DARK_GRASS, T.CRIMSON, T.FUNGAL], "min_level": 5},
	"mother_mycel": {"name": "Mother Mycel", "monster": "spore_shambler", "tint": Color(1.0, 0.8, 1.0), "size": 1.2, "tiles": [T.FUNGAL, T.BOG], "min_level": 6},
	"hollow_archer": {"name": "The Hollow Archer", "monster": "bone_archer", "tint": Color(0.85, 0.9, 1.0), "size": 1.15, "tiles": [T.ASH, T.DEAD_GRASS, T.SALT], "min_level": 7},
	"old_frostjaw": {"name": "Old Frostjaw", "monster": "frost_wolf", "tint": Color(0.85, 0.95, 1.15), "size": 1.2, "tiles": [T.SNOW, T.FROSTPINE, T.PEAK], "min_level": 8},
	"thornback": {"name": "Thornback", "monster": "thorn_stalker", "tint": Color(1.0, 0.85, 0.7), "size": 1.2, "tiles": [T.THORN, T.CRIMSON], "min_level": 8},
	"the_drowned_one": {"name": "The Drowned One", "monster": "bog_lurker", "tint": Color(0.7, 0.95, 0.9), "size": 1.15, "tiles": [T.BOG, T.TAR, T.MUD], "min_level": 9},
	"sandreaver": {"name": "Sandreaver", "monster": "sand_scorpion", "tint": Color(1.1, 0.85, 0.6), "size": 1.2, "tiles": [T.SAND, T.SALT], "min_level": 10},
	"bonecaller_veth": {"name": "Bonecaller Veth", "monster": "rot_cultist", "tint": Color(1.0, 0.75, 0.75), "size": 1.15, "tiles": [T.CRIMSON, T.THORN, T.ASH], "min_level": 11},
	"ashen_widow": {"name": "The Ashen Widow", "monster": "ash_wraith", "tint": Color(1.0, 0.85, 0.8), "size": 1.2, "tiles": [T.ASH, T.VOIDSCAR, T.CINDER], "min_level": 12},
	"magmaw": {"name": "Magmaw", "monster": "magma_slime", "tint": Color(1.1, 0.8, 0.65), "size": 1.25, "tiles": [T.CINDER, T.TAR], "min_level": 14},
	"stonefather": {"name": "The Stonefather", "monster": "crag_golem", "tint": Color(0.9, 0.9, 1.0), "size": 1.15, "tiles": [T.ROCK, T.PEAK, T.ASH], "min_level": 15},
	"the_unseen": {"name": "The Unseen", "monster": "void_stalker", "tint": Color(0.9, 0.75, 1.1), "size": 1.15, "tiles": [T.VOIDSCAR], "min_level": 16},
	"ironbark": {"name": "Ironbark", "monster": "treant", "tint": Color(0.85, 0.9, 0.75), "size": 1.1, "tiles": [T.DARK_GRASS, T.FUNGAL, T.FROSTPINE], "min_level": 18},
}
## Chance each spawn is a named miniboss, when one fits and none is about.
const CHANCE := 0.006


## A named miniboss that could roam here, or "".
static func pick(tile: int, area_level: int) -> String:
	var options: Array[String] = []
	for id: String in NAMED:
		if tile in NAMED[id]["tiles"] and area_level >= int(NAMED[id]["min_level"]):
			options.append(id)
	return "" if options.is_empty() else options[randi() % options.size()]


## What one leaves on top of a Mini-boss's usual drops: a piece of Rare or
## better gear, gold, and heart shards.
static func drops(level: int) -> Array[Item]:
	var items: Array[Item] = [LootGenerator.make_equipment(level, maxi(LootGenerator.roll_rarity(0.0, 6.0), 2))]
	items.append(Item.create("heart_shard", 1))
	if randf() < 0.5:
		items.append(Item.create(Gems.random_gem(level + 10)))
	return items
