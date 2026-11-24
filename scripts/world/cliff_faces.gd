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

## The faces themselves, drawn a pixel at a time (tools/generate_cliffs.py):
## one strip per look, four tiles wide, repeating along a ridge. The face
## proper starts FACE_TOP pixels down each strip (the lip can rise above it).
const FACES: Texture2D = preload("res://assets/tiles/cliffs.png")
const FACE_LOOKS: Array[String] = ["rock", "peak", "earth", "frozen", "sandstone", "ash"]
const FACE_WIDTH := 176
const FACE_HEIGHT := 56
const FACE_TOP := 8.0

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
## Called with a tile; true where a river runs (only rivers make waterfalls).
var river: Callable
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
	return _height(x, y - 1) > _height(x, y) and not TerrainTiles.is_water(_type(x, y))


func _is_stairs(x: int, y: int) -> bool:
	return stairs.is_valid() and stairs.call(origin + Vector2i(x, y))


func _ready() -> void:
	# The faces block the climb, but not the drop; steps let one climb.
	var body := StaticBody2D.new()
	body.collision_layer = TerrainTiles.CLIFF_COLLISION
	body.collision_mask = 0
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
	# Waterfalls: where a river runs off higher ground, the water pours
	# down the drop in an animated fall.
	for y in size:
		for x in size:
			if _is_waterfall(x, y):
				var fall := ColorRect.new()
				fall.position = Vector2(x, y) * TILE
				fall.size = Vector2(TILE, TILE)
				# Narrowed at the sides where the fall has no neighbour.
				fall.material = _waterfall_material(not _is_waterfall(x - 1, y), not _is_waterfall(x + 1, y))
				fall.mouse_filter = Control.MOUSE_FILTER_IGNORE
				add_child(fall)


## Water with higher water just north: a river falling off higher ground.
func _is_waterfall(x: int, y: int) -> bool:
	if x < -1 or y < 0 or x > span - 2 or y > span - 2:
		return false
	if not (TerrainTiles.is_water(_type(x, y)) and TerrainTiles.is_water(_type(x, y - 1)) and _height(x, y - 1) > _height(x, y)):
		return false
	return river.is_valid() and river.call(origin + Vector2i(x, y)) and river.call(origin + Vector2i(x, y - 1))


const WATERFALL_SHADER := """
shader_type canvas_item;
// Water pouring down a drop, a whole pixel at a time: falling streaks in
// two-pixel columns at their own pace, a bright lip where it tips over,
// and white water churning at the foot.
uniform vec2 edges = vec2(0.0);
uniform vec4 deep : source_color = vec4(0.13, 0.22, 0.34, 1.0);
uniform vec4 mid : source_color = vec4(0.27, 0.44, 0.6, 1.0);
uniform vec4 light : source_color = vec4(0.58, 0.76, 0.88, 1.0);
uniform vec4 foam : source_color = vec4(0.88, 0.95, 1.0, 1.0);

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 p = floor(UV * 44.0);
	float column = floor(p.x / 2.0);
	float h = hash(vec2(column, 3.0));
	float speed = 70.0 + 40.0 * h;
	float t = fract((p.y - TIME * speed) / (14.0 + 10.0 * h) + h);
	vec3 c = t < 0.35 ? deep.rgb : t < 0.8 ? mid.rgb : light.rgb;
	// The lip where it tips over, and the dark rock showing at the sides.
	if (p.y < 2.0) {
		c = light.rgb;
	}
	if ((edges.x > 0.5 && p.x < 3.0) || (edges.y > 0.5 && p.x > 40.0)) {
		c = mix(c, deep.rgb * 0.6, 0.6);
	}
	// White water at the foot, churning.
	float churn = hash(vec2(column, floor(TIME * 10.0) + floor(p.y / 2.0) * 3.7));
	if (p.y > 32.0 && churn > 0.62 - (p.y - 32.0) * 0.03) {
		c = foam.rgb;
	}
	COLOR = vec4(c, 1.0);
}
"""
static var _fall_materials: Dictionary = {}


