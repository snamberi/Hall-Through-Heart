class_name MonsterLook
extends RefCounted
## How a monster wears its rank and meets its end, on top of its frames.
##
## Rank: a one-pixel outline in the rank's colour, with a shimmer of its own:
## an Elite's gold glint sweeping up, a Champion's two violet glints
## crossing, an Ancient's (and a named one's) flickering ember edge, a
## boss's crimson edge pulsing with the heartbeat and throwing sparks.
##
## Death, by family: husks and corpses crumble from the head down to dust,
## skeletons drop apart into bones, slimes burst and melt into a puddle,
## wisps and spirits rise and come apart into sparks, stone shatters, and
## beasts fall and lie still before fading. Every effect only takes away
## whole pixels of the art (nothing is stretched or blurred), and the bits
## that fly are in the creature's own colours.

## The death of each family; any other falls and lies still ("fall").
const DEATHS := {
	"husk": "crumble", "rot_cultist": "crumble", "rotten_corpse": "crumble", "spore_shambler": "crumble", "dune_mummy": "crumble",
	"matron": "crumble", "masked_noble": "crumble", "treant": "crumble", "heartsworn_knight": "crumble", "frost_troll": "crumble",
	"crimson_fiend": "crumble", "bone_archer": "bones",
	"bog_slime": "splat", "magma_slime": "splat",
	"ember_wisp": "fade", "ash_wraith": "fade", "ghost": "fade", "void_eye": "fade", "veinheart": "fade", "cinder_imp": "fade",
	"void_stalker": "fade",
	"crag_golem": "shatter",
}
## Each style's dissolve: [how it is eaten away (0 top down, 1 melting, 2
## scattered, 3 rising), seconds, wait after the death frames].
const STYLE := {
	"crumble": [0, 1.3, 0.5], "bones": [0, 0.7, 0.2], "splat": [1, 0.9, 0.0], "fade": [3, 1.1, 0.0], "shatter": [2, 0.45, 0.1],
}
## Rank -> [outline colour, glint colour, pattern].
const RANKS := {
	Enemy.Rank.ELITE: [Color(0.96, 0.74, 0.3, 0.85), Color(1.0, 0.98, 0.8), 0],
	Enemy.Rank.CHAMPION: [Color(0.72, 0.48, 1.0, 0.85), Color(0.95, 0.85, 1.0), 1],
	Enemy.Rank.MINIBOSS: [Color(1.0, 0.42, 0.22, 0.9), Color(1.0, 0.86, 0.5), 2],
	Enemy.Rank.BOSS: [Color(0.86, 0.1, 0.16, 0.95), Color(1.0, 0.7, 0.6), 3],
}

