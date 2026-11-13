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

const BASE_ABILITIES := {
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
	# --- class abilities learned deeper in each class tree
	"war_stomp": {
		"name": "War Stomp", "class": "warrior", "level": 30, "icon": 28, "shape": "slam",
		"damage": 2.6, "stamina": 30.0, "cooldown": 9.0, "radius": 130.0, "distance": 0.0, "knockback": 700.0,
		"status": {"status": "chill", "duration": 2.0, "power": 0.6}, "text": "Stamp the ground, battering and staggering everything nearby.",
	},
	"blade_storm": {
		"name": "Blade Storm", "class": "warrior", "level": 45, "icon": 27, "shape": "spin",
		"damage": 1.5, "stamina": 45.0, "cooldown": 14.0, "radius": 120.0, "hits": 4, "knockback": 260.0,
		"text": "Become a whirl of steel for a moment.",
	},
	"guardian_charge": {
		"name": "Guardian Charge", "class": "guardian", "level": 30, "icon": 29, "shape": "dash",
		"damage": 2.0, "stamina": 25.0, "cooldown": 8.0, "distance": 260.0, "radius": 50.0, "knockback": 700.0,
		"text": "Charge forward, flattening anything in the way.",
	},
	"bastion": {
		"name": "Bastion", "class": "guardian", "level": 45, "icon": 5, "shape": "buff",
		"stamina": 30.0, "cooldown": 30.0, "duration": 5.0, "mods": {"damage_taken": {"percent": -0.7}, "knockback_resistance": {"flat": 1.0}},
		"color": Color(0.9, 0.85, 0.5), "text": "Take 70% less damage for 5 seconds and cannot be moved.",
	},
	"multishot": {
		"name": "Multishot", "class": "ranger", "level": 30, "icon": 31, "shape": "shot",
		"damage": 1.3, "stamina": 25.0, "cooldown": 6.0, "count": 3, "spread": 18.0,
		"projectile": {"sprite": 0, "speed": 880.0, "radius": 11.0, "range": 600.0, "pierce": true, "knockback": 200.0},
		"text": "Three piercing arrows at once.",
	},
	"rain_of_arrows": {
		"name": "Rain of Arrows", "class": "ranger", "level": 45, "icon": 31, "shape": "slam",
		"damage": 3.0, "stamina": 40.0, "cooldown": 14.0, "radius": 150.0, "distance": 220.0, "knockback": 200.0,
		"text": "Darken the sky over a spot ahead of you.",
	},
	"smoke_bomb": {
		"name": "Smoke Bomb", "class": "assassin", "level": 30, "icon": 29, "shape": "buff",
		"stamina": 20.0, "cooldown": 18.0, "duration": 6.0, "mods": {"dodge_efficiency": {"percent": 0.6}, "move_speed": {"percent": 0.25}, "critical_chance": {"flat": 0.15}},
		"color": Color(0.6, 0.6, 0.65), "text": "Vanish in smoke: faster, slipperier, and deadlier for 6 seconds.",
	},
	"death_mark": {
		"name": "Death Mark", "class": "assassin", "level": 45, "icon": 15, "shape": "buff",
		"stamina": 30.0, "cooldown": 30.0, "duration": 8.0, "mods": {"critical_damage": {"flat": 1.0}},
		"color": Color(0.8, 0.2, 0.25), "text": "Critical hits deal double extra damage for 8 seconds.",
	},
	"arcane_missiles": {
		"name": "Arcane Missiles", "class": "mage", "level": 30, "icon": 30, "shape": "shot", "magic": true,
		"damage": 1.0, "mana": 25.0, "cooldown": 6.0, "count": 5, "spread": 30.0,
		"projectile": {"sprite": 1, "speed": 640.0, "radius": 12.0, "range": 560.0, "knockback": 120.0, "color": Color(0.75, 0.55, 1.0)},
		"text": "A spray of five seeking bolts.",
	},
	"blizzard": {
		"name": "Blizzard", "class": "mage", "level": 45, "icon": 27, "shape": "slam", "magic": true,
		"damage": 3.4, "mana": 45.0, "cooldown": 16.0, "radius": 170.0, "distance": 200.0, "knockback": 300.0,
		"status": {"status": "chill", "duration": 4.0, "power": 0.6}, "color": Color(0.7, 0.9, 1.0),
		"text": "A howling storm of ice over a wide area.",
	},
	"arcane_dash": {
		"name": "Arcane Dash", "class": "spellblade", "level": 30, "icon": 29, "shape": "dash", "magic": true,
		"damage": 1.6, "mana": 15.0, "cooldown": 6.0, "distance": 240.0, "radius": 46.0, "knockback": 200.0, "color": Color(0.75, 0.55, 1.0),
		"text": "Blink forward through a line of foes.",
	},
	"storm_blade": {
		"name": "Storm Blade", "class": "spellblade", "level": 45, "icon": 37, "shape": "chain", "magic": true,
		"damage": 2.2, "stamina": 15.0, "mana": 25.0, "cooldown": 10.0, "targets": 6, "reach": 300.0, "jump": 200.0,
		"color": Color(0.7, 0.85, 1.0), "text": "Lightning leaps from your blade through six enemies.",
	},
	# --- spells of the schools of magic (see MagicDB). "school" marks them;
	# "level" is the character level each unlocks at. "heal" restores that
	# share of health when cast.
	"spell_fire_bolt": {
		"name": "Fire Bolt", "school": "fire", "level": 1, "icon": 34, "shape": "shot", "magic": true,
		"damage": 1.6, "mana": 10.0, "cooldown": 1.5, "count": 1, "spread": 0.0, "color": Color(1.0, 0.6, 0.2),
		"projectile": {"sprite": 2, "speed": 600.0, "radius": 12.0, "range": 520.0, "explode": 60.0, "knockback": 260.0,
			"status": {"status": "burn", "duration": 3.0, "power": 0.25}, "color": Color(1.0, 0.6, 0.2)},
		"text": "A bolt of fire that bursts and sets enemies alight.",
	},
	"spell_flame_ring": {
		"name": "Ring of Fire", "school": "fire", "level": 8, "icon": 27, "shape": "spin", "magic": true,
		"damage": 1.8, "mana": 20.0, "cooldown": 7.0, "radius": 130.0, "hits": 1, "knockback": 380.0,
		"status": {"status": "burn", "duration": 4.0, "power": 0.3}, "color": Color(1.0, 0.5, 0.15),
		"text": "Flame bursts out all around you and leaves everything near burning.",
	},
	"spell_meteor": {
		"name": "Falling Star", "school": "fire", "level": 16, "icon": 28, "shape": "slam", "magic": true,
		"damage": 3.2, "mana": 35.0, "cooldown": 12.0, "radius": 110.0, "distance": 160.0, "knockback": 650.0,
		"status": {"status": "burn", "duration": 5.0, "power": 0.35}, "color": Color(1.0, 0.45, 0.15),
		"text": "Call down a burning star on the ground ahead.",
	},
	"spell_inferno_cloak": {
		"name": "Inferno Cloak", "school": "fire", "level": 24, "icon": 38, "shape": "buff", "magic": true,
		"mana": 25.0, "cooldown": 30.0, "duration": 20.0, "color": Color(1.0, 0.55, 0.2),
		"mods": {"fire_damage": {"flat": 10.0}, "fire_resist": {"flat": 0.2}, "magic_power": {"percent": 0.1}},
		"text": "Wrap yourself in fire: +10 fire damage, +20% fire resistance and +10% magic damage for 20 seconds.",
	},
	"spell_spark": {
		"name": "Spark", "school": "lightning", "level": 1, "icon": 30, "shape": "shot", "magic": true,
		"damage": 0.75, "mana": 8.0, "cooldown": 1.2, "count": 3, "spread": 18.0, "color": Color(0.6, 0.85, 1.0),
		"projectile": {"sprite": 1, "speed": 950.0, "radius": 10.0, "range": 460.0, "knockback": 120.0, "color": Color(0.6, 0.85, 1.0)},
		"text": "Three crackling sparks, quick and cheap.",
	},
	"spell_chain_lightning": {
		"name": "Forked Lightning", "school": "lightning", "level": 8, "icon": 37, "shape": "chain", "magic": true,
		"damage": 1.5, "mana": 22.0, "cooldown": 6.0, "targets": 6, "reach": 360.0, "jump": 190.0, "color": Color(0.7, 0.85, 1.0),
		"text": "Lightning that leaps between up to six enemies.",
	},
	"spell_thunderclap": {
		"name": "Thunderclap", "school": "lightning", "level": 16, "icon": 28, "shape": "slam", "magic": true,
		"damage": 2.2, "mana": 28.0, "cooldown": 10.0, "radius": 145.0, "distance": 0.0, "knockback": 720.0,
		"status": {"status": "chill", "duration": 2.5, "power": 0.7}, "color": Color(0.7, 0.9, 1.0),
		"text": "A crack of thunder around you that hurls enemies back and leaves them dazed.",
	},
	"spell_storm_rush": {
		"name": "Storm Rush", "school": "lightning", "level": 24, "icon": 9, "shape": "dash", "magic": true,
		"damage": 1.6, "mana": 20.0, "cooldown": 7.0, "distance": 230.0, "radius": 44.0, "knockback": 300.0, "color": Color(0.6, 0.85, 1.0),
		"text": "Become lightning for a moment and rush ahead through your enemies.",
	},
	"spell_shadow_bolt": {
		"name": "Shadow Bolt", "school": "dark", "level": 1, "icon": 20, "shape": "shot", "magic": true,
		"damage": 1.7, "mana": 12.0, "cooldown": 2.0, "count": 1, "spread": 0.0, "color": Color(0.62, 0.4, 0.95),
		"projectile": {"sprite": 1, "speed": 560.0, "radius": 13.0, "range": 520.0, "knockback": 180.0,
			"status": {"status": "poison", "duration": 4.0, "power": 0.3}, "color": Color(0.62, 0.4, 0.95)},
		"text": "A bolt of shadow that rots what it touches.",
	},
	"spell_umbral_burst": {
		"name": "Umbral Burst", "school": "dark", "level": 8, "icon": 27, "shape": "spin", "magic": true,
		"damage": 1.6, "mana": 20.0, "cooldown": 8.0, "radius": 125.0, "hits": 2, "knockback": 260.0,
		"status": {"status": "poison", "duration": 4.0, "power": 0.3}, "color": Color(0.55, 0.3, 0.9),
		"text": "Darkness bursts from you twice, rotting everything near.",
	},
	"spell_void_rift": {
		"name": "Void Rift", "school": "dark", "level": 16, "icon": 28, "shape": "slam", "magic": true,
		"damage": 2.8, "mana": 30.0, "cooldown": 12.0, "radius": 120.0, "distance": 150.0, "knockback": -260.0,
		"status": {"status": "chill", "duration": 3.0, "power": 0.6}, "color": Color(0.6, 0.35, 1.0),
		"text": "Tear open the void ahead: it drags enemies in and holds them slow.",
	},
	"spell_dark_pact": {
		"name": "Dark Pact", "school": "dark", "level": 24, "icon": 12, "shape": "buff", "magic": true,
		"mana": 10.0, "cooldown": 30.0, "duration": 15.0, "color": Color(0.6, 0.3, 0.95),
		"mods": {"magic_power": {"percent": 0.35}, "life_steal": {"flat": 0.06}, "damage_taken": {"percent": 0.15}},
		"text": "+35% magic damage and 6% life steal for 15 seconds, but you take 15% more damage.",
	},
	"spell_holy_lance": {
		"name": "Holy Lance", "school": "light", "level": 1, "icon": 63, "shape": "shot", "magic": true,
		"damage": 1.6, "mana": 12.0, "cooldown": 2.0, "count": 1, "spread": 0.0, "color": Color(1.0, 0.92, 0.6),
		"projectile": {"sprite": 1, "speed": 1000.0, "radius": 10.0, "range": 600.0, "knockback": 160.0, "pierce": true, "color": Color(1.0, 0.92, 0.6)},
		"text": "A lance of light that passes through every enemy in a line.",
	},
	"spell_radiant_burst": {
		"name": "Radiant Burst", "school": "light", "level": 8, "icon": 27, "shape": "spin", "magic": true,
		"damage": 1.4, "mana": 24.0, "cooldown": 9.0, "radius": 135.0, "hits": 1, "knockback": 340.0, "heal": 0.12, "color": Color(1.0, 0.9, 0.55),
		"text": "Light bursts from you, burning enemies and healing you for 12% of your health.",
	},
	"spell_smite": {
		"name": "Smite", "school": "light", "level": 16, "icon": 28, "shape": "slam", "magic": true,
		"damage": 3.0, "mana": 30.0, "cooldown": 10.0, "radius": 100.0, "distance": 130.0, "knockback": 560.0, "color": Color(1.0, 0.95, 0.7),
		"text": "Judgement falls from the sky on the ground ahead.",
	},
	"spell_blessing": {
		"name": "Blessing", "school": "light", "level": 24, "icon": 35, "shape": "buff", "magic": true,
		"mana": 30.0, "cooldown": 35.0, "duration": 20.0, "heal": 0.25, "color": Color(1.0, 0.92, 0.6),
		"mods": {"health_regen": {"flat": 4.0}, "armor": {"percent": 0.2}, "damage_taken": {"percent": -0.1}},
		"text": "Heal 25% at once, then +4 health a second, +20% armor and 10% less damage taken for 20 seconds.",
	},
	"spell_ice_shard": {
		"name": "Ice Shards", "school": "frost", "level": 1, "icon": 19, "shape": "shot", "magic": true,
		"damage": 0.9, "mana": 10.0, "cooldown": 2.0, "count": 3, "spread": 28.0, "color": Color(0.7, 0.92, 1.0),
		"projectile": {"sprite": 1, "speed": 700.0, "radius": 10.0, "range": 480.0, "knockback": 140.0,
			"status": {"status": "chill", "duration": 2.5, "power": 0.35}, "color": Color(0.7, 0.92, 1.0)},
		"text": "Three shards of ice that slow what they hit.",
	},
	"spell_frost_ring": {
		"name": "Frost Ring", "school": "frost", "level": 8, "icon": 27, "shape": "spin", "magic": true,
		"damage": 1.5, "mana": 20.0, "cooldown": 8.0, "radius": 140.0, "hits": 1, "knockback": 300.0,
		"status": {"status": "chill", "duration": 4.0, "power": 0.5}, "color": Color(0.6, 0.9, 1.0),
		"text": "A burst of cold around you that slows everything it touches.",
	},
	"spell_glacial_spike": {
		"name": "Glacial Spike", "school": "frost", "level": 16, "icon": 28, "shape": "slam", "magic": true,
		"damage": 3.0, "mana": 30.0, "cooldown": 11.0, "radius": 95.0, "distance": 140.0, "knockback": 520.0,
		"status": {"status": "chill", "duration": 4.0, "power": 0.65}, "color": Color(0.65, 0.9, 1.0),
		"text": "A spike of ice bursts up from the ground ahead.",
	},
	"spell_ice_armor": {
		"name": "Ice Armour", "school": "frost", "level": 24, "icon": 59, "shape": "buff", "magic": true,
		"mana": 25.0, "cooldown": 30.0, "duration": 20.0, "color": Color(0.7, 0.92, 1.0),
		"mods": {"armor": {"percent": 0.35}, "frost_resist": {"flat": 0.25}, "knockback_resistance": {"flat": 0.3}},
		"text": "+35% armor, +25% frost resistance and steady footing for 20 seconds.",
	},
}

