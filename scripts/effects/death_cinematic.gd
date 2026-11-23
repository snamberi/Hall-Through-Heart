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
	flash.tween_method(_set_effect.bind("flash"), 0.08 if GameSettings.reduce_flashes else 0.25, 0.0, 0.4)
	await tween.finished
	_rect.visible = false


## A boss steps in: black bars slide over the top and bottom of the
## screen, time slows, the camera glides to the boss and holds while its
## name is set out on a card, then everything returns to the player.
## Once per boss each time it is fought.
var _bars: Array[ColorRect] = []
var _card: Label
var _sub: Label
var _busy := false


func play_boss_intro(player: Player, boss: Node2D, title: String, words: String) -> void:
	if _busy or player == null or not is_instance_valid(boss):
		return
	_busy = true
	_ensure_bars()
	var camera := player.camera
	var home := camera.offset
	var toward := (boss.global_position - player.global_position).limit_length(320.0)
	Engine.time_scale = 0.4
	var show := _tween().set_parallel()
	for k in 2:
		var bar := _bars[k]
		bar.visible = true
		var shut := -bar.size.y if k == 0 else get_viewport().get_visible_rect().size.y
		var open := 0.0 if k == 0 else get_viewport().get_visible_rect().size.y - bar.size.y
		bar.position.y = shut
		show.tween_property(bar, "position:y", open, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	show.tween_property(camera, "offset", home + toward, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await show.finished
	_card.text = title.to_upper()
	_sub.text = words
	_card.visible = true
	_sub.visible = true
	_card.modulate.a = 0.0
	_sub.modulate.a = 0.0
	var words_in := _tween().set_parallel()
	words_in.tween_property(_card, "modulate:a", 1.0, 0.35)
	words_in.tween_property(_sub, "modulate:a", 1.0, 0.6)
	Audio.play("level_up", -4.0, 0.0)
	await _real_seconds(1.5)
	var back := _tween().set_parallel()
	back.tween_property(camera, "offset", home, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	back.tween_property(_card, "modulate:a", 0.0, 0.4)
	back.tween_property(_sub, "modulate:a", 0.0, 0.4)
	for k in 2:
		var bar := _bars[k]
		back.tween_property(bar, "position:y", -bar.size.y if k == 0 else get_viewport().get_visible_rect().size.y, 0.5)
	Engine.time_scale = 1.0
	await back.finished
	for bar in _bars:
		bar.visible = false
	_card.visible = false
	_sub.visible = false
	_busy = false


## A boss falls: a beat of slow time and its end set out on the card.
func play_boss_fall(title: String) -> void:
	if _busy:
		return
	_busy = true
	_ensure_bars()
	Engine.time_scale = 0.3
	_card.text = "VANQUISHED"
	_sub.text = title
	_card.visible = true
	_sub.visible = true
	_card.modulate.a = 1.0
	_sub.modulate.a = 1.0
	await _real_seconds(0.9)
	Engine.time_scale = 1.0
	var out := _tween().set_parallel()
	out.tween_property(_card, "modulate:a", 0.0, 0.8)
	out.tween_property(_sub, "modulate:a", 0.0, 0.8)
	await out.finished
	_card.visible = false
	_sub.visible = false
	_busy = false


func _ensure_bars() -> void:
	if not _bars.is_empty():
		return
	var view := get_viewport().get_visible_rect().size
	for k in 2:
		var bar := ColorRect.new()
		bar.color = Color(0.0, 0.0, 0.0, 0.92)
		bar.size = Vector2(view.x, roundf(view.y * 0.11))
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.visible = false
		add_child(bar)
		_bars.append(bar)
	_card = Label.new()
	_card.add_theme_font_override("font", UITheme.bold())
	_card.add_theme_font_size_override("font_size", 40)
	_card.add_theme_color_override("font_color", Color(0.96, 0.82, 0.5))
	_card.add_theme_color_override("font_outline_color", Color(0.1, 0.02, 0.03))
	_card.add_theme_constant_override("outline_size", 10)
	_card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card.size = Vector2(view.x, 56)
	_card.position = Vector2(0, view.y * 0.62)
	_card.visible = false
	add_child(_card)
	_sub = Label.new()
	_sub.add_theme_font_size_override("font_size", 17)
	_sub.add_theme_color_override("font_color", Color(0.85, 0.8, 0.86))
	_sub.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_sub.add_theme_constant_override("outline_size", 6)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.size = Vector2(view.x, 28)
	_sub.position = Vector2(0, view.y * 0.62 + 54)
	_sub.visible = false
	add_child(_sub)


func _set_effect(value: float, parameter: String) -> void:
	_material.set_shader_parameter(parameter, value)


func _tween() -> Tween:
	return create_tween().set_ignore_time_scale(true)


func _real_seconds(seconds: float) -> Signal:
	return get_tree().create_timer(seconds, true, false, true).timeout


func _spawn_death_motes(player: Player) -> void:
	var motes := CPUParticles2D.new()
	motes.amount = GameSettings.particle_amount(28)
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
