class_name ItemDB
extends RefCounted
## Every item, rarity, random modifier, and loot table in the game.
##
## Ids here are stable: saves, quests, and recipes refer to them, so rename
## the "name" freely but never an id.

const ICONS: Texture2D = preload("res://assets/icons/items.png")
const ICON_SIZE := 22
const ICON_COLUMNS := 8
const GOLD_ICON := 17
const MAX_STACK := 999

## Index is the rarity number stored on items.
## "mods": random modifiers rolled. "power": multiplier on base damage/armor.
## "weight": relative drop chance before magic find.
## Rarity is what makes gear strong: "power" multiplies an item's damage or
## armour, "affix" its random bonuses, and "gift" is a bonus of its own that
## Epic gear and better carries. A Legendary blade ten levels old still
## beats a fresh Common one.
const RARITIES: Array[Dictionary] = [
	{"id": "common", "name": "Common", "color": Color("c8c4b8"), "mods": 0, "power": 1.0, "affix": 1.0, "gift": 0.0, "weight": 600.0},
	{"id": "uncommon", "name": "Uncommon", "color": Color("5fd068"), "mods": 1, "power": 1.3, "affix": 1.15, "gift": 0.0, "weight": 250.0},
	{"id": "rare", "name": "Rare", "color": Color("4f9dff"), "mods": 2, "power": 1.7, "affix": 1.35, "gift": 0.0, "weight": 100.0},
	{"id": "epic", "name": "Epic", "color": Color("b565f0"), "mods": 3, "power": 2.25, "affix": 1.6, "gift": 0.05, "weight": 40.0},
	{"id": "legendary", "name": "Legendary", "color": Color("ff9a2e"), "mods": 4, "power": 3.0, "affix": 1.9, "gift": 0.1, "weight": 9.0},
	{"id": "mythic", "name": "Mythic", "color": Color("ff4d6d"), "mods": 5, "power": 4.0, "affix": 2.3, "gift": 0.16, "weight": 1.0},
]
## Wearing several pieces of one rarity (or better) attunes them. The best
## tier with ATTUNE_PIECES pieces counts: rarity -> bonuses.
const ATTUNE_PIECES := 4
const ATTUNEMENTS := {
	2: {"name": "Rare attunement", "mods": {"max_health": {"percent": 0.06}, "physical_damage": {"percent": 0.06}}},
	3: {"name": "Epic attunement", "mods": {"max_health": {"percent": 0.1}, "physical_damage": {"percent": 0.1}, "critical_chance": {"flat": 0.04}}},
	4: {"name": "Legendary attunement", "mods": {"max_health": {"percent": 0.16}, "physical_damage": {"percent": 0.16}, "critical_chance": {"flat": 0.07}, "move_speed": {"percent": 0.06}}},
	5: {"name": "Mythic attunement", "mods": {"max_health": {"percent": 0.25}, "physical_damage": {"percent": 0.25}, "critical_chance": {"flat": 0.1}, "move_speed": {"percent": 0.1}}},
}

const SLOTS: Array[String] = [
	"main_hand", "off_hand", "helmet", "chest", "legs", "boots",
	"necklace", "ring_1", "ring_2", "artifact",
]
const SLOT_NAMES := {
	"main_hand": "Main hand",
	"off_hand": "Off hand",
	"helmet": "Helmet",
	"chest": "Chest",
	"legs": "Legs",
	"boots": "Boots",
	"necklace": "Necklace",
	"ring": "Ring",
	"ring_1": "Ring",
	"ring_2": "Ring",
	"artifact": "Artifact",
}

## Name prefix for metal gear by item level, matching the ore tiers.
## The colour tints worn armour on the character.
const TIERS: Array[Array] = [
	[850, "Ascendant", Color("ffd86b")], [600, "Primordial", Color("7ae0a0")], [400, "Celestial", Color("e8ecff")],
	[250, "Eclipse", Color("7a5ab8")], [150, "Starmetal", Color("8ab8ff")],
	[100, "Heartstone", Color("e0506a")], [80, "Void", Color("9a6cf0")],
	[65, "Adamantite", Color("d06a5a")], [50, "Obsidian", Color("6a6480")],
	[40, "Mithril", Color("8fe0e8")], [30, "Gilded", Color("f0cf6a")],
	[20, "Silver", Color("eef2f6")], [10, "Iron", Color("aab2bc")], [1, "Copper", Color("d99a6c")],
]
## Base damage and armor grow by this share per item level above 1.
const POWER_PER_LEVEL := 0.08

## Colour and name for each status a weapon can inflict.
const STATUSES := {
	"burn": {"name": "Burn", "color": Color(1.0, 0.6, 0.25)},
	"poison": {"name": "Poison", "color": Color(0.55, 0.95, 0.4)},
	"bleed": {"name": "Bleed", "color": Color(0.95, 0.3, 0.3)},
	"chill": {"name": "Chill", "color": Color(0.6, 0.85, 1.0)},
}

## Courses of food. Each course is its own buff, so one meal, one drink and
## one treat can all work at once; another of the same course replaces it.
## Food not listed here is a meal.
const DRINKS: Array[String] = ["frost_tea", "hunters_brew", "swiftfoot_tea", "ironbark_tonic", "sages_infusion", "ember_ale", "sunroot_cordial"]
const TREATS: Array[String] = ["berry_tart", "thornberry_jam", "frostberry_tart", "sweet_roll", "candied_frostberries", "pumpkin_bread"]
const COURSE_NAMES := {"meal": "Meal", "drink": "Drink", "treat": "Treat"}


## "meal", "drink" or "treat" for food; "" for anything else.
static func course_of(item_id: String) -> String:
	var use: Dictionary = ITEMS.get(item_id, {}).get("use", {})
	if use.get("buff", "") != "food":
		return ""
	return "drink" if item_id in DRINKS else "treat" if item_id in TREATS else "meal"


## Fighting bare-handed.
const UNARMED := {"type": "unarmed", "range": 44.0, "arc": 100.0, "cooldown": 0.3, "knockback": 300.0}

