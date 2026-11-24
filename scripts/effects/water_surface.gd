class_name WaterSurface
extends RefCounted
## What moves on water and wet ground, drawn in one pass over the area
## round the player (GroundFX lays it down), every pixel on the same 2px
## grid as the terrain art and dithered rather than blurred:
##
##   Shores: a swell rolls in every few seconds, rises to a crest, breaks
##   into foam on the bank and washes up in a thin film, then draws back,
##   leaving a lace of foam that thins out; a dotted line of foam and a few
##   bubbles stay along every bank between waves. The waves arrive along a
##   coast a little after one another, so they roll down it.
##
##   Open water holds the sky: by day the clouds drift across it (paler
##   shapes dithered at their edges); at night the stars come out in it,
##   twinkling, and the moon lays a broken path of light down the water.
##
##   Wet ground: in the rain, puddles gather in the hollows of grass, mud,
##   roads and rock, lit along their far lip and dark along the near one,
##   with rings where the drops land; after the rain they shrink, leaving
##   dark damp earth that dries last.

## The look of foam, swell and sky in the water (Hall Through Heart's
## navy shores, lifted to sea-glass at the foam).
const FOAM_HI := Color("dcecf0")
const FOAM_MID := Color("9fc3d3")
const SWELL := Color("4f7894")
const FILM := Color("78a0b4")
const CLOUD := Color("a9c0cf")
const STAR := Color("eef2ff")
const MOON := Color("f6eccc")
const BLOOD_MOON := Color("f08a78")
const PUDDLE := Color("4a6276")
const PUDDLE_LIP := Color("8eaabb")
const PUDDLE_DEEP := Color("27333f")
const RIPPLE := Color("a6bccb")
## The sun's light playing on a shallow bed, and the sand and pebbles there.
const CAUSTIC := Color("cfe8e0")
const BED := Color("8a7a5a")