static func _waterfall_material(left: bool, right: bool) -> ShaderMaterial:
	var key := int(left) + 2 * int(right)
	if not _fall_materials.has(key):
		var shader: Shader = (_fall_materials.values()[0] as ShaderMaterial).shader if not _fall_materials.is_empty() else Shader.new()
		if shader.code == "":
			shader.code = WATERFALL_SHADER
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("edges", Vector2(1.0 if left else 0.0, 1.0 if right else 0.0))
		_fall_materials[key] = material
	return _fall_materials[key]


func _draw() -> void:
	var size := span - 2
	for y in size:
		for x in size:
			var mine := _height(x, y)
			var at := Vector2(x, y) * TILE
			var above := _type(x, y - 1)
			var drop := _height(x, y - 1) - mine
			# Raised ground catches more light than the land below it.
			if mine > 0 and level(_type(x, y)) == 0:
				draw_rect(Rect2(at, Vector2(TILE, TILE)), Color(1.0, 0.97, 0.86, 0.1))
			if drop > 0 and _is_face(x, y):
				_cliff(at, drop, above, x, y)
				if _is_stairs(x, y):
					_steps(at, drop, above, x, y)
			# Ground at the foot of higher ground to the west or east lies in
			# its shadow (the light comes from the upper left).
			if _height(x - 1, y) > mine:
				for k in 7:
					draw_rect(Rect2(at.x + k * 2.0, at.y, 2.0, TILE), Color(0, 0, 0, 0.3 * (1.0 - k / 7.0)))
			if _height(x + 1, y) > mine:
				for k in 3:
					draw_rect(Rect2(at.x + TILE - (k + 1) * 2.0, at.y, 2.0, TILE), Color(0, 0, 0, 0.14 * (1.0 - k / 3.0)))
			# Behind higher ground to the south, the low ground darkens toward it.
			if _height(x, y + 1) > mine and not _is_face(x, y + 1):
				for k in 3:
					draw_rect(Rect2(at.x, at.y + TILE - (k + 1) * 2.0, TILE, 2.0), Color(0, 0, 0, 0.18 * (1.0 - k / 3.0)))
	# Edges of raised ground on its other three sides, drawn over the rest.
	for y in size:
		for x in size:
			var mine := _height(x, y)
			if mine <= 0 or TerrainTiles.is_water(_type(x, y)):
				continue
			var at := Vector2(x, y) * TILE
			if _height(x, y - 1) < mine:
				_north_rim(at, x, y)
			if _height(x - 1, y) < mine:
				_side_wall(at, x, y, true)
			if _height(x + 1, y) < mine:
				_side_wall(at, x, y, false)


## The far (north) edge of raised ground: the ground runs to a bright,
## ragged lip with a dark line where it falls away behind.
func _north_rim(at: Vector2, x: int, y: int) -> void:
	var ground := _type(x, y)
	var base: Color = TerrainTiles.COLORS[ground]
	var lit := Color.from_hsv(base.h, minf(base.s * 1.2, 1.0), clampf(base.v + 0.32, 0.0, 0.95))
	var world_x := float(origin.x + x) * TILE
	for c in 22:
		var px := at.x + c * 2.0
		var dip := maxf(2.0 + _wave(world_x + c * 2.0, 3.3, 4.0), 0.0)
		# The low ground just beyond the edge lies darker.
		for k in 3:
			draw_rect(Rect2(px, at.y - (k + 1) * 2.0 + dip, 2.0, 2.0), Color(0.04, 0.03, 0.07, 0.3 * (1.0 - k / 3.0)))
		draw_rect(Rect2(px, at.y + dip, 2.0, 1.0), lit.lightened(0.12))
		draw_rect(Rect2(px, at.y + dip + 1.0, 2.0, 1.0), lit)
		draw_rect(Rect2(px, at.y + dip + 2.0, 2.0, 1.0), Color(lit, 0.45))


