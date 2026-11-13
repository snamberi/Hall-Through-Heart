class_name BossDB
extends RefCounted
## World bosses: each one has its own name, look, moves, and treasure. They
## live in arenas out in the world (and at the bottom of dungeons).
##
##   "monster"  the sheet and kind it is built from (its minions are this kind)
##   "attacks"  moves used from the start; "phase2" / "phase3" are added at
##              two thirds and one third of its health
##   "tiles"    where its arena may stand      "set"  the set it always drops
##   "min_level" the area level it needs before its arena appears (default 1);
##              where several bosses fit a place, the arena's seed picks one

const T := TerrainTiles.Type
const BOSSES := {
	# Keeper of the Ninefold Blade's last piece, deep in the high, cold places.
	"sword_keeper": {"name": "The Sword Keeper", "monster": "heartsworn_knight", "tint": Color(0.8, 0.88, 1.0), "size": 2.4, "health": 1.4,
		"attacks": ["charge", "slam", "volley"], "phase2": ["spiral"], "phase3": ["teleport"], "color": Color(0.85, 0.9, 1.0),
		"tiles": [T.ROCK, T.PEAK, T.SNOW, T.ASH], "set": "gravewarden", "unique": "stormcaller", "min_level": 30},
	# Rises in a graveyard once its dead have been put down (see Structures).
	"corpse_of_roots": {"name": "The Corpse of Roots", "monster": "rotten_corpse", "tint": Color(0.85, 1.0, 0.75), "size": 2.8, "health": 1.1,
		"attacks": ["slam", "summon", "pools"], "phase2": ["charge"], "phase3": ["nova"], "color": Color(0.55, 0.85, 0.35),
		"tiles": [], "set": "gravewarden", "unique": "wispkeeper"},
	"weeping_shade": {"name": "The Weeping Shade", "monster": "ghost", "tint": Color(0.75, 0.8, 1.0), "size": 2.6, "health": 0.9,
		"attacks": ["teleport", "volley", "spiral"], "phase2": ["summon"], "phase3": ["nova"], "color": Color(0.7, 0.85, 1.0),
		"tiles": [T.ASH, T.DEAD_GRASS, T.SNOW], "set": "nightstalker", "unique": "frostbite", "min_level": 18},
	"hollow_king": {"name": "The Hollow King", "monster": "husk", "tint": Color(0.75, 0.68, 0.95), "size": 2.6, "health": 1.0,
		"attacks": ["slam", "charge", "summon"], "phase2": ["volley"], "phase3": ["nova"], "color": Color(0.75, 0.55, 1.0),
		"tiles": [T.DEAD_GRASS, T.DARK_GRASS, T.MUD], "set": "gravewarden", "unique": "bloodthirst"},
	"rot_mother": {"name": "Mother of Rot", "monster": "bog_slime", "tint": Color(0.7, 1.0, 0.6), "size": 3.0, "health": 1.2,
		"attacks": ["pools", "slam", "summon"], "phase2": ["nova"], "phase3": ["volley"], "color": Color(0.55, 0.95, 0.35),
		"tiles": [T.BOG, T.FUNGAL, T.TAR], "set": "nightstalker", "unique": "voidwalker"},
	"cinderlord": {"name": "The Cinderlord", "monster": "ember_wisp", "tint": Color(1.0, 0.75, 0.6), "size": 2.8, "health": 0.9,
		"attacks": ["spiral", "meteor"], "phase2": ["nova"], "phase3": ["summon"], "color": Color(1.0, 0.55, 0.2),
		"tiles": [T.CINDER, T.ASH], "set": "emberheart", "unique": "ember_crown"},
	"frostwarden": {"name": "The Frostwarden", "monster": "crag_golem", "tint": Color(0.6, 0.85, 1.2), "size": 2.4, "health": 1.3,
		"attacks": ["slam", "charge", "volley"], "phase2": ["meteor"], "phase3": ["nova"], "color": Color(0.6, 0.88, 1.0),
		"tiles": [T.SNOW, T.FROSTPINE, T.PEAK], "set": "frostbound", "unique": "frostbite"},
	"pale_matron": {"name": "The Pale Matron", "monster": "ash_wraith", "tint": Color(0.85, 0.8, 1.0), "size": 2.5, "health": 0.9,
		"attacks": ["teleport", "volley", "summon"], "phase2": ["spiral"], "phase3": ["meteor"], "color": Color(0.72, 0.5, 1.0),
		"tiles": [T.VOIDSCAR, T.CRIMSON], "set": "archmage", "unique": "gravecaller"},
	"sunless_prophet": {"name": "The Sunless Prophet", "monster": "rot_cultist", "tint": Color(1.0, 0.9, 0.7), "size": 2.4, "health": 1.0,
		"attacks": ["meteor", "volley", "summon"], "phase2": ["teleport"], "phase3": ["spiral"], "color": Color(1.0, 0.85, 0.45),
		"tiles": [T.SAND, T.SALT, T.THORN], "set": "sunward", "unique": "sunfang"},
	"briar_queen": {"name": "The Briar Queen", "monster": "thorn_stalker", "tint": Color(1.0, 0.75, 0.8), "size": 2.6, "health": 1.0,
		"attacks": ["charge", "volley", "summon"], "phase2": ["pools"], "phase3": ["spiral"], "color": Color(0.95, 0.4, 0.5),
		"tiles": [T.THORN, T.CRIMSON, T.DARK_GRASS], "set": "nightstalker", "unique": "bloodthirst", "min_level": 12},
	"dune_tyrant": {"name": "The Dune Tyrant", "monster": "sand_scorpion", "tint": Color(1.1, 0.9, 0.65), "size": 2.7, "health": 1.25,
		"attacks": ["charge", "slam", "pools"], "phase2": ["volley"], "phase3": ["meteor"], "color": Color(0.95, 0.75, 0.35),
		"tiles": [T.SAND, T.SALT], "set": "sunward", "unique": "splitshot", "min_level": 16},
	"rime_colossus": {"name": "The Rime Colossus", "monster": "frost_troll", "tint": Color(0.75, 0.9, 1.15), "size": 2.6, "health": 1.4,
		"attacks": ["slam", "charge"], "phase2": ["meteor"], "phase3": ["nova"], "color": Color(0.55, 0.85, 1.0),
		"tiles": [T.SNOW, T.PEAK, T.FROSTPINE], "set": "frostbound", "unique": "frostbite", "min_level": 22},
	"molten_heart": {"name": "The Molten Heart", "monster": "magma_slime", "tint": Color(1.15, 0.8, 0.6), "size": 3.0, "health": 1.2,
		"attacks": ["pools", "slam", "summon"], "phase2": ["spiral"], "phase3": ["meteor"], "color": Color(1.0, 0.45, 0.15),
		"tiles": [T.CINDER, T.TAR], "set": "emberheart", "unique": "ember_crown", "min_level": 25},
	"mire_leviathan": {"name": "The Mire Leviathan", "monster": "bog_lurker", "tint": Color(0.75, 1.0, 0.8), "size": 2.8, "health": 1.3,
		"attacks": ["pools", "charge", "summon"], "phase2": ["slam"], "phase3": ["volley"], "color": Color(0.4, 0.85, 0.55),
		"tiles": [T.BOG, T.MUD, T.TAR], "set": "gravewarden", "unique": "voidwalker", "min_level": 14},
	"elder_grove": {"name": "The Elder Grove", "monster": "treant", "tint": Color(0.85, 1.0, 0.8), "size": 2.5, "health": 1.5,
		"attacks": ["slam", "summon", "pools"], "phase2": ["volley"], "phase3": ["nova"], "color": Color(0.45, 0.85, 0.35),
		"tiles": [T.DARK_GRASS, T.FUNGAL, T.DEAD_GRASS], "set": "gravewarden", "unique": "wispkeeper", "min_level": 18},
	"unblinking_eye": {"name": "The Unblinking Eye", "monster": "void_eye", "tint": Color(1.0, 0.85, 1.15), "size": 3.0, "health": 1.1,
		"attacks": ["teleport", "spiral", "volley"], "phase2": ["summon"], "phase3": ["nova"], "color": Color(0.8, 0.5, 1.0),
		"tiles": [T.VOIDSCAR, T.ASH], "set": "archmage", "unique": "stormcaller", "min_level": 30},
}
## Boss health and damage on top of a Mini-boss's.
const HEALTH := 3.5
const DAMAGE := 1.15
## In-game days before a beaten world boss returns.
const RESPAWN_DAYS := 3


