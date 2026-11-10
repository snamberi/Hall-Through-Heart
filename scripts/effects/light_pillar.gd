class_name LightPillar
extends Node2D
## A column of light with rising motes, for the player's rebirth.

const HEIGHT := 420.0

var _width := 0.0
var _color := Color(1.0, 0.9, 0.6)


static func spawn(parent: Node, at: Vector2, color: Color = Color(1.0, 0.9, 0.6)) -> void:
	var pillar := LightPillar.new()
	pillar._color = color
	pillar.position = at
	pillar.z_index = 40
	parent.add_child(pillar)

	var motes := CPUParticles2D.new()
	motes.amount = 36
	motes.lifetime = 1.4
	motes.one_shot = true
	motes.explosiveness = 0.2
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(22.0, 6.0)
	motes.direction = Vector2.UP
	motes.spread = 12.0
	motes.gravity = Vector2.ZERO
	motes.initial_velocity_min = 40.0
	motes.initial_velocity_max = 110.0
	motes.scale_amount_min = 2.0
	motes.scale_amount_max = 4.0
	motes.color = color
	pillar.add_child(motes)
	motes.emitting = true

	var tween := pillar.create_tween()
	tween.tween_method(pillar._set_width, 0.0, 34.0, 0.25).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.5)
	tween.tween_method(pillar._set_width, 34.0, 0.0, 0.8).set_ease(Tween.EASE_IN)
	tween.tween_interval(0.6)
	tween.tween_callback(pillar.queue_free)


func _set_width(value: float) -> void:
	_width = value
	queue_redraw()


func _draw() -> void:
	if _width <= 0.5:
		return
	var clear := Color(_color, 0.0)
	for layer: Array in [[1.0, 0.22], [0.55, 0.35], [0.2, 0.6]]:
		var half: float = _width * layer[0]
		var solid := Color(_color, layer[1])
		draw_polygon(
			PackedVector2Array([Vector2(-half, 0), Vector2(half, 0), Vector2(half, -HEIGHT), Vector2(-half, -HEIGHT)]),
			PackedColorArray([solid, solid, clear, clear])
		)
