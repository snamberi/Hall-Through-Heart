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
	"ember_staff": {
		"name": "Emberstaff", "icon": 34, "visual": "ember_staff", "slot": "main_hand", "tiered": true,
		"drop_weight": 1.5, "min_rarity": 1, "damage": 4.5, "two_handed": true, "magic": true,
		"slash": Color(1.0, 0.6, 0.2), "requires": {"intelligence": [3.0, 0.7]},
		"on_hit": {"status": "burn", "duration": 3.0, "power": 0.3},
		"implicit": [{"stat": "max_mana", "kind": "flat", "base": 10.0, "per_level": 0.5}],
		"weapon": {"type": "staves", "range": 480.0, "arc": 0.0, "cooldown": 0.55, "knockback": 160.0,
			"projectile": {"sprite": 2, "speed": 560.0, "radius": 12.0, "range": 480.0, "color": Color(1.0, 0.6, 0.2)}},
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
	"poison_mushroom": {"name": "Poison Mushroom", "icon": 44, "tint": Color("b06ad0"), "material_rarity": 1, "text": "Do not eat this one raw."},
	"rare_root": {"name": "Rare Root", "icon": 44, "tint": Color("d0b070"), "material_rarity": 2, "text": "A knotted root prized by alchemists."},
	"minnow": {"name": "Minnow", "icon": 45, "tint": Color("c0d0d8"), "material_rarity": 0, "text": "Fresh from the black water. Best cooked."},
	"trout": {"name": "Trout", "icon": 45, "tint": Color("e0a080"), "material_rarity": 1, "text": "Fresh from the black water. Best cooked."},
	"eel": {"name": "Eel", "icon": 45, "tint": Color("708090"), "material_rarity": 2, "text": "Fresh from the black water. Best cooked."},
	"enchanted_dust": {"name": "Enchanted Dust", "icon": 52, "tint": Color("ffffff"), "material_rarity": 1, "text": "What is left when magic gear is broken down."},
	"hound_pelt": {"name": "Hound Pelt", "icon": 13, "tint": Color("8a5a4a"), "material_rarity": 0, "text": "Mangy, but it will cure."},
	"slime_gel": {"name": "Slime Gel", "icon": 16, "tint": Color("b8f08a"), "material_rarity": 0, "text": "It never quite stops moving."},
	"bat_wing": {"name": "Bat Wing", "icon": 15, "tint": Color("5a4a5e"), "material_rarity": 0, "text": "Thin as old paper."},
	"chitin": {"name": "Chitin", "icon": 13, "tint": Color("4a5040"), "material_rarity": 1, "text": "Light, hard plates from a stalker's back."},
	"spore_cap": {"name": "Spore Cap", "icon": 44, "tint": Color("c05a8a"), "material_rarity": 1, "text": "Keep it away from your face."},
	"cultist_sigil": {"name": "Cultist Sigil", "icon": 53, "tint": Color("c08cff"), "material_rarity": 1, "text": "A prayer to something that should not answer."},
	"wraith_cloth": {"name": "Wraith Cloth", "icon": 43, "tint": Color("dfe6ee"), "material_rarity": 2, "text": "Cold to the touch, and weightless."},
	"heart_shard": {"name": "Heart Shard", "icon": 12, "tint": Color("ff6a7a"), "material_rarity": 3, "text": "A splinter of something vast. It still pulses."},
	"venom_sac": {"name": "Venom Sac", "icon": 16, "tint": Color("b06ad0"), "material_rarity": 1, "text": "Handle with care."},
	"ember_core": {"name": "Ember Core", "icon": 16, "tint": Color("f08a2e"), "material_rarity": 2, "text": "Still warm."},
	"stone_heart": {"name": "Stone Heart", "icon": 42, "tint": Color("8a8794"), "material_rarity": 2, "text": "The slow-beating core of a golem."},
	# --- consumables: "use" is what happens when used
	"health_potion": {"name": "Health Potion", "icon": 47, "tint": Color("e0555a"), "material_rarity": 0, "use": {"heal": 0.4}, "text": "Restores 40% of your health."},
	"mana_potion": {"name": "Mana Potion", "icon": 47, "tint": Color("4f9dff"), "material_rarity": 0, "use": {"mana": 0.6}, "text": "Restores 60% of your mana."},
	"stamina_tonic": {"name": "Stamina Tonic", "icon": 47, "tint": Color("f0cf6a"), "material_rarity": 0, "use": {"stamina": 1.0}, "text": "Fully restores your stamina."},
	"might_elixir": {"name": "Might Elixir", "icon": 47, "tint": Color("f08a2e"), "material_rarity": 1, "use": {"buff": "might", "name": "Might", "duration": 90.0, "mods": {"physical_damage": {"percent": 0.15}}}, "text": "+15% damage for 90 seconds."},
	"grilled_minnow": {"name": "Grilled Minnow", "icon": 48, "tint": Color("e0c090"), "material_rarity": 0, "use": {"buff": "food", "name": "Well Fed", "duration": 300.0, "mods": {"max_health": {"flat": 20.0}, "health_regen": {"flat": 0.5}}}, "text": "+20 maximum HP and regeneration for 5 minutes."},
	"trout_stew": {"name": "Trout Stew", "icon": 48, "tint": Color("f0a060"), "material_rarity": 1, "use": {"buff": "food", "name": "Well Fed", "duration": 300.0, "mods": {"max_health": {"flat": 60.0}, "max_stamina": {"flat": 20.0}}}, "text": "+60 maximum HP and +20 stamina for 5 minutes."},
	"eel_pie": {"name": "Eel Pie", "icon": 48, "tint": Color("c09060"), "material_rarity": 2, "use": {"buff": "food", "name": "Well Fed", "duration": 300.0, "mods": {"max_health": {"flat": 100.0}, "physical_damage": {"percent": 0.08}}}, "text": "+100 maximum HP and +8% damage for 5 minutes."},
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
	"fishing_rod": {"name": "Fishing Rod", "icon": 51, "material_rarity": 0, "tool": {"kind": "rod", "tier": 1, "speed": 1.0}, "text": "For the patient."},
}

