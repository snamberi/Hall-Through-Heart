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
## Changing class costs this much gold per character level.
const RESET_COST_PER_LEVEL := 100

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
