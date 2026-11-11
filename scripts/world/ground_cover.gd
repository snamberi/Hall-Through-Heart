class_name GroundCover
extends Node2D
## The flowers, grass, pebbles, and the like on one chunk, drawn in one go
## underneath everything that moves.

## [position, small sheet index, flip]
var plants: Array = []


func _ready() -> void:
	z_index = -9


func _draw() -> void:
	for plant: Array in plants:
		var region := Flora.small_region(plant[1])
		var size := Flora.SMALL_SIZE * (Vector2(-1, 1) if plant[2] else Vector2.ONE)
		draw_texture_rect_region(Flora.SMALL, Rect2(plant[0] - Vector2(Flora.SMALL_SIZE.x / 2.0 * (-1.0 if plant[2] else 1.0), Flora.SMALL_SIZE.y - 4.0), size), region)
