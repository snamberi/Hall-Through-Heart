extends RefCounted
## Trinkets: charms worn on the head, body, feet and hands (in the Trinkets
## window of the bag). Each grows from level 1 to 3 by doing what it is
## about, never by gold:
##
##   level 1  a strength (more damage, more health, quicker feet...)
##   level 2  that strength greater, and a small gift of its own (a shorter
##            dash, a longer one, potions sooner...)
##   level 3  a power: seeing in the dark, walking on water, climbing the
##            high ground, recipes no one else knows, wood that goes further
##
## An Orb of Awakening (one chest in a hundred) raises one to level 3 at once.
## (Loaded by path; no class name, so a stale editor cache cannot break it.)

const SLOTS: Array[String] = ["trinket_head", "trinket_body", "trinket_feet", "trinket_hands"]
const SLOT_NAMES := {"trinket_head": "Head charm", "trinket_body": "Body charm", "trinket_feet": "Foot charm", "trinket_hands": "Hand charm"}
const MAX_LEVEL := 3
const ORB := "orb_of_awakening"

## What each activity is called, for "Slay monsters 12 / 40".
const ACTIVITIES := {
	"kills": "Slay monsters", "spells": "Cast spells", "meals": "Eat meals", "felled": "Fell trees", "crafted": "Craft things",
	"potions": "Drink potions", "walked": "Walk tiles", "swum": "Swim tiles", "dashes": "Dash", "mined": "Mine ore and stone",
	"parries": "Parry blows", "abilities": "Use abilities",
}

## id -> its slot, what raises it, how much for levels 2 and 3, the
## strength at levels 1 and 2 (with the small gift's words), the power.
const TRINKETS := {
	"hunters_circlet": {"name": "Hunter's Circlet", "slot": "trinket_head", "activity": "kills", "goals": [40, 240],
		"l1": {"physical_damage": {"percent": 0.05}},
		"l2": {"physical_damage": {"percent": 0.1}, "critical_chance": {"flat": 0.03}}, "gift": "+3% critical chance",
		"power": "night_eyes", "power_name": "Night Eyes", "power_text": "See in the dark: night and caves are lit wide around you."},
	"scholars_band": {"name": "Scholar's Band", "slot": "trinket_head", "activity": "spells", "goals": [40, 250],
		"l1": {"magic_power": {"percent": 0.06}},
		"l2": {"magic_power": {"percent": 0.12}, "max_mana": {"percent": 0.1}}, "gift": "+10% maximum mana",
		"power": "deep_lore", "power_name": "Deep Lore", "power_text": "Learn recipes no one else knows: greater potions and runed salves."},
	"cooks_kerchief": {"name": "Cook's Kerchief", "slot": "trinket_head", "activity": "meals", "goals": [15, 90],
		"l1": {"max_health": {"percent": 0.05}},
		"l2": {"max_health": {"percent": 0.1}, "health_regen": {"flat": 0.6}}, "gift": "+0.6 health regained each second",
		"power": "hearty", "power_name": "Hearty", "power_text": "Every meal also heals a fifth of your health."},
	"woodwrights_apron": {"name": "Woodwright's Apron", "slot": "trinket_body", "activity": "felled", "goals": [40, 260],
		"l1": {"armor": {"percent": 0.04}},
		"l2": {"armor": {"percent": 0.08}, "max_stamina": {"percent": 0.08}}, "gift": "+8% maximum stamina",
		"power": "thrift_of_wood", "power_name": "Thrift of Wood", "power_text": "Every recipe that takes wood takes a third less."},
	"smiths_vest": {"name": "Smith's Vest", "slot": "trinket_body", "activity": "crafted", "goals": [25, 160],
		"l1": {"armor": {"percent": 0.05}},
		"l2": {"armor": {"percent": 0.1}, "elemental_resistance": {"flat": 0.04}}, "gift": "+4% elemental resistance",
		"power": "masterwork", "power_name": "Masterwork", "power_text": "Learn the smith's secret recipes: tempered plates and fine whetstones."},
	"alchemists_bandolier": {"name": "Alchemist's Bandolier", "slot": "trinket_body", "activity": "potions", "goals": [12, 70],
		"l1": {"max_health": {"percent": 0.04}},
		"l2": {"max_health": {"percent": 0.08}}, "gift": "potions ready a third sooner",
		"power": "distiller", "power_name": "Distiller", "power_text": "Every potion also mends you for eight seconds after."},
	"wayfarers_anklet": {"name": "Wayfarer's Anklet", "slot": "trinket_feet", "activity": "walked", "goals": [3000, 18000],
		"l1": {"move_speed": {"percent": 0.04}},
		"l2": {"move_speed": {"percent": 0.08}, "dodge_distance": {"percent": 0.2}}, "gift": "dashes reach a fifth further",
		"power": "mountain_goat", "power_name": "Mountain Goat", "power_text": "Climb straight up the cliffs and banks that block others."},
	"tide_charm": {"name": "Tide Charm", "slot": "trinket_feet", "activity": "swum", "goals": [250, 1600],
		"l1": {"move_speed": {"percent": 0.03}},
		"l2": {"move_speed": {"percent": 0.06}, "max_stamina": {"percent": 0.1}}, "gift": "swim at near your walking pace",
		"power": "waterwalker", "power_name": "Waterwalker", "power_text": "Walk on water as on dry land."},
	"quickstep_spurs": {"name": "Quickstep Spurs", "slot": "trinket_feet", "activity": "dashes", "goals": [100, 600],
		"l1": {"dodge_efficiency": {"percent": 0.1}},
		"l2": {"dodge_efficiency": {"percent": 0.2}, "dodge_distance": {"percent": 0.15}}, "gift": "dash cooldown a fifth shorter, dashes further",
		"power": "phase_step", "power_name": "Phase Step", "power_text": "Untouchable for twice as long in every dash."},
	"miners_gauntlets": {"name": "Miner's Gauntlets", "slot": "trinket_hands", "activity": "mined", "goals": [60, 380],
		"l1": {"mining_efficiency": {"percent": 0.1}},
		"l2": {"mining_efficiency": {"percent": 0.2}, "physical_damage": {"percent": 0.04}}, "gift": "+4% physical damage",
		"power": "prospector", "power_name": "Prospector", "power_text": "One stone in four gives twice the ore."},
	"duelists_grips": {"name": "Duelist's Grips", "slot": "trinket_hands", "activity": "parries", "goals": [20, 130],
		"l1": {"attack_speed": {"percent": 0.04}},
		"l2": {"attack_speed": {"percent": 0.08}, "critical_damage": {"flat": 0.1}}, "gift": "+10% critical damage",
		"power": "riposte", "power_name": "Riposte", "power_text": "Every parry heals a tenth of your health."},
	"brawlers_wraps": {"name": "Brawler's Wraps", "slot": "trinket_hands", "activity": "abilities", "goals": [60, 380],
		"l1": {"critical_damage": {"flat": 0.06}},
		"l2": {"critical_damage": {"flat": 0.12}, "life_steal": {"flat": 0.01}}, "gift": "+1% life steal",
		"power": "second_wind", "power_name": "Second Wind", "power_text": "Fall below a quarter of your health and a fifth of it comes back (once a minute)."},
}


