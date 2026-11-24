class_name PlayerAnimator
extends AnimatedSprite2D
const PX := preload("res://scripts/effects/pixel_draw.gd")
## Plays the player's animation and draws their visible equipment.
##
## The body sheet is the bare character. Each visible piece of equipment is
## its own sheet with the same rows, layered over the body and kept on the
## same frame, so new gear never needs the body redrawn.
## Rows must match HUMAN_ANIMATIONS in tools/generate_art.py.

signal rebirth_finished

const SHEET: Texture2D = preload("res://assets/sprites/player_sheet.png")
const FRAME_SIZE := 96
const ROWS: Array[Dictionary] = [
	{"name": "idle", "frames": 8, "fps": 6.0, "loop": true},
	{"name": "walk", "frames": 12, "fps": 16.5, "loop": true, "wrap_row": 52},
	{"name": "run", "frames": 12, "fps": 18.0, "loop": true, "wrap_row": 53},
	{"name": "attack", "frames": 8, "fps": 20.0, "loop": false},
	{"name": "heavy", "frames": 8, "fps": 13.0, "loop": false},
	{"name": "dodge", "frames": 7, "fps": 16.0, "loop": false},
	{"name": "hurt", "frames": 3, "fps": 12.0, "loop": false},
	{"name": "death", "frames": 8, "fps": 10.0, "loop": false},
	{"name": "rebirth", "frames": 8, "fps": 8.0, "loop": false},
	{"name": "ride", "frames": 4, "fps": 5.0, "loop": true},
	{"name": "thrust", "frames": 6, "fps": 15.0, "loop": false},
	{"name": "smash", "frames": 7, "fps": 13.0, "loop": false},
	{"name": "shoot", "frames": 6, "fps": 13.0, "loop": false},
	{"name": "cast", "frames": 6, "fps": 13.0, "loop": false},
	# Each class at rest, its own way (two to a row).
	{"name": "idle_warrior", "frames": 4, "fps": 6.0, "loop": true, "row": 14, "col": 0},
	{"name": "idle_guardian", "frames": 4, "fps": 6.0, "loop": true, "row": 14, "col": 4},
	{"name": "idle_ranger", "frames": 4, "fps": 3.0, "loop": true, "row": 15, "col": 0},
	{"name": "idle_assassin", "frames": 4, "fps": 6.0, "loop": true, "row": 15, "col": 4},
	{"name": "idle_mage", "frames": 4, "fps": 5.0, "loop": true, "row": 16, "col": 0},
	{"name": "idle_spellblade", "frames": 4, "fps": 6.0, "loop": true, "row": 16, "col": 4},
	{"name": "idle_necromancer", "frames": 4, "fps": 5.0, "loop": true, "row": 17, "col": 0},
	{"name": "idle_spellcaster", "frames": 4, "fps": 5.0, "loop": true, "row": 17, "col": 4},
	# Seen from behind (walking up) and in profile (walking sideways).
	{"name": "idle_back", "frames": 4, "fps": 6.0, "loop": true, "row": 18, "col": 0},
	{"name": "idle_side", "frames": 4, "fps": 6.0, "loop": true, "row": 18, "col": 4},
	{"name": "walk_back", "frames": 12, "fps": 16.5, "loop": true, "row": 19, "wrap_row": 54},
	{"name": "run_back", "frames": 12, "fps": 18.0, "loop": true, "row": 20, "wrap_row": 55},
	{"name": "walk_side", "frames": 12, "fps": 16.5, "loop": true, "row": 21, "wrap_row": 56},
	{"name": "run_side", "frames": 12, "fps": 18.0, "loop": true, "row": 22, "wrap_row": 57},
	# The diagonals, seen three-quarter from the front and from behind.
	{"name": "idle_fq", "frames": 4, "fps": 6.0, "loop": true, "row": 23, "col": 0},
	{"name": "idle_bq", "frames": 4, "fps": 6.0, "loop": true, "row": 23, "col": 4},
	{"name": "walk_fq", "frames": 12, "fps": 16.5, "loop": true, "row": 24, "wrap_row": 58},
	{"name": "run_fq", "frames": 12, "fps": 18.0, "loop": true, "row": 25, "wrap_row": 59},
	{"name": "walk_bq", "frames": 12, "fps": 16.5, "loop": true, "row": 26, "wrap_row": 60},
	{"name": "run_bq", "frames": 12, "fps": 18.0, "loop": true, "row": 27, "wrap_row": 61},
	# Every blow in every view (tools/generate_people.py VIEWED_BLOWS).
	{"name": "attack_back", "frames": 8, "fps": 20.0, "loop": false, "row": 28},
	{"name": "heavy_back", "frames": 8, "fps": 13.0, "loop": false, "row": 29},
	{"name": "thrust_back", "frames": 6, "fps": 15.0, "loop": false, "row": 30},
	{"name": "smash_back", "frames": 7, "fps": 13.0, "loop": false, "row": 31},
	{"name": "shoot_back", "frames": 6, "fps": 13.0, "loop": false, "row": 32},
	{"name": "cast_back", "frames": 6, "fps": 13.0, "loop": false, "row": 33},
	{"name": "attack_side", "frames": 8, "fps": 20.0, "loop": false, "row": 34},
	{"name": "heavy_side", "frames": 8, "fps": 13.0, "loop": false, "row": 35},
	{"name": "thrust_side", "frames": 6, "fps": 15.0, "loop": false, "row": 36},
	{"name": "smash_side", "frames": 7, "fps": 13.0, "loop": false, "row": 37},
	{"name": "shoot_side", "frames": 6, "fps": 13.0, "loop": false, "row": 38},
	{"name": "cast_side", "frames": 6, "fps": 13.0, "loop": false, "row": 39},
	{"name": "attack_fq", "frames": 8, "fps": 20.0, "loop": false, "row": 40},
	{"name": "heavy_fq", "frames": 8, "fps": 13.0, "loop": false, "row": 41},
	{"name": "thrust_fq", "frames": 6, "fps": 15.0, "loop": false, "row": 42},
	{"name": "smash_fq", "frames": 7, "fps": 13.0, "loop": false, "row": 43},
	{"name": "shoot_fq", "frames": 6, "fps": 13.0, "loop": false, "row": 44},
	{"name": "cast_fq", "frames": 6, "fps": 13.0, "loop": false, "row": 45},
	{"name": "attack_bq", "frames": 8, "fps": 20.0, "loop": false, "row": 46},
	{"name": "heavy_bq", "frames": 8, "fps": 13.0, "loop": false, "row": 47},
	{"name": "thrust_bq", "frames": 6, "fps": 15.0, "loop": false, "row": 48},
	{"name": "smash_bq", "frames": 7, "fps": 13.0, "loop": false, "row": 49},
	{"name": "shoot_bq", "frames": 6, "fps": 13.0, "loop": false, "row": 50},
	{"name": "cast_bq", "frames": 6, "fps": 13.0, "loop": false, "row": 51},
]
## The blows that have a row for each view.
const BLOWS: Array[String] = ["attack", "heavy", "thrust", "smash", "shoot", "cast"]
## Which way the figure is seen. Every character is drawn from the front,
## mirrored to face left or right, whichever way it goes, swims, shoots or
## swings; the other views stay in the sheets but are not shown.
static func view_of(_heading: Vector2) -> String:
	return "front"