## The side of raised ground where it drops away to the west (lit) or east
## (in shade): seen nearly edge-on, a narrow wall of soil or rock under a
## grass lip that hangs over it here and there.
func _side_wall(at: Vector2, x: int, y: int, west: bool) -> void:
	var ground := _type(x, y)
	var rocky := level(ground) > 0
	var look := ("peak" if ground == T.PEAK else "rock") if rocky else _soil_name(ground)
	var stones := _stone_look(ground)
	var soil: Array = stones if rocky else _soil(ground)
	var base: Color = TerrainTiles.COLORS[ground]
	var grass := Color.from_hsv(base.h, minf(base.s * 1.2, 1.0), clampf(base.v + 0.22, 0.0, 0.92))
	var dark: Color = soil[3]
	var world_x := int(float(origin.x) * TILE + at.x)
	var world_y := float(origin.y + y) * TILE
	# The west side catches the light; the east lies in shade.
	var light := Color(1.14, 1.1, 1.04) if west else Color(0.7, 0.68, 0.78)
	var row := maxi(FACE_LOOKS.find(look), 0) * FACE_HEIGHT
	# Where the wall starts: below the north rim if there is one.
	var start := 4 if _height(x, y - 1) < _height(x, y) else 0
	var random := RandomNumberGenerator.new()
	random.seed = hash(Vector3i(origin.x + x, origin.y + y, 919 if west else 929))
	for r in range(start, int(TILE)):
		var py := at.y + r
		var width := 10.0 + _wave(world_y + float(r - r % 2), 5.1 if west else 6.7, 4.0)
		var outer := at.x if west else at.x + TILE - width
		var inner := at.x + width if west else at.x + TILE - width
		# The wall is the same stone or soil as the faces, a pixel row at a
		# time, taken from the strip by height so its beds run level.
		var sy := FACE_TOP + float(posmod(int(world_y) + r, int(TILE) - 4))
		var sx := posmod(world_x + int(outer - at.x), FACE_WIDTH - int(width))
		draw_texture_rect_region(FACES, Rect2(outer, py, width, 1.0), Rect2(sx, row + sy, width, 1.0), light)
		# A dark line on its outer edge, and the ground's lip on its inner.
		draw_rect(Rect2(at.x if west else at.x + TILE - 1.0, py, 1.0, 1.0), dark)
		draw_rect(Rect2(inner - (1.0 if west else 0.0), py, 1.0, 1.0), grass.lightened(0.2) if west else grass.darkened(0.15))
		draw_rect(Rect2(inner - (2.0 if west else -1.0), py, 1.0, 1.0), Color(0, 0, 0, 0.18))
		# Grass hanging over the wall here and there, a pixel-wide fringe.
		if not rocky and r % 2 == 0 and random.randf() < 0.3:
			var hang := float(random.randi_range(1, 3))
			var hang_x := inner - hang if west else inner
			draw_rect(Rect2(hang_x, py, hang, 1.0), grass.darkened(0.05))
			draw_rect(Rect2(hang_x, py + 1.0, hang, 1.0), grass.darkened(0.25))


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
	var road := _type(x, y) in [T.PATH, T.TRACK] or above in [T.PATH, T.TRACK]
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


# --- the cliff as stacked stones under a wandering, overhanging lip

## Stone looks: [stone, lit, shade, gap] for each kind of high ground.
const STONES := {
	"earth": [Color("8e8270"), Color("b6aa92"), Color("645a4c"), Color("2e2219")],
	"frozen": [Color("8a8e9c"), Color("b8bece"), Color("62667a"), Color("2a2a36")],
	"sandstone": [Color("b8955e"), Color("d8b880"), Color("8a6a40"), Color("4a3420")],
	"ash": [Color("5a5458"), Color("7a7278"), Color("3e3a3e"), Color("1a1618")],
	"rock": [Color("7a7682"), Color("a8a4b2"), Color("55525e"), Color("24222a")],
	"peak": [Color("9aa4b8"), Color("d0d8e8"), Color("6a7488"), Color("2e3442")],
}


func _stone_look(above: int) -> Array:
	if above == T.PEAK:
		return STONES["peak"]
	if above == T.ROCK:
		return STONES["rock"]
	if above in [T.SNOW, T.FROSTPINE, T.SALT]:
		return STONES["frozen"]
	if above == T.SAND:
		return STONES["sandstone"]
	if above in [T.ASH, T.CINDER]:
		return STONES["ash"]
	return STONES["earth"]


## A wandering line, the same wherever it is asked for, so neighbouring
## tiles join without a seam (in steps of two pixels, as the art is drawn).
static func _wave(wx: float, seed: float, size: float) -> float:
	var v := sin(wx * 0.045 + seed) * 0.6 + sin(wx * 0.13 + seed * 2.3) * 0.4
	return roundf(v * size / 2.0) * 2.0


