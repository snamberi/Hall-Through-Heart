class_name HeroClasses
extends RefCounted
## The character classes. Ids are stable.
##
## Everyone starts as an Adventurer and picks a class at CHOICE_LEVEL.
##   "mods"      permanent stat modifiers
##   "weapons"   favoured weapon types, which get WEAPON_BONUS more damage
##   "abilities" class ability ids (see AbilityDB), on ability slots 3 and 4

const CHOICE_LEVEL := 10
const WEAPON_BONUS := 0.1
## Class points: one on choosing, then one every CLASS_POINT_LEVELS levels.
const CLASS_POINT_LEVELS := 2
## Each class's tree. Two columns: "abilities" (each needs the one before,
## and a character level) and "passives" (each needs the one before).
##   abilities: [ability id, level]
##   passives:  [id, name, max ranks, mods per rank, icon]
const TREES := {
	"warrior": {
		"abilities": [["battle_cry", 10], ["crushing_leap", 20], ["war_stomp", 30], ["blade_storm", 45]],
		"passives": [["warrior_might", "Might", 3, {"physical_damage": {"percent": 0.04}}, 0],
			["warrior_hide", "Hardened", 3, {"max_health": {"percent": 0.05}}, 7],
			["warrior_tempo", "Battle Tempo", 3, {"attack_speed": {"percent": 0.03}}, 3],
			["warrior_master", "Weapon Master", 1, {"physical_damage": {"percent": 0.12}, "critical_damage": {"flat": 0.2}}, 1]],
	},
	"guardian": {
		"abilities": [["shield_bash", 10], ["iron_skin", 20], ["guardian_charge", 30], ["bastion", 45]],
		"passives": [["guardian_plate", "Plate", 3, {"armor": {"percent": 0.08}}, 7],
			["guardian_vigor", "Vigor", 3, {"max_health": {"percent": 0.06}}, 35],
			["guardian_stand", "Stand Firm", 3, {"knockback_resistance": {"flat": 0.15}, "damage_taken": {"percent": -0.02}}, 5],
			["guardian_wall", "Living Wall", 1, {"damage_taken": {"percent": -0.1}, "armor": {"flat": 25.0}}, 5]],
	},
	"ranger": {
		"abilities": [["hunters_mark", 10], ["shadow_step", 20], ["multishot", 30], ["rain_of_arrows", 45]],
		"passives": [["ranger_eye", "Eagle Eye", 3, {"critical_chance": {"flat": 0.02}}, 40],
			["ranger_feet", "Light Feet", 3, {"move_speed": {"percent": 0.03}}, 9],
			["ranger_draw", "Quick Draw", 3, {"attack_speed": {"percent": 0.04}}, 32],
			["ranger_hunter", "Apex Hunter", 1, {"critical_damage": {"flat": 0.3}, "physical_damage": {"percent": 0.08}}, 32]],
	},
	"assassin": {
		"abilities": [["backstab", 10], ["execution", 20], ["smoke_bomb", 30], ["death_mark", 45]],
		"passives": [["assassin_edge", "Edge", 3, {"critical_damage": {"flat": 0.1}}, 3],
			["assassin_shadow", "Shadow", 3, {"dodge_efficiency": {"percent": 0.06}}, 29],
			["assassin_venom", "Venom", 3, {"critical_chance": {"flat": 0.02}}, 24],
			["assassin_reaper", "Reaper", 1, {"critical_chance": {"flat": 0.08}, "critical_damage": {"flat": 0.4}}, 15]],
	},
	"mage": {
		"abilities": [["fireball", 10], ["lightning_chain", 20], ["arcane_missiles", 30], ["blizzard", 45]],
		"passives": [["mage_power", "Arcane Power", 3, {"magic_power": {"percent": 0.06}}, 41],
			["mage_well", "Deep Well", 3, {"max_mana": {"percent": 0.1}}, 36],
			["mage_flow", "Flow", 3, {"mana_regen": {"percent": 0.15}}, 36],
			["mage_archmage", "Archmage", 1, {"magic_power": {"percent": 0.2}, "max_mana": {"flat": 50.0}}, 33]],
	},
	"spellblade": {
		"abilities": [["enchanted_strike", 10], ["elemental_burst", 20], ["arcane_dash", 30], ["storm_blade", 45]],
		"passives": [["spellblade_edge", "Runed Edge", 3, {"physical_damage": {"percent": 0.03}, "magic_power": {"percent": 0.03}}, 19],
			["spellblade_ward", "Ward", 3, {"max_mana": {"percent": 0.06}, "armor": {"flat": 4.0}}, 5],
			["spellblade_haste", "Quickened", 3, {"attack_speed": {"percent": 0.03}}, 3],
			["spellblade_avatar", "Avatar", 1, {"physical_damage": {"percent": 0.1}, "magic_power": {"percent": 0.15}}, 19]],
	},
}

const CLASSES := {
	"adventurer": {
		"name": "Adventurer", "icon": 9, "text": "No path chosen yet.",
		"mods": {}, "weapons": [], "abilities": [],
	},
	"warrior": {
		"name": "Warrior", "icon": 1, "text": "Close-range fighter with strong damage and staying power.",
		"mods": {"physical_damage": {"percent": 0.1}, "max_health": {"percent": 0.1}},
		"weapons": ["swords", "greatswords", "axes"], "abilities": ["battle_cry", "crushing_leap"],
	},
	"guardian": {
		"name": "Guardian", "icon": 5, "text": "Armoured defender who shrugs off blows and holds the line.",
		"mods": {"armor": {"flat": 10.0, "percent": 0.25}, "max_health": {"percent": 0.15}, "damage_taken": {"percent": -0.05}},
		"weapons": ["swords", "axes", "spears"], "abilities": ["shield_bash", "iron_skin"],
	},
	"ranger": {
		"name": "Ranger", "icon": 32, "text": "Mobile marksman who picks enemies off from range.",
		"mods": {"move_speed": {"flat": 15.0}, "critical_chance": {"flat": 0.05}, "attack_speed": {"percent": 0.05}},
		"weapons": ["bows", "spears"], "abilities": ["hunters_mark", "shadow_step"],
	},
	"assassin": {
		"name": "Assassin", "icon": 3, "text": "Fast killer built on critical hits.",
		"mods": {"critical_damage": {"flat": 0.3}, "critical_chance": {"flat": 0.05}, "dodge_efficiency": {"percent": 0.1}},
		"weapons": ["daggers"], "abilities": ["backstab", "execution"],
	},
	"mage": {
		"name": "Mage", "icon": 33, "text": "Spellcaster dealing elemental damage over wide areas.",
		"mods": {"magic_power": {"percent": 0.2}, "max_mana": {"flat": 30.0}, "mana_regen": {"flat": 2.0}},
		"weapons": ["staves"], "abilities": ["fireball", "lightning_chain"],
	},
	"spellblade": {
		"name": "Spellblade", "icon": 19, "text": "Swordsman who weaves magic into every strike.",
		"mods": {"physical_damage": {"percent": 0.06}, "magic_power": {"percent": 0.1}, "max_mana": {"flat": 15.0}},
		"weapons": ["swords", "staves"], "abilities": ["enchanted_strike", "elemental_burst"],
	},
}

## Classes offered at CHOICE_LEVEL, in display order.
const CHOICES: Array[String] = ["warrior", "guardian", "ranger", "assassin", "mage", "spellblade"]


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
	return lines