## The row for a blow in the view now shown, if the sheet has it.
func _viewed(row: String) -> String:
	var viewed := row + "_" + _view
	return viewed if _view != "front" and sprite_frames and sprite_frames.has_animation(viewed) else row
## Below this speed the player walks rather than runs, in pixels/second.
const RUN_SPEED := 150.0

## Layers over the body, back to front: first the character's own features
## (hair, ears, horns... see Appearance), then what they wear. "behind"
## layers draw under the body.
const LAYERS: Array[Dictionary] = [
	{"name": "look_tail", "behind": true},
	{"name": "look_wings", "behind": true},
	{"name": "look_cape", "behind": true},
	{"name": "cape", "behind": true},
	{"name": "look_ears", "behind": false},
	{"name": "look_race", "behind": false},
	{"name": "look_outfit", "behind": false},
	{"name": "look_eyes", "behind": false},
	{"name": "look_mark", "behind": false},
	{"name": "look_race_accent", "behind": false},
	{"name": "look_neck", "behind": false},
	{"name": "look_face", "behind": false},
	{"name": "look_beard", "behind": false},
	{"name": "look_hair", "behind": false},
	{"name": "look_horns", "behind": false},
	{"name": "look_hat", "behind": false},
	{"name": "legs", "behind": false},
	{"name": "boots", "behind": false},
	{"name": "chest", "behind": false},
	{"name": "shoulders", "behind": false},
	{"name": "helmet", "behind": false},
	{"name": "hood", "behind": false},
	{"name": "shield", "behind": false},
	{"name": "weapon", "behind": false},
]
## How each piece of armour looks when worn: "plate" (mail for the first
## metal, then three plate styles as the metal improves, all tinted with
## it), or a look in its own colours.
const ARMOUR_LOOKS := {"helmet": "plate", "leather_cap": "leather", "ember_crown": "crown",
	"chestplate": "plate", "leather_vest": "leather", "fur_cloak": "fur",
	"greaves": "plate", "leather_leggings": "leather", "boots": "plate", "leather_boots": "leather", "voidwalker": "plate",
	"heartsworn_helm": "heart", "heartsworn_cuirass": "heart", "heartsworn_greaves": "heart", "heartsworn_sabatons": "heart"}