const SHADER := """
shader_type canvas_item;
// TEXTURE is the chunk's own mask (one texel a tile, two tiles of border):
// red is land, green is ground that holds puddles, blue is shallow water,
// alpha is a river's flow (its angle; zero where no river runs).
uniform sampler2D noise : repeat_enable, filter_linear;
uniform float wave_time = 0.0;
uniform float daylight = 1.0;
// Undoes the night's tint for the stars and the moon, which shine.
uniform float star_boost = 1.0;
uniform float moon_x = 0.0;
uniform vec2 cloud_drift = vec2(0.0);
uniform float clear_sky = 1.0;
uniform float wet = 0.0;
uniform float damp = 0.0;
uniform float rain = 0.0;
uniform vec4 foam_hi : source_color;
uniform vec4 foam_mid : source_color;
uniform vec4 swell : source_color;
uniform vec4 film : source_color;
uniform vec4 cloud : source_color;
uniform vec4 star : source_color;
uniform vec4 moon : source_color;
uniform vec4 puddle : source_color;
uniform vec4 puddle_lip : source_color;
uniform vec4 puddle_deep : source_color;
uniform vec4 ripple : source_color;
uniform vec4 caustic : source_color;
uniform vec4 bed : source_color;
varying vec2 world;

const float TILE = 44.0;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float bayer2(vec2 a) {
	a = floor(a);
	return fract(a.x / 2.0 + a.y * a.y * 0.75);
}

// 0..1, the 4x4 ordered-dither threshold for a pixel.
float bayer4(vec2 a) {
	return bayer2(0.5 * a) * 0.25 + bayer2(a);
}

vec4 over(vec4 base, vec4 top) {
	float a = top.a + base.a * (1.0 - top.a);
	if (a <= 0.0001) {
		return vec4(0.0);
	}
	return vec4((top.rgb * top.a + base.rgb * base.a * (1.0 - top.a)) / a, a);
}

// Pools: some cells of the ground have a hollow; how full it is (`level`)
// decides how far it spreads. Above zero is inside a pool, and how deep.
// They are wide and shallow (seen from above, at a slant), their edges
// wobbling a little, and each starts filling at its own point in the rain.
float pool(vec2 p, float level) {
	vec2 g = floor(p / 64.0);
	float best = -1.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 c = g + vec2(float(i), float(j));
			if (hash12(c * 1.37 + 11.0) > 0.5) {
				continue;
			}
			vec2 centre = (c + 0.2 + 0.6 * vec2(hash12(c + 3.1), hash12(c + 8.7))) * 64.0;
			vec2 radius = vec2(11.0 + 15.0 * hash12(c + 5.3), 6.0 + 6.0 * hash12(c + 9.9));
			radius *= clamp((level - hash12(c + 2.2) * 0.45) / 0.55, 0.0, 1.0);
			if (radius.x < 3.0) {
				continue;
			}
			vec2 q = (p - centre) / radius;
			float wobble = (texture(noise, p / 38.0 + c * 0.13).r - 0.5) * 0.4;
			best = max(best, 1.0 - length(q) + wobble);
		}
	}
	return best;
}

float sky_clouds(vec2 px) {
	return texture(noise, (px + cloud_drift) / 540.0).r * 0.7 + texture(noise, (px + cloud_drift * 1.35) / 170.0 + vec2(0.5)).r * 0.3;
}

void fragment() {
	vec2 cell = floor(world / 2.0);
	vec2 px = cell * 2.0 + 1.0;
	vec2 per_world = TEXTURE_PIXEL_SIZE / TILE;
	vec2 here = UV + (px - world) * per_world;
	vec3 mask3 = texture(TEXTURE, here).rgb;
	vec2 mask = mask3.rg;
	// The tile's own texel, exactly: land is land, water is water.
	vec4 own4 = texture(TEXTURE, (floor(here / TEXTURE_PIXEL_SIZE) + 0.5) * TEXTURE_PIXEL_SIZE);
	vec3 own3 = own4.rgb;
	vec2 own = own3.rg;
	bool river = own4.a > 0.02;
	// How far out from the bank (in world units; below zero is land). The
	// mask grades across one tile; past that, the land a tile further on
	// grades the next.
	float d = (0.5 - mask.r) * TILE;
	if (mask.r < 0.002) {
		float a = texture(TEXTURE, here + vec2(TILE, 0.0) * per_world).r;
		float b = texture(TEXTURE, here - vec2(TILE, 0.0) * per_world).r;
		float c = texture(TEXTURE, here + vec2(0.0, TILE) * per_world).r;
		float e = texture(TEXTURE, here - vec2(0.0, TILE) * per_world).r;
		d = TILE * 0.5 + (1.0 - max(max(a, b), max(c, e))) * TILE;
	}
	float coast = texture(noise, px / 300.0).r;
	d += (coast - 0.5) * 6.0;
	d = own.r > 0.5 ? -1.0 : max(d, 1.0);
	float dither = bayer4(cell);
	vec4 col = vec4(0.0);
	float night = 1.0 - daylight;
	if (d > 0.0) {
		// --- depth: where the shallows shelve off into deep water a dark
		// band runs along the drop; on the shallow bed itself, sand and
		// pebbles show through and the sun's light plays over them in a
		// moving net (caustics), in whole pixels and only by day.
		float shallow = mask3.b;
		if (own3.b < 0.5 && shallow > 0.12) {
			float band = (shallow - 0.12) / 0.38;
			if (band > 0.55 || dither < band / 0.55) {
				col = over(col, vec4(0.0, 0.02, 0.06, 0.2));
			}
		} else if (own3.b > 0.5) {
			float grit = hash12(cell + 3.0);
			if (grit > 0.965 && d > 6.0) {
				col = over(col, vec4(grit > 0.99 ? caustic.rgb : bed.rgb, 0.2));
			}
			// The net shows in drifting patches where the sun gets through,
			// thin and broken, never as a pattern over the whole bed.
			float patch = texture(noise, px / 220.0 + vec2(wave_time * 0.004, wave_time * 0.002)).r;
			if (daylight > 0.1 && d > 6.0 && patch > 0.52) {
				vec2 q = px / 34.0;
				float a = abs(sin(q.x * 2.1 + wave_time * 0.7 + sin(q.y * 1.7 + wave_time * 0.5) * 1.5));
				float b = abs(sin(q.y * 2.4 - wave_time * 0.6 + sin(q.x * 1.3 - wave_time * 0.4) * 1.7));
				float net = min(a, b);
				float edge = smoothstep(0.52, 0.66, patch);
				if (net < 0.05 && dither < edge) {
					col = over(col, vec4(caustic.rgb, (0.16 * clear_sky + 0.04) * daylight));
				}
			}
		}
		// --- a river's current: short streaks of lighter water running
		// downstream in lanes, each lane at its own pace, with a fleck of
		// foam at the head of some.
		if (river) {
			float ang = (own4.a - 0.04) / 0.96 * 6.2831853;
			vec2 dir = vec2(cos(ang), sin(ang));
			vec2 perp = vec2(-dir.y, dir.x);
			float u = dot(px, dir);
			float v = dot(px, perp);
			float lane = floor(v / 6.0);
			float h = hash12(vec2(lane, 7.0));
			float dash = fract((u - wave_time * (18.0 + 12.0 * h)) / (28.0 + 16.0 * h) + h);
			if (mod(v, 6.0) < 2.0) {
				if (dash < 0.14) {
					col = over(col, vec4(swell.rgb, 0.4));
				} else if (dash < 0.18 && h > 0.5) {
					col = over(col, vec4(foam_mid.rgb, 0.45));
				}
			}
		}
		// --- the sky in the water
		if (d > 10.0) {
			if (clear_sky > 0.0 && daylight > 0.05) {
				float amount = sky_clouds(px) - 0.6;
				if (amount > 0.0 && (amount > 0.12 || dither < amount / 0.12)) {
					col = over(col, vec4(cloud.rgb, 0.05 * daylight * clear_sky));
				}
			}
			if (night > 0.2 && clear_sky > 0.0) {
				float h = hash12(cell);
				float twinkle = 0.55 + 0.45 * sin(wave_time * 2.1 + h * 97.0);
				float strength = smoothstep(0.2, 0.7, night) * clear_sky;
				if (h > 0.9956) {
					col = over(col, vec4(star.rgb * star_boost, 0.85 * strength * twinkle));
				} else {
					// The arms of the few bright stars.
					float arms = 0.0;
					arms = max(arms, step(0.9993, hash12(cell + vec2(1.0, 0.0))));
					arms = max(arms, step(0.9993, hash12(cell - vec2(1.0, 0.0))));
					arms = max(arms, step(0.9993, hash12(cell + vec2(0.0, 1.0))));
					arms = max(arms, step(0.9993, hash12(cell - vec2(0.0, 1.0))));
					col = over(col, vec4(star.rgb * star_boost, 0.45 * arms * strength * twinkle));
				}
				// The moon's road: broken bars of light shivering on the water.
				float dx = abs(px.x - moon_x);
				float row = hash12(vec2(cell.y * 1.7, floor(wave_time * 1.6 + cell.y * 0.13)));
				float width = 8.0 + 22.0 * texture(noise, vec2(cell.y * 0.031, wave_time * 0.02)).r;
				if (row > 0.38 && dx < width * (0.35 + 0.65 * row)) {
					float fade = 1.0 - dx / width;
					if (fade > 0.35 || dither < fade / 0.35) {
						col = over(col, vec4(moon.rgb * star_boost, 0.42 * strength * (0.5 + 0.5 * fade)));
					}
				}
			}
		}
		// --- the open water's own movement: short crests of light that
		// drift with the current and wink in and out, a dark trough under
		// each, whole pixels only; fewer far out, more where it is shallow.
		if (d > 6.0) {
			float drift = wave_time * 0.32;
			vec2 lane = vec2(floor(cell.x / 10.0 + drift + floor(cell.y / 6.0) * 0.37), floor(cell.y / 6.0));
			float h = hash12(lane);
			float busy = d > 60.0 ? 0.8 : 0.68;
			if (h > busy) {
				float lx = floor(fract(cell.x / 10.0 + drift + floor(cell.y / 6.0) * 0.37) * 10.0);
				float ly = mod(cell.y, 6.0);
				float life = 0.5 + 0.5 * sin(wave_time * 1.15 + h * 53.0);
				float len = 2.0 + floor(fract(h * 13.7) * 4.0);
				if (life > 0.3 && lx >= 3.0 && lx < 3.0 + len) {
					if (ly < 1.0) {
						col = over(col, vec4(swell.rgb, (0.26 + 0.2 * life) * (0.45 + 0.55 * daylight)));
					} else if (ly < 2.0 && lx >= 4.0) {
						col = over(col, vec4(0.0, 0.02, 0.07, 0.16 * life));
					}
				}
			}
		}
		// --- the waves. The bank's own ragged edge lies over all this, so
		// the foam always meets the shore just where it is drawn. Foam comes
		// in clumps and lace (two drifting noises), never in a pattern.
		// Broad noises only: foam lies in clumps and strands, never in
		// single loose pixels (those read as glitches against the bank).
		float lace = texture(noise, px / 70.0 + vec2(wave_time * 0.006, wave_time * 0.003)).r * 0.65
			+ texture(noise, px / 38.0 - vec2(wave_time * 0.005, 0.0)).r * 0.35;
		float along = coast * 0.7 + (px.x * 0.55 + px.y) * 0.0011;
		float phase = fract(wave_time / 5.5 + along);
		float arrive = clamp(phase / 0.55, 0.0, 1.0);
		float front = mix(44.0, -2.0, 1.0 - (1.0 - arrive) * (1.0 - arrive));
		float back_t = clamp((phase - 0.55) / 0.45, 0.0, 1.0);
		float left = 1.0 - back_t;
		float rising = smoothstep(0.0, 0.16, phase);
		if (river) {
			// A river's banks take no swell, only the line of foam below.
		} else if (phase < 0.6) {
			// The swell: a lighter body with a crest at its leading edge,
			// broken where the lace is thin.
			if (d >= front + 2.0 && d < front + 8.0 && (d < front + 6.0 || dither < 0.5)) {
				col = over(col, vec4(swell.rgb, 0.16 * rising));
			}
			if (d >= front && d < front + 2.0 && lace > 0.36 - phase * 0.3) {
				col = over(col, vec4(phase > 0.4 ? foam_hi.rgb : foam_mid.rgb, (0.45 + 0.4 * arrive) * rising));
			}
			// Where it breaks: white water tumbling in behind the crest.
			if (phase > 0.42 && d < front && lace > 0.62 - (phase - 0.42) * 2.2) {
				col = over(col, vec4(foam_hi.rgb, 0.65));
			}
		} else {
			// The wash drawing back: a thin film, its edge a line of lace.
			float wash = mix(4.0, 24.0, back_t);
			if (d < wash) {
				col = over(col, vec4(film.rgb, 0.24 * left));
			}
			if (d >= wash - 2.0 && d < wash + 2.0 && lace > 0.42 + back_t * 0.18) {
				col = over(col, vec4(lace > 0.56 ? foam_hi.rgb : foam_mid.rgb, 0.8 * left));
			}
		}
		// Foam gathered against the bank, breaking into lace further out;
		// for a while after each wave it spreads a little further.
		float spread = smoothstep(0.48, 0.62, phase) * left;
		float reach = 18.0 + 10.0 * spread;
		if (d < 4.0) {
			// The unbroken line of foam where water meets the bank.
			col = over(col, vec4(d < 2.0 ? foam_hi.rgb : foam_mid.rgb, 0.8));
		} else {
			float threshold = 0.38 + (d / reach) * 0.32;
			if (d < reach && lace > threshold) {
				col = over(col, vec4(lace > threshold + 0.06 ? foam_hi.rgb : foam_mid.rgb, 0.66));
			}
		}
	} else if ((wet > 0.002 || damp > 0.002) && mask.g > 0.8 && own.g > 0.5) {
		// --- puddles in the hollows of the ground
		float inside = pool(px, wet);
		if (inside > 0.0) {
			bool open_above = pool(px - vec2(0.0, 2.0), wet) <= 0.0;
			bool open_below = pool(px + vec2(0.0, 2.0), wet) <= 0.0;
			vec3 c = puddle.rgb;
			if (open_above) {
				// The far lip, catching the light.
				c = puddle_lip.rgb;
			} else if (open_below) {
				c = puddle_deep.rgb;
			} else if (clear_sky > 0.0 && sky_clouds(px) > 0.6) {
				// The sky in the puddle, as in open water.
				c = mix(c, cloud.rgb, 0.35 * daylight);
			}
			col = vec4(c, 0.88);
			// Rings where raindrops land.
			if (rain > 0.0 && !open_above && !open_below) {
				vec2 grid = floor(cell / 5.0);
				float h = hash12(grid);
				vec2 centre = grid * 5.0 + 2.5 + (vec2(h, hash12(grid + 7.0)) - 0.5) * 2.0;
				float r = fract(wave_time * 1.25 + h) * 4.5;
				float dist = length((cell - centre) * vec2(1.0, 1.6));
				if (r > 0.7 && abs(dist - r) < 0.55) {
					col = vec4(ripple.rgb, 0.88);
				}
			}
		} else if (wet > 0.05 && inside > -0.14) {
			// The wet rim round a pool.
			col = vec4(0.04, 0.03, 0.03, 0.34);
		} else if (damp > 0.05 && pool(px, damp) > -0.1 && (pool(px, damp) > -0.04 || dither < 0.5)) {
			// Dark earth where a puddle was, drying last.
			col = vec4(0.06, 0.035, 0.02, 0.3);
		}
	}
	COLOR = col;
}
"""


