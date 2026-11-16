class_name Trophies
extends RefCounted
## Boss trophies for a trophy hall. Beating a world boss earns its trophy;
## set it on a Trophy Stand inside a house and it gives a small lasting
## bonus while it stands there (each boss's trophy counts once).
##
## Each trophy is drawn from a small hand-placed pixel map in the boss's
## colours: o outline, l light, m mid, d dark, w highlight, x black.

const SHAPES := {
	"skull": [
		"...oooooo...",
		"..ollllllo..",
		".ollllllmmo.",
		".olxxllxxmo.",
		".olxxllxxmo.",
		".ollllxllmo.",
		"..ollmmmlo..",
		"...olmlmo...",
		"...oxmxmo...",
		"....oooo....",
	],
	"crown": [
		".o...o....o.",
		"olo.olo..olo",
		"olmoolmooomo",
		"olllllllllmo",
		"olwlllwlllmo",
		"olllllllllmo",
		"ommmmmmmmmdo",
		"oooooooooooo",
	],
	"flame": [
		".....o......",
		"....olo.....",
		"...olwlo.o..",
		"...olwlo.olo",
		"..olwwllolmo",
		"..olwwlllmo.",
		".olwwwllmmo.",
		".olwwlllmmo.",
		".ollllllmdo.",
		"..ollllmdo..",
		"...ommmdo...",
		"....oooo....",
	],
	"crystal": [
		".....oo.....",
		"....olmo....",
		"...olwmmo...",
		"..olwlmmdo..",
		"..olwlmmdo..",
		"..olwlmmdo..",
		"..olllmmdo..",
		"...ollmdo...",
		"....olmo....",
		".....oo.....",
	],
	"orb": [
		"...oooooo...",
		"..ollllllo..",
		".olwwllllmo.",
		".olwlllllmo.",
		".ollllllmmo.",
		".ollllllmmo.",
		".olllllmmdo.",
		"..olmmmmdo..",
		"...oooooo...",
	],
	"heart": [
		"..ooo..ooo..",
		".olllo.olmo.",
		"olwlllolllmo",
		"olwllllllmmo",
		"olllllllllmo",
		".olllllllmo.",
		"..olllllmo..",
		"...olllmo...",
		"....olmo....",
		".....oo.....",
	],
	"eye": [
		"....oooo....",
		"..oowwwwoo..",
		".owwwmmwwwo.",
		"owwwmxxmwwwo",
		"owwwmxxmwwwo",
		".owwwmmwwwo.",
		"..oowwwwoo..",
		"....oooo....",
	],
	"helm": [
		"...oooooo...",
		"..ollllllo..",
		".ollllllmmo.",
		".olllllllmo.",
		".oxxxxxxxxo.",
		".ollolmolmo.",
		".ollolmolmo.",
		".olllllllmo.",
		"..ommmmmmo..",
		"...oooooo...",
	],
	"mask": [
		"..oooooooo..",
		".ollllllllo.",
		".olxxllxxlo.",
		".olxxllxxlo.",
		".ollllllllo.",
		".olllxxlllo.",
		"..ollxxllo..",
		"..olllllmo..",
		"...ommmmo...",
		"....oooo....",
	],
	"horn": [
		"..........oo",
		".........olo",
		"........olmo",
		".......olmo.",
		".....ollmo..",
		"...olllmo...",
		"..ollmmo....",
		".ollmmdo....",
		".olmmdo.....",
		".oooooo.....",
	],
	"fang": [
		".oooooooooo.",
		".ollllllmmo.",
		"..olllllmo..",
		"..ollllmmo..",
		"...ollmmo...",
		"...olllmo...",
		"....olmo....",
		"....olmo....",
		".....oo.....",
	],
	"leaf": [
		"........oo..",
		"......oolo..",
		"....oollmo..",
		"...ollllmo..",
		"..olllllmo..",
		".ollwlllmo..",
		".olwlllmo...",
		".olllmmo....",
		"..ommmo.....",
		".o.ooo......",
		"o...........",
	],
}