## Equipment has "slot". Weapons add "weapon" (attack profile) and "damage".
## "requires": attribute -> [base, per item level].
## "implicit": modifiers every copy has; value = base + per_level * item level.
const ITEMS := {
	# --- weapons
	# "visual" names the sheet in assets/sprites/weapons/. "slash" tints the
	# swing. "on_hit" applies a status to whatever is struck:
	#   burn / poison / bleed: "power" x the hit's damage, every second
	#   chill: "power" is the share of movement speed removed
	# "life_steal" heals that share of damage dealt.
	"club": {
		"name": "Wooden Club", "icon": 58, "visual": "club", "slot": "main_hand", "drop_weight": 0.0,
		"damage": 4.0, "text": "A heavy stick. Better than nothing.",
		"weapon": {"type": "unarmed", "range": 56.0, "arc": 110.0, "cooldown": 0.42, "knockback": 360.0},
	},
	"sword": {
		"name": "Sword", "icon": 0, "visual": "sword", "slot": "main_hand", "tiered": true, "drop_weight": 10.0,
		"damage": 6.0,
		"weapon": {"type": "swords", "range": 64.0, "arc": 120.0, "cooldown": 0.34, "knockback": 380.0},
	},
	"flame_sword": {
		"name": "Emberbrand", "icon": 18, "visual": "flame_sword", "slot": "main_hand", "implicit": [{"stat": "fire_damage", "kind": "flat", "base": 2.0, "per_level": 0.45}], "tiered": true,
		"drop_weight": 2.0, "min_rarity": 1, "damage": 5.5, "slash": Color(1.0, 0.6, 0.2),
		"on_hit": {"status": "burn", "duration": 3.0, "power": 0.3},
		"weapon": {"type": "swords", "range": 64.0, "arc": 120.0, "cooldown": 0.34, "knockback": 380.0},
	},
	"frost_sword": {
		"name": "Frostbrand", "icon": 19, "visual": "frost_sword", "slot": "main_hand", "implicit": [{"stat": "frost_damage", "kind": "flat", "base": 2.0, "per_level": 0.45}], "tiered": true,
		"drop_weight": 2.0, "min_rarity": 1, "damage": 5.5, "slash": Color(0.6, 0.9, 1.0),
		"on_hit": {"status": "chill", "duration": 2.5, "power": 0.4},
		"weapon": {"type": "swords", "range": 64.0, "arc": 120.0, "cooldown": 0.34, "knockback": 380.0},
	},
	"dark_sword": {
		"name": "Gloomblade", "icon": 20, "visual": "dark_sword", "slot": "main_hand", "implicit": [{"stat": "shadow_damage", "kind": "flat", "base": 1.5, "per_level": 0.35}], "tiered": true,
		"drop_weight": 1.5, "min_rarity": 2, "damage": 7.0, "slash": Color(0.7, 0.45, 1.0),
		"life_steal": 0.05,
		"weapon": {"type": "swords", "range": 66.0, "arc": 125.0, "cooldown": 0.38, "knockback": 400.0},
	},
	"katana": {
		"name": "Katana", "icon": 21, "visual": "katana", "slot": "main_hand", "tiered": true, "drop_weight": 3.0,
		"damage": 5.0, "requires": {"agility": [3.0, 0.5]},
		"implicit": [{"stat": "critical_damage", "kind": "flat", "base": 0.25, "per_level": 0.0}],
		"weapon": {"type": "swords", "range": 74.0, "arc": 80.0, "cooldown": 0.26, "knockback": 260.0},
	},
	"greatsword": {
		"name": "Greatsword", "icon": 1, "visual": "greatsword", "slot": "main_hand", "tiered": true, "drop_weight": 5.0,
		"damage": 11.0, "two_handed": true, "requires": {"strength": [4.0, 1.0]},
		"weapon": {"type": "greatswords", "range": 82.0, "arc": 150.0, "cooldown": 0.6, "knockback": 540.0},
	},
	"executioner": {
		"name": "Executioner", "icon": 22, "visual": "executioner", "slot": "main_hand", "tiered": true,
		"drop_weight": 1.5, "min_rarity": 1, "damage": 13.0, "two_handed": true, "slash": Color(1.0, 0.4, 0.4),
		"requires": {"strength": [5.0, 1.1]},
		"implicit": [{"stat": "critical_damage", "kind": "flat", "base": 0.3, "per_level": 0.0}],
		"weapon": {"type": "greatswords", "range": 84.0, "arc": 130.0, "cooldown": 0.7, "knockback": 600.0},
	},
	"axe": {
		"name": "Axe", "icon": 2, "visual": "axe", "slot": "main_hand", "tiered": true, "drop_weight": 6.0,
		"damage": 8.0, "requires": {"strength": [2.0, 0.6]},
		"weapon": {"type": "axes", "range": 60.0, "arc": 110.0, "cooldown": 0.45, "knockback": 460.0},
	},
	"reaver": {
		"name": "Reaver", "icon": 23, "visual": "reaver", "slot": "main_hand", "tiered": true,
		"drop_weight": 1.5, "min_rarity": 1, "damage": 9.5, "slash": Color(1.0, 0.4, 0.4),
		"requires": {"strength": [3.0, 0.7]},
		"on_hit": {"status": "bleed", "duration": 4.0, "power": 0.2},
		"weapon": {"type": "axes", "range": 66.0, "arc": 140.0, "cooldown": 0.5, "knockback": 480.0},
	},
	"dagger": {
		"name": "Dagger", "icon": 3, "visual": "dagger", "slot": "main_hand", "tiered": true, "drop_weight": 6.0,
		"damage": 4.0, "requires": {"agility": [2.0, 0.6]},
		"implicit": [{"stat": "critical_chance", "kind": "flat", "base": 0.05, "per_level": 0.0}],
		"weapon": {"type": "daggers", "range": 48.0, "arc": 90.0, "cooldown": 0.22, "knockback": 220.0},
	},
	"fang": {
		"name": "Fang", "icon": 24, "visual": "fang", "slot": "main_hand", "implicit": [{"stat": "poison_damage", "kind": "flat", "base": 1.5, "per_level": 0.35}], "tiered": true,
		"drop_weight": 1.5, "min_rarity": 1, "damage": 3.5, "slash": Color(0.6, 1.0, 0.4),
		"requires": {"agility": [2.0, 0.6]},
		"on_hit": {"status": "poison", "duration": 4.0, "power": 0.25},
		"weapon": {"type": "daggers", "range": 48.0, "arc": 90.0, "cooldown": 0.2, "knockback": 200.0},
	},
	"spear": {
		"name": "Spear", "icon": 4, "visual": "spear", "slot": "main_hand", "tiered": true, "drop_weight": 5.0,
		"damage": 7.0, "two_handed": true,
		"weapon": {"type": "spears", "range": 106.0, "arc": 50.0, "cooldown": 0.42, "knockback": 420.0},
	},
	"halberd": {
		"name": "Halberd", "icon": 25, "visual": "halberd", "slot": "main_hand", "tiered": true, "drop_weight": 2.0,
		"damage": 9.0, "two_handed": true, "requires": {"strength": [3.0, 0.7]},
		"weapon": {"type": "spears", "range": 100.0, "arc": 110.0, "cooldown": 0.55, "knockback": 480.0},
	},
	# Ranged weapons fire a projectile (see Projectile for the keys) instead
	# of swinging. "magic" weapons scale with magic damage.
	"bow": {
		"name": "Bow", "icon": 32, "visual": "bow", "slot": "main_hand", "tiered": true, "drop_weight": 5.0,
		"damage": 5.5, "two_handed": true, "requires": {"agility": [3.0, 0.7]},
		"weapon": {"type": "bows", "range": 560.0, "arc": 0.0, "cooldown": 0.5, "knockback": 200.0,
			"projectile": {"sprite": 0, "speed": 780.0, "radius": 10.0, "range": 560.0}},
	},
	"staff": {
		"name": "Staff", "icon": 33, "visual": "staff", "slot": "main_hand", "tiered": true, "drop_weight": 4.0,
		"damage": 5.0, "two_handed": true, "magic": true, "slash": Color(0.75, 0.55, 1.0),
		"requires": {"intelligence": [3.0, 0.7]},
		"implicit": [{"stat": "max_mana", "kind": "flat", "base": 10.0, "per_level": 0.5}],
		"weapon": {"type": "staves", "range": 480.0, "arc": 0.0, "cooldown": 0.55, "knockback": 160.0,
			"projectile": {"sprite": 1, "speed": 560.0, "radius": 12.0, "range": 480.0, "color": Color(0.75, 0.55, 1.0)}},
	},
	# Given at the Altar of Magic to one who comes without a magic weapon:
	# anyone can carry it.
	"altar_staff": {
		"name": "Altar Staff", "icon": 33, "visual": "staff", "slot": "main_hand", "tiered": true, "drop_weight": 0.0,
		"damage": 4.5, "two_handed": true, "magic": true, "slash": Color(0.8, 0.6, 1.0),
		"implicit": [{"stat": "max_mana", "kind": "flat", "base": 15.0, "per_level": 0.5}],
		"weapon": {"type": "staves", "range": 480.0, "arc": 0.0, "cooldown": 0.55, "knockback": 160.0,
			"projectile": {"sprite": 1, "speed": 560.0, "radius": 12.0, "range": 480.0, "color": Color(0.8, 0.6, 1.0)}},
	},
	"ember_staff": {
		"name": "Emberstaff", "icon": 34, "visual": "ember_staff", "slot": "main_hand", "tiered": true,
		"drop_weight": 1.5, "min_rarity": 1, "damage": 4.5, "two_handed": true, "magic": true,
		"slash": Color(1.0, 0.6, 0.2), "requires": {"intelligence": [3.0, 0.7]},
		"on_hit": {"status": "burn", "duration": 3.0, "power": 0.3},
		"implicit": [{"stat": "fire_damage", "kind": "flat", "base": 2.0, "per_level": 0.45}, {"stat": "max_mana", "kind": "flat", "base": 10.0, "per_level": 0.5}],
		"weapon": {"type": "staves", "range": 480.0, "arc": 0.0, "cooldown": 0.55, "knockback": 160.0,
			"projectile": {"sprite": 2, "speed": 560.0, "radius": 12.0, "range": 480.0, "color": Color(1.0, 0.6, 0.2)}},
	},
	# --- unique weapons and gear: one of a kind, always Legendary, each with
	# its own effect (see Uniques). Never rolled as random bases.
	"stormcaller": {
		"name": "Stormcaller", "icon": 60, "visual": "stormcaller", "slot": "main_hand", "unique": "chain_lightning", "min_rarity": 4, "drop_weight": 0.0,
		"damage": 7.0, "slash": Color(0.6, 0.85, 1.0),
		"weapon": {"type": "swords", "range": 66.0, "arc": 120.0, "cooldown": 0.32, "knockback": 380.0},
	},
	"splitshot": {
		"name": "Splitshot", "icon": 61, "visual": "splitshot", "slot": "main_hand", "unique": "split_arrows", "min_rarity": 4, "drop_weight": 0.0,
		"damage": 5.0, "two_handed": true, "requires": {"agility": [3.0, 0.7]},
		"weapon": {"type": "bows", "range": 560.0, "arc": 0.0, "cooldown": 0.5, "knockback": 200.0,
			"projectile": {"sprite": 0, "speed": 820.0, "radius": 10.0, "range": 560.0}},
	},
	"wispkeeper": {
		"name": "Wispkeeper", "icon": 62, "visual": "wispkeeper", "slot": "main_hand", "unique": "wisp", "min_rarity": 4, "drop_weight": 0.0,
		"damage": 5.0, "two_handed": true, "magic": true, "slash": Color(0.55, 1.0, 0.95),
		"implicit": [{"stat": "max_mana", "kind": "flat", "base": 15.0, "per_level": 0.6}],
		"weapon": {"type": "staves", "range": 480.0, "arc": 0.0, "cooldown": 0.55, "knockback": 160.0,
			"projectile": {"sprite": 1, "speed": 560.0, "radius": 12.0, "range": 480.0, "color": Color(0.55, 1.0, 0.95)}},
	},
	"bloodthirst": {
		"name": "Bloodthirst", "icon": 63, "visual": "bloodthirst", "slot": "main_hand", "unique": "bloodthirst", "min_rarity": 4, "drop_weight": 0.0,
		"damage": 9.0, "slash": Color(1.0, 0.25, 0.3), "requires": {"strength": [2.0, 0.6]},
		"weapon": {"type": "axes", "range": 62.0, "arc": 115.0, "cooldown": 0.45, "knockback": 460.0},
	},
	"frostbite": {
		"name": "Frostbite", "icon": 64, "visual": "frostbite", "slot": "main_hand", "unique": "freeze", "min_rarity": 4, "drop_weight": 0.0,
		"damage": 4.0, "slash": Color(0.6, 0.9, 1.0), "requires": {"agility": [2.0, 0.6]},
		"implicit": [{"stat": "frost_damage", "kind": "flat", "base": 2.0, "per_level": 0.4}],
		"weapon": {"type": "daggers", "range": 48.0, "arc": 90.0, "cooldown": 0.22, "knockback": 220.0},
	},
	"sunfang": {
		"name": "Sunfang", "icon": 65, "visual": "sunfang", "slot": "main_hand", "unique": "sun_pillar", "min_rarity": 4, "drop_weight": 0.0,
		"damage": 7.5, "two_handed": true, "slash": Color(1.0, 0.9, 0.5),
		"implicit": [{"stat": "holy_damage", "kind": "flat", "base": 2.0, "per_level": 0.45}],
		"weapon": {"type": "spears", "range": 106.0, "arc": 50.0, "cooldown": 0.42, "knockback": 420.0},
	},
	"ember_crown": {"name": "Ember Crown", "icon": 101, "tint": Color("ff9a4a"), "slot": "helmet", "unique": "fire_nova", "min_rarity": 4, "drop_weight": 0.0, "armor": 5.0,
		"implicit": [{"stat": "fire_resist", "kind": "flat", "base": 0.15, "per_level": 0.0}]},
	"phoenix_ring": {"name": "Phoenix Ring", "icon": 11, "tint": Color("ffb060"), "slot": "ring", "unique": "phoenix", "min_rarity": 4, "drop_weight": 0.0,
		"implicit": [{"stat": "health_regen", "kind": "flat", "base": 0.5, "per_level": 0.05}]},
	# --- the Heartsworn: forged from what heart monsters leave behind (see
	# RecipeDB), worn as a set. Each piece carries a heart of its own.
	"heartsworn_helm": {"name": "Helm", "icon": 117, "slot": "helmet", "set": "heartsworn", "drop_weight": 0.0, "min_rarity": 2, "armor": 5.0,
		"implicit": [{"stat": "max_health", "kind": "flat", "base": 12.0, "per_level": 2.5}]},
	"heartsworn_cuirass": {"name": "Cuirass", "icon": 118, "slot": "chest", "set": "heartsworn", "drop_weight": 0.0, "min_rarity": 2, "armor": 10.0,
		"implicit": [{"stat": "life_steal", "kind": "flat", "base": 0.015, "per_level": 0.0}]},
	"heartsworn_greaves": {"name": "Greaves", "icon": 119, "slot": "legs", "set": "heartsworn", "drop_weight": 0.0, "min_rarity": 2, "armor": 7.0,
		"implicit": [{"stat": "health_regen", "kind": "flat", "base": 0.6, "per_level": 0.05}]},
	"heartsworn_sabatons": {"name": "Sabatons", "icon": 120, "slot": "boots", "set": "heartsworn", "drop_weight": 0.0, "min_rarity": 2, "armor": 4.0,
		"implicit": [{"stat": "move_speed", "kind": "flat", "base": 8.0, "per_level": 0.1}]},
	"pulsebrand": {
		"name": "Pulsebrand", "icon": 121, "visual": "pulsebrand", "slot": "main_hand", "set": "heartsworn", "drop_weight": 0.0, "min_rarity": 2,
		"damage": 12.5, "two_handed": true, "slash": Color(1.0, 0.35, 0.45), "life_steal": 0.04, "requires": {"strength": [4.0, 1.0]},
		"on_hit": {"status": "bleed", "duration": 4.0, "power": 0.25},
		"weapon": {"type": "greatswords", "range": 84.0, "arc": 150.0, "cooldown": 0.6, "knockback": 540.0},
	},
	"heartpiercer": {
		"name": "Heartpiercer", "icon": 122, "visual": "heartpiercer", "slot": "main_hand", "drop_weight": 0.0, "min_rarity": 2,
		"damage": 8.5, "two_handed": true, "slash": Color(1.0, 0.35, 0.45), "life_steal": 0.03,
		"on_hit": {"status": "bleed", "duration": 4.0, "power": 0.3},
		"weapon": {"type": "spears", "range": 112.0, "arc": 50.0, "cooldown": 0.42, "knockback": 420.0},
	},
	"heartstring": {
		"name": "Heartstring", "icon": 123, "visual": "heartstring", "slot": "main_hand", "drop_weight": 0.0, "min_rarity": 2,
		"damage": 6.5, "two_handed": true, "slash": Color(1.0, 0.35, 0.45), "life_steal": 0.02, "requires": {"agility": [3.0, 0.7]},
		"on_hit": {"status": "bleed", "duration": 3.0, "power": 0.25},
		"weapon": {"type": "bows", "range": 580.0, "arc": 0.0, "cooldown": 0.48, "knockback": 200.0,
			"projectile": {"sprite": 0, "speed": 800.0, "radius": 10.0, "range": 580.0}},
	},
	"voidwalker": {"name": "Voidwalkers", "icon": 9, "tint": Color("b88aff"), "slot": "boots", "unique": "void_rift", "min_rarity": 4, "drop_weight": 0.0, "armor": 3.0,
		"implicit": [{"stat": "move_speed", "kind": "flat", "base": 10.0, "per_level": 0.1}]},
	"gravecaller": {"name": "Gravecaller", "icon": 12, "tint": Color("8affb0"), "slot": "artifact", "unique": "spirit_bolt", "min_rarity": 4, "drop_weight": 0.0,
		"implicit": [{"stat": "shadow_damage", "kind": "flat", "base": 1.0, "per_level": 0.25}]},
	# --- gems: set into sockets on gear (see Gems). Three of a grade make one of the next.
	"ruby_1": {"name": "Chipped Ruby", "icon": 59, "tint": Color("e0405a"), "gem": "ruby", "grade": 1, "material_rarity": 0, "value": 8, "text": "A gem for a socket."},
	"ruby_2": {"name": "Flawed Ruby", "icon": 59, "tint": Color("e0405a"), "gem": "ruby", "grade": 2, "material_rarity": 1, "value": 25, "text": "A gem for a socket."},
	"ruby_3": {"name": "Ruby", "icon": 59, "tint": Color("e0405a"), "gem": "ruby", "grade": 3, "material_rarity": 2, "value": 70, "text": "A gem for a socket."},
	"ruby_4": {"name": "Flawless Ruby", "icon": 59, "tint": Color("e0405a"), "gem": "ruby", "grade": 4, "material_rarity": 3, "value": 200, "text": "A gem for a socket."},
	"ruby_5": {"name": "Perfect Ruby", "icon": 59, "tint": Color("e0405a"), "gem": "ruby", "grade": 5, "material_rarity": 4, "value": 600, "text": "A gem for a socket."},
	"sapphire_1": {"name": "Chipped Sapphire", "icon": 59, "tint": Color("4a8af0"), "gem": "sapphire", "grade": 1, "material_rarity": 0, "value": 8, "text": "A gem for a socket."},
	"sapphire_2": {"name": "Flawed Sapphire", "icon": 59, "tint": Color("4a8af0"), "gem": "sapphire", "grade": 2, "material_rarity": 1, "value": 25, "text": "A gem for a socket."},
	"sapphire_3": {"name": "Sapphire", "icon": 59, "tint": Color("4a8af0"), "gem": "sapphire", "grade": 3, "material_rarity": 2, "value": 70, "text": "A gem for a socket."},
	"sapphire_4": {"name": "Flawless Sapphire", "icon": 59, "tint": Color("4a8af0"), "gem": "sapphire", "grade": 4, "material_rarity": 3, "value": 200, "text": "A gem for a socket."},
	"sapphire_5": {"name": "Perfect Sapphire", "icon": 59, "tint": Color("4a8af0"), "gem": "sapphire", "grade": 5, "material_rarity": 4, "value": 600, "text": "A gem for a socket."},
	"emerald_1": {"name": "Chipped Emerald", "icon": 59, "tint": Color("40d070"), "gem": "emerald", "grade": 1, "material_rarity": 0, "value": 8, "text": "A gem for a socket."},
	"emerald_2": {"name": "Flawed Emerald", "icon": 59, "tint": Color("40d070"), "gem": "emerald", "grade": 2, "material_rarity": 1, "value": 25, "text": "A gem for a socket."},
	"emerald_3": {"name": "Emerald", "icon": 59, "tint": Color("40d070"), "gem": "emerald", "grade": 3, "material_rarity": 2, "value": 70, "text": "A gem for a socket."},
	"emerald_4": {"name": "Flawless Emerald", "icon": 59, "tint": Color("40d070"), "gem": "emerald", "grade": 4, "material_rarity": 3, "value": 200, "text": "A gem for a socket."},
	"emerald_5": {"name": "Perfect Emerald", "icon": 59, "tint": Color("40d070"), "gem": "emerald", "grade": 5, "material_rarity": 4, "value": 600, "text": "A gem for a socket."},
	"topaz_1": {"name": "Chipped Topaz", "icon": 59, "tint": Color("f0c040"), "gem": "topaz", "grade": 1, "material_rarity": 0, "value": 8, "text": "A gem for a socket."},
	"topaz_2": {"name": "Flawed Topaz", "icon": 59, "tint": Color("f0c040"), "gem": "topaz", "grade": 2, "material_rarity": 1, "value": 25, "text": "A gem for a socket."},
	"topaz_3": {"name": "Topaz", "icon": 59, "tint": Color("f0c040"), "gem": "topaz", "grade": 3, "material_rarity": 2, "value": 70, "text": "A gem for a socket."},
	"topaz_4": {"name": "Flawless Topaz", "icon": 59, "tint": Color("f0c040"), "gem": "topaz", "grade": 4, "material_rarity": 3, "value": 200, "text": "A gem for a socket."},
	"topaz_5": {"name": "Perfect Topaz", "icon": 59, "tint": Color("f0c040"), "gem": "topaz", "grade": 5, "material_rarity": 4, "value": 600, "text": "A gem for a socket."},
	"amethyst_1": {"name": "Chipped Amethyst", "icon": 59, "tint": Color("b070f0"), "gem": "amethyst", "grade": 1, "material_rarity": 0, "value": 8, "text": "A gem for a socket."},
	"amethyst_2": {"name": "Flawed Amethyst", "icon": 59, "tint": Color("b070f0"), "gem": "amethyst", "grade": 2, "material_rarity": 1, "value": 25, "text": "A gem for a socket."},
	"amethyst_3": {"name": "Amethyst", "icon": 59, "tint": Color("b070f0"), "gem": "amethyst", "grade": 3, "material_rarity": 2, "value": 70, "text": "A gem for a socket."},
	"amethyst_4": {"name": "Flawless Amethyst", "icon": 59, "tint": Color("b070f0"), "gem": "amethyst", "grade": 4, "material_rarity": 3, "value": 200, "text": "A gem for a socket."},
	"amethyst_5": {"name": "Perfect Amethyst", "icon": 59, "tint": Color("b070f0"), "gem": "amethyst", "grade": 5, "material_rarity": 4, "value": 600, "text": "A gem for a socket."},
	"diamond_1": {"name": "Chipped Diamond", "icon": 59, "tint": Color("eef6ff"), "gem": "diamond", "grade": 1, "material_rarity": 0, "value": 8, "text": "A gem for a socket."},
	"diamond_2": {"name": "Flawed Diamond", "icon": 59, "tint": Color("eef6ff"), "gem": "diamond", "grade": 2, "material_rarity": 1, "value": 25, "text": "A gem for a socket."},
	"diamond_3": {"name": "Diamond", "icon": 59, "tint": Color("eef6ff"), "gem": "diamond", "grade": 3, "material_rarity": 2, "value": 70, "text": "A gem for a socket."},
	"diamond_4": {"name": "Flawless Diamond", "icon": 59, "tint": Color("eef6ff"), "gem": "diamond", "grade": 4, "material_rarity": 3, "value": 200, "text": "A gem for a socket."},
	"diamond_5": {"name": "Perfect Diamond", "icon": 59, "tint": Color("eef6ff"), "gem": "diamond", "grade": 5, "material_rarity": 4, "value": 600, "text": "A gem for a socket."},
	"garnet_1": {"name": "Chipped Garnet", "icon": 59, "tint": Color("f07030"), "gem": "garnet", "grade": 1, "material_rarity": 0, "value": 8, "text": "A gem for a socket."},
	"garnet_2": {"name": "Flawed Garnet", "icon": 59, "tint": Color("f07030"), "gem": "garnet", "grade": 2, "material_rarity": 1, "value": 25, "text": "A gem for a socket."},
	"garnet_3": {"name": "Garnet", "icon": 59, "tint": Color("f07030"), "gem": "garnet", "grade": 3, "material_rarity": 2, "value": 70, "text": "A gem for a socket."},
	"garnet_4": {"name": "Flawless Garnet", "icon": 59, "tint": Color("f07030"), "gem": "garnet", "grade": 4, "material_rarity": 3, "value": 200, "text": "A gem for a socket."},
	"garnet_5": {"name": "Perfect Garnet", "icon": 59, "tint": Color("f07030"), "gem": "garnet", "grade": 5, "material_rarity": 4, "value": 600, "text": "A gem for a socket."},
	# --- armor
	"shield": {"name": "Shield", "icon": 5, "slot": "off_hand", "tiered": true, "drop_weight": 6.0, "armor": 8.0},
	"helmet": {"name": "Helm", "icon": 6, "slot": "helmet", "tiered": true, "drop_weight": 8.0, "armor": 4.0},
	"chestplate": {"name": "Chestplate", "icon": 7, "slot": "chest", "tiered": true, "drop_weight": 8.0, "armor": 8.0},
	"greaves": {"name": "Greaves", "icon": 8, "slot": "legs", "tiered": true, "drop_weight": 8.0, "armor": 6.0},
	"boots": {"name": "Boots", "icon": 9, "slot": "boots", "tiered": true, "drop_weight": 8.0, "armor": 3.0},
	# --- accessories
	"necklace": {
		"name": "Necklace", "icon": 10, "slot": "necklace", "drop_weight": 4.0,
		"implicit": [{"stat": "max_health", "kind": "flat", "base": 8.0, "per_level": 1.5}],
	},
	"ring": {
		"name": "Ring", "icon": 11, "slot": "ring", "drop_weight": 6.0,
		"implicit": [{"stat": "physical_damage", "kind": "flat", "base": 1.0, "per_level": 0.2}],
	},
	"relic": {
		"name": "Relic", "icon": 12, "slot": "artifact", "drop_weight": 2.0, "min_rarity": 2,
		"implicit": [{"stat": "magic_find", "kind": "flat", "base": 0.05, "per_level": 0.0005}],
	},
	# --- materials
	"husk_fragment": {"name": "Husk Fragment", "icon": 13, "material_rarity": 0, "text": "A scrap of hardened husk hide."},
	"bone": {"name": "Bone", "icon": 14, "material_rarity": 0, "text": "Picked clean. Still useful."},
	"claw": {"name": "Claw", "icon": 15, "material_rarity": 1, "text": "Sharp enough to keep an edge."},
	"essence": {"name": "Essence", "icon": 16, "material_rarity": 2, "text": "A bead of whatever keeps the dead moving."},
	# --- gathered materials (pale icons tinted by "tint")
	"stone": {"name": "Stone", "icon": 42, "tint": Color("9a98a0"), "material_rarity": 0, "text": "Plain rock. Useful in every forge."},
	"tin_ore": {"name": "Tin Ore", "icon": 42, "tint": Color("c8d0d4"), "material_rarity": 0, "text": "Soft ore, smelted with copper into bronze."},
	"copper_ore": {"name": "Copper Ore", "icon": 42, "tint": Color("d98a5a"), "material_rarity": 0, "text": "Raw copper, ready for smelting."},
	"iron_ore": {"name": "Iron Ore", "icon": 42, "tint": Color("8f9aa6"), "material_rarity": 0, "text": "Raw iron, ready for smelting."},
	"silver_ore": {"name": "Silver Ore", "icon": 42, "tint": Color("eef2f6"), "material_rarity": 1, "text": "Raw silver, ready for smelting."},
	"gold_ore": {"name": "Gold Ore", "icon": 42, "tint": Color("f0cf6a"), "material_rarity": 1, "text": "Raw gold, ready for smelting."},
	"mithril_ore": {"name": "Mithril Ore", "icon": 42, "tint": Color("8fe0e8"), "material_rarity": 2, "text": "Raw mithril, ready for smelting."},
	"obsidian_ore": {"name": "Obsidian Ore", "icon": 42, "tint": Color("5a5470"), "material_rarity": 2, "text": "Raw obsidian, ready for smelting."},
	"adamantite_ore": {"name": "Adamantite Ore", "icon": 42, "tint": Color("d06a5a"), "material_rarity": 3, "text": "Raw adamantite, ready for smelting."},
	"void_crystal": {"name": "Void Crystal", "icon": 42, "tint": Color("9a6cf0"), "material_rarity": 3, "text": "Raw void, ready for smelting."},
	"heartstone": {"name": "Heartstone", "icon": 42, "tint": Color("e0506a"), "material_rarity": 4, "text": "Raw heartstone, ready for smelting."},
	"bronze_ingot": {"name": "Bronze Ingot", "icon": 46, "tint": Color("c9954a"), "material_rarity": 0, "text": "Copper and tin. Makes sturdy tools."},
	"copper_ingot": {"name": "Copper Ingot", "icon": 46, "tint": Color("d98a5a"), "material_rarity": 0, "text": "A bar of copper for the forge."},
	"iron_ingot": {"name": "Iron Ingot", "icon": 46, "tint": Color("8f9aa6"), "material_rarity": 0, "text": "A bar of iron for the forge."},
	"silver_ingot": {"name": "Silver Ingot", "icon": 46, "tint": Color("eef2f6"), "material_rarity": 1, "text": "A bar of silver for the forge."},
	"gold_ingot": {"name": "Gold Ingot", "icon": 46, "tint": Color("f0cf6a"), "material_rarity": 1, "text": "A bar of gold for the forge."},
	"mithril_ingot": {"name": "Mithril Ingot", "icon": 46, "tint": Color("8fe0e8"), "material_rarity": 2, "text": "A bar of mithril for the forge."},
	"obsidian_ingot": {"name": "Obsidian Ingot", "icon": 46, "tint": Color("5a5470"), "material_rarity": 2, "text": "A bar of obsidian for the forge."},
	"adamantite_ingot": {"name": "Adamantite Ingot", "icon": 46, "tint": Color("d06a5a"), "material_rarity": 3, "text": "A bar of adamantite for the forge."},
	"void_ingot": {"name": "Void Ingot", "icon": 46, "tint": Color("9a6cf0"), "material_rarity": 3, "text": "A bar of void for the forge."},
	"heartstone_ingot": {"name": "Heartstone Ingot", "icon": 46, "tint": Color("e0506a"), "material_rarity": 4, "text": "A bar of heartstone for the forge."},
	"oak_wood": {"name": "Oak Wood", "icon": 43, "tint": Color("b08a5a"), "material_rarity": 0, "text": "Timber for hafts, bows, and staves."},
	"pine_wood": {"name": "Pine Wood", "icon": 43, "tint": Color("8a6a48"), "material_rarity": 0, "text": "Timber for hafts, bows, and staves."},
	"ancient_wood": {"name": "Ancient Wood", "icon": 43, "tint": Color("6f7a5a"), "material_rarity": 2, "text": "Timber for hafts, bows, and staves."},
	"spiritwood": {"name": "Spiritwood", "icon": 43, "tint": Color("a8e0d0"), "material_rarity": 3, "text": "Timber for hafts, bows, and staves."},
	"healing_herb": {"name": "Healing Herb", "icon": 44, "tint": Color("6fd070"), "material_rarity": 0, "text": "Bitter leaves that close wounds."},
	"mana_flower": {"name": "Mana Flower", "icon": 44, "tint": Color("6fa0f0"), "material_rarity": 1, "text": "Its petals hum faintly."},
	"poison_mushroom": {"name": "Poison Mushroom", "icon": 91, "tint": Color("b06ad0"), "material_rarity": 1, "text": "Do not eat this one raw."},
	"rare_root": {"name": "Rare Root", "icon": 44, "tint": Color("d0b070"), "material_rarity": 2, "text": "A knotted root prized by alchemists."},
	"minnow": {"name": "Minnow", "icon": 45, "tint": Color("c0d0d8"), "material_rarity": 0, "text": "Fresh from the black water. Best cooked."},
	"trout": {"name": "Trout", "icon": 45, "tint": Color("e0a080"), "material_rarity": 1, "text": "Fresh from the black water. Best cooked."},
	"eel": {"name": "Eel", "icon": 45, "tint": Color("708090"), "material_rarity": 2, "text": "Fresh from the black water. Best cooked."},
	"enchanted_dust": {"name": "Enchanted Dust", "icon": 52, "tint": Color("ffffff"), "material_rarity": 1, "text": "What is left when magic gear is broken down."},
	"boss_trophy": {"name": "Boss Trophy", "icon": 12, "tint": Color("ff6a5a"), "material_rarity": 4, "value": 500, "text": "Proof that a great foe has fallen. Merchants pay well for it."},
	"dungeon_key": {"name": "Dungeon Key", "icon": 17, "tint": Color("c0a060"), "material_rarity": 1, "value": 0, "text": "Opens one locked door in the dungeon where it was found."},
	"gold_coins": {"name": "Gold", "icon": 17, "material_rarity": 0, "currency": true, "text": "Coin of a dead kingdom. Still spends."},
	"frost_pelt": {"name": "Frost Pelt", "icon": 82, "tint": Color("dce8f4"), "material_rarity": 1, "text": "Thick white fur, rimed with ice."},
	"troll_hide": {"name": "Troll Hide", "icon": 82, "tint": Color("7a8c9a"), "material_rarity": 2, "text": "It knits itself back together if you leave it."},
	"boar_tusk": {"name": "Boar Tusk", "icon": 85, "tint": Color("f0e8d0"), "material_rarity": 0, "text": "Curved and wicked."},
	"heartwood": {"name": "Heartwood", "icon": 43, "tint": Color("6a4a2a"), "material_rarity": 2, "text": "The living core of a treant. Still warm."},
	"scorpion_stinger": {"name": "Scorpion Stinger", "icon": 15, "tint": Color("d8b070"), "material_rarity": 1, "text": "A drop of venom still beads at the tip."},
	"mummy_wrap": {"name": "Mummy Wrap", "icon": 89, "tint": Color("e0d4b4"), "material_rarity": 1, "text": "Linen that has outlasted kingdoms."},
	"void_shard": {"name": "Void Shard", "icon": 42, "tint": Color("a070f0"), "material_rarity": 2, "text": "A splinter of nothing, given edges."},
	"heartblood": {"name": "Heartblood", "icon": 124, "material_rarity": 2, "value": 40, "text": "Still warm, and it beats against the glass. Left by heart monsters."},
	"crimson_plate": {"name": "Crimson Plate", "icon": 125, "material_rarity": 2, "value": 45, "text": "A shard of a Heartsworn Knight's armour. Smiths can forge it anew."},
	"fiend_horn": {"name": "Fiend Horn", "icon": 85, "tint": Color("e05a3a"), "material_rarity": 1, "text": "Hot to the touch."},
	"magma_core": {"name": "Magma Core", "icon": 16, "tint": Color("ff8a2e"), "material_rarity": 2, "text": "Molten rock that will not cool."},
	"harpy_feather": {"name": "Harpy Feather", "icon": 84, "tint": Color("a8b8d0"), "material_rarity": 1, "text": "It crackles in dry air."},
	"lurker_tongue": {"name": "Lurker Tongue", "icon": 16, "tint": Color("c05a6a"), "material_rarity": 0, "text": "Long, sticky, and best not thought about."},
	"hound_pelt": {"name": "Hound Pelt", "icon": 82, "tint": Color("8a5a4a"), "material_rarity": 0, "text": "Mangy, but it will cure."},
	"slime_gel": {"name": "Slime Gel", "icon": 16, "tint": Color("b8f08a"), "material_rarity": 0, "text": "It never quite stops moving."},
	"bat_wing": {"name": "Bat Wing", "icon": 15, "tint": Color("5a4a5e"), "material_rarity": 0, "text": "Thin as old paper."},
	"chitin": {"name": "Chitin", "icon": 87, "tint": Color("4a5040"), "material_rarity": 1, "text": "Light, hard plates from a stalker's back."},
	"spore_cap": {"name": "Spore Cap", "icon": 91, "tint": Color("c05a8a"), "material_rarity": 1, "text": "Keep it away from your face."},
	"cultist_sigil": {"name": "Cultist Sigil", "icon": 53, "tint": Color("c08cff"), "material_rarity": 1, "text": "A prayer to something that should not answer."},
	"wraith_cloth": {"name": "Wraith Cloth", "icon": 43, "tint": Color("dfe6ee"), "material_rarity": 2, "text": "Cold to the touch, and weightless."},
	"heart_shard": {"name": "Heart Shard", "icon": 12, "tint": Color("ff6a7a"), "material_rarity": 3, "text": "A splinter of something vast. It still pulses."},
	# --- biome plants (icons from the flora sheet: "flora")
	"frost_lily": {"name": "Frost Lily", "icon": 44, "flora": 24, "material_rarity": 1, "text": "Its petals never thaw."},
	"bloodcap": {"name": "Bloodcap", "icon": 44, "flora": 25, "material_rarity": 1, "text": "Bell-shaped and the colour of a wound."},
	"glowshroom": {"name": "Glowshroom", "icon": 44, "flora": 26, "material_rarity": 1, "text": "Gives off a soft green light."},
	"desert_aloe": {"name": "Desert Aloe", "icon": 44, "flora": 27, "material_rarity": 0, "text": "Cool sap that soothes burns."},
	"emberbloom": {"name": "Emberbloom", "icon": 44, "flora": 28, "material_rarity": 2, "text": "Warm enough to light a pipe."},
	"void_bloom": {"name": "Void Bloom", "icon": 44, "flora": 29, "material_rarity": 3, "text": "It grows toward nothing at all."},
	"saltweed": {"name": "Saltweed", "icon": 44, "flora": 30, "material_rarity": 0, "text": "Crunchy, bitter, and keeps forever."},
	"wild_berries": {"name": "Wild Berries", "icon": 80, "tint": Color("c0303a"), "material_rarity": 0, "use": {"heal": 0.08}, "value": 6, "text": "A handful of berries. Restores a little health."},
	"thornberries": {"name": "Thornberries", "icon": 80, "tint": Color("e8d8a0"), "material_rarity": 0, "use": {"heal": 0.12}, "value": 10, "text": "Worth the scratches. Restores some health."},
	"berry_tart": {"name": "Berry Tart", "icon": 70, "tint": Color("e05a6a"), "material_rarity": 0, "use": {"buff": "food", "name": "Well Fed", "duration": 300.0, "mods": {"max_health": {"flat": 30.0}, "move_speed": {"percent": 0.05}}}, "text": "+30 maximum HP and +5% speed for 5 minutes."},
	"frost_tea": {"name": "Frost Tea", "icon": 69, "tint": Color("a8d8f0"), "material_rarity": 1, "use": {"buff": "food", "name": "Well Fed", "duration": 300.0, "mods": {"stamina_regen": {"percent": 0.4}, "max_stamina": {"flat": 25.0}}}, "text": "Stamina comes back 40% faster; +25 stamina for 5 minutes."},
	"glowshroom_soup": {"name": "Glowshroom Soup", "icon": 69, "tint": Color("3ab088"), "material_rarity": 1, "use": {"buff": "food", "name": "Well Fed", "duration": 300.0, "mods": {"mana_regen": {"percent": 0.6}, "max_mana": {"flat": 30.0}}}, "text": "Mana comes back 60% faster; +30 mana for 5 minutes."},
	"thornberry_jam": {"name": "Thornberry Jam", "icon": 70, "tint": Color("b02a3a"), "material_rarity": 1, "use": {"buff": "food", "name": "Well Fed", "duration": 300.0, "mods": {"critical_chance": {"flat": 0.06}}}, "text": "+6% critical-hit chance for 5 minutes."},
	"ember_stew": {"name": "Ember Stew", "icon": 69, "tint": Color("f08a2e"), "material_rarity": 2, "use": {"buff": "food", "name": "Well Fed", "duration": 300.0, "mods": {"physical_damage": {"percent": 0.12}, "max_health": {"flat": 60.0}}}, "text": "+12% damage and +60 maximum HP for 5 minutes."},
	# --- drinks and treats: each course is its own buff, so a meal, a drink
	# and a treat can all be working at once (see ItemDB.course_of)
	"hunters_brew": {"name": "Hunter's Brew", "icon": 47, "tint": Color("b8743a"), "material_rarity": 0, "use": {"buff": "food", "name": "Refreshed", "duration": 300.0, "mods": {"attack_speed": {"percent": 0.1}, "critical_chance": {"flat": 0.04}}}, "value": 22, "text": "Dark and bitter. +10% attack speed and +4% critical-hit chance for 5 minutes."},
	"swiftfoot_tea": {"name": "Swiftfoot Tea", "icon": 47, "tint": Color("8ad0b0"), "material_rarity": 1, "use": {"buff": "food", "name": "Refreshed", "duration": 300.0, "mods": {"move_speed": {"percent": 0.1}, "stamina_regen": {"percent": 0.3}}}, "value": 30, "text": "+10% movement speed and stamina back 30% faster for 5 minutes."},
	"ironbark_tonic": {"name": "Ironbark Tonic", "icon": 47, "tint": Color("8a6a48"), "material_rarity": 1, "use": {"buff": "food", "name": "Refreshed", "duration": 300.0, "mods": {"armor": {"percent": 0.15}, "knockback_resistance": {"flat": 0.25}}}, "value": 34, "text": "+15% armor and hard to knock down for 5 minutes."},
	"sages_infusion": {"name": "Sage's Infusion", "icon": 47, "tint": Color("7aa8ff"), "material_rarity": 1, "use": {"buff": "food", "name": "Refreshed", "duration": 360.0, "mods": {"magic_power": {"percent": 0.1}, "mana_regen": {"percent": 0.4}}}, "value": 40, "text": "+10% magic damage and mana back 40% faster for 6 minutes."},
	"ember_ale": {"name": "Ember Ale", "icon": 47, "tint": Color("f08a2e"), "material_rarity": 2, "use": {"buff": "food", "name": "Refreshed", "duration": 300.0, "mods": {"fire_damage": {"flat": 6.0}, "fire_resist": {"flat": 0.15}}}, "value": 55, "text": "Warms all the way down. +6 fire damage and +15% fire resistance for 5 minutes."},
	"sunroot_cordial": {"name": "Sunroot Cordial", "icon": 47, "tint": Color("ffe060"), "material_rarity": 2, "use": {"buff": "food", "name": "Refreshed", "duration": 360.0, "mods": {"holy_damage": {"flat": 6.0}, "health_regen": {"flat": 1.5}}}, "value": 70, "text": "+6 holy damage and +1.5 health a second for 6 minutes."},
	"sweet_roll": {"name": "Sweet Roll", "icon": 70, "tint": Color("e0b070"), "material_rarity": 0, "use": {"buff": "food", "name": "Sweet Tooth", "duration": 300.0, "mods": {"critical_damage": {"flat": 0.1}, "dodge_efficiency": {"flat": 0.05}}}, "value": 18, "text": "+10% critical damage and dodges cost less for 5 minutes."},
	"candied_frostberries": {"name": "Candied Frostberries", "icon": 80, "tint": Color("a8d8f0"), "material_rarity": 1, "use": {"buff": "food", "name": "Sweet Tooth", "duration": 300.0, "mods": {"frost_resist": {"flat": 0.15}, "max_mana": {"flat": 20.0}}}, "value": 32, "text": "+15% frost resistance and +20 mana for 5 minutes."},
	"pumpkin_bread": {"name": "Pumpkin Bread", "icon": 70, "tint": Color("e09a40"), "material_rarity": 1, "use": {"buff": "food", "name": "Sweet Tooth", "duration": 360.0, "mods": {"max_stamina": {"flat": 30.0}, "stamina_regen": {"percent": 0.2}}}, "value": 36, "text": "+30 stamina and stamina back 20% faster for 6 minutes."},
	"aloe_salve": {"name": "Aloe Salve", "icon": 47, "tint": Color("aac87a"), "material_rarity": 0, "use": {"heal": 0.3, "buff": "salve", "name": "Soothed", "duration": 20.0, "mods": {"health_regen": {"flat": 3.0}}}, "text": "Restores 30% health and more over 20 seconds."},
	"bloodcap_draught": {"name": "Bloodcap Draught", "icon": 47, "tint": Color("c02a3a"), "material_rarity": 2, "use": {"buff": "draught", "name": "Bloodthirst", "duration": 90.0, "mods": {"life_steal": {"flat": 0.05}}}, "text": "Heal for 5% of damage dealt for 90 seconds."},
	"void_tonic": {"name": "Void Tonic", "icon": 47, "tint": Color("9a6cf0"), "material_rarity": 3, "use": {"buff": "tonic", "name": "Void-touched", "duration": 90.0, "mods": {"magic_power": {"percent": 0.25}}}, "text": "+25% magic damage for 90 seconds."},
	"bandage": {"name": "Bandage", "icon": 43, "tint": Color("f4f2ec"), "material_rarity": 0, "use": {"heal": 0.2}, "value": 8, "text": "Rough cloth and herbs. Restores 20% health."},
	"torch": {"name": "Torch", "icon": 94, "tint": Color("f08a2e"), "material_rarity": 0, "place": "torch", "value": 4, "text": "Carried, one lights itself in caves and after dark and burns for four minutes. Use it to plant it in the ground as a lasting light."},
	"venom_sac": {"name": "Venom Sac", "icon": 16, "tint": Color("b06ad0"), "material_rarity": 1, "text": "Handle with care."},
	"ember_core": {"name": "Ember Core", "icon": 16, "tint": Color("f08a2e"), "material_rarity": 2, "text": "Still warm."},
	"stone_heart": {"name": "Stone Heart", "icon": 42, "tint": Color("8a8794"), "material_rarity": 2, "text": "The slow-beating core of a golem."},
	# --- consumables: "use" is what happens when used
	"health_potion": {"name": "Health Potion", "icon": 47, "tint": Color("e0555a"), "material_rarity": 0, "use": {"heal": 0.4}, "text": "Restores 40% of your health."},
	"mana_potion": {"name": "Mana Potion", "icon": 47, "tint": Color("4f9dff"), "material_rarity": 0, "use": {"mana": 0.6}, "text": "Restores 60% of your mana."},
	"stamina_tonic": {"name": "Stamina Tonic", "icon": 47, "tint": Color("f0cf6a"), "material_rarity": 0, "use": {"stamina": 1.0}, "text": "Fully restores your stamina."},
	"might_elixir": {"name": "Might Elixir", "icon": 47, "tint": Color("f08a2e"), "material_rarity": 1, "use": {"buff": "might", "name": "Might", "duration": 90.0, "mods": {"physical_damage": {"percent": 0.15}}}, "text": "+15% damage for 90 seconds."},
	"grilled_minnow": {"name": "Grilled Minnow", "icon": 72, "tint": Color("e0c090"), "material_rarity": 0, "use": {"buff": "food", "name": "Well Fed", "duration": 300.0, "mods": {"max_health": {"flat": 20.0}, "health_regen": {"flat": 0.5}}}, "text": "+20 maximum HP and regeneration for 5 minutes."},
	"trout_stew": {"name": "Trout Stew", "icon": 69, "tint": Color("f0a060"), "material_rarity": 1, "use": {"buff": "food", "name": "Well Fed", "duration": 300.0, "mods": {"max_health": {"flat": 60.0}, "max_stamina": {"flat": 20.0}}}, "text": "+60 maximum HP and +20 stamina for 5 minutes."},
	"eel_pie": {"name": "Eel Pie", "icon": 70, "tint": Color("c09060"), "material_rarity": 2, "use": {"buff": "food", "name": "Well Fed", "duration": 300.0, "mods": {"max_health": {"flat": 100.0}, "physical_damage": {"percent": 0.08}}}, "text": "+100 maximum HP and +8% damage for 5 minutes."},
	# --- things to place in the world: "place" is the kind of building
	"rug": {"name": "Woven Rug", "decor": Prop.Decor.RUG, "icon": 54, "material_rarity": 0, "place": "rug", "value": 20, "text": "A warm rug for the floor. Use it to set it down."},
	"bookshelf": {"name": "Bookshelf", "decor": Prop.Decor.SHELF, "icon": 54, "material_rarity": 0, "place": "bookshelf", "value": 40, "text": "Shelves of old books and jars. Use it to set it down."},
	"potted_plant": {"name": "Potted Plant", "decor": Prop.Decor.PLANT_POT, "icon": 54, "material_rarity": 0, "place": "potted_plant", "value": 15, "text": "A little green for the house. Use it to set it down."},
	"dining_table": {"name": "Dining Table", "decor": Prop.Decor.TABLE, "icon": 54, "material_rarity": 0, "place": "dining_table", "value": 35, "text": "A sturdy table to eat at. Use it to set it down."},
	"chair": {"name": "Chair", "decor": Prop.Decor.CHAIR, "icon": 54, "material_rarity": 0, "place": "chair", "value": 12, "text": "Somewhere to sit. Use it to set it down."},
	"candles": {"name": "Candles", "decor": Prop.Decor.CANDLES, "icon": 54, "material_rarity": 0, "place": "candles", "value": 10, "text": "A cluster of candles. Gives light. Use it to set it down."},
	"fireplace": {"name": "Fireplace", "decor": Prop.Decor.FIREPLACE, "icon": 54, "material_rarity": 0, "place": "fireplace", "value": 70, "text": "A stone hearth with a chimney and a fire that never goes out. Warms and lights a room. Use it to set it down."},
	"wall_banner": {"name": "Banner", "decor": Prop.Decor.BANNER, "icon": 54, "material_rarity": 0, "place": "wall_banner", "value": 25, "text": "A red banner on a pole. Use it to set it down."},
	"barrel": {"name": "Barrel", "decor": Prop.Decor.BARREL, "icon": 54, "material_rarity": 0, "place": "barrel", "value": 12, "text": "A plain oak barrel. Use it to set it down."},
	"crate": {"name": "Crate", "decor": Prop.Decor.CRATE, "icon": 54, "material_rarity": 0, "place": "crate", "value": 10, "text": "A wooden crate. Use it to set it down."},
	"stone_statue": {"name": "Stone Statue", "decor": Prop.Decor.STATUE, "icon": 54, "material_rarity": 0, "place": "stone_statue", "value": 80, "text": "A carved figure of a forgotten hero. Use it to set it down."},
	"brazier": {"name": "Brazier", "decor": Prop.Decor.BRAZIER, "icon": 54, "material_rarity": 0, "place": "brazier", "value": 45, "text": "An iron bowl of fire. Gives light. Use it to set it down."},
	"fence": {"name": "Fence", "decor": Prop.Decor.FENCE, "icon": 54, "material_rarity": 0, "place": "fence", "value": 6, "text": "A short length of fence. Use it to set it down."},
	"lantern_post": {"name": "Lantern Post", "decor": Prop.Decor.LANTERN, "icon": 54, "material_rarity": 0, "place": "lantern_post", "value": 30, "text": "A lantern on a post. Gives light. Use it to set it down."},
	"floor_plank": {"name": "Plank Floor", "icon": 42, "tint": Color("b08a5a"), "floor": TerrainTiles.Type.PLANK, "material_rarity": 0, "place": "floor", "value": 3, "text": "Lays one tile of floor inside a house. Use it, then click a tile."},
	"floor_stone": {"name": "Stone Floor", "icon": 42, "tint": Color("8f8a90"), "floor": TerrainTiles.Type.CAVE_FLOOR, "material_rarity": 0, "place": "floor", "value": 3, "text": "Lays one tile of floor inside a house. Use it, then click a tile."},
	"floor_cobble": {"name": "Cobble Floor", "icon": 42, "tint": Color("a39478"), "floor": TerrainTiles.Type.PATH, "material_rarity": 0, "place": "floor", "value": 3, "text": "Lays one tile of floor inside a house. Use it, then click a tile."},
	"floor_moss": {"name": "Moss Floor", "icon": 42, "tint": Color("4f7a46"), "floor": TerrainTiles.Type.DARK_GRASS, "material_rarity": 0, "place": "floor", "value": 3, "text": "Lays one tile of floor inside a house. Use it, then click a tile."},
	"floor_sand": {"name": "Sandstone Floor", "icon": 42, "tint": Color("d8c08a"), "floor": TerrainTiles.Type.SAND, "material_rarity": 0, "place": "floor", "value": 3, "text": "Lays one tile of floor inside a house. Use it, then click a tile."},
	"floor_snow": {"name": "Snow Floor", "icon": 42, "tint": Color("e6eef6"), "floor": TerrainTiles.Type.SNOW, "material_rarity": 0, "place": "floor", "value": 3, "text": "Lays one tile of floor inside a house. Use it, then click a tile."},
	"rowboat": {"name": "Rowboat", "icon": 43, "tint": Color("a07850"), "boat": true, "material_rarity": 1, "value": 120, "text": "Use it at the water's edge to sail. Step onto land to stow it again."},
	"treasure_map": {"name": "Treasure Map", "icon": 53, "tint": Color("e8d098"), "treasure_map": true, "material_rarity": 2, "value": 60, "text": "Read it to mark where something is buried. Then find the spot and dig."},
	# --- farming
	"farm_plot": {"name": "Farm Plot", "decor": Prop.Decor.SOIL, "icon": 54, "material_rarity": 0, "place": "plot", "value": 10, "text": "A bed of tilled earth. Set it down outdoors, sow seeds, water, and harvest."},
	"scarecrow": {"name": "Scarecrow", "decor": Prop.Decor.SCARECROW, "icon": 54, "material_rarity": 0, "place": "scarecrow", "value": 20, "text": "Crops near it grow a quarter faster."},
	"wheat_seeds": {"name": "Wheat Seeds", "icon": 90, "tint": Color("d8c070"), "material_rarity": 0, "value": 3, "text": "Sow in a farm plot. Ripens in about a day."},
	"carrot_seeds": {"name": "Carrot Seeds", "icon": 90, "tint": Color("f09040"), "material_rarity": 0, "value": 3, "text": "Sow in a farm plot. Quick to ripen."},
	"potato_seeds": {"name": "Seed Potatoes", "icon": 90, "tint": Color("c0a070"), "material_rarity": 0, "value": 3, "text": "Sow in a farm plot."},
	"pumpkin_seeds": {"name": "Pumpkin Seeds", "icon": 90, "tint": Color("f0a040"), "material_rarity": 1, "value": 8, "text": "Sow in a farm plot. Slow, but worth it."},
	"frostberry_seeds": {"name": "Frostberry Seeds", "icon": 90, "tint": Color("a0d8f0"), "material_rarity": 1, "value": 10, "text": "Sow in a farm plot. Found in the cold lands."},
	"sunroot_seeds": {"name": "Sunroot Seeds", "icon": 90, "tint": Color("f8e070"), "material_rarity": 2, "value": 25, "text": "Sow in a farm plot. Rare, and slow to grow."},
	"wheat": {"name": "Wheat", "icon": 79, "tint": Color("e8d080"), "material_rarity": 0, "value": 4, "text": "Grind it, bake it."},
	"carrot": {"name": "Carrot", "icon": 76, "tint": Color("ff8a2e"), "material_rarity": 0, "use": {"heal": 0.06}, "value": 4, "text": "Crunchy. Restores a little health."},
	"potato": {"name": "Potato", "icon": 77, "tint": Color("c8a878"), "material_rarity": 0, "value": 4, "text": "Better cooked."},
	"pumpkin": {"name": "Pumpkin", "icon": 78, "tint": Color("ff9a2e"), "material_rarity": 1, "value": 12, "text": "Heavy, round and orange."},
	"frostberry": {"name": "Frostberries", "icon": 80, "tint": Color("a8e0ff"), "material_rarity": 1, "use": {"heal": 0.1}, "value": 8, "text": "Cold and sweet. Restores some health."},
	"sunroot": {"name": "Sunroot", "icon": 44, "tint": Color("ffe060"), "material_rarity": 2, "value": 30, "text": "It glows faintly, even at night."},
	"bread": {"name": "Bread", "icon": 71, "tint": Color("d8a860"), "material_rarity": 0, "use": {"buff": "food", "name": "Well Fed", "duration": 360.0, "mods": {"max_stamina": {"flat": 25.0}, "stamina_regen": {"percent": 0.25}}}, "value": 14, "text": "+25 stamina and stamina returns 25% faster for 6 minutes."},
	"carrot_stew": {"name": "Carrot Stew", "icon": 69, "tint": Color("f0a050"), "material_rarity": 1, "use": {"buff": "food", "name": "Well Fed", "duration": 360.0, "mods": {"max_health": {"flat": 40.0}, "health_regen": {"flat": 1.0}}}, "value": 24, "text": "+40 maximum HP and +1 HP per second for 6 minutes."},
	"baked_potato": {"name": "Baked Potato", "icon": 77, "tint": Color("b88850"), "material_rarity": 0, "use": {"heal": 0.25}, "value": 10, "text": "Restores a quarter of your health."},
	"pumpkin_pie": {"name": "Pumpkin Pie", "icon": 70, "tint": Color("e88a30"), "material_rarity": 2, "use": {"buff": "food", "name": "Feast", "duration": 480.0, "mods": {"max_health": {"percent": 0.1}, "physical_damage": {"percent": 0.08}, "magic_find": {"flat": 0.1}}}, "value": 60, "text": "+10% maximum HP, +8% damage and +10% magic find for 8 minutes."},
	"frostberry_tart": {"name": "Frostberry Tart", "icon": 70, "tint": Color("a0d0f0"), "material_rarity": 1, "use": {"buff": "food", "name": "Well Fed", "duration": 360.0, "mods": {"frost_resist": {"flat": 0.25}, "fire_resist": {"flat": 0.15}, "max_mana": {"flat": 25.0}}}, "value": 30, "text": "+25% frost and +15% fire resistance, +25 mana for 6 minutes."},
	"sunroot_elixir": {"name": "Sunroot Elixir", "icon": 47, "tint": Color("ffe060"), "material_rarity": 2, "use": {"buff": "sunroot", "name": "Sunlit", "duration": 300.0, "mods": {"holy_damage": {"flat": 8.0}, "shadow_resist": {"flat": 0.3}, "critical_chance": {"flat": 0.05}}}, "value": 90, "text": "+8 holy damage, +30% shadow resistance and +5% critical chance for 5 minutes."},
	# --- defences
	"palisade_wall": {"name": "Palisade", "decor": Prop.Decor.PALISADE, "icon": 54, "material_rarity": 0, "place": "palisade", "value": 12, "text": "A wall of sharpened logs. Monsters must go round."},
	"spike_trap": {"name": "Spike Trap", "decor": Prop.Decor.SPIKE_TRAP, "icon": 54, "material_rarity": 0, "place": "spikes", "value": 20, "text": "Hurts monsters that walk over it."},
	"ballista": {"name": "Ballista", "decor": Prop.Decor.BALLISTA, "icon": 54, "material_rarity": 1, "place": "ballista", "value": 80, "text": "Looses bolts at monsters that come near."},
	"taming_treat": {"name": "Taming Treat", "icon": 48, "tint": Color("e0a0c0"), "material_rarity": 1, "value": 25, "text": "Use beside a small creature, or a monster beaten to its last legs, to tame it as a pet."},
	"pony_whistle": {"name": "Pony Whistle", "icon": 51, "tint": Color("d8b890"), "mount": "pony", "material_rarity": 1, "value": 300, "text": "Calls a pony to ride. Press H to mount and dismount."},
	"horse_whistle": {"name": "Horse Whistle", "icon": 51, "tint": Color("b08050"), "mount": "horse", "material_rarity": 2, "value": 900, "text": "Calls a horse to ride. Press H to mount and dismount."},
	"frost_elk_whistle": {"name": "Frost Elk Horn", "icon": 51, "tint": Color("c0e8ff"), "mount": "frost_elk", "material_rarity": 3, "value": 1500, "text": "Calls a frost elk: snow and blizzards cannot slow or chill it."},
	"sand_strider_whistle": {"name": "Sand Strider Whistle", "icon": 51, "tint": Color("f0c070"), "mount": "sand_strider", "material_rarity": 3, "value": 1500, "text": "Calls a sand strider: sand and sandstorms cannot slow it."},
	"nightmare_whistle": {"name": "Nightmare Bell", "icon": 51, "tint": Color("8a5aa0"), "mount": "nightmare", "material_rarity": 4, "value": 4000, "text": "Calls a nightmare: the fastest steed, and blows cannot unseat you."},
	# --- hunting: what wild animals give, and what to make of it
	"venison": {"name": "Raw Venison", "icon": 66, "tint": Color("b84a4a"), "material_rarity": 0, "use": {"heal": 0.05}, "value": 6, "text": "Better cooked. Restores a little health raw."},
	"deer_hide": {"name": "Deer Hide", "icon": 82, "tint": Color("a07050"), "material_rarity": 0, "value": 8, "text": "Soft and supple. Tan it into leather."},
	"antler": {"name": "Antler", "icon": 86, "tint": Color("e8dcc0"), "material_rarity": 1, "value": 14, "text": "A shed crown of bone."},
	"hare_meat": {"name": "Hare Meat", "icon": 66, "tint": Color("c86a5a"), "material_rarity": 0, "use": {"heal": 0.04}, "value": 4, "text": "Lean meat. Better cooked."},
	"hare_pelt": {"name": "Hare Pelt", "icon": 82, "tint": Color("b89a80"), "material_rarity": 0, "value": 5, "text": "Small and soft."},
	"pork": {"name": "Raw Pork", "icon": 66, "tint": Color("e08a8a"), "material_rarity": 0, "use": {"heal": 0.05}, "value": 6, "text": "Cook it before you eat it."},
	"pig_hide": {"name": "Pig Hide", "icon": 82, "tint": Color("d8a0a0"), "material_rarity": 0, "value": 6, "text": "Thick and bristly."},
	"goat_meat": {"name": "Goat Meat", "icon": 66, "tint": Color("b85a50"), "material_rarity": 0, "use": {"heal": 0.05}, "value": 7, "text": "Tough and gamey."},
	"goat_horn": {"name": "Goat Horn", "icon": 85, "tint": Color("6a5040"), "material_rarity": 1, "value": 12, "text": "Curled and hard as stone."},
	"mutton": {"name": "Raw Mutton", "icon": 66, "tint": Color("c86a6a"), "material_rarity": 0, "use": {"heal": 0.05}, "value": 6, "text": "Fatty and rich. Better roasted."},
	"beef": {"name": "Raw Beef", "icon": 66, "tint": Color("b03a3a"), "material_rarity": 0, "use": {"heal": 0.05}, "value": 8, "text": "A good red cut. Cook it."},
	"cow_hide": {"name": "Cow Hide", "icon": 82, "tint": Color("c8b8a0"), "material_rarity": 0, "value": 9, "text": "A big, tough hide. Tans into plenty of leather."},
	"chicken_meat": {"name": "Raw Chicken", "icon": 68, "tint": Color("f0d0b0"), "material_rarity": 0, "use": {"heal": 0.03}, "value": 4, "text": "Do cook this one."},
	"egg": {"name": "Egg", "icon": 133, "material_rarity": 0, "use": {"heal": 0.03}, "value": 3, "text": "Still warm. Good in a pan."},
	"feather": {"name": "Feather", "icon": 84, "tint": Color("f4f0e8"), "material_rarity": 0, "value": 2, "text": "Soft and white."},
	"bear_meat": {"name": "Bear Meat", "icon": 66, "tint": Color("8a3030"), "material_rarity": 1, "use": {"heal": 0.06}, "value": 12, "text": "Dark, strong meat. It wants a long stew."},
	"bear_pelt": {"name": "Bear Pelt", "icon": 82, "tint": Color("7a5236"), "material_rarity": 1, "value": 30, "text": "Thick enough to sleep on. Tans into a lot of leather."},
	"spider_silk": {"name": "Spider Silk", "icon": 89, "tint": Color("e8e8f4"), "material_rarity": 1, "value": 10, "text": "Stronger than it has any right to be."},
	"roast_mutton": {"name": "Roast Mutton", "icon": 67, "tint": Color("b86a48"), "material_rarity": 0, "use": {"buff": "food", "name": "Well Fed", "duration": 360.0, "mods": {"max_health": {"flat": 30.0}, "health_regen": {"flat": 0.8}}}, "value": 20, "text": "+30 maximum HP and +0.8 health a second for 6 minutes."},
	"beef_steak": {"name": "Beef Steak", "icon": 67, "tint": Color("9a4a30"), "material_rarity": 0, "use": {"buff": "food", "name": "Well Fed", "duration": 420.0, "mods": {"physical_damage": {"percent": 0.06}, "max_health": {"flat": 30.0}}}, "value": 28, "text": "+6% damage and +30 maximum HP for 7 minutes."},
	"roast_chicken": {"name": "Roast Chicken", "icon": 68, "tint": Color("d89850"), "material_rarity": 0, "use": {"buff": "food", "name": "Well Fed", "duration": 300.0, "mods": {"stamina_regen": {"percent": 0.2}, "max_health": {"flat": 15.0}}}, "value": 14, "text": "Stamina returns 20% faster and +15 maximum HP for 5 minutes."},
	"omelette": {"name": "Omelette", "icon": 71, "tint": Color("f0d060"), "material_rarity": 0, "use": {"heal": 0.25}, "value": 10, "text": "Quick, hot and filling. Restores 25% of your health."},
	"bear_stew": {"name": "Bear Stew", "icon": 69, "tint": Color("7a4a30"), "material_rarity": 1, "use": {"buff": "food", "name": "Well Fed", "duration": 480.0, "mods": {"max_health": {"flat": 60.0}, "armor": {"percent": 0.08}}}, "value": 50, "text": "+60 maximum HP and +8% armour for 8 minutes."},
	"wool": {"name": "Wool", "icon": 89, "tint": Color("f0ece4"), "material_rarity": 0, "value": 5, "text": "Warm, white and itchy."},
	"pheasant_meat": {"name": "Pheasant", "icon": 68, "tint": Color("d89070"), "material_rarity": 0, "use": {"heal": 0.04}, "value": 6, "text": "A plump bird for the pot."},
	"pheasant_feather": {"name": "Pheasant Feather", "icon": 84, "tint": Color("c86a3a"), "material_rarity": 0, "value": 4, "text": "Long, bright and barred."},
	"lizard_meat": {"name": "Lizard Meat", "icon": 66, "tint": Color("c8a070"), "material_rarity": 0, "use": {"heal": 0.04}, "value": 5, "text": "Tastes like chicken, almost."},
	"lizard_scale": {"name": "Lizard Scales", "icon": 88, "tint": Color("d8b878"), "material_rarity": 0, "value": 6, "text": "Tough little plates."},
	"fox_pelt": {"name": "Snow Fox Pelt", "icon": 82, "tint": Color("f4f8fc"), "material_rarity": 1, "value": 18, "text": "The softest fur in the north."},
	"crab_meat": {"name": "Crab Meat", "icon": 66, "tint": Color("f0a090"), "material_rarity": 0, "use": {"heal": 0.05}, "value": 7, "text": "Sweet, once you get it out."},
	"crab_shell": {"name": "Crab Shell", "icon": 87, "tint": Color("d84a3a"), "material_rarity": 0, "value": 6, "text": "Hard and red."},
	"toad_legs": {"name": "Toad Legs", "icon": 68, "tint": Color("8aa85a"), "material_rarity": 0, "value": 4, "text": "A delicacy, they say."},
	"toad_slime": {"name": "Toad Slime", "icon": 16, "tint": Color("a8d070"), "material_rarity": 0, "value": 5, "text": "Numbing. Alchemists like it."},
	"leather": {"name": "Leather", "icon": 83, "tint": Color("8a5a3a"), "material_rarity": 0, "value": 14, "text": "Tanned hide, ready to stitch."},
	"roast_venison": {"name": "Roast Venison", "icon": 67, "tint": Color("a85030"), "material_rarity": 0, "use": {"buff": "food", "name": "Well Fed", "duration": 360.0, "mods": {"max_health": {"flat": 35.0}, "physical_damage": {"percent": 0.04}}}, "value": 22, "text": "+35 maximum HP and +4% damage for 6 minutes."},
	"hare_stew": {"name": "Hare Stew", "icon": 69, "tint": Color("b87850"), "material_rarity": 0, "use": {"buff": "food", "name": "Well Fed", "duration": 360.0, "mods": {"health_regen": {"flat": 1.2}, "max_stamina": {"flat": 20.0}}}, "value": 24, "text": "+1.2 HP per second and +20 stamina for 6 minutes."},
	"grilled_pork": {"name": "Grilled Pork", "icon": 67, "tint": Color("c86a4a"), "material_rarity": 0, "use": {"heal": 0.3}, "value": 14, "text": "Restores 30% of your health."},
	"pork_pie": {"name": "Pork Pie", "icon": 70, "tint": Color("d89a5a"), "material_rarity": 1, "use": {"buff": "food", "name": "Well Fed", "duration": 420.0, "mods": {"max_health": {"flat": 50.0}, "max_stamina": {"flat": 25.0}}}, "value": 34, "text": "+50 maximum HP and +25 stamina for 7 minutes."},
	"goat_skewer": {"name": "Goat Skewer", "icon": 73, "tint": Color("a85a40"), "material_rarity": 0, "use": {"buff": "food", "name": "Well Fed", "duration": 360.0, "mods": {"physical_damage": {"percent": 0.07}, "armor": {"percent": 0.05}}}, "value": 26, "text": "+7% damage and +5% armour for 6 minutes."},
	"roast_pheasant": {"name": "Roast Pheasant", "icon": 68, "tint": Color("c88050"), "material_rarity": 0, "use": {"buff": "food", "name": "Well Fed", "duration": 360.0, "mods": {"move_speed": {"percent": 0.06}, "max_health": {"flat": 20.0}}}, "value": 22, "text": "+6% movement speed and +20 maximum HP for 6 minutes."},
	"fried_toad_legs": {"name": "Fried Toad Legs", "icon": 68, "tint": Color("98a860"), "material_rarity": 0, "use": {"buff": "food", "name": "Well Fed", "duration": 360.0, "mods": {"poison_resist": {"flat": 0.25}, "health_regen": {"flat": 0.6}}}, "value": 20, "text": "+25% poison resistance and +0.6 HP per second for 6 minutes."},
	"spiced_lizard": {"name": "Spiced Lizard", "icon": 73, "tint": Color("d8984a"), "material_rarity": 0, "use": {"buff": "food", "name": "Well Fed", "duration": 360.0, "mods": {"fire_resist": {"flat": 0.25}, "max_stamina": {"flat": 15.0}}}, "value": 22, "text": "+25% fire resistance and +15 stamina for 6 minutes."},
	"crab_cakes": {"name": "Crab Cakes", "icon": 75, "tint": Color("e8a878"), "material_rarity": 1, "use": {"buff": "food", "name": "Well Fed", "duration": 360.0, "mods": {"max_mana": {"flat": 30.0}, "mana_regen": {"percent": 0.3}}}, "value": 28, "text": "+30 mana and mana returns 30% faster for 6 minutes."},
	"jerky": {"name": "Jerky", "icon": 74, "tint": Color("8a4a30"), "material_rarity": 0, "use": {"heal": 0.15}, "value": 8, "text": "Dried meat for the road. Restores 15% of your health."},
	"hunters_feast": {"name": "Hunter's Feast", "icon": 81, "tint": Color("c86030"), "material_rarity": 2, "use": {"buff": "food", "name": "Feast", "duration": 600.0, "mods": {"max_health": {"percent": 0.12}, "physical_damage": {"percent": 0.1}, "critical_chance": {"flat": 0.05}}}, "value": 90, "text": "+12% maximum HP, +10% damage and +5% critical chance for 10 minutes."},
	# More fish.
	"perch": {"name": "Perch", "icon": 45, "tint": Color("a8c070"), "material_rarity": 0, "use": {"heal": 0.05}, "value": 8, "text": "Striped and spiny."},
	"pike": {"name": "Pike", "icon": 45, "tint": Color("7a9a6a"), "material_rarity": 1, "value": 16, "text": "All teeth and temper."},
	"salmon": {"name": "Salmon", "icon": 45, "tint": Color("f09070"), "material_rarity": 1, "value": 20, "text": "Rich, pink and prized."},
	"catfish": {"name": "Catfish", "icon": 45, "tint": Color("8a7a6a"), "material_rarity": 1, "value": 24, "text": "Whiskered bottom-dweller."},
	"glowfin": {"name": "Glowfin", "icon": 45, "tint": Color("8ff0e0"), "material_rarity": 2, "value": 45, "text": "It lights up the bucket."},
	"golden_carp": {"name": "Golden Carp", "icon": 45, "tint": Color("f0c840"), "material_rarity": 3, "value": 120, "text": "A fish of legend. Lucky, they say."},
	"salmon_steak": {"name": "Salmon Steak", "icon": 72, "tint": Color("f08a6a"), "material_rarity": 1, "use": {"buff": "food", "name": "Well Fed", "duration": 420.0, "mods": {"max_health": {"flat": 40.0}, "mana_regen": {"percent": 0.25}}}, "value": 40, "text": "+40 maximum HP and mana returns 25% faster for 7 minutes."},
	"pike_chowder": {"name": "Pike Chowder", "icon": 69, "tint": Color("e8d8b0"), "material_rarity": 1, "use": {"buff": "food", "name": "Well Fed", "duration": 420.0, "mods": {"frost_resist": {"flat": 0.2}, "health_regen": {"flat": 1.0}}}, "value": 36, "text": "+20% frost resistance and +1 HP per second for 7 minutes."},
	"glowfin_soup": {"name": "Glowfin Soup", "icon": 69, "tint": Color("8fe8d8"), "material_rarity": 2, "use": {"buff": "food", "name": "Glowing", "duration": 480.0, "mods": {"shadow_resist": {"flat": 0.25}, "magic_find": {"flat": 0.1}}}, "value": 70, "text": "+25% shadow resistance and +10% magic find for 8 minutes."},
	"golden_platter": {"name": "Golden Platter", "icon": 81, "tint": Color("f0c850"), "material_rarity": 3, "use": {"buff": "food", "name": "Feast", "duration": 600.0, "mods": {"magic_find": {"flat": 0.25}, "gold_find": {"percent": 0.25}, "max_health": {"percent": 0.1}}}, "value": 220, "text": "+25% magic find, +25% gold found and +10% maximum HP for 10 minutes."},
	# Leather gear: light armour for early hunters.
	"leather_cap": {"name": "Leather Cap", "icon": 96, "tint": Color("a87a50"), "slot": "helmet", "drop_weight": 0.0, "armor": 3.0,
		"implicit": [{"stat": "agility", "kind": "flat", "base": 1.0, "per_level": 0.05}]},
	"leather_vest": {"name": "Leather Vest", "icon": 97, "tint": Color("a87a50"), "slot": "chest", "drop_weight": 0.0, "armor": 6.0,
		"implicit": [{"stat": "move_speed", "kind": "flat", "base": 6.0, "per_level": 0.1}]},
	"leather_leggings": {"name": "Leather Leggings", "icon": 98, "tint": Color("a87a50"), "slot": "legs", "drop_weight": 0.0, "armor": 4.0,
		"implicit": [{"stat": "max_stamina", "kind": "flat", "base": 10.0, "per_level": 0.4}]},
	"leather_boots": {"name": "Leather Boots", "icon": 99, "tint": Color("a87a50"), "slot": "boots", "drop_weight": 0.0, "armor": 2.0,
		"implicit": [{"stat": "move_speed", "kind": "flat", "base": 8.0, "per_level": 0.1}]},
	"fur_cloak": {"name": "Fur Mantle", "icon": 100, "tint": Color("e8eef4"), "slot": "chest", "drop_weight": 0.0, "armor": 7.0,
		"implicit": [{"stat": "frost_resist", "kind": "flat", "base": 0.2, "per_level": 0.0}]},
	"crafting_table": {"name": "Crafting Table", "icon": 54, "material_rarity": 0, "place": "table", "value": 30, "text": "Stand beside one to craft. Use it from your bag to set it down."},
	"furnace": {"name": "Furnace", "decor": Prop.Decor.FURNACE, "icon": 54, "material_rarity": 0, "place": "furnace", "value": 60,
		"text": "Smelts ore into ingots, one ore to one ingot, slowly, as long as there is coal in it. Use it from your bag to set it down."},
	"coal": {"name": "Coal", "icon": 138, "material_rarity": 0, "value": 4, "text": "Black and greasy. A furnace burns one lump for every eight ores it smelts. Mined from coal seams, or burned from wood."},
	"farmhouse_kit": {"name": "Farmhouse", "decor": Prop.Decor.FARMHOUSE, "icon": 54, "material_rarity": 1, "place": "farmhouse", "value": 200,
		"text": "A little red barn for a farm. Feed a sheep, cow or chicken wheat and it follows you; lead it here and it stays, leaving wool, milk or eggs inside. Feed two of a kind here and they raise young."},
	"milk": {"name": "Milk", "icon": 134, "material_rarity": 0, "value": 6, "text": "A jug of milk from your own cows."},
	"herb_omelette": {"name": "Herb Omelette", "icon": 135, "material_rarity": 1, "use": {"buff": "food", "name": "Farm Breakfast", "duration": 360.0, "mods": {"max_health": {"percent": 0.08}, "health_regen": {"flat": 1.0}}}, "value": 24, "text": "+8% maximum health and health back faster for 6 minutes."},
	"cheese": {"name": "Wheel of Cheese", "icon": 136, "material_rarity": 1, "use": {"buff": "food", "name": "Hearty", "duration": 480.0, "mods": {"armor": {"percent": 0.1}, "max_stamina": {"flat": 20.0}}}, "value": 30, "text": "+10% armour and +20 stamina for 8 minutes."},
	"custard_tart": {"name": "Custard Tart", "icon": 137, "material_rarity": 1, "use": {"buff": "food", "name": "Sweet Tooth", "duration": 360.0, "mods": {"attack_speed": {"percent": 0.06}, "move_speed": {"percent": 0.04}}}, "value": 32, "text": "+6% attack speed and +4% speed for 6 minutes."},
	# --- root-tech: living stumps that work for you (see RootMachine)
	"rootling_woodcutter": {"name": "Rootling Woodcutter", "decor": Prop.Decor.ROOT_CUTTER, "icon": 54, "material_rarity": 2, "place": "root_cutter", "value": 400,
		"text": "A stump that has learned to work: its root arm creeps out to the nearest tree, fells it, and brings the wood home. Set it near trees, outdoors."},
	"rootling_delver": {"name": "Rootling Delver", "decor": Prop.Decor.ROOT_DELVER, "icon": 54, "material_rarity": 2, "place": "root_delver", "value": 500,
		"text": "Its roots grip stone and crack it open: it mines the ore veins around it. Set it near rocks, outdoors."},
	"rootling_tender": {"name": "Rootling Tender", "decor": Prop.Decor.ROOT_TENDER, "icon": 54, "material_rarity": 2, "place": "root_tender", "value": 400,
		"text": "Soft root fingers that pick herbs, water your farm plots, and harvest and replant them when ripe."},
	"root_hollow": {"name": "Root Hollow", "decor": Prop.Decor.ROOT_HOLLOW, "icon": 54, "material_rarity": 1, "place": "root_hollow", "value": 120,
		"text": "A great hollow stump. Root-tech nearby fills it with what it gathers. Holds 24 stacks."},
	"storage_chest": {"name": "Storage Chest", "icon": 55, "material_rarity": 0, "place": "chest", "value": 50, "text": "Holds 24 stacks. Use it from your bag to set it down."},
	"bed": {"name": "Bed", "icon": 57, "material_rarity": 0, "place": "bed", "value": 60, "text": "Sleep in it to make this place home. Use it from your bag to set it down."},
	# --- shaping the land: each lays one tile of ground outdoors (taken up
	# again, the land returns to what it was)
	"stone_path": {"name": "Path Stones", "icon": 42, "tint": Color("a39478"), "ground": TerrainTiles.Type.PATH, "material_rarity": 0, "place": "ground", "value": 2, "text": "Lays a tile of stone path outdoors."},
	"wooden_decking": {"name": "Wooden Decking", "icon": 43, "tint": Color("b08a5a"), "ground": TerrainTiles.Type.PLANK, "material_rarity": 0, "place": "ground", "value": 3, "text": "Lays a tile of plank decking outdoors."},
	"flagstones": {"name": "Flagstones", "icon": 42, "tint": Color("8f8a90"), "ground": TerrainTiles.Type.CAVE_FLOOR, "material_rarity": 0, "place": "ground", "value": 3, "text": "Lays a tile of flat grey stone outdoors."},
	"grass_turf": {"name": "Grass Turf", "icon": 44, "tint": Color("4e8a4a"), "ground": TerrainTiles.Type.DARK_GRASS, "material_rarity": 0, "place": "ground", "value": 2, "text": "Lays a tile of green grass, even on ash or sand."},
	"sand_sack": {"name": "Sack of Sand", "icon": 42, "tint": Color("c8b080"), "ground": TerrainTiles.Type.SAND, "material_rarity": 0, "place": "ground", "value": 2, "text": "Spreads a tile of sand."},
	"water_bucket": {"name": "Bucket of Water", "icon": 47, "tint": Color("5a8ac8"), "ground": TerrainTiles.Type.SHALLOW_WATER, "material_rarity": 0, "place": "ground", "value": 4, "text": "Digs a tile of shallow pond. Lay several for a pond."},
	# --- walls that join their neighbours, built tile by tile outdoors
	"wooden_wall": {"name": "Wooden Wall", "icon": 43, "tint": Color("8a6238"), "wall": "wood", "material_rarity": 0, "place": "wall", "value": 6, "text": "A tile of stake wall. Walls join their neighbours; leave a gap for a way through."},
	"stone_wall_block": {"name": "Stone Wall", "icon": 42, "tint": Color("a8a5b2"), "wall": "keep", "material_rarity": 0, "place": "wall", "value": 8, "text": "A tile of cut-stone wall with capstones. Walls join their neighbours."},
	"brick_wall": {"name": "Brick Wall", "icon": 126, "wall": "brick", "material_rarity": 0, "place": "wall", "value": 10, "text": "A tile of red brick in running bond, capped in stone. Walls join their neighbours."},
	"mossy_wall": {"name": "Mossy Stone Wall", "icon": 127, "wall": "mossy", "material_rarity": 0, "place": "wall", "value": 10, "text": "Old grey stone with ivy climbing it. Walls join their neighbours."},
	"marble_wall": {"name": "Marble Wall", "icon": 128, "wall": "marble", "material_rarity": 2, "place": "wall", "value": 40, "text": "Tall polished slabs banded in gold. Walls join their neighbours."},
	"timber_wall": {"name": "Timber Wall", "icon": 129, "wall": "timber", "material_rarity": 0, "place": "wall", "value": 12, "text": "White plaster in a braced oak frame, like a village house. Walls join their neighbours."},
	"rootwood_wall": {"name": "Rootwood Wall", "icon": 130, "wall": "rootwood", "material_rarity": 1, "place": "wall", "value": 25, "text": "Living trunks grown into a wall, a knot of sap glowing in the bark, leaves along the top."},
	"heartstone_wall": {"name": "Heartstone Wall", "icon": 131, "wall": "heartstone", "material_rarity": 3, "place": "wall", "value": 80, "text": "Dark crimson stone whose cracks glow and fade like a slow pulse."},
	"glass_wall": {"name": "Stained Glass Wall", "icon": 132, "wall": "glass", "material_rarity": 2, "place": "wall", "value": 45, "text": "A stone frame round leaded panes of coloured glass."},
	"ruined_wall_block": {"name": "Ruined Wall", "icon": 42, "tint": Color("7d7986"), "wall": "ruin", "material_rarity": 0, "place": "wall", "value": 5, "text": "A tile of old, broken wall with moss, for a ruin of your own."},
	"house_kit": {"name": "House Kit", "icon": 56, "material_rarity": 1, "place": "house", "value": 300, "text": "Everything needed to raise a small house. Use it from your bag to choose the spot."},
	# --- tools: needed to gather; higher tiers reach better materials and work faster
	"worn_pickaxe": {"name": "Worn Pickaxe", "icon": 49, "tint": Color("9a98a0"), "material_rarity": 0, "tool": {"kind": "pickaxe", "tier": 1, "speed": 1.0}, "text": "Tier 1 pickaxe."},
	"bronze_pickaxe": {"name": "Bronze Pickaxe", "icon": 49, "tint": Color("c9954a"), "material_rarity": 1, "tool": {"kind": "pickaxe", "tier": 2, "speed": 1.2}, "text": "Tier 2 pickaxe."},
	"iron_pickaxe": {"name": "Iron Pickaxe", "icon": 49, "tint": Color("aab2bc"), "material_rarity": 2, "tool": {"kind": "pickaxe", "tier": 3, "speed": 1.4}, "text": "Tier 3 pickaxe."},
	"mithril_pickaxe": {"name": "Mithril Pickaxe", "icon": 49, "tint": Color("8fe0e8"), "material_rarity": 3, "tool": {"kind": "pickaxe", "tier": 4, "speed": 1.7}, "text": "Tier 4 pickaxe."},
	"adamantite_pickaxe": {"name": "Adamantite Pickaxe", "icon": 49, "tint": Color("d06a5a"), "material_rarity": 4, "tool": {"kind": "pickaxe", "tier": 5, "speed": 2.0}, "text": "Tier 5 pickaxe."},
	"worn_hatchet": {"name": "Worn Hatchet", "icon": 50, "tint": Color("9a98a0"), "material_rarity": 0, "tool": {"kind": "hatchet", "tier": 1, "speed": 1.0}, "text": "Tier 1 hatchet."},
	"bronze_hatchet": {"name": "Bronze Hatchet", "icon": 50, "tint": Color("c9954a"), "material_rarity": 1, "tool": {"kind": "hatchet", "tier": 2, "speed": 1.2}, "text": "Tier 2 hatchet."},
	"iron_hatchet": {"name": "Iron Hatchet", "icon": 50, "tint": Color("aab2bc"), "material_rarity": 2, "tool": {"kind": "hatchet", "tier": 3, "speed": 1.4}, "text": "Tier 3 hatchet."},
	"mithril_hatchet": {"name": "Mithril Hatchet", "icon": 50, "tint": Color("8fe0e8"), "material_rarity": 3, "tool": {"kind": "hatchet", "tier": 4, "speed": 1.7}, "text": "Tier 4 hatchet."},
	"adamantite_hatchet": {"name": "Adamantite Hatchet", "icon": 50, "tint": Color("d06a5a"), "material_rarity": 4, "tool": {"kind": "hatchet", "tier": 5, "speed": 2.0}, "text": "Tier 5 hatchet."},
	"relic_hearthstone": {"name": "Hearthstone Shard", "icon": 102, "relic": "hearthstone", "material_rarity": 3, "value": 600, "text": "A relic. Keep it in the relic bag and wear it from there."},
	"relic_tidewalker": {"name": "Tidewalker's Scale", "icon": 103, "relic": "tidewalker", "material_rarity": 3, "value": 600, "text": "A relic. Keep it in the relic bag and wear it from there."},
	"relic_ember_heart": {"name": "Ember Heart", "icon": 104, "relic": "ember_heart", "material_rarity": 3, "value": 600, "text": "A relic. Keep it in the relic bag and wear it from there."},
	"relic_frostbound_eye": {"name": "Frostbound Eye", "icon": 105, "relic": "frostbound_eye", "material_rarity": 3, "value": 600, "text": "A relic. Keep it in the relic bag and wear it from there."},
	"relic_bloodvine": {"name": "Bloodvine Locket", "icon": 106, "relic": "bloodvine", "material_rarity": 3, "value": 600, "text": "A relic. Keep it in the relic bag and wear it from there."},
	"relic_gale_feather": {"name": "Gale Feather", "icon": 107, "relic": "gale_feather", "material_rarity": 3, "value": 600, "text": "A relic. Keep it in the relic bag and wear it from there."},
	"relic_ironroot": {"name": "Ironroot Seed", "icon": 108, "relic": "ironroot", "material_rarity": 3, "value": 600, "text": "A relic. Keep it in the relic bag and wear it from there."},
	"relic_void_lens": {"name": "Void Lens", "icon": 109, "relic": "void_lens", "material_rarity": 3, "value": 600, "text": "A relic. Keep it in the relic bag and wear it from there."},
	"relic_gilded_idol": {"name": "Gilded Idol", "icon": 110, "relic": "gilded_idol", "material_rarity": 3, "value": 600, "text": "A relic. Keep it in the relic bag and wear it from there."},
	"relic_stormheart": {"name": "Stormheart Coil", "icon": 111, "relic": "stormheart", "material_rarity": 3, "value": 600, "text": "A relic. Keep it in the relic bag and wear it from there."},
	"relic_moonlit_bell": {"name": "Moonlit Bell", "icon": 112, "relic": "moonlit_bell", "material_rarity": 3, "value": 600, "text": "A relic. Keep it in the relic bag and wear it from there."},
	"relic_grave_lantern": {"name": "Grave Lantern", "icon": 113, "relic": "grave_lantern", "material_rarity": 3, "value": 600, "text": "A relic. Keep it in the relic bag and wear it from there."},
	"rope_belt": {"name": "Rope Belt", "icon": 114, "belt": {"bag": 5, "relics": 0}, "material_rarity": 0, "value": 15, "text": "A length of rope knotted round the waist. Wear it for 5 more bag slots."},
	"leather_belt": {"name": "Leather Belt", "icon": 115, "belt": {"bag": 10, "relics": 1}, "material_rarity": 1, "value": 90, "text": "A good leather belt with a relic loop. Wear it for 10 more bag slots and room for a second relic."},
	"reliquary_belt": {"name": "Reliquary Belt", "icon": 116, "belt": {"bag": 10, "relics": 2}, "material_rarity": 3, "value": 900, "text": "A belt of gold-set leather with two relic cases. Wear it for 10 more bag slots and three relics at once."},
	"bindle": {"name": "Bindle", "icon": 93, "tint": Color("c8b48a"), "material_rarity": 0, "backpack": 6, "value": 12, "text": "A stick over the shoulder and a bundle of woven herb stalks tied to it. Wear it for 6 more bag slots. Anyone can make one by hand."},
	"satchel": {"name": "Satchel", "icon": 93, "tint": Color("b08a5a"), "material_rarity": 1, "backpack": 10, "value": 60, "text": "A small leather pack. Wear it for 10 more bag slots."},
	"backpack": {"name": "Backpack", "icon": 93, "tint": Color("8a6a48"), "material_rarity": 2, "backpack": 20, "value": 220, "text": "A sturdy framed pack. Wear it for 20 more bag slots."},
	"explorers_pack": {"name": "Explorer's Pack", "icon": 93, "tint": Color("6a8ab0"), "material_rarity": 3, "backpack": 30, "value": 700, "text": "Pockets on its pockets. Wear it for 30 more bag slots."},
	"fishing_rod": {"name": "Fishing Rod", "icon": 51, "material_rarity": 0, "tool": {"kind": "rod", "tier": 1, "speed": 1.0}, "text": "For the patient."},
}

