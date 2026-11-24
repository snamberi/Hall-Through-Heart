extends ColorRect
## The light's mood through the day, over the world (not the HUD): golden
## mornings with rosy shadows, clear colour at noon, amber dusks with blue-
## violet shadows, and moonlit nights, the colour drained toward silver and
## the shadows deepened blue. Rain and storms grey it, a blood moon reddens
## the dark. Works on each pixel's own colour, so the art stays crisp.
## Atmosphere puts it first on its layer (under the fog and mist). Loaded
## by path.

const SHADER := """
shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform vec3 shadow_tint = vec3(0.0);
uniform vec3 high_tint = vec3(0.0);
uniform float saturation = 1.0;
uniform float contrast = 1.0;
uniform float strength = 0.0;

void fragment() {
	vec3 c = texture(screen, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 g = mix(vec3(l), c, saturation);
	g = (g - 0.5) * contrast + 0.5;
	float shadows = 1.0 - smoothstep(0.0, 0.55, l);
	float highs = smoothstep(0.35, 1.0, l);
	g += shadow_tint * shadows + high_tint * highs;
	COLOR = vec4(mix(c, clamp(g, 0.0, 1.0), strength), 1.0);
}
"""

## Through the day (0 = midnight, 0.5 = noon): saturation, contrast, the
## tint added to the shadows, the tint added to the highlights.
const KEYS: Array[Array] = [
	[0.0, 0.7, 1.08, Vector3(-0.02, -0.005, 0.05), Vector3(-0.01, 0.02, 0.06)],
	[0.2, 0.72, 1.08, Vector3(-0.02, -0.005, 0.05), Vector3(-0.01, 0.02, 0.06)],
	[0.27, 1.04, 1.02, Vector3(0.04, 0.0, 0.035), Vector3(0.08, 0.045, -0.02)],
	[0.36, 1.06, 1.02, Vector3(0.0, 0.0, 0.015), Vector3(0.035, 0.02, 0.0)],
	[0.5, 1.08, 1.03, Vector3.ZERO, Vector3(0.01, 0.01, 0.0)],
	[0.66, 1.07, 1.03, Vector3(0.0, 0.0, 0.01), Vector3(0.035, 0.018, -0.01)],
	[0.77, 1.05, 1.04, Vector3(0.0, -0.01, 0.06), Vector3(0.09, 0.035, -0.035)],
	[0.86, 0.72, 1.08, Vector3(-0.02, -0.005, 0.05), Vector3(-0.01, 0.02, 0.06)],
	[1.0, 0.7, 1.08, Vector3(-0.02, -0.005, 0.05), Vector3(-0.01, 0.02, 0.06)],
]

var _material: ShaderMaterial


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var shader := Shader.new()
	shader.code = SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader
	material = _material


## The grade for a time of day, as [saturation, contrast, shadow tint,
## highlight tint].
static func grade_at(time: float) -> Array:
	time = fposmod(time, 1.0)
	for i in KEYS.size() - 1:
		var a: Array = KEYS[i]
		var b: Array = KEYS[i + 1]
		if time <= float(b[0]):
			var t := smoothstep(float(a[0]), float(b[0]), time)
			return [lerpf(a[1], b[1], t), lerpf(a[2], b[2], t), (a[3] as Vector3).lerp(b[3], t), (a[4] as Vector3).lerp(b[4], t)]
	var last: Array = KEYS[-1]
	return [last[1], last[2], last[3], last[4]]


## Sets the grade for now. `amount` 0 turns it off (indoors, low graphics).
func apply(time: float, amount: float, weather: String, blood_moon: bool) -> void:
	visible = amount > 0.0
	if not visible:
		return
	var grade := grade_at(time)
	var saturation: float = grade[0]
	var shadow: Vector3 = grade[2]
	if weather in ["Rain", "Thunderstorm", "Ash storm", "Ashfall"]:
		saturation *= 0.84
	if blood_moon and (time < 0.22 or time > 0.84):
		shadow += Vector3(0.06, -0.02, -0.03)
	_material.set_shader_parameter("saturation", saturation)
	_material.set_shader_parameter("contrast", grade[1])
	_material.set_shader_parameter("shadow_tint", shadow)
	_material.set_shader_parameter("high_tint", grade[3])
	_material.set_shader_parameter("strength", amount)