## Number of ability slots on the bar.
## Abilities on the bar: two sets of SET_SIZE, switched with a key.
## Every ability's own icon, in the order of ABILITIES (drawn by
## tools/generate_ability_icons.py).
const ICON_SHEET: Texture2D = preload("res://assets/icons/abilities.png")
const ICON_SIZE := 24
const ICON_COLUMNS := 8
static var _icons: Dictionary = {}


static func icon(id: String) -> Texture2D:
	# Generated moves borrow the picture of the ability they grew from.
	if ABILITIES.has(id) and ABILITIES[id].has("icon_from"):
		return icon(ABILITIES[id]["icon_from"])
	if not _icons.has(id):
		var index := BASE_ABILITIES.keys().find(id)
		if index < 0:
			return ItemDB.icon(0)
		var atlas := AtlasTexture.new()
		atlas.atlas = ICON_SHEET
		atlas.region = Rect2(index % ICON_COLUMNS * ICON_SIZE, index / ICON_COLUMNS * ICON_SIZE, ICON_SIZE, ICON_SIZE)
		_icons[id] = atlas
	return _icons[id]


## Two sets on the bar, switched with Tab: 0 is the moves of whatever is
## in hand (the weapon's own, the combat style's, or the magic school's
## spells), 1 is the universal abilities chosen in the Abilities screen.
const SET_SIZE := 4
const SETS := 2
const SLOTS := SET_SIZE