## Metal for each equipment tier, by the item level the tier starts at.
const TIER_INGOTS := {1: "copper_ingot", 10: "iron_ingot", 20: "silver_ingot", 30: "gold_ingot", 40: "mithril_ingot",
	50: "obsidian_ingot", 65: "adamantite_ingot", 80: "void_ingot", 100: "heartstone_ingot"}
## Wearing several armour pieces of one tier gives a set bonus.
const SET_SLOTS: Array[String] = ["off_hand", "helmet", "chest", "legs", "boots"]
const SET_BONUSES := {
	2: {"max_health": {"percent": 0.06}},
	3: {"max_health": {"percent": 0.08}, "armor": {"percent": 0.1}},
	4: {"max_health": {"percent": 0.12}, "armor": {"percent": 0.15}, "physical_damage": {"percent": 0.08}},
	5: {"max_health": {"percent": 0.16}, "armor": {"percent": 0.22}, "physical_damage": {"percent": 0.12}},
}
## Named sets: pieces drop from bosses and Champions, at Epic power.
## Bonuses add up as more pieces are worn.
const SET_COLOR := Color("3fe0a0")
const ITEM_SETS := {
	"gravewarden": {"name": "Gravewarden", "pieces": ["helmet", "chestplate", "greaves", "boots", "shield"],
		"bonuses": {2: {"max_health": {"percent": 0.1}}, 3: {"armor": {"percent": 0.2}}, 5: {"damage_taken": {"percent": -0.15}, "physical_damage": {"percent": 0.1}}}},
	"emberheart": {"name": "Emberheart", "pieces": ["helmet", "chestplate", "ring", "necklace", "flame_sword"],
		"bonuses": {2: {"fire_resist": {"flat": 0.2}}, 3: {"fire_damage": {"percent": 0.4}}, 5: {"fire_damage": {"percent": 0.6}, "critical_chance": {"flat": 0.05}}}},
	"frostbound": {"name": "Frostbound", "pieces": ["helmet", "chestplate", "greaves", "boots", "frost_sword"],
		"bonuses": {2: {"frost_resist": {"flat": 0.2}}, 3: {"frost_damage": {"percent": 0.4}, "max_health": {"percent": 0.05}}, 5: {"frost_damage": {"percent": 0.6}, "move_speed": {"percent": 0.08}}}},
	"nightstalker": {"name": "Nightstalker", "pieces": ["helmet", "boots", "dagger", "ring", "necklace"],
		"bonuses": {2: {"critical_chance": {"flat": 0.05}}, 3: {"shadow_damage": {"percent": 0.5}, "attack_speed": {"percent": 0.08}}, 5: {"critical_damage": {"flat": 0.5}, "life_steal": {"flat": 0.03}}}},
	"archmage": {"name": "Archmage", "pieces": ["helmet", "chestplate", "staff", "ring", "relic"],
		"bonuses": {2: {"max_mana": {"percent": 0.2}}, 3: {"magic_power": {"percent": 0.15}, "mana_regen": {"percent": 0.3}}, 5: {"magic_power": {"percent": 0.25}, "holy_damage": {"percent": 0.5}}}},
	"heartsworn": {"name": "Heartsworn", "pieces": ["heartsworn_helm", "heartsworn_cuirass", "heartsworn_greaves", "heartsworn_sabatons", "pulsebrand"],
		"bonuses": {2: {"max_health": {"percent": 0.12}}, 3: {"life_steal": {"flat": 0.03}, "health_regen": {"percent": 0.5}},
			5: {"physical_damage": {"percent": 0.15}, "damage_taken": {"percent": -0.1}}}},
	"sunward": {"name": "Sunward", "pieces": ["helmet", "chestplate", "greaves", "spear", "necklace"],
		"bonuses": {2: {"holy_damage": {"percent": 0.3}}, 3: {"shadow_resist": {"flat": 0.25}, "health_regen": {"percent": 0.5}}, 5: {"holy_damage": {"percent": 0.6}, "max_health": {"percent": 0.1}}}},
}

