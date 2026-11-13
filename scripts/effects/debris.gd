class_name Debris
extends Node2D
## Splinters and bits flying out of something broken: square pixels that
## arc out, fall, bounce once and fade.

## [position, velocity, colour, size, life left]
var _bits: Array = []


static func spawn(parent: Node, at: Vector2, colours: Array[Color], count: int = 14) -> void:
	if parent == null:
		return
	var debris := Debris.new()
	debris.position = at
	debris.z_index = 2
	for i in count:
		var angle := randf_range(-PI * 0.95, -PI * 0.05)
		var speed := randf_range(50.0, 150.0)
		debris._bits.append([Vector2(randf_range(-8, 8), randf_range(-18, -4)), Vector2.from_angle(angle) * speed,
			colours[i % colours.size()], float([2, 2, 3, 4][randi() % 4]), randf_range(0.5, 0.9)])
	parent.add_child(debris)


func _process(delta: float) -> void:
	var alive := false
	for bit: Array in _bits:
		if bit[4] <= 0.0:
			continue
		alive = true
		bit[4] -= delta
		bit[1].y += 420.0 * delta
		bit[0] += bit[1] * delta
		# The ground is the spot the thing stood on; bits bounce once there.
		if bit[0].y > 2.0 and bit[1].y > 0.0:
			bit[0].y = 2.0
			bit[1] = Vector2(bit[1].x * 0.4, -bit[1].y * 0.3)
	if not alive:
		queue_free()
	queue_redraw()


func _draw() -> void:
	for bit: Array in _bits:
		if bit[4] <= 0.0:
			continue
		var colour: Color = bit[2]
		colour.a = clampf(bit[4] / 0.3, 0.0, 1.0)
		draw_rect(Rect2(bit[0].round(), Vector2(bit[3], bit[3])), colour)
