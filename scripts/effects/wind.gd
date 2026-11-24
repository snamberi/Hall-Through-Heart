class_name Wind
extends RefCounted
## The wind in the trees. Every tree, bush and banner shares one material
## that leans its top to and fro, each a little out of step with the next;
## a storm blows them harder. Grass and flowers bend too, each plant from
## its own foot. In snowfall or ashfall, snow or ash settles along the top
## edges of trees, bushes and props, and wears away after.
##
## Gusts: now and then a stronger breath sweeps across the land as a band,
## leaning everything it passes the same way at once, and moving on (WindFX
## shows it as streaks and blown leaves). Trees sway by whole pixels, row
## by row, so the pixel art never smears.
##
## Broadleaf trees and bushes wear Seasons' materials: the same sway, and
## leaves that turn with the year.

## Settled snow or ash on top edges: lit where a pixel has open air above,
## deeper as more settles (up to three pixels), the cap's underside in a
## cooler shade.
const DUSTING := """
uniform vec4 dust_color : source_color = vec4(1.0);
uniform vec4 dust_shade : source_color = vec4(0.72, 0.8, 0.92, 1.0);
uniform float dust = 0.0;
// How many pixels deep the cap grows as the snow lies deeper.
uniform float dust_reach = 2.4;

// `own` is the picture's alpha here; a1..a3 its alpha one, two and three
// pixels up. (The picture is sampled by the caller: Godot cannot hand its
// TEXTURE on to a function.)
vec4 dusted(vec4 color, float own, float a1, float a2, float a3) {
	if (dust <= 0.0 || own < 0.5) {
		return color;
	}
	float depth = 1.0 + floor(dust * dust_reach);
	float under = a1 < 0.5 ? 1.0 : (a2 < 0.5 ? 2.0 : (a3 < 0.5 ? 3.0 : 9.0));
	if (under > depth) {
		return color;
	}
	vec3 snow = under < 1.5 ? dust_color.rgb : mix(dust_color.rgb, dust_shade.rgb, under > 2.5 ? 0.85 : 0.5);
	return vec4(mix(color.rgb, snow, clamp(dust * 1.4, 0.0, 0.95)), color.a);
}
"""


## The gusts: bands of stronger wind crossing the land along gust_dir.
const GUSTS := """
uniform float strength = 2.0;
uniform float gust_time = 0.0;
uniform vec2 gust_dir = vec2(0.98, 0.18);
uniform float gust_power = 3.0;
const float GUST_SPEED = 300.0;
const float GUST_SPACING = 0.0026;

// 0 most of the time, rising to 1 as a gust passes this point.
float gust_at(vec2 p) {
	float wave = sin((dot(p, gust_dir) - gust_time * GUST_SPEED) * GUST_SPACING);
	return pow(max(wave, 0.0), 6.0);
}
"""

const SHADER := """
shader_type canvas_item;
uniform float reach = 48.0;
""" + DUSTING + GUSTS + """
varying float lift;
varying vec2 place;

void vertex() {
	// The foot stays planted; the higher up, the further it moves.
	lift = clamp(0.5 - VERTEX.y / (reach * 2.0), 0.0, 1.0);
	place = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xy;
}

// How many whole pixels this row leans.
float lean_px() {
	float sway = sin(TIME * 1.3 + place.x * 0.021 + place.y * 0.013) + 0.4 * sin(TIME * 2.9 + place.x * 0.05);
	float gust = gust_at(place);
	float flutter = sin(TIME * 9.0 + place.x * 0.3) * 0.35;
	float lean = (sway * strength * (1.0 - gust * 0.6) + gust * gust_power * (sign(gust_dir.x) + flutter)) * lift * lift;
	// The leaves rustle: a ripple running up through the crown, a pixel
	// either way row by row, livelier in a gust.
	float rustle = sin(TIME * 3.4 - lift * 16.0 + place.x * 0.11) * (0.55 + 0.2 * strength + gust) * smoothstep(0.38, 0.8, lift);
	return clamp(floor(lean + rustle + 0.5), -6.0, 6.0);
}

void fragment() {
	vec2 uv = UV - vec2(lean_px() * TEXTURE_PIXEL_SIZE.x, 0.0);
	vec4 c = texture(TEXTURE, uv) * COLOR;
	COLOR = dusted(c, texture(TEXTURE, uv).a, texture(TEXTURE, uv - vec2(0.0, TEXTURE_PIXEL_SIZE.y)).a, texture(TEXTURE, uv - vec2(0.0, TEXTURE_PIXEL_SIZE.y * 2.0)).a, texture(TEXTURE, uv - vec2(0.0, TEXTURE_PIXEL_SIZE.y * 3.0)).a);
}
"""