func _cliff(at: Vector2, drop: int, above: int, x: int, y: int) -> void:
	var stones := _stone_look(above)
	var rocky := level(above) > 0
	# The ground's map colour is darker and duller than it looks: lift it.
	var base_grass: Color = TerrainTiles.COLORS[above]
	var grass := Color.from_hsv(base_grass.h, minf(base_grass.s * 1.25, 1.0), clampf(base_grass.v + 0.22, 0.0, 0.92))
	var random := RandomNumberGenerator.new()
	random.seed = hash(Vector3i(origin.x + x, origin.y + y, 733))
	# Every face stands a full tile tall, rock and earth alike.
	var height := TILE - 4.0
	var world_x := float(origin.x + x) * TILE
	# Outer corners: where the high ground above ends beside this face, the
	# face turns the corner into the plateau's side wall.
	var outer_left := _height(x - 1, y - 1) < _height(x, y - 1)
	var outer_right := _height(x + 1, y - 1) < _height(x, y - 1)
	# Per two-pixel column: where the lip and the foot lie. Ends of a cliff
	# curve round: the face shrinks toward them instead of stopping square.
	var tops: Array[float] = []
	var bottoms: Array[float] = []
	for c in 22:
		var cx := c * 2.0
		var wx := world_x + cx
		var top := at.y + 2.0 + _wave(wx, 1.7, 6.0)
		var bottom := at.y + height + _wave(wx, 4.1, 5.0)
		# The foot rounds off a little at an outer corner.
		if outer_left and c < 2:
			bottom -= (2 - c) * 2.0
		if outer_right and c > 19:
			bottom -= (c - 19) * 2.0
		tops.append(top)
		bottoms.append(bottom)
	# The shadow the cliff throws on the ground below.
	for c in 22:
		for k in 6:
			draw_rect(Rect2(at.x + c * 2.0, bottoms[c] + k * 2.0, 2.0, 2.0), Color(0, 0, 0, 0.32 * (1.0 - k / 6.0)))
	_face_strip(at, tops, bottoms, ("peak" if above == T.PEAK else "rock") if rocky else _soil_name(above))
	var wall: Array = stones if rocky else _soil(above)
	var look := ("peak" if above == T.PEAK else "rock") if rocky else _soil_name(above)
	if outer_left:
		_corner(at, tops, bottoms, true, wall, look)
	if outer_right:
		_corner(at, tops, bottoms, false, wall, look)
	_cliff_trim(at, tops, bottoms, stones, grass, rocky, random)
	match _variant(above, x, y):
		"mossy":
			_mossy(at, tops, bottoms, random)
		"rooted":
			_rooted(at, tops, bottoms, random)
		"ore":
			_ore(at, tops, bottoms, above, random)


## The end of a face at an outer corner: the plateau's side wall coming
## down to the foot, lit on the west, shaded on the east, in bands like the
## face, with a hard edge where it turns.
func _corner(at: Vector2, tops: Array[float], bottoms: Array[float], west: bool, wall: Array, look: String = "rock") -> void:
	var columns := range(0, 5) if west else range(17, 22)
	var row := maxi(FACE_LOOKS.find(look), 0) * FACE_HEIGHT
	var world_x := int(float(origin.x) * TILE + at.x)
	# The side turning toward the light is brighter, the other in shade.
	var light := Color(1.16, 1.12, 1.05) if west else Color(0.68, 0.66, 0.76)
	for c: int in columns:
		var y0: float = tops[c]
		var tall: float = bottoms[c] - y0
		if tall <= 0.0:
			continue
		var sy := maxf(FACE_TOP + (y0 - at.y), 0.0)
		tall = minf(tall, FACE_HEIGHT - sy)
		var sx := posmod(world_x + c * 2, FACE_WIDTH)
		draw_texture_rect_region(FACES, Rect2(at.x + c * 2.0, y0, 2.0, tall), Rect2(sx, row + sy, 2.0, tall), light)
	# The outer edge, a dark pixel line, and the turn of the corner: a lit
	# (or dim) pixel line where the two sides meet.
	var edge_c := 0 if west else 21
	var turn_c := 5 if west else 16
	var edge_x := at.x + (0.0 if west else TILE - 1.0)
	draw_rect(Rect2(edge_x, tops[edge_c], 1.0, bottoms[edge_c] - tops[edge_c]), wall[3])
	var turn: Color = (wall[1] as Color).lightened(0.15) if west else (wall[2] as Color).darkened(0.3)
	var turn_x := at.x + turn_c * 2.0 + (0.0 if west else 1.0)
	draw_rect(Rect2(turn_x, tops[turn_c] + 3.0, 1.0, maxf(bottoms[turn_c] - tops[turn_c] - 5.0, 0.0)), Color(turn, 0.85))


