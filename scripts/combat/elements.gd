class_name Elements
extends RefCounted
## The five elements. Weapons, gems, and gear add "<element>_damage" on top
## of each blow; armour adds "<element>_resist". Every monster has an element
## it attacks with (or none), and elements it is weak or hardy against.

const LIST: Array[String] = ["fire", "frost", "poison", "shadow", "holy"]
const DATA := {
	"fire": {"name": "Fire", "color": Color(1.0, 0.55, 0.2)},
	"frost": {"name": "Frost", "color": Color(0.6, 0.88, 1.0)},
	"poison": {"name": "Poison", "color": Color(0.55, 0.95, 0.35)},
	"shadow": {"name": "Shadow", "color": Color(0.72, 0.5, 1.0)},
	"holy": {"name": "Holy", "color": Color(1.0, 0.92, 0.55)},
	# Not an element of its own: the lightning of the Stormcaller.
	"storm": {"name": "Lightning", "color": Color(0.6, 0.85, 1.0)},
}
## The most of an element's damage that resistance can turn away.
const RESIST_CAP := 0.75
const WEAK := 1.5
const HARDY := 0.5
## Share of a monster's blow that is its element (the rest is physical).
const ATTACK_SHARE := 0.5

## Monster id -> {"attack": element, "weak": [...], "hardy": [...]}.
const MONSTERS := {
	"husk": {"weak": ["fire", "holy"]},
	"rot_hound": {"attack": "poison", "weak": ["fire"]},
	"bone_archer": {"weak": ["holy"], "hardy": ["poison", "frost"]},
	"bog_slime": {"attack": "poison", "weak": ["fire"], "hardy": ["poison"]},
	"carrion_bat": {"attack": "shadow", "weak": ["holy", "frost"]},
	"thorn_stalker": {"attack": "poison", "weak": ["fire"], "hardy": ["poison"]},
	"spore_shambler": {"attack": "poison", "weak": ["fire"], "hardy": ["poison", "shadow"]},
	"rot_cultist": {"attack": "shadow", "weak": ["holy"], "hardy": ["shadow"]},
	"ember_wisp": {"attack": "fire", "weak": ["frost"], "hardy": ["fire"]},
	"ash_wraith": {"attack": "shadow", "weak": ["holy", "fire"], "hardy": ["poison", "frost"]},
	"crag_golem": {"weak": ["frost"], "hardy": ["fire", "poison"]},
	"frost_wolf": {"attack": "frost", "weak": ["fire"], "hardy": ["frost"]},
	"frost_troll": {"attack": "frost", "weak": ["fire"], "hardy": ["frost", "poison"]},
	"dire_boar": {"weak": ["poison"]},
	"treant": {"weak": ["fire"], "hardy": ["poison", "frost"]},
	"sand_scorpion": {"attack": "poison", "weak": ["frost"], "hardy": ["fire", "poison"]},
	"dune_mummy": {"attack": "shadow", "weak": ["fire", "holy"], "hardy": ["poison"]},
	"void_stalker": {"attack": "shadow", "weak": ["holy"], "hardy": ["shadow"]},
	"void_eye": {"attack": "shadow", "weak": ["holy"], "hardy": ["shadow", "frost"]},
	"crimson_fiend": {"attack": "fire", "weak": ["holy", "frost"], "hardy": ["fire"]},
	"magma_slime": {"attack": "fire", "weak": ["frost"], "hardy": ["fire", "poison"]},
	"cinder_imp": {"attack": "fire", "weak": ["frost"], "hardy": ["fire"]},
	"bog_lurker": {"attack": "poison", "weak": ["fire"], "hardy": ["poison"]},
	"storm_harpy": {"weak": ["poison", "shadow"], "hardy": ["frost"]},
}


static func name_of(element: String) -> String:
	return DATA[element]["name"] if DATA.has(element) else "Physical"


static func color(element: String) -> Color:
	return DATA[element]["color"] if DATA.has(element) else Color(0.95, 0.9, 0.75)


## How much of an element's damage a monster takes.
static func multiplier(monster_id: String, element: String) -> float:
	var info: Dictionary = MONSTERS.get(monster_id, {})
	if element in info.get("weak", []):
		return WEAK
	if element in info.get("hardy", []):
		return HARDY
	return 1.0


static func attack_element(monster_id: String) -> String:
	return MONSTERS.get(monster_id, {}).get("attack", "")


## The player's resistance to an element, capped.
static func resistance(stats: CharacterStats, element: String) -> float:
	if element == "":
		return 0.0
	return clampf(stats.get_stat(element + "_resist") + stats.get_stat("elemental_resistance"), 0.0, RESIST_CAP)


## One line for tooltips and the bestiary.
static func describe_monster(monster_id: String) -> String:
	var info: Dictionary = MONSTERS.get(monster_id, {})
	var parts: PackedStringArray = []
	if info.has("attack"):
		parts.append("Attacks with %s" % name_of(info["attack"]).to_lower())
	if not info.get("weak", []).is_empty():
		parts.append("weak to " + ", ".join((info["weak"] as Array).map(func(e: String) -> String: return name_of(e).to_lower())))
	if not info.get("hardy", []).is_empty():
		parts.append("resists " + ", ".join((info["hardy"] as Array).map(func(e: String) -> String: return name_of(e).to_lower())))
	return "; ".join(parts)