## Base power gained per blacksmith upgrade level, and the most upgrades allowed.
const UPGRADE_POWER := 0.08
const MAX_UPGRADE := 10

## Random modifiers. Value = (base + per_level * item level) * a quality roll.
## "slots" lists the equipment slots an affix can appear on ("ring" covers both).
const ARMOR_SLOTS: Array[String] = ["off_hand", "helmet", "chest", "legs", "boots"]
const AFFIXES: Array[Dictionary] = [
	{"stat": "physical_damage", "kind": "flat", "base": 1.0, "per_level": 0.25, "slots": ["main_hand", "ring"]},
	{"stat": "physical_damage", "kind": "percent", "base": 0.04, "per_level": 0.0004, "slots": ["main_hand", "ring", "necklace"]},
	{"stat": "max_health", "kind": "flat", "base": 8.0, "per_level": 2.0, "slots": ["off_hand", "helmet", "chest", "legs", "boots", "necklace"]},
	{"stat": "armor", "kind": "flat", "base": 2.0, "per_level": 0.5, "slots": ["off_hand", "helmet", "chest", "legs", "boots"]},
	{"stat": "critical_chance", "kind": "flat", "base": 0.02, "per_level": 0.0002, "slots": ["main_hand", "ring", "necklace", "helmet"]},
	{"stat": "critical_damage", "kind": "flat", "base": 0.08, "per_level": 0.001, "slots": ["main_hand", "ring", "necklace", "artifact"]},
	{"stat": "attack_speed", "kind": "percent", "base": 0.03, "per_level": 0.0003, "slots": ["main_hand", "ring", "artifact"]},
	{"stat": "move_speed", "kind": "flat", "base": 4.0, "per_level": 0.05, "slots": ["boots", "legs"]},
	{"stat": "max_stamina", "kind": "flat", "base": 5.0, "per_level": 0.3, "slots": ["chest", "legs", "boots", "necklace", "artifact"]},
	{"stat": "max_mana", "kind": "flat", "base": 5.0, "per_level": 0.3, "slots": ["helmet", "necklace", "ring", "artifact"]},
	{"stat": "health_regen", "kind": "flat", "base": 0.2, "per_level": 0.03, "slots": ["chest", "necklace", "ring", "artifact"]},
	{"stat": "magic_find", "kind": "flat", "base": 0.02, "per_level": 0.0003, "slots": ["ring", "necklace", "artifact", "helmet"]},
	{"stat": "fire_damage", "kind": "flat", "base": 1.5, "per_level": 0.3, "slots": ["main_hand", "ring"]},
	{"stat": "frost_damage", "kind": "flat", "base": 1.5, "per_level": 0.3, "slots": ["main_hand", "ring"]},
	{"stat": "poison_damage", "kind": "flat", "base": 1.5, "per_level": 0.3, "slots": ["main_hand", "ring"]},
	{"stat": "shadow_damage", "kind": "flat", "base": 1.5, "per_level": 0.3, "slots": ["main_hand", "ring"]},
	{"stat": "holy_damage", "kind": "flat", "base": 1.5, "per_level": 0.3, "slots": ["main_hand", "ring"]},
	{"stat": "fire_resist", "kind": "flat", "base": 0.05, "per_level": 0.0012, "slots": ["off_hand", "helmet", "chest", "legs", "boots", "necklace"]},
	{"stat": "frost_resist", "kind": "flat", "base": 0.05, "per_level": 0.0012, "slots": ["off_hand", "helmet", "chest", "legs", "boots", "necklace"]},
	{"stat": "poison_resist", "kind": "flat", "base": 0.05, "per_level": 0.0012, "slots": ["off_hand", "helmet", "chest", "legs", "boots", "necklace"]},
	{"stat": "shadow_resist", "kind": "flat", "base": 0.05, "per_level": 0.0012, "slots": ["off_hand", "helmet", "chest", "legs", "boots", "necklace"]},
	{"stat": "holy_resist", "kind": "flat", "base": 0.05, "per_level": 0.0012, "slots": ["off_hand", "helmet", "chest", "legs", "boots", "necklace"]},
	{"stat": "strength", "kind": "flat", "base": 1.0, "per_level": 0.08},
	{"stat": "vitality", "kind": "flat", "base": 1.0, "per_level": 0.08},
	{"stat": "agility", "kind": "flat", "base": 1.0, "per_level": 0.08},
	{"stat": "luck", "kind": "flat", "base": 1.0, "per_level": 0.08},
	{"stat": "intelligence", "kind": "flat", "base": 1.0, "per_level": 0.08},
	{"stat": "endurance", "kind": "flat", "base": 1.0, "per_level": 0.08},
]

