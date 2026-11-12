class_name WallFaces
extends Node2D
## The front faces of a room's walls: wherever a wall has open floor below
## it, its lower part is drawn as a face (rough rock in caves, cut stone in
## crypts, logs in houses), with a lit rim along the top and a soft shadow
## cast onto the floor. Side edges get a thin highlight or shade.

const T := TerrainTiles.Type
const FACE := 0.62
const STYLES := {
	"rock": {"face": Color(0.33, 0.3, 0.37), "light": Color(0.46, 0.43, 0.5), "dark": Color(0.18, 0.16, 0.21), "rim": Color(0.55, 0.52, 0.6)},
	"stone": {"face": Color(0.38, 0.36, 0.42), "light": Color(0.52, 0.5, 0.56), "dark": Color(0.2, 0.19, 0.24), "rim": Color(0.62, 0.6, 0.66),
		"top": Color(0.16, 0.15, 0.19), "seam": Color(0.1, 0.1, 0.13)},
	"wood": {"face": Color(0.45, 0.31, 0.2), "light": Color(0.58, 0.42, 0.28), "dark": Color(0.26, 0.17, 0.11), "rim": Color(0.68, 0.52, 0.36),
		"top": Color(0.19, 0.13, 0.09), "seam": Color(0.11, 0.07, 0.05)},
	"void": {"face": Color(0.22, 0.16, 0.32), "light": Color(0.42, 0.3, 0.6), "dark": Color(0.1, 0.07, 0.16), "rim": Color(0.62, 0.45, 0.9),
		"top": Color(0.07, 0.05, 0.11), "seam": Color(0.04, 0.03, 0.07)},
}

var room: Room
var style := "rock"


func _ready() -> void:
	z_index = -9


func _is_wall(cell: Vector2i) -> bool:
	return room.cells.get(cell, -1) == T.WALL


func _is_open(cell: Vector2i) -> bool:
	return room.cells.has(cell) and room.cells[cell] != T.WALL


func _draw() -> void:
	if room == null:
		return
	var colors: Dictionary = STYLES.get(style, STYLES["rock"])
	var size := float(TerrainTiles.TILE_SIZE)
	for cell: Vector2i in room.cells:
		if not _is_wall(cell):
			continue
		var origin := Vector2(cell) * size
		var below := _is_open(cell + Vector2i.DOWN)
		var seed := absi(hash(cell))
		# Built rooms cap their walls (beams, slabs) instead of showing raw rock.
		if colors.has("top"):
			_cap(Rect2(origin, Vector2(size, size * (1.0 - FACE) if below else size)), colors, seed)
		if below:
			var top := origin.y + size * (1.0 - FACE)
			var face := Rect2(origin.x, top, size, size * FACE)
			draw_rect(face, colors["face"])
			_face_detail(face, colors, seed)
			draw_line(Vector2(face.position.x, top), Vector2(face.end.x, top), colors["rim"], 2.0)
			draw_line(Vector2(face.position.x, face.end.y - 1), Vector2(face.end.x, face.end.y - 1), colors["dark"], 2.0)
			# The shadow the wall casts onto the floor in front of it.
			for k in 6:
				draw_rect(Rect2(origin.x, origin.y + size + k * 2.0, size, 2.0), Color(0, 0, 0, 0.32 * (1.0 - k / 6.0)))
			if style == "void":
				# Where solid ground ends at the void wall, a seam of violet
				# light, so the edge of the walkable floor is plain to see.
				var lip := Color(colors["rim"], 0.9)
				draw_line(Vector2(face.position.x, face.end.y + 1.0), Vector2(face.end.x, face.end.y + 1.0), lip, 2.0)
				for k in 3:
					draw_rect(Rect2(origin.x, face.end.y + 2.0 + k * 2.0, size, 2.0), Color(colors["rim"], 0.22 * (1.0 - k / 3.0)))
		# Edges against open floor at the sides and above.
		if _is_open(cell + Vector2i.LEFT):
			draw_line(origin + Vector2(1, 0), origin + Vector2(1, size), Color(colors["rim"], 0.7), 2.0)
			if style == "void":
				draw_rect(Rect2(origin.x - 4.0, origin.y, 4.0, size), Color(colors["rim"], 0.14))
		if _is_open(cell + Vector2i.RIGHT):
			draw_line(origin + Vector2(size - 1, 0), origin + Vector2(size - 1, size), Color(colors["dark"], 0.9), 2.0)
			if style == "void":
				draw_rect(Rect2(origin.x + size, origin.y, 3.0, size), Color(colors["rim"], 0.16))
			for k in 4:
				draw_rect(Rect2(origin.x + size + k * 2.0, origin.y, 2.0, size), Color(0, 0, 0, 0.18 * (1.0 - k / 4.0)))
		if _is_open(cell + Vector2i.UP):
			draw_line(origin + Vector2(0, 1), origin + Vector2(size, 1), Color(colors["rim"], 0.8), 2.0)


