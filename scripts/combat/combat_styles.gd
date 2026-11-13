class_name CombatStyles
extends RefCounted
## Ways of fighting with your own body. Everyone starts with Brawler's
## Fists; the legendary styles are taught by masters who keep to lonely
## shrines (see Structures "dojo") and ask gold and rare things for it.
## A style is equipped in the Abilities screen and used from the first
## hotbar slot: its strikes, its on-hit effect, its bonuses while in use,
## and four moves of its own (AbilityDB turns them into "st_<style>_<n>").

const WATER := Color(0.45, 0.78, 1.0)
const FIRE := Color(1.0, 0.55, 0.2)
const DARK := Color(0.7, 0.45, 1.0)
const STONE := Color(0.82, 0.7, 0.52)
const STORM := Color(0.78, 0.9, 1.0)
const WIND := Color(0.75, 1.0, 0.85)

## id -> {"name", "color", "element" (for the strike trail), "strike" (how
## the plain attack lands: jab, palm, blink, heavy, kick, sweep), "profile"
## (attack profile like a weapon's), "on_hit" (optional status), "mods"
## (while in use), "moves", "teacher" (name), "cost" ({"gold", items...}),
## "level" (needed to be taught), "text"}.
static var STYLES: Dictionary = _styles()


static func _styles() -> Dictionary:
	var W := WeaponMoves
	return {
		"fist": {"name": "Brawler's Fists", "color": Color(0.95, 0.75, 0.5), "element": "", "strike": "jab", "level": 1,
			"profile": {"type": "unarmed", "range": 46.0, "arc": 100.0, "cooldown": 0.3, "knockback": 300.0},
			"mods": {}, "text": "Plain fists and stubbornness. Everyone starts here.",
			"moves": ["palm_strike", W.arc("Haymaker", "palm_strike", 2.6, 5.0, 80.0, 1.15, 900.0, "A wild swing that knocks them flat.", {"stun": 0.6}),
				"rapid_blows", "dragon_kick"]},
		"water_karate": {"name": "Water Karate", "color": WATER, "element": "frost", "strike": "palm", "level": 10, "teacher": "Master Ren of the Still Pool",
			"cost": {"gold": 1500, "pike": 3, "crab_shell": 6, "essence": 2},
			"profile": {"type": "unarmed", "range": 54.0, "arc": 130.0, "cooldown": 0.32, "knockback": 420.0},
			"on_hit": {"status": "chill", "duration": 1.5, "power": 0.3},
			"mods": {"dodge_efficiency": {"percent": 0.15}, "health_regen": {"flat": 1.0}},
			"text": "Flowing open palms that push foes away and slow them like cold water.",
			"moves": [W.arc("Tide Palm", "palm_strike", 2.0, 3.0, 120.0, 1.3, 950.0, "A wave of force from the open palm.", W.chill(0.5)),
				W.dash("Riptide Kick", "shadow_dash", 1.6, 5.0, 220.0, "Slide through foes like a current.", W.chill(0.4)),
				W.spin("Whirlpool", "frost_nova", 1.2, 8.0, 125.0, 3, "Spin like a whirlpool, three turns.", W.chill(0.5)),
				W.slam("Crashing Wave", "spell_frost_ring", 3.0, 11.0, 145.0, 90.0, "Bring a wave of force crashing down.", W.chill(0.7))]},
		"fire_fist": {"name": "Fire Fist", "color": FIRE, "element": "fire", "strike": "jab", "level": 15, "teacher": "Master Hoka the Ember",
			"cost": {"gold": 2000, "ember_core": 5, "fiend_horn": 5},
			"profile": {"type": "unarmed", "range": 46.0, "arc": 90.0, "cooldown": 0.27, "knockback": 260.0},
			"on_hit": {"status": "burn", "duration": 2.5, "power": 0.25},
			"mods": {"fire_damage": {"flat": 3.0}, "attack_speed": {"percent": 0.06}},
			"text": "Burning fists, fast jabs and uppercuts that leave foes on fire.",
			"moves": [W.arc("Blazing Jab", "spell_fire_bolt", 1.8, 2.5, 80.0, 1.1, 300.0, "A quick jab wreathed in fire.", W.burn(0.35)),
				W.arc("Flame Uppercut", "palm_strike", 2.6, 5.0, 90.0, 1.15, 800.0, "An uppercut that throws them up burning.", {"stun": 0.5, "status": {"status": "burn", "duration": 3.0, "power": 0.4}, "color": FIRE}),
				W.flurry("Inferno Barrage", "rapid_blows", 0.55, 7.0, 7, "Seven burning punches.", W.burn(0.2)),
				W.leap("Phoenix Dive", "dragon_kick", 3.0, 11.0, 125.0, 210.0, "Leap and come down as a falling fire.", W.burn(0.5))]},
		"dark_step": {"name": "Dark Step", "color": DARK, "element": "shadow", "strike": "blink", "level": 20, "teacher": "The Nameless Shade",
			"cost": {"gold": 2500, "void_shard": 6, "wraith_cloth": 4},
			"profile": {"type": "unarmed", "range": 50.0, "arc": 100.0, "cooldown": 0.3, "knockback": 220.0},
			"mods": {"life_steal": {"flat": 0.03}, "shadow_damage": {"flat": 3.0}, "move_speed": {"percent": 0.06}},
			"text": "Step through the dark to strike from where they are not looking. Every blow drinks a little life.",
			"moves": [W.arc("Shade Strike", "backstab", 2.2, 3.0, 90.0, 1.2, 250.0, "A strike from the shadow at their side.", {"color": DARK, "heal": 0.02}),
				{"name": "Umbral Step", "shape": "blink", "icon_from": "shadow_step", "damage": 1.6, "stamina": 18.0, "cooldown": 5.0, "distance": 240.0, "radius": 70.0, "knockback": 200.0, "color": DARK, "text": "Vanish and step out of the dark where you point, striking all near."},
				W.flurry("Night Flurry", "blade_flurry", 0.6, 7.0, 6, "Six blows from the dark.", {"color": DARK}),
				{"name": "Eclipse", "shape": "veil", "icon_from": "smoke_bomb", "damage": 2.0, "stamina": 30.0, "cooldown": 30.0, "radius": 150.0, "duration": 5.0, "knockback": 300.0, "color": DARK, "mods": {"move_speed": {"percent": 0.3}, "critical_chance": {"flat": 0.25}}, "text": "Darkness bursts from you: foes lose you, and for 5 seconds you move faster and crit more."}]},
		"stone_palm": {"name": "Stone Palm", "color": STONE, "element": "", "strike": "heavy", "level": 12, "teacher": "Old Gorran of the Hill",
			"cost": {"gold": 1500, "stone_heart": 3, "stone": 20},
			"profile": {"type": "unarmed", "range": 50.0, "arc": 110.0, "cooldown": 0.42, "knockback": 650.0},
			"mods": {"armor": {"percent": 0.15}, "knockback_resistance": {"flat": 0.3}, "physical_damage": {"percent": 0.1}},
			"text": "Slow, heavy palms like falling stone. Hard to move, harder to stop.",
			"moves": [W.arc("Rock Palm", "palm_strike", 2.8, 4.0, 100.0, 1.2, 1100.0, "A palm like a falling boulder.", {"stun": 0.8, "color": STONE}),
				W.spin("Quake Stomp", "war_stomp", 2.0, 8.0, 135.0, 1, "Stamp the ground; everything near reels.", {"stun": 1.0, "color": STONE}),
				W.slam("Avalanche", "earthshatter", 3.2, 11.0, 135.0, 100.0, "Bring the hillside down on them.", {"color": STONE}),
				W.buff("Mountain Stance", "iron_skin", 35.0, 8.0, {"armor": {"percent": 0.5}, "damage_taken": {"percent": -0.25}}, STONE, "For 8 seconds stand like a mountain: far tougher and harder to hurt.")]},
		"storm_kick": {"name": "Storm Kick", "color": STORM, "element": "storm", "strike": "kick", "level": 25, "teacher": "Sky-Sister Aelith",
			"cost": {"gold": 2500, "harpy_feather": 6, "essence": 3},
			"profile": {"type": "unarmed", "range": 56.0, "arc": 80.0, "cooldown": 0.25, "knockback": 300.0},
			"mods": {"attack_speed": {"percent": 0.1}, "move_speed": {"percent": 0.08}},
			"text": "Kicks quick as lightning; the storm leaps from foe to foe.",
			"moves": [W.arc("Thunder Kick", "dragon_kick", 2.2, 3.0, 80.0, 1.25, 500.0, "A kick that cracks like thunder.", {"color": STORM}),
				W.dash("Static Rush", "spell_storm_rush", 1.8, 5.0, 260.0, "Rush through foes trailing sparks.", {"color": STORM}),
				{"name": "Arc Heel", "shape": "chain", "icon_from": "lightning_chain", "damage": 1.5, "stamina": 20.0, "cooldown": 6.0, "targets": 4, "reach": 300.0, "jump": 170.0, "color": STORM, "text": "A heel-strike whose lightning leaps between four foes."},
				W.leap("Heaven's Heel", "dragon_kick", 3.0, 11.0, 125.0, 220.0, "Leap high and drive the heel down like a bolt.", {"color": STORM})]},
		"wind_crane": {"name": "Wind Crane", "color": WIND, "element": "", "strike": "sweep", "level": 18, "teacher": "Master Lio of the High Reeds",
			"cost": {"gold": 1800, "feather": 10, "pheasant_feather": 6},
			"profile": {"type": "unarmed", "range": 58.0, "arc": 160.0, "cooldown": 0.3, "knockback": 340.0},
			"mods": {"dodge_efficiency": {"percent": 0.25}, "move_speed": {"percent": 0.1}},
			"text": "Wide, sweeping crane kicks and steps light as wind.",
			"moves": [W.arc("Crane Kick", "dragon_kick", 2.0, 3.0, 180.0, 1.2, 450.0, "A wide sweeping kick.", {"color": WIND}),
				W.spin("Gale Spin", "whirlwind", 1.1, 7.0, 115.0, 3, "Spin like a whirlwind, three turns.", {"color": WIND, "knockback": 450.0}),
				W.dash("Feather Step", "arcane_dash", 1.2, 4.0, 290.0, "Step far and light, striking as you pass.", {"color": WIND}),
				W.spin("Tempest", "cleaving_storm", 2.6, 12.0, 175.0, 1, "A storm of wind bursts from you.", {"color": WIND, "knockback": 750.0})]},
	}


static func profile(style: String) -> Dictionary:
	return STYLES.get(style, STYLES["fist"])["profile"]


## A style's icon: the picture of its first move.
static func icon(style: String) -> Texture2D:
	return AbilityDB.icon("st_%s_0" % style)


## Everything a master asks: "1500 gold, 3 Pike, ..."
static func cost_text(style: String) -> String:
	var parts: PackedStringArray = []
	var cost: Dictionary = STYLES[style].get("cost", {})
	for key: String in cost:
		parts.append("%d gold" % cost[key] if key == "gold" else "%d %s" % [cost[key], ItemDB.ITEMS[key]["name"]])
	return ", ".join(parts)
