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
uniform vec2 anchor = vec2(0.0);
uniform float vignette = 0.35;

void fragment() {
	// Anchored to the land, so fog banks stay put as the player walks through them.
	vec2 uv = (UV + anchor) * vec2(1.6, 0.9);
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
## Weather fronts roll across the whole world; what a front means depends on
## the land under the player. Storminess 0 is clear, 1 is mild, 2 heavy.
##   climate -> [name at 1, name at 2]
const FRONTS := {
	"wet": ["Rain", "Thunderstorm"],
	"cold": ["Snowfall", "Blizzard"],
	"dry": ["Dust", "Sandstorm"],
	"ash": ["Ashfall", "Ash storm"],
}
## Fog, tint, and particles each weather brings.
const WEATHERS := {
	"Rain": {"fog": 0.12, "tint": Color(0.62, 0.68, 0.78), "particles": "rain"},
	"Thunderstorm": {"fog": 0.22, "tint": Color(0.42, 0.46, 0.58), "particles": "storm"},
	"Snowfall": {"fog": 0.12, "tint": Color(0.92, 0.95, 1.0), "particles": "snow_heavy"},
	"Blizzard": {"fog": 0.5, "tint": Color(0.94, 0.96, 1.0), "particles": "blizzard"},
	"Dust": {"fog": 0.12, "tint": Color(0.86, 0.76, 0.56), "particles": "dust"},
	"Sandstorm": {"fog": 0.48, "tint": Color(0.84, 0.7, 0.48), "particles": "sandstorm"},
	"Ashfall": {"fog": 0.14, "tint": Color(0.55, 0.52, 0.52), "particles": "ash"},
	"Ash storm": {"fog": 0.36, "tint": Color(0.5, 0.36, 0.3), "particles": "embers_heavy"},
}
## The weather where the player stands now ("" when clear).
static var weather := ""
static var _storminess := 0
const FRONT_SECONDS := Vector2(150.0, 320.0)

const PARTICLES := {
	"rain": {"color": Color(0.7, 0.8, 1.0, 0.55), "gravity": Vector2(80, 900), "speed": 420.0, "size": 1.0, "amount": 260, "streak": true},
	"storm": {"color": Color(0.7, 0.8, 1.0, 0.65), "gravity": Vector2(260, 1100), "speed": 560.0, "size": 1.0, "amount": 420, "streak": true},
	"snow_heavy": {"color": Color(1, 1, 1, 0.9), "gravity": Vector2(-20, 50), "speed": 30.0, "size": 2.5, "amount": 240},
	"blizzard": {"color": Color(1, 1, 1, 0.95), "gravity": Vector2(-260, 70), "speed": 120.0, "size": 3.0, "amount": 420},
	"sandstorm": {"color": Color(0.92, 0.8, 0.56, 0.75), "gravity": Vector2(300, 10), "speed": 160.0, "size": 2.5, "amount": 380},
	"embers_heavy": {"color": Color(1.0, 0.55, 0.25, 0.9), "gravity": Vector2(80, -30), "speed": 60.0, "size": 2.0, "amount": 200},
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
var _front_left := 60.0
var _strike_left := 6.0
var _chill_left := 3.0
var _flash: ColorRect
var _streak: Texture2D


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
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_flash)
	var image := Image.create(1, 8, false, Image.FORMAT_RGBA8)
	for y in 8:
		image.set_pixel(0, y, Color(1, 1, 1, y / 8.0))
	_streak = ImageTexture.create_from_image(image)
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
	_front_left -= delta
	if _front_left <= 0.0:
		_front_left = randf_range(FRONT_SECONDS.x, FRONT_SECONDS.y)
		var roll := randf()
		_storminess = 0 if roll < 0.5 else 1 if roll < 0.85 else 2
	_weather_effects(delta)
	_density = lerpf(_density, _target_density, 0.6 * delta)
	_tint = _tint.lerp(_target_tint, 0.6 * delta)
	var t := Time.get_ticks_msec() / 1000.0
	_material.set_shader_parameter("density", _density)
	_material.set_shader_parameter("tint", _tint)
	# The fog drifts slowly, and is pinned to the land rather than the screen.
	_material.set_shader_parameter("drift", Vector2(t * 0.006, t * 0.002))
	var camera := get_viewport().get_camera_2d()
	if camera:
		var view := get_viewport().get_visible_rect().size / camera.zoom
		_material.set_shader_parameter("anchor", camera.get_screen_center_position() / view)
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
		# Clear land keeps only a whisper of haze; marsh and ash still fog up.
		_target_density = weather[1] * 0.55 + hour_fog * 0.6
		kind = weather[2]
		Atmosphere.weather = _weather_for(tile)
		if Atmosphere.weather != "":
			var info: Dictionary = WEATHERS[Atmosphere.weather]
			_target_density += info["fog"]
			_target_tint = _target_tint.lerp(info["tint"], 0.7)
			kind = info["particles"]
		if _day_night.is_night() and tile in [TerrainTiles.Type.DARK_GRASS, TerrainTiles.Type.DEAD_GRASS, TerrainTiles.Type.BOG, TerrainTiles.Type.FUNGAL]:
			kind = "fireflies"
	if _player.indoors:
		Atmosphere.weather = ""
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
	_particles.texture = _streak if settings.get("streak", false) else null
	_particles.lifetime = 1.0 if settings.get("streak", false) else 6.0
	_particles.particle_flag_align_y = settings.get("streak", false)
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.add_point(0.2, Color(1, 1, 1, 1))
	fade.add_point(0.8, Color(1, 1, 1, 1))
	fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0))
	_particles.color_ramp = fade