## Abilities anyone can use with or without a weapon, unlocked by level
## ("u_<id>"). Class abilities join them for their class.
const UNIVERSAL := {
	"flash_step": {"name": "Flash Step", "shape": "dash", "icon_from": "arcane_dash", "level": 1, "damage": 0.6, "stamina": 15.0, "cooldown": 6.0,
		"distance": 200.0, "radius": 30.0, "knockback": 100.0, "color": Color(0.85, 0.95, 1.0), "text": "A blink-quick step you cannot be hit during."},
	"second_wind": {"name": "Second Wind", "shape": "buff", "icon_from": "iron_skin", "level": 3, "heal": 0.25, "stamina": 0.0, "cooldown": 60.0,
		"duration": 6.0, "mods": {"health_regen": {"flat": 3.0}}, "color": Color(0.6, 1.0, 0.6), "text": "Catch your breath: heal a quarter of your health and more over 6 seconds."},
	"aegis": {"name": "Aegis", "shape": "buff", "icon_from": "bastion", "level": 6, "stamina": 20.0, "cooldown": 30.0, "duration": 4.0,
		"mods": {"damage_taken": {"percent": -0.6}}, "color": Color(0.8, 0.9, 1.0), "text": "A shield of force: for 4 seconds take 60% less damage."},
	"blink": {"name": "Blink", "shape": "blink", "icon_from": "shadow_step", "level": 10, "damage": 0.0, "mana": 15.0, "cooldown": 12.0,
		"distance": 260.0, "radius": 0.0, "knockback": 0.0, "color": Color(0.75, 0.6, 1.0), "text": "Vanish and reappear where you point."},
	"haste": {"name": "Haste", "shape": "buff", "icon_from": "hunters_mark", "level": 15, "stamina": 15.0, "cooldown": 40.0, "duration": 8.0,
		"mods": {"move_speed": {"percent": 0.3}, "attack_speed": {"percent": 0.15}}, "color": Color(0.9, 1.0, 0.6), "text": "For 8 seconds move 30% and strike 15% faster."},
	"shockwave": {"name": "Shockwave", "shape": "spin", "icon_from": "war_stomp", "level": 20, "damage": 1.2, "stamina": 25.0, "cooldown": 14.0,
		"radius": 140.0, "hits": 1, "knockback": 800.0, "color": Color(0.9, 0.85, 0.7), "text": "A burst of force that throws everyone near you back."},
	"smoke_veil": {"name": "Smoke Veil", "shape": "veil", "icon_from": "smoke_bomb", "level": 28, "damage": 0.0, "stamina": 20.0, "cooldown": 45.0,
		"radius": 0.0, "duration": 5.0, "knockback": 0.0, "mods": {"move_speed": {"percent": 0.25}}, "color": Color(0.6, 0.6, 0.7),
		"text": "Vanish in smoke: foes lose you, and you move faster for 5 seconds."},
	"war_cry": {"name": "War Cry", "shape": "buff", "icon_from": "battle_cry", "level": 35, "stamina": 20.0, "cooldown": 50.0, "duration": 10.0,
		"mods": {"physical_damage": {"percent": 0.2}, "critical_chance": {"flat": 0.05}}, "color": Color(1.0, 0.55, 0.35), "text": "For 10 seconds hit 20% harder and crit more."},
}