## Item levels where metal armour moves on: mail below the first (Copper),
## plate from Iron, finer plate from Gilded, crested plate from Adamantite.
const PLATE_STYLE_LEVELS: Array[int] = [10, 30, 65]
## Armour of these rarities is trimmed whatever its upgrades: epic in
## bronze, legendary and mythic in gold with runes glowing in its colour
## (the same marks a blacksmith's +3 and +6 leave).
const RARITY_TRIM := {3: 3, 4: 6, 5: 6}


## The layer sheet for a worn piece, e.g. "layers/helmet_plate_2".
static func armour_sheet(part: String, item: Item) -> String:
	var look: String = ARMOUR_LOOKS.get(item.id, "plate")
	# Helmets and chest pieces have mail and three plate styles; legs mail
	# and plate; boots one.
	if look == "plate" and part != "boots":
		var style := 0
		for level: int in PLATE_STYLE_LEVELS:
			if item.level >= level:
				style += 1
		if style == 0:
			look = "chain"
		elif part in ["helmet", "chest"]:
			look = "plate_%d" % style
	return "layers/%s_%s" % [part, look]


## Chest armour of this rarity or better adds shoulder pieces / a cape.
const SHOULDERS_FROM_RARITY := 2
const CAPE_FROM_RARITY := 3
## Any equipped item of this rarity or better gives the player an aura.
const AURA_FROM_RARITY := 4

## Tints a layer by its material tier, recolours its dark outline in the
## item's rarity colour, and makes the better rarities shimmer.
const LAYER_SHADER := """
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(1.0);
// With a ramp, grey art takes the chosen colour's own three tones exactly
// (light, mid, dark) instead of being multiplied darker.
uniform vec4 tint_mid : source_color = vec4(1.0);
uniform vec4 tint_dark : source_color = vec4(1.0);
uniform float use_ramp = 0.0;
uniform vec4 rarity_color : source_color = vec4(1.0);
uniform float outline_mix = 0.0;
uniform float glow = 0.0;
uniform float glint = 0.0;
uniform float glint_period = 5.0;
uniform float sparkle = 0.0;
uniform float water_line = 9999.0;
// Blacksmith upgrades show on the gear itself: +1 polishes it brighter,
// +3 gilds its rim in a trim of bronze (gold from +6), +6 cuts runes into
// it that glow in its rarity's colour, +9 sets its outline smouldering.
uniform float upgrade = 0.0;
uniform vec4 trim : source_color = vec4(0.78, 0.56, 0.29, 1.0);
varying float local_y;
varying vec2 local_pos;
varying vec4 modulate;

void vertex() {
	local_y = VERTEX.y;
	local_pos = VERTEX;
	modulate = COLOR;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	if (local_y > water_line) {
		discard;
	}
	vec4 pixel = texture(TEXTURE, UV);
	float outline = step(pixel.r + pixel.g + pixel.b, 0.125) * pixel.a;
	vec3 body = COLOR.rgb * tint.rgb + rarity_color.rgb * glow * 0.3;
	float spread = max(max(pixel.r, pixel.g), pixel.b) - min(min(pixel.r, pixel.g), pixel.b);
	if (use_ramp > 0.5 && spread < 0.08 && outline < 0.5) {
		float level = pixel.g;
		vec3 tone = level > 0.88 ? tint.rgb : (level > 0.68 ? tint_mid.rgb : (level > 0.5 ? tint_dark.rgb : tint_dark.rgb * 0.78));
		body = tone * modulate.rgb + rarity_color.rgb * glow * 0.3;
	}
	vec3 edge = rarity_color.rgb;
	vec3 result = mix(body, mix(COLOR.rgb, edge, outline_mix), outline);
	float inside = (1.0 - outline) * step(0.5, pixel.a);
	// Fine gear catches the light now and then: a narrow gleam sweeps
	// across it, then it rests, so the art stays readable.
	if (glint > 0.0) {
		float cycle = fract(TIME / glint_period);
		float sweep = mix(-60.0, 60.0, cycle / 0.16);
		float band = step(cycle, 0.16) * (1.0 - smoothstep(0.0, 3.5, abs(local_pos.x + local_pos.y * 0.6 - sweep)));
		result += (rarity_color.rgb * 0.7 + vec3(0.35)) * band * glint * inside;
	}
	if (upgrade > 0.5 && inside > 0.5) {
		result *= 1.0 + 0.05 * min(upgrade, 3.0);
		float rim = 0.0;
		for (int k = 0; k < 4; k++) {
			vec2 d = k == 0 ? vec2(1.0, 0.0) : (k == 1 ? vec2(-1.0, 0.0) : (k == 2 ? vec2(0.0, 1.0) : vec2(0.0, -1.0)));
			vec4 n = texture(TEXTURE, UV + d * TEXTURE_PIXEL_SIZE);
			rim = max(rim, max(1.0 - n.a, step(n.r + n.g + n.b, 0.125) * n.a));
		}
		if (upgrade >= 3.0) {
			vec3 metal = upgrade >= 6.0 ? vec3(0.95, 0.78, 0.32) : trim.rgb;
			result = mix(result, metal * (0.7 + 0.45 * pixel.g), rim * 0.8);
		}
		if (upgrade >= 6.0) {
			vec2 cell = floor(UV / TEXTURE_PIXEL_SIZE);
			float rune = step(0.9, hash(floor(cell / 2.0) * 3.1 + 0.5)) * (1.0 - rim);
			float pulse = 0.55 + 0.45 * sin(TIME * 2.4 + cell.x * 0.4 + cell.y * 0.2);
			result = mix(result, rarity_color.rgb * 1.25 + vec3(0.18), rune * pulse * 0.85);
		}
	}
	if (upgrade >= 9.0 && outline > 0.5) {
		result = mix(result, rarity_color.rgb, 0.55 + 0.35 * sin(TIME * 3.0));
	}
	// The finest twinkle: a pixel here and there flashes white.
	if (sparkle > 0.0) {
		vec2 cell = floor(UV / TEXTURE_PIXEL_SIZE);
		float h = hash(cell + floor(TIME * 3.0) * 17.31);
		result = mix(result, vec3(1.0), step(1.0 - 0.006 * sparkle, h) * inside * 0.85);
	}
	COLOR.rgb = result;
}
"""
## Per rarity, for the weapon in hand: [gleam strength, seconds between
## gleams, twinkle]. Common and uncommon steel stays plain.
const RARITY_LOOK: Array[Array] = [[0.0, 5.0, 0.0], [0.0, 5.0, 0.0], [0.45, 7.0, 0.0], [0.6, 5.5, 0.0], [0.8, 4.2, 0.6], [1.0, 3.2, 1.0]]
## Seconds between fading after-images while dodging.
const GHOST_INTERVAL := 0.04

