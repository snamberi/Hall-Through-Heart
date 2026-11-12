class_name Wind
extends RefCounted
## The wind in the trees. Every tree, bush and banner shares one material
## that leans its top to and fro, each a little out of step with the next;
## a storm blows them harder. Grass and flowers bend too, each plant from
## its own foot. In snowfall or ashfall, snow or ash settles along the top
## edges of trees, bushes and props, and wears away after.

## Settled snow or ash on top edges: lit where a pixel has open air above.
const DUSTING := """
uniform vec4 dust_color : source_color = vec4(1.0);
uniform float dust = 0.0;

vec4 dusted(sampler2D tex, vec2 uv, vec2 pixel_size, vec4 color) {
	if (dust <= 0.0 || color.a < 0.5) {
		return color;
	}
	float above = texture(tex, uv - vec2(0.0, pixel_size.y)).a;
	float above2 = texture(tex, uv - vec2(0.0, pixel_size.y * 2.0)).a;
	float top = (1.0 - step(0.5, above)) + (1.0 - step(0.5, above2)) * 0.6 * step(0.6, dust);
	return vec4(mix(color.rgb, dust_color.rgb, clamp(top, 0.0, 1.0) * dust * 0.9), color.a);
}
"""

const SHADER := """
shader_type canvas_item;
uniform float strength = 2.0;
uniform float reach = 48.0;
""" + DUSTING + """
void vertex() {
	// The foot stays planted; the higher up, the further it moves.
	float lift = clamp(0.5 - VERTEX.y / (reach * 2.0), 0.0, 1.0);
	vec2 place = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xy;
	float gust = sin(TIME * 1.3 + place.x * 0.021 + place.y * 0.013) + 0.4 * sin(TIME * 2.9 + place.x * 0.05);
	VERTEX.x += gust * strength * lift * lift;
}

void fragment() {
	COLOR = dusted(TEXTURE, UV, TEXTURE_PIXEL_SIZE, COLOR);
}
"""

## For still things (props, boulders): no sway, only the dusting.
const STILL_SHADER := """
shader_type canvas_item;
""" + DUSTING + """
void fragment() {
	COLOR = dusted(TEXTURE, UV, TEXTURE_PIXEL_SIZE, COLOR);
}
"""

## Ground cover: every plant bends from its own foot (the bottom of its
## picture). Flat decals and shadows (drawn see-through) stay still.
const GRASS_SHADER := """
shader_type canvas_item;
uniform float strength = 2.0;

void vertex() {
	if (COLOR.a > 0.95) {
		vec2 world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
		float lift = 1.0 - UV.y;
		float gust = sin(TIME * 1.7 + world.x * 0.03 + world.y * 0.017) + 0.5 * sin(TIME * 3.3 + world.x * 0.07);
		VERTEX.x += gust * strength * 0.9 * lift;
	}
}
"""

static var material: ShaderMaterial = _make(SHADER)
static var still: ShaderMaterial = _make(STILL_SHADER)
static var grass: ShaderMaterial = _make(GRASS_SHADER)


static func _make(code: String) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = code
	var result := ShaderMaterial.new()
	result.shader = shader
	return result


## How hard it blows: about 2 on a fair day, 6 in a storm.
static func set_strength(strength: float) -> void:
	material.set_shader_parameter("strength", strength)
	grass.set_shader_parameter("strength", strength * 0.8)


## How much snow or ash lies on top of things, 0 to 1, and its colour.
static func set_dusting(color: Color, amount: float) -> void:
	for target: ShaderMaterial in [material, still]:
		target.set_shader_parameter("dust_color", color)
		target.set_shader_parameter("dust", amount)