## Every ability: the hand-written ones, each weapon's and each combat
## style's own moves (WeaponMoves, CombatStyles), and the universal ones.
static var ABILITIES: Dictionary = _all()


static func _all() -> Dictionary:
	var all: Dictionary = BASE_ABILITIES.duplicate(true)
	for weapon_id: String in WeaponMoves.MOVES:
		var type: String = ItemDB.ITEMS[weapon_id]["weapon"]["type"]
		var moves: Array = WeaponMoves.MOVES[weapon_id]
		for index in moves.size():
			var move := _move(moves[index])
			move["weapon_item"] = weapon_id
			move["weapon"] = type
			move["mastery"] = WeaponMoves.UNLOCK[index]
			all["wm_%s_%d" % [weapon_id, index]] = move
	for style: String in CombatStyles.STYLES:
		var moves: Array = CombatStyles.STYLES[style]["moves"]
		for index in moves.size():
			var move := _move(moves[index])
			move.erase("weapon")
			move["style"] = style
			move["mastery"] = 1
			all["st_%s_%d" % [style, index]] = move
	for id: String in UNIVERSAL:
		var move: Dictionary = UNIVERSAL[id].duplicate(true)
		move["universal"] = true
		all["u_" + id] = move
	return all


## A move given as an ability id becomes a copy of it that borrows its icon.
static func _move(entry: Variant) -> Dictionary:
	if entry is String:
		var copy: Dictionary = BASE_ABILITIES[entry].duplicate(true)
		copy["icon_from"] = entry
		copy.erase("class")
		copy.erase("level")
		return copy
	return (entry as Dictionary).duplicate(true)


## The four moves of a weapon (by item id), or of a combat style.
static func moves_for(weapon_id: String) -> Array[String]:
	var ids: Array[String] = []
	for index in WeaponMoves.MOVES.get(weapon_id, []).size():
		ids.append("wm_%s_%d" % [weapon_id, index])
	return ids


static func style_moves(style: String) -> Array[String]:
	var ids: Array[String] = []
	for index in CombatStyles.STYLES.get(style, {}).get("moves", []).size():
		ids.append("st_%s_%d" % [style, index])
	return ids


## Universal abilities and class abilities: what the second set can hold.
static func is_universal(id: String) -> bool:
	return ABILITIES.has(id) and (ABILITIES[id].get("universal", false) or ABILITIES[id].has("class"))


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
