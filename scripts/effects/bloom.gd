class_name Bloom
extends WorldEnvironment
## A soft glow round bright things (fire, magic, lit windows), when bloom
## is turned on in the graphics settings and shaders are Full (High and
## Ultra): the glow blurs the whole screen several times over, the dearest
## effect there is on a phone, so Normal goes without it.


func _ready() -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_CANVAS
	environment.glow_enabled = false
	environment.glow_intensity = 0.55
	environment.glow_strength = 0.9
	environment.glow_bloom = 0.04
	environment.glow_hdr_threshold = 0.82
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	GameSettings.graphics_changed.connect(_apply)
	_apply()


func _apply() -> void:
	environment.glow_enabled = GameSettings.bloom and GameSettings.shader_level() >= 2