## What each enemy type drops: only its own materials, and now and then a
## piece of gear that suits it ("gear": [[base id, chance], ...]).
## "gold" is [min, max] at level 1. Enemies without an entry use "husk".
const LOOT_TABLES := {
	"husk": {"gold": [0, 2], "gear": [["sword", 0.02], ["helmet", 0.015]], "materials": [
		{"id": "husk_fragment", "chance": 0.35, "count": [1, 1]}, {"id": "bone", "chance": 0.08, "count": [1, 1]}]},
	"rot_hound": {"gold": [0, 1], "gear": [["boots", 0.02]], "materials": [
		{"id": "hound_pelt", "chance": 0.3, "count": [1, 1]}, {"id": "claw", "chance": 0.18, "count": [1, 1]}]},
	"bone_archer": {"gold": [1, 2], "gear": [["bow", 0.03]], "materials": [
		{"id": "bone", "chance": 0.4, "count": [1, 2]}]},
	"bog_slime": {"gold": [0, 1], "gear": [["ring", 0.015]], "materials": [
		{"id": "slime_gel", "chance": 0.35, "count": [1, 1]}, {"id": "venom_sac", "chance": 0.08, "count": [1, 1]}]},
	"carrion_bat": {"gold": [0, 1], "gear": [["dagger", 0.02]], "materials": [
		{"id": "bat_wing", "chance": 0.3, "count": [1, 1]}]},
	"thorn_stalker": {"gold": [1, 2], "gear": [["fang", 0.02], ["greaves", 0.015]], "materials": [
		{"id": "chitin", "chance": 0.3, "count": [1, 1]}, {"id": "venom_sac", "chance": 0.2, "count": [1, 1]}]},
	"spore_shambler": {"gold": [1, 2], "gear": [["staff", 0.02]], "materials": [
		{"id": "spore_cap", "chance": 0.35, "count": [1, 1]}, {"id": "poison_mushroom", "chance": 0.2, "count": [1, 1]}]},
	"rot_cultist": {"gold": [2, 5], "gear": [["staff", 0.03], ["necklace", 0.02]], "materials": [
		{"id": "cultist_sigil", "chance": 0.3, "count": [1, 1]}, {"id": "essence", "chance": 0.1, "count": [1, 1]}]},
	"ember_wisp": {"gold": [0, 1], "gear": [["ember_staff", 0.015]], "materials": [
		{"id": "ember_core", "chance": 0.25, "count": [1, 1]}]},
	"ash_wraith": {"gold": [1, 3], "gear": [["relic", 0.01], ["dark_sword", 0.015]], "materials": [
		{"id": "wraith_cloth", "chance": 0.3, "count": [1, 1]}, {"id": "essence", "chance": 0.15, "count": [1, 1]}]},
	"crag_golem": {"gold": [3, 6], "gear": [["shield", 0.04], ["chestplate", 0.03]], "materials": [
		{"id": "stone", "chance": 0.7, "count": [1, 3]}, {"id": "stone_heart", "chance": 0.15, "count": [1, 1]}]},
	"frost_wolf": {"gold": [0, 2], "gear": [["boots", 0.02], ["frost_sword", 0.006]], "materials": [
		{"id": "frost_pelt", "chance": 0.3, "count": [1, 1]}, {"id": "claw", "chance": 0.15, "count": [1, 1]}]},
	"frost_troll": {"gold": [3, 7], "gear": [["greatsword", 0.03], ["chestplate", 0.03]], "materials": [
		{"id": "troll_hide", "chance": 0.35, "count": [1, 1]}, {"id": "frost_pelt", "chance": 0.3, "count": [1, 2]}]},
	"dire_boar": {"gold": [0, 2], "gear": [["greaves", 0.02]], "materials": [
		{"id": "boar_tusk", "chance": 0.35, "count": [1, 2]}, {"id": "hound_pelt", "chance": 0.25, "count": [1, 1]}]},
	"treant": {"gold": [2, 5], "gear": [["staff", 0.03], ["shield", 0.03]], "materials": [
		{"id": "heartwood", "chance": 0.3, "count": [1, 1]}, {"id": "oak_wood", "chance": 0.7, "count": [2, 4]}]},
	"sand_scorpion": {"gold": [1, 2], "gear": [["fang", 0.015], ["dagger", 0.02]], "materials": [
		{"id": "scorpion_stinger", "chance": 0.3, "count": [1, 1]}, {"id": "venom_sac", "chance": 0.15, "count": [1, 1]}]},
	"dune_mummy": {"gold": [2, 4], "gear": [["necklace", 0.02], ["relic", 0.008]], "materials": [
		{"id": "mummy_wrap", "chance": 0.35, "count": [1, 2]}, {"id": "bone", "chance": 0.3, "count": [1, 2]}]},
	"void_stalker": {"gold": [1, 3], "gear": [["dark_sword", 0.015], ["katana", 0.015]], "materials": [
		{"id": "void_shard", "chance": 0.25, "count": [1, 1]}, {"id": "essence", "chance": 0.12, "count": [1, 1]}]},
	"void_eye": {"gold": [1, 3], "gear": [["ring", 0.03], ["staff", 0.015]], "materials": [
		{"id": "void_shard", "chance": 0.3, "count": [1, 1]}, {"id": "essence", "chance": 0.2, "count": [1, 1]}]},
	"crimson_fiend": {"gold": [2, 4], "gear": [["reaver", 0.015], ["axe", 0.02]], "materials": [
		{"id": "fiend_horn", "chance": 0.3, "count": [1, 1]}, {"id": "claw", "chance": 0.2, "count": [1, 1]}]},
	"magma_slime": {"gold": [0, 2], "gear": [["ring", 0.015]], "materials": [
		{"id": "magma_core", "chance": 0.2, "count": [1, 1]}, {"id": "slime_gel", "chance": 0.3, "count": [1, 1]}]},
	"cinder_imp": {"gold": [1, 2], "gear": [["ember_staff", 0.015], ["flame_sword", 0.008]], "materials": [
		{"id": "ember_core", "chance": 0.25, "count": [1, 1]}, {"id": "fiend_horn", "chance": 0.1, "count": [1, 1]}]},
	"veinheart": {"gold": [2, 4], "gear": [["heartstring", 0.01]], "materials": [
		{"id": "heartblood", "chance": 0.45, "count": [1, 2]}, {"id": "essence", "chance": 0.12, "count": [1, 1]}]},
	"heartsworn_knight": {"gold": [3, 6], "gear": [["heartsworn_helm", 0.008], ["heartsworn_sabatons", 0.008], ["heartpiercer", 0.008]], "materials": [
		{"id": "crimson_plate", "chance": 0.4, "count": [1, 2]}, {"id": "heartblood", "chance": 0.25, "count": [1, 1]}]},
	"bog_lurker": {"gold": [0, 2], "gear": [["boots", 0.015]], "materials": [
		{"id": "lurker_tongue", "chance": 0.35, "count": [1, 1]}, {"id": "slime_gel", "chance": 0.2, "count": [1, 1]}]},
	"storm_harpy": {"gold": [1, 2], "gear": [["bow", 0.025], ["spear", 0.015]], "materials": [
		{"id": "harpy_feather", "chance": 0.35, "count": [1, 2]}, {"id": "claw", "chance": 0.15, "count": [1, 1]}]},
	"deer": {"gold": [0, 0], "materials": [{"id": "venison", "chance": 0.9, "count": [1, 2]}, {"id": "deer_hide", "chance": 0.6, "count": [1, 1]}, {"id": "antler", "chance": 0.25, "count": [1, 1]}]},
	"wild_hare": {"gold": [0, 0], "materials": [{"id": "hare_meat", "chance": 0.9, "count": [1, 1]}, {"id": "hare_pelt", "chance": 0.5, "count": [1, 1]}]},
	"wild_pig": {"gold": [0, 0], "materials": [{"id": "pork", "chance": 0.95, "count": [1, 3]}, {"id": "pig_hide", "chance": 0.5, "count": [1, 1]}]},
	"mountain_goat": {"gold": [0, 0], "materials": [{"id": "goat_meat", "chance": 0.9, "count": [1, 2]}, {"id": "wool", "chance": 0.6, "count": [1, 3]}, {"id": "goat_horn", "chance": 0.25, "count": [1, 1]}]},
	"pheasant": {"gold": [0, 0], "materials": [{"id": "pheasant_meat", "chance": 0.9, "count": [1, 1]}, {"id": "pheasant_feather", "chance": 0.7, "count": [1, 3]}]},
	"desert_lizard": {"gold": [0, 0], "materials": [{"id": "lizard_meat", "chance": 0.9, "count": [1, 1]}, {"id": "lizard_scale", "chance": 0.6, "count": [1, 2]}]},
	"snow_fox": {"gold": [0, 0], "materials": [{"id": "fox_pelt", "chance": 0.7, "count": [1, 1]}, {"id": "hare_meat", "chance": 0.4, "count": [1, 1]}]},
	"shore_crab": {"gold": [0, 1], "materials": [{"id": "crab_meat", "chance": 0.9, "count": [1, 2]}, {"id": "crab_shell", "chance": 0.6, "count": [1, 1]}]},
	"sheep": {"gold": [0, 0], "materials": [{"id": "mutton", "chance": 0.9, "count": [1, 2]}, {"id": "wool", "chance": 0.95, "count": [1, 3]}]},
	"cow": {"gold": [0, 0], "materials": [{"id": "beef", "chance": 0.95, "count": [2, 4]}, {"id": "cow_hide", "chance": 0.7, "count": [1, 1]}]},
	"chicken": {"gold": [0, 0], "materials": [{"id": "chicken_meat", "chance": 0.9, "count": [1, 1]}, {"id": "feather", "chance": 0.8, "count": [1, 3]}, {"id": "egg", "chance": 0.4, "count": [1, 2]}]},
	"bear": {"gold": [0, 0], "materials": [{"id": "bear_meat", "chance": 0.95, "count": [2, 3]}, {"id": "bear_pelt", "chance": 0.7, "count": [1, 1]}, {"id": "claw", "chance": 0.5, "count": [1, 2]}]},
	"grey_wolf": {"gold": [0, 2], "gear": [["boots", 0.02], ["dagger", 0.01]], "materials": [
		{"id": "hound_pelt", "chance": 0.4, "count": [1, 1]}, {"id": "claw", "chance": 0.2, "count": [1, 1]}]},
	"giant_spider": {"gold": [0, 3], "gear": [["dagger", 0.02], ["ring", 0.01]], "materials": [
		{"id": "spider_silk", "chance": 0.6, "count": [1, 2]}, {"id": "venom_sac", "chance": 0.25, "count": [1, 1]}, {"id": "chitin", "chance": 0.2, "count": [1, 1]}]},
	"web_spider": {"gold": [0, 2], "gear": [["bow", 0.01]], "materials": [
		{"id": "spider_silk", "chance": 0.8, "count": [1, 3]}, {"id": "venom_sac", "chance": 0.1, "count": [1, 1]}]},
	"marsh_toad": {"gold": [0, 0], "materials": [{"id": "toad_legs", "chance": 0.9, "count": [1, 2]}, {"id": "toad_slime", "chance": 0.5, "count": [1, 1]}]},
}

