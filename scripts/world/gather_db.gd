class_name GatherDB
extends RefCounted
## Everything that can be gathered from the world. Ids are stable.
##
##   "kind"     ore, tree, herb, or fish (decides the look and the tool)
##   "item"     what it yields          "level"  profession level needed
##   "tier"     tool tier needed        "tiles"  terrain it grows on
## Better resources appear where the area level is at least their "level"
## times AREA_FACTOR, so tougher country holds richer materials.

const AREA_FACTOR := 0.6
const KINDS := {
	"ore": {"profession": "mining", "tool": "pickaxe", "verb": "Mine", "seconds": 2.4, "frame": 0},
	"tree": {"profession": "woodcutting", "tool": "hatchet", "verb": "Chop", "seconds": 2.2, "frame": 2},
	"herb": {"profession": "herbalism", "tool": "", "verb": "Pick", "seconds": 0.9, "frame": 3},
	"fish": {"profession": "fishing", "tool": "rod", "verb": "Fish", "seconds": 3.2, "frame": 4},
}
const T := TerrainTiles.Type
const ROCKY: Array[int] = [T.ASH, T.MUD, T.DEAD_GRASS]
const WOODED: Array[int] = [T.DARK_GRASS, T.DEAD_GRASS]

const RESOURCES := {
	"stone": {"kind": "ore", "item": "stone", "level": 1, "tier": 1, "tiles": ROCKY},
	"copper": {"kind": "ore", "item": "copper_ore", "level": 1, "tier": 1, "tiles": ROCKY},
	"tin": {"kind": "ore", "item": "tin_ore", "level": 5, "tier": 1, "tiles": ROCKY},
	"iron": {"kind": "ore", "item": "iron_ore", "level": 10, "tier": 2, "tiles": ROCKY},
	"silver": {"kind": "ore", "item": "silver_ore", "level": 20, "tier": 2, "tiles": ROCKY},
	"gold": {"kind": "ore", "item": "gold_ore", "level": 30, "tier": 3, "tiles": ROCKY},
	"mithril": {"kind": "ore", "item": "mithril_ore", "level": 40, "tier": 3, "tiles": ROCKY},
	"obsidian": {"kind": "ore", "item": "obsidian_ore", "level": 50, "tier": 4, "tiles": ROCKY},
	"adamantite": {"kind": "ore", "item": "adamantite_ore", "level": 65, "tier": 4, "tiles": ROCKY},
	"void_crystal": {"kind": "ore", "item": "void_crystal", "level": 80, "tier": 5, "tiles": ROCKY},
	"heartstone": {"kind": "ore", "item": "heartstone", "level": 100, "tier": 5, "tiles": ROCKY},
	"oak": {"kind": "tree", "item": "oak_wood", "level": 1, "tier": 1, "tiles": WOODED},
	"pine": {"kind": "tree", "item": "pine_wood", "level": 10, "tier": 1, "tiles": WOODED},
	"ancient_tree": {"kind": "tree", "item": "ancient_wood", "level": 30, "tier": 3, "tiles": WOODED},
	"spirit_tree": {"kind": "tree", "item": "spiritwood", "level": 60, "tier": 4, "tiles": WOODED},
	"healing_herb": {"kind": "herb", "item": "healing_herb", "level": 1, "tier": 0, "tiles": [T.DARK_GRASS, T.DEAD_GRASS, T.BOG]},
	"poison_mushroom": {"kind": "herb", "item": "poison_mushroom", "level": 5, "tier": 0, "tiles": [T.BOG, T.DARK_GRASS]},
	"mana_flower": {"kind": "herb", "item": "mana_flower", "level": 10, "tier": 0, "tiles": [T.DARK_GRASS, T.ASH]},
	"rare_root": {"kind": "herb", "item": "rare_root", "level": 30, "tier": 0, "tiles": [T.BOG, T.MUD]},
	"fishing_spot": {"kind": "fish", "item": "minnow", "level": 1, "tier": 1, "tiles": [T.SHALLOW_WATER]},
}
## What a fishing spot can give: [item, fishing level needed, weight].
const FISH: Array[Array] = [["minnow", 1, 10.0], ["trout", 10, 6.0], ["eel", 25, 3.0]]
## Chance a catch is treasure instead of a fish.
const TREASURE_CHANCE := 0.05
## How many resources each kind tries to place per chunk.
const PER_CHUNK := {"ore": 2, "tree": 3, "herb": 3, "fish": 1}


static func display_name(id: String) -> String:
	if RESOURCES[id]["kind"] == "fish":
		return "Fishing Spot"
	var name: String = ItemDB.ITEMS[RESOURCES[id]["item"]]["name"]
	return name.trim_suffix(" Ore").trim_suffix(" Wood") + (" Tree" if RESOURCES[id]["kind"] == "tree" else " Vein" if RESOURCES[id]["kind"] == "ore" and id != "stone" else "")


static func color(id: String) -> Color:
	return ItemDB.ITEMS[RESOURCES[id]["item"]].get("tint", Color.WHITE)


## Picks a resource of a kind for a tile, or "" if none grows there.
static func pick(kind: String, tile: int, area_level: int, random: RandomNumberGenerator) -> String:
	var options: Array[String] = []
	for id: String in RESOURCES:
		var data: Dictionary = RESOURCES[id]
		if data["kind"] == kind and tile in data["tiles"] and area_level >= floori(data["level"] * AREA_FACTOR):
			options.append(id)
	if options.is_empty():
		return ""
	options.sort_custom(func(a: String, b: String) -> bool: return RESOURCES[a]["level"] > RESOURCES[b]["level"])
	# Favour the richest few that this area supports.
	options = options.slice(0, 3)
	return options[mini(int(random.randf() * random.randf() * options.size() * 1.6), options.size() - 1)]