## Bosses that rise again when first beaten: a second life at full health,
## a new name, a new colour and harder moves. Only the second fall counts.
const REVIVES := {
	"sword_keeper": {"name": "The Sword Keeper, Unsheathed", "moves": ["nova", "meteor"], "tint": Color(1.0, 0.9, 0.6)},
	"corpse_of_roots": {"name": "The Corpse of Roots, Rerooted", "moves": ["spiral", "summon"], "tint": Color(0.7, 1.0, 0.5)},
	"hollow_king": {"name": "The Hollow King, Unbound", "moves": ["spiral", "meteor"], "tint": Color(0.9, 0.55, 1.0)},
	"cinderlord": {"name": "The Cinderlord Reborn", "moves": ["nova", "pools"], "tint": Color(1.2, 0.7, 0.4)},
	"pale_matron": {"name": "The Pale Matron, Risen", "moves": ["teleport", "nova"], "tint": Color(0.8, 0.9, 1.2)},
	"elder_grove": {"name": "The Elder Grove, Rekindled", "moves": ["meteor", "charge"], "tint": Color(1.0, 0.8, 0.5)},
}
## The boss that leaves each piece of the Ninefold Blade.
const PIECES := {
	"hollow_king": "pommel_hollow", "cinderlord": "guard_cinder", "frostwarden": "edge_frost", "pale_matron": "grip_pale",
	"briar_queen": "wrap_briar", "dune_tyrant": "fuller_dune", "molten_heart": "core_molten", "unblinking_eye": "gem_eye",
	"sword_keeper": "heart_blade",
}


