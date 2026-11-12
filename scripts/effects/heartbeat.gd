class_name Heartbeat
extends CanvasLayer
## The player's heart. It beats slowly when all is well and races when it
## is not: wounded, hunted, face to face with something huge. You hear it
## when it quickens, the edges of the world pulse red with it when life is
## low, and the heart on the health bar beats in time.
##
## A racing heart lends speed; a steady one, at rest, mends the body.

const SHADER := """
shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float pulse = 0.0;
uniform float danger = 0.0;

void fragment() {
	vec4 seen = texture(screen, SCREEN_UV);
	// Colour drains from the world as life does.
	float grey = dot(seen.rgb, vec3(0.299, 0.587, 0.114));
	seen.rgb = mix(seen.rgb, vec3(grey), danger * 0.5);
	float edge = smoothstep(0.3, 0.95, distance(UV, vec2(0.5)) * 1.3);
	seen.rgb = mix(seen.rgb, vec3(0.5, 0.02, 0.04), edge * danger * (0.3 + 0.5 * pulse));
	COLOR = seen;
}
"""
const REST_BPM := 54.0
const TOP_BPM := 156.0

## The beat just now, 1 at the thump and falling to 0: for anything that
## wants to move in time (the heart on the health bar).
static var pulse := 0.0
## How hard the heart is working, 0 (at peace) to 1 (terror).
static var tension := 0.0
## Beats per minute, for display.
static var bpm := REST_BPM

var _player: Player
var _rect: ColorRect
var _material: ShaderMaterial
var _to_beat := 0.5
var _second := false
var _calm := 0.0
var _racing := 0.0
var _mood_left := 0.0


func setup(player: Player) -> void:
	_player = player
	layer = 1
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var shader := Shader.new()
	shader.code = SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader
	_rect = ColorRect.new()
	_rect.material = _material
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.visible = false
	add_child(_rect)
	tension = 0.0
	pulse = 0.0


func _process(delta: float) -> void:
	if _player == null:
		return
	var wanted := 0.0 if _player.is_dead() else _read_tension()
	# The heart quickens fast and settles slowly.
	tension = move_toward(tension, wanted, delta * (1.6 if wanted > tension else 0.22))
	bpm = lerpf(REST_BPM, TOP_BPM, tension)
	pulse = maxf(pulse - delta * 4.5, 0.0)
	_to_beat -= delta
	if _to_beat <= 0.0 and not _player.is_dead():
		_to_beat = 60.0 / bpm
		pulse = 1.0
		# Heard only once it is working; louder and tighter the harder it goes.
		if tension > 0.22:
			Audio.play("heartbeat", lerpf(-22.0, -3.0, tension), 0.02)
	var life := _player.health.current / maxf(_player.health.max_health, 1.0)
	var danger := 0.0 if _player.is_dead() else clampf((0.4 - life) / 0.4, 0.0, 1.0)
	_rect.visible = danger > 0.01
	if _rect.visible:
		_material.set_shader_parameter("danger", danger)
		_material.set_shader_parameter("pulse", pulse)
	_moods(delta)


## How much there is to fear right now.
func _read_tension() -> float:
	var life := _player.health.current / maxf(_player.health.max_health, 1.0)
	var fear := clampf((0.6 - life) / 0.6, 0.0, 1.0) * 0.75
	# Things that are after you, weighed by how bad they are.
	var hunted := 0.0
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.health.is_dead() or enemy.is_wild():
			continue
		var distance := enemy.global_position.distance_to(_player.global_position)
		if distance > 420.0 or enemy.state == Enemy.State.WANDER:
			continue
		hunted += [0.14, 0.26, 0.4, 0.6, 0.9][enemy.rank] * (1.0 - distance / 520.0)
	fear += minf(hunted, 0.75)
	if _player.since_hurt < 2.5:
		fear += 0.15
	if _player.sprinting and _player.velocity.length() > 150.0:
		fear += 0.08
	if DayNight.blood_moon:
		fear += 0.1
	return clampf(fear, 0.0, 1.0)


## A racing heart lends speed; a steady one mends.
func _moods(delta: float) -> void:
	_racing = _racing + delta if tension > 0.68 else 0.0
	_calm = _calm + delta if tension < 0.1 and _player.velocity.length() < 10.0 else 0.0
	_mood_left -= delta
	if _mood_left > 0.0 or _player.is_dead():
		return
	_mood_left = 1.0
	if _racing > 2.0:
		_player.buffs.add("heart", "Racing heart", 2.2, {"attack_speed": {"percent": 0.08}, "move_speed": {"percent": 0.06}})
	elif _calm > 10.0:
		_player.buffs.add("heart", "Steady heart", 2.2, {"health_regen": {"flat": 1.5}})
