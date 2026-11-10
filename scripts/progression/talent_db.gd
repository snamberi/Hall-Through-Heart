class_name TalentDB
extends RefCounted
## The talent trees. Ids are stable; saves store ranks by id.
##
## Each node:
##   "tree"      which tree it belongs to
##   "pos"       column and row in the tree's grid (row 0 is the top)
##   "kind"      minor (stackable), major (one strong rank), keystone (build-defining)
##   "max"       ranks it can take
##   "requires"  node ids that each need at least one rank first
##   "mods"      stat id -> {"flat"/"percent": amount per rank}
##   "text"      shown for effects that are not plain stat changes
## Only talents whose effects exist in the game are listed.

const TREES: Array[Dictionary] = [
	{"id": "offense", "name": "Offense", "icon": 0},
	{"id": "defense", "name": "Defense", "icon": 5},
	{"id": "mobility", "name": "Mobility", "icon": 39},
	{"id": "fortune", "name": "Fortune", "icon": 40},
	{"id": "survival", "name": "Survival", "icon": 35},
]

const NODES := {
	# --- offense
	"sharpened_edge": {"name": "Sharpened Edge", "tree": "offense", "pos": Vector2i(1, 0), "kind": "minor", "max": 5, "icon": 0,
		"mods": {"physical_damage": {"percent": 0.02}}},
	"quick_hands": {"name": "Quick Hands", "tree": "offense", "pos": Vector2i(0, 1), "kind": "minor", "max": 5, "icon": 3,
		"requires": ["sharpened_edge"], "mods": {"attack_speed": {"percent": 0.015}}},
	"cruelty": {"name": "Cruelty", "tree": "offense", "pos": Vector2i(2, 1), "kind": "minor", "max": 5, "icon": 15,
		"requires": ["sharpened_edge"], "mods": {"critical_damage": {"flat": 0.06}}},
	"killing_rhythm": {"name": "Killing Rhythm", "tree": "offense", "pos": Vector2i(1, 2), "kind": "major", "max": 1, "icon": 31,
		"requires": ["quick_hands", "cruelty"], "mods": {"physical_damage": {"percent": 0.08}, "attack_speed": {"percent": 0.04}}},
	"berserker": {"name": "Berserker", "tree": "offense", "pos": Vector2i(0, 3), "kind": "keystone", "max": 1, "icon": 2,
		"requires": ["killing_rhythm"], "mods": {"damage_taken": {"percent": 0.15}},
		"text": "Deal 40% more damage while below 35% health."},
	"glass_cannon": {"name": "Glass Cannon", "tree": "offense", "pos": Vector2i(1, 3), "kind": "keystone", "max": 1, "icon": 18,
		"requires": ["killing_rhythm"], "mods": {"physical_damage": {"percent": 0.3}, "max_health": {"percent": -0.25}}},
	"vampiric_strike": {"name": "Vampiric Strike", "tree": "offense", "pos": Vector2i(2, 3), "kind": "keystone", "max": 1, "icon": 20,
		"requires": ["killing_rhythm"], "mods": {"life_steal": {"flat": 0.03}},
		"text": "No single hit heals more than 5% of your maximum health."},
	# --- defense
	"toughness": {"name": "Toughness", "tree": "defense", "pos": Vector2i(0, 0), "kind": "minor", "max": 5, "icon": 35,
		"mods": {"max_health": {"percent": 0.03}}},
	"thick_hide": {"name": "Thick Hide", "tree": "defense", "pos": Vector2i(2, 0), "kind": "minor", "max": 5, "icon": 7,
		"mods": {"armor": {"flat": 3.0, "percent": 0.05}}},
	"recovery": {"name": "Recovery", "tree": "defense", "pos": Vector2i(0, 1), "kind": "minor", "max": 5, "icon": 16,
		"requires": ["toughness"], "mods": {"health_regen": {"flat": 0.4}}},
	"bulwark": {"name": "Bulwark", "tree": "defense", "pos": Vector2i(1, 2), "kind": "major", "max": 1, "icon": 5,
		"requires": ["toughness", "thick_hide"], "mods": {"damage_taken": {"percent": -0.06}}},
	"unbreakable": {"name": "Unbreakable", "tree": "defense", "pos": Vector2i(1, 3), "kind": "keystone", "max": 1, "icon": 6,
		"requires": ["bulwark"], "mods": {},
		"text": "A blow that would kill you leaves you at 1 health instead. Once every 2 minutes."},
	# --- mobility
	"fleet_foot": {"name": "Fleet Foot", "tree": "mobility", "pos": Vector2i(1, 0), "kind": "minor", "max": 5, "icon": 9,
		"mods": {"move_speed": {"percent": 0.02}}},
	"tumbler": {"name": "Tumbler", "tree": "mobility", "pos": Vector2i(0, 1), "kind": "minor", "max": 5, "icon": 39,
		"requires": ["fleet_foot"], "mods": {"dodge_efficiency": {"percent": 0.04}}},
	"second_wind": {"name": "Second Wind", "tree": "mobility", "pos": Vector2i(2, 1), "kind": "minor", "max": 5, "icon": 37,
		"requires": ["fleet_foot"], "mods": {"stamina_regen": {"percent": 0.06}}},
	"long_roll": {"name": "Long Roll", "tree": "mobility", "pos": Vector2i(0, 2), "kind": "major", "max": 1, "icon": 29,
		"requires": ["tumbler"], "mods": {"dodge_distance": {"percent": 0.2}}},
	"perfect_dodge": {"name": "Perfect Dodge", "tree": "mobility", "pos": Vector2i(0, 3), "kind": "keystone", "max": 1, "icon": 29,
		"requires": ["long_roll"], "mods": {},
		"text": "Dodging through an attack grants +30% critical-hit chance for 5 seconds."},
	# --- fortune
	"keen_eye": {"name": "Keen Eye", "tree": "fortune", "pos": Vector2i(0, 0), "kind": "minor", "max": 5, "icon": 12,
		"mods": {"magic_find": {"flat": 0.02}}},
	"prospector": {"name": "Prospector", "tree": "fortune", "pos": Vector2i(2, 0), "kind": "minor", "max": 5, "icon": 17,
		"mods": {"gold_find": {"percent": 0.05}}},
	"lucky_strikes": {"name": "Lucky Strikes", "tree": "fortune", "pos": Vector2i(0, 1), "kind": "minor", "max": 5, "icon": 40,
		"requires": ["keen_eye"], "mods": {"critical_chance": {"flat": 0.01}}},
	"windfall": {"name": "Windfall", "tree": "fortune", "pos": Vector2i(1, 2), "kind": "major", "max": 1, "icon": 11,
		"requires": ["keen_eye", "prospector"], "mods": {"magic_find": {"flat": 0.1}, "gold_find": {"percent": 0.15}}},
	"treasure_hunter": {"name": "Treasure Hunter", "tree": "fortune", "pos": Vector2i(1, 3), "kind": "keystone", "max": 1, "icon": 10,
		"requires": ["windfall"], "mods": {"magic_find": {"flat": 0.25}, "gold_find": {"percent": 0.25}, "physical_damage": {"percent": -0.08}}},
	# --- survival
	"hardy": {"name": "Hardy", "tree": "survival", "pos": Vector2i(0, 0), "kind": "minor", "max": 5, "icon": 37,
		"mods": {"max_stamina": {"percent": 0.03}}},
	"deep_breath": {"name": "Deep Breath", "tree": "survival", "pos": Vector2i(2, 0), "kind": "minor", "max": 5, "icon": 36,
		"mods": {"max_mana": {"percent": 0.04}, "mana_regen": {"percent": 0.06}}},
	"field_medic": {"name": "Field Medic", "tree": "survival", "pos": Vector2i(0, 1), "kind": "minor", "max": 5, "icon": 35,
		"requires": ["hardy"], "mods": {"health_regen": {"flat": 0.3}}},
	"survivor": {"name": "Survivor", "tree": "survival", "pos": Vector2i(1, 2), "kind": "major", "max": 1, "icon": 13,
		"requires": ["hardy", "deep_breath"], "mods": {"max_health": {"percent": 0.1}, "health_regen": {"flat": 1.0}}},
}


static func nodes_in(tree: String) -> Array[String]:
	var ids: Array[String] = []
	for id: String in NODES:
		if NODES[id]["tree"] == tree:
			ids.append(id)
	return ids


## Lines describing what `ranks` ranks of a node give.
static func describe(id: String, ranks: int) -> PackedStringArray:
	var lines: PackedStringArray = []
	var mods: Dictionary = NODES[id]["mods"]
	for stat: String in mods:
		for kind: String in mods[stat]:
			var amount: float = mods[stat][kind] * ranks
			var text := ItemDB.describe_modifier({"stat": stat, "kind": kind, "value": absf(amount)})
			lines.append(text if amount >= 0.0 else "-" + text.substr(1))
	if NODES[id].has("text"):
		lines.append(NODES[id]["text"])
	return lines