func _weather_for(tile: int) -> String:
	if _storminess == 0:
		return ""
	var T := TerrainTiles.Type
	var climate := "wet"
	if tile in [T.SNOW, T.FROSTPINE, T.PEAK, T.SALT]:
		climate = "cold"
	elif tile in [T.SAND]:
		climate = "dry"
	elif tile in [T.ASH, T.CINDER, T.TAR]:
		climate = "ash"
	elif tile == T.VOIDSCAR:
		return ""
	return FRONTS[climate][_storminess - 1]


## What the weather does besides look: lightning in storms, cold in
## blizzards, wind in sandstorms.
func _weather_effects(delta: float) -> void:
	_flash.color.a = maxf(_flash.color.a - delta * 3.0, 0.0)
	if _player.indoors or _player.is_dead():
		return
	match Atmosphere.weather:
		"Thunderstorm":
			_strike_left -= delta
			if _strike_left <= 0.0:
				_strike_left = randf_range(4.0, 10.0)
				var at := _player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(0.0, 320.0)
				if randf() < 0.3:
					at = _player.global_position
				Lightning.strike(_player.get_parent(), at, _player, self)
		"Blizzard":
			_chill_left -= delta
			if _chill_left <= 0.0:
				_chill_left = 3.0
				if not _near_fire() and not (_player.mount_id != "" and Mount.MOUNTS[_player.mount_id].get("snow", false)):
					_player.apply_status("chill", 3.2, 0.25)
		"Sandstorm":
			if _player.state == Player.State.MOVE and not (_player.mount_id != "" and Mount.MOUNTS[_player.mount_id].get("sand", false)):
				_player.velocity += Vector2(70.0, 10.0) * delta * 6.0


func flash(strength: float = 0.6) -> void:
	_flash.color.a = strength * 0.6
	_day_night.lightning(minf(strength * 1.5, 1.0))


func _near_fire() -> bool:
	for node in get_tree().get_nodes_in_group("props"):
		var prop := node as Prop
		if prop and prop.global_position.distance_to(_player.global_position) < 160.0 and prop.find_children("*", "PointLight2D", false, false).size() > 0:
			return true
	return false