## An animation that must finish before movement animations resume.
var _busy := ""
var _ghost_left := 0.0
var _layers: Dictionary[String, AnimatedSprite2D] = {}
var _aura_color := Color.TRANSPARENT
var _water: Node2D
var _ripple_left := 0.0

static var _frames_cache: Dictionary = {}

@onready var _player: Player = owner


func _ready() -> void:
	sprite_frames = SheetAnimations.build(SHEET, FRAME_SIZE, ROWS)
	animation_finished.connect(_on_animation_finished)
	play("idle")

	# The water that hides the lower body while swimming, drawn in front.
	_water = Node2D.new()
	_water.z_index = 1
	_water.visible = false
	_water.draw.connect(_draw_water)
	add_child(_water)
	Events.splash.connect(_on_splash)

	var shader := Shader.new()
	shader.code = LAYER_SHADER
	for layer in LAYERS:
		var sprite := AnimatedSprite2D.new()
		var material := ShaderMaterial.new()
		material.shader = shader
		sprite.material = material
		sprite.show_behind_parent = layer["behind"]
		sprite.visible = false
		add_child(sprite)
		_layers[layer["name"]] = sprite


## The sun shadow hides while the body is in water or in the saddle.
func casts_shadow() -> bool:
	return not (_player.swimming or _player.boating or _player.mount_id != "")


func _process(delta: float) -> void:
	_choose_animation(delta)
	for sprite: AnimatedSprite2D in _layers.values():
		if sprite.visible:
			BodyFit.follow(sprite, self)
	if _aura_color.a > 0.0:
		queue_redraw()
	# Sink while swimming (deeper in deep water) and bob with each stroke;
	# the water line is drawn over the body.
	_water.visible = _player.swimming
	if _player.swimming:
		# Deep water takes a little more of the body, never the head: the
		# face and chin always stay above the surface.
		var sink := 7.0 if _player.deep_water else 4.0
		var bob := sin(Time.get_ticks_msec() / 220.0) * 1.5
		position.y = _rest_y + sink + bob
		# The waterline sits a little below the shoulders whatever the depth;
		# the body below it is cut away so the real water shows through.
		_water.position.y = 19.0 - sink
		_set_water_line(19.0 - sink)
		_water.queue_redraw()
		_ripple_left -= delta
		if _ripple_left <= 0.0 and _player.velocity.length() > 30.0:
			_ripple_left = 0.22
			_spawn_ripple()
	elif position.y != _rest_y:
		position.y = _rest_y
		_set_water_line(9999.0)
		_water.position.y = 0.0


