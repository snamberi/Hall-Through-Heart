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
	{"id": "sweet_roll", "profession": "cooking", "level": 6, "inputs": {"wheat": 2, "wild_berries": 1}, "item": "sweet_roll", "count": 1, "xp": 14.0},
	{"id": "hunters_brew", "profession": "cooking", "level": 8, "inputs": {"wild_berries": 2, "wheat": 1}, "item": "hunters_brew", "count": 1, "xp": 16.0},
	{"id": "swiftfoot_tea", "profession": "cooking", "level": 14, "inputs": {"mana_flower": 1, "frost_lily": 1}, "item": "swiftfoot_tea", "count": 1, "xp": 26.0},
	{"id": "candied_frostberries", "profession": "cooking", "level": 16, "inputs": {"frostberry": 3, "wheat": 1}, "item": "candied_frostberries", "count": 1, "xp": 28.0},
	{"id": "ironbark_tonic", "profession": "cooking", "level": 18, "inputs": {"rare_root": 1, "healing_herb": 2}, "item": "ironbark_tonic", "count": 1, "xp": 32.0},
	{"id": "pumpkin_bread", "profession": "cooking", "level": 20, "inputs": {"pumpkin": 1, "wheat": 2}, "item": "pumpkin_bread", "count": 2, "xp": 34.0},
	{"id": "sages_infusion", "profession": "cooking", "level": 22, "inputs": {"mana_flower": 2, "glowshroom": 1}, "item": "sages_infusion", "count": 1, "xp": 38.0},
	{"id": "ember_ale", "profession": "cooking", "level": 28, "inputs": {"emberbloom": 1, "wheat": 2}, "item": "ember_ale", "count": 1, "xp": 48.0},
	{"id": "sunroot_cordial", "profession": "cooking", "level": 35, "inputs": {"sunroot": 1, "wild_berries": 2}, "item": "sunroot_cordial", "count": 1, "xp": 60.0},
	{"id": "aloe_salve", "profession": "alchemy", "level": 12, "inputs": {"desert_aloe": 2}, "item": "aloe_salve", "count": 1, "xp": 22.0},
	{"id": "bloodcap_draught", "profession": "alchemy", "level": 25, "inputs": {"bloodcap": 2, "venom_sac": 1}, "item": "bloodcap_draught", "count": 1, "xp": 44.0},
	{"id": "void_tonic", "profession": "alchemy", "level": 40, "inputs": {"void_bloom": 1, "essence": 1}, "item": "void_tonic", "count": 1, "xp": 70.0},
	{"id": "rug", "profession": "building", "level": 1, "inputs": {"husk_fragment": 4, "healing_herb": 2}, "item": "rug", "count": 1, "xp": 10.0},
	{"id": "bookshelf", "profession": "building", "level": 2, "inputs": {"oak_wood": 8}, "item": "bookshelf", "count": 1, "xp": 14.0},
	{"id": "potted_plant", "profession": "building", "level": 1, "inputs": {"stone": 2, "healing_herb": 1}, "item": "potted_plant", "count": 1, "xp": 10.0},
	{"id": "dining_table", "profession": "building", "level": 1, "inputs": {"oak_wood": 6}, "item": "dining_table", "count": 1, "xp": 10.0},
	{"id": "chair", "profession": "building", "level": 1, "inputs": {"oak_wood": 3}, "item": "chair", "count": 1, "xp": 10.0},
	{"id": "candles", "profession": "building", "level": 1, "inputs": {"oak_wood": 1, "husk_fragment": 1}, "item": "candles", "count": 1, "xp": 10.0},
	{"id": "wall_banner", "profession": "building", "level": 2, "inputs": {"oak_wood": 2, "husk_fragment": 3}, "item": "wall_banner", "count": 1, "xp": 14.0},
	{"id": "barrel", "profession": "building", "level": 1, "inputs": {"oak_wood": 5}, "item": "barrel", "count": 1, "xp": 10.0},
	{"id": "crate", "profession": "building", "level": 1, "inputs": {"oak_wood": 4}, "item": "crate", "count": 1, "xp": 10.0},
	{"id": "stone_statue", "profession": "building", "level": 4, "inputs": {"stone": 20}, "item": "stone_statue", "count": 1, "xp": 22.0},
	{"id": "brazier", "profession": "building", "level": 4, "inputs": {"iron_ingot": 3, "stone": 4}, "item": "brazier", "count": 1, "xp": 22.0},
	{"id": "fence", "profession": "building", "level": 1, "inputs": {"oak_wood": 2}, "item": "fence", "count": 1, "xp": 10.0},
	{"id": "lantern_post", "profession": "building", "level": 2, "inputs": {"oak_wood": 3, "copper_ingot": 1}, "item": "lantern_post", "count": 1, "xp": 14.0},
	{"id": "floor_plank", "profession": "building", "level": 1, "inputs": {"oak_wood": 1}, "item": "floor_plank", "count": 4, "xp": 2.0},
	{"id": "floor_stone", "profession": "building", "level": 1, "inputs": {"stone": 2}, "item": "floor_stone", "count": 4, "xp": 2.0},
	{"id": "floor_cobble", "profession": "building", "level": 1, "inputs": {"stone": 1}, "item": "floor_cobble", "count": 4, "xp": 2.0},
	{"id": "floor_moss", "profession": "building", "level": 1, "inputs": {"stone": 1, "healing_herb": 1}, "item": "floor_moss", "count": 4, "xp": 2.0},
	{"id": "floor_sand", "profession": "building", "level": 1, "inputs": {"stone": 2}, "item": "floor_sand", "count": 4, "xp": 2.0},
	{"id": "floor_snow", "profession": "building", "level": 1, "inputs": {"stone": 2}, "item": "floor_snow", "count": 4, "xp": 2.0},
	{"id": "ruby_2", "profession": "blacksmithing", "level": 5, "inputs": {"ruby_1": 3}, "item": "ruby_2", "count": 1, "xp": 24.0},
	{"id": "ruby_3", "profession": "blacksmithing", "level": 15, "inputs": {"ruby_2": 3}, "item": "ruby_3", "count": 1, "xp": 54.0},
	{"id": "ruby_4", "profession": "blacksmithing", "level": 30, "inputs": {"ruby_3": 3}, "item": "ruby_4", "count": 1, "xp": 96.0},
	{"id": "ruby_5", "profession": "blacksmithing", "level": 45, "inputs": {"ruby_4": 3}, "item": "ruby_5", "count": 1, "xp": 150.0},
	{"id": "sapphire_2", "profession": "blacksmithing", "level": 5, "inputs": {"sapphire_1": 3}, "item": "sapphire_2", "count": 1, "xp": 24.0},
	{"id": "sapphire_3", "profession": "blacksmithing", "level": 15, "inputs": {"sapphire_2": 3}, "item": "sapphire_3", "count": 1, "xp": 54.0},
	{"id": "sapphire_4", "profession": "blacksmithing", "level": 30, "inputs": {"sapphire_3": 3}, "item": "sapphire_4", "count": 1, "xp": 96.0},
	{"id": "sapphire_5", "profession": "blacksmithing", "level": 45, "inputs": {"sapphire_4": 3}, "item": "sapphire_5", "count": 1, "xp": 150.0},
	{"id": "emerald_2", "profession": "blacksmithing", "level": 5, "inputs": {"emerald_1": 3}, "item": "emerald_2", "count": 1, "xp": 24.0},
	{"id": "emerald_3", "profession": "blacksmithing", "level": 15, "inputs": {"emerald_2": 3}, "item": "emerald_3", "count": 1, "xp": 54.0},
	{"id": "emerald_4", "profession": "blacksmithing", "level": 30, "inputs": {"emerald_3": 3}, "item": "emerald_4", "count": 1, "xp": 96.0},
	{"id": "emerald_5", "profession": "blacksmithing", "level": 45, "inputs": {"emerald_4": 3}, "item": "emerald_5", "count": 1, "xp": 150.0},
	{"id": "topaz_2", "profession": "blacksmithing", "level": 5, "inputs": {"topaz_1": 3}, "item": "topaz_2", "count": 1, "xp": 24.0},
	{"id": "topaz_3", "profession": "blacksmithing", "level": 15, "inputs": {"topaz_2": 3}, "item": "topaz_3", "count": 1, "xp": 54.0},
	{"id": "topaz_4", "profession": "blacksmithing", "level": 30, "inputs": {"topaz_3": 3}, "item": "topaz_4", "count": 1, "xp": 96.0},
	{"id": "topaz_5", "profession": "blacksmithing", "level": 45, "inputs": {"topaz_4": 3}, "item": "topaz_5", "count": 1, "xp": 150.0},
	{"id": "amethyst_2", "profession": "blacksmithing", "level": 5, "inputs": {"amethyst_1": 3}, "item": "amethyst_2", "count": 1, "xp": 24.0},
	{"id": "amethyst_3", "profession": "blacksmithing", "level": 15, "inputs": {"amethyst_2": 3}, "item": "amethyst_3", "count": 1, "xp": 54.0},
	{"id": "amethyst_4", "profession": "blacksmithing", "level": 30, "inputs": {"amethyst_3": 3}, "item": "amethyst_4", "count": 1, "xp": 96.0},
	{"id": "amethyst_5", "profession": "blacksmithing", "level": 45, "inputs": {"amethyst_4": 3}, "item": "amethyst_5", "count": 1, "xp": 150.0},
	{"id": "diamond_2", "profession": "blacksmithing", "level": 5, "inputs": {"diamond_1": 3}, "item": "diamond_2", "count": 1, "xp": 24.0},
	{"id": "diamond_3", "profession": "blacksmithing", "level": 15, "inputs": {"diamond_2": 3}, "item": "diamond_3", "count": 1, "xp": 54.0},
	{"id": "diamond_4", "profession": "blacksmithing", "level": 30, "inputs": {"diamond_3": 3}, "item": "diamond_4", "count": 1, "xp": 96.0},
	{"id": "diamond_5", "profession": "blacksmithing", "level": 45, "inputs": {"diamond_4": 3}, "item": "diamond_5", "count": 1, "xp": 150.0},
	{"id": "garnet_2", "profession": "blacksmithing", "level": 5, "inputs": {"garnet_1": 3}, "item": "garnet_2", "count": 1, "xp": 24.0},
	{"id": "garnet_3", "profession": "blacksmithing", "level": 15, "inputs": {"garnet_2": 3}, "item": "garnet_3", "count": 1, "xp": 54.0},
	{"id": "garnet_4", "profession": "blacksmithing", "level": 30, "inputs": {"garnet_3": 3}, "item": "garnet_4", "count": 1, "xp": 96.0},
	{"id": "garnet_5", "profession": "blacksmithing", "level": 45, "inputs": {"garnet_4": 3}, "item": "garnet_5", "count": 1, "xp": 150.0},
	{"id": "rowboat", "profession": "building", "level": 3, "inputs": {"oak_wood": 25, "copper_ingot": 2, "hound_pelt": 2}, "item": "rowboat", "count": 1, "xp": 60.0},
	{"id": "farm_plot", "profession": "building", "level": 1, "inputs": {"oak_wood": 2, "stone": 2}, "item": "farm_plot", "count": 1, "xp": 6.0},
	{"id": "scarecrow", "profession": "building", "level": 2, "inputs": {"oak_wood": 4, "wheat": 3}, "item": "scarecrow", "count": 1, "xp": 12.0},
	{"id": "palisade_wall", "profession": "building", "level": 2, "inputs": {"oak_wood": 6}, "item": "palisade_wall", "count": 2, "xp": 8.0},
	{"id": "spike_trap", "profession": "building", "level": 3, "inputs": {"oak_wood": 3, "copper_ingot": 1}, "item": "spike_trap", "count": 1, "xp": 14.0},
	{"id": "ballista", "profession": "building", "level": 5, "inputs": {"oak_wood": 12, "iron_ingot": 3, "hound_pelt": 2}, "item": "ballista", "count": 1, "xp": 40.0},
	{"id": "bread", "profession": "cooking", "level": 1, "inputs": {"wheat": 3}, "item": "bread", "count": 1, "xp": 8.0},
	{"id": "baked_potato", "profession": "cooking", "level": 1, "inputs": {"potato": 1}, "item": "baked_potato", "count": 1, "xp": 5.0},
	{"id": "carrot_stew", "profession": "cooking", "level": 8, "inputs": {"carrot": 2, "potato": 1}, "item": "carrot_stew", "count": 1, "xp": 18.0},
	{"id": "frostberry_tart", "profession": "cooking", "level": 15, "inputs": {"frostberry": 3, "wheat": 1}, "item": "frostberry_tart", "count": 1, "xp": 28.0},
	{"id": "pumpkin_pie", "profession": "cooking", "level": 20, "inputs": {"pumpkin": 1, "wheat": 2}, "item": "pumpkin_pie", "count": 1, "xp": 40.0},
	{"id": "sunroot_elixir", "profession": "alchemy", "level": 25, "inputs": {"sunroot": 1, "mana_flower": 1}, "item": "sunroot_elixir", "count": 1, "xp": 50.0},
	{"id": "taming_treat", "profession": "cooking", "level": 2, "inputs": {"wild_berries": 2, "bone": 1}, "item": "taming_treat", "count": 2, "xp": 10.0},
	{"id": "leather", "profession": "salvaging", "level": 1, "inputs": {"deer_hide": 2}, "item": "leather", "count": 1, "xp": 6.0},
	{"id": "leather_from_pig", "profession": "salvaging", "level": 1, "inputs": {"pig_hide": 2}, "item": "leather", "count": 1, "xp": 6.0},
	{"id": "leather_from_hare", "profession": "salvaging", "level": 1, "inputs": {"hare_pelt": 3}, "item": "leather", "count": 1, "xp": 6.0},
	{"id": "satchel", "profession": "blacksmithing", "level": 2, "inputs": {"leather": 5}, "item": "satchel", "count": 1, "xp": 18.0},
	{"id": "backpack", "profession": "blacksmithing", "level": 8, "inputs": {"leather": 12, "iron_ingot": 2}, "item": "backpack", "count": 1, "xp": 40.0},
	{"id": "explorers_pack", "profession": "blacksmithing", "level": 16, "inputs": {"leather": 20, "silver_ingot": 4}, "item": "explorers_pack", "count": 1, "xp": 80.0},
	{"id": "leather_cap", "profession": "blacksmithing", "level": 2, "inputs": {"leather": 3}, "item": "leather_cap", "count": 1, "xp": 14.0},
	{"id": "leather_vest", "profession": "blacksmithing", "level": 3, "inputs": {"leather": 6}, "item": "leather_vest", "count": 1, "xp": 20.0},
	{"id": "leather_leggings", "profession": "blacksmithing", "level": 3, "inputs": {"leather": 5}, "item": "leather_leggings", "count": 1, "xp": 18.0},
	{"id": "leather_boots", "profession": "blacksmithing", "level": 2, "inputs": {"leather": 3}, "item": "leather_boots", "count": 1, "xp": 14.0},
	{"id": "fur_cloak", "profession": "blacksmithing", "level": 12, "inputs": {"fox_pelt": 3, "wool": 4, "leather": 2}, "item": "fur_cloak", "count": 1, "xp": 40.0},
	{"id": "roast_venison", "profession": "cooking", "level": 1, "inputs": {"venison": 1}, "item": "roast_venison", "count": 1, "xp": 8.0},
	{"id": "hare_stew", "profession": "cooking", "level": 4, "inputs": {"hare_meat": 1, "carrot": 1, "potato": 1}, "item": "hare_stew", "count": 1, "xp": 14.0},
	{"id": "grilled_pork", "profession": "cooking", "level": 1, "inputs": {"pork": 1}, "item": "grilled_pork", "count": 1, "xp": 6.0},
	{"id": "pork_pie", "profession": "cooking", "level": 10, "inputs": {"pork": 2, "wheat": 2}, "item": "pork_pie", "count": 1, "xp": 22.0},
	{"id": "goat_skewer", "profession": "cooking", "level": 6, "inputs": {"goat_meat": 2}, "item": "goat_skewer", "count": 1, "xp": 14.0},
	{"id": "roast_pheasant", "profession": "cooking", "level": 3, "inputs": {"pheasant_meat": 1}, "item": "roast_pheasant", "count": 1, "xp": 10.0},
	{"id": "fried_toad_legs", "profession": "cooking", "level": 5, "inputs": {"toad_legs": 2}, "item": "fried_toad_legs", "count": 1, "xp": 12.0},
	{"id": "spiced_lizard", "profession": "cooking", "level": 8, "inputs": {"lizard_meat": 1, "desert_aloe": 1}, "item": "spiced_lizard", "count": 1, "xp": 16.0},
	{"id": "crab_cakes", "profession": "cooking", "level": 12, "inputs": {"crab_meat": 2, "wheat": 1}, "item": "crab_cakes", "count": 1, "xp": 22.0},
	{"id": "jerky", "profession": "cooking", "level": 2, "inputs": {"venison": 1, "saltweed": 1}, "item": "jerky", "count": 3, "xp": 10.0},
	{"id": "hunters_feast", "profession": "cooking", "level": 25, "inputs": {"roast_venison": 1, "grilled_pork": 1, "bread": 1, "roast_pheasant": 1}, "item": "hunters_feast", "count": 1, "xp": 60.0},
	{"id": "salmon_steak", "profession": "cooking", "level": 18, "inputs": {"salmon": 1}, "item": "salmon_steak", "count": 1, "xp": 26.0},
	{"id": "pike_chowder", "profession": "cooking", "level": 14, "inputs": {"pike": 1, "potato": 1}, "item": "pike_chowder", "count": 1, "xp": 22.0},
	{"id": "glowfin_soup", "profession": "cooking", "level": 30, "inputs": {"glowfin": 1, "glowshroom": 1}, "item": "glowfin_soup", "count": 1, "xp": 45.0},
	{"id": "golden_platter", "profession": "cooking", "level": 45, "inputs": {"golden_carp": 1, "bread": 1}, "item": "golden_platter", "count": 1, "xp": 90.0},
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
