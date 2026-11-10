class_name RingBurst
extends Node2D
## An expanding ring of light, used for level-ups.

var _radius := 0.0
var _color := Color.WHITE


static func spawn(parent: Node, at: Vector2, color: Color, max_radius: float = 90.0) -> void:
	var ring := RingBurst.new()
	ring._color = color
	ring.position = at
	ring.z_index = 50
	parent.add_child(ring)
	var tween := ring.create_tween().set_parallel()
	tween.tween_method(ring._set_radius, 6.0, max_radius, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(ring, "modulate:a", 0.0, 0.6).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(ring.queue_free)


func _set_radius(value: float) -> void:
	_radius = value
	queue_redraw()


func _draw() -> void:
	draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 48, _color, 5.0)
	draw_arc(Vector2.ZERO, _radius * 0.7, 0.0, TAU, 40, Color(_color, 0.4), 3.0)