func _draw() -> void:
	if _player.swimming:
		return
	if _aura_color.a <= 0.0:
		return
	# A faint, still ring on the ground under the feet; now and then a
	# bright spark runs once round it, rather than a constant pulse.
	var t := Time.get_ticks_msec() / 1000.0
	draw_set_transform(Vector2(0, 23), 0.0, Vector2(1.0, 0.4))
	PX.disc(self, Vector2.ZERO, 24.0, Color(_aura_color, 0.07))
	PX.arc(self, Vector2.ZERO, 24.0, 0.0, TAU, 32, Color(_aura_color, 0.32), 1.0)
	var cycle := fmod(t, 4.0) / 4.0
	if cycle < 0.22:
		var head := PI * 0.5 + cycle / 0.22 * TAU
		PX.arc(self, Vector2.ZERO, 24.0, head - 0.9, head, 10, Color(_aura_color.lightened(0.4), 0.85 * (1.0 - cycle / 0.22 * 0.5)), 2.0)
	draw_set_transform(Vector2.ZERO)


var _water_line := 9999.0


## Cuts the body (and everything worn) off below `line`, in sprite pixels.
func _set_water_line(line: float) -> void:
	if is_equal_approx(line, _water_line):
		return
	_water_line = line
	if material is ShaderMaterial:
		(material as ShaderMaterial).set_shader_parameter("water_line", line)
	for sprite: AnimatedSprite2D in _layers.values():
		(sprite.material as ShaderMaterial).set_shader_parameter("water_line", line)


func _draw_water() -> void:
	var deep := _player.deep_water
	var t := Time.get_ticks_msec() / 1000.0
	var line := 0.0
	# A wavy glint of surface across the body; the water itself is the ground's.
	var surface := PackedVector2Array()
	for i in 7:
		var x := -13.0 + i * 4.33
		surface.append(Vector2(x, line + sin(t * 5.0 + i * 0.9) * 1.0))
	PX.polyline(_water, surface, Color(0.8, 0.92, 1.0, 0.8), 1.5)
	# Rings spreading from the swimmer.
	_water.draw_set_transform(Vector2(0.0, line), 0.0, Vector2(1.0, 0.32))
	for k in 2:
		var phase := fposmod(t * 0.9 + k * 0.5, 1.0)
		PX.arc(_water, Vector2.ZERO, 11.0 + phase * 8.0, 0.0, TAU, 28, Color(0.7, 0.85, 0.95, 0.5 * (1.0 - phase)), 1.5)
	_water.draw_set_transform(Vector2.ZERO)
	# A few bubbles in deep water.
	if deep:
		for k in 3:
			var rise := fposmod(t * 0.7 + k * 0.33, 1.0)
			PX.disc(_water, Vector2(-8.0 + k * 8.0, line + 16.0 - rise * 14.0), 1.2, Color(0.8, 0.92, 1.0, 0.7 * (1.0 - rise)))


## A ring left behind on the water as the player swims.
func _spawn_ripple() -> void:
	var ring := Node2D.new()
	ring.global_position = _player.global_position + Vector2(0, 2)
	ring.z_index = -1
	var radius := [6.0]
	ring.draw.connect(func() -> void:
		ring.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
		PX.arc(ring, Vector2.ZERO, radius[0], 0.0, TAU, 24, Color(0.75, 0.88, 0.95, 0.7), 1.5)
	)
	_player.get_parent().add_child(ring)
	var tween := ring.create_tween().set_parallel()
	tween.tween_method(func(r: float) -> void:
		radius[0] = r
		ring.queue_redraw()
	, 6.0, 26.0, 0.8)
	tween.tween_property(ring, "modulate:a", 0.0, 0.8)
	tween.chain().tween_callback(ring.queue_free)


func _on_splash(at: Vector2) -> void:
	var drops := CPUParticles2D.new()
	drops.amount = GameSettings.particle_amount(16)
	drops.lifetime = 0.5
	drops.one_shot = true
	drops.explosiveness = 1.0
	drops.direction = Vector2.UP
	drops.spread = 60.0
	drops.gravity = Vector2(0, 520)
	drops.initial_velocity_min = 90.0
	drops.initial_velocity_max = 170.0
	drops.scale_amount_min = 2.0
	drops.scale_amount_max = 3.0
	drops.color = Color(0.75, 0.88, 0.97)
	drops.global_position = at
	drops.z_index = 5
	_player.get_parent().add_child(drops)
	drops.emitting = true
	get_tree().create_timer(1.0).timeout.connect(drops.queue_free)
	Audio.play("swing", -10.0, 0.3)


