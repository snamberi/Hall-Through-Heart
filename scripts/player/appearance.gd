class_name Appearance
extends RefCounted
## How the player looks: skin tone, hair, clothes and trousers, recoloured
## from the body sheet by a palette-swap shader, or a whole "look" (skin)
## unlocked through achievements.

## The body sheet's own colours, in the order the shader swaps them.
const SOURCE: Array[String] = [
	"e8c4a0", "c99c7c", "9c7460", "b98a6c",   # skin x3, shade
	"6e4a33", "523625", "38241a",             # hair x3
	"b9ad92", "968a72", "6e6454", "7d7260",   # tunic x3, fold
	"4c4a5e", "383648", "272633",             # trousers x3
]
const SKIN_TONES: Array[Array] = [
	["e8c4a0", "c99c7c", "9c7460", "b98a6c"], ["f6dcc6", "dcb89c", "ac8a70", "cca488"], ["d0a078", "a87a56", "7a5236", "9a6a48"],
	["9a6644", "7a4c30", "54321e", "6a402a"], ["6a4430", "4e3020", "321e14", "422a1c"], ["e2e0e8", "c4c0cc", "96909e", "b2aebc"],
]
const HAIR: Array[Array] = [
	["6e4a33", "523625", "38241a"], ["2a2428", "1c181c", "100c10"], ["e8c870", "c8a050", "907034"], ["c0502e", "963820", "6a2414"],
	["e8e6ea", "bcbac2", "8a8892"], ["6a7aa0", "4c5a7a", "343e56"],
]
const CLOTHES: Array[Array] = [
	["b9ad92", "968a72", "6e6454", "7d7260"], ["b03a3a", "862a2c", "5a1a1e", "6e2226"], ["4e8a4a", "386a36", "264a24", "2e5a2c"],
	["3e5a92", "2c4472", "1e2e50", "26385e"], ["3a3440", "28242e", "18161e", "201c26"], ["7a4a9a", "5c3678", "3e2452", "4a2c62"],
	["e8e2d4", "c4bcaa", "948c7a", "aca492"], ["c08a3a", "966a2a", "6a4a1c", "7c5822"],
]
const TROUSERS: Array[Array] = [
	["4c4a5e", "383648", "272633"], ["6a5040", "4e3a2e", "34261e"], ["2a2a30", "1c1c22", "121216"], ["3a4a6a", "2a3650", "1c2438"],
	["8a8070", "6a6254", "4a443a"],
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
const DEFAULT := {"skin": 0, "hair": 0, "clothes": 0, "trousers": 0, "look": "wanderer"}

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


## The colours actually worn, after a look's overrides.
static func resolved(appearance: Dictionary) -> Dictionary:
	var result := DEFAULT.duplicate()
	result.merge(appearance, true)
	var look: Dictionary = LOOKS.get(result["look"], LOOKS["wanderer"])
	for key: String in ["skin", "hair", "clothes", "trousers"]:
		if look.has(key):
			result[key] = look[key]
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
	for hex: String in SKIN_TONES[clampi(worn["skin"], 0, SKIN_TONES.size() - 1)]:
		targets.append(_color(hex))
	for hex: String in HAIR[clampi(worn["hair"], 0, HAIR.size() - 1)]:
		targets.append(_color(hex))
	for hex: String in CLOTHES[clampi(worn["clothes"], 0, CLOTHES.size() - 1)]:
		targets.append(_color(hex))
	for hex: String in TROUSERS[clampi(worn["trousers"], 0, TROUSERS.size() - 1)]:
		targets.append(_color(hex))
	material.set_shader_parameter("source", sources)
	material.set_shader_parameter("target", targets)


## The hood colour of a look, or transparent if it has none.
static func hood(appearance: Dictionary) -> Color:
	var look: Dictionary = LOOKS.get(resolved(appearance)["look"], {})
	return look.get("hood", Color.TRANSPARENT)
