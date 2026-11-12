class_name Appearance
extends RefCounted
## How the player looks. A character is a dictionary of choices:
##
##   race                         who they are: sets a starting look and a few gifts
##   skin, clothes, trousers      colours, recoloured on the body sheet by a palette-swap shader
##   hair_style, hair, beard      shape and colour of hair (separate layers over a bald body)
##   eyes, ears, horns, tail, wings, mark    features, each its own layer
##   height, build                how tall and how broad
##   look                         a whole outfit unlocked through achievements
##
## Every list here is one row of choices in the character creator and the
## wardrobe; indices are saved, so only ever add to the ends.

## The body sheet's own colours, in the order the shader swaps them.
const SOURCE: Array[String] = [
	"e8c4a0", "c99c7c", "9c7460", "b98a6c",   # skin x3, shade
	"6e4a33", "523625", "38241a",             # hair x3 (unused: hair is a layer)
	"b9ad92", "968a72", "6e6454", "7d7260",   # tunic x3, fold
	"4c4a5e", "383648", "272633",             # trousers x3
]
const SKIN_TONES: Array[Array] = [
	["e8c4a0", "c99c7c", "9c7460", "b98a6c"], ["f6dcc6", "dcb89c", "ac8a70", "cca488"], ["d0a078", "a87a56", "7a5236", "9a6a48"],
	["9a6644", "7a4c30", "54321e", "6a402a"], ["6a4430", "4e3020", "321e14", "422a1c"], ["e2e0e8", "c4c0cc", "96909e", "b2aebc"],
	["9cc878", "74a054", "4e7438", "608a44"], ["a4ae72", "808a54", "5a643c", "6e7848"], ["8ff0c8", "5fd0a0", "3a9a78", "4ab48c"],
	["eeeadc", "cfcab8", "9c9888", "b8b4a2"], ["e87060", "bc4c42", "84302c", "a03c36"], ["a83a44", "802a32", "581a20", "6c222a"],
	["5ab4a2", "3e8c7c", "2a6458", "34786a"], ["7ab8e8", "5690c4", "3a6894", "487cac"], ["a8a8b6", "848490", "5c5c68", "70707c"],
	["b890e0", "9068b8", "664888", "7a58a0"], ["f0e4e8", "d4c0c8", "a4909a", "bca8b0"], ["e4b470", "bc8c4c", "8a6030", "a47440"],
]
const SKIN_NAMES: Array[String] = ["Fair", "Pale", "Tan", "Brown", "Dark", "Ashen", "Goblin green", "Olive", "Slime", "Bone", "Ember red", "Crimson",
	"Scale teal", "Sea blue", "Stone", "Violet", "Moonlit", "Golden"]
