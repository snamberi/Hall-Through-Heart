class_name ShieldGuard
extends Node2D
## The shield raised while blocking, held toward the mouse. It is drawn from
## hand-placed pixel maps in three views: its face (held toward the screen,
## south), its edge (east and west) and its back with the straps (north,
## behind the body). The aim is taken in eight directions; diagonals use
## the nearer view, shifted to that side.
##
## Map keys: o outline, r rim, H rim shine, R rim shade, v rivet, f face,
## F face shade, h face shine, b emblem (a bronze heart), B emblem shade,
## w back planks, W back shade, g wood knot, s strap.

const FRONT := [
	".oooooooooooo.",
	"ovHHHHHHHHHHvo",
	"orhhfffffffFRo",
	"orhfbbffbbfFRo",
	"orhbBbbbbBbFRo",
	"orhbbbbbbbbFRo",
	"orhfbbbbbbFFRo",
	"orhffbbbbFFFRo",
	".orhffbbFFFRo.",
	".orhfffFFFFRo.",
	"..orhffFFFRo..",
	"..orhfFFFFRo..",
	"...orfFFRRo...",
	"....orFRRo....",
	".....oRRo.....",
	"......oo......",
]
const BACK := [
	".oooooooooooo.",
	"ovrrrrrrrrrrvo",
	"orwwwwwwwwwWRo",
	"orwssssssssWRo",
	"orwgwwwwwgwWRo",
	"orwwwwgwwwwWRo",
	"orwssssssssWRo",
	"orwwwwwwwwWWRo",
	".orwwgwwwWWRo.",
	".orwwwwwWWWRo.",
	"..orwwwWWWRo..",
	"..orwwWWWWRo..",
	"...orwWWRRo...",
	"....orWRRo....",
	".....oRRo.....",
	"......oo......",
]
## Three-quarter view, its face turned toward the east.
const SIDE := [
	".ooooo..",
	"oHrrrRo.",
	"orhfbFRo",
	"orhbBFRo",
	"orhbbFRo",
	"orhfbFRo",
	"orhffFRo",
	"orhffFRo",
	".orhfFRo",
	".orhfFRo",
	".orffFRo",
	"..orfRo.",
	"..orFRo.",
	"...oRo..",
	"...oRo..",
	"....o...",
]
## Where the shield sits for each of eight aims (east first, going round
## clockwise): [offset of its middle from the feet, view, in front of the body].
const PLACES := [
	[Vector2(12, -19), "side", true],
	[Vector2(8, -14), "front", true],
	[Vector2(0, -13), "front", true],
	[Vector2(-8, -14), "front", true],
	[Vector2(-12, -19), "side", true],
	[Vector2(-12, -26), "back", false],
	[Vector2(10, -28), "back", false],
	[Vector2(12, -26), "back", false],
]

var direction := Vector2.DOWN
var metal := Color(0.7, 0.72, 0.78)
var face := Color(0.45, 0.5, 0.62)
var _flash := 0.0


## Colours from the shield: its metal for the rim, a darker face, and the
## rarity in the boss.
func dress(item: Item) -> void:
	if item == null:
		return
	metal = ItemDB.tier_color(item.tier_level()).lightened(0.15)
	face = ItemDB.tier_color(item.tier_level()).darkened(0.5)
	queue_redraw()


func flash() -> void:
	_flash = 0.15
	queue_redraw()


## Which of the eight places the aim falls in.
func place_index() -> int:
	return posmod(roundi(direction.angle() / (PI / 4.0)), 8)


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(_flash - delta, 0.0)
		queue_redraw()
	var place: Array = PLACES[place_index()]
	z_index = 1 if place[2] else -1
	queue_redraw()


func _draw() -> void:
	var place: Array = PLACES[place_index()]
	var rows: Array = {"front": FRONT, "back": BACK, "side": SIDE}[place[1]]
	var mirrored: bool = place[1] == "side" and direction.x < 0.0
	var colors := {
		"o": Color("1a1420"), "r": metal, "H": metal.lightened(0.45), "R": metal.darkened(0.35), "v": Color("f4e4b8"),
		"f": face, "F": face.darkened(0.3), "h": face.lightened(0.3), "b": Color("f4d27a"), "B": Color("b8863a"),
		"w": Color("7a5a40"), "W": Color("4a3626"), "g": Color("5a4030"), "s": Color("2a2018"),
	}
	var width := String(rows[0]).length()
	var origin := (place[0] as Vector2) - Vector2(width / 2, rows.size() / 2)
	for y in rows.size():
		var row: String = rows[y]
		for x in width:
			var key := row[width - 1 - x] if mirrored else row[x]
			if key == ".":
				continue
			var color: Color = colors[key]
			if _flash > 0.0 and key != "o":
				color = color.lerp(Color.WHITE, 0.7)
			draw_rect(Rect2(origin + Vector2(x, y), Vector2.ONE), color)
	# A blow caught on the shield: sparks thrown off its face.
	if _flash > 0.0 and place[2]:
		var out := 1.0 - _flash / 0.15
		var middle := place[0] as Vector2
		for k in 5:
			var angle := direction.angle() + (k - 2) * 0.45
			var at := (middle + Vector2.from_angle(angle) * (9.0 + out * 10.0)).round()
			draw_rect(Rect2(at, Vector2(2, 1) if k % 2 == 0 else Vector2(1, 2)), Color(1.0, 0.92, 0.6, 1.0 - out))