## For still things (props, boulders): no sway, only the dusting.
const STILL_SHADER := """
shader_type canvas_item;
""" + DUSTING + """
void fragment() {
	COLOR = dusted(COLOR, texture(TEXTURE, UV).a, texture(TEXTURE, UV - vec2(0.0, TEXTURE_PIXEL_SIZE.y)).a, texture(TEXTURE, UV - vec2(0.0, TEXTURE_PIXEL_SIZE.y * 2.0)).a, texture(TEXTURE, UV - vec2(0.0, TEXTURE_PIXEL_SIZE.y * 3.0)).a);
}
"""

## Roofs: the dusting, and in deep snow icicles hanging from the eaves, a
## few pixels long, pale with a bright tip.
const ROOF_SHADER := """
shader_type canvas_item;
""" + DUSTING + """
uniform vec4 ice : source_color = vec4(0.84, 0.91, 0.96, 1.0);
uniform vec4 ice_shade : source_color = vec4(0.62, 0.76, 0.88, 1.0);

float column_hash(float x) {
	return fract(sin(x * 91.3458) * 47453.5453);
}

void fragment() {
	vec4 c = dusted(COLOR, texture(TEXTURE, UV).a, texture(TEXTURE, UV - vec2(0.0, TEXTURE_PIXEL_SIZE.y)).a, texture(TEXTURE, UV - vec2(0.0, TEXTURE_PIXEL_SIZE.y * 2.0)).a, texture(TEXTURE, UV - vec2(0.0, TEXTURE_PIXEL_SIZE.y * 3.0)).a);
	if (texture(TEXTURE, UV).a < 0.5 && dust > 0.45) {
		// Under an eave: solid roof one and two pixels up.
		float column = floor(UV.x / TEXTURE_PIXEL_SIZE.x);
		float h = column_hash(column);
		float drip = 1.0 + floor(h * 4.0 * (dust - 0.3));
		if (h < 0.42) {
			for (int k = 1; k <= 4; k++) {
				float above = texture(TEXTURE, UV - vec2(0.0, TEXTURE_PIXEL_SIZE.y * float(k))).a;
				float above2 = texture(TEXTURE, UV - vec2(0.0, TEXTURE_PIXEL_SIZE.y * float(k + 1))).a;
				if (above > 0.5 && above2 > 0.5) {
					if (float(k) <= drip) {
						c = vec4(float(k) == drip ? ice.rgb : ice_shade.rgb, 0.92);
					}
					break;
				}
				if (above > 0.5) {
					break;
				}
			}
		}
	}
	COLOR = c;
}
"""

## Ground cover: every plant bends from its own foot (the bottom of its
## picture). Flat decals and shadows (drawn see-through) stay still.
const GRASS_SHADER := """
shader_type canvas_item;
""" + GUSTS + """
void vertex() {
	if (COLOR.a > 0.95) {
		vec2 world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
		float lift = 1.0 - UV.y;
		float sway = sin(TIME * 1.7 + world.x * 0.03 + world.y * 0.017) + 0.5 * sin(TIME * 3.3 + world.x * 0.07);
		float gust = gust_at(world);
		float bend = (sway * strength * 0.9 * (1.0 - gust * 0.5) + gust * gust_power * 1.6 * sign(gust_dir.x)) * lift;
		// Whole pixels only.
		VERTEX.x += floor(bend + 0.5);
	}
}
"""

