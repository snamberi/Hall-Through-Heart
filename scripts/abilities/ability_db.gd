class_name AbilityDB
extends RefCounted
## Every weapon ability. Ids are stable; names and numbers are free to change.
##
## A weapon ability has "weapon" and "mastery": it sits on slots 1-2 while
## that weapon type is in hand and unlocks at that mastery level.
## A class ability has "class" and "level": it sits on slots 3-4 for that
## class and unlocks at that character level.
## Costs are "stamina" and/or "mana". "magic": true scales with magic damage.
## "shape" picks how it plays out (see AbilityUser):
##   shot    fires "count" projectiles spread over "spread" degrees
##   buff    a timed bonus: "duration" seconds of "mods"
##   chain   lightning that jumps between up to "targets" enemies
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
	# --- bows
	"piercing_arrow": {
		"name": "Piercing Arrow", "weapon": "bows", "mastery": 10, "icon": 30, "shape": "shot",
		"damage": 2.2, "stamina": 20.0, "cooldown": 5.0, "count": 1, "spread": 0.0,
		"projectile": {"sprite": 0, "speed": 950.0, "radius": 13.0, "range": 680.0, "pierce": true, "knockback": 300.0},
		"text": "A heavy arrow that passes through every enemy in its path.",
	},
	"rapid_volley": {
		"name": "Rapid Volley", "weapon": "bows", "mastery": 50, "icon": 31, "shape": "shot",
		"damage": 0.9, "stamina": 30.0, "cooldown": 8.0, "count": 5, "spread": 40.0,
		"projectile": {"sprite": 0, "speed": 780.0, "radius": 10.0, "range": 520.0, "knockback": 160.0},
		"text": "Loose five arrows in a fan.",
	},
	# --- staves
	"arcane_barrage": {
		"name": "Arcane Barrage", "weapon": "staves", "mastery": 10, "icon": 30, "shape": "shot", "magic": true,
		"damage": 1.3, "mana": 15.0, "cooldown": 5.0, "count": 3, "spread": 24.0,
		"projectile": {"sprite": 1, "speed": 620.0, "radius": 12.0, "range": 520.0, "knockback": 200.0, "color": Color(0.75, 0.55, 1.0)},
		"text": "Three bolts of raw magic.",
	},
	"frost_nova": {
		"name": "Frost Nova", "weapon": "staves", "mastery": 50, "icon": 27, "shape": "spin", "magic": true,
		"damage": 1.8, "mana": 25.0, "cooldown": 10.0, "radius": 150.0, "hits": 1, "knockback": 300.0,
		"status": {"status": "chill", "duration": 4.0, "power": 0.5}, "color": Color(0.6, 0.9, 1.0),
		"text": "A burst of cold that damages and slows everything around you.",
	},
	# --- third abilities, at mastery 200
	"blade_dance": {
		"name": "Blade Dance", "weapon": "swords", "mastery": 200, "icon": 31, "shape": "flurry",
		"damage": 1.0, "stamina": 35.0, "cooldown": 12.0, "hits": 5, "reach": 1.3, "arc": 140.0, "knockback": 120.0,
		"text": "Five sweeping cuts in a blur.",
	},
	"earthshatter": {
		"name": "Earthshatter", "weapon": "greatswords", "mastery": 200, "icon": 28, "shape": "slam",
		"damage": 3.8, "stamina": 45.0, "cooldown": 14.0, "radius": 150.0, "distance": 90.0, "knockback": 820.0,
		"text": "A blow that cracks the ground across a huge area.",
	},
	"bloodbath": {
		"name": "Bloodbath", "weapon": "axes", "mastery": 200, "icon": 27, "shape": "spin",
		"damage": 1.6, "stamina": 40.0, "cooldown": 12.0, "radius": 110.0, "hits": 2, "knockback": 300.0,
		"status": {"status": "bleed", "duration": 5.0, "power": 0.3},
		"text": "Two wild circles that leave everything nearby bleeding.",
	},
	"fan_of_knives": {
		"name": "Fan of Knives", "weapon": "daggers", "mastery": 200, "icon": 31, "shape": "shot",
		"damage": 1.1, "stamina": 30.0, "cooldown": 9.0, "count": 7, "spread": 110.0,
		"projectile": {"sprite": 0, "speed": 820.0, "radius": 10.0, "range": 360.0, "knockback": 140.0},
		"text": "Throw seven blades in a wide fan.",
	},
	"impale": {
		"name": "Impale", "weapon": "spears", "mastery": 200, "icon": 29, "shape": "dash",
		"damage": 2.8, "stamina": 35.0, "cooldown": 10.0, "distance": 280.0, "radius": 50.0, "knockback": 500.0,
		"text": "Charge spear-first through everything in your way.",
	},
	"explosive_arrow": {
		"name": "Explosive Arrow", "weapon": "bows", "mastery": 200, "icon": 28, "shape": "shot",
		"damage": 2.6, "stamina": 35.0, "cooldown": 10.0, "count": 1, "spread": 0.0,
		"projectile": {"sprite": 0, "speed": 820.0, "radius": 12.0, "range": 600.0, "explode": 110.0, "knockback": 420.0,
			"status": {"status": "burn", "duration": 3.0, "power": 0.2}, "color": Color(1.0, 0.6, 0.2)},
		"text": "An arrow that bursts into flame where it lands.",
	},
	"meteor": {
		"name": "Meteor", "weapon": "staves", "mastery": 200, "icon": 28, "shape": "slam", "magic": true,
		"damage": 3.6, "mana": 40.0, "cooldown": 14.0, "radius": 140.0, "distance": 190.0, "knockback": 700.0,
		"status": {"status": "burn", "duration": 4.0, "power": 0.25}, "color": Color(1.0, 0.55, 0.2),
		"text": "Call down fire on a spot ahead of you.",
	},
	"dragon_kick": {
		"name": "Dragon Kick", "weapon": "unarmed", "mastery": 200, "icon": 29, "shape": "leap",
		"damage": 3.0, "stamina": 35.0, "cooldown": 10.0, "radius": 90.0, "distance": 220.0, "knockback": 760.0,
		"text": "A flying kick that bowls enemies over.",
	},
	# --- class abilities
	"battle_cry": {
		"name": "Battle Cry", "class": "warrior", "level": 10, "icon": 28, "shape": "buff",
		"stamina": 20.0, "cooldown": 20.0, "duration": 8.0, "mods": {"physical_damage": {"percent": 0.25}},
		"color": Color(1.0, 0.5, 0.3), "text": "Roar, dealing 25% more damage for 8 seconds.",
	},
	"crushing_leap": {
		"name": "Crushing Leap", "class": "warrior", "level": 25, "icon": 28, "shape": "leap",
		"damage": 2.6, "stamina": 30.0, "cooldown": 10.0, "radius": 100.0, "distance": 200.0, "knockback": 620.0,
		"text": "Leap at your enemies and land with a crushing blow.",
	},
	"shield_bash": {
		"name": "Shield Bash", "class": "guardian", "level": 10, "icon": 26, "shape": "arc",
		"damage": 1.6, "stamina": 20.0, "cooldown": 6.0, "reach": 1.0, "arc": 90.0, "knockback": 820.0,
		"status": {"status": "chill", "duration": 1.5, "power": 0.8},
		"text": "Slam enemies away and leave them reeling.",
	},
	"iron_skin": {
		"name": "Iron Skin", "class": "guardian", "level": 25, "icon": 5, "shape": "buff",
		"stamina": 20.0, "cooldown": 20.0, "duration": 6.0, "mods": {"damage_taken": {"percent": -0.4}},
		"color": Color(0.7, 0.8, 0.9), "text": "Take 40% less damage for 6 seconds.",
	},
	"hunters_mark": {
		"name": "Hunter's Mark", "class": "ranger", "level": 10, "icon": 40, "shape": "buff",
		"stamina": 15.0, "cooldown": 20.0, "duration": 10.0, "mods": {"critical_chance": {"flat": 0.2}},
		"color": Color(0.6, 1.0, 0.5), "text": "+20% critical-hit chance for 10 seconds.",
	},
	"shadow_step": {
		"name": "Shadow Step", "class": "ranger", "level": 25, "icon": 29, "shape": "dash",
		"damage": 0.6, "stamina": 20.0, "cooldown": 6.0, "distance": 300.0, "radius": 40.0, "knockback": 100.0,
		"text": "Slip a long way in an instant. You cannot be hurt mid-step.",
	},
	"backstab": {
		"name": "Backstab", "class": "assassin", "level": 10, "icon": 3, "shape": "arc",
		"damage": 3.0, "stamina": 20.0, "cooldown": 6.0, "reach": 1.1, "arc": 60.0, "knockback": 200.0,
		"text": "One precise, brutal stab.",
	},
	"execution": {
		"name": "Execution", "class": "assassin", "level": 25, "icon": 15, "shape": "arc",
		"damage": 4.5, "stamina": 35.0, "cooldown": 14.0, "reach": 1.1, "arc": 60.0, "knockback": 300.0,
		"text": "A killing blow with a long recovery.",
	},
	"fireball": {
		"name": "Fireball", "class": "mage", "level": 10, "icon": 18, "shape": "shot", "magic": true,
		"damage": 2.4, "mana": 20.0, "cooldown": 5.0, "count": 1, "spread": 0.0,
		"projectile": {"sprite": 2, "speed": 520.0, "radius": 14.0, "range": 520.0, "explode": 90.0, "knockback": 360.0,
			"status": {"status": "burn", "duration": 3.0, "power": 0.25}, "color": Color(1.0, 0.6, 0.2)},
		"text": "A ball of fire that explodes and sets enemies alight.",
	},
	"lightning_chain": {
		"name": "Lightning Chain", "class": "mage", "level": 25, "icon": 37, "shape": "chain", "magic": true,
		"damage": 1.6, "mana": 25.0, "cooldown": 8.0, "targets": 5, "reach": 340.0, "jump": 180.0,
		"color": Color(0.7, 0.85, 1.0), "text": "Lightning that leaps between up to five enemies.",
	},
	"enchanted_strike": {
		"name": "Enchanted Strike", "class": "spellblade", "level": 10, "icon": 19, "shape": "arc", "magic": true,
		"damage": 2.0, "stamina": 10.0, "mana": 10.0, "cooldown": 5.0, "reach": 1.3, "arc": 140.0, "knockback": 420.0,
		"status": {"status": "burn", "duration": 3.0, "power": 0.25}, "color": Color(1.0, 0.6, 0.2),
		"text": "A flaming swing that leaves enemies burning.",
	},
	"elemental_burst": {
		"name": "Elemental Burst", "class": "spellblade", "level": 25, "icon": 27, "shape": "spin", "magic": true,
		"damage": 2.0, "mana": 25.0, "cooldown": 10.0, "radius": 130.0, "hits": 1, "knockback": 400.0,
		"status": {"status": "chill", "duration": 3.0, "power": 0.4}, "color": Color(0.6, 0.9, 1.0),
		"text": "Release stored magic in a freezing ring.",
	},
}

