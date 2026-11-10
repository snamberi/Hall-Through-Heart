extends CanvasLayer
## The death and rebirth sequences: slow motion, a camera push-in, the world
## draining of colour and fading to black, then light returning.
##
## The screen effect is a shader over everything below this layer; the HUD
## sits above it so messages stay readable.

const SHADER := """
shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float drain : hint_range(0.0, 1.0) = 0.0;
uniform float blackout : hint_range(0.0, 1.0) = 0.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec3 colour = texture(screen, SCREEN_UV).rgb;
	float grey = dot(colour, vec3(0.3, 0.59, 0.11));
	// Drain towards a cold, blood-tinted monochrome.
	colour = mix(colour, vec3(grey * 1.05, grey * 0.72, grey * 0.72), drain);
	float edge = distance(UV, vec2(0.5)) * 1.6;
	colour *= 1.0 - drain * smoothstep(0.35, 1.1, edge);
	colour = mix(colour, vec3(0.0), blackout);
	colour = mix(colour, vec3(1.0, 0.95, 0.8), flash);
	COLOR = vec4(colour, 1.0);
}
"""
const ZOOM_NORMAL := Vector2(2.0, 2.0)
const ZOOM_CLOSE := Vector2(3.0, 3.0)

var _material: ShaderMaterial
var _rect: ColorRect


func _ready() -> void:
	var shader := Shader.new()
	shader.code = SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader
	_rect = ColorRect.new()
	_rect.material = _material
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.visible = false
	add_child(_rect)


## Plays the death sequence and returns once the screen is black.
## `show_message` is called part-way through, when the death text should appear.
func play_death(player: Player, show_message: Callable) -> void:
	_rect.visible = true
	_spawn_death_motes(player)
	Engine.time_scale = 0.35

	var tween := _tween()
	tween.set_parallel()
	tween.tween_method(_set_effect.bind("drain"), 0.0, 1.0, 1.1)
	tween.tween_property(player.camera, "zoom", ZOOM_CLOSE, 1.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	await _real_seconds(0.6)
	Engine.time_scale = 1.0
	await _real_seconds(0.6)
	show_message.call()
	await _real_seconds(1.6)
	var fade := _tween()
	fade.tween_method(_set_effect.bind("blackout"), 0.0, 1.0, 0.8)
	await fade.finished
	await _real_seconds(0.4)


## Plays the rebirth sequence. Call after the player has been moved; returns
## when the player is back in control.
func play_rebirth(player: Player) -> void:
	player.camera.zoom = ZOOM_CLOSE
	LightPillar.spawn(player.get_parent(), player.global_position)
	player.begin_rebirth()

	var tween := _tween()
	tween.set_parallel()
	tween.tween_method(_set_effect.bind("blackout"), 1.0, 0.0, 0.7)
	tween.tween_method(_set_effect.bind("drain"), 1.0, 0.0, 1.4)
	tween.tween_property(player.camera, "zoom", ZOOM_NORMAL, 1.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)

	await player.rebirth_finished
	RingBurst.spawn(player.get_parent(), player.global_position + Vector2(0, -16), Color(1.0, 0.92, 0.65), 130.0)
	var flash := _tween()
	flash.tween_method(_set_effect.bind("flash"), 0.25, 0.0, 0.4)
	await tween.finished
	_rect.visible = false


func _set_effect(value: float, parameter: String) -> void:
	_material.set_shader_parameter(parameter, value)


func _tween() -> Tween:
	return create_tween().set_ignore_time_scale(true)


func _real_seconds(seconds: float) -> Signal:
	return get_tree().create_timer(seconds, true, false, true).timeout


func _spawn_death_motes(player: Player) -> void:
	var motes := CPUParticles2D.new()
	motes.amount = 28
	motes.lifetime = 1.6
	motes.one_shot = true
	motes.explosiveness = 0.1
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	motes.emission_sphere_radius = 14.0
	motes.direction = Vector2.UP
	motes.spread = 25.0
	motes.gravity = Vector2(0, -30.0)
	motes.initial_velocity_min = 10.0
	motes.initial_velocity_max = 45.0
	motes.scale_amount_min = 2.0
	motes.scale_amount_max = 3.0
	motes.color = Color(0.55, 0.08, 0.12, 0.9)
	motes.position = player.global_position + Vector2(0, -14)
	motes.z_index = 40
	player.get_parent().add_child(motes)
	motes.emitting = true
	get_tree().create_timer(4.0).timeout.connect(motes.queue_free)
