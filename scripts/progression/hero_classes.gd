class_name HeroClasses
extends RefCounted
## The character classes. Ids are stable.
##
## A class is chosen when a character is made (older worlds, made before,
## may still pick one at CHOICE_LEVEL). Each class has its own tree:
##   class experience comes from using abilities and defeating enemies;
##   class levels open the class's six abilities one by one (they go on
##   the third ability set, "Class") and give a class point each, spent
##   on the tree's passives.
##   "mods"      permanent stat modifiers
##   "weapons"   favoured weapon types, which get WEAPON_BONUS more damage;
##               any other weapon is handled clumsily (see off_class_penalty)
##   "kit"       what a new character of the class starts with

const CHOICE_LEVEL := 10
const WEAPON_BONUS := 0.1
const MAX_CLASS_LEVEL := 25
## At this character level a second class can be taken up: half its
## strengths, its weapons as your own, and the first of its abilities.
const SECOND_CLASS_LEVEL := 75
const SECOND_SHARE := 0.5
const SECOND_ABILITIES := 3
## (Older saves: class points once came every CLASS_POINT_LEVELS levels.)
const CLASS_POINT_LEVELS := 2
## Class experience: per ability used (class abilities give more), and per
## enemy defeated by its rank (normal to boss).
const XP_ABILITY := 3
const XP_CLASS_ABILITY := 10
const XP_KILL: Array[int] = [3, 5, 7, 15, 40]
## A weapon the class does not train with: [damage kept, slower by] at each
## difficulty. Normal keeps 70% of the damage and strikes 10% slower.
const OFF_CLASS := {"peaceful": [0.9, 0.0], "easy": [0.85, 0.05], "normal": [0.7, 0.1], "hard": [0.6, 0.15], "insane": [0.5, 0.2]}
## Each class's tree. "abilities": [ability id, the class level it opens at].
## "passives": [id, name, max ranks, mods per rank, icon, (a note)], bought
## with class points (one per class level).
const TREES := {
	"warrior": {
		"abilities": [["battle_cry", 1], ["crushing_leap", 3], ["war_stomp", 6], ["rallying_roar", 10], ["blade_storm", 15], ["titan_cleave", 21]],
		"passives": [["warrior_might", "Might", 5, {"physical_damage": {"percent": 0.04}}, 0],
			["warrior_hide", "Hardened", 5, {"max_health": {"percent": 0.05}}, 7],
			["warrior_tempo", "Battle Tempo", 5, {"attack_speed": {"percent": 0.03}}, 3],
			["warrior_master", "Weapon Master", 1, {"physical_damage": {"percent": 0.12}, "critical_damage": {"flat": 0.2}}, 1]],
	},
	"guardian": {
		"abilities": [["shield_bash", 1], ["iron_skin", 3], ["guardian_charge", 6], ["shield_wall", 10], ["bastion", 15], ["earthshaker", 21]],
		"passives": [["guardian_plate", "Plate", 5, {"armor": {"percent": 0.08}}, 7],
			["guardian_vigor", "Vigor", 5, {"max_health": {"percent": 0.06}}, 35],
			["guardian_stand", "Stand Firm", 5, {"knockback_resistance": {"flat": 0.15}, "damage_taken": {"percent": -0.02}}, 5],
			["guardian_wall", "Living Wall", 1, {"damage_taken": {"percent": -0.1}, "armor": {"flat": 25.0}}, 5]],
	},
	"ranger": {
		"abilities": [["hunters_mark", 1], ["shadow_step", 3], ["multishot", 6], ["piercing_shot", 10], ["rain_of_arrows", 15], ["snare_trap", 21]],
		"passives": [["ranger_eye", "Eagle Eye", 5, {"critical_chance": {"flat": 0.02}}, 40],
			["ranger_feet", "Light Feet", 5, {"move_speed": {"percent": 0.03}}, 9],
			["ranger_draw", "Quick Draw", 5, {"attack_speed": {"percent": 0.04}}, 32],
			["ranger_hunter", "Apex Hunter", 1, {"critical_damage": {"flat": 0.3}, "physical_damage": {"percent": 0.08}}, 32]],
	},
	"assassin": {
		"abilities": [["backstab", 1], ["execution", 3], ["smoke_bomb", 6], ["knife_storm", 10], ["death_mark", 15], ["shadow_dance", 21]],
		"passives": [["assassin_edge", "Edge", 5, {"critical_damage": {"flat": 0.1}}, 3],
			["assassin_shadow", "Shadow", 5, {"dodge_efficiency": {"percent": 0.06}}, 29],
			["assassin_venom", "Venom", 5, {"critical_chance": {"flat": 0.02}}, 24],
			["assassin_reaper", "Reaper", 1, {"critical_chance": {"flat": 0.08}, "critical_damage": {"flat": 0.4}}, 15]],
	},
	"mage": {
		"abilities": [["fireball", 1], ["lightning_chain", 3], ["arcane_missiles", 6], ["glacial_nova", 10], ["blizzard", 15], ["meteor_swarm", 21]],
		"passives": [["mage_power", "Arcane Power", 5, {"magic_power": {"percent": 0.06}}, 41],
			["mage_well", "Deep Well", 5, {"max_mana": {"percent": 0.1}}, 36],
			["mage_flow", "Flow", 5, {"mana_regen": {"percent": 0.15}}, 36],
			["mage_archmage", "Archmage", 1, {"magic_power": {"percent": 0.2}, "max_mana": {"flat": 50.0}}, 33]],
	},
	"spellblade": {
		"abilities": [["enchanted_strike", 1], ["elemental_burst", 3], ["arcane_dash", 6], ["runic_ward", 10], ["storm_blade", 15], ["spellsunder", 21]],
		"passives": [["spellblade_edge", "Runed Edge", 5, {"physical_damage": {"percent": 0.03}, "magic_power": {"percent": 0.03}}, 19],
			["spellblade_ward", "Ward", 5, {"max_mana": {"percent": 0.06}, "armor": {"flat": 4.0}}, 5],
			["spellblade_haste", "Quickened", 5, {"attack_speed": {"percent": 0.03}}, 3],
			["spellblade_avatar", "Avatar", 1, {"physical_damage": {"percent": 0.1}, "magic_power": {"percent": 0.15}}, 19]],
	},
	"necromancer": {
		"abilities": [["raise_dead", 1], ["bone_spear", 3], ["corpse_bloom", 6], ["grave_chill", 10], ["bone_archers", 15], ["army_of_the_dead", 21]],
		"passives": [["necro_rot", "Rot", 5, {"shadow_damage": {"flat": 1.5}, "poison_damage": {"flat": 1.0}}, 20],
			["necro_bones", "Bone Armour", 5, {"armor": {"percent": 0.05}, "max_health": {"percent": 0.03}}, 13],
			["necro_horde", "The Horde", 3, {"magic_power": {"percent": 0.02}}, 12, "Each rank lets one more of your raised dead stand at once."],
			["necro_lich", "Lich", 1, {"magic_power": {"percent": 0.2}, "life_steal": {"flat": 0.04}}, 12]],
	},
	"spellcaster": {
		"abilities": [["arcane_bolt", 1], ["hex", 3], ["warding_sigil", 6], ["conjure_familiar", 10], ["mana_storm", 15], ["astral_prison", 21]],
		"passives": [["caster_focus", "Focus", 5, {"magic_power": {"percent": 0.04}}, 41],
			["caster_well", "Wellspring", 5, {"max_mana": {"percent": 0.08}, "mana_regen": {"percent": 0.08}}, 36],
			["caster_ward", "Warded", 5, {"damage_taken": {"percent": -0.02}, "elemental_resistance": {"flat": 0.02}}, 5],
			["caster_sage", "Sage", 1, {"magic_power": {"percent": 0.15}, "mana_regen": {"percent": 0.3}}, 33]],
	},
}