## How enemy rank changes loot.
const RANK_LOOT := {
	"normal": {"gold": 1.0, "materials": 1.0, "equipment_chance": 1.0, "rarity_bonus": 0.0},
	"elite": {"gold": 4.0, "materials": 2.0, "equipment_chance": 10.0, "rarity_bonus": 1.5},
	"champion": {"gold": 10.0, "materials": 3.0, "equipment_chance": 100.0, "rarity_bonus": 4.0},
	"miniboss": {"gold": 30.0, "materials": 4.0, "equipment_chance": 100.0, "rarity_bonus": 8.0},
	"boss": {"gold": 60.0, "materials": 6.0, "equipment_chance": 100.0, "rarity_bonus": 14.0},
}

static var _icon_cache: Dictionary = {}


static func icon(index: int) -> Texture2D:
	if not _icon_cache.has(index):
		var atlas := AtlasTexture.new()
		atlas.atlas = ICONS
		atlas.region = Rect2(index % ICON_COLUMNS * ICON_SIZE, index / ICON_COLUMNS * ICON_SIZE, ICON_SIZE, ICON_SIZE)
		_icon_cache[index] = atlas
	return _icon_cache[index]


## Icons from this index on are drawn in their own colours: an item's tint
## only colours their pale parts, baked in once here.
const NATURAL_ICONS_FROM := 66
static var _tinted_cache: Dictionary = {}