const HAIR: Array[Array] = [
	["8a6044", "523625", "38241a"], ["3a3238", "1c181c", "100c10"], ["f0d078", "c8a050", "907034"], ["d05a34", "963820", "6a2414"],
	["f0eef2", "bcbac2", "8a8892"], ["7a8ab0", "4c5a7a", "343e56"], ["fff4d8", "e0d0a8", "b0a078"], ["f090b8", "c06088", "8a3c5c"],
	["78c860", "4c9838", "306a22"], ["50c8c0", "2c9890", "1a6a64"], ["a070e0", "7448b0", "4c2c80"], ["f09040", "c46820", "8c4410"],
	["4a5a9a", "303c70", "1e264c"], ["a89080", "7c6858", "544438"],
]
const HAIR_NAMES: Array[String] = ["Brown", "Black", "Blond", "Red", "White", "Steel blue", "Platinum", "Rose", "Moss", "Teal", "Violet", "Copper", "Midnight", "Ash"]
const EYES: Array[Array] = [
	["2a2228", "1a1418", "0c080c"], ["5ab0ff", "3a80d0", "2458a0"], ["6ad070", "40a048", "246c2c"], ["f0b040", "c08020", "8a5810"], ["ff5050", "d02828", "901414"],
	["c080ff", "9050d8", "6030a0"], ["c0c8d0", "909aa4", "646e78"], ["ffe060", "e0b830", "a88410"], ["80fff0", "40d8c8", "1ca090"], ["ffffff", "e0e0e8", "b0b0bc"],
]
const EYE_NAMES: Array[String] = ["Dark", "Blue", "Green", "Amber", "Red", "Violet", "Grey", "Gold", "Glowing cyan", "White"]
const CLOTHES: Array[Array] = [
	["b9ad92", "968a72", "6e6454", "7d7260"], ["b03a3a", "862a2c", "5a1a1e", "6e2226"], ["4e8a4a", "386a36", "264a24", "2e5a2c"],
	["3e5a92", "2c4472", "1e2e50", "26385e"], ["3a3440", "28242e", "18161e", "201c26"], ["7a4a9a", "5c3678", "3e2452", "4a2c62"],
	["e8e2d4", "c4bcaa", "948c7a", "aca492"], ["c08a3a", "966a2a", "6a4a1c", "7c5822"], ["3a8a8a", "2a6a6c", "1c4a4e", "225a5c"],
	["c86a8a", "9c4a6a", "6e2e48", "843a58"], ["8a5a3a", "6a4028", "462a1a", "583420"], ["5a6a3a", "44522a", "2e3a1c", "384622"],
]
const CLOTHES_NAMES: Array[String] = ["Undyed", "Red", "Green", "Blue", "Black", "Purple", "White", "Ochre", "Teal", "Rose", "Leather", "Moss"]
const TROUSERS: Array[Array] = [
	["4c4a5e", "383648", "272633"], ["6a5040", "4e3a2e", "34261e"], ["2a2a30", "1c1c22", "121216"], ["3a4a6a", "2a3650", "1c2438"],
	["8a8070", "6a6254", "4a443a"], ["5a3a3a", "422828", "2c1a1a"], ["3a5a44", "2a4432", "1c2e22"], ["c8c0b0", "a09888", "746c60"],
]
const TROUSER_NAMES: Array[String] = ["Slate", "Brown", "Black", "Blue", "Linen", "Oxblood", "Forest", "White"]
## Feature lists: "sheet" is a file in assets/sprites/looks ("" for none).
const HAIR_STYLES: Array[Dictionary] = [
	{"name": "Tousled", "sheet": "hair_0"}, {"name": "Cropped", "sheet": "hair_1"}, {"name": "Long", "sheet": "hair_2"}, {"name": "Ponytail", "sheet": "hair_3"},
	{"name": "Mohawk", "sheet": "hair_4"}, {"name": "Topknot", "sheet": "hair_5"}, {"name": "Spiky", "sheet": "hair_6"}, {"name": "Bob", "sheet": "hair_7"},
	{"name": "Braids", "sheet": "hair_8"}, {"name": "Wild mane", "sheet": "hair_9"}, {"name": "Side sweep", "sheet": "hair_10"}, {"name": "Curls", "sheet": "hair_11"},
	{"name": "Curtains", "sheet": "hair_12"}, {"name": "Bald", "sheet": ""},
]
const BEARDS: Array[Dictionary] = [
	{"name": "Clean shaven", "sheet": ""}, {"name": "Moustache", "sheet": "beard_1"}, {"name": "Goatee", "sheet": "beard_2"}, {"name": "Short beard", "sheet": "beard_3"},
	{"name": "Long beard", "sheet": "beard_4"}, {"name": "Forked beard", "sheet": "beard_5"},
]
const EARS: Array[Dictionary] = [
	{"name": "Round", "sheet": ""}, {"name": "Pointed", "sheet": "ears_1"}, {"name": "Long", "sheet": "ears_2"}, {"name": "Beast", "sheet": "ears_3", "tint": "hair"},
	{"name": "Fins", "sheet": "ears_4"},
]
const HORNS: Array[Dictionary] = [
	{"name": "None", "sheet": ""}, {"name": "Nubs", "sheet": "horns_1"}, {"name": "Ram", "sheet": "horns_2"}, {"name": "Devil", "sheet": "horns_3"},
	{"name": "Antlers", "sheet": "horns_4"}, {"name": "Crystal crown", "sheet": "horns_5"}, {"name": "Unicorn", "sheet": "horns_6"},
]
const TAILS: Array[Dictionary] = [
	{"name": "None", "sheet": ""}, {"name": "Devil", "sheet": "tail_1", "tint": "skin"}, {"name": "Brush", "sheet": "tail_2", "tint": "hair"}, {"name": "Lizard", "sheet": "tail_3", "tint": "skin"},
]
const WINGS: Array[Dictionary] = [
	{"name": "None", "sheet": ""}, {"name": "Fairy", "sheet": "wings_1", "color": Color(0.75, 0.95, 1.0)}, {"name": "Bat", "sheet": "wings_2", "tint": "skin"},
]
const MARKS: Array[Dictionary] = [
	{"name": "None", "sheet": ""}, {"name": "Scar", "sheet": "mark_1"}, {"name": "War paint", "sheet": "mark_2"}, {"name": "Freckles", "sheet": "mark_3"},
	{"name": "Blush", "sheet": "mark_4"}, {"name": "Brow gem", "sheet": "mark_5"}, {"name": "Tattoo", "sheet": "mark_6"}, {"name": "Tusks", "sheet": "mark_7"},
	{"name": "Fangs", "sheet": "mark_8"},
]
const HEIGHTS: Array[Dictionary] = [
	{"name": "Small", "scale": 0.88}, {"name": "Short", "scale": 0.94}, {"name": "Average", "scale": 1.0}, {"name": "Tall", "scale": 1.06}, {"name": "Towering", "scale": 1.12},
]
const BUILDS: Array[Dictionary] = [{"name": "Slight", "scale": 0.92}, {"name": "Average", "scale": 1.0}, {"name": "Broad", "scale": 1.09}]
## Who the character is. "look" is the starting appearance; "mods" are the
## race's gifts, kept for life.
const RACES := {
	"human": {"name": "Human", "text": "Stubborn and quick to learn. No gift is theirs alone, so they take a little of each.",
		"look": {"skin": 0}, "mods": {"max_health": {"percent": 0.04}, "physical_damage": {"percent": 0.04}, "magic_find": {"flat": 0.05}}},
	"elf": {"name": "Elf", "text": "Long-lived and sharp-eyed, at home with bow and spell.",
		"look": {"skin": 1, "ears": 1, "height": 3, "build": 0, "hair_style": 2, "hair": 6, "eyes": 2}, "mods": {"magic_power": {"percent": 0.1}, "critical_chance": {"flat": 0.04}, "max_mana": {"percent": 0.1}}},
	"dwarf": {"name": "Dwarf", "text": "Short, broad and hard as the rock they mine.",
		"look": {"skin": 2, "height": 0, "build": 2, "beard": 4, "hair_style": 8, "hair": 3}, "mods": {"armor": {"percent": 0.12}, "max_health": {"percent": 0.08}, "mining_efficiency": {"percent": 0.25}}},
	"orc": {"name": "Orc", "text": "Big, loud and happiest in a fight.",
		"look": {"skin": 7, "height": 4, "build": 2, "mark": 7, "hair_style": 4, "hair": 1, "ears": 1}, "mods": {"physical_damage": {"percent": 0.12}, "max_health": {"percent": 0.08}, "magic_power": {"percent": -0.05}}},
	"goblin": {"name": "Goblin", "text": "Small, quick and never without a coin that used to be someone else's.",
		"look": {"skin": 6, "height": 0, "build": 0, "ears": 2, "hair_style": 13, "eyes": 7}, "mods": {"move_speed": {"percent": 0.08}, "gold_find": {"flat": 0.2}, "dodge_efficiency": {"flat": 0.1}, "max_health": {"percent": -0.05}}},
	"slime": {"name": "Slime", "text": "A person-shaped puddle that learned to walk. Poison is a drink to it, and it mends itself.",
		"look": {"skin": 8, "hair_style": 13, "eyes": 8, "height": 1}, "alpha": 0.82,
		"mods": {"poison_resist": {"flat": 0.5}, "health_regen": {"flat": 1.5}, "damage_taken": {"percent": -0.05}, "armor": {"percent": -0.1}}},
	"undead": {"name": "Undead", "text": "Died once already and did not care for it. Shadow holds no fear for the dead.",
		"look": {"skin": 9, "hair_style": 13, "eyes": 8, "build": 0}, "mods": {"shadow_resist": {"flat": 0.4}, "life_steal": {"flat": 0.03}, "holy_resist": {"flat": -0.2}}},
	"demonkin": {"name": "Demonkin", "text": "Horned children of the ember fields. Fire is in their blood.",
		"look": {"skin": 10, "horns": 3, "tail": 1, "hair": 1, "hair_style": 10, "eyes": 3}, "mods": {"fire_damage": {"flat": 3.0}, "fire_resist": {"flat": 0.4}, "physical_damage": {"percent": 0.05}, "frost_resist": {"flat": -0.15}}},
	"beastkin": {"name": "Beastkin", "text": "Ears that hear a twig snap a field away, and legs to match.",
		"look": {"skin": 17, "ears": 3, "tail": 2, "hair_style": 9, "hair": 11, "eyes": 3}, "mods": {"attack_speed": {"percent": 0.08}, "move_speed": {"percent": 0.06}, "critical_chance": {"flat": 0.03}}},
	"lizardfolk": {"name": "Lizardfolk", "text": "Cold-blooded, thick-scaled and patient.",
		"look": {"skin": 12, "tail": 3, "hair_style": 13, "eyes": 7, "horns": 1}, "mods": {"armor": {"percent": 0.08}, "poison_resist": {"flat": 0.3}, "health_regen": {"flat": 1.0}}},
	"fairy": {"name": "Fairy", "text": "Tiny, bright and far more dangerous than it looks.",
		"look": {"skin": 1, "wings": 1, "height": 0, "build": 0, "ears": 1, "hair_style": 5, "hair": 7, "eyes": 5}, "mods": {"max_mana": {"percent": 0.2}, "magic_power": {"percent": 0.08}, "dodge_efficiency": {"flat": 0.15}, "max_health": {"percent": -0.08}}},
	"stoneborn": {"name": "Stoneborn", "text": "Carved from the mountain and woken by accident. Slow, and very hard to break.",
		"look": {"skin": 14, "horns": 5, "hair_style": 13, "height": 3, "build": 2, "eyes": 8}, "mods": {"armor": {"percent": 0.2}, "damage_taken": {"percent": -0.06}, "move_speed": {"percent": -0.05}}},
	"vampire": {"name": "Vampire", "text": "Pale, polite and always a little hungry.",
		"look": {"skin": 16, "mark": 8, "hair": 1, "hair_style": 12, "eyes": 4, "ears": 1}, "mods": {"life_steal": {"flat": 0.05}, "shadow_damage": {"flat": 3.0}, "holy_resist": {"flat": -0.2}}},
	"merfolk": {"name": "Merfolk", "text": "Born of the deep water, walking the land out of curiosity.",
		"look": {"skin": 13, "ears": 4, "hair": 9, "hair_style": 2, "eyes": 8}, "mods": {"frost_resist": {"flat": 0.3}, "max_mana": {"percent": 0.1}, "health_regen": {"flat": 1.0}}},
}
## Rows of choices, in the order the creator shows them:
## [key, title, list, kind] where kind is "colour" (swatches) or "shape" (named buttons).
const OPTIONS: Array[Array] = [
	["skin", "Skin", "SKIN_TONES", "colour"], ["height", "Height", "HEIGHTS", "shape"], ["build", "Build", "BUILDS", "shape"],
	["hair_style", "Hair", "HAIR_STYLES", "shape"], ["hair", "Hair colour", "HAIR", "colour"], ["beard", "Beard", "BEARDS", "shape"],
	["eyes", "Eyes", "EYES", "colour"], ["mark", "Face", "MARKS", "shape"], ["ears", "Ears", "EARS", "shape"], ["horns", "Horns", "HORNS", "shape"],
	["tail", "Tail", "TAILS", "shape"], ["wings", "Wings", "WINGS", "shape"],
	["clothes", "Clothes", "CLOTHES", "colour"], ["trousers", "Trousers", "TROUSERS", "colour"],
]
## Looks unlocked by achievements. Each fixes the colours ("skin", "hair",
## "clothes", "trousers" as option indices) and may add a hood.
const LOOKS := {
	"wanderer": {"name": "Wanderer", "text": "Your own colours."},
	"reaper": {"name": "Reaper", "text": "A pale face under a black cowl. From the achievement Death's Hand.",
		"skin": 5, "hair": 1, "clothes": 4, "trousers": 2, "hood": Color(0.12, 0.1, 0.14)},
	"ashen": {"name": "Ashen", "text": "Grey as the burned fields. From the achievement The Butcher.",
		"skin": 5, "hair": 4, "clothes": 4, "trousers": 4, "hood": Color(0.42, 0.4, 0.42)},
	"verdant": {"name": "Verdant", "text": "Dressed for the deep woods. From the achievement Wayfarer.",
		"hair": 3, "clothes": 2, "trousers": 1},
	"dawn_knight": {"name": "Knight of Dawn", "text": "White and gold. From the achievement Dawnbringer.",
		"hair": 2, "clothes": 6, "trousers": 4},
}
const DEFAULT := {"race": "human", "skin": 0, "hair": 0, "hair_style": 0, "beard": 0, "eyes": 0, "ears": 0, "horns": 0, "tail": 0, "wings": 0, "mark": 0,
	"height": 2, "build": 1, "clothes": 0, "trousers": 0, "look": "wanderer"}