const SHADER := """
shader_type canvas_item;
// Rank outline.
uniform vec4 edge : source_color = vec4(0.0);
uniform vec4 glint : source_color = vec4(1.0);
uniform int pattern = -1;
// Dissolve: 0 nothing gone, 1 all gone; how it is eaten away.
uniform float gone = 0.0;
uniform int way = 0;
uniform float frame_px = 96.0;
// The sprite's own colour and fade (modulate), from the vertex: in the
// fragment COLOR already holds the texture too.
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Whether a pixel of the frame has been eaten away yet.
bool eaten(vec2 local, vec2 cell) {
	if (gone <= 0.0) {
		return false;
	}
	float noise = hash(cell);
	float height = 1.0 - local.y / frame_px;
	float order;
	if (way == 0) {
		// Top down, ragged.
		order = (1.0 - height) * 0.75 + noise * 0.25;
		order = 1.0 - order;
	} else if (way == 1) {
		// Melting: columns sink at their own pace.
		order = height * 0.6 + hash(vec2(cell.x, 7.0)) * 0.25 + noise * 0.15;
	} else if (way == 3) {
		// Rising into sparks: the lowest go first.
		order = (1.0 - height) * 0.5 + noise * 0.5;
		order = 1.0 - order;
		order = order * 0.5 + noise * 0.5;
	} else {
		order = noise;
	}
	return order < gone * 1.15 - 0.05;
}

void fragment() {
	vec2 cell = floor(UV / TEXTURE_PIXEL_SIZE);
	vec2 local = mod(cell, frame_px);
	vec4 here = texture(TEXTURE, UV);
	if (here.a > 0.5) {
		COLOR = here * tint;
		if (eaten(local, cell)) {
			COLOR.a = 0.0;
		}
	} else {
		COLOR = vec4(0.0);
		if (pattern >= 0 && gone <= 0.0) {
			float near = texture(TEXTURE, UV + vec2(TEXTURE_PIXEL_SIZE.x, 0.0)).a + texture(TEXTURE, UV - vec2(TEXTURE_PIXEL_SIZE.x, 0.0)).a
				+ texture(TEXTURE, UV + vec2(0.0, TEXTURE_PIXEL_SIZE.y)).a + texture(TEXTURE, UV - vec2(0.0, TEXTURE_PIXEL_SIZE.y)).a;
			if (near > 0.5) {
				vec4 colour = edge;
				float t = TIME;
				if (pattern == 0) {
					// A glint sweeping up and round.
					float band = mod(local.y + local.x * 0.35 - (frame_px - mod(t * 34.0, frame_px + 30.0)), frame_px + 30.0);
					if (band < 2.5) { colour = glint; }
				} else if (pattern == 1) {
					// Two glints crossing.
					float a = mod(local.x + local.y - mod(t * 42.0, frame_px * 2.0), frame_px * 2.0);
					float b = mod(local.x - local.y + mod(t * 42.0, frame_px * 2.0), frame_px * 2.0);
					if (a < 2.5 || b < 2.5) { colour = glint; }
				} else if (pattern == 2) {
					// An ember edge: each pixel flickers on its own.
					float flick = hash(cell + floor(t * 9.0));
					colour = mix(edge * vec4(0.55, 0.45, 0.4, 1.0), glint, step(0.62, flick));
				} else {
					// The heartbeat: two thumps, then a rest; sparks now and then.
					float beat = mod(t, 1.4);
					float pulse = max(exp(-pow((beat - 0.1) / 0.07, 2.0)), 0.7 * exp(-pow((beat - 0.32) / 0.07, 2.0)));
					colour = mix(edge * vec4(0.6, 0.5, 0.5, 1.0), glint, step(0.55, pulse));
					if (hash(cell + floor(t * 12.0)) > 0.985) { colour = vec4(1.0, 0.95, 0.8, 1.0); }
				}
				COLOR = vec4(colour.rgb, colour.a * tint.a);
			}
		}
	}
}
"""

static var _shader: Shader
## sheet -> colours sampled from its first frame
static var _colours: Dictionary = {}


static func dress(enemy: Enemy, sprite: CanvasItem) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var look := ShaderMaterial.new()
	look.shader = _shader
	var rank: int = enemy.rank
	if enemy.named_id != "" or enemy.boss_id != "":
		rank = maxi(rank, Enemy.Rank.MINIBOSS)
	if RANKS.has(rank) and not enemy.is_wild():
		var data: Array = RANKS[rank]
		var colour: Color = data[0]
		# A named monster's edge is its own colour.
		if enemy.named_id != "" and enemy.boss_id == "":
			colour = Color(MinibossDB.NAMED[enemy.named_id]["tint"], 0.9)
		look.set_shader_parameter("edge", colour)
		look.set_shader_parameter("glint", data[1])
		look.set_shader_parameter("pattern", data[2])
	sprite.material = look
	return look


static func death_of(enemy_id: String) -> String:
	return str(DEATHS.get(enemy_id, "fall"))