const CLASSES := {
	"adventurer": {
		"name": "Adventurer", "icon": 9, "text": "No path chosen yet. (Worlds made before classes were chosen at the start pick one at level 10.)",
		"mods": {}, "weapons": [], "kit": [],
	},
	"warrior": {
		"name": "Warrior", "icon": 1, "text": "Close-range fighter with strong damage and staying power.",
		"mods": {"physical_damage": {"percent": 0.1}, "max_health": {"percent": 0.1}},
		"weapons": ["swords", "greatswords", "axes"],
		"kit": [["sword", 1, true], ["chestplate", 1, true], ["health_potion", 3], ["bread", 4]],
	},
	"guardian": {
		"name": "Guardian", "icon": 5, "text": "Armoured defender who shrugs off blows and holds the line.",
		"mods": {"armor": {"flat": 10.0, "percent": 0.25}, "max_health": {"percent": 0.15}, "damage_taken": {"percent": -0.05}},
		"weapons": ["swords", "axes", "spears"],
		"kit": [["sword", 1, true], ["shield", 1, true], ["helmet", 1, true], ["bandage", 4], ["bread", 3]],
	},
	"ranger": {
		"name": "Ranger", "icon": 32, "text": "Mobile marksman who picks enemies off from range.",
		"mods": {"move_speed": {"flat": 15.0}, "critical_chance": {"flat": 0.05}, "attack_speed": {"percent": 0.05}},
		"weapons": ["bows", "spears"],
		"kit": [["bow", 1, true], ["leather_boots", 1, true], ["leather_cap", 1, true], ["health_potion", 2], ["wild_berries", 6]],
	},
	"assassin": {
		"name": "Assassin", "icon": 3, "text": "Fast killer built on critical hits.",
		"mods": {"critical_damage": {"flat": 0.3}, "critical_chance": {"flat": 0.05}, "dodge_efficiency": {"percent": 0.1}},
		"weapons": ["daggers"],
		"kit": [["dagger", 1, true], ["leather_vest", 1, true], ["leather_boots", 1, true], ["health_potion", 3]],
	},
	"mage": {
		"name": "Mage", "icon": 33, "text": "Spellcaster dealing elemental damage over wide areas.",
		"mods": {"magic_power": {"percent": 0.2}, "max_mana": {"flat": 30.0}, "mana_regen": {"flat": 2.0}},
		"weapons": ["staves"],
		"kit": [["staff", 1, true], ["mana_potion", 4], ["health_potion", 2], ["bread", 3]],
	},
	"spellblade": {
		"name": "Spellblade", "icon": 19, "text": "Swordsman who weaves magic into every strike.",
		"mods": {"physical_damage": {"percent": 0.06}, "magic_power": {"percent": 0.1}, "max_mana": {"flat": 15.0}},
		"weapons": ["swords", "staves"],
		"kit": [["sword", 1, true], ["leather_vest", 1, true], ["mana_potion", 2], ["health_potion", 2]],
	},
	"necromancer": {
		"name": "Necromancer", "icon": 12, "text": "Raises the dead to fight for them, and rots what they touch. Frail in body.",
		"mods": {"magic_power": {"percent": 0.12}, "shadow_damage": {"flat": 2.0}, "max_mana": {"flat": 25.0}, "max_health": {"percent": -0.05}},
		"weapons": ["staves", "daggers"],
		"kit": [["staff", 1, true], ["dagger", 1, false], ["mana_potion", 3], ["bone", 6], ["health_potion", 2]],
	},
	"spellcaster": {
		"name": "Spellcaster", "icon": 36, "text": "A scholar of sigils and hexes: wards that shield, curses that slow, and conjured familiars.",
		"mods": {"magic_power": {"percent": 0.1}, "max_mana": {"flat": 40.0}, "mana_regen": {"percent": 0.25}},
		"weapons": ["staves"],
		"kit": [["staff", 1, true], ["mana_potion", 5], ["essence", 2], ["bread", 3]],
	},
}

