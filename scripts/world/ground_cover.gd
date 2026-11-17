class_name GroundCover
extends Node2D
## The flowers, grass, pebbles, and the like on one chunk. Flat detail
## (cracks, puddles, leaf litter) and the plants' little shadows lie on the
## ground under everything; the plants themselves stand in thin rows that
## sort with everything that moves, so a flower in front of the player's
## feet is drawn over them and one behind is drawn under.

## [position, small sheet index, flip]
var plants: Array = []
## Flat ground detail drawn first: cracks, puddles, roots, leaf litter.
var decals: Array = []

## Plants are grouped in rows this many pixels tall, each sorted by its
## bottom edge.
const ROW := 6.0


func _ready() -> void:
	# The rows below sort with the world; this node itself only draws flat things.
	y_sort_enabled = true
	var rows := {}
	for plant: Array in plants:
		var key := int(floorf((plant[0] as Vector2).y / ROW))
		if not rows.has(key):
			rows[key] = []
		(rows[key] as Array).append(plant)
	for key: int in rows:
		var row := PlantRow.new()
		row.position = Vector2(0.0, (key + 1) * ROW)
		row.plants = rows[key]
		add_child(row)
	_flat()


func _flat() -> void:
	var flat := Node2D.new()
	flat.z_index = -9
	flat.z_as_relative = false
	flat.draw.connect(func() -> void:
		for decal: Array in decals:
			var region := Flora.small_region(decal[1])
			var size := Flora.SMALL_SIZE * (Vector2(-1, 1) if decal[2] else Vector2.ONE) * 1.3
			flat.draw_texture_rect_region(Flora.SMALL, Rect2(decal[0] - Vector2(size.x / 2.0, size.y * 0.75), size), region, Color(1, 1, 1, 0.9))
		# A small shadow under each plant, stone and bone, all on the ground.
		for plant: Array in plants:
			flat.draw_set_transform(plant[0] + Vector2(0, -3), 0.0, Vector2(1.0, 0.3))
			flat.draw_circle(Vector2.ZERO, 7.0, Color(0.02, 0.02, 0.06, 0.2))
		flat.draw_set_transform(Vector2.ZERO)
	)
	add_child(flat)


## One row of plants, standing at its bottom edge among the things that move.
class PlantRow:
	extends Node2D

	var plants: Array = []

	func _ready() -> void:
		material = Wind.grass

	func _draw() -> void:
		for plant: Array in plants:
			var region := Flora.small_region(plant[1])
			var size := Flora.SMALL_SIZE * (Vector2(-1, 1) if plant[2] else Vector2.ONE)
			var at: Vector2 = (plant[0] as Vector2) - position
			draw_texture_rect_region(Flora.SMALL, Rect2(at - Vector2(Flora.SMALL_SIZE.x / 2.0 * (-1.0 if plant[2] else 1.0), Flora.SMALL_SIZE.y - 4.0), size), region)