## Slots for feature layers, back to front: [slot, appearance key, list, drawn behind the body].
const FEATURES: Array[Array] = [
	["tail", "tail", "TAILS", true], ["wings", "wings", "WINGS", true], ["ears", "ears", "EARS", false], ["eyes", "eyes", "", false],
	["mark", "mark", "MARKS", false], ["beard", "beard", "BEARDS", false], ["hair", "hair_style", "HAIR_STYLES", false], ["horns", "horns", "HORNS", false],
]
## Layers every race has of its own (not chosen in the creator).
const RACE_LAYERS: Array[String] = ["race", "race_accent"]
## Every look layer in drawing order, back to front: [slot, behind body].
const LAYER_ORDER: Array[Array] = [["tail", true], ["wings", true], ["ears", false], ["race", false], ["eyes", false], ["mark", false],
	["race_accent", false], ["beard", false], ["hair", false], ["horns", false]]

const SHADER := """
shader_type canvas_item;
uniform vec3 source[14];
uniform vec3 target[14];
// Below this line (in the sprite's own pixels) the body is under water.
uniform float water_line = 9999.0;
varying float local_y;
void vertex() {
	local_y = VERTEX.y;
}
void fragment() {
	if (local_y > water_line) {
		discard;
	}
	vec4 pixel = texture(TEXTURE, UV);
	vec3 result = pixel.rgb;
	for (int i = 0; i < 14; i++) {
		if (distance(pixel.rgb, source[i]) < 0.02) {
			result = target[i];
		}
	}
	COLOR = vec4(result, pixel.a) * COLOR;
	COLOR.rgb = mix(COLOR.rgb, vec3(0.75, 0.88, 0.95), step(water_line - 1.5, local_y) * 0.55);
}
"""

