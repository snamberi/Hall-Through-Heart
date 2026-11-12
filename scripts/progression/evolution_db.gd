class_name EvolutionDB
extends RefCounted
## Race evolution: every race may grow, permanently, along one of three
## paths of four stages. The first step chooses the path for good.
##
## Each path has a pace:
##   swift     quick to climb (low levels, few bosses, little treasure) but
##             its gifts are the smallest
##   balanced  between the two
##   slow      a long climb (high levels, many world bosses, costly
##             offerings) for the greatest gifts
## A stage asks for a character level, a number of world bosses beaten
## (ever), and an offering of heart shards, trophies and the path's own
## material, all given up when the stage is taken. Each stage's gifts
## replace the last's and grow with it. From the second stage on, a path
## may change how the character looks (its "look").

const PACES := {
	"swift": {"name": "Swift", "text": "Quick to climb; the smallest gifts.", "color": Color("8ad0b0"), "power": 0.7,
		"levels": [8, 20, 38, 60], "bosses": [0, 0, 1, 2], "shards": [1, 2, 3, 5], "trophies": [0, 0, 0, 1], "material": [0, 2, 0, 5]},
	"balanced": {"name": "Balanced", "text": "A steady climb for steady gifts.", "color": Color("f0cf6a"), "power": 1.0,
		"levels": [15, 35, 65, 100], "bosses": [0, 1, 3, 5], "shards": [2, 4, 6, 10], "trophies": [0, 0, 1, 2], "material": [0, 4, 0, 10]},
	"slow": {"name": "Slow", "text": "A long, hard climb; the greatest gifts.", "color": Color("e07a7a"), "power": 1.5,
		"levels": [25, 55, 100, 160], "bosses": [1, 3, 6, 10], "shards": [4, 8, 12, 20], "trophies": [0, 1, 2, 4], "material": [0, 6, 0, 15]},
}
## How much of a path's gifts each stage gives.
const STAGE_POWER: Array[float] = [1.0, 1.8, 2.7, 3.8]