## The one material every chunk's surface shares (GroundFX moves its clock).
static var material: ShaderMaterial
## Ground that holds puddles in the rain (not sand, snow or salt, which
## drink it or freeze it).
const PUDDLE_GROUND: Array[int] = [TerrainTiles.Type.DARK_GRASS, TerrainTiles.Type.DEAD_GRASS, TerrainTiles.Type.MUD, TerrainTiles.Type.BOG,
	TerrainTiles.Type.PATH, TerrainTiles.Type.TRACK, TerrainTiles.Type.ASH, TerrainTiles.Type.THORN, TerrainTiles.Type.CRIMSON, TerrainTiles.Type.FUNGAL, TerrainTiles.Type.ROCK]
const BORDER := 2


static func shared_material() -> ShaderMaterial:
	if material == null:
		var noise := FastNoiseLite.new()
		noise.frequency = 0.02
		noise.fractal_octaves = 3
		var texture := NoiseTexture2D.new()
		texture.noise = noise
		texture.seamless = true
		texture.width = 256
		texture.height = 256
		var shader := Shader.new()
		shader.code = SHADER
		material = ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("noise", texture)
		for pair: Array in [["foam_hi", FOAM_HI], ["foam_mid", FOAM_MID], ["swell", SWELL], ["film", FILM], ["cloud", CLOUD], ["star", STAR],
				["moon", MOON], ["puddle", PUDDLE], ["puddle_lip", PUDDLE_LIP], ["puddle_deep", PUDDLE_DEEP], ["ripple", RIPPLE],
				["caustic", CAUSTIC], ["bed", BED]]:
			material.set_shader_parameter(pair[0], pair[1])
	return material