static var _shader: Shader


static func _color(hex: String) -> Vector3:
	var c := Color(hex)
	return Vector3(c.r, c.g, c.b)


## The list behind an option row, by its constant's name.
static func list(list_name: String) -> Array:
	match list_name:
		"SKIN_TONES": return SKIN_TONES
		"HAIR": return HAIR
		"EYES": return EYES
		"CLOTHES": return CLOTHES
		"TROUSERS": return TROUSERS
		"HAIR_STYLES": return HAIR_STYLES
		"BEARDS": return BEARDS
		"EARS": return EARS
		"HORNS": return HORNS
		"TAILS": return TAILS
		"WINGS": return WINGS
		"MARKS": return MARKS
		"HEIGHTS": return HEIGHTS
		"BUILDS": return BUILDS
	return []


## The name of one choice, for labels.
static func option_name(list_name: String, index: int) -> String:
	match list_name:
		"SKIN_TONES": return SKIN_NAMES[index]
		"HAIR": return HAIR_NAMES[index]
		"EYES": return EYE_NAMES[index]
		"CLOTHES": return CLOTHES_NAMES[index]
		"TROUSERS": return TROUSER_NAMES[index]
	return str(list(list_name)[index]["name"])


## How many separate choices the creator offers, races included.
static func option_count() -> int:
	var total := RACES.size()
	for row in OPTIONS:
		total += list(row[2]).size()
	return total


