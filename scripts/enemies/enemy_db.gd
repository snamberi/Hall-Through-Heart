class_name EnemyDB
extends RefCounted
## Every kind of monster. Ids are stable (saves, quests, and loot use them).
##
## Numbers are for a level 1 normal enemy; level and rank scale them.
##   "attack"  how it fights (see Enemy):
##       lunge    wind up, then dash at the player
##       shoot    keep a distance and fire a projectile
##       slam     wind up, then hit everything in a circle around itself
##       cloud    like slam, and leaves a lingering hazard
##       explode  rush the player and blow itself up
##   "touch"   status inflicted on the player by its hits
##   "traits"  standing buffs (see TRAITS)
##   "tiles"   terrain it lives on     "min_level"  lowest area level it appears at
##   "flying"  ignores water and walls
##   "active"  "night" (most), "day", or "always": when it roams the open world

const T := TerrainTiles.Type
const SHEETS := "res://assets/sprites/enemies/%s.png"

const TRAITS := {
	"enrage": "Below 40% health it moves and hits much harder.",
	"armored": "Takes 35% less damage.",
	"regen": "Heals when left alone for a few seconds.",
	"pack": "Faster and stronger for each ally nearby.",
	"blink": "Vanishes and reappears next to its prey.",
	"lifesteal": "Heals for half the damage it deals.",
	"split": "Bursts into two smaller copies when killed.",
	"erratic": "Weaves from side to side as it closes in.",
	"inspire": "Allies near it move and attack faster.",
}