## Broadleaf trees: the tree's sway and dusting, and leaves that turn with
## the seasons (see Seasons).
const LEAFY_SHADER := """
shader_type canvas_item;
uniform float reach = 48.0;
""" + DUSTING + GUSTS + """
uniform vec4 cuts = vec4(0.235, 0.337, 0.453, 0.6);
uniform float canopy_line = 0.63;
// Only green pixels are leaves (bark, fruit and blossom drawn among them stay).
uniform bool green_only = false;
uniform vec4 modes = vec4(1.0, 0.0, 3.0, 7.0);
uniform int season_a = 0;
uniform int season_b = 1;
uniform float season_blend = 0.0;
uniform vec4 spring_0 : source_color; uniform vec4 spring_1 : source_color; uniform vec4 spring_2 : source_color; uniform vec4 spring_3 : source_color; uniform vec4 spring_4 : source_color;
uniform vec4 summer_0 : source_color; uniform vec4 summer_1 : source_color; uniform vec4 summer_2 : source_color; uniform vec4 summer_3 : source_color; uniform vec4 summer_4 : source_color;
uniform vec4 gold_0 : source_color; uniform vec4 gold_1 : source_color; uniform vec4 gold_2 : source_color; uniform vec4 gold_3 : source_color; uniform vec4 gold_4 : source_color;
uniform vec4 orange_0 : source_color; uniform vec4 orange_1 : source_color; uniform vec4 orange_2 : source_color; uniform vec4 orange_3 : source_color; uniform vec4 orange_4 : source_color;
uniform vec4 red_0 : source_color; uniform vec4 red_1 : source_color; uniform vec4 red_2 : source_color; uniform vec4 red_3 : source_color; uniform vec4 red_4 : source_color;
uniform vec4 rust_0 : source_color; uniform vec4 rust_1 : source_color; uniform vec4 rust_2 : source_color; uniform vec4 rust_3 : source_color; uniform vec4 rust_4 : source_color;
uniform vec4 twig_0 : source_color; uniform vec4 twig_1 : source_color; uniform vec4 twig_2 : source_color; uniform vec4 twig_3 : source_color; uniform vec4 twig_4 : source_color;
uniform vec4 blossom_0 : source_color; uniform vec4 blossom_1 : source_color;
varying float lift;
varying vec2 place;

void vertex() {
	lift = clamp(0.5 - VERTEX.y / (reach * 2.0), 0.0, 1.0);
	place = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xy;
}

float lean_px() {
	float sway = sin(TIME * 1.3 + place.x * 0.021 + place.y * 0.013) + 0.4 * sin(TIME * 2.9 + place.x * 0.05);
	float gust = gust_at(place);
	float flutter = sin(TIME * 9.0 + place.x * 0.3) * 0.35;
	float lean = (sway * strength * (1.0 - gust * 0.6) + gust * gust_power * (sign(gust_dir.x) + flutter)) * lift * lift;
	// The leaves rustle: a ripple running up through the crown, a pixel
	// either way row by row, livelier in a gust.
	float rustle = sin(TIME * 3.4 - lift * 16.0 + place.x * 0.11) * (0.55 + 0.2 * strength + gust) * smoothstep(0.38, 0.8, lift);
	return clamp(floor(lean + rustle + 0.5), -6.0, 6.0);
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec3 pick(int i, vec4 a, vec4 b, vec4 c, vec4 d, vec4 e) {
	return i == 0 ? a.rgb : i == 1 ? b.rgb : i == 2 ? c.rgb : i == 3 ? d.rgb : e.rgb;
}

// The leaf's colour for a mode; alpha 0 where a bare tree has no twig.
vec4 turned(int mode, int i, vec4 original, float tree, vec2 texel) {
	if (mode == 0) {
		return original;
	}
	if (mode == 1) {
		// Spring: fresh green, now and then a little cluster of blossom.
		float b = hash12(floor(texel / 2.0) + tree * 37.0);
		if (b > 0.94 && i >= 2) {
			return vec4(b > 0.975 ? blossom_1.rgb : blossom_0.rgb, original.a);
		}
		return vec4(pick(i, spring_0, spring_1, spring_2, spring_3, spring_4), original.a);
	}
	if (mode == 2) {
		return vec4(pick(i, summer_0, summer_1, summer_2, summer_3, summer_4), original.a);
	}
	if (mode == 3) {
		// Autumn: each tree its own colour.
		float which = fract(tree * 7.13);
		if (which < 0.4) {
			return vec4(pick(i, gold_0, gold_1, gold_2, gold_3, gold_4), original.a);
		} else if (which < 0.75) {
			return vec4(pick(i, orange_0, orange_1, orange_2, orange_3, orange_4), original.a);
		}
		return vec4(pick(i, red_0, red_1, red_2, red_3, red_4), original.a);
	}
	if (mode == 4) {
		return vec4(pick(i, orange_0, orange_1, orange_2, orange_3, orange_4), original.a);
	}
	if (mode == 5) {
		return vec4(pick(i, red_0, red_1, red_2, red_3, red_4), original.a);
	}
	if (mode == 6) {
		return vec4(pick(i, rust_0, rust_1, rust_2, rust_3, rust_4), original.a);
	}
	// Bare: a thin tangle of twigs where the crown was, a few dry leaves.
	float twig = hash12(floor(texel / vec2(2.0, 3.0)) + tree * 11.0);
	float fine = hash12(texel + tree * 5.0);
	if (twig < 0.42 || fine < 0.25) {
		if (fine > 0.97) {
			return vec4(rust_2.rgb, original.a);
		}
		return vec4(pick(min(i, 3), twig_0, twig_1, twig_2, twig_3, twig_4), original.a);
	}
	return vec4(0.0);
}

int mode_for(int season) {
	return int(season == 0 ? modes.x : season == 1 ? modes.y : season == 2 ? modes.z : modes.w);
}

void fragment() {
	vec2 uv = UV - vec2(lean_px() * TEXTURE_PIXEL_SIZE.x, 0.0);
	vec4 picture = texture(TEXTURE, uv);
	vec4 c = picture * COLOR;
	vec2 texel = floor(uv / TEXTURE_PIXEL_SIZE);
	float in_frame = fract(uv.y);
	bool leafy = !green_only || (picture.g > picture.r * 1.05 && picture.g >= picture.b * 0.98);
	if (picture.a > 0.5 && in_frame < canopy_line && leafy) {
		vec3 rgb = picture.rgb;
		float l = dot(rgb, vec3(0.299, 0.587, 0.114));
		float hi = max(rgb.r, max(rgb.g, rgb.b));
		float lo = min(rgb.r, min(rgb.g, rgb.b));
		float saturation = hi > 0.0 ? (hi - lo) / hi : 0.0;
		// Berries stay as they are.
		bool berry = saturation > 0.6 && rgb.r > rgb.g * 2.5 && rgb.r > rgb.b * 2.0 && modes.y == 0.0 && modes.z == 6.0;
		bool outline = hi < 0.14;
		if (!berry) {
			int i = l < cuts.x ? 0 : l < cuts.y ? 1 : l < cuts.z ? 2 : l < cuts.w ? 3 : 4;
			float tree = hash12(floor(place / 4.0));
			bool next = hash12(floor(texel / 2.0) + tree * 19.0) < season_blend;
			int mode = mode_for(next ? season_b : season_a);
			if (!outline || mode == 7) {
				vec4 leaf = turned(mode, outline ? 0 : i, picture, tree, texel);
				c = vec4(leaf.rgb * COLOR.rgb, leaf.a * COLOR.a);
			}
		}
	}
	COLOR = dusted(c, texture(TEXTURE, uv).a, texture(TEXTURE, uv - vec2(0.0, TEXTURE_PIXEL_SIZE.y)).a, texture(TEXTURE, uv - vec2(0.0, TEXTURE_PIXEL_SIZE.y * 2.0)).a, texture(TEXTURE, uv - vec2(0.0, TEXTURE_PIXEL_SIZE.y * 3.0)).a);
}
"""