## The top of a wall seen from above.
func _cap(rect: Rect2, colors: Dictionary, seed: int) -> void:
	draw_rect(rect, colors["top"])
	match style:
		"wood":
			# Roof beams running across.
			for k in range(1, 4):
				var y := rect.position.y + 11.0 * k
				if y < rect.end.y:
					draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), colors["seam"], 1.0)
			if seed % 3 == 0:
				draw_rect(Rect2(rect.position + Vector2(seed % 30 + 4, 3), Vector2(2, 2)), Color(colors["face"], 0.5))
		"stone":
			var x := rect.position.x + (22.0 if seed % 2 else 0.0)
			draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), colors["seam"], 1.0)
			draw_line(Vector2(rect.position.x, rect.position.y + 1), Vector2(rect.end.x, rect.position.y + 1), Color(colors["face"], 0.35), 1.0)
		"void":
			if seed % 4 == 0:
				draw_rect(Rect2(rect.position + Vector2(seed % 34 + 4, (seed / 7) % maxi(int(rect.size.y) - 4, 1) + 2), Vector2(2, 2)), Color(colors["rim"], 0.6))


func _face_detail(face: Rect2, colors: Dictionary, seed: int) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = seed
	match style:
		"wood":
			# Stacked logs with dark seams and round ends.
			var rows := 3
			for row in rows:
				var y := face.position.y + face.size.y * row / rows
				draw_rect(Rect2(face.position.x, y + 1, face.size.x, face.size.y / rows - 2), colors["face"].lerp(colors["light"], 0.15 * (row % 2)))
				draw_line(Vector2(face.position.x, y), Vector2(face.end.x, y), colors["dark"], 1.0)
				draw_line(Vector2(face.position.x, y + 2), Vector2(face.end.x, y + 2), Color(colors["light"], 0.5), 1.0)
				if random.randf() < 0.4:
					var knot := Vector2(face.position.x + random.randf_range(6, face.size.x - 6), y + face.size.y / rows / 2.0)
					draw_circle(knot, 1.6, colors["dark"])
		"stone", "void":
			# Dressed blocks in courses.
			var rows := 2
			for row in rows:
				var y := face.position.y + face.size.y * row / rows
				var h := face.size.y / rows
				var x := face.position.x - (11.0 if row % 2 else 0.0)
				while x < face.end.x:
					var w := 22.0
					var block := Rect2(maxf(x, face.position.x) + 1, y + 1, minf(x + w, face.end.x) - maxf(x, face.position.x) - 2, h - 2)
					if block.size.x > 1.0:
						draw_rect(block, colors["face"].lerp(colors["light"], random.randf_range(0.0, 0.25)))
						draw_line(block.position, Vector2(block.end.x, block.position.y), Color(colors["light"], 0.8), 1.0)
					x += w
				draw_line(Vector2(face.position.x, y), Vector2(face.end.x, y), colors["dark"], 1.0)
			if style == "void":
				draw_rect(Rect2(face.position.x + random.randf_range(8, 30), face.position.y + face.size.y * 0.5, 3, 2), colors["rim"])
		_:
			# Rough rock: uneven strata, chips of light, a crack or two.
			for k in 3:
				var y := face.position.y + face.size.y * (0.25 + 0.25 * k) + random.randf_range(-2, 2)
				var points := PackedVector2Array()
				for step in 5:
					points.append(Vector2(face.position.x + face.size.x * step / 4.0, y + random.randf_range(-2.5, 2.5)))
				draw_polyline(points, colors["dark"], 1.0)
				draw_polyline(Array(points).map(func(p: Vector2) -> Vector2: return p + Vector2(0, 1.5)), Color(colors["light"], 0.6), 1.0)
			for k in 4:
				draw_rect(Rect2(face.position + Vector2(random.randf_range(2, face.size.x - 4), random.randf_range(2, face.size.y - 4)), Vector2(2, 2)), colors["light"])
			if random.randf() < 0.5:
				var x := face.position.x + random.randf_range(8, face.size.x - 8)
				draw_polyline(PackedVector2Array([Vector2(x, face.position.y + 3), Vector2(x + 3, face.position.y + 10), Vector2(x + 1, face.end.y - 3)]), colors["dark"], 1.0)
