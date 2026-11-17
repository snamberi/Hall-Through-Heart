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
## Ground worn by walking: [tile centre, wear 1 (trampled) or 2 (a dirt trail), hash]
var trails: Array = []

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
		# All the worn ground first, then the beaten middles over it.
		for core_pass: bool in [false, true]:
			for trail: Array in trails:
				_draw_trail(flat, trail[0], trail[1], trail[2], trail[3], core_pass)
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


## A worn patch, row by row on whole pixels. Toward a worn neighbour it
## runs flush to the tile's edge (where the neighbour takes over, so the
## two never overlap); elsewhere its edge is rounded and ragged. Drawn in
## two passes: the worn ground, then the beaten middle and its pebbles.
static func _draw_trail(canvas: CanvasItem, center: Vector2, wear: int, grain: int, joined: int, core_pass: bool) -> void:
	if core_pass and wear < 2:
		return
	var at := center.round()
	var edge := TerrainTiles.TILE_SIZE / 2.0
	var reach := (20.0 if wear == 2 else 14.0) + float(grain % 3)
	var open_tall := (16.0 if wear == 2 else 11.0) + float(grain / 3 % 3)
	var top := edge if joined & 1 else open_tall
	var bottom := edge if joined & 4 else open_tall
	var color := Color("80653f", 0.55) if core_pass else Color("6a5136", 0.62) if wear == 2 else Color("8d8256", 0.3)
	var inset := 8.0 if core_pass else 0.0
	for y in range(-int(top) + int(inset * 0.6), int(bottom) - int(inset * 0.6)):
		var going_on := (y < 0 and joined & 1) or (y >= 0 and joined & 4)
		var tall := top if y < 0 else bottom
		var round_off := 1.0 if going_on else sqrt(maxf(1.0 - float(y * y) / (tall * tall), 0.0))
		var wobble := float((grain >> (absi(y) % 20)) % 5) - 2.0
		var left := edge if joined & 8 else floorf(reach * round_off + wobble) - inset
		var right := edge if joined & 2 else floorf(reach * round_off - wobble * 0.5) - inset
		if left + right > 0.0:
			canvas.draw_rect(Rect2(at.x - left, at.y + y, left + right, 1.0), color)
	# Pebbles kicked up along a trail; on trampled ground, flattened grass.
	if core_pass or wear == 1:
		for k in 4:
			var bits := grain >> (k * 5)
			var spot := at + Vector2(bits % 25 - 12, (bits >> 3) % 15 - 7)
			if wear == 2:
				canvas.draw_rect(Rect2(spot, Vector2(2, 1)), Color("9a8e7a"))
				canvas.draw_rect(Rect2(spot + Vector2(0, 1), Vector2(2, 1)), Color("4a3a2a"))
			else:
				canvas.draw_rect(Rect2(spot, Vector2(3, 1)), Color("a59a62", 0.5))


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