## Redraws the visible equipment from what is worn.
func update_equipment(equipment: Equipment, show_helmet: bool) -> void:
	if _layers.is_empty():
		await ready
	# The hand holds a weapon, a belt tool, or a tool taken up for a job.
	var held := equipment.in_hand()
	if held and held.is_tool():
		var tool_kind: String = held.definition()["tool"]["kind"]
		_set_layer("weapon", held, "weapons/" + tool_kind, false, held.definition().get("tint", Color.WHITE))
	else:
		_set_layer("weapon", held, weapon_sheet(held) if held else "", false)
	# A shield stays on the back while both hands are busy.
	var both_hands: bool = held != null and (held.is_tool() or held.definition().get("two_handed", false))
	_set_layer("shield", null if both_hands else equipment.get_item("off_hand"), "layers/shield")
	var helmet: Item = equipment.get_item("helmet") if show_helmet else null
	var chest := equipment.get_item("chest")
	var legs := equipment.get_item("legs")
	var boots := equipment.get_item("boots")
	for entry: Array in [["helmet", helmet], ["chest", chest], ["legs", legs], ["boots", boots]]:
		var piece: Item = entry[1]
		var sheet := armour_sheet(entry[0], piece) if piece else ""
		# Plate takes its metal's colour; leather, fur and gold keep their own.
		_set_layer(entry[0], piece, sheet, sheet.contains("_plate") or sheet.contains("_chain"))
	var plate_chest: bool = chest != null and ARMOUR_LOOKS.get(chest.id, "plate") == "plate"
	_set_layer("shoulders", chest if plate_chest and chest.rarity >= SHOULDERS_FROM_RARITY else null, "layers/shoulders")
	_set_layer("cape", chest if chest and chest.rarity >= CAPE_FROM_RARITY else null, "layers/cape")
	if _layers["cape"].visible:
		# The cape takes the rarity colour itself rather than the metal's.
		(_layers["cape"].material as ShaderMaterial).set_shader_parameter("tint", chest.color().darkened(0.15))
		_layers["cape"].set_meta("tint", chest.color().darkened(0.15))

	var best: Item = null
	for item: Item in equipment.counted():
		if item.rarity >= AURA_FROM_RARITY and (best == null or item.rarity > best.rarity):
			best = item
	_aura_color = best.color() if best else Color.TRANSPARENT
	_update_hood()
	_show_features()
	queue_redraw()


## Where the sprite's middle sits so the feet rest on the ground, whatever
## the character's height.
var _rest_y := -23.0
## Features a helmet covers.
const UNDER_HELMET: Array[String] = ["hair", "horns", "hat"]
var _features: Dictionary = {}
## The appearance the body and its layers are fitted to.
var _appearance: Dictionary = Appearance.DEFAULT.duplicate()


## Dresses the body for the player's appearance: colours, size, and the
## feature layers (hair, beard, ears, horns, tail, wings, marks, eyes).
func apply_appearance(appearance: Dictionary) -> void:
	if _layers.is_empty():
		await ready
	if material is ShaderMaterial and (material as ShaderMaterial).shader.code == Appearance.SHADER:
		Appearance.update_material(material, appearance)
	else:
		material = Appearance.make_material(appearance)
		_water_line = 9999.0
	# Height and build are drawn into the body's own sheet, pixel for pixel:
	# nothing is stretched.
	_appearance = appearance.duplicate()
	var keep := animation
	var at := frame
	sprite_frames = BodyFit.body(appearance)
	animation = keep
	frame = at
	scale = Vector2.ONE
	_rest_y = -23.0
	position.y = _rest_y
	self_modulate.a = Appearance.alpha(appearance)
	_features = Appearance.layers(appearance)
	# Worn armour and the weapon move to fit the new height and build.
	for layer: String in _layers:
		var sprite: AnimatedSprite2D = _layers[layer]
		if sprite.visible and sprite.has_meta("fit_path") and not layer.begins_with("look_"):
			BodyFit.wear(sprite, sprite.get_meta("fit_path"), layer, _appearance)
	_show_features()
	_hood_color = Appearance.hood(appearance)
	_update_hood()


## Shows each feature layer the character has; a helmet hides hair and horns.
func _show_features() -> void:
	var helmeted := _layers["helmet"].visible or _layers["hood"].visible
	var slots: Array[String] = []
	for feature in Appearance.FEATURES:
		slots.append(feature[0])
	slots.append_array(Appearance.RACE_LAYERS)
	for slot: String in slots:
		var sprite := _layers["look_" + slot]
		if not _features.has(slot) or (helmeted and slot in UNDER_HELMET):
			sprite.visible = false
			continue
		BodyFit.wear(sprite, "looks/" + _features[slot]["sheet"], "look_" + slot, _appearance)
		BodyFit.follow(sprite, self)
		sprite.visible = true
		var look_material := sprite.material as ShaderMaterial
		Appearance.apply_tint(look_material, _features[slot])
		look_material.set_shader_parameter("rarity_color", Color.BLACK)
		look_material.set_shader_parameter("outline_mix", 0.0)
		look_material.set_shader_parameter("glow", 0.0)


var _hood_color := Color.TRANSPARENT


## A look's hood shows when no helmet hides it.
func _update_hood() -> void:
	var sprite := _layers["hood"]
	if _hood_color.a == 0.0 or _layers["helmet"].visible:
		sprite.visible = false
		return
	BodyFit.wear(sprite, "layers/hood", "hood", _appearance)
	BodyFit.follow(sprite, self)
	sprite.visible = true
	var hood_material := sprite.material as ShaderMaterial
	hood_material.set_shader_parameter("tint", _hood_color)
	hood_material.set_shader_parameter("rarity_color", Color.BLACK)
	hood_material.set_shader_parameter("outline_mix", 0.0)
	hood_material.set_shader_parameter("glow", 0.0)


