class_name CliffFaces
extends Node2D
## The drop from high ground to low. Rock stands one step above the land
## around it and the peaks a step above the rock; out in the open country,
## plateaus of grass, snow or sand stand a step up too. Wherever high
## ground has lower ground to its south, the cliff shows as a face: banded
## rock under mountains, and under a plateau an earthen bank, its own
## ground hanging over the lip in tufts, roots and stones in the soil. Scree
## lies at its foot and a shadow on the ground; along the sides and far rim
## it gets an edge and a shadow, and the raised ground itself catches a
## little more light.
##
## A face cannot be climbed, only dropped down: the way up is round by the
## sides or the back, or by steps cut into it where a road meets it and
## here and there along a long bank.

const TILE := 44.0
## How tall one step of height looks, in pixels.
const STEP := 32.0
const T := TerrainTiles.Type
const ROCK_LOOK := {"top": Color("8f8a94"), "mid": Color("6d6873"), "low": Color("4c4853"), "lip": Color("b9b4c2"), "seam": Color("2e2b35")}
const PEAK_LOOK := {"top": Color("c9d4e2"), "mid": Color("93a0b4"), "low": Color("647086"), "lip": Color("f4f8ff"), "seam": Color("3a4254")}
## Earthen banks under raised ground: [soil top, soil, soil low, seam].
const SOIL := {
	"earth": [Color("7a5a3c"), Color("5e432c"), Color("47321f"), Color("2a1c12")],
	"frozen": [Color("6a6474"), Color("524c5c"), Color("3e3a48"), Color("24202c")],
	"sandstone": [Color("c8a070"), Color("a8804e"), Color("86623a"), Color("4a3420")],
	"ash": [Color("5a5054"), Color("463e42"), Color("342e32"), Color("1c181a")],
}

## Tile types for the chunk plus a one-tile border, row by row.
var types: PackedInt32Array
## How many steps up each of those tiles stands (WorldGenerator.height_at).
var heights: PackedInt32Array
var span := 0
## The chunk's first tile, for seeding each face's detail.
var origin := Vector2i.ZERO
## Called with a tile; true where something is built (a ruin, a village)
## and the ground has been levelled: no face is drawn there.
var levelled: Callable
## Called with a tile; true where steps are cut into the face.
var stairs: Callable


static func level(type: int) -> int:
	return 2 if type == T.PEAK else 1 if type == T.ROCK else 0


func _type(x: int, y: int) -> int:
	return types[(y + 1) * span + x + 1]


func _height(x: int, y: int) -> int:
	if heights.is_empty():
		return level(_type(x, y))
	return heights[(y + 1) * span + x + 1]


## Whether a face stands on a chunk tile: higher ground just north, and
## nothing built there.
func _is_face(x: int, y: int) -> bool:
	if _height(x, y - 1) <= _height(x, y) or TerrainTiles.is_water(_type(x, y)):
		return false
	return not (levelled.is_valid() and levelled.call(origin + Vector2i(x, y)))


func _is_stairs(x: int, y: int) -> bool:
	return stairs.is_valid() and stairs.call(origin + Vector2i(x, y))


