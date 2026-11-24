extends Control
## The title logo, alive, at three screen pixels to each of its own:
## - it comes in through a dither, HALL THROUGH first, then HEART, and the
##   underline draws out both ways from the gem;
## - the heart in THROUGH beats, lub-dub, swelling a pixel each time;
## - now and then a glint of light runs across the letters' faces;
## - the gem under HEART sparkles.
## Every effect works in whole logo pixels. (Loaded by path.)

const LOGO: Texture2D = preload("res://assets/ui/logo.png")
const BEAT: Texture2D = preload("res://assets/ui/logo_heart_beat.png")
const DATA := preload("res://scripts/ui/logo_data.gd")
const SCALE := 3
## Seconds for the letters to come in, then for the underline to draw out.
const REVEAL := 1.1
const LINE := 0.5
const BEAT_PERIOD := 1.4
const GLINT_EVERY := 5.0
const SPARKLE_EVERY := 3.3

const SHADER := """
shader_type canvas_item;
uniform vec2 logo_size = vec2(252.0, 92.0);
uniform float reveal = 0.0;
uniform float line = 0.0;
uniform float glint = -100.0;
uniform float split_row = 33.0;
uniform float line_row = 77.0;
uniform float gem_x = 126.0;

float bayer(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int m[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[x + y * 4]) + 0.5) / 16.0;
}

void fragment() {
	vec2 texel = floor(UV * logo_size);
	vec4 c = texture(TEXTURE, UV);
	// Coming in: the top line, then HEART, through an ordered dither.
	float shown = texel.y < split_row ? clamp(reveal * 2.0, 0.0, 1.0) : clamp(reveal * 2.0 - 0.7, 0.0, 1.0);
	if (texel.y >= line_row) {
		// The underline and gem draw out from the middle.
		shown = step(abs(texel.x - gem_x), line * 130.0 + 3.0) * step(0.001, line);
	}
	if (bayer(texel) >= shown) {
		c.a = 0.0;
	}
	// A glint: a slanting band of light two pixels wide over the faces.
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	bool face = lum > 0.55 && abs(c.r - c.g) < 0.25 && c.a > 0.5;
	float d = texel.x + texel.y * 0.6 - glint;
	if (face && d >= 0.0 && d < 2.0) {
		c.rgb = vec3(1.0, 0.97, 0.86);
	} else if (face && d >= 2.0 && d < 3.0) {
		c.rgb = mix(c.rgb, vec3(1.0, 0.95, 0.8), 0.6);
	}
	COLOR = c;
}
"""

var _time := 0.0
var _overlay: Control


func _ready() -> void:
	custom_minimum_size = LOGO.get_size() * SCALE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = SHADER
	var look := ShaderMaterial.new()
	look.shader = shader
	look.set_shader_parameter("logo_size", LOGO.get_size())
	look.set_shader_parameter("split_row", float(DATA.SPLIT_ROW))
	look.set_shader_parameter("line_row", float(DATA.LINE_ROW))
	look.set_shader_parameter("gem_x", float(DATA.GEM_AT.x))
	material = look
	# The beat and the sparkle are drawn over it, without its shader.
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)


func _process(delta: float) -> void:
	_time += delta
	var look := material as ShaderMaterial
	look.set_shader_parameter("reveal", clampf(_time / REVEAL, 0.0, 1.0))
	look.set_shader_parameter("line", clampf((_time - REVEAL) / LINE, 0.0, 1.0))
	# The glint crosses the logo in a second, every few seconds.
	var since := fposmod(_time - REVEAL - LINE, GLINT_EVERY)
	look.set_shader_parameter("glint", floorf(since * 320.0) - 60.0 if _time > REVEAL + LINE and since < 1.0 else -1000.0)
	queue_redraw()
	_overlay.queue_redraw()


func _draw() -> void:
	draw_texture_rect(LOGO, Rect2(Vector2.ZERO, LOGO.get_size() * SCALE), false)


func _draw_overlay() -> void:
	if _time < REVEAL:
		return
	# Lub-dub: two quick beats, then rest.
	var phase := fposmod(_time, BEAT_PERIOD)
	if phase < 0.11 or (phase > 0.22 and phase < 0.31):
		_overlay.draw_texture_rect(BEAT, Rect2(Vector2(DATA.HEART_AT) * SCALE, BEAT.get_size() * SCALE), false)
	# The gem sparkles: a cross that opens and closes.
	if _time > REVEAL + LINE:
		var s := fposmod(_time, SPARKLE_EVERY)
		if s < 0.36:
			var arm := 1 if s < 0.12 or s > 0.24 else 2
			var at := Vector2(DATA.GEM_AT) + Vector2(1, -2)
			for k in range(1, arm + 1):
				for way: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
					_px(at + way * k, Color(1.0, 0.85, 0.9, 1.0 if k == 1 else 0.7))
			_px(at, Color.WHITE)


func _px(at: Vector2, colour: Color) -> void:
	_overlay.draw_rect(Rect2(at * SCALE, Vector2(SCALE, SCALE)), colour)