## Each kind of weapon's own blow: [quick attack, heavy attack]. Swords and
## the like keep the plain swing and the big wind-up.
const ATTACK_ROWS := {
	"spears": ["thrust", "thrust"], "daggers": ["thrust", "attack"], "axes": ["attack", "smash"],
	"greatswords": ["attack", "smash"], "bows": ["shoot", "shoot"], "staves": ["cast", "cast"],
	# By the weapon's own look, where it differs from its kind.
	"halberd": ["thrust", "smash"], "club": ["smash", "smash"],
}


## Plays the blow for what is in hand, fitted into `duration` seconds.
## `heavy` uses the bigger wind-up meant for abilities.
func play_attack(duration: float, heavy: bool = false) -> void:
	var rows: Array = ATTACK_ROWS.get(_held_type(), ["attack", "heavy"])
	_busy = rows[1] if heavy else rows[0]
	if not sprite_frames or not sprite_frames.has_animation(_busy):
		_busy = "heavy" if heavy else "attack"
	# The blow faces where it is aimed (mirrored left or right).
	if _player and not _player.swimming:
		_view = view_of(_player.facing)
		_busy = _viewed(_busy)
	_play_for(_busy, duration, true)


func _held_type() -> String:
	if _player == null or _player.equipment == null or _player.equipment.weapon() == null:
		return ""
	var definition := _player.equipment.weapon().definition()
	var look := str(definition.get("visual", ""))
	if ATTACK_ROWS.has(look):
		return look
	return str(definition.get("weapon", {}).get("type", ""))


func play_hurt() -> void:
	if _busy in ["death", "rebirth"]:
		return
	_busy = "hurt"
	_play_for("hurt", SheetAnimations.seconds(sprite_frames, "hurt"), true)


func play_death() -> void:
	_busy = "death"
	_play_for("death", SheetAnimations.seconds(sprite_frames, "death"), true)


func play_rebirth() -> void:
	_busy = "rebirth"
	_play_for("rebirth", SheetAnimations.seconds(sprite_frames, "rebirth"), true)


func _choose_animation(delta: float) -> void:
	if _player.falling:
		# Falling: tumbling over and over (the dash's quarter turns).
		if animation != "dodge":
			play("dodge")
		pause()
		frame = 1 + int(Time.get_ticks_msec() / 110) % 4
		_busy = ""
		return
	match _player.state:
		Player.State.DEAD, Player.State.REVIVING:
			return
		Player.State.GATHER:
			# Keep swinging for as long as the work takes.
			var swing := _viewed("attack")
			if animation != swing or not is_playing():
				_play_for(swing, 0.55, true)
			_busy = ""
			return
		Player.State.DODGE:
			_play_for("dodge", _player.dodge_duration)
			_busy = ""
			_ghost_left -= delta
			if _ghost_left <= 0.0:
				_ghost_left = GHOST_INTERVAL
				_spawn_ghost()
			return
	if _busy != "":
		return
	var speed := _player.velocity.length()
	speed_scale = 1.0
	if _player.mount_id != "":
		# Sitting astride, bobbing faster as the mount picks up pace.
		speed_scale = 2.2 if speed > 20.0 else 1.0
		_loop("ride")
		return
	if _player.swimming:
		# A slow paddling stroke, still while treading water.
		speed_scale = 0.55 if speed > 20.0 else 0.25
		_loop("walk")
		return
	if speed > 20.0:
		_view = view_of(_player.velocity)
	var suffix := "" if _view == "front" else "_" + _view
	if speed > RUN_SPEED:
		# Legs keep pace with how fast the player actually moves.
		speed_scale = clampf(speed / 200.0, 0.7, 1.8)
		_loop("run" + suffix)
	elif speed > 20.0:
		_loop("walk" + suffix)
	elif _view == "front":
		# At rest facing us: the class's own stance.
		var stance := "idle_" + _player.class_id
		_loop(stance if sprite_frames.has_animation(stance) else "idle")
	else:
		_loop("idle" + suffix)


## Which way the player was last seen going (see view_of).
var _view := "front"


func _loop(animation_name: String) -> void:
	if animation != animation_name:
		play(animation_name)
		_turn_behind_layers()


## Seen from behind, a cape, wings and tail hang over the back instead of
## behind the body.
func _turn_behind_layers() -> void:
	var from_behind := String(animation).ends_with("_back") or String(animation).ends_with("_bq")
	for layer in LAYERS:
		if layer["behind"] and _layers.has(layer["name"]):
			(_layers[layer["name"]] as CanvasItem).show_behind_parent = not from_behind
	# Seen from behind, what is held is in front of the body, away from us.
	if _layers.has("weapon"):
		_layers["weapon"].show_behind_parent = from_behind


