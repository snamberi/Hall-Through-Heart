class_name RecipeDB
extends RefCounted
## Every crafting recipe. Most are generated from the metal tiers, so adding
## a tier or a craftable base adds its recipes automatically.
##
## A recipe: {"id", "name", "profession", "level", "inputs": {item: count},
##   "xp", and either "item"/"count" or "equipment"/"item_level"}.

## Equipment a smith can forge: base id -> [ingots, wood].
const FORGEABLE := {
	"sword": [3, 0], "katana": [3, 0], "dagger": [2, 0], "axe": [3, 1], "greatsword": [5, 0],
	"spear": [2, 2], "halberd": [4, 2], "bow": [1, 3], "staff": [1, 3],
	"shield": [3, 1], "helmet": [2, 0], "chestplate": [5, 0], "greaves": [4, 0], "boots": [2, 0],
}
## Wood used alongside each tier's metal.
const TIER_WOOD := {1: "oak_wood", 10: "oak_wood", 20: "pine_wood", 30: "pine_wood", 40: "ancient_wood",
	50: "ancient_wood", 65: "ancient_wood", 80: "spiritwood", 100: "spiritwood"}
## Ore smelted into each ingot.
const ORES := {"copper_ingot": "copper_ore", "iron_ingot": "iron_ore", "silver_ingot": "silver_ore",
	"gold_ingot": "gold_ore", "mithril_ingot": "mithril_ore", "obsidian_ingot": "obsidian_ore",
	"adamantite_ingot": "adamantite_ore", "void_ingot": "void_crystal", "heartstone_ingot": "heartstone"}
## Tools above the worn starting set: [id prefix, smithing level, ingot, wood].
const TOOL_TIERS: Array[Array] = [
	["bronze", 5, "bronze_ingot", "oak_wood"], ["iron", 10, "iron_ingot", "oak_wood"],
	["mithril", 40, "mithril_ingot", "ancient_wood"], ["adamantite", 65, "adamantite_ingot", "ancient_wood"],
]
## Recipes that can be made with bare hands, away from a crafting table.
const NO_TABLE: Array[String] = ["crafting_table", "bandage", "torch", "wooden_club"]
const HAND_WRITTEN: Array[Dictionary] = [
	{"id": "crafting_table", "profession": "building", "level": 1, "inputs": {"oak_wood": 6, "stone": 4}, "item": "crafting_table", "count": 1, "xp": 20.0},
	{"id": "bandage", "profession": "alchemy", "level": 1, "inputs": {"healing_herb": 1, "husk_fragment": 1}, "item": "bandage", "count": 2, "xp": 6.0},
	{"id": "torch", "profession": "building", "level": 1, "inputs": {"oak_wood": 1}, "item": "torch", "count": 3, "xp": 3.0},
	{"id": "wooden_club", "profession": "blacksmithing", "level": 1, "inputs": {"oak_wood": 4}, "equipment": "club", "item_level": 1, "xp": 8.0},
	{"id": "berry_tart", "profession": "cooking", "level": 5, "inputs": {"wild_berries": 3, "healing_herb": 1}, "item": "berry_tart", "count": 1, "xp": 16.0},
	{"id": "frost_tea", "profession": "cooking", "level": 15, "inputs": {"frost_lily": 2}, "item": "frost_tea", "count": 1, "xp": 28.0},
	{"id": "thornberry_jam", "profession": "cooking", "level": 12, "inputs": {"thornberries": 3}, "item": "thornberry_jam", "count": 1, "xp": 24.0},
	{"id": "glowshroom_soup", "profession": "cooking", "level": 20, "inputs": {"glowshroom": 2, "minnow": 1}, "item": "glowshroom_soup", "count": 1, "xp": 34.0},
	{"id": "ember_stew", "profession": "cooking", "level": 30, "inputs": {"emberbloom": 1, "trout": 1, "saltweed": 1}, "item": "ember_stew", "count": 1, "xp": 52.0},
	{"id": "aloe_salve", "profession": "alchemy", "level": 12, "inputs": {"desert_aloe": 2}, "item": "aloe_salve", "count": 1, "xp": 22.0},
	{"id": "bloodcap_draught", "profession": "alchemy", "level": 25, "inputs": {"bloodcap": 2, "venom_sac": 1}, "item": "bloodcap_draught", "count": 1, "xp": 44.0},
	{"id": "void_tonic", "profession": "alchemy", "level": 40, "inputs": {"void_bloom": 1, "essence": 1}, "item": "void_tonic", "count": 1, "xp": 70.0},
	{"id": "storage_chest", "profession": "building", "level": 1, "inputs": {"oak_wood": 8, "copper_ingot": 1}, "item": "storage_chest", "count": 1, "xp": 25.0},
	{"id": "bed", "profession": "building", "level": 1, "inputs": {"oak_wood": 10, "husk_fragment": 6}, "item": "bed", "count": 1, "xp": 30.0},
	{"id": "house_kit", "profession": "building", "level": 2, "inputs": {"oak_wood": 30, "stone": 20, "copper_ingot": 4}, "item": "house_kit", "count": 1, "xp": 120.0},
	{"id": "bronze_ingot", "profession": "blacksmithing", "level": 5, "inputs": {"copper_ore": 2, "tin_ore": 1}, "item": "bronze_ingot", "count": 1, "xp": 14.0},
	{"id": "health_potion", "profession": "alchemy", "level": 1, "inputs": {"healing_herb": 2}, "item": "health_potion", "count": 1, "xp": 10.0},
	{"id": "stamina_tonic", "profession": "alchemy", "level": 5, "inputs": {"healing_herb": 1, "poison_mushroom": 1}, "item": "stamina_tonic", "count": 1, "xp": 16.0},
	{"id": "mana_potion", "profession": "alchemy", "level": 10, "inputs": {"mana_flower": 2}, "item": "mana_potion", "count": 1, "xp": 22.0},
	{"id": "might_elixir", "profession": "alchemy", "level": 20, "inputs": {"claw": 1, "rare_root": 1, "healing_herb": 1}, "item": "might_elixir", "count": 1, "xp": 40.0},
	{"id": "grilled_minnow", "profession": "cooking", "level": 1, "inputs": {"minnow": 1}, "item": "grilled_minnow", "count": 1, "xp": 10.0},
	{"id": "trout_stew", "profession": "cooking", "level": 10, "inputs": {"trout": 1, "healing_herb": 1}, "item": "trout_stew", "count": 1, "xp": 24.0},
	{"id": "eel_pie", "profession": "cooking", "level": 25, "inputs": {"eel": 1, "rare_root": 1}, "item": "eel_pie", "count": 1, "xp": 48.0},
	{"id": "enchanted_dust", "profession": "enchanting", "level": 1, "inputs": {"essence": 1}, "item": "enchanted_dust", "count": 2, "xp": 12.0},
]

