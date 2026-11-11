class_name Atmosphere
extends CanvasLayer
## Weather and mood: drifting fog over the land, a darkening at the edges of
## the view, and particles in the air that suit the ground underfoot -
## snow, ash, spores, motes from the void, fireflies after dark.

const FOG_SHADER := """
shader_type canvas_item;
uniform sampler2D noise : repeat_enable, filter_linear;
uniform vec4 tint : source_color = vec4(0.8, 0.82, 0.85, 1.0);
uniform float density = 0.15;
uniform vec2 drift = vec2(0.0);
uniform float vignette = 0.35;

void fragment() {
	vec2 uv = UV * vec2(1.6, 0.9);
	float a = texture(noise, uv * 0.9 + drift).r;
	float b = texture(noise, uv * 1.7 - drift * 1.4 + vec2(0.3, 0.7)).r;
	float fog = smoothstep(0.35, 0.85, a * 0.65 + b * 0.45) * density;
	float edge = smoothstep(0.45, 0.95, distance(UV, vec2(0.5)) * 1.35) * vignette;
	COLOR = vec4(mix(tint.rgb, vec3(0.0), edge / max(fog + edge, 0.001) * step(0.001, edge)), clamp(fog + edge, 0.0, 0.85));
}
"""
## Per terrain: fog colour, fog thickness, and the particle kind.
const WEATHER := {
	TerrainTiles.Type.BOG: [Color(0.7, 0.8, 0.65), 0.32, "spores"],
	TerrainTiles.Type.FUNGAL: [Color(0.85, 0.7, 0.9), 0.3, "spores"],
	TerrainTiles.Type.TAR: [Color(0.4, 0.38, 0.42), 0.34, ""],
	TerrainTiles.Type.VOIDSCAR: [Color(0.55, 0.42, 0.8), 0.36, "void"],
	TerrainTiles.Type.ASH: [Color(0.6, 0.58, 0.58), 0.24, "ash"],
	TerrainTiles.Type.CINDER: [Color(0.7, 0.45, 0.35), 0.22, "embers"],
	TerrainTiles.Type.SNOW: [Color(0.9, 0.93, 0.97), 0.22, "snow"],
	TerrainTiles.Type.FROSTPINE: [Color(0.85, 0.9, 0.95), 0.2, "snow"],
	TerrainTiles.Type.PEAK: [Color(0.92, 0.94, 0.98), 0.28, "snow"],
	TerrainTiles.Type.SAND: [Color(0.85, 0.75, 0.55), 0.14, "dust"],
	TerrainTiles.Type.SALT: [Color(0.92, 0.9, 0.86), 0.16, "dust"],
	TerrainTiles.Type.CRIMSON: [Color(0.75, 0.5, 0.55), 0.2, "spores"],
	TerrainTiles.Type.DARK_GRASS: [Color(0.75, 0.82, 0.75), 0.16, "leaves"],
}
const PARTICLES := {
	"snow": {"color": Color(1, 1, 1, 0.9), "gravity": Vector2(-12, 40), "speed": 20.0, "size": 2.5, "amount": 120},
	"ash": {"color": Color(0.75, 0.72, 0.72, 0.8), "gravity": Vector2(10, 18), "speed": 15.0, "size": 2.0, "amount": 80},
	"embers": {"color": Color(1.0, 0.6, 0.25, 0.9), "gravity": Vector2(6, -30), "speed": 20.0, "size": 2.0, "amount": 60},
	"spores": {"color": Color(0.85, 0.95, 0.7, 0.7), "gravity": Vector2(4, -6), "speed": 10.0, "size": 2.0, "amount": 60},
	"void": {"color": Color(0.75, 0.55, 1.0, 0.85), "gravity": Vector2(0, -12), "speed": 12.0, "size": 2.0, "amount": 70},
	"dust": {"color": Color(0.9, 0.82, 0.62, 0.6), "gravity": Vector2(40, 2), "speed": 30.0, "size": 2.0, "amount": 50},
	"leaves": {"color": Color(0.55, 0.75, 0.4, 0.85), "gravity": Vector2(14, 22), "speed": 15.0, "size": 2.5, "amount": 30},
	"fireflies": {"color": Color(0.9, 1.0, 0.5, 1.0), "gravity": Vector2(0, 0), "speed": 18.0, "size": 2.0, "amount": 40},
}

