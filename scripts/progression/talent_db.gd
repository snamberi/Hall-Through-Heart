class_name TalentDB
extends RefCounted
## The talent tree: one connected web. It starts at the Awakened Heart in
## the middle; five branches reach outward (Offense, Mobility, Defense,
## Survival, Fortune) and rings join neighbouring branches, so a build can
## wander from one to the next.
##
## A talent can be learned when one of its neighbours has a rank. Milestone
## talents (big, gold-rimmed) also need a number of points already spent in
## the tree: the first point, then every 10th, opens something major.
## Ids are stable; saves store ranks by id.

## Branch name, angle on screen, and colour.
const BRANCHES := {
	"offense": ["Offense", -PI / 2.0, Color("e0605a")],
	"mobility": ["Mobility", -PI / 2.0 + TAU / 5.0, Color("8fd66a")],
	"defense": ["Defense", -PI / 2.0 + TAU * 2.0 / 5.0, Color("7aa8e0")],
	"survival": ["Survival", -PI / 2.0 + TAU * 3.0 / 5.0, Color("e09ad0")],
	"fortune": ["Fortune", -PI / 2.0 + TAU * 4.0 / 5.0, Color("f0cf6a")],
}
const STEP := 92.0

## Each node: name, branch, ring (distance out), side (angle offset), kind,
## max ranks, mods per rank, optional "text", optional "milestone" (points
## that must already be spent), icon.
const NODES := {
	"awakened_heart": {"name": "Awakened Heart", "branch": "", "ring": 0, "side": 0.0, "kind": "milestone", "max": 1, "milestone": 0, "icon": 35,
		"mods": {"physical_damage": {"percent": 0.08}, "max_health": {"percent": 0.08}, "move_speed": {"percent": 0.05}},
		"text": "The first beat. The start of every path."},
	# --- offense
	"sharpened_edge": {"name": "Sharpened Edge", "branch": "offense", "ring": 1, "side": 0.0, "kind": "minor", "max": 3, "icon": 0, "mods": {"physical_damage": {"percent": 0.03}}},
	"quick_hands": {"name": "Quick Hands", "branch": "offense", "ring": 2, "side": 0.0, "kind": "minor", "max": 3, "icon": 3, "mods": {"attack_speed": {"percent": 0.025}}},
	"bloodlust": {"name": "Bloodlust", "branch": "offense", "ring": 3, "side": 0.0, "kind": "milestone", "max": 1, "milestone": 10, "icon": 1,
		"mods": {"physical_damage": {"percent": 0.15}, "attack_speed": {"percent": 0.05}}},
	"cruelty": {"name": "Cruelty", "branch": "offense", "ring": 4, "side": 0.0, "kind": "minor", "max": 3, "icon": 15, "mods": {"critical_damage": {"flat": 0.1}}},
	"keen_strikes": {"name": "Keen Strikes", "branch": "offense", "ring": 4, "side": 0.32, "kind": "minor", "max": 3, "icon": 40, "mods": {"critical_chance": {"flat": 0.015}}},
	"executioner": {"name": "Executioner", "branch": "offense", "ring": 5, "side": 0.0, "kind": "milestone", "max": 1, "milestone": 20, "icon": 22, "mods": {},
		"text": "Deal 40% more damage to enemies below 30% health."},
	"killing_rhythm": {"name": "Killing Rhythm", "branch": "offense", "ring": 6, "side": 0.0, "kind": "major", "max": 1, "icon": 31,
		"mods": {"physical_damage": {"percent": 0.08}, "attack_speed": {"percent": 0.06}}},
	"berserker": {"name": "Berserker", "branch": "offense", "ring": 7, "side": -0.12, "kind": "keystone", "max": 1, "milestone": 30, "icon": 2,
		"mods": {"damage_taken": {"percent": 0.15}}, "text": "Deal 40% more damage while below 35% health."},
	"glass_cannon": {"name": "Glass Cannon", "branch": "offense", "ring": 7, "side": 0.12, "kind": "keystone", "max": 1, "milestone": 30, "icon": 18,
		"mods": {"physical_damage": {"percent": 0.3}, "max_health": {"percent": -0.25}}},
	# --- mobility
	"fleet_foot": {"name": "Fleet Foot", "branch": "mobility", "ring": 1, "side": 0.0, "kind": "minor", "max": 3, "icon": 9, "mods": {"move_speed": {"percent": 0.025}}},
	"second_wind": {"name": "Second Wind", "branch": "mobility", "ring": 2, "side": 0.0, "kind": "minor", "max": 3, "icon": 37, "mods": {"stamina_regen": {"percent": 0.08}}},
	"wind_runner": {"name": "Wind Runner", "branch": "mobility", "ring": 3, "side": 0.0, "kind": "milestone", "max": 1, "milestone": 10, "icon": 39,
		"mods": {"move_speed": {"percent": 0.12}, "dodge_distance": {"percent": 0.2}}},
	"tumbler": {"name": "Tumbler", "branch": "mobility", "ring": 4, "side": 0.0, "kind": "minor", "max": 3, "icon": 29, "mods": {"dodge_efficiency": {"percent": 0.05}}},
	"light_step": {"name": "Light Step", "branch": "mobility", "ring": 4, "side": 0.32, "kind": "minor", "max": 3, "icon": 9, "mods": {"max_stamina": {"flat": 10.0}}},
	"phantom_step": {"name": "Phantom Step", "branch": "mobility", "ring": 5, "side": 0.0, "kind": "milestone", "max": 1, "milestone": 20, "icon": 29,
		"mods": {"dodge_efficiency": {"percent": 0.3}, "stamina_cost_multiplier": {"percent": -0.3}}},
	"swift_blade": {"name": "Swift Blade", "branch": "mobility", "ring": 6, "side": 0.0, "kind": "major", "max": 1, "icon": 3, "mods": {"attack_speed": {"percent": 0.08}, "move_speed": {"percent": 0.05}}},
	"perfect_dodge": {"name": "Perfect Dodge", "branch": "mobility", "ring": 7, "side": 0.0, "kind": "keystone", "max": 1, "milestone": 30, "icon": 29, "mods": {},
		"text": "Dodging through an attack grants +30% critical-hit chance for 5 seconds."},
	# --- defense
	"toughness": {"name": "Toughness", "branch": "defense", "ring": 1, "side": 0.0, "kind": "minor", "max": 3, "icon": 35, "mods": {"max_health": {"percent": 0.04}}},
	"thick_hide": {"name": "Thick Hide", "branch": "defense", "ring": 2, "side": 0.0, "kind": "minor", "max": 3, "icon": 7, "mods": {"armor": {"flat": 4.0, "percent": 0.05}}},
	"bulwark": {"name": "Bulwark", "branch": "defense", "ring": 3, "side": 0.0, "kind": "milestone", "max": 1, "milestone": 10, "icon": 5,
		"mods": {"damage_taken": {"percent": -0.1}, "armor": {"percent": 0.15}}},
	"iron_will": {"name": "Iron Will", "branch": "defense", "ring": 4, "side": 0.0, "kind": "minor", "max": 3, "icon": 6, "mods": {"knockback_resistance": {"flat": 0.1}, "max_health": {"flat": 15.0}}},
	"plated": {"name": "Plated", "branch": "defense", "ring": 4, "side": 0.32, "kind": "minor", "max": 3, "icon": 7, "mods": {"armor": {"flat": 6.0}}},
	"last_stand": {"name": "Last Stand", "branch": "defense", "ring": 5, "side": 0.0, "kind": "milestone", "max": 1, "milestone": 20, "icon": 5, "mods": {},
		"text": "Below 30% health, take 30% less damage."},
	"fortress": {"name": "Fortress", "branch": "defense", "ring": 6, "side": 0.0, "kind": "major", "max": 1, "icon": 5, "mods": {"max_health": {"percent": 0.12}, "armor": {"percent": 0.2}}},
	"unbreakable": {"name": "Unbreakable", "branch": "defense", "ring": 7, "side": 0.0, "kind": "keystone", "max": 1, "milestone": 30, "icon": 6, "mods": {},
		"text": "A blow that would kill you leaves you at 1 health instead. Once every 2 minutes."},
	# --- survival
	"field_medic": {"name": "Field Medic", "branch": "survival", "ring": 1, "side": 0.0, "kind": "minor", "max": 3, "icon": 16, "mods": {"health_regen": {"flat": 0.5}}},
	"hardy": {"name": "Hardy", "branch": "survival", "ring": 2, "side": 0.0, "kind": "minor", "max": 3, "icon": 37, "mods": {"max_stamina": {"percent": 0.05}}},
	"second_heart": {"name": "Second Heart", "branch": "survival", "ring": 3, "side": 0.0, "kind": "milestone", "max": 1, "milestone": 10, "icon": 35,
		"mods": {"max_health": {"percent": 0.15}, "health_regen": {"flat": 1.5}}},
	"deep_breath": {"name": "Deep Breath", "branch": "survival", "ring": 4, "side": 0.0, "kind": "minor", "max": 3, "icon": 36, "mods": {"max_mana": {"percent": 0.06}, "mana_regen": {"percent": 0.08}}},
	"forager": {"name": "Forager", "branch": "survival", "ring": 4, "side": 0.32, "kind": "minor", "max": 3, "icon": 44, "mods": {"gather_speed": {"percent": 0.08}}},
	"vampiric_strike": {"name": "Vampiric Strike", "branch": "survival", "ring": 5, "side": 0.0, "kind": "milestone", "max": 1, "milestone": 20, "icon": 20,
		"mods": {"life_steal": {"flat": 0.03}}, "text": "No single hit heals more than 5% of your maximum health."},
	"survivor": {"name": "Survivor", "branch": "survival", "ring": 6, "side": 0.0, "kind": "major", "max": 1, "icon": 13, "mods": {"max_health": {"percent": 0.1}, "health_regen": {"flat": 1.0}}},
	"undying": {"name": "Undying", "branch": "survival", "ring": 7, "side": 0.0, "kind": "keystone", "max": 1, "milestone": 30, "icon": 35, "mods": {},
		"text": "Health starts returning 2 seconds after a hit instead of 5, and twice as fast."},
	# --- fortune
	"keen_eye": {"name": "Keen Eye", "branch": "fortune", "ring": 1, "side": 0.0, "kind": "minor", "max": 3, "icon": 12, "mods": {"magic_find": {"flat": 0.03}}},
	"prospector": {"name": "Prospector", "branch": "fortune", "ring": 2, "side": 0.0, "kind": "minor", "max": 3, "icon": 17, "mods": {"gold_find": {"percent": 0.06}}},
	"golden_touch": {"name": "Golden Touch", "branch": "fortune", "ring": 3, "side": 0.0, "kind": "milestone", "max": 1, "milestone": 10, "icon": 17,
		"mods": {"gold_find": {"percent": 0.25}, "magic_find": {"flat": 0.15}}},
	"lucky_strikes": {"name": "Lucky Strikes", "branch": "fortune", "ring": 4, "side": 0.0, "kind": "minor", "max": 3, "icon": 40, "mods": {"critical_chance": {"flat": 0.012}}},
	"scavenger": {"name": "Scavenger", "branch": "fortune", "ring": 4, "side": 0.32, "kind": "minor", "max": 3, "icon": 13, "mods": {"magic_find": {"flat": 0.03}}},
	"lucky_star": {"name": "Lucky Star", "branch": "fortune", "ring": 5, "side": 0.0, "kind": "milestone", "max": 1, "milestone": 20, "icon": 40,
		"mods": {"critical_chance": {"flat": 0.08}, "critical_damage": {"flat": 0.25}}},
	"windfall": {"name": "Windfall", "branch": "fortune", "ring": 6, "side": 0.0, "kind": "major", "max": 1, "icon": 11, "mods": {"magic_find": {"flat": 0.1}, "gold_find": {"percent": 0.15}}},
	"treasure_hunter": {"name": "Treasure Hunter", "branch": "fortune", "ring": 7, "side": 0.0, "kind": "keystone", "max": 1, "milestone": 30, "icon": 10,
		"mods": {"magic_find": {"flat": 0.25}, "gold_find": {"percent": 0.25}, "physical_damage": {"percent": -0.08}}},
	# --- the crown: at the far end of the web
	"heartsong": {"name": "Heartsong", "branch": "", "ring": 0, "side": 0.0, "kind": "milestone", "max": 1, "milestone": 40, "icon": 35,
		"mods": {"physical_damage": {"percent": 0.12}, "max_health": {"percent": 0.12}, "attack_speed": {"percent": 0.06}, "magic_power": {"percent": 0.12}},
		"text": "Every branch hums together. Reached from any keystone."},
}