## race -> its three paths (swift, balanced, slow). "gifts" are per unit of
## stage power: stat -> [kind, value].
const PATHS := {
	"human": [
		{"name": "Wanderer", "pace": "swift", "stages": ["Wayfarer", "Veteran", "Far-strider", "Paragon of the Roads"], "material": "pheasant_feather",
			"gifts": {"move_speed": ["percent", 0.02], "max_stamina": ["flat", 8.0], "magic_find": ["flat", 0.02]}, "text": "Restless feet and luck on the road."},
		{"name": "Knight", "pace": "balanced", "stages": ["Squire", "Knight", "Knight-Captain", "Lord Paladin"], "material": "iron_ingot",
			"gifts": {"armor": ["percent", 0.03], "max_health": ["percent", 0.03], "holy_damage": ["flat", 1.5]}, "text": "Steel, oath and a little holy fire.", "look": {"eyes": 1}},
		{"name": "Ascendant", "pace": "slow", "stages": ["Touched", "Chosen", "Exalted", "Ascended"], "material": "sunroot",
			"gifts": {"physical_damage": ["percent", 0.03], "magic_power": ["percent", 0.03], "max_health": ["percent", 0.025]}, "text": "Something more than human wakes in the blood.", "look": {"eyes": 7}},
	],
	"elf": [
		{"name": "Wood Elf", "pace": "swift", "stages": ["Wood Elf", "Greenwarden", "Grove Ranger", "Sylvan Lord"], "material": "healing_herb",
			"gifts": {"move_speed": ["percent", 0.025], "critical_chance": ["flat", 0.015], "dodge_efficiency": ["flat", 0.02]}, "text": "Light of foot and sure of aim.", "look": {"eyes": 2}},
		{"name": "High Elf", "pace": "balanced", "stages": ["High Elf", "Spellwright", "Archon", "Starborn"], "material": "mana_flower",
			"gifts": {"magic_power": ["percent", 0.04], "max_mana": ["percent", 0.04], "holy_resist": ["flat", 0.03]}, "text": "The old learning, and the starlight in it.", "look": {"eyes": 9, "skin": 16}},
		{"name": "Dark Elf", "pace": "slow", "stages": ["Shadow-kissed", "Dark Elf", "Drow Blademaster", "Shadow Sovereign"], "material": "void_bloom",
			"gifts": {"shadow_damage": ["flat", 2.5], "critical_chance": ["flat", 0.02], "life_steal": ["flat", 0.008]}, "text": "Gone down into the dark and come back changed.", "look": {"skin": 15, "eyes": 4}},
	],
	"dwarf": [
		{"name": "Hill Dwarf", "pace": "swift", "stages": ["Hill Dwarf", "Prospector", "Deepdelver", "Lode-lord"], "material": "copper_ingot",
			"gifts": {"mining_efficiency": ["percent", 0.06], "max_stamina": ["flat", 8.0], "gold_find": ["flat", 0.03]}, "text": "Knows where the good seams run."},
		{"name": "Ironbeard", "pace": "balanced", "stages": ["Shieldbearer", "Ironbeard", "Hold-warden", "Mountain King"], "material": "iron_ingot",
			"gifts": {"armor": ["percent", 0.04], "max_health": ["percent", 0.03], "knockback_resistance": ["flat", 0.03]}, "text": "Stands like the hold's own gate."},
		{"name": "Runesmith", "pace": "slow", "stages": ["Rune-marked", "Runesmith", "Forge-lord", "Runelord"], "material": "gold_ingot",
			"gifts": {"physical_damage": ["percent", 0.03], "armor": ["percent", 0.04], "fire_resist": ["flat", 0.03]}, "text": "Fire and runes worked into the bone.", "look": {"eyes": 3}},
	],
	"orc": [
		{"name": "Raider", "pace": "swift", "stages": ["Raider", "Reaver", "Warband Runner", "Storm of the Steppe"], "material": "hare_pelt",
			"gifts": {"attack_speed": ["percent", 0.025], "move_speed": ["percent", 0.02], "life_steal": ["flat", 0.005]}, "text": "Hit fast, take what you can, ride on."},
		{"name": "Warchief", "pace": "balanced", "stages": ["Brute", "Warrior", "Warlord", "Warchief"], "material": "boar_tusk",
			"gifts": {"physical_damage": ["percent", 0.04], "max_health": ["percent", 0.03]}, "text": "The biggest and loudest, and so the leader."},
		{"name": "Blood Orc", "pace": "slow", "stages": ["Blood-sworn", "Blood Orc", "Uruk", "Blood Tyrant"], "material": "venom_sac",
			"gifts": {"physical_damage": ["percent", 0.05], "damage_taken": ["percent", -0.015], "critical_damage": ["flat", 0.04]}, "text": "Blooded in a hundred fights.", "look": {"skin": 11, "eyes": 4}},
	],
	"goblin": [
		{"name": "Shadowfoot", "pace": "swift", "stages": ["Sneak", "Cutpurse", "Shadowfoot", "Ghost of the Market"], "material": "thornberries",
			"gifts": {"dodge_efficiency": ["flat", 0.03], "move_speed": ["percent", 0.025], "critical_chance": ["flat", 0.01]}, "text": "Never there when the blow lands."},
		{"name": "Tinker", "pace": "balanced", "stages": ["Scrounger", "Tinker", "Gadgeteer", "Goblin Genius"], "material": "copper_ingot",
			"gifts": {"gold_find": ["flat", 0.05], "magic_find": ["flat", 0.03], "attack_speed": ["percent", 0.02]}, "text": "Every pocket full of useful junk."},
		{"name": "Hobgoblin", "pace": "slow", "stages": ["Hobgoblin", "Boss", "Big Boss", "Goblin King"], "material": "boss_trophy",
			"gifts": {"max_health": ["percent", 0.04], "physical_damage": ["percent", 0.035], "armor": ["percent", 0.03]}, "text": "Grew big, and meaner with it.", "look": {"height": 2, "build": 1}},
	],
	"slime": [
		{"name": "Quickgel", "pace": "swift", "stages": ["Quickgel", "Slick", "Splashdancer", "Living Torrent"], "material": "toad_slime",
			"gifts": {"move_speed": ["percent", 0.025], "health_regen": ["flat", 0.4], "dodge_efficiency": ["flat", 0.02]}, "text": "Slips through gaps and out of trouble."},
		{"name": "Ooze", "pace": "balanced", "stages": ["Ooze", "Acid Ooze", "Corroder", "Devouring Ooze"], "material": "venom_sac",
			"gifts": {"poison_damage": ["flat", 2.0], "poison_resist": ["flat", 0.04], "health_regen": ["flat", 0.4]}, "text": "Everything it touches starts to melt.", "look": {"skin": 6}},
		{"name": "Royal Jelly", "pace": "slow", "stages": ["Gelatin", "Royal Jelly", "Slime Noble", "Slime Monarch"], "material": "heart_shard",
			"gifts": {"max_health": ["percent", 0.05], "damage_taken": ["percent", -0.02], "health_regen": ["flat", 0.6]}, "text": "A slime of standing, and of size.", "look": {"eyes": 7, "height": 3}},
	],
	"undead": [
		{"name": "Ghoul", "pace": "swift", "stages": ["Ghoul", "Grave Runner", "Ghast", "Hunger Unending"], "material": "bone",
			"gifts": {"attack_speed": ["percent", 0.025], "life_steal": ["flat", 0.006], "move_speed": ["percent", 0.02]}, "text": "Always hungry, never tired."},
		{"name": "Revenant", "pace": "balanced", "stages": ["Risen", "Revenant", "Death Knight", "Deathless"], "material": "iron_ingot",
			"gifts": {"shadow_resist": ["flat", 0.04], "life_steal": ["flat", 0.006], "max_health": ["percent", 0.03]}, "text": "Came back with a purpose, and armour."},
		{"name": "Lich", "pace": "slow", "stages": ["Bonecaller", "Necromancer", "Lich", "Archlich"], "material": "void_bloom",
			"gifts": {"magic_power": ["percent", 0.05], "shadow_damage": ["flat", 2.5], "max_mana": ["percent", 0.04]}, "text": "Death, studied until it obeys.", "look": {"eyes": 8}},
	],
	"demonkin": [
		{"name": "Imp", "pace": "swift", "stages": ["Imp", "Firefly", "Flickerfiend", "Wildfire"], "material": "emberbloom",
			"gifts": {"move_speed": ["percent", 0.025], "fire_damage": ["flat", 1.5], "dodge_efficiency": ["flat", 0.02]}, "text": "A spark that never sits still."},
		{"name": "Hellborn", "pace": "balanced", "stages": ["Hellborn", "Flamecaller", "Pit Lord", "Infernal Duke"], "material": "ember_core",
			"gifts": {"fire_damage": ["flat", 2.5], "physical_damage": ["percent", 0.03], "fire_resist": ["flat", 0.03]}, "text": "The ember fields remember their own."},
		{"name": "Archfiend", "pace": "slow", "stages": ["Fiend", "Greater Fiend", "Demon Lord", "Archfiend"], "material": "heart_shard",
			"gifts": {"physical_damage": ["percent", 0.04], "fire_damage": ["flat", 3.0], "life_steal": ["flat", 0.006]}, "text": "Old fire, and older hunger.", "look": {"skin": 11, "eyes": 7}},
	],
	"beastkin": [
		{"name": "Swiftpaw", "pace": "swift", "stages": ["Swiftpaw", "Runner", "Windchaser", "Gale-born"], "material": "hare_pelt",
			"gifts": {"move_speed": ["percent", 0.03], "attack_speed": ["percent", 0.02]}, "text": "Nothing on two legs can catch you."},
		{"name": "Wildheart", "pace": "balanced", "stages": ["Wildheart", "Packrunner", "Packleader", "Spirit of the Wild"], "material": "frost_pelt",
			"gifts": {"critical_chance": ["flat", 0.015], "attack_speed": ["percent", 0.02], "max_health": ["percent", 0.02]}, "text": "The pack's instinct, and its loyalty."},
		{"name": "Primal", "pace": "slow", "stages": ["Feral", "Primal", "Apex", "Alpha"], "material": "boar_tusk",
			"gifts": {"physical_damage": ["percent", 0.04], "critical_damage": ["flat", 0.05], "life_steal": ["flat", 0.005]}, "text": "The beast inside, given its head.", "look": {"eyes": 3}},
	],
	"lizardfolk": [
		{"name": "Skink", "pace": "swift", "stages": ["Skink", "Quickscale", "Darter", "Shimmerscale"], "material": "lizard_scale",
			"gifts": {"move_speed": ["percent", 0.025], "dodge_efficiency": ["flat", 0.025], "poison_damage": ["flat", 1.0]}, "text": "Small, fast and hard to hold."},
		{"name": "Scaleguard", "pace": "balanced", "stages": ["Scaleguard", "Shellback", "Bulwark", "Ancient Scale"], "material": "crab_shell",
			"gifts": {"armor": ["percent", 0.04], "poison_resist": ["flat", 0.03], "health_regen": ["flat", 0.3]}, "text": "Scales like plate, and the patience of stone."},
		{"name": "Dragonkin", "pace": "slow", "stages": ["Drake-blooded", "Drake", "Wyrm", "Dragonkin"], "material": "ember_core",
			"gifts": {"fire_damage": ["flat", 2.5], "max_health": ["percent", 0.04], "armor": ["percent", 0.03]}, "text": "The blood of old dragons stirs.", "look": {"horns": 3, "eyes": 3}},
	],
	"fairy": [
		{"name": "Pixie", "pace": "swift", "stages": ["Pixie", "Flitter", "Will-o'-wisp", "Starlight Trickster"], "material": "wild_berries",
			"gifts": {"dodge_efficiency": ["flat", 0.03], "move_speed": ["percent", 0.025]}, "text": "Now here, now there, now laughing behind you."},
		{"name": "Fae Noble", "pace": "balanced", "stages": ["Sprite", "Fae Courtier", "Fae Noble", "Summer Lord"], "material": "mana_flower",
			"gifts": {"magic_power": ["percent", 0.04], "max_mana": ["percent", 0.04]}, "text": "Glamour, manners and dangerous favours."},
		{"name": "Archfey", "pace": "slow", "stages": ["Wild Fae", "Old Fae", "Fae Queen", "Archfey"], "material": "sunroot",
			"gifts": {"magic_power": ["percent", 0.05], "holy_damage": ["flat", 2.0], "damage_taken": ["percent", -0.01]}, "text": "Older than the forest, and twice as strange.", "look": {"eyes": 9}},
	],
	"stoneborn": [
		{"name": "Gravelborn", "pace": "swift", "stages": ["Gravelborn", "Rolling Stone", "Avalanche", "Landslide"], "material": "stone",
			"gifts": {"move_speed": ["percent", 0.02], "attack_speed": ["percent", 0.02], "mining_efficiency": ["percent", 0.05]}, "text": "Loose stone moves quickest."},
		{"name": "Graniteheart", "pace": "balanced", "stages": ["Granite", "Graniteheart", "Bastion", "Living Fortress"], "material": "iron_ingot",
			"gifts": {"armor": ["percent", 0.05], "max_health": ["percent", 0.03]}, "text": "A wall that walks."},
		{"name": "Colossus", "pace": "slow", "stages": ["Monolith", "Titan-stone", "Colossus", "Mountain Walking"], "material": "stone_heart",
			"gifts": {"damage_taken": ["percent", -0.02], "armor": ["percent", 0.05], "knockback_resistance": ["flat", 0.04]}, "text": "The mountain itself, risen.", "look": {"height": 4, "build": 2}},
	],
	"vampire": [
		{"name": "Nightstalker", "pace": "swift", "stages": ["Fledgling", "Nightstalker", "Night Hunter", "Shadow of Night"], "material": "bloodcap",
			"gifts": {"move_speed": ["percent", 0.025], "critical_chance": ["flat", 0.015]}, "text": "Fast in the dark and gone by dawn."},
		{"name": "Noble Vampire", "pace": "balanced", "stages": ["Courtly", "Noble Vampire", "Count", "Elder of the Court"], "material": "gold_ingot",
			"gifts": {"life_steal": ["flat", 0.008], "magic_power": ["percent", 0.03]}, "text": "Old manners, old money, old hunger."},
		{"name": "Vampire Lord", "pace": "slow", "stages": ["Blood-drinker", "Elder Vampire", "Vampire Lord", "Lord of the Night"], "material": "heart_shard",
			"gifts": {"life_steal": ["flat", 0.01], "shadow_damage": ["flat", 2.5], "max_health": ["percent", 0.04]}, "text": "Centuries of blood, made into power.", "look": {"eyes": 4}},
	],
	"merfolk": [
		{"name": "Reef Runner", "pace": "swift", "stages": ["Reef Runner", "Wave-rider", "Current", "Riptide"], "material": "minnow",
			"gifts": {"move_speed": ["percent", 0.025], "stamina_regen": ["percent", 0.04]}, "text": "Moves on land as in a current."},
		{"name": "Tidecaller", "pace": "balanced", "stages": ["Tidecaller", "Tide-singer", "Stormtide", "Voice of the Deep"], "material": "pike",
			"gifts": {"max_mana": ["percent", 0.04], "frost_damage": ["flat", 1.5], "magic_power": ["percent", 0.03]}, "text": "The sea answers when called."},
		{"name": "Leviathan-blood", "pace": "slow", "stages": ["Deep-born", "Abyssal", "Leviathan-blood", "Leviathan"], "material": "salmon",
			"gifts": {"max_health": ["percent", 0.05], "frost_resist": ["flat", 0.04], "armor": ["percent", 0.03]}, "text": "Something vast from the deep water.", "look": {"skin": 13, "eyes": 8}},
	],
}