static var _recipes: Array[Dictionary] = []


static func all() -> Array[Dictionary]:
	if _recipes.is_empty():
		_build()
	return _recipes


static func for_profession(profession: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for recipe in all():
		if recipe["profession"] == profession:
			result.append(recipe)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["level"] < b["level"])
	return result


static func find(id: String) -> Dictionary:
	for recipe in all():
		if recipe["id"] == id:
			return recipe
	return {}


## Name shown for a recipe: what it makes.
static func display_name(recipe: Dictionary) -> String:
	if recipe.has("equipment"):
		return "%s %s" % [ItemDB.tier_name(recipe["item_level"]), ItemDB.ITEMS[recipe["equipment"]]["name"]]
	var name: String = ItemDB.ITEMS[recipe["item"]]["name"]
	return name if recipe["count"] == 1 else "%s x%d" % [name, recipe["count"]]


static func _build() -> void:
	for recipe in HAND_WRITTEN:
		_recipes.append(recipe)
	for tier_level: int in ItemDB.TIER_INGOTS:
		var ingot: String = ItemDB.TIER_INGOTS[tier_level]
		var inputs := {ORES[ingot]: 3}
		if tier_level >= 10:
			inputs["stone"] = 1
		_recipes.append({"id": ingot, "profession": "blacksmithing", "level": tier_level, "inputs": inputs,
			"item": ingot, "count": 1, "xp": 10.0 + tier_level * 1.5})
		for base: String in FORGEABLE:
			var cost: Array = FORGEABLE[base]
			var gear_inputs := {ingot: cost[0]}
			if cost[1] > 0:
				gear_inputs[TIER_WOOD[tier_level]] = cost[1]
			_recipes.append({"id": "%s_%d" % [base, tier_level], "profession": "blacksmithing", "level": tier_level,
				"inputs": gear_inputs, "equipment": base, "item_level": tier_level, "xp": (20.0 + tier_level * 3.0) * cost[0] / 3.0})
	for tool: Array in TOOL_TIERS:
		for kind: String in ["pickaxe", "hatchet"]:
			var id := "%s_%s" % [tool[0], kind]
			_recipes.append({"id": id, "profession": "blacksmithing", "level": tool[1],
				"inputs": {tool[2]: 3, tool[3]: 2, "stone": 1}, "item": id, "count": 1, "xp": 30.0 + tool[1] * 3.0})