## The choices actually worn, after a look's overrides, each kept in range.
static func resolved(appearance: Dictionary) -> Dictionary:
	var result := DEFAULT.duplicate()
	result.merge(appearance, true)
	var look: Dictionary = LOOKS.get(result["look"], LOOKS["wanderer"])
	for key: String in ["skin", "hair", "clothes", "trousers"]:
		if look.has(key):
			result[key] = look[key]
	for row in OPTIONS:
		result[row[0]] = clampi(int(result[row[0]]), 0, list(row[2]).size() - 1)
	if not RACES.has(result["race"]):
		result["race"] = "human"
	return result


## A fresh character of a race: the race's own look over the defaults.
static func for_race(race: String) -> Dictionary:
	var result := DEFAULT.duplicate()
	result["race"] = race
	result.merge(RACES[race]["look"], true)
	return result


## A character rolled from nothing.
static func random() -> Dictionary:
	var races: Array = RACES.keys()
	var result := for_race(races[randi() % races.size()])
	for key: String in ["hair", "clothes", "trousers", "eyes"]:
		for row in OPTIONS:
			if row[0] == key:
				result[key] = randi() % list(row[2]).size()
	if randf() < 0.7 and int(result["hair_style"]) != HAIR_STYLES.size() - 1:
		result["hair_style"] = randi() % (HAIR_STYLES.size() - 1)
	if randf() < 0.25:
		result["beard"] = randi() % BEARDS.size()
	if randf() < 0.3:
		result["mark"] = randi() % MARKS.size()
	result["height"] = clampi(int(result["height"]) + randi_range(-1, 1), 0, HEIGHTS.size() - 1)
	return result


