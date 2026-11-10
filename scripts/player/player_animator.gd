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
]
## Below this speed the player walks rather than runs, in pixels/second.
const RUN_SPEED := 150.0

## Equipment layers, back to front. "behind" layers draw under the body.
const LAYERS: Array[Dictionary] = [
	{"name": "cape", "behind": true},
	{"name": "chest", "behind": false},
	{"name": "shoulders", "behind": false},
	{"name": "helmet", "behind": false},
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

void fragment() {
	vec4 pixel = texture(TEXTURE, UV);
	float outline = step(pixel.r + pixel.g + pixel.b, 0.125) * pixel.a;
	float pulse = 0.5 + 0.5 * sin(TIME * 5.0);
	vec3 body = COLOR.rgb * tint.rgb + rarity_color.rgb * glow * 0.3 * pulse;
	vec3 edge = rarity_color.rgb * (1.0 + glow * 0.6 * pulse);
	COLOR.rgb = mix(body, mix(COLOR.rgb, edge, outline_mix), outline);
}
"""
## Per rarity: how strongly the outline takes the rarity colour, and the shimmer.
const RARITY_LOOK: Array[Array] = [[0.0, 0.0], [0.75, 0.0], [1.0, 0.0], [1.0, 0.35], [1.0, 0.65], [1.0, 1.0]]
## Seconds between fading after-images while dodging.
const GHOST_INTERVAL := 0.04

## An animation that must finish before movement animations resume.
var _busy := ""
var _ghost_left := 0.0
var _layers: Dictionary[String, AnimatedSprite2D] = {}
var _aura_color := Color.TRANSPARENT

static var _frames_cache: Dictionary = {}

@onready var _player: Player = owner


func _ready() -> void:
	sprite_frames = SheetAnimations.build(SHEET, FRAME_SIZE, ROWS)
	animation_finished.connect(_on_animation_finished)
	play("idle")

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


func _process(delta: float) -> void:
	_choose_animation(delta)
	for sprite: AnimatedSprite2D in _layers.values():
		if sprite.visible:
			sprite.animation = animation
			sprite.frame = frame
	if _aura_color.a > 0.0:
		queue_redraw()


func _draw() -> void:
	if _aura_color.a <= 0.0:
		return
	# A soft pulsing glow on the ground under the feet.
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 250.0)
	draw_set_transform(Vector2(0, 23), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 24.0 + 3.0 * pulse, Color(_aura_color, 0.16 + 0.1 * pulse))
	draw_arc(Vector2.ZERO, 24.0 + 3.0 * pulse, 0.0, TAU, 32, Color(_aura_color, 0.55), 1.5)
	draw_set_transform(Vector2.ZERO)


## Redraws the visible equipment from what is worn.
func update_equipment(equipment: Equipment, show_helmet: bool) -> void:
	if _layers.is_empty():
		await ready
	var weapon := equipment.get_item("main_hand")
	_set_layer("weapon", weapon, "weapons/" + str(weapon.definition().get("visual", "")) if weapon else "", false)
	_set_layer("shield", equipment.get_item("off_hand"), "layers/shield")
	_set_layer("helmet", equipment.get_item("helmet") if show_helmet else null, "layers/helmet")
	var chest := equipment.get_item("chest")
	_set_layer("chest", chest, "layers/chest")
	_set_layer("shoulders", chest if chest and chest.rarity >= SHOULDERS_FROM_RARITY else null, "layers/shoulders")
	_set_layer("cape", chest if chest and chest.rarity >= CAPE_FROM_RARITY else null, "layers/cape")
	if _layers["cape"].visible:
		# The cape takes the rarity colour itself rather than the metal's.
		(_layers["cape"].material as ShaderMaterial).set_shader_parameter("tint", chest.color().darkened(0.15))

	var best: Item = null
	for item: Item in equipment.equipped.values():
		if item.rarity >= AURA_FROM_RARITY and (best == null or item.rarity > best.rarity):
			best = item
	_aura_color = best.color() if best else Color.TRANSPARENT
	queue_redraw()


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
func _set_layer(layer: String, item: Item, path: String, tier_tint: bool = true) -> void:
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
	var look: Array = RARITY_LOOK[item.rarity]
	material.set_shader_parameter("tint", ItemDB.tier_color(item.level) if tier_tint else Color.WHITE)
	material.set_shader_parameter("rarity_color", item.color())
	material.set_shader_parameter("outline_mix", look[0])
	material.set_shader_parameter("glow", look[1])


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