## Metal for each equipment tier, by the item level the tier starts at.
const TIER_INGOTS := {1: "copper_ingot", 10: "iron_ingot", 20: "silver_ingot", 30: "gold_ingot", 40: "mithril_ingot",
	50: "obsidian_ingot", 65: "adamantite_ingot", 80: "void_ingot", 100: "heartstone_ingot"}
## Wearing several armour pieces of one tier gives a set bonus.
const SET_SLOTS: Array[String] = ["off_hand", "helmet", "chest", "legs", "boots"]
const SET_BONUSES := {
	2: {"max_health": {"percent": 0.05}},
	4: {"max_health": {"percent": 0.05}, "armor": {"percent": 0.1}, "physical_damage": {"percent": 0.05}},
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
}
## How enemy rank changes loot.
const RANK_LOOT := {
	"normal": {"gold": 1.0, "materials": 1.0, "equipment_chance": 1.0, "rarity_bonus": 0.0},
	"elite": {"gold": 4.0, "materials": 2.0, "equipment_chance": 10.0, "rarity_bonus": 1.5},
	"champion": {"gold": 10.0, "materials": 3.0, "equipment_chance": 100.0, "rarity_bonus": 4.0},
	"miniboss": {"gold": 30.0, "materials": 4.0, "equipment_chance": 100.0, "rarity_bonus": 8.0},
}

static var _icon_cache: Dictionary = {}


static func icon(index: int) -> Texture2D:
	if not _icon_cache.has(index):
		var atlas := AtlasTexture.new()
		atlas.atlas = ICONS
		atlas.region = Rect2(index % ICON_COLUMNS * ICON_SIZE, index / ICON_COLUMNS * ICON_SIZE, ICON_SIZE, ICON_SIZE)
		_icon_cache[index] = atlas
	return _icon_cache[index]


## Item level at which the tier of `level` begins (1, 10, 20, ...).
static func tier_start(level: int) -> int:
	for tier in TIERS:
		if level >= tier[0]:
			return tier[0]
	return 1


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
