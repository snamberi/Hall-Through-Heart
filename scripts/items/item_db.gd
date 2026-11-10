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
const RARITIES: Array[Dictionary] = [
	{"id": "common", "name": "Common", "color": Color("c8c4b8"), "mods": 0, "power": 1.0, "weight": 600.0},
	{"id": "uncommon", "name": "Uncommon", "color": Color("5fd068"), "mods": 1, "power": 1.1, "weight": 250.0},
	{"id": "rare", "name": "Rare", "color": Color("4f9dff"), "mods": 2, "power": 1.2, "weight": 100.0},
	{"id": "epic", "name": "Epic", "color": Color("b565f0"), "mods": 3, "power": 1.35, "weight": 40.0},
	{"id": "legendary", "name": "Legendary", "color": Color("ff9a2e"), "mods": 4, "power": 1.5, "weight": 9.0},
	{"id": "mythic", "name": "Mythic", "color": Color("ff4d6d"), "mods": 5, "power": 1.7, "weight": 1.0},
]

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
	[100, "Heartstone", Color("e0506a")], [80, "Void", Color("9a6cf0")],
	[65, "Adamantite", Color("d06a5a")], [50, "Obsidian", Color("6a6480")],
	[40, "Mithril", Color("8fe0e8")], [30, "Gilded", Color("f0cf6a")],
	[20, "Silver", Color("eef2f6")], [10, "Iron", Color("aab2bc")], [1, "Copper", Color("d99a6c")],
]
## Base damage and armor grow by this share per item level above 1.
const POWER_PER_LEVEL := 0.15

## Colour and name for each status a weapon can inflict.
const STATUSES := {
	"burn": {"name": "Burn", "color": Color(1.0, 0.6, 0.25)},
	"poison": {"name": "Poison", "color": Color(0.55, 0.95, 0.4)},
	"bleed": {"name": "Bleed", "color": Color(0.95, 0.3, 0.3)},
	"chill": {"name": "Chill", "color": Color(0.6, 0.85, 1.0)},
}

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
	"sword": {
		"name": "Sword", "icon": 0, "visual": "sword", "slot": "main_hand", "tiered": true, "drop_weight": 10.0,
		"damage": 6.0,
		"weapon": {"type": "swords", "range": 64.0, "arc": 120.0, "cooldown": 0.34, "knockback": 380.0},
	},
	"flame_sword": {
		"name": "Emberbrand", "icon": 18, "visual": "flame_sword", "slot": "main_hand", "tiered": true,
		"drop_weight": 2.0, "min_rarity": 1, "damage": 5.5, "slash": Color(1.0, 0.6, 0.2),
		"on_hit": {"status": "burn", "duration": 3.0, "power": 0.3},
		"weapon": {"type": "swords", "range": 64.0, "arc": 120.0, "cooldown": 0.34, "knockback": 380.0},
	},
	"frost_sword": {
		"name": "Frostbrand", "icon": 19, "visual": "frost_sword", "slot": "main_hand", "tiered": true,
		"drop_weight": 2.0, "min_rarity": 1, "damage": 5.5, "slash": Color(0.6, 0.9, 1.0),
		"on_hit": {"status": "chill", "duration": 2.5, "power": 0.4},
		"weapon": {"type": "swords", "range": 64.0, "arc": 120.0, "cooldown": 0.34, "knockback": 380.0},
	},
	"dark_sword": {
		"name": "Gloomblade", "icon": 20, "visual": "dark_sword", "slot": "main_hand", "tiered": true,
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
		"name": "Fang", "icon": 24, "visual": "fang", "slot": "main_hand", "tiered": true,
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
}

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
	{"stat": "strength", "kind": "flat", "base": 1.0, "per_level": 0.08},
	{"stat": "vitality", "kind": "flat", "base": 1.0, "per_level": 0.08},
	{"stat": "agility", "kind": "flat", "base": 1.0, "per_level": 0.08},
	{"stat": "luck", "kind": "flat", "base": 1.0, "per_level": 0.08},
	{"stat": "intelligence", "kind": "flat", "base": 1.0, "per_level": 0.08},
	{"stat": "endurance", "kind": "flat", "base": 1.0, "per_level": 0.08},
]

## What each enemy type can drop. "gold" is [min, max] at level 1.
const LOOT_TABLES := {
	"husk": {
		"gold": [1, 3],
		"equipment_chance": 0.1,
		"materials": [
			{"id": "husk_fragment", "chance": 0.6, "count": [1, 2]},
			{"id": "bone", "chance": 0.25, "count": [1, 1]},
			{"id": "claw", "chance": 0.12, "count": [1, 1]},
			{"id": "essence", "chance": 0.03, "count": [1, 1]},
		],
	},
}
## How enemy rank changes loot.
const RANK_LOOT := {
	"normal": {"gold": 1.0, "materials": 1.0, "equipment_chance": 1.0, "rarity_bonus": 0.0},
	"elite": {"gold": 4.0, "materials": 2.0, "equipment_chance": 6.0, "rarity_bonus": 1.5},
}

static var _icon_cache: Dictionary = {}


static func icon(index: int) -> Texture2D:
	if not _icon_cache.has(index):
		var atlas := AtlasTexture.new()
		atlas.atlas = ICONS
		atlas.region = Rect2(index % ICON_COLUMNS * ICON_SIZE, index / ICON_COLUMNS * ICON_SIZE, ICON_SIZE, ICON_SIZE)
		_icon_cache[index] = atlas
	return _icon_cache[index]


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