## The face, laid down a two-pixel column at a time from its look's strip,
## between the wavy lip and foot; the strip is placed by world position so
## neighbouring faces run on without a seam.
func _face_strip(at: Vector2, tops: Array[float], bottoms: Array[float], look: String) -> void:
	var row := maxi(FACE_LOOKS.find(look), 0) * FACE_HEIGHT
	var world_x := int(float(origin.x) * TILE + at.x)
	for c in 22:
		var y0: float = tops[c]
		var y1: float = bottoms[c]
		if y1 <= y0:
			continue
		var sy := maxf(FACE_TOP + (y0 - at.y), 0.0)
		var tall := minf(y1 - y0, FACE_HEIGHT - sy)
		if tall <= 0.0:
			continue
		var sx := posmod(world_x + c * 2, FACE_WIDTH)
		draw_texture_rect_region(FACES, Rect2(at.x + c * 2.0, y0, 2.0, tall), Rect2(sx, row + sy, 2.0, tall))


## Which earthen look a bank under this ground has.
static func _soil_name(top: int) -> String:
	if top in [T.SNOW, T.FROSTPINE, T.SALT]:
		return "frozen"
	if top in [T.SAND]:
		return "sandstone"
	if top in [T.ASH, T.CINDER]:
		return "ash"
	return "earth"


## What every face shares: roots from the lip, the lip itself hanging over,
## and the foot with its fallen stones and grass.
func _cliff_trim(at: Vector2, tops: Array[float], bottoms: Array[float], stones: Array, grass: Color, rocky: bool, random: RandomNumberGenerator) -> void:
	# Roots hanging from the lip.
	if not rocky:
		for k in random.randi_range(1, 3):
			var c := random.randi_range(1, 20)
			var ry := tops[c] + 4.0
			var length := random.randi_range(3, 8)
			for step in length:
				if ry > bottoms[c] - 2.0:
					break
				draw_rect(Rect2(at.x + c * 2.0, ry, 2.0, 2.0), Color("3a2414"))
				ry += 2.0
				if random.randf() < 0.35:
					c = clampi(c + (1 if random.randf() < 0.5 else -1), 0, 21)
	# The lip: the ground above, bright along its edge, hanging over the
	# stones in tufts and clumps; blades standing up along the very edge.
	for c in 22:
		var px := at.x + c * 2.0
		var top := tops[c]
		if bottoms[c] <= top:
			continue
		draw_rect(Rect2(px, top - 2.0, 2.0, 8.0), grass)
		draw_rect(Rect2(px, top - 2.0, 2.0, 2.0), grass.lightened(0.25))
		draw_rect(Rect2(px, top + 6.0, 2.0, 2.0), grass.darkened(0.3))
		if rocky:
			continue
		# Tufts and whole clumps of grass hanging over the stones.
		var hang := 0.0
		if random.randf() < 0.55:
			hang = float(random.randi_range(1, 3)) * 2.0
		if random.randf() < 0.16:
			hang = float(random.randi_range(4, 7)) * 2.0
		if hang > 0.0:
			var room := bottoms[c] - top - 8.0
			draw_rect(Rect2(px, top + 6.0, 2.0, minf(hang, room)), grass.darkened(0.12))
			draw_rect(Rect2(px, top + 6.0 + minf(hang, room), 2.0, 2.0), grass.darkened(0.4))
		if random.randf() < 0.35:
			draw_rect(Rect2(px, top - 4.0, 2.0, 2.0), grass.lightened(0.12))
	# The foot: a dark line, fallen boulders half sunk in the ground, and a
	# little grass growing against the face.
	for c in 22:
		if bottoms[c] > tops[c]:
			draw_rect(Rect2(at.x + c * 2.0, bottoms[c] - 2.0, 2.0, 2.0), stones[3])
	for k in random.randi_range(0, 2):
		var c := random.randi_range(2, 18)
		var bw := float(random.randi_range(3, 5)) * 2.0
		var bh := float(random.randi_range(2, 3)) * 2.0
		var bx := at.x + c * 2.0
		var by := bottoms[c] - bh + 2.0
		draw_rect(Rect2(bx, by, bw, bh), stones[0])
		draw_rect(Rect2(bx, by, bw, 2.0), stones[1])
		draw_rect(Rect2(bx + bw - 2.0, by, 2.0, bh), stones[2])
		draw_rect(Rect2(bx, by + bh, bw, 2.0), Color(0, 0, 0, 0.35))
	if not rocky:
		for k in random.randi_range(1, 3):
			var c := random.randi_range(0, 20)
			draw_rect(Rect2(at.x + c * 2.0, bottoms[c] - 4.0, 2.0, 4.0), grass.darkened(0.1))
			draw_rect(Rect2(at.x + c * 2.0 + 2.0, bottoms[c] - 2.0, 2.0, 2.0), grass)