var _player: Player
var _world: World
var _day_night: DayNight
var _fog: ColorRect
var _material: ShaderMaterial
var _particles: CPUParticles2D
var _kind := ""
var _check_left := 0.0
var _density := 0.1
var _target_density := 0.1
var _tint := Color(0.8, 0.82, 0.85)
var _target_tint := Color(0.8, 0.82, 0.85)


func setup(player: Player, world: World, day_night: DayNight) -> void:
	_player = player
	_world = world
	_day_night = day_night
	layer = 1
	var noise := FastNoiseLite.new()
	noise.frequency = 0.012
	noise.fractal_octaves = 3
	var texture := NoiseTexture2D.new()
	texture.noise = noise
	texture.seamless = true
	texture.width = 256
	texture.height = 256
	var shader := Shader.new()
	shader.code = FOG_SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader
	_material.set_shader_parameter("noise", texture)
	_fog = ColorRect.new()
	_fog.material = _material
	_fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fog.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fog)
	_particles = CPUParticles2D.new()
	_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_particles.emission_rect_extents = Vector2(420, 260)
	_particles.lifetime = 6.0
	_particles.z_index = 40
	_particles.emitting = false
	player.add_child(_particles)


func _process(delta: float) -> void:
	if _player == null:
		return
	_check_left -= delta
	if _check_left <= 0.0:
		_check_left = 0.5
		_read_place()
	_density = lerpf(_density, _target_density, 0.6 * delta)
	_tint = _tint.lerp(_target_tint, 0.6 * delta)
	var t := Time.get_ticks_msec() / 1000.0
	_material.set_shader_parameter("density", _density)
	_material.set_shader_parameter("tint", _tint)
	# The fog drifts, and shifts as the player moves so it feels part of the land.
	_material.set_shader_parameter("drift", Vector2(t * 0.006, t * 0.002) + _player.global_position / 9000.0)
	_material.set_shader_parameter("vignette", 0.55 if _player.indoors else 0.28 + 0.25 * _day_night.darkness())


func _read_place() -> void:
	var kind := ""
	if _player.indoors:
		_target_density = 0.0
	else:
		var tile := _world.tile_type_at_position(_player.global_position)
		var weather: Array = WEATHER.get(tile, [Color(0.82, 0.84, 0.86), 0.1, ""])
		_target_tint = weather[0]
		# Mist gathers at dawn and in the dark.
		var hour_fog := 0.12 if _day_night.phase() in ["Dawn", "Dusk"] else 0.06 * _day_night.darkness()
		_target_density = weather[1] + hour_fog
		kind = weather[2]
		if _day_night.is_night() and tile in [TerrainTiles.Type.DARK_GRASS, TerrainTiles.Type.DEAD_GRASS, TerrainTiles.Type.BOG, TerrainTiles.Type.FUNGAL]:
			kind = "fireflies"
	if kind == _kind:
		return
	_kind = kind
	_particles.emitting = kind != ""
	if kind == "":
		return
	var settings: Dictionary = PARTICLES[kind]
	_particles.amount = settings["amount"]
	_particles.color = settings["color"]
	_particles.gravity = settings["gravity"]
	_particles.initial_velocity_min = settings["speed"] * 0.5
	_particles.initial_velocity_max = settings["speed"]
	_particles.direction = Vector2(0.3, 1.0) if kind in ["snow", "ash", "leaves"] else Vector2(0, -1)
	_particles.spread = 180.0 if kind in ["fireflies", "spores", "void"] else 25.0
	_particles.scale_amount_min = settings["size"] * 0.7
	_particles.scale_amount_max = settings["size"]
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.add_point(0.2, Color(1, 1, 1, 1))
	fade.add_point(0.8, Color(1, 1, 1, 1))
	fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0))
	_particles.color_ramp = fade
