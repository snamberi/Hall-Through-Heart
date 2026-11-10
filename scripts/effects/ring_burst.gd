class_name RingBurst
extends Sprite2D
## A pixel-art shockwave ring that grows and breaks apart.

const RING: Texture2D = preload("res://assets/effects/ring.png")
const FRAMES := 6
## Radius of the ring in the last frame of the art.
const ART_RADIUS := 58.0


static func spawn(parent: Node, at: Vector2, color: Color, max_radius: float = 90.0) -> void:
	var ring := RingBurst.new()
	ring.texture = RING
	ring.hframes = FRAMES
	ring.position = at
	ring.modulate = color
	ring.z_index = 50
	ring.scale = Vector2.ONE * max_radius / ART_RADIUS
	parent.add_child(ring)
	var tween := ring.create_tween()
	tween.tween_property(ring, "frame", FRAMES - 1, 0.42)
	tween.tween_callback(ring.queue_free)