static func tinted_icon(index: int, tint: Color) -> Texture2D:
	var key := "%d:%s" % [index, tint.to_html()]
	if not _tinted_cache.has(key):
		var image := ICONS.get_image().get_region(Rect2i(index % ICON_COLUMNS * ICON_SIZE, index / ICON_COLUMNS * ICON_SIZE, ICON_SIZE, ICON_SIZE))
		image.convert(Image.FORMAT_RGBA8)
		for y in image.get_height():
			for x in image.get_width():
				var c := image.get_pixel(x, y)
				# The pale, faintly blue greys of the "plate" parts take the tint.
				if c.a > 0.0 and absf(c.r - c.g) < 0.04 and c.b >= c.r and c.b - c.r < 0.09 and c.r > 0.45:
					image.set_pixel(x, y, Color(c.r * tint.r * 1.05, c.g * tint.g * 1.05, c.b * tint.b, c.a))
		_tinted_cache[key] = ImageTexture.create_from_image(image)
	return _tinted_cache[key]


## Item level at which the tier of `level` begins (1, 10, 20, ...).
## Whether an item is a plain material (no slot, no use, nothing to place).
static func is_material(item_id: String) -> bool:
	var def: Dictionary = ITEMS.get(item_id, {})
	return not def.is_empty() and not def.has("slot") and not def.has("use") and not def.has("place") and not def.has("tool") \
		and not def.has("backpack") and not def.has("relic") and not def.has("belt") and not def.has("gem") and not def.get("currency", false) \
		and not def.has("mount") and not def.has("boat") and not def.has("treasure_map")