## The surface for one chunk: a node drawing the chunk's mask through the
## shared material. Goes first among the chunk's children, so the fringes
## of the land are drawn over it. `type_at` gives the terrain of a tile.
static func chunk_surface(origin: Vector2i, size: int, type_at: Callable, flow_at: Callable = Callable()) -> Node2D:
	var span := size + BORDER * 2
	var image := Image.create(span, span, false, Image.FORMAT_RGBA8)
	var any_water := false
	var any_hollow := false
	for y in span:
		for x in span:
			var type: int = type_at.call(origin + Vector2i(x - BORDER, y - BORDER))
			var land := not TerrainTiles.is_water(type)
			any_water = any_water or not land
			var hollow := type in PUDDLE_GROUND
			any_hollow = any_hollow or hollow
			var flow := 0.0
			if not land and flow_at.is_valid():
				var along: Vector2 = flow_at.call(origin + Vector2i(x - BORDER, y - BORDER))
				if along != Vector2.ZERO:
					flow = 0.04 + fposmod(along.angle(), TAU) / TAU * 0.96
			image.set_pixel(x, y, Color(1.0 if land else 0.0, 1.0 if hollow else 0.0, 1.0 if type == TerrainTiles.Type.SHALLOW_WATER else 0.0, flow))
	var node := ChunkSurface.new()
	node.name = "Surface"
	node.mask = ImageTexture.create_from_image(image)
	node.size = size
	node.material = shared_material()
	node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# Dry land with nowhere for a puddle draws nothing at all.
	node.visible = any_water or any_hollow
	return node


class ChunkSurface:
	extends Node2D
	var mask: Texture2D
	var size := 16

	func _draw() -> void:
		var tile := float(TerrainTiles.TILE_SIZE)
		draw_texture_rect_region(mask, Rect2(Vector2.ZERO, Vector2(size, size) * tile), Rect2(Vector2(BORDER, BORDER), Vector2(size, size)))
