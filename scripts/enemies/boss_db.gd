class_name BossDB
extends RefCounted
## World bosses: each one has its own name, look, moves, and treasure. They
## live in arenas out in the world (and at the bottom of dungeons).
##
##   "monster"  the sheet and kind it is built from (its minions are this kind)
##   "attacks"  moves used from the start; "phase2" / "phase3" are added at
##              two thirds and one third of its health
##   "tiles"    where its arena may stand      "set"  the set it always drops

const T := TerrainTiles.Type
const BOSSES := {
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
}
## Boss health and damage on top of a Mini-boss's.
const HEALTH := 3.5
const DAMAGE := 1.15
## In-game days before a beaten world boss returns.
const RESPAWN_DAYS := 3


static func for_tile(tile: int) -> String:
	for id: String in BOSSES:
		if tile in BOSSES[id]["tiles"]:
			return id
	return "hollow_king"


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
	items.append(Item.create("boss_trophy").to_dict())
	return items
