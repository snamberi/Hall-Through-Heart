class_name AbilityDB
extends RefCounted
## Every weapon ability. Ids are stable; names and numbers are free to change.
##
## Each ability belongs to a weapon type and unlocks at a mastery level with
## that type. "shape" picks how it plays out (see AbilityUser):
##   arc     one heavy swing in a cone
##   spin    hits everything around the player
##   slam    delayed blast on the ground in front
##   dash    rush forward, hitting what is passed through
##   leap    dash, then a blast where the player lands
##   flurry  several quick swings
## "damage" multiplies the player's physical damage per hit.

## Mastery levels between ranks. Each rank adds RANK_DAMAGE to the multiplier.
const RANK_EVERY := 25
const RANK_DAMAGE := 0.1
const MAX_RANK := 10

const ABILITIES := {
	# --- swords
	"heavy_slash": {
		"name": "Heavy Slash", "weapon": "swords", "mastery": 10, "icon": 26, "shape": "arc",
		"damage": 2.2, "stamina": 20.0, "cooldown": 4.0, "reach": 1.3, "arc": 160.0, "knockback": 620.0,
		"text": "A wide, heavy swing that throws enemies back.",
	},
	"whirlwind": {
		"name": "Whirlwind", "weapon": "swords", "mastery": 50, "icon": 27, "shape": "spin",
		"damage": 1.3, "stamina": 30.0, "cooldown": 8.0, "radius": 96.0, "hits": 3, "knockback": 260.0,
		"text": "Spin three times, cutting everything around you.",
	},
	# --- greatswords
	"ground_breaker": {
		"name": "Ground Breaker", "weapon": "greatswords", "mastery": 10, "icon": 28, "shape": "slam",
		"damage": 2.8, "stamina": 30.0, "cooldown": 6.0, "radius": 100.0, "distance": 70.0, "knockback": 700.0,
		"text": "Smash the ground ahead, blasting everything nearby.",
	},
	"cleaving_storm": {
		"name": "Cleaving Storm", "weapon": "greatswords", "mastery": 50, "icon": 27, "shape": "spin",
		"damage": 2.0, "stamina": 40.0, "cooldown": 10.0, "radius": 120.0, "hits": 2, "knockback": 480.0,
		"text": "Two great sweeping circles that clear the space around you.",
	},
	# --- axes
	"rend": {
		"name": "Rend", "weapon": "axes", "mastery": 10, "icon": 26, "shape": "arc",
		"damage": 1.8, "stamina": 20.0, "cooldown": 5.0, "reach": 1.2, "arc": 140.0, "knockback": 400.0,
		"status": {"status": "bleed", "duration": 5.0, "power": 0.35},
		"text": "A tearing chop that leaves enemies bleeding.",
	},
	"leap_slam": {
		"name": "Leap Slam", "weapon": "axes", "mastery": 50, "icon": 28, "shape": "leap",
		"damage": 2.4, "stamina": 35.0, "cooldown": 9.0, "radius": 95.0, "distance": 190.0, "knockback": 600.0,
		"text": "Leap forward and crash down where you land.",
	},
	# --- daggers
	"shadow_dash": {
		"name": "Shadow Dash", "weapon": "daggers", "mastery": 10, "icon": 29, "shape": "dash",
		"damage": 1.8, "stamina": 20.0, "cooldown": 4.0, "distance": 230.0, "radius": 46.0, "knockback": 120.0,
		"text": "Dart through enemies, cutting each one you pass. You cannot be hurt mid-dash.",
	},
	"blade_flurry": {
		"name": "Blade Flurry", "weapon": "daggers", "mastery": 50, "icon": 31, "shape": "flurry",
		"damage": 0.7, "stamina": 30.0, "cooldown": 7.0, "hits": 6, "reach": 1.2, "arc": 100.0, "knockback": 60.0,
		"text": "Six stabs faster than the eye can follow.",
	},
	# --- spears
	"piercing_thrust": {
		"name": "Piercing Thrust", "weapon": "spears", "mastery": 10, "icon": 30, "shape": "arc",
		"damage": 2.4, "stamina": 20.0, "cooldown": 4.0, "reach": 1.7, "arc": 26.0, "knockback": 560.0,
		"text": "A long thrust that runs through every enemy in a line.",
	},
	"sweeping_arc": {
		"name": "Sweeping Arc", "weapon": "spears", "mastery": 50, "icon": 27, "shape": "spin",
		"damage": 1.7, "stamina": 30.0, "cooldown": 8.0, "radius": 130.0, "hits": 1, "knockback": 520.0,
		"text": "Swing the shaft in a full circle, knocking everything away.",
	},
	# --- unarmed
	"palm_strike": {
		"name": "Palm Strike", "weapon": "unarmed", "mastery": 10, "icon": 30, "shape": "arc",
		"damage": 2.0, "stamina": 15.0, "cooldown": 3.0, "reach": 1.3, "arc": 70.0, "knockback": 800.0,
		"text": "An open-handed blow that sends one enemy flying.",
	},
	"rapid_blows": {
		"name": "Rapid Blows", "weapon": "unarmed", "mastery": 50, "icon": 31, "shape": "flurry",
		"damage": 0.8, "stamina": 25.0, "cooldown": 6.0, "hits": 5, "reach": 1.2, "arc": 100.0, "knockback": 80.0,
		"text": "Five punches in the time of one.",
	},
}

## Number of ability slots on the bar.
const SLOTS := 4


## Ability ids for a weapon type, in unlock order.
static func for_weapon(weapon_type: String) -> Array[String]:
	var ids: Array[String] = []
	for id: String in ABILITIES:
		if ABILITIES[id]["weapon"] == weapon_type:
			ids.append(id)
	ids.sort_custom(func(a: String, b: String) -> bool: return ABILITIES[a]["mastery"] < ABILITIES[b]["mastery"])
	return ids


## Upgrade rank of an ability at a mastery level: 0 while locked, then 1 up.
static func rank(id: String, mastery_level: int) -> int:
	var unlock: int = ABILITIES[id]["mastery"]
	if mastery_level < unlock:
		return 0
	return mini(1 + (mastery_level - unlock) / RANK_EVERY, MAX_RANK)


## Damage multiplier of an ability at a rank.
static func damage(id: String, ability_rank: int) -> float:
	return ABILITIES[id]["damage"] * (1.0 + RANK_DAMAGE * maxi(ability_rank - 1, 0))