## A material's rarity as found: its usual one, sometimes one or two better
## and very rarely three.
static func roll_material_rarity(item_id: String) -> int:
	var base := int(ITEMS[item_id].get("material_rarity", 0))
	var roll := randf()
	var step := 3 if roll < 0.008 else 2 if roll < 0.045 else 1 if roll < 0.2 else 0
	return clampi(base + step, 0, RARITIES.size() - 1)


static func tier_start(level: int) -> int:
	for tier in TIERS:
		if level >= tier[0]:
			return tier[0]
	return 1


## The ingot that works gear of this level: its tier's, or for the tiers
## past Heartstone (which no ore yields), Heartstone's.
static func tier_ingot(level: int) -> String:
	var best := 1
	for start: int in TIER_INGOTS:
		if level >= start and start > best:
			best = start
	return TIER_INGOTS[best]


static func tier_name(level: int) -> String:
	for tier in TIERS:
		if level >= tier[0]:
			return tier[1]
	return TIERS[-1][1]


static func tier_color(level: int) -> Color:
	for tier in TIERS:
		if level >= tier[0]:
			return tier[2]
	return TIERS[-1][2]


## Readable name for a stat or attribute id.
static func stat_name(stat: String) -> String:
	if Attributes.NAMES.has(stat):
		return Attributes.NAMES[stat]
	for entry in CharacterStats.DISPLAY:
		if entry["id"] == stat:
			return entry["name"]
	return stat.capitalize()


## "+12 Maximum HP", "+4.0% Physical damage", and so on.
static func describe_modifier(modifier: Dictionary) -> String:
	var stat: String = modifier["stat"]
	var value: float = modifier["value"]
	var format := "number"
	for entry in CharacterStats.DISPLAY:
		if entry["id"] == stat:
			format = entry["format"]
	var amount: String
	if modifier["kind"] == "percent" or format in ["percent", "percent_fine", "bonus_percent", "multiplier"]:
		amount = "+%.1f%%" % (value * 100.0)
	elif format == "per_second":
		amount = "+%.1f/s" % value
	else:
		amount = "+%d" % roundi(value)
	return "%s %s" % [amount, stat_name(stat)]