const BRANCH_ORDER: Array[String] = ["offense", "mobility", "defense", "survival", "fortune"]

static var _edges: Array = []
static var _positions: Dictionary = {}


## Where a node sits on the tree's canvas, the Heart at the origin.
static func position(id: String) -> Vector2:
	if _positions.is_empty():
		for node_id: String in NODES:
			var node: Dictionary = NODES[node_id]
			if node["branch"] == "":
				_positions[node_id] = Vector2.ZERO if node_id == "awakened_heart" else Vector2(0, 0)
			else:
				var angle: float = BRANCHES[node["branch"]][1] + node["side"]
				_positions[node_id] = Vector2.from_angle(angle) * STEP * node["ring"]
		# The crown floats beyond everything, above the tree.
		_positions["heartsong"] = Vector2(0, STEP * 8.6)
	return _positions[id]


## Pairs of node ids that are joined.
static func edges() -> Array:
	if not _edges.is_empty():
		return _edges
	for branch in BRANCH_ORDER:
		var chain := _chain(branch)
		_edges.append(["awakened_heart", chain[0]])
		for index in chain.size() - 1:
			_edges.append([chain[index], chain[index + 1]])
		# Side nodes hang off ring 4; keystones off ring 6.
		for id: String in NODES:
			var node: Dictionary = NODES[id]
			if node["branch"] == branch and node["side"] != 0.0:
				var ring: int = node["ring"]
				_edges.append([_at_ring(branch, ring if node["kind"] != "keystone" else ring - 1), id])
		for id: String in NODES:
			if NODES[id]["branch"] == branch and NODES[id]["kind"] == "keystone":
				_edges.append([id, "heartsong"])
	# Rings joining each branch to the next: at ring 2, and side to side at ring 4.
	for index in BRANCH_ORDER.size():
		var here := BRANCH_ORDER[index]
		var next := BRANCH_ORDER[(index + 1) % BRANCH_ORDER.size()]
		_edges.append([_at_ring(here, 2), _at_ring(next, 2)])
		_edges.append([_side(here), _at_ring(next, 4)])
	return _edges


static func neighbours(id: String) -> Array[String]:
	var result: Array[String] = []
	for edge: Array in edges():
		if edge[0] == id:
			result.append(edge[1])
		elif edge[1] == id:
			result.append(edge[0])
	return result


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


static func _chain(branch: String) -> Array[String]:
	var ids: Array[String] = []
	for ring in range(1, 8):
		var id := _at_ring(branch, ring)
		if id != "":
			ids.append(id)
	return ids


static func _at_ring(branch: String, ring: int) -> String:
	for id: String in NODES:
		var node: Dictionary = NODES[id]
		if node["branch"] == branch and node["ring"] == ring and node["side"] == 0.0:
			return id
	return ""


static func _side(branch: String) -> String:
	for id: String in NODES:
		var node: Dictionary = NODES[id]
		if node["branch"] == branch and node["kind"] == "minor" and node["side"] != 0.0:
			return id
	return ""
