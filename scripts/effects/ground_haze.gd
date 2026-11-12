class_name GroundHaze
extends Node2D
## Low haze lying on the land, drawn over the ground but under everything
## standing on it, pinned to the world so it drifts past as the player
## walks. Together with the foreground mist (see Atmosphere) it gives the
## view depth: the far layer sits on the ground, the near one floats past
## the camera faster, and neither covers the player or the fight.

const SHADER := """
shader_type canvas_item;
uniform sampler2D noise : repeat_enable, filter_linear;
uniform vec4 tint : source_color = vec4(0.8, 0.82, 0.85, 1.0);
uniform float density = 0.0;
varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float a = texture(noise, world / 1100.0 + vec2(TIME * 0.004, TIME * 0.001)).r;
	float b = texture(noise, world / 460.0 - vec2(TIME * 0.003, -TIME * 0.005)).r;
	float haze = smoothstep(0.42, 0.82, a * 0.6 + b * 0.5) * density;
	COLOR = vec4(tint.rgb, haze);
}
"""

var density := 0.0
var tint := Color(0.8, 0.82, 0.85)
var _material: ShaderMaterial


func setup(noise: Texture2D) -> void:
	z_as_relative = false
	z_index = -7
	var shader := Shader.new()
	shader.code = SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader
	_material.set_shader_parameter("noise", noise)
	material = _material


func _process(_delta: float) -> void:
	visible = density > 0.005
	if not visible:
		return
	_material.set_shader_parameter("density", density)
	_material.set_shader_parameter("tint", tint)
	queue_redraw()


func _draw() -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var view := get_viewport().get_visible_rect().size / camera.zoom
	var center := camera.get_screen_center_position()
	draw_rect(Rect2(center - view * 0.6, view * 1.2), Color.WHITE)