static func paths(race: String) -> Array:
	return PATHS.get(race, PATHS["human"])


## The gifts of a stage (1-4) on a path, as stat modifiers.
static func mods(race: String, path: int, stage: int) -> Dictionary:
	if path < 0 or stage <= 0:
		return {}
	var data: Dictionary = paths(race)[path]
	var power: float = STAGE_POWER[stage - 1] * float(PACES[data["pace"]]["power"])
	var result := {}
	for stat: String in data["gifts"]:
		var gift: Array = data["gifts"][stat]
		result[stat] = {gift[0]: float(gift[1]) * power}
	return result


## What a stage (1-4) asks: {"level", "bosses", "items": {id: count}}.
static func cost(race: String, path: int, stage: int) -> Dictionary:
	var data: Dictionary = paths(race)[path]
	var pace: Dictionary = PACES[data["pace"]]
	var items := {}
	var index := stage - 1
	if int(pace["shards"][index]) > 0:
		items["heart_shard"] = int(pace["shards"][index])
	if int(pace["trophies"][index]) > 0:
		items["boss_trophy"] = int(pace["trophies"][index]) + int(items.get("boss_trophy", 0))
	if int(pace["material"][index]) > 0 and ItemDB.ITEMS.has(data["material"]):
		items[data["material"]] = int(pace["material"][index]) + int(items.get(data["material"], 0))
	return {"level": pace["levels"][index], "bosses": pace["bosses"][index], "items": items}
