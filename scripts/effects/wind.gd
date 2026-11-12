class_name Wind
extends RefCounted
## The wind in the trees. Every tree, bush and banner shares one material
## that leans its top to and fro, each a little out of step with the next;
## a storm blows them harder.

const SHADER := """
shader_type canvas_item;
uniform float strength = 2.0;
uniform float reach = 48.0;

void vertex() {
	// The foot stays planted; the higher up, the further it moves.
	float lift = clamp(0.5 - VERTEX.y / (reach * 2.0), 0.0, 1.0);
	vec2 place = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xy;
	float gust = sin(TIME * 1.3 + place.x * 0.021 + place.y * 0.013) + 0.4 * sin(TIME * 2.9 + place.x * 0.05);
	VERTEX.x += gust * strength * lift * lift;
}
"""

static var material: ShaderMaterial = _make()


static func _make() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = SHADER
	var result := ShaderMaterial.new()
	result.shader = shader
	return result


## How hard it blows: about 2 on a fair day, 6 in a storm.
static func set_strength(strength: float) -> void:
	material.set_shader_parameter("strength", strength)