static var material: ShaderMaterial = _make(SHADER)
static var still: ShaderMaterial = _make(STILL_SHADER)
static var roof: ShaderMaterial = _roof()
static var grass: ShaderMaterial = _make(GRASS_SHADER)
static var _strength := 2.0
static var _dust := 0.0
static var _dust_color := Color.WHITE
static var _gust := [0.0, Vector2(0.98, 0.18), 3.0]


static func _roof() -> ShaderMaterial:
	var made := _make(ROOF_SHADER)
	# Roofs hold a deep cap of snow.
	made.set_shader_parameter("dust_reach", 4.5)
	return made


static func _make(code: String) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = code
	var result := ShaderMaterial.new()
	result.shader = shader
	return result


## Every material that sways or settles snow.
static func _swaying() -> Array:
	var all: Array = [material]
	all.append_array(Seasons.all_materials())
	return all


## How hard it blows: about 2 on a fair day, 6 in a storm.
static func set_strength(strength: float) -> void:
	# Shaders off (graphics settings): nothing sways.
	if GameSettings.shader_level() == 0:
		strength = 0.0
	_strength = strength
	for target: ShaderMaterial in _swaying():
		target.set_shader_parameter("strength", strength)
	grass.set_shader_parameter("strength", strength * 0.8)


## How much snow or ash lies on top of things, 0 to 1, and its colour.
static func set_dusting(color: Color, amount: float) -> void:
	_dust = amount
	_dust_color = color
	var targets := _swaying()
	targets.append(still)
	targets.append(roof)
	for target: ShaderMaterial in targets:
		target.set_shader_parameter("dust_color", color)
		target.set_shader_parameter("dust", amount)


## Where the gusts are: their clock, the way they blow and how hard.
static func set_gust(time: float, direction: Vector2, power: float) -> void:
	if GameSettings.shader_level() == 0:
		power = 0.0
	_gust = [time, direction, power]
	var targets := _swaying()
	targets.append(grass)
	for target: ShaderMaterial in targets:
		target.set_shader_parameter("gust_time", time)
		target.set_shader_parameter("gust_dir", direction)
		target.set_shader_parameter("gust_power", power)


## Gives a newly made material the wind and snow as they are now.
static func copy_state(target: ShaderMaterial) -> void:
	target.set_shader_parameter("strength", _strength)
	target.set_shader_parameter("dust_color", _dust_color)
	target.set_shader_parameter("dust", _dust)
	target.set_shader_parameter("gust_time", _gust[0])
	target.set_shader_parameter("gust_dir", _gust[1])
	target.set_shader_parameter("gust_power", _gust[2])


## How strongly a gust blows at a point now (0 most of the time, 1 at its
## height), the same reckoning the shaders use.
static func gust_at(point: Vector2) -> float:
	var direction: Vector2 = _gust[1]
	var wave := sin((point.dot(direction) - float(_gust[0]) * 300.0) * 0.0026)
	return pow(maxf(wave, 0.0), 6.0)