static func for_tile(tile: int) -> String:
	for id: String in BOSSES:
		if tile in BOSSES[id]["tiles"]:
			return id
	return "hollow_king"


## The boss for an arena or crypt here: any whose land this is and whose
## level the area has reached, chosen by the place's own seed so it stays
## the same each visit.
static func for_site(tile: int, level: int, seed: int) -> String:
	var options: Array[String] = []
	for id: String in BOSSES:
		if tile in BOSSES[id]["tiles"] and level >= int(BOSSES[id].get("min_level", 1)):
			options.append(id)
	if options.is_empty():
		return for_tile(tile)
	return options[posmod(seed, options.size())]


## What a boss leaves: a set piece of its own set, often its unique, gems,
## gold, and a trophy.
static func drops(id: String, level: int) -> Array:
	var data: Dictionary = BOSSES[id]
	var items: Array = [{"id": "gold_coins", "count": roundi(randf_range(80.0, 140.0) * pow(level, 0.9))}]
	items.append(LootGenerator.make_set_piece(level, data["set"]).to_dict())
	if randf() < 0.35:
		items.append(LootGenerator.make_unique(level, data["unique"]).to_dict())
	items.append(LootGenerator.make_equipment(level, maxi(LootGenerator.roll_rarity(0.0, 10.0), 3)).to_dict())
	for i in 2:
		items.append(Item.create(Gems.random_gem(level + 20)).to_dict())
	items.append(Item.create("heart_shard", 3).to_dict())
	if PIECES.has(id):
		items.append(Item.create(PIECES[id]).to_dict())
	items.append(Item.create("boss_trophy").to_dict())
	var steed: String = {"frostwarden": "frost_elk_whistle", "sunless_prophet": "sand_strider_whistle", "pale_matron": "nightmare_whistle", "hollow_king": "nightmare_whistle"}.get(id, "")
	if steed != "" and randf() < 0.2:
		items.append(Item.create(steed).to_dict())
	return items
