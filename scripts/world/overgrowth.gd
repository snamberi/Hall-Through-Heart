class_name Overgrowth
extends Node2D
## Green taking back a camp left empty: ivy climbing the tent and crates,
## weeds through the cold fire, tall grass and, in time, young trees. Drawn
## pixel by pixel; each piece stands just in front of what it grows on, so
## it sorts with the world like the thing itself.

const LEAF := [Color("26391f"), Color("3c5a2a"), Color("557d35"), Color("78a447")]
const STEM := Color("2c3f22")
const BLOSSOM := [Color("d8c45a"), Color("c88aa8"), Color("e8e4d0")]

## "ivy" (climbing a thing `reach` wide and up to `height` tall), "weeds"
## (a tuft of tall grass and flowers) or "sapling" (a young tree).
var kind := "weeds"
## 1 a few days on, 2 long abandoned.
var stage := 1
var reach := 30.0
var height := 30.0
var grain := 0


static func make(what: String, at: Vector2, how_far: int, wide: float = 30.0, tall: float = 30.0) -> Overgrowth:
	var growth := Overgrowth.new()
	growth.kind = what
	growth.position = (at + Vector2(0, 1)).round()
	growth.stage = how_far
	growth.reach = wide
	growth.height = tall
	growth.grain = absi(hash(at))
	return growth


## Spreads growth over an abandoned camp at `center`: ivy on the given
## things ([position, width, height] each), weeds about, and saplings once
## it has been empty long enough.
static func cover(placed: Array, center: Vector2, things: Array, how_far: int, random: RandomNumberGenerator) -> void:
	for thing: Array in things:
		var ivy := make("ivy", thing[0], how_far, thing[1], thing[2])
		placed.append(ivy)
	for i in 6 + how_far * 6:
		var at := center + Vector2(random.randf_range(-170, 170), random.randf_range(-120, 130))
		var weeds := make("weeds", at, how_far)
		placed.append(weeds)
	if how_far >= 2:
		for i in random.randi_range(1, 3):
			var at := center + Vector2(random.randf_range(-150, 150), random.randf_range(-110, 120))
			var sapling := make("sapling", at, how_far)
			placed.append(sapling)


func _draw() -> void:
	match kind:
		"ivy":
			_ivy()
		"sapling":
			_sapling()
		_:
			_weeds()


func _bits(k: int) -> int:
	return absi(hash(Vector2i(grain, k)))


func _ivy() -> void:
	var strands := int(reach / 7.0) + stage * 2
	var top := height * (0.45 if stage == 1 else 0.85)
	for s in strands:
		var x := -reach / 2.0 + reach * (s + 0.5) / strands + float(_bits(s) % 5) - 2.0
		var tall := top * (0.5 + float(_bits(s + 40) % 50) / 100.0)
		var y := 0.0
		var sway := 0.0
		while y > -tall:
			var at := Vector2(roundf(x + sway), roundf(y) - 1.0)
			draw_rect(Rect2(at, Vector2(1, 2)), STEM)
			# Leaves either side, now and then.
			var bits := _bits(int(-y) * 7 + s)
			if bits % 3 == 0:
				var side := -2.0 if bits % 2 == 0 else 1.0
				draw_rect(Rect2(at + Vector2(side, 0), Vector2(2, 2)), LEAF[1 + bits % 3])
				draw_rect(Rect2(at + Vector2(side + (0.0 if side < 0 else 1.0), 0), Vector2(1, 1)), LEAF[3])
			if bits % 23 == 0 and stage >= 2:
				draw_rect(Rect2(at + Vector2(-1, -1), Vector2(2, 2)), BLOSSOM[bits % 3])
			y -= 2.0
			sway += (float(bits % 3) - 1.0) * 0.5
			sway = clampf(sway, -3.0, 3.0)
	# A skirt of leaves along the foot.
	for x in range(int(-reach / 2.0), int(reach / 2.0), 3):
		var bits := _bits(x + 300)
		draw_rect(Rect2(x, -2 - bits % 3, 3, 3), LEAF[bits % 3])


func _weeds() -> void:
	var blades := 4 + stage * 3
	for b in blades:
		var bits := _bits(b)
		var x := float(bits % 13) - 6.0
		var tall := 6.0 + float(bits % 7) + stage * 3.0
		var lean := 1.0 if bits % 2 == 0 else -1.0
		for y in int(tall):
			var at := Vector2(roundf(x + lean * floorf(y / 4.0)), -y - 1)
			draw_rect(Rect2(at, Vector2(1, 1)), LEAF[1 + (y * 2) / int(tall) if y < tall - 1 else 3])
		if bits % 5 == 0:
			var head := Vector2(roundf(x + lean * floorf(tall / 4.0)), -tall - 2)
			draw_rect(Rect2(head + Vector2(-1, 0), Vector2(3, 2)), BLOSSOM[bits % 3])
	draw_rect(Rect2(-5, -1, 10, 1), LEAF[0])


func _sapling() -> void:
	# A thin trunk and a small, layered crown.
	draw_rect(Rect2(-1, -16, 2, 16), Color("5a4030"))
	draw_rect(Rect2(-1, -16, 1, 16), Color("745438"))
	draw_rect(Rect2(1, -9, 3, 1), Color("5a4030"))
	for layer: Array in [[-24, 7, 0], [-20, 9, 1], [-15, 8, 2]]:
		var y: int = layer[0]
		var half: int = layer[1]
		for row in 5:
			var w := half - absi(row - 2)
			draw_rect(Rect2(-w, y + row, w * 2, 1), LEAF[layer[2] + (1 if row < 2 else 0)])
	draw_rect(Rect2(-3, -27, 6, 3), LEAF[2])
	draw_rect(Rect2(-1, -28, 2, 1), LEAF[3])
	draw_rect(Rect2(-6, -1, 12, 1), Color(0.02, 0.02, 0.05, 0.3))