# --- three looks a cliff can take, a stretch at a time

## Moss: [shade, base, light, highlight].
const MOSS := [Color("2c4a22"), Color("3f6a2c"), Color("5e8e36"), Color("8cb84a")]
## Roots: [dark, base, light, highlight].
const ROOT := [Color("2a1810"), Color("4a2e1a"), Color("6c4428"), Color("8e6038")]
## Ore in the rock, by the land above: [dark, base, light, glint].
const ORES := {
	"iron": [Color("4a2010"), Color("8a3e1c"), Color("c06a34"), Color("f0b070")],
	"copper": [Color("1e4a40"), Color("2e7a68"), Color("54b096"), Color("a8ecd2")],
	"gold": [Color("6a4a14"), Color("a8822a"), Color("e0c050"), Color("fff0a8")],
	"ember": [Color("5a160a"), Color("a8341a"), Color("f07a2c"), Color("ffd27a")],
	"void": [Color("2e1658"), Color("5e34a0"), Color("9a6ae8"), Color("e6d4ff")],
	"salt": [Color("6a7684"), Color("a4b2c0"), Color("dce6ee"), Color("ffffff")],
}


## Which look this stretch of cliff has. Neighbouring faces share it, so a
## cliff is mossy (or rooted, or veined) for a run of several tiles.
func _variant(above: int, x: int, y: int) -> String:
	var wx := origin.x + x
	var wy := origin.y + y
	var region := Vector2i(floori(wx / 6.0), floori(wy / 4.0))
	var roll := posmod(hash(Vector3i(region.x, region.y, 4471)), 100)
	if above in [T.DARK_GRASS, T.BOG, T.FUNGAL, T.FROSTPINE]:
		return "mossy" if roll < 42 else "rooted" if roll < 70 else ""
	if above in [T.DEAD_GRASS, T.THORN, T.CRIMSON, T.MUD]:
		return "rooted" if roll < 40 else "mossy" if roll < 58 else ""
	if above in [T.ROCK, T.PEAK, T.ASH, T.CINDER, T.SAND, T.SALT, T.VOIDSCAR]:
		return "ore" if roll < 45 else "mossy" if roll < 55 and above == T.ROCK else ""
	return ""