## Classes offered at CHOICE_LEVEL, in display order.
const CHOICES: Array[String] = ["warrior", "guardian", "ranger", "assassin", "mage", "spellblade", "necromancer", "spellcaster"]


## Class experience needed to go from a class level to the next.
## The abilities a second class lends: the first few of its tree.
static func second_abilities(id: String) -> Array[String]:
	var out: Array[String] = []
	for entry: Array in TREES.get(id, {}).get("abilities", []).slice(0, SECOND_ABILITIES):
		out.append(str(entry[0]))
	return out


## A class's strengths at the share a second class gives.
static func second_mods(id: String) -> Dictionary:
	var out := {}
	var mods: Dictionary = CLASSES.get(id, {}).get("mods", {})
	for stat: String in mods:
		out[stat] = {}
		for kind: String in mods[stat]:
			out[stat][kind] = float(mods[stat][kind]) * SECOND_SHARE
	return out


static func xp_to_next(level: int) -> int:
	return int(30.0 + 18.0 * pow(float(level), 1.25))


## The class level an ability of a class opens at, or 0 if not in its tree.
static func ability_level(class_id: String, ability_id: String) -> int:
	for entry: Array in TREES.get(class_id, {}).get("abilities", []):
		if entry[0] == ability_id:
			return int(entry[1])
	return 0


## [damage kept, slower by] for a weapon the class does not train with.
static func off_class_penalty(difficulty: String) -> Array:
	return OFF_CLASS.get(difficulty, OFF_CLASS["normal"])


## Lines describing a class's permanent bonuses.
static func describe_bonuses(id: String) -> PackedStringArray:
	var lines: PackedStringArray = []
	var data: Dictionary = CLASSES[id]
	for stat: String in data["mods"]:
		for kind: String in data["mods"][stat]:
			var amount: float = data["mods"][stat][kind]
			var text := ItemDB.describe_modifier({"stat": stat, "kind": kind, "value": absf(amount)})
			lines.append(text if amount >= 0.0 else "-" + text.substr(1))
	if not data["weapons"].is_empty():
		var names: PackedStringArray = []
		for type: String in data["weapons"]:
			names.append(WeaponMastery.NAMES[type].to_lower())
		lines.append("+%d%% damage with %s" % [roundi(WEAPON_BONUS * 100.0), ", ".join(names)])
		var penalty := off_class_penalty("normal")
		lines.append("Other weapons: %d%% damage, %d%% slower" % [roundi(float(penalty[0]) * 100.0), roundi(float(penalty[1]) * 100.0)])
	return lines