## Boss id -> its trophy: the shape, a name, what it gives, and the bonus.
const TROPHIES := {
	"sword_keeper": {"shape": "helm", "name": "Keeper's Helm", "text": "+5% critical damage", "mods": {"critical_damage": {"flat": 0.05}}},
	"corpse_of_roots": {"shape": "skull", "name": "Root-Bound Skull", "text": "+4% poison resistance", "mods": {"poison_resist": {"flat": 0.04}}},
	"weeping_shade": {"shape": "mask", "name": "Weeping Mask", "text": "+4% shadow resistance", "mods": {"shadow_resist": {"flat": 0.04}}},
	"hollow_king": {"shape": "crown", "name": "Hollow Crown", "text": "+3% physical damage", "mods": {"physical_damage": {"percent": 0.03}}},
	"rot_mother": {"shape": "orb", "name": "Brood Sac", "text": "+0.5 health per second", "mods": {"health_regen": {"flat": 0.5}}},
	"cinderlord": {"shape": "flame", "name": "Undying Cinder", "text": "+4% fire resistance", "mods": {"fire_resist": {"flat": 0.04}}},
	"frostwarden": {"shape": "crystal", "name": "Heart of Rime", "text": "+4% frost resistance", "mods": {"frost_resist": {"flat": 0.04}}},
	"pale_matron": {"shape": "mask", "name": "Matron's Veil", "text": "+3% magic damage", "mods": {"magic_power": {"percent": 0.03}}},
	"sunless_prophet": {"shape": "orb", "name": "Sunless Orb", "text": "+4% holy resistance", "mods": {"holy_resist": {"flat": 0.04}}},
	"briar_queen": {"shape": "crown", "name": "Briar Circlet", "text": "+1% life steal", "mods": {"life_steal": {"flat": 0.01}}},
	"dune_tyrant": {"shape": "horn", "name": "Tyrant's Barb", "text": "+5% gold found", "mods": {"gold_find": {"percent": 0.05}}},
	"rime_colossus": {"shape": "fang", "name": "Colossus Tusk", "text": "+3% armour", "mods": {"armor": {"percent": 0.03}}},
	"molten_heart": {"shape": "heart", "name": "Cooling Heart", "text": "+3% maximum health", "mods": {"max_health": {"percent": 0.03}}},
	"mire_leviathan": {"shape": "fang", "name": "Leviathan Fang", "text": "+3% maximum stamina", "mods": {"max_stamina": {"percent": 0.03}}},
	"elder_grove": {"shape": "leaf", "name": "Elder Leaf", "text": "+3% mana", "mods": {"max_mana": {"percent": 0.03}}},
	"unblinking_eye": {"shape": "eye", "name": "The Eye, Closed", "text": "+4% magic find", "mods": {"magic_find": {"flat": 0.04}}},
}
const OUTLINE := Color("1a1420")
const BLACK := Color("120c14")
const HIGHLIGHT := Color(1.0, 0.98, 0.9)
## Bone and steel trophies keep most of their own colour.
const BASES := {"skull": Color("e8dcc0"), "helm": Color("b8c0cc")}


static func color_of(boss_id: String) -> Color:
	return BossDB.BOSSES.get(boss_id, {}).get("color", Color(0.8, 0.8, 0.8))


## Bosses beaten at least once, in the order they are listed.
static func earned(codex: Codex) -> Array[String]:
	var result: Array[String] = []
	for id: String in TROPHIES:
		if codex != null and int(codex.boss_kills.get(id, 0)) > 0:
			result.append(id)
	return result


## The stat modifiers from a set of displayed trophies (each boss once).
static func bonus(shown: Array) -> Dictionary:
	var total := {}
	var seen := {}
	for id: String in shown:
		if not TROPHIES.has(id) or seen.has(id):
			continue
		seen[id] = true
		var mods: Dictionary = TROPHIES[id]["mods"]
		for stat: String in mods:
			if not total.has(stat):
				total[stat] = {}
			for kind: String in mods[stat]:
				total[stat][kind] = float(total[stat].get(kind, 0.0)) + float(mods[stat][kind])
	return total


## The size of a trophy's pixel map.
static func size_of(boss_id: String) -> Vector2i:
	var rows: Array = SHAPES[TROPHIES[boss_id]["shape"]]
	return Vector2i(String(rows[0]).length(), rows.size())


## Draws a trophy on any canvas item, its bottom middle at `foot`, each map
## pixel `pixel` screen pixels wide (whole numbers only).
static func draw(canvas: CanvasItem, boss_id: String, foot: Vector2, pixel: int = 1, faded := false) -> void:
	var shape: String = TROPHIES[boss_id]["shape"]
	var rows: Array = SHAPES[shape]
	var tint := color_of(boss_id)
	if BASES.has(shape):
		tint = BASES[shape].lerp(tint, 0.3)
	var colors := {
		"o": OUTLINE, "x": BLACK, "w": HIGHLIGHT,
		"l": tint.lightened(0.3), "m": tint, "d": tint.darkened(0.45),
	}
	var width := String(rows[0]).length()
	var origin := (foot - Vector2(width * pixel / 2.0, rows.size() * pixel)).round()
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var key := row[x]
			if key == ".":
				continue
			var color: Color = colors[key]
			if faded:
				color = Color(0.22, 0.24, 0.3, 0.9) if key != "o" else Color(0.1, 0.11, 0.15, 0.9)
			canvas.draw_rect(Rect2(origin + Vector2(x * pixel, y * pixel), Vector2(pixel, pixel)), color)