static func is_trinket(item_id: String) -> bool:
	return TRINKETS.has(item_id)


## The strength a trinket gives at its level.
static func mods(item_id: String, level: int) -> Dictionary:
	var data: Dictionary = TRINKETS.get(item_id, {})
	if data.is_empty():
		return {}
	return data["l2"] if level >= 2 else data["l1"]


## How much activity a trinket needs to reach its next level (0 at the top).
static func goal(item_id: String, level: int) -> int:
	if level >= MAX_LEVEL or not TRINKETS.has(item_id):
		return 0
	return int(TRINKETS[item_id]["goals"][level - 1])


## Its lines for a tooltip: each level, the one reached marked.
static func describe(item_id: String, level: int, progress: float) -> PackedStringArray:
	var data: Dictionary = TRINKETS[item_id]
	var lines: PackedStringArray = []
	lines.append("Level %d of %d" % [level, MAX_LEVEL])
	lines.append(("● " if level >= 1 else "○ ") + "1: " + words(data["l1"]))
	lines.append(("● " if level >= 2 else "○ ") + "2: " + words(data["l2"]) + ", " + str(data["gift"]))
	lines.append(("● " if level >= 3 else "○ ") + "3: " + str(data["power_name"]) + ". " + str(data["power_text"]))
	if level < MAX_LEVEL:
		lines.append("%s: %d / %d to level %d" % [ACTIVITIES[data["activity"]], int(progress), goal(item_id, level), level + 1])
	return lines


## A strength in words: "+5% physical damage, +3% critical chance".
static func words(mods_in: Dictionary) -> String:
	var parts: PackedStringArray = []
	for stat: String in mods_in:
		for kind: String in mods_in[stat]:
			parts.append(ItemDB.describe_modifier({"stat": stat, "kind": kind, "value": float(mods_in[stat][kind])}))
	return ", ".join(parts)