## A handful of the creature's own colours, for the bits that fly.
static func colours_of(sheet: Texture2D) -> Array[Color]:
	if _colours.has(sheet):
		return _colours[sheet]
	var out: Array[Color] = []
	var image := sheet.get_image() if sheet else null
	if image:
		if image.is_compressed():
			image.decompress()
		var seen := {}
		for y in range(20, 80, 3):
			for x in range(20, 76, 3):
				var colour := image.get_pixel(x, y)
				if colour.a > 0.9 and colour.get_luminance() > 0.12:
					var key := colour.to_html(false)
					if not seen.has(key):
						seen[key] = true
						out.append(colour)
	if out.is_empty():
		out = [Color(0.5, 0.45, 0.4)]
	out.shuffle()
	out.resize(mini(out.size(), 8))
	_colours[sheet] = out
	return out


## The end of a monster, by its family's style. `sprite` is its picture,
## `look` the material from dress(); calls `done` when it is gone.
static func fall(enemy: Enemy, sprite: CanvasItem, look: ShaderMaterial, death_frames: float, tint: Color, done: Callable) -> void:
	var style := death_of(enemy.enemy_id)
	var visual := sprite.get_parent() as Node2D
	var tween := enemy.create_tween()
	visual.modulate = Color(4.0, 4.0, 4.0)
	tween.tween_property(visual, "modulate", tint, 0.15)
	if look:
		look.set_shader_parameter("pattern", -1)
	if style == "fall" or look == null:
		# Let the collapse play, lie still a moment, then fade away.
		tween.tween_interval(death_frames + 3.5)
		tween.tween_property(enemy, "modulate:a", 0.0, 1.2)
		tween.tween_callback(done)
		return
	var how: Array = STYLE[style]
	var colours := colours_of(EnemyDB.sheet(enemy.enemy_id))
	var parent := enemy.get_parent()
	var at := enemy.global_position
	look.set_shader_parameter("way", int(how[0]))
	match style:
		"splat":
			# Bursts at once, and melts into what it leaves on the ground.
			Debris.spawn(parent, at + Vector2(0, -4), colours, 18)
			FightMarks.leave(enemy.get_tree(), "goo", at + Vector2(0, 4))
			Audio.play("hit", -6.0, 0.25)
		"shatter":
			tween.tween_interval(death_frames * 0.5)
			tween.tween_callback(func() -> void:
				Debris.spawn(parent, at + Vector2(0, -12), colours, 22)
				FightMarks.leave(enemy.get_tree(), "dust", at + Vector2(0, 4))
				Audio.play("chop", -4.0, 0.2))
		"bones":
			tween.tween_interval(death_frames)
			tween.tween_callback(func() -> void:
				Debris.spawn(parent, at + Vector2(0, -10), colours, 16)
				FightMarks.leave(enemy.get_tree(), "dust", at + Vector2(0, 4)))
		"crumble":
			tween.tween_interval(death_frames + float(how[2]))
			tween.tween_callback(func() -> void:
				Debris.spawn(parent, at + Vector2(0, -14), colours, 14)
				FightMarks.leave(enemy.get_tree(), "dust", at + Vector2(0, 4)))
		"fade":
			tween.tween_interval(death_frames * 0.4)
			# Coming apart into sparks...
			tween.tween_callback(func() -> void:
				var melt := enemy.create_tween()
				melt.tween_method(func(value: float) -> void: look.set_shader_parameter("gone", value), 0.0, 1.0, float(how[1])))
			# ...rising a whole pixel at a time as it goes.
			for step in 6:
				tween.tween_callback(func() -> void:
					visual.position.y -= 1.0
					HitSpark.spawn(parent, at + Vector2(randf_range(-10, 10), randf_range(-30, -6)), colours[step % colours.size()], false))
				tween.tween_interval(float(how[1]) / 6.0)
			tween.tween_callback(done)
			return
	tween.tween_method(func(value: float) -> void: look.set_shader_parameter("gone", value), 0.0, 1.0, float(how[1]))
	tween.tween_callback(done)
