class_name GroundCover
extends Node2D
## The flowers, grass, pebbles, and the like on one chunk, drawn in one go
## underneath everything that moves.

## [position, small sheet index, flip]
var plants: Array = []
## Flat ground detail drawn first: cracks, puddles, roots, leaf litter.
var decals: Array = []


func _ready() -> void:
	z_index = -9
	material = Wind.grass


func _draw() -> void:
	for decal: Array in decals:
		var region := Flora.small_region(decal[1])
		var size := Flora.SMALL_SIZE * (Vector2(-1, 1) if decal[2] else Vector2.ONE) * 1.3
		draw_texture_rect_region(Flora.SMALL, Rect2(decal[0] - Vector2(size.x / 2.0, size.y * 0.75), size), region, Color(1, 1, 1, 0.9))
	# A small shadow under each plant, stone and bone, all drawn first so
	# none falls across a neighbour.
	for plant: Array in plants:
		draw_set_transform(plant[0] + Vector2(0, -3), 0.0, Vector2(1.0, 0.3))
		draw_circle(Vector2.ZERO, 7.0, Color(0.02, 0.02, 0.06, 0.2))
	draw_set_transform(Vector2.ZERO)
	for plant: Array in plants:
		var region := Flora.small_region(plant[1])
		var size := Flora.SMALL_SIZE * (Vector2(-1, 1) if plant[2] else Vector2.ONE)
		draw_texture_rect_region(Flora.SMALL, Rect2(plant[0] - Vector2(Flora.SMALL_SIZE.x / 2.0 * (-1.0 if plant[2] else 1.0), Flora.SMALL_SIZE.y - 4.0), size), region)