func _play_for(animation_name: String, duration: float, restart: bool = false) -> void:
	if animation == animation_name and not restart:
		return
	speed_scale = SheetAnimations.seconds(sprite_frames, animation_name) / maxf(duration, 0.05)
	stop()
	play(animation_name)
	_turn_behind_layers()


func _on_animation_finished() -> void:
	if animation == "rebirth":
		rebirth_finished.emit()
	if animation == _busy and animation != "death":
		_busy = ""


## A weapon grows finer to look at as it grows stronger: grade 1 honed, 2
## gilded, 3 runed (tools/generate_people.py GRADES), by its level or its
## upgrades, whichever is further along.
const GRADE_LEVELS: Array[int] = [20, 45, 80]
const GRADE_UPGRADES: Array[int] = [2, 5, 8]


static func weapon_grade(item: Item) -> int:
	var grade := 0
	for k in 3:
		if item.level >= GRADE_LEVELS[k] or item.upgrade >= GRADE_UPGRADES[k]:
			grade = k + 1
	return grade


## The sheet for a weapon in hand at its grade (falling back to plain art).
static func weapon_sheet(item: Item) -> String:
	var base := "weapons/" + str(item.definition().get("visual", ""))
	var grade := weapon_grade(item)
	while grade > 0:
		var graded := "%s_g%d" % [base, grade]
		if ResourceLoader.exists("res://assets/sprites/%s.png" % graded):
			return graded
		grade -= 1
	return base


## Shows `item` on a layer using the sheet at assets/sprites/<path>.png, or
## hides the layer when item is null. Metal layers are tinted by tier.
## While a shield is raised it is drawn by ShieldGuard, so the one carried
## in the hand is hidden.
var _guarding := false


func set_guarding(on: bool) -> void:
	_guarding = on
	if _layers.has("shield") and _layers["shield"].get_meta("worn", false):
		_layers["shield"].visible = not on


func _set_layer(layer: String, item: Item, path: String, tier_tint: bool = true, tint: Color = Color.WHITE) -> void:
	var sprite := _layers[layer]
	if item == null or path == "" or path.ends_with("/"):
		sprite.visible = false
		sprite.set_meta("worn", false)
		return
	BodyFit.wear(sprite, path, layer, _appearance)
	BodyFit.follow(sprite, self)
	sprite.visible = not (layer == "shield" and _guarding)
	sprite.set_meta("worn", true)
	sprite.set_meta("sheet", path)
	sprite.set_meta("tint", ItemDB.tier_color(item.tier_level()) if tier_tint else tint)
	var material := sprite.material as ShaderMaterial
	# Worn gear is drawn as part of the body: its own metal, a plain dark
	# outline, no coloured edge or glow. Rarity shows in the aura underfoot.
	material.set_shader_parameter("tint", ItemDB.tier_color(item.tier_level()) if tier_tint else tint)
	material.set_shader_parameter("rarity_color", item.color())
	material.set_shader_parameter("outline_mix", 0.0)
	material.set_shader_parameter("glow", 0.0)
	# Only the weapon in hand shows its rarity, and only as a passing gleam.
	var look: Array = RARITY_LOOK[clampi(item.rarity, 0, RARITY_LOOK.size() - 1)] if layer == "weapon" and item.is_equipment() else [0.0, 5.0, 0.0]
	# The finest armour is trimmed and runed even before the smith touches it.
	var marks := item.upgrade
	if layer in ["helmet", "chest", "legs", "boots", "shoulders"]:
		marks = maxi(marks, int(RARITY_TRIM.get(item.rarity, 0)))
	material.set_shader_parameter("upgrade", float(marks))
	sprite.set_meta("upgrade", marks)
	material.set_shader_parameter("glint", look[0])
	material.set_shader_parameter("glint_period", look[1])
	material.set_shader_parameter("sparkle", look[2])


## What is worn, for others to see it on this player: [{"l": layer,
## "s": sheet, "t": tint}], in drawing order.
func worn() -> Array:
	var out: Array = []
	for layer in LAYERS:
		var name: String = layer["name"]
		if name.begins_with("look_") or not _layers.has(name):
			continue
		var sprite: AnimatedSprite2D = _layers[name]
		if sprite.get_meta("worn", false):
			out.append({"l": name, "s": str(sprite.get_meta("sheet", "")), "t": sprite.get_meta("tint", Color.WHITE), "u": int(sprite.get_meta("upgrade", 0))})
	return out


func _spawn_ghost() -> void:
	var ghost := Sprite2D.new()
	ghost.texture = sprite_frames.get_frame_texture(animation, frame)
	ghost.global_position = global_position
	ghost.scale = global_scale
	ghost.modulate = Color(0.7, 0.85, 1.0, 0.45)
	_player.get_parent().add_child(ghost)
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.25)
	tween.tween_callback(ghost.queue_free)