func _ready() -> void:
	# The faces block the climb, but not the drop; steps let one climb.
	var body := StaticBody2D.new()
	var size := span - 2
	for y in size:
		var run_start := -1
		for x in size + 1:
			var is_face := x < size and _is_face(x, y) and not _is_stairs(x, y)
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
			var mine := _height(x, y)
			var at := Vector2(x, y) * TILE
			var above := _type(x, y - 1)
			var drop := _height(x, y - 1) - mine
			# Raised open ground catches a touch more light than the land below.
			var open_ground := mine > 0 and level(_type(x, y)) == 0
			if open_ground:
				draw_rect(Rect2(at, Vector2(TILE, TILE)), Color(1.0, 0.97, 0.88, 0.07))
				# Its sides: a rim where it drops away west (lit) or east (shaded).
				var rim: Color = (TerrainTiles.COLORS[_type(x, y)] as Color).lightened(0.3)
				if _height(x - 1, y) < mine:
					draw_rect(Rect2(at, Vector2(2.0, TILE)), Color(rim, 0.7))
				if _height(x + 1, y) < mine:
					draw_rect(Rect2(at + Vector2(TILE - 2.0, 0), Vector2(2.0, TILE)), Color(rim.darkened(0.45), 0.7))
			if drop > 0 and _is_face(x, y):
				if level(above) > 0:
					_face(at, drop, above, x, y)
				else:
					_bank(at, drop, above, x, y)
				if _is_stairs(x, y):
					_steps(at, drop, above, x, y)
			elif mine > 0:
				# The far rim of high ground: a thin dark line where it falls away north.
				if _height(x, y - 1) < mine:
					draw_rect(Rect2(at, Vector2(TILE, 2.0)), Color(0, 0, 0, 0.28))
					if level(_type(x, y)) == 0:
						draw_rect(Rect2(at + Vector2(0, 2), Vector2(TILE, 2.0)), Color(1, 1, 1, 0.08))
			# Ground beside higher ground lies in its shadow.
			if _height(x - 1, y) > mine:
				for k in 6:
					draw_rect(Rect2(at.x + k * 2.0, at.y, 2.0, TILE), Color(0, 0, 0, 0.26 * (1.0 - k / 6.0)))
				draw_rect(Rect2(at.x, at.y, 2.0, TILE), Color(0.12, 0.11, 0.15, 0.6))
			if _height(x + 1, y) > mine:
				for k in 4:
					draw_rect(Rect2(at.x + TILE - (k + 1) * 2.0, at.y, 2.0, TILE), Color(0, 0, 0, 0.16 * (1.0 - k / 4.0)))
				draw_rect(Rect2(at.x + TILE - 2.0, at.y, 2.0, TILE), Color(0.12, 0.11, 0.15, 0.6))


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
	_ends(at, height, look["seam"], look["lip"], x, y)
	_foot(at, height, look["seam"], look["mid"], look["lip"], random)


## The soil a plateau of this ground stands on.
static func _soil(top: int) -> Array:
	if top in [T.SNOW, T.FROSTPINE, T.SALT]:
		return SOIL["frozen"]
	if top in [T.SAND]:
		return SOIL["sandstone"]
	if top in [T.ASH, T.CINDER]:
		return SOIL["ash"]
	return SOIL["earth"]


## One tile of earthen bank under raised ground: layered soil with stones
## and roots in it, and the ground above hanging over its lip in tufts.
func _bank(at: Vector2, drop: int, above: int, x: int, y: int) -> void:
	var soil := _soil(above)
	# The ground's map colour is darker than the ground looks; lift it.
	var grass: Color = (TerrainTiles.COLORS[above] as Color).lightened(0.22)
	var random := RandomNumberGenerator.new()
	random.seed = hash(Vector3i(origin.x + x, origin.y + y, 517))
	var height := minf(STEP * drop, TILE - 4.0)
	draw_rect(Rect2(at, Vector2(TILE, height)), soil[1])
	# Layers of soil, their edges wandering in two-pixel steps.
	var top_band := height * 0.32
	var low_band := height * 0.7
	for column in 22:
		top_band = clampf(top_band + float(random.randi_range(-1, 1)) * 2.0, height * 0.2, height * 0.44)
		low_band = clampf(low_band + float(random.randi_range(-1, 1)) * 2.0, height * 0.6, height * 0.86)
		var cx := at.x + column * 2.0
		draw_rect(Rect2(cx, at.y, 2.0, top_band), soil[0])
		draw_rect(Rect2(cx, at.y + low_band, 2.0, height - low_band), soil[2])
	# Stones bedded in the soil, lit on top.
	for k in random.randi_range(1, 3):
		var stone := Vector2(float(random.randi_range(2, 4)) * 2.0, float(random.randi_range(1, 2)) * 2.0)
		var sx := at.x + float(random.randi_range(1, 18)) * 2.0
		var sy := at.y + float(random.randi_range(4, int(height / 2.0) - 3)) * 2.0
		draw_rect(Rect2(sx, sy, stone.x, stone.y), Color("6e6a74"))
		draw_rect(Rect2(sx, sy, stone.x, 2.0), Color("9a96a0"))
		draw_rect(Rect2(sx, sy + stone.y, stone.x, 2.0), Color(soil[3], 0.6))
	# Roots wandering down from the lip.
	for k in random.randi_range(0, 2):
		var rx := at.x + float(random.randi_range(2, 19)) * 2.0
		var ry := at.y + 4.0
		var length := random.randi_range(3, 7)
		for step in length:
			draw_rect(Rect2(rx, ry, 2.0, 2.0), soil[3])
			ry += 2.0
			rx += float(random.randi_range(-1, 1)) * 2.0
			rx = clampf(rx, at.x, at.x + TILE - 2.0)
	# The lip: the ground above, a lit edge, and tufts hanging over the face.
	draw_rect(Rect2(at.x, at.y, TILE, 4.0), grass)
	draw_rect(Rect2(at.x, at.y, TILE, 2.0), grass.lightened(0.18))
	for column in 22:
		if random.randf() < 0.45:
			var hang := float(random.randi_range(1, 3)) * 2.0
			draw_rect(Rect2(at.x + column * 2.0, at.y + 4.0, 2.0, hang), grass.darkened(0.12))
			draw_rect(Rect2(at.x + column * 2.0, at.y + 4.0 + hang, 2.0, 2.0), Color(soil[3], 0.55))
		else:
			draw_rect(Rect2(at.x + column * 2.0, at.y + 4.0, 2.0, 2.0), Color(soil[3], 0.5))
	_ends(at, height, soil[3], soil[0], x, y)
	_foot(at, height, soil[3], soil[1], soil[0], random)


