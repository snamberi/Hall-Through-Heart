class_name StoneWall
extends Node2D
## One tile's worth of a slim standing wall. Pieces join their neighbours
## into runs: a wall running east-west shows its face of stone courses with
## a lit top; one running north-south is seen from above, a narrow band of
## capstones with a short face at its south end. Ruined walls are chipped
## and uneven along the top, with moss and the odd fallen block.
##
## The part that blocks movement is only as thick as the wall, not the
## whole tile, so the player can pass close by on either side.

const TILE := 44.0
const THICK := 12.0
const STYLES := {
	"ruin": {"face": Color("7d7986"), "light": Color("a09caa"), "dark": Color("4a4754"), "top": Color("b4b0bd"), "seam": Color("38353f"), "height": 30.0, "broken": true, "moss": Color("5d7a3f")},
	"keep": {"face": Color("8a8794"), "light": Color("a8a5b2"), "dark": Color("55525e"), "top": Color("c0bdc9"), "seam": Color("3c3944"), "height": 34.0, "broken": false, "moss": Color("5d7a3f")},
	"wood": {"face": Color("8a6238"), "light": Color("a87c4a"), "dark": Color("57391f"), "top": Color("c09a62"), "seam": Color("3a2412"), "height": 32.0, "broken": false, "moss": Color("5d7a3f")},
}

var style := "ruin"
## Whether there is wall on each side of this piece.
var north := false
var east := false
var south := false
var west := false
## A number that fixes this piece's chips and cracks.
var variation := 0


## Makes the pieces for a set of wall cells, each joined to its neighbours.
## `at` gives the world position of a cell's middle.
static func build(cells: Array, at: Callable, wall_style: String = "ruin") -> Array[StoneWall]:
	var taken := {}
	for cell: Vector2i in cells:
		taken[cell] = true
	var pieces: Array[StoneWall] = []
	for cell: Vector2i in cells:
		var piece := StoneWall.new()
		piece.style = wall_style
		piece.north = taken.has(cell + Vector2i.UP)
		piece.east = taken.has(cell + Vector2i.RIGHT)
		piece.south = taken.has(cell + Vector2i.DOWN)
		piece.west = taken.has(cell + Vector2i.LEFT)
		piece.variation = absi(hash(cell * 31 + Vector2i(7, 3)))
		# The origin is the wall's foot line, so things sort in front of and behind it.
		piece.position = (at.call(cell) as Vector2) + Vector2(0, THICK / 2.0)
		pieces.append(piece)
	return pieces


func _ready() -> void:
	var body := StaticBody2D.new()
	for rect in _footprint():
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = rect.size
		shape.shape = box
		shape.position = rect.get_center()
		body.add_child(shape)
	add_child(body)


## Whether the wall runs sideways here (a lone piece counts).
func _runs_across() -> bool:
	return east or west or not (north or south)


## The ground the wall stands on, as rectangles: its thin strip(s).
func _footprint() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var half := TILE / 2.0
	if _runs_across():
		var from := -half if west else -THICK / 2.0 - 4.0
		var to := half if east else THICK / 2.0 + 4.0
		rects.append(Rect2(from, -THICK, to - from, THICK))
	if north or south:
		var top := -half - THICK / 2.0 if north else -THICK
		var bottom := half - THICK / 2.0 if south else 0.0
		rects.append(Rect2(-THICK / 2.0, top, THICK, bottom - top))
	return rects


