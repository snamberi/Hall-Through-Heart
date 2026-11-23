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
// How much of the profile's width shows: 1 side-on, less when the
// creature walks toward or away from us.
uniform float turn = 1.0;
// The sprite's own colour and fade (modulate), from the vertex: in the
// fragment COLOR already holds the texture too.
varying vec4 tint;
// Swimming: everything below this line (sprite pixels) is under water.
uniform float water_line = 9999.0;
varying float local_y;

void vertex() {
	tint = COLOR;
	local_y = VERTEX.y;
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
	vec2 uv = UV;
	bool off_frame = false;
	// Turned toward or away from us: the profile drawn narrower by leaving
	// out whole columns about its middle (nothing blended or stretched).
	if (turn < 0.999) {
		float col = mod(floor(uv.x / TEXTURE_PIXEL_SIZE.x), frame_px);
		float middle = frame_px * 0.5;
		float source = middle + floor((col - middle + 0.5) / turn);
		off_frame = source < 0.0 || source >= frame_px;
		uv.x += (clamp(source, 0.0, frame_px - 1.0) - col) * TEXTURE_PIXEL_SIZE.x;
	}
	vec2 cell = floor(uv / TEXTURE_PIXEL_SIZE);
	vec2 local = mod(cell, frame_px);
	vec4 here = texture(TEXTURE, uv);
	if (here.a > 0.5) {
		COLOR = here * tint;
		if (eaten(local, cell)) {
			COLOR.a = 0.0;
		}
	} else {
		COLOR = vec4(0.0);
		if (pattern >= 0 && gone <= 0.0) {
			float near = texture(TEXTURE, uv + vec2(TEXTURE_PIXEL_SIZE.x, 0.0)).a + texture(TEXTURE, uv - vec2(TEXTURE_PIXEL_SIZE.x, 0.0)).a
				+ texture(TEXTURE, uv + vec2(0.0, TEXTURE_PIXEL_SIZE.y)).a + texture(TEXTURE, uv - vec2(0.0, TEXTURE_PIXEL_SIZE.y)).a;
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
	if (local_y > water_line || off_frame) {
		COLOR.a = 0.0;
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


## sheet -> Vector2(top, bottom) of the body in the first frame, in the
## sprite's own (centred) pixels.
static var _rows: Dictionary = {}


static func body_rows(sheet: Texture2D, frame: int = 96) -> Vector2:
	if sheet == null:
		return Vector2(-24, 24)
	if _rows.has(sheet):
		return _rows[sheet]
	var image := sheet.get_image()
	if image.is_compressed():
		image.decompress()
	var top := frame
	var bottom := 0
	for y in mini(frame, image.get_height()):
		for x in range(0, mini(frame, image.get_width()), 2):
			if image.get_pixel(x, y).a > 0.5:
				top = mini(top, y)
				bottom = maxi(bottom, y)
				break
	var rows := Vector2(top - frame / 2.0, bottom - frame / 2.0) if bottom > top else Vector2(-24, 24)
	_rows[sheet] = rows
	return rows


## In the water up to its middle (deeper water, a little more): the body
## below the surface is cut away and the creature sinks so the surface lies
## where its feet were. Returns how far the picture sinks, in its own pixels.
static func wade(look: ShaderMaterial, sheet: Texture2D, in_water: bool, deep: bool) -> float:
	if look == null:
		return 0.0
	if not in_water:
		look.set_shader_parameter("water_line", 9999.0)
		return 0.0
	var rows := body_rows(sheet)
	var line := rows.x + (rows.y - rows.x) * (0.5 if deep else 0.62)
	look.set_shader_parameter("water_line", line)
	return rows.y - line


## The wake round a swimming creature: rings spreading on the water and a
## glinting line of surface across its body.
class Wake:
	extends Node2D
	var width := 20.0

	func _process(_delta: float) -> void:
		if visible:
			queue_redraw()

	func _draw() -> void:
		var t := Time.get_ticks_msec() / 1000.0
		var half := roundf(width * 0.5)
		var surface := PackedVector2Array()
		for i in 7:
			var x := -half + i * width / 6.0
			surface.append(Vector2(roundf(x), roundf(sin(t * 5.0 + i * 0.9))))
		draw_polyline(surface, Color(0.8, 0.92, 1.0, 0.75), 1.5)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.32))
		for k in 2:
			var phase := fposmod(t * 0.9 + k * 0.5, 1.0)
			draw_arc(Vector2.ZERO, half + 2.0 + phase * 8.0, 0.0, TAU, 28, Color(0.7, 0.85, 0.95, 0.45 * (1.0 - phase)), 1.5)
		draw_set_transform(Vector2.ZERO)


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
## Spots on the body in a sheet's last death frame where a wound can sit
## (well inside the body, not at its edge), by sheet.
static var _wound_spots: Dictionary = {}


## A heart-shaped hole in one part of a fallen creature's body: dark inside,
## a torn rim of blood, a drip below. Drawn in whole pixels on the sprite.
static func heart_wound(sprite: CanvasItem, sheet: Texture2D, frame: int = 96) -> void:
	if not is_instance_valid(sprite) or sheet == null:
		return
	if not _wound_spots.has(sheet):
		var spots: Array[Vector2i] = []
		var image := sheet.get_image()
		if image and image.get_height() >= frame * 6:
			var ox := frame * 7
			var oy := frame * 5
			for y in range(4, frame - 4, 2):
				for x in range(4, frame - 4, 2):
					var inside := true
					for d: Vector2i in [Vector2i(-4, 0), Vector2i(4, 0), Vector2i(0, -3), Vector2i(0, 4), Vector2i.ZERO]:
						if image.get_pixel(ox + x + d.x, oy + y + d.y).a < 0.5:
							inside = false
							break
					if inside:
						spots.append(Vector2i(x, y))
		_wound_spots[sheet] = spots
	var spots: Array = _wound_spots[sheet]
	if spots.is_empty():
		return
	var spot: Vector2i = spots[randi() % spots.size()]
	var wound := HeartWound.new()
	var centered := (sprite as AnimatedSprite2D).centered if sprite is AnimatedSprite2D else true
	var offset := (sprite as AnimatedSprite2D).offset if sprite is AnimatedSprite2D else Vector2.ZERO
	wound.position = Vector2(spot) - (Vector2(frame, frame) / 2.0 if centered else Vector2.ZERO) + offset
	if sprite is AnimatedSprite2D and (sprite as AnimatedSprite2D).flip_h:
		wound.position.x = -wound.position.x
	sprite.add_child(wound)


## The wound itself (see heart_wound).
class HeartWound extends Node2D:
	const SHAPE: Array[String] = [
		".rr.rr.",
		"rddrddr",
		"rdddddr",
		".rdddr.",
		"..rdr..",
		"...r...",
	]
	var _age := 0.0

	func _ready() -> void:
		z_index = 1
		z_as_relative = true

	func _process(delta: float) -> void:
		_age += delta
		if _age < 0.5:
			queue_redraw()
		# It goes as the body goes, when the body dissolves.
		var body := get_parent() as CanvasItem
		if body and body.material is ShaderMaterial:
			var gone: Variant = (body.material as ShaderMaterial).get_shader_parameter("gone")
			modulate.a = 1.0 - clampf(float(gone) if gone != null else 0.0, 0.0, 1.0)

	func _draw() -> void:
		var grow := clampf(_age / 0.3, 0.0, 1.0)
		var rim := Color("8a1222")
		var deep := Color("1a0508")
		var wet := Color("c0283a")
		for y in SHAPE.size():
			for x in SHAPE[y].length():
				var c := SHAPE[y][x]
				if c == ".":
					continue
				# Opens from the middle out in its first moments.
				if grow < 1.0 and absf(x - 3) + absf(y - 2) > grow * 6.0:
					continue
				draw_rect(Rect2(Vector2(x - 3, y - 3), Vector2.ONE), rim if c == "r" else deep)
		draw_rect(Rect2(Vector2(-1, -2), Vector2.ONE), wet)
		if grow >= 1.0:
			# A drip running down from the point.
			var drip := mini(int((_age - 0.3) * 10.0), 3)
			for k in drip:
				draw_rect(Rect2(Vector2(0, 3 + k), Vector2.ONE), rim)


static func fall(enemy: Enemy, sprite: CanvasItem, look: ShaderMaterial, death_frames: float, tint: Color, done: Callable) -> void:
	var style := death_of(enemy.enemy_id)
	var visual := sprite.get_parent() as Node2D
	var tween := enemy.create_tween()
	visual.modulate = Color(4.0, 4.0, 4.0)
	tween.tween_property(visual, "modulate", tint, 0.15)
	if look:
		look.set_shader_parameter("pattern", -1)
	if style == "fall" or look == null:
		# Let the collapse play; as it comes to rest a heart-shaped wound
		# opens on its body; it lies still a moment, then fades away.
		tween.tween_interval(death_frames * 0.6)
		tween.tween_callback(func() -> void: heart_wound(sprite, EnemyDB.sheet(enemy.enemy_id)))
		tween.tween_interval(death_frames * 0.4 + 3.5)
		tween.tween_property(enemy, "modulate:a", 0.0, 1.2)
		tween.tween_callback(done)
		return
	var how: Array = STYLE[style]
	# Flesh and bone take the heart-shaped wound too, before they come apart.
	if style in ["crumble", "bones", "shatter"]:
		var mark := enemy.create_tween()
		mark.tween_interval(death_frames * 0.5)
		mark.tween_callback(func() -> void: heart_wound(sprite, EnemyDB.sheet(enemy.enemy_id)))
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
