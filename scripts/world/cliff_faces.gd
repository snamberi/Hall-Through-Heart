class_name CliffFaces
extends Node2D
## The drop from high ground to low. Rock stands one step above the land
## around it and the peaks a step above the rock. Wherever high ground has
## lower ground to its south, the cliff shows as a tall face of banded rock
## with a lit lip, scree at its foot and a shadow thrown on the ground;
## along its sides and far rim it gets an edge and a shadow.
##
## A face cannot be climbed, only dropped down: the way up is round by the
## sides or the back.

const TILE := 44.0
## How tall one step of height looks, in pixels.
const STEP := 32.0
const T := TerrainTiles.Type
const ROCK_LOOK := {"top": Color("8f8a94"), "mid": Color("6d6873"), "low": Color("4c4853"), "lip": Color("b9b4c2"), "seam": Color("2e2b35")}
const PEAK_LOOK := {"top": Color("c9d4e2"), "mid": Color("93a0b4"), "low": Color("647086"), "lip": Color("f4f8ff"), "seam": Color("3a4254")}

## Tile types for the chunk plus a one-tile border, row by row.
var types: PackedInt32Array
var span := 0
## The chunk's first tile, for seeding each face's detail.
var origin := Vector2i.ZERO
## Called with a tile; true where something is built (a ruin, a village)
## and the ground has been levelled: no face is drawn there.
var levelled: Callable


static func level(type: int) -> int:
	return 2 if type == T.PEAK else 1 if type == T.ROCK else 0


func _type(x: int, y: int) -> int:
	return types[(y + 1) * span + x + 1]


## Whether a face stands on a chunk tile: higher ground just north, and
## nothing built there.
func _is_face(x: int, y: int) -> bool:
	if level(_type(x, y - 1)) <= level(_type(x, y)) or TerrainTiles.is_water(_type(x, y)):
		return false
	return not (levelled.is_valid() and levelled.call(origin + Vector2i(x, y)))


func _ready() -> void:
	# The faces block the climb, but not the drop.
	var body := StaticBody2D.new()
	var size := span - 2
	for y in size:
		var run_start := -1
		for x in size + 1:
			var is_face := x < size and _is_face(x, y)
			if is_face and run_start < 0:
				run_start = x
			elif not is_face and run_start >= 0:
				var shape := CollisionShape2D.new()
				var box := RectangleShape2D.new()
				box.size = Vector2((x - run_start) * TILE, 10.0)
				shape.shape = box
				shape.position = Vector2((run_start + x) * TILE / 2.0, y * TILE + 12.0)
				# Turned over, so it stops what comes from below (the south) only.
				shape.rotation = PI
				shape.one_way_collision = true
				shape.one_way_collision_margin = 6.0
				body.add_child(shape)
				run_start = -1
	if body.get_child_count() > 0:
		add_child(body)


func _draw() -> void:
	var size := span - 2
	for y in size:
		for x in size:
			var here := _type(x, y)
			var mine := level(here)
			var at := Vector2(x, y) * TILE
			var above := _type(x, y - 1)
			var drop := level(above) - mine
			if drop > 0 and _is_face(x, y):
				_face(at, drop, above, x, y)
			elif mine > 0:
				# The far rim of high ground: a thin dark line where it falls away north.
				if level(above) < mine:
					draw_rect(Rect2(at, Vector2(TILE, 2.0)), Color(0, 0, 0, 0.28))
			# Ground beside higher ground lies in its shadow.
			if level(_type(x - 1, y)) > mine:
				for k in 6:
					draw_rect(Rect2(at.x + k * 2.0, at.y, 2.0, TILE), Color(0, 0, 0, 0.26 * (1.0 - k / 6.0)))
				draw_rect(Rect2(at.x, at.y, 2.0, TILE), Color(0.12, 0.11, 0.15, 0.85))
			if level(_type(x + 1, y)) > mine:
				for k in 4:
					draw_rect(Rect2(at.x + TILE - (k + 1) * 2.0, at.y, 2.0, TILE), Color(0, 0, 0, 0.16 * (1.0 - k / 4.0)))
				draw_rect(Rect2(at.x + TILE - 2.0, at.y, 2.0, TILE), Color(0.12, 0.11, 0.15, 0.85))