## Number of ability slots on the bar.
const SLOTS := 5
## How many of the slots hold weapon abilities; the rest hold class abilities.
const WEAPON_SLOTS := 3


## Ability ids for a weapon type, in unlock order.
static func for_weapon(weapon_type: String) -> Array[String]:
	var ids: Array[String] = []
	for id: String in ABILITIES:
		if ABILITIES[id].get("weapon", "") == weapon_type:
			ids.append(id)
	ids.sort_custom(func(a: String, b: String) -> bool: return ABILITIES[a]["mastery"] < ABILITIES[b]["mastery"])
	return ids


## Level an ability unlocks at: a mastery level for weapon abilities, a
## character level for class abilities.
static func unlock_level(id: String) -> int:
	return ABILITIES[id].get("mastery", ABILITIES[id].get("level", 1))


## Upgrade rank at a mastery (or character) level: 0 while locked, then 1 up.
static func rank(id: String, level: int) -> int:
	var unlock := unlock_level(id)
	if level < unlock:
		return 0
	return mini(1 + (level - unlock) / RANK_EVERY, MAX_RANK)


## Damage multiplier of an ability at a rank.
static func damage(id: String, ability_rank: int) -> float:
	return ABILITIES[id].get("damage", 0.0) * (1.0 + RANK_DAMAGE * maxi(ability_rank - 1, 0))