## Steps cut into a face: treads lit on top, risers in shadow, between two
## posts (timber in soil, stone in rock).
func _steps(at: Vector2, drop: int, above: int, x: int, y: int) -> void:
	var height := minf(STEP * drop, TILE - 4.0)
	var road := _type(x, y) == T.PATH or above == T.PATH
	var tread := Color("a39478") if road else Color("8e6a42")
	var riser := Color("6a5a44") if road else Color("553e26")
	var post := Color("4a3626")
	var left := at.x + 10.0
	var width := TILE - 20.0
	var count := 4
	var each := height / count
	for k in count:
		var sy := at.y + k * each
		draw_rect(Rect2(left, sy, width, each), riser)
		draw_rect(Rect2(left, sy, width, 2.0), tread.lightened(0.15))
		draw_rect(Rect2(left, sy + 2.0, width, 2.0), tread)
		draw_rect(Rect2(left, sy + each - 2.0, width, 2.0), Color(0, 0, 0, 0.3))
	draw_rect(Rect2(left - 4.0, at.y - 2.0, 4.0, height + 4.0), post)
	draw_rect(Rect2(left + width, at.y - 2.0, 4.0, height + 4.0), post)
	draw_rect(Rect2(left - 4.0, at.y - 2.0, 4.0, 2.0), post.lightened(0.3))
	draw_rect(Rect2(left + width, at.y - 2.0, 4.0, 2.0), post.lightened(0.3))


## Ends of a face: a hard edge where the cliff turns away.
func _ends(at: Vector2, height: float, seam: Color, lip: Color, x: int, y: int) -> void:
	if _height(x - 1, y - 1) - _height(x - 1, y) <= 0:
		draw_rect(Rect2(at.x, at.y, 2.0, height), seam)
		draw_rect(Rect2(at.x + 2.0, at.y, 2.0, height), Color(lip, 0.35))
	if _height(x + 1, y - 1) - _height(x + 1, y) <= 0:
		draw_rect(Rect2(at.x + TILE - 2.0, at.y, 2.0, height), seam)
		draw_rect(Rect2(at.x + TILE - 5.0, at.y, 3.0, height), Color(0, 0, 0, 0.25))


## The foot: a dark line, scree, and the cliff's shadow on the ground.
func _foot(at: Vector2, height: float, seam: Color, mid: Color, lip: Color, random: RandomNumberGenerator) -> void:
	draw_rect(Rect2(at.x, at.y + height - 2.0, TILE, 2.0), seam)
	for k in 7:
		draw_rect(Rect2(at.x, at.y + height + k * 2.0, TILE, 2.0), Color(0, 0, 0, 0.36 * (1.0 - k / 7.0)))
	for k in random.randi_range(2, 5):
		var sx := at.x + random.randf_range(2.0, TILE - 7.0)
		var sy := at.y + height + random.randf_range(0.0, 7.0)
		var stone := Vector2(random.randf_range(3.0, 6.0), random.randf_range(2.0, 4.0))
		draw_rect(Rect2(sx, sy, stone.x, stone.y), mid)
		draw_rect(Rect2(sx, sy, stone.x, 1.0), lip)
		draw_rect(Rect2(sx, sy + stone.y, stone.x, 1.0), Color(0, 0, 0, 0.4))