## How the body is stretched: x for build, y for height.
static func body_scale(appearance: Dictionary) -> Vector2:
	var worn := resolved(appearance)
	var height: float = HEIGHTS[worn["height"]]["scale"]
	return Vector2(height * float(BUILDS[worn["build"]]["scale"]), height)


## How solid the body is drawn (slimes are see-through).
static func alpha(appearance: Dictionary) -> float:
	return float(RACES[resolved(appearance)["race"]].get("alpha", 1.0))


## The race's stat modifiers.
static func race_mods(appearance: Dictionary) -> Dictionary:
	return RACES[resolved(appearance)["race"]]["mods"]


## The feature layers to draw: slot -> {"sheet", "tint"}; a slot with
## nothing to show is left out.
static func layers(appearance: Dictionary) -> Dictionary:
	var worn := resolved(appearance)
	var skin := Color(SKIN_TONES[worn["skin"]][0])
	var hair := Color(HAIR[worn["hair"]][0])
	var result := {}
	for feature in FEATURES:
		var slot: String = feature[0]
		if slot == "eyes":
			if worn["eyes"] > 0:
				result[slot] = {"sheet": "eyes", "tint": Color(EYES[worn["eyes"]][0])}
			continue
		var choice: Dictionary = list(feature[2])[worn[feature[1]]]
		if choice["sheet"] == "":
			continue
		var tint := Color.WHITE
		if slot in ["hair", "beard"] or choice.get("tint", "") == "hair":
			tint = hair
		elif slot == "ears" or choice.get("tint", "") == "skin":
			tint = skin
		elif choice.has("color"):
			tint = choice["color"]
		result[slot] = {"sheet": choice["sheet"], "tint": tint}
	# Each race's own details: one layer in the skin's colours, one that
	# keeps its own (tusks, embers, moss, fin glints...).
	var race: String = str(worn.get("race", "human"))
	if ResourceLoader.exists("res://assets/sprites/looks/race_%s.png" % race):
		result["race"] = {"sheet": "race_" + race, "tint": skin}
	if ResourceLoader.exists("res://assets/sprites/looks/race_%s_accent.png" % race):
		result["race_accent"] = {"sheet": "race_%s_accent" % race, "tint": Color.WHITE}
	return result


static func make_material(appearance: Dictionary) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var material := ShaderMaterial.new()
	material.shader = _shader
	update_material(material, appearance)
	return material


static func update_material(material: ShaderMaterial, appearance: Dictionary) -> void:
	var worn := resolved(appearance)
	var sources := PackedVector3Array()
	for hex in SOURCE:
		sources.append(_color(hex))
	var targets := PackedVector3Array()
	for hex: String in SKIN_TONES[worn["skin"]]:
		targets.append(_color(hex))
	for hex: String in HAIR[worn["hair"]]:
		targets.append(_color(hex))
	for hex: String in CLOTHES[worn["clothes"]]:
		targets.append(_color(hex))
	for hex: String in TROUSERS[worn["trousers"]]:
		targets.append(_color(hex))
	material.set_shader_parameter("source", sources)
	material.set_shader_parameter("target", targets)


## The hood colour of a look, or transparent if it has none.
static func hood(appearance: Dictionary) -> Color:
	var look: Dictionary = LOOKS.get(resolved(appearance)["look"], {})
	return look.get("hood", Color.TRANSPARENT)