func _draw() -> void:
	var look: Dictionary = STYLES[style]
	var random := RandomNumberGenerator.new()
	random.seed = variation
	var height: float = look["height"]
	var half := TILE / 2.0
	# A soft shadow on the ground along the wall's foot.
	for rect in _footprint():
		draw_rect(Rect2(rect.position + Vector2(2, 3), rect.size + Vector2(3, 2)), Color(0, 0, 0, 0.22))
	# A wall going north-south: seen from above, a band of capstones, with
	# its near end showing a short face.
	if north or south:
		var top := (-half - THICK / 2.0 if north else -THICK) - height
		var bottom := (half - THICK / 2.0 if south else 0.0) - height
		if not south:
			var end := Rect2(-THICK / 2.0, -height, THICK, height)
			draw_rect(end, look["face"])
			_courses(end, look, random, 6.0)
			draw_rect(Rect2(end.position, Vector2(2, end.size.y)), Color(look["light"], 0.7))
			draw_rect(Rect2(end.end.x - 2, end.position.y, 2, end.size.y), Color(look["dark"], 0.8))
		var cap := Rect2(-THICK / 2.0, top, THICK, bottom - top)
		draw_rect(cap, look["top"])
		var y := cap.position.y + random.randf_range(5.0, 9.0)
		while y < cap.end.y - 2.0:
			draw_line(Vector2(cap.position.x, y), Vector2(cap.end.x, y), look["seam"], 1.0)
			y += random.randf_range(8.0, 12.0)
		draw_rect(Rect2(cap.position, Vector2(1.5, cap.size.y)), Color(1, 1, 1, 0.25))
		draw_rect(Rect2(cap.end.x - 1.5, cap.position.y, 1.5, cap.size.y), Color(look["dark"], 0.8))
		draw_rect(cap, look["seam"], false, 1.0)
	# A wall going east-west: its face toward the viewer, capstones on top.
	if _runs_across():
		var from := -half if west else -THICK / 2.0 - 4.0
		var to := half if east else THICK / 2.0 + 4.0
		var broken: bool = look["broken"]
		# Ruins stand at uneven heights, and lose their last blocks at an open end.
		var left_height := height - (random.randf_range(0.0, 9.0) if broken else 0.0)
		var right_height := height - (random.randf_range(0.0, 9.0) if broken else 0.0)
		if broken and not west:
			left_height *= 0.55
		if broken and not east:
			right_height *= 0.55
		var face := PackedVector2Array([Vector2(from, 0), Vector2(from, -left_height)])
		var steps := 4
		for step in range(1, steps):
			var x := lerpf(from, to, step / float(steps))
			var h := lerpf(left_height, right_height, step / float(steps)) - (random.randf_range(0.0, 6.0) if broken else 0.0)
			# Stepped, like missing blocks, not a slope.
			face.append(Vector2(x, face[face.size() - 1].y))
			face.append(Vector2(x, -h))
		face.append(Vector2(to, face[face.size() - 1].y))
		face.append(Vector2(to, 0))
		draw_colored_polygon(face, look["face"])
		_courses(Rect2(from, -height, to - from, height), look, random, 7.0, face)
		# Capstones along the top edge, following the broken line.
		for index in range(1, face.size() - 2, 2):
			var a := face[index]
			var b := face[index + 1]
			draw_rect(Rect2(a.x, a.y - 4.0, b.x - a.x, 4.0), look["top"])
			draw_line(Vector2(a.x, a.y), Vector2(b.x, a.y), look["seam"], 1.0)
			draw_line(Vector2(a.x, a.y - 4.0), Vector2(b.x, a.y - 4.0), Color(1, 1, 1, 0.35), 1.0)
		draw_polyline(face, look["seam"], 1.0)
		# Shade under the cap and along the foot.
		draw_rect(Rect2(from, -2.0, to - from, 2.0), Color(look["dark"], 0.8))
		if style == "wood":
			# Pointed stakes.
			var x := from + 2.0
			while x < to - 2.0:
				draw_colored_polygon(PackedVector2Array([Vector2(x, -height), Vector2(x + 3.5, -height - 7.0), Vector2(x + 7.0, -height)]), look["light"])
				draw_line(Vector2(x + 7.0, -height), Vector2(x + 7.0, 0), look["seam"], 1.0)
				x += 7.0
			draw_rect(Rect2(from, -height * 0.62, to - from, 3.0), look["dark"])
		elif random.randf() < 0.55:
			# Moss creeping up from the ground, and a tuft on top.
			var mx := random.randf_range(from + 4.0, to - 10.0)
			draw_rect(Rect2(mx, -random.randf_range(5.0, 11.0), random.randf_range(5.0, 9.0), 11.0), Color(look["moss"], 0.85))
			draw_rect(Rect2(mx + 2.0, -3.0, 4.0, 3.0), Color(look["moss"].lightened(0.2), 0.9))
		if broken and random.randf() < 0.45:
			# A block that fell out, lying at the foot.
			var bx := random.randf_range(from + 2.0, to - 12.0)
			draw_rect(Rect2(bx, 2.0, 9.0, 6.0), look["face"])
			draw_rect(Rect2(bx, 2.0, 9.0, 2.0), look["top"])
			draw_rect(Rect2(bx, 2.0, 9.0, 6.0), look["seam"], false, 1.0)


## Courses of blocks across a face: seams, a lit edge, the odd dark or
## pale stone, a crack. `outline` clips nothing but keeps seams off air.
func _courses(rect: Rect2, look: Dictionary, random: RandomNumberGenerator, course: float, outline: PackedVector2Array = PackedVector2Array()) -> void:
	var row := 0
	var y := rect.end.y - course
	while y > rect.position.y - 1.0:
		var x := rect.position.x - (random.randf_range(4.0, 9.0) if row % 2 else 0.0)
		while x < rect.end.x:
			var width := random.randf_range(10.0, 16.0)
			var left := maxf(x, rect.position.x)
			var right := minf(x + width, rect.end.x)
			if right - left > 2.0 and _inside(Vector2((left + right) / 2.0, y + course / 2.0), outline):
				var tone := random.randf()
				if tone < 0.18:
					draw_rect(Rect2(left, y, right - left, course), Color(look["dark"], 0.55))
				elif tone > 0.85:
					draw_rect(Rect2(left, y, right - left, course), Color(look["light"], 0.5))
				draw_line(Vector2(left, y), Vector2(right, y), Color(look["light"], 0.55), 1.0)
				draw_line(Vector2(right, y), Vector2(right, y + course), look["seam"], 1.0)
				draw_line(Vector2(left, y + course), Vector2(right, y + course), look["seam"], 1.0)
			x += width
		y -= course
		row += 1
	if random.randf() < 0.4 and rect.size.x > 20.0:
		var cx := rect.position.x + random.randf_range(8.0, rect.size.x - 8.0)
		draw_polyline(PackedVector2Array([Vector2(cx, rect.end.y - 2.0), Vector2(cx + 3.0, rect.end.y - 9.0), Vector2(cx + 1.0, rect.end.y - 15.0)]), look["seam"], 1.0)


## Whether a point lies under the wall's top line (the broken silhouette).
func _inside(point: Vector2, outline: PackedVector2Array) -> bool:
	if outline.is_empty():
		return true
	return Geometry2D.is_point_in_polygon(point, outline)