## Moss over the lip and the stones: caps hanging in strands of different
## lengths, cushions on the faces, damp streaks under them, ferns at the foot.
func _mossy(at: Vector2, tops: Array[float], bottoms: Array[float], random: RandomNumberGenerator) -> void:
	var world_x := float(origin.x) * TILE + at.x
	for c in 22:
		var top: float = tops[c] + 6.0
		var room: float = bottoms[c] - top - 4.0
		if room <= 0.0:
			continue
		var px := at.x + c * 2.0
		# A cap of moss along the lip, hanging further here and there.
		var hang := 2.0 + maxf(_wave(world_x + c * 2.0, 6.3, 6.0), 0.0)
		if random.randf() < 0.18:
			hang += float(random.randi_range(2, 5)) * 2.0
		hang = minf(hang, room)
		var y0 := top
		while y0 < top + hang:
			var step := (y0 - top) / maxf(hang, 1.0)
			var colour: Color = MOSS[3] if y0 == top else MOSS[2] if step < 0.35 else MOSS[1] if step < 0.8 else MOSS[0]
			draw_rect(Rect2(px, y0, 2.0, 2.0), colour)
			y0 += 2.0
		# The damp it leaves running down the stone.
		if hang > 6.0 and random.randf() < 0.5:
			var streak := minf(float(random.randi_range(2, 5)) * 2.0, room - hang)
			if streak > 0.0:
				draw_rect(Rect2(px, top + hang, 2.0, streak), Color(0.02, 0.05, 0.03, 0.28))
	# Cushions of moss on the face, lit from the upper left.
	for k in random.randi_range(2, 4):
		var c := random.randi_range(1, 18)
		var w := random.randi_range(2, 4)
		var cy: float = tops[c] + 14.0 + float(random.randi_range(0, 5)) * 2.0
		if cy + 6.0 > bottoms[c] - 2.0:
			continue
		for i in w:
			var px := at.x + (c + i) * 2.0
			var h := 4.0 if i == 0 or i == w - 1 else 6.0
			draw_rect(Rect2(px, cy + (2.0 if h < 6.0 else 0.0), 2.0, h - 2.0), MOSS[1])
			draw_rect(Rect2(px, cy + (2.0 if h < 6.0 else 0.0), 2.0, 2.0), MOSS[2] if i < w - 1 else MOSS[1])
			draw_rect(Rect2(px, cy + h, 2.0, 2.0), MOSS[0])
		draw_rect(Rect2(at.x + c * 2.0 + 2.0, cy, 2.0, 2.0), MOSS[3])
	# Little ferns against the foot.
	for k in random.randi_range(1, 3):
		var c := random.randi_range(1, 19)
		var fx := at.x + c * 2.0
		var fy: float = bottoms[c] - 2.0
		draw_rect(Rect2(fx, fy - 4.0, 2.0, 4.0), MOSS[1])
		draw_rect(Rect2(fx - 2.0, fy - 6.0, 2.0, 2.0), MOSS[2])
		draw_rect(Rect2(fx + 2.0, fy - 6.0, 2.0, 2.0), MOSS[2])
		draw_rect(Rect2(fx, fy - 8.0, 2.0, 2.0), MOSS[3])


## Roots of whatever grows above, broken out through the face: thick and
## lit along one side, thinning as they go, a few rootlets off them, and
## where they reach the foot, arching back into the ground.
func _rooted(at: Vector2, tops: Array[float], bottoms: Array[float], random: RandomNumberGenerator) -> void:
	for k in random.randi_range(1, 2):
		var c := random.randi_range(2, 18)
		var y: float = tops[c] + 6.0
		var width := 2
		var steps := 0
		while c >= 0 and c < 21 and y < bottoms[c] - 4.0 and steps < 30:
			var px := at.x + c * 2.0
			for i in width:
				var colour: Color = ROOT[2] if i == 0 else ROOT[1]
				draw_rect(Rect2(px + i * 2.0, y, 2.0, 2.0), colour)
			# Lit on the left, in shadow on the right.
			draw_rect(Rect2(px - 2.0, y, 2.0, 2.0), Color(ROOT[3], 0.55))
			draw_rect(Rect2(px + width * 2.0, y, 2.0, 2.0), ROOT[0])
			# A rootlet now and then.
			if steps > 2 and random.randf() < 0.18:
				var side := -1 if random.randf() < 0.5 else 1
				var rx := px + (side * 2.0 if side < 0 else width * 2.0)
				for r in random.randi_range(2, 4):
					rx += side * 2.0
					draw_rect(Rect2(rx, y + r * 2.0, 2.0, 2.0), ROOT[1] if r < 2 else ROOT[0])
			y += 2.0
			steps += 1
			if random.randf() < 0.3:
				c = clampi(c + (1 if random.randf() < 0.5 else -1), 1, 19)
			if steps == 8 and random.randf() < 0.6:
				width = 1
		# Into the ground at the foot: an arch over the soil.
		if steps > 4 and c > 1 and c < 19:
			var foot: float = bottoms[c]
			var px := at.x + c * 2.0
			draw_rect(Rect2(px, foot - 2.0, 2.0, 2.0), ROOT[1])
			draw_rect(Rect2(px + 2.0, foot - 4.0, 4.0, 2.0), ROOT[2])
			draw_rect(Rect2(px + 2.0, foot - 2.0, 4.0, 2.0), ROOT[0])
			draw_rect(Rect2(px + 6.0, foot - 2.0, 2.0, 2.0), ROOT[1])
			draw_rect(Rect2(px + 2.0, foot, 6.0, 2.0), Color(0, 0, 0, 0.3))
	# A knot where a root broke off.
	if random.randf() < 0.6:
		var c := random.randi_range(3, 17)
		var ky: float = tops[c] + 12.0 + float(random.randi_range(0, 4)) * 2.0
		if ky + 6.0 < bottoms[c]:
			var kx := at.x + c * 2.0
			draw_rect(Rect2(kx, ky, 4.0, 4.0), ROOT[1])
			draw_rect(Rect2(kx, ky, 2.0, 2.0), ROOT[3])
			draw_rect(Rect2(kx + 2.0, ky + 2.0, 2.0, 2.0), ROOT[0])
			draw_rect(Rect2(kx + 4.0, ky + 2.0, 2.0, 2.0), Color(0, 0, 0, 0.35))


