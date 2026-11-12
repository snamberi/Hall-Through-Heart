class_name PlayerAnimator
extends AnimatedSprite2D
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
	{"name": "idle", "frames": 4, "fps": 6.0, "loop": true},
	{"name": "walk", "frames": 8, "fps": 11.0, "loop": true},
	{"name": "run", "frames": 8, "fps": 12.0, "loop": true},
	{"name": "attack", "frames": 6, "fps": 15.0, "loop": false},
	{"name": "heavy", "frames": 8, "fps": 13.0, "loop": false},
	{"name": "dodge", "frames": 7, "fps": 16.0, "loop": false},
	{"name": "hurt", "frames": 3, "fps": 12.0, "loop": false},
	{"name": "death", "frames": 8, "fps": 10.0, "loop": false},
	{"name": "rebirth", "frames": 8, "fps": 8.0, "loop": false},
	{"name": "ride", "frames": 4, "fps": 5.0, "loop": true},
]
## Below this speed the player walks rather than runs, in pixels/second.
const RUN_SPEED := 150.0

## Layers over the body, back to front: first the character's own features
## (hair, ears, horns... see Appearance), then what they wear. "behind"
## layers draw under the body.
const LAYERS: Array[Dictionary] = [
	{"name": "look_tail", "behind": true},
	{"name": "look_wings", "behind": true},
	{"name": "cape", "behind": true},
	{"name": "look_ears", "behind": false},
	{"name": "look_eyes", "behind": false},
	{"name": "look_mark", "behind": false},
	{"name": "look_beard", "behind": false},
	{"name": "look_hair", "behind": false},
	{"name": "look_horns", "behind": false},
	{"name": "chest", "behind": false},
	{"name": "shoulders", "behind": false},
	{"name": "helmet", "behind": false},
	{"name": "hood", "behind": false},
	{"name": "shield", "behind": false},
	{"name": "weapon", "behind": false},
]
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
uniform vec4 rarity_color : source_color = vec4(1.0);
uniform float outline_mix = 0.0;
uniform float glow = 0.0;
uniform float glint = 0.0;
uniform float glint_period = 5.0;
uniform float sparkle = 0.0;
uniform float water_line = 9999.0;
varying float local_y;
varying vec2 local_pos;