const ENEMIES := {
	"husk": {
		"active": "night", "name": "Husk", "sheet": "res://assets/sprites/husk_sheet.png", "health": 30.0, "damage": 10.0, "speed": 105.0, "xp": 8,
		"radius": 13.0, "size": 1.0, "tiles": [T.DEAD_GRASS, T.DARK_GRASS, T.MUD, T.ASH, T.BOG, T.SNOW, T.FROSTPINE, T.CRIMSON, T.SAND, T.THORN], "min_level": 1, "weight": 10.0,
		"attack": {"kind": "swipe", "range": 62.0, "windup": 0.5, "arc": 110.0, "recover": 0.8, "color": Color(0.85, 0.8, 0.7)},
		"traits": [],
	},
	"rot_hound": {
		"active": "day", "name": "Rot Hound", "health": 22.0, "damage": 8.0, "speed": 165.0, "xp": 9,
		"radius": 13.0, "size": 1.0, "tiles": [T.DEAD_GRASS, T.MUD, T.ASH, T.SNOW, T.SALT, T.THORN, T.CRIMSON], "min_level": 2, "weight": 7.0,
		"attack": {"kind": "pounce", "range": 140.0, "windup": 0.4, "time": 0.36, "radius": 46.0, "recover": 0.7, "color": Color(0.9, 0.4, 0.35)},
		"touch": {"status": "bleed", "duration": 3.0, "power": 0.25}, "traits": ["pack", "enrage"],
	},
	"bone_archer": {
		"active": "night", "name": "Bone Archer", "health": 20.0, "damage": 9.0, "speed": 85.0, "xp": 10,
		"radius": 12.0, "size": 1.0, "tiles": [T.ASH, T.MUD, T.DEAD_GRASS, T.SALT, T.SAND, T.CINDER, T.SNOW], "min_level": 3, "weight": 6.0,
		"attack": {"kind": "shoot", "range": 330.0, "windup": 0.6, "recover": 1.1, "sprite": 0, "speed": 430.0, "color": Color.WHITE},
		"traits": [],
	},
	"bog_slime": {
		"active": "day", "name": "Bog Slime", "health": 34.0, "damage": 7.0, "speed": 70.0, "xp": 9,
		"radius": 14.0, "size": 1.0, "tiles": [T.BOG, T.MUD, T.FUNGAL, T.TAR], "min_level": 2, "weight": 8.0,
		"attack": {"kind": "spit", "range": 200.0, "windup": 0.6, "recover": 1.2, "sprite": 1, "speed": 300.0, "count": 3, "spread": 34.0, "color": Color(0.55, 0.9, 0.4),
			"status": {"status": "poison", "duration": 3.0, "power": 0.25}},
		"touch": {"status": "poison", "duration": 4.0, "power": 0.3}, "traits": ["split"],
	},
	"carrion_bat": {
		"active": "night", "name": "Carrion Bat", "health": 14.0, "damage": 7.0, "speed": 175.0, "xp": 8, "flying": true,
		"radius": 11.0, "size": 0.9, "tiles": [T.DEAD_GRASS, T.DARK_GRASS, T.BOG, T.THORN, T.CRIMSON, T.SAND, T.FROSTPINE], "min_level": 3, "weight": 6.0,
		"attack": {"kind": "swoop", "range": 150.0, "windup": 0.35, "speed": 620.0, "time": 0.42, "recover": 1.1},
		"traits": ["erratic", "lifesteal"],
	},
	"thorn_stalker": {
		"active": "day", "name": "Thorn Stalker", "health": 28.0, "damage": 9.0, "speed": 120.0, "xp": 11,
		"radius": 14.0, "size": 1.0, "tiles": [T.DARK_GRASS, T.BOG, T.THORN, T.FUNGAL, T.FROSTPINE], "min_level": 4, "weight": 6.0,
		"attack": {"kind": "shoot", "range": 240.0, "windup": 0.5, "recover": 1.4, "sprite": 3, "speed": 380.0, "color": Color(0.8, 1.0, 0.8),
			"status": {"status": "chill", "duration": 2.5, "power": 0.45}},
		"touch": {"status": "poison", "duration": 4.0, "power": 0.3}, "traits": [],
	},
	"spore_shambler": {
		"active": "night", "name": "Spore Shambler", "health": 48.0, "damage": 6.0, "speed": 55.0, "xp": 12,
		"radius": 15.0, "size": 1.1, "tiles": [T.DARK_GRASS, T.BOG, T.FUNGAL, T.TAR], "min_level": 4, "weight": 5.0,
		"attack": {"kind": "cloud", "range": 80.0, "windup": 0.8, "recover": 1.6, "radius": 110.0, "linger": 4.0, "color": Color(0.7, 0.4, 0.8),
			"status": {"status": "poison", "duration": 3.0, "power": 0.35}},
		"traits": ["regen"],
	},
	"rot_cultist": {
		"active": "night", "name": "Rot Cultist", "health": 26.0, "damage": 11.0, "speed": 80.0, "xp": 14,
		"radius": 12.0, "size": 1.0, "tiles": [T.BOG, T.ASH, T.DARK_GRASS, T.CRIMSON, T.VOIDSCAR, T.FROSTPINE], "min_level": 6, "weight": 4.0,
		"attack": {"kind": "shoot", "range": 300.0, "windup": 0.7, "recover": 1.3, "sprite": 1, "speed": 360.0, "color": Color(0.6, 1.0, 0.6)},
		"traits": ["inspire"],
	},
	"ember_wisp": {
		"active": "always", "name": "Ember Wisp", "health": 12.0, "damage": 16.0, "speed": 150.0, "xp": 10, "flying": true,
		"radius": 11.0, "size": 0.9, "tiles": [T.ASH, T.MUD, T.CINDER, T.VOIDSCAR, T.SAND], "min_level": 5, "weight": 5.0,
		"attack": {"kind": "explode", "range": 46.0, "windup": 0.55, "recover": 0.0, "radius": 95.0, "color": Color(1.0, 0.6, 0.2),
			"status": {"status": "burn", "duration": 3.0, "power": 0.3}},
		"traits": [],
	},
	"ash_wraith": {
		"active": "night", "name": "Ash Wraith", "health": 24.0, "damage": 12.0, "speed": 95.0, "xp": 15, "flying": true,
		"radius": 12.0, "size": 1.0, "tiles": [T.ASH, T.DEAD_GRASS, T.SNOW, T.SALT, T.VOIDSCAR], "min_level": 8, "weight": 4.0,
		"attack": {"kind": "shoot", "range": 260.0, "windup": 0.55, "recover": 1.2, "sprite": 3, "speed": 400.0, "color": Color(0.7, 0.9, 1.0)},
		"traits": ["blink", "lifesteal"],
	},
	"crag_golem": {
		"active": "day", "name": "Crag Golem", "health": 90.0, "damage": 18.0, "speed": 60.0, "xp": 22,
		"radius": 18.0, "size": 1.35, "tiles": [T.ASH, T.MUD, T.SALT, T.CINDER, T.SAND], "min_level": 7, "weight": 3.0,
		"attack": {"kind": "slam", "range": 80.0, "windup": 0.9, "recover": 1.4, "radius": 120.0, "color": Color(1.0, 0.7, 0.4), "knockback": 520.0},
		"traits": ["armored", "enrage"],
	},
	# --- wildlife: animals to hunt. "wild": "flee" runs when hurt; "defend"
	# fights back once struck. They never come as Elites.
	"deer": {
		"active": "day", "wild": "flee", "name": "Deer", "health": 22.0, "damage": 0.0, "speed": 150.0, "xp": 4,
		"radius": 13.0, "size": 1.05, "tiles": [T.DARK_GRASS, T.DEAD_GRASS, T.FROSTPINE, T.THORN], "min_level": 1, "weight": 7.0,
		"attack": {"kind": "lunge", "range": 0.0, "windup": 0.5, "speed": 0.0, "time": 0.2, "recover": 0.5}, "traits": [],
	},
	"wild_hare": {
		"active": "always", "wild": "flee", "name": "Wild Hare", "health": 8.0, "damage": 0.0, "speed": 175.0, "xp": 2,
		"radius": 9.0, "size": 0.8, "tiles": [T.DARK_GRASS, T.DEAD_GRASS, T.SNOW, T.MUD, T.SAND], "min_level": 1, "weight": 6.0,
		"attack": {"kind": "lunge", "range": 0.0, "windup": 0.5, "speed": 0.0, "time": 0.2, "recover": 0.5}, "traits": [],
	},
	"wild_pig": {
		"active": "day", "wild": "defend", "name": "Wild Pig", "health": 30.0, "damage": 6.0, "speed": 120.0, "xp": 5,
		"radius": 13.0, "size": 1.0, "tiles": [T.DARK_GRASS, T.BOG, T.MUD, T.DEAD_GRASS], "min_level": 1, "weight": 6.0,
		"attack": {"kind": "charge", "range": 180.0, "windup": 0.6, "speed": 520.0, "time": 0.45, "recover": 0.9, "knockback": 360.0}, "traits": [],
	},
	"mountain_goat": {
		"active": "day", "wild": "defend", "name": "Mountain Goat", "health": 32.0, "damage": 7.0, "speed": 135.0, "xp": 6,
		"radius": 13.0, "size": 1.0, "tiles": [T.ROCK, T.PEAK, T.SNOW, T.FROSTPINE], "min_level": 2, "weight": 7.0,
		"attack": {"kind": "charge", "range": 220.0, "windup": 0.65, "speed": 600.0, "time": 0.45, "recover": 1.0, "knockback": 520.0}, "traits": [],
	},
	"pheasant": {
		"active": "day", "wild": "flee", "name": "Pheasant", "health": 9.0, "damage": 0.0, "speed": 160.0, "xp": 2,
		"radius": 10.0, "size": 0.85, "tiles": [T.DEAD_GRASS, T.THORN, T.DARK_GRASS, T.CRIMSON], "min_level": 1, "weight": 5.0,
		"attack": {"kind": "lunge", "range": 0.0, "windup": 0.5, "speed": 0.0, "time": 0.2, "recover": 0.5}, "traits": [],
	},
	"desert_lizard": {
		"active": "always", "wild": "flee", "name": "Desert Lizard", "health": 14.0, "damage": 0.0, "speed": 170.0, "xp": 3,
		"radius": 11.0, "size": 0.95, "tiles": [T.SAND, T.SALT, T.CINDER], "min_level": 1, "weight": 7.0,
		"attack": {"kind": "lunge", "range": 0.0, "windup": 0.5, "speed": 0.0, "time": 0.2, "recover": 0.5}, "traits": [],
	},
	"snow_fox": {
		"active": "always", "wild": "flee", "name": "Snow Fox", "health": 16.0, "damage": 0.0, "speed": 180.0, "xp": 4,
		"radius": 11.0, "size": 0.95, "tiles": [T.SNOW, T.FROSTPINE, T.PEAK], "min_level": 1, "weight": 6.0,
		"attack": {"kind": "lunge", "range": 0.0, "windup": 0.5, "speed": 0.0, "time": 0.2, "recover": 0.5}, "traits": [],
	},
	"shore_crab": {
		"active": "always", "wild": "defend", "name": "Shore Crab", "health": 20.0, "damage": 5.0, "speed": 90.0, "xp": 3,
		"radius": 12.0, "size": 0.9, "tiles": [T.SAND, T.MUD, T.SALT], "min_level": 1, "weight": 4.0,
		"attack": {"kind": "combo", "range": 58.0, "windup": 0.45, "count": 2, "gap": 0.2, "arc": 90.0, "claws": 2, "recover": 0.9, "color": Color(1.0, 0.6, 0.45)}, "traits": ["armored"],
	},
	"marsh_toad": {
		"active": "always", "wild": "flee", "name": "Marsh Toad", "health": 14.0, "damage": 0.0, "speed": 95.0, "xp": 3,
		"radius": 12.0, "size": 0.85, "tiles": [T.BOG, T.FUNGAL, T.MUD, T.TAR], "min_level": 1, "weight": 6.0,
		"attack": {"kind": "lunge", "range": 0.0, "windup": 0.5, "speed": 0.0, "time": 0.2, "recover": 0.5}, "traits": [],
	},
	"sheep": {
		"active": "day", "wild": "flee", "name": "Sheep", "health": 18.0, "damage": 0.0, "speed": 105.0, "xp": 3,
		"radius": 13.0, "size": 1.0, "tiles": [T.DARK_GRASS, T.DEAD_GRASS], "min_level": 1, "weight": 6.0,
		"attack": {"kind": "lunge", "range": 0.0, "windup": 0.5, "speed": 0.0, "time": 0.2, "recover": 0.5}, "traits": [],
	},
	"cow": {
		"active": "day", "wild": "flee", "name": "Cow", "health": 42.0, "damage": 0.0, "speed": 85.0, "xp": 5,
		"radius": 15.0, "size": 1.15, "tiles": [T.DARK_GRASS, T.DEAD_GRASS, T.MUD], "min_level": 1, "weight": 4.5,
		"attack": {"kind": "lunge", "range": 0.0, "windup": 0.5, "speed": 0.0, "time": 0.2, "recover": 0.5}, "traits": [],
	},
	"chicken": {
		"active": "day", "wild": "flee", "name": "Chicken", "health": 6.0, "damage": 0.0, "speed": 135.0, "xp": 1,
		"radius": 8.0, "size": 0.8, "tiles": [T.DARK_GRASS, T.DEAD_GRASS, T.SAND], "min_level": 1, "weight": 5.0,
		"attack": {"kind": "lunge", "range": 0.0, "windup": 0.5, "speed": 0.0, "time": 0.2, "recover": 0.5}, "traits": [],
	},
	"bear": {
		"active": "always", "wild": "defend", "name": "Bear", "health": 95.0, "damage": 16.0, "speed": 125.0, "xp": 18,
		"radius": 16.0, "size": 1.3, "tiles": [T.DARK_GRASS, T.FROSTPINE, T.ROCK, T.THORN], "min_level": 4, "weight": 2.5,
		"attack": {"kind": "swipe", "range": 74.0, "windup": 0.55, "arc": 130.0, "recover": 0.9, "knockback": 380.0, "color": Color(1.0, 0.9, 0.75)}, "traits": ["enrage"],
	},
	# --- biome families
	"grey_wolf": {
		"active": "night", "name": "Grey Wolf", "health": 26.0, "damage": 9.0, "speed": 170.0, "xp": 10,
		"radius": 13.0, "size": 1.0, "tiles": [T.DARK_GRASS, T.DEAD_GRASS, T.FROSTPINE, T.THORN, T.ROCK], "min_level": 2, "weight": 6.0,
		"attack": {"kind": "pounce", "range": 150.0, "windup": 0.38, "time": 0.34, "radius": 48.0, "recover": 0.6, "color": Color(0.85, 0.85, 0.9)},
		"touch": {"status": "bleed", "duration": 3.0, "power": 0.2}, "traits": ["pack"],
	},
	"giant_spider": {
		"active": "night", "name": "Giant Spider", "health": 32.0, "damage": 10.0, "speed": 150.0, "xp": 12,
		"radius": 14.0, "size": 1.25, "tiles": [T.DARK_GRASS, T.THORN, T.FUNGAL, T.BOG, T.CRIMSON], "min_level": 3, "weight": 5.0,
		"attack": {"kind": "pounce", "range": 130.0, "windup": 0.45, "time": 0.3, "radius": 44.0, "recover": 0.8, "color": Color(0.8, 0.4, 0.9)},
		"touch": {"status": "poison", "duration": 4.0, "power": 0.3}, "traits": ["erratic"],
	},
	"web_spider": {
		"active": "always", "name": "Web Spinner", "health": 20.0, "damage": 7.0, "speed": 120.0, "xp": 9,
		"radius": 12.0, "size": 1.0, "tiles": [T.FUNGAL, T.BOG, T.ROCK, T.DEAD_GRASS, T.ASH], "min_level": 2, "weight": 4.0,
		"attack": {"kind": "shoot", "range": 260.0, "windup": 0.55, "recover": 1.3, "sprite": 3, "speed": 340.0, "color": Color(0.95, 0.95, 1.0),
			"status": {"status": "chill", "duration": 3.0, "power": 0.55}},
		"traits": [],
	},
	"frost_wolf": {
		"active": "always", "name": "Frost Wolf", "health": 26.0, "damage": 10.0, "speed": 175.0, "xp": 11,
		"radius": 13.0, "size": 1.0, "tiles": [T.SNOW, T.FROSTPINE, T.PEAK], "min_level": 4, "weight": 9.0,
		"attack": {"kind": "pounce", "range": 150.0, "windup": 0.38, "time": 0.34, "radius": 50.0, "recover": 0.6, "color": Color(0.7, 0.9, 1.0)},
		"touch": {"status": "chill", "duration": 2.0, "power": 0.3}, "traits": ["pack"],
	},
	"frost_troll": {
		"active": "night", "name": "Frost Troll", "health": 110.0, "damage": 20.0, "speed": 62.0, "xp": 26,
		"radius": 19.0, "size": 1.45, "tiles": [T.SNOW, T.FROSTPINE, T.PEAK, T.ROCK], "min_level": 9, "weight": 3.0,
		"attack": {"kind": "slam", "range": 85.0, "windup": 0.95, "recover": 1.4, "radius": 130.0, "color": Color(0.6, 0.88, 1.0), "knockback": 540.0,
			"status": {"status": "chill", "duration": 3.0, "power": 0.4}},
		"traits": ["regen", "enrage"],
	},
	"dire_boar": {
		"active": "day", "name": "Dire Boar", "health": 40.0, "damage": 13.0, "speed": 140.0, "xp": 12,
		"radius": 15.0, "size": 1.1, "tiles": [T.DARK_GRASS, T.DEAD_GRASS, T.THORN], "min_level": 3, "weight": 5.0,
		"attack": {"kind": "charge", "range": 280.0, "windup": 0.8, "speed": 760.0, "time": 0.6, "recover": 1.0, "knockback": 600.0},
		"traits": ["enrage"],
	},
	"treant": {
		"active": "night", "name": "Treant", "health": 120.0, "damage": 15.0, "speed": 45.0, "xp": 24,
		"radius": 19.0, "size": 1.5, "tiles": [T.DARK_GRASS, T.BOG, T.FROSTPINE], "min_level": 8, "weight": 2.0,
		"attack": {"kind": "slam", "range": 85.0, "windup": 1.0, "recover": 1.5, "radius": 125.0, "color": Color(0.55, 0.9, 0.4), "knockback": 500.0},
		"traits": ["regen", "armored"],
	},
	"sand_scorpion": {
		"active": "always", "name": "Sand Scorpion", "health": 30.0, "damage": 11.0, "speed": 130.0, "xp": 11,
		"radius": 14.0, "size": 1.05, "tiles": [T.SAND, T.SALT], "min_level": 3, "weight": 9.0,
		"attack": {"kind": "thrust", "range": 104.0, "windup": 0.5, "arc": 34.0, "recover": 0.8, "color": Color(1.0, 0.85, 0.5)},
		"touch": {"status": "poison", "duration": 4.0, "power": 0.35}, "traits": [],
	},
	"dune_mummy": {
		"active": "night", "name": "Dune Mummy", "health": 45.0, "damage": 12.0, "speed": 68.0, "xp": 14,
		"radius": 13.0, "size": 1.05, "tiles": [T.SAND, T.SALT, T.ASH], "min_level": 5, "weight": 6.0,
		"attack": {"kind": "swipe", "range": 70.0, "windup": 0.6, "arc": 150.0, "claws": 1, "recover": 1.0, "color": Color(0.95, 0.9, 0.75)},
		"touch": {"status": "bleed", "duration": 4.0, "power": 0.25}, "traits": ["regen"],
	},
	"void_stalker": {
		"active": "night", "name": "Void Stalker", "health": 34.0, "damage": 15.0, "speed": 160.0, "xp": 17,
		"radius": 13.0, "size": 1.05, "tiles": [T.VOIDSCAR, T.CRIMSON], "min_level": 9, "weight": 6.0,
		"attack": {"kind": "combo", "range": 66.0, "windup": 0.35, "count": 3, "gap": 0.14, "arc": 100.0, "recover": 0.8, "color": Color(0.8, 0.55, 1.0)},
		"traits": ["blink", "erratic"],
	},
	"void_eye": {
		"active": "always", "name": "Void Eye", "health": 22.0, "damage": 13.0, "speed": 85.0, "xp": 15, "flying": true,
		"radius": 13.0, "size": 1.0, "tiles": [T.VOIDSCAR], "min_level": 8, "weight": 5.0,
		"attack": {"kind": "shoot", "range": 320.0, "windup": 0.65, "recover": 1.1, "sprite": 1, "speed": 380.0, "color": Color(0.8, 0.5, 1.0)},
		"traits": [],
	},
	"crimson_fiend": {
		"active": "night", "name": "Crimson Fiend", "health": 40.0, "damage": 14.0, "speed": 120.0, "xp": 16,
		"radius": 13.0, "size": 1.05, "tiles": [T.CRIMSON, T.THORN], "min_level": 7, "weight": 6.0,
		"attack": {"kind": "spin", "range": 70.0, "windup": 0.5, "radius": 84.0, "recover": 0.9, "color": Color(0.95, 0.3, 0.3)},
		"touch": {"status": "bleed", "duration": 3.0, "power": 0.3}, "traits": ["lifesteal", "enrage"],
	},
	# The heart's own: a living heart that pulses blood in waves, and a
	# knight whose open chest cage still holds a beating heart.
	"veinheart": {
		"active": "always", "name": "Veinheart", "health": 42.0, "damage": 12.0, "speed": 92.0, "xp": 18, "flying": true,
		"radius": 15.0, "size": 1.05, "tiles": [T.CRIMSON, T.THORN, T.ASH, T.BOG], "min_level": 14, "weight": 4.0,
		"attack": {"kind": "slam", "range": 96.0, "windup": 0.7, "recover": 1.1, "radius": 118.0, "color": Color(1.0, 0.3, 0.4), "knockback": 300.0},
		"touch": {"status": "bleed", "duration": 4.0, "power": 0.3}, "traits": ["lifesteal", "regen"],
	},
	"heartsworn_knight": {
		"active": "night", "name": "Heartsworn Knight", "health": 72.0, "damage": 15.0, "speed": 102.0, "xp": 26,
		"radius": 15.0, "size": 1.12, "tiles": [T.CRIMSON, T.THORN, T.ASH, T.DEAD_GRASS], "min_level": 18, "weight": 3.0,
		"attack": {"kind": "combo", "range": 64.0, "windup": 0.5, "count": 3, "gap": 0.22, "arc": 110.0, "claws": 1, "recover": 1.0, "color": Color(1.0, 0.35, 0.45)},
		"touch": {"status": "bleed", "duration": 3.0, "power": 0.25}, "traits": ["armored", "enrage"],
	},
	"magma_slime": {
		"active": "always", "name": "Magma Slime", "health": 38.0, "damage": 12.0, "speed": 70.0, "xp": 13,
		"radius": 14.0, "size": 1.0, "tiles": [T.CINDER, T.ASH, T.TAR], "min_level": 6, "weight": 7.0,
		"attack": {"kind": "spit", "range": 210.0, "windup": 0.6, "recover": 1.2, "sprite": 2, "speed": 320.0, "count": 3, "spread": 30.0, "color": Color(1.0, 0.55, 0.2),
			"status": {"status": "burn", "duration": 3.0, "power": 0.25}},
		"touch": {"status": "burn", "duration": 3.0, "power": 0.35}, "traits": ["split"],
	},
	"cinder_imp": {
		"active": "night", "name": "Cinder Imp", "health": 16.0, "damage": 11.0, "speed": 165.0, "xp": 12, "flying": true,
		"radius": 11.0, "size": 0.9, "tiles": [T.CINDER, T.ASH, T.CRIMSON], "min_level": 6, "weight": 6.0,
		"attack": {"kind": "shoot", "range": 280.0, "windup": 0.5, "recover": 1.0, "sprite": 2, "speed": 420.0, "color": Color(1.0, 0.6, 0.25),
			"status": {"status": "burn", "duration": 3.0, "power": 0.3}},
		"traits": ["erratic"],
	},
	"bog_lurker": {
		"active": "night", "name": "Bog Lurker", "health": 36.0, "damage": 12.0, "speed": 95.0, "xp": 12,
		"radius": 15.0, "size": 1.05, "tiles": [T.BOG, T.MUD, T.FUNGAL], "min_level": 4, "weight": 6.0,
		"attack": {"kind": "burrow", "range": 220.0, "windup": 1.1, "radius": 72.0, "recover": 1.0, "color": Color(0.5, 0.75, 0.4), "knockback": 300.0},
		"touch": {"status": "poison", "duration": 4.0, "power": 0.3}, "traits": [],
	},
	"storm_harpy": {
		"active": "day", "name": "Storm Harpy", "health": 24.0, "damage": 11.0, "speed": 170.0, "xp": 13, "flying": true,
		"radius": 12.0, "size": 1.0, "tiles": [T.ROCK, T.PEAK, T.SALT, T.DEAD_GRASS], "min_level": 5, "weight": 5.0,
		"attack": {"kind": "swoop", "range": 180.0, "windup": 0.4, "speed": 700.0, "time": 0.45, "recover": 1.0},
		"traits": ["erratic"],
	},
}

static func sheet(id: String) -> Texture2D:
	return load(ENEMIES[id].get("sheet", SHEETS % id))


## Picks which enemy spawns on a tile at an area level, by weight, among
## those about at this time of day. Returns "" if nothing fits.
static func pick(tile: int, area_level: int, night: bool = true, wild_ok: bool = true) -> String:
	var total := 0.0
	var options: Array[String] = []
	for id: String in ENEMIES:
		var data: Dictionary = ENEMIES[id]
		if not wild_ok and data.has("wild"):
			continue
		var active: String = data.get("active", "night")
		if active != "always" and (active == "night") != night:
			continue
		if tile in data["tiles"] and area_level >= data["min_level"]:
			options.append(id)
			total += data["weight"]
	if options.is_empty():
		return ""
	var roll := randf() * total
	for id in options:
		roll -= ENEMIES[id]["weight"]
		if roll <= 0.0:
			return id
	return options[0]