## A vein of ore running through the face: a jagged line of it crossing the
## stones, bright where it catches the light, and a few nuggets or crystals
## standing out of the rock.
func _ore(at: Vector2, tops: Array[float], bottoms: Array[float], above: int, random: RandomNumberGenerator) -> void:
	var kind := "iron"
	match above:
		T.SAND:
			kind = "gold"
		T.ASH, T.CINDER:
			kind = "ember"
		T.VOIDSCAR:
			kind = "void"
		T.SALT:
			kind = "salt"
		_:
			kind = "copper" if posmod(hash(Vector2i(origin.x / 8, origin.y / 8)), 3) == 0 else "iron"
	var ore: Array = ORES[kind]
	# The vein: wandering down and across the face.
	var c := random.randi_range(0, 8)
	var y: float = tops[c] + 8.0
	var going := 1 if random.randf() < 0.7 else -1
	var steps := 0
	while c >= 0 and c < 22 and y < bottoms[c] - 4.0 and steps < 26:
		var px := at.x + c * 2.0
		draw_rect(Rect2(px, y, 2.0, 2.0), ore[1])
		draw_rect(Rect2(px, y + 2.0, 2.0, 2.0), ore[0])
		if random.randf() < 0.22:
			draw_rect(Rect2(px, y, 2.0, 2.0), ore[3] if random.randf() < 0.4 else ore[2])
		if random.randf() < 0.6:
			c += going
		else:
			y += 2.0
		if random.randf() < 0.12:
			y += 2.0
		steps += 1
	# Nuggets (or crystals) standing out of the rock.
	for k in random.randi_range(1, 3):
		var nc := random.randi_range(2, 18)
		var ny: float = tops[nc] + 12.0 + float(random.randi_range(0, 6)) * 2.0
		if ny + 8.0 > bottoms[nc]:
			continue
		var nx := at.x + nc * 2.0
		if kind in ["void", "salt"]:
			# A crystal: a point of light, a lit face and a shaded one.
			draw_rect(Rect2(nx, ny, 2.0, 2.0), ore[3])
			draw_rect(Rect2(nx - 2.0, ny + 2.0, 2.0, 4.0), ore[2])
			draw_rect(Rect2(nx, ny + 2.0, 2.0, 4.0), ore[1])
			draw_rect(Rect2(nx + 2.0, ny + 4.0, 2.0, 2.0), ore[0])
			draw_rect(Rect2(nx - 2.0, ny + 6.0, 6.0, 2.0), Color(0, 0, 0, 0.35))
		else:
			draw_rect(Rect2(nx, ny, 4.0, 4.0), ore[1])
			draw_rect(Rect2(nx, ny, 2.0, 2.0), ore[3])
			draw_rect(Rect2(nx + 2.0, ny, 2.0, 2.0), ore[2])
			draw_rect(Rect2(nx + 2.0, ny + 2.0, 2.0, 2.0), ore[0])
			draw_rect(Rect2(nx, ny + 4.0, 4.0, 2.0), Color(0, 0, 0, 0.35))