void vertex() {
	local_y = VERTEX.y;
	local_pos = VERTEX;
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
			sprite.animation = animation
			sprite.frame = frame
	if _aura_color.a > 0.0:
		queue_redraw()
	# Sink while swimming (deeper in deep water) and bob with each stroke;
	# the water line is drawn over the body.
	_water.visible = _player.swimming
	if _player.swimming:
		var sink := 19.0 if _player.deep_water else 13.0
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
	draw_circle(Vector2.ZERO, 24.0, Color(_aura_color, 0.07))
	draw_arc(Vector2.ZERO, 24.0, 0.0, TAU, 32, Color(_aura_color, 0.32), 1.0)
	var cycle := fmod(t, 4.0) / 4.0
	if cycle < 0.22:
		var head := PI * 0.5 + cycle / 0.22 * TAU
		draw_arc(Vector2.ZERO, 24.0, head - 0.9, head, 10, Color(_aura_color.lightened(0.4), 0.85 * (1.0 - cycle / 0.22 * 0.5)), 2.0)
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
	_water.draw_polyline(surface, Color(0.8, 0.92, 1.0, 0.8), 1.5)
	# Rings spreading from the swimmer.
	_water.draw_set_transform(Vector2(0.0, line), 0.0, Vector2(1.0, 0.32))
	for k in 2:
		var phase := fposmod(t * 0.9 + k * 0.5, 1.0)
		_water.draw_arc(Vector2.ZERO, 11.0 + phase * 8.0, 0.0, TAU, 28, Color(0.7, 0.85, 0.95, 0.5 * (1.0 - phase)), 1.5)
	_water.draw_set_transform(Vector2.ZERO)
	# A few bubbles in deep water.
	if deep:
		for k in 3:
			var rise := fposmod(t * 0.7 + k * 0.33, 1.0)
			_water.draw_circle(Vector2(-8.0 + k * 8.0, line + 16.0 - rise * 14.0), 1.2, Color(0.8, 0.92, 1.0, 0.7 * (1.0 - rise)))


## A ring left behind on the water as the player swims.
func _spawn_ripple() -> void:
	var ring := Node2D.new()
	ring.global_position = _player.global_position + Vector2(0, 2)
	ring.z_index = -1
	var radius := [6.0]
	ring.draw.connect(func() -> void:
		ring.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
		ring.draw_arc(Vector2.ZERO, radius[0], 0.0, TAU, 24, Color(0.75, 0.88, 0.95, 0.7), 1.5)
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
	drops.amount = 16
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
		_set_layer("weapon", held, "weapons/" + str(held.definition().get("visual", "")) if held else "", false)
	# A shield stays on the back while both hands are busy.
	var both_hands: bool = held != null and (held.is_tool() or held.definition().get("two_handed", false))
	_set_layer("shield", null if both_hands else equipment.get_item("off_hand"), "layers/shield")
	_set_layer("helmet", equipment.get_item("helmet") if show_helmet else null, "layers/helmet")
	var chest := equipment.get_item("chest")
	_set_layer("chest", chest, "layers/chest")
	_set_layer("shoulders", chest if chest and chest.rarity >= SHOULDERS_FROM_RARITY else null, "layers/shoulders")
	_set_layer("cape", chest if chest and chest.rarity >= CAPE_FROM_RARITY else null, "layers/cape")
	if _layers["cape"].visible:
		# The cape takes the rarity colour itself rather than the metal's.
		(_layers["cape"].material as ShaderMaterial).set_shader_parameter("tint", chest.color().darkened(0.15))

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
const UNDER_HELMET: Array[String] = ["hair", "horns"]
var _features: Dictionary = {}


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
	scale = Appearance.body_scale(appearance)
	_rest_y = -23.0 * scale.y
	position.y = _rest_y
	self_modulate.a = Appearance.alpha(appearance)
	_features = Appearance.layers(appearance)
	_show_features()
	_hood_color = Appearance.hood(appearance)
	_update_hood()


## Shows each feature layer the character has; a helmet hides hair and horns.
func _show_features() -> void:
	var helmeted := _layers["helmet"].visible or _layers["hood"].visible
	for feature in Appearance.FEATURES:
		var slot: String = feature[0]
		var sprite := _layers["look_" + slot]
		if not _features.has(slot) or (helmeted and slot in UNDER_HELMET):
			sprite.visible = false
			continue
		var path: String = "looks/" + _features[slot]["sheet"]
		if not _frames_cache.has(path):
			_frames_cache[path] = SheetAnimations.build(load("res://assets/sprites/%s.png" % path), FRAME_SIZE, ROWS)
		sprite.sprite_frames = _frames_cache[path]
		sprite.animation = animation
		sprite.frame = frame
		sprite.visible = true
		var look_material := sprite.material as ShaderMaterial
		look_material.set_shader_parameter("tint", _features[slot]["tint"])
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
	var path := "layers/hood"
	if not _frames_cache.has(path):
		_frames_cache[path] = SheetAnimations.build(load("res://assets/sprites/layers/hood.png"), FRAME_SIZE, ROWS)
	sprite.sprite_frames = _frames_cache[path]
	sprite.animation = animation
	sprite.frame = frame
	sprite.visible = true
	var hood_material := sprite.material as ShaderMaterial
	hood_material.set_shader_parameter("tint", _hood_color)
	hood_material.set_shader_parameter("rarity_color", Color.BLACK)
	hood_material.set_shader_parameter("outline_mix", 0.0)
	hood_material.set_shader_parameter("glow", 0.0)


## Plays the swing, fitted into `duration` seconds. `heavy` uses the bigger
## wind-up meant for abilities.
func play_attack(duration: float, heavy: bool = false) -> void:
	_busy = "heavy" if heavy else "attack"
	_play_for(_busy, duration, true)


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
	match _player.state:
		Player.State.DEAD, Player.State.REVIVING:
			return
		Player.State.GATHER:
			# Keep swinging for as long as the work takes.
			if animation != "attack" or not is_playing():
				_play_for("attack", 0.55, true)
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
	if speed > RUN_SPEED:
		# Legs keep pace with how fast the player actually moves.
		speed_scale = clampf(speed / 200.0, 0.7, 1.8)
		_loop("run")
	elif speed > 20.0:
		_loop("walk")
	else:
		_loop("idle")


func _loop(animation_name: String) -> void:
	if animation != animation_name:
		play(animation_name)


func _play_for(animation_name: String, duration: float, restart: bool = false) -> void:
	if animation == animation_name and not restart:
		return
	speed_scale = SheetAnimations.seconds(sprite_frames, animation_name) / maxf(duration, 0.05)
	stop()
	play(animation_name)


func _on_animation_finished() -> void:
	if animation == "rebirth":
		rebirth_finished.emit()
	if animation == _busy and animation != "death":
		_busy = ""


## Shows `item` on a layer using the sheet at assets/sprites/<path>.png, or
## hides the layer when item is null. Metal layers are tinted by tier.
func _set_layer(layer: String, item: Item, path: String, tier_tint: bool = true, tint: Color = Color.WHITE) -> void:
	var sprite := _layers[layer]
	if item == null or path == "" or path.ends_with("/"):
		sprite.visible = false
		return
	if not _frames_cache.has(path):
		var sheet: Texture2D = load("res://assets/sprites/%s.png" % path)
		_frames_cache[path] = SheetAnimations.build(sheet, FRAME_SIZE, ROWS)
	sprite.sprite_frames = _frames_cache[path]
	sprite.animation = animation
	sprite.frame = frame
	sprite.visible = true
	var material := sprite.material as ShaderMaterial
	# Worn gear is drawn as part of the body: its own metal, a plain dark
	# outline, no coloured edge or glow. Rarity shows in the aura underfoot.
	material.set_shader_parameter("tint", ItemDB.tier_color(item.level) if tier_tint else tint)
	material.set_shader_parameter("rarity_color", item.color())
	material.set_shader_parameter("outline_mix", 0.0)
	material.set_shader_parameter("glow", 0.0)
	# Only the weapon in hand shows its rarity, and only as a passing gleam.
	var look: Array = RARITY_LOOK[clampi(item.rarity, 0, RARITY_LOOK.size() - 1)] if layer == "weapon" and item.is_equipment() else [0.0, 5.0, 0.0]
	material.set_shader_parameter("glint", look[0])
	material.set_shader_parameter("glint_period", look[1])
	material.set_shader_parameter("sparkle", look[2])


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