## One tile of cliff face, `drop` steps tall, hanging from the high ground above.
func _face(at: Vector2, drop: int, above: int, x: int, y: int) -> void:
	var look: Dictionary = PEAK_LOOK if above == T.PEAK else ROCK_LOOK
	var height := minf(STEP * drop, TILE - 4.0)
	var random := RandomNumberGenerator.new()
	random.seed = hash(Vector3i(origin.x + x, origin.y + y, 911))
	var face := Rect2(at, Vector2(TILE, height))
	draw_rect(face, look["mid"])
	# Bands of rock, their edges stepping up and down along the face.
	var columns := 11
	var width := TILE / columns
	var band_top := height * 0.3
	var band_low := height * 0.68
	for column in columns:
		band_top = clampf(band_top + random.randf_range(-2.5, 2.5), height * 0.16, height * 0.42)
		band_low = clampf(band_low + random.randf_range(-2.5, 2.5), height * 0.56, height * 0.84)
		var cx := at.x + column * width
		draw_rect(Rect2(cx, at.y, width + 0.5, band_top), look["top"])
		draw_rect(Rect2(cx, at.y + band_low, width + 0.5, height - band_low), look["low"])
		if random.randf() < 0.3:
			draw_rect(Rect2(cx, at.y + band_top, width + 0.5, 1.5), Color(look["seam"], 0.5))
	# Cracks running down, and chips of light.
	for k in random.randi_range(2, 4):
		var cx := at.x + random.randf_range(3.0, TILE - 3.0)
		var from := random.randf_range(2.0, height * 0.4)
		var points := PackedVector2Array([Vector2(cx, at.y + from)])
		var cy := from
		while cy < height - 3.0:
			cy += random.randf_range(4.0, 8.0)
			cx += random.randf_range(-2.0, 2.0)
			points.append(Vector2(clampf(cx, at.x + 1.0, at.x + TILE - 1.0), at.y + minf(cy, height - 1.0)))
		draw_polyline(points, look["seam"], 1.0)
	for k in 5:
		draw_rect(Rect2(at + Vector2(random.randf_range(2.0, TILE - 4.0), random.randf_range(3.0, height - 5.0)), Vector2(2, 1.5)), Color(look["lip"], 0.6))
	# Ledges: short pale shelves with a shadow under them.
	for k in random.randi_range(1, 2):
		var lx := at.x + random.randf_range(2.0, TILE - 16.0)
		var ly := at.y + random.randf_range(height * 0.25, height * 0.75)
		var lw := random.randf_range(8.0, 14.0)
		draw_rect(Rect2(lx, ly, lw, 2.0), look["lip"])
		draw_rect(Rect2(lx + 1.0, ly + 2.0, lw, 2.0), Color(look["seam"], 0.7))
	# The lip where the high ground ends, bright against the face.
	draw_rect(Rect2(at.x, at.y, TILE, 2.5), look["lip"])
	draw_rect(Rect2(at.x, at.y + 2.5, TILE, 1.5), Color(look["seam"], 0.55))
	# Ends of the face: a hard edge where the cliff turns away.
	if level(_type(x - 1, y - 1)) - level(_type(x - 1, y)) <= 0:
		draw_rect(Rect2(at.x, at.y, 2.0, height), look["seam"])
		draw_rect(Rect2(at.x + 2.0, at.y, 2.0, height), Color(look["lip"], 0.35))
	if level(_type(x + 1, y - 1)) - level(_type(x + 1, y)) <= 0:
		draw_rect(Rect2(at.x + TILE - 2.0, at.y, 2.0, height), look["seam"])
		draw_rect(Rect2(at.x + TILE - 5.0, at.y, 3.0, height), Color(0, 0, 0, 0.25))
	# The foot: a dark line, scree, and the cliff's shadow on the ground.
	draw_rect(Rect2(at.x, at.y + height - 2.0, TILE, 2.0), look["seam"])
	for k in 7:
		draw_rect(Rect2(at.x, at.y + height + k * 2.0, TILE, 2.0), Color(0, 0, 0, 0.36 * (1.0 - k / 7.0)))
	for k in random.randi_range(2, 5):
		var sx := at.x + random.randf_range(2.0, TILE - 7.0)
		var sy := at.y + height + random.randf_range(0.0, 7.0)
		var stone := Vector2(random.randf_range(3.0, 6.0), random.randf_range(2.0, 4.0))
		draw_rect(Rect2(sx, sy, stone.x, stone.y), look["mid"])
		draw_rect(Rect2(sx, sy, stone.x, 1.0), look["lip"])
		draw_rect(Rect2(sx, sy + stone.y, stone.x, 1.0), Color(0, 0, 0, 0.4))
