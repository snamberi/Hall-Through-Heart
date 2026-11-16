class_name ShieldGuard
extends Node2D
## The shield raised while blocking, held toward the mouse. It is drawn from
## hand-placed pixel maps in three views: its face (held toward the screen,
## south), its edge (east and west) and its back with the straps (north,
## behind the body). The aim is taken in eight directions; diagonals use
## the nearer view, shifted to that side.
##
## Map keys: o outline, r rim, R rim shade, f face, F face shade, h shine,
## b boss, w back wood, W back shade, s strap.

const FRONT := [
	".ooooooooo.",
	"orrrrrrrrRo",
	"orhffbffFRo",
	"orhfbbbfFRo",
	"orhffbffFRo",
	"orfffffFFRo",
	".orfffFFRo.",
	".orffFFFRo.",
	"..orfFFRo..",
	"...orFRo...",
	"....oRo....",
	".....o.....",
]
const BACK := [
	".ooooooooo.",
	"owwwwwwwwwo",
	"owwssssswwo",
	"owwwwwwwwWo",
	"owwssssswWo",
	"owwwwwwwWWo",
	".owwwwwWWo.",
	".owwwwWWWo.",
	"..owwWWWo..",
	"...owWWo...",
	"....oWo....",
	".....o.....",
]
## Three-quarter view, its face turned toward the east.
const SIDE := [
	".oooo..",
	"orrrRo.",
	"orhfFRo",
	"orfbFRo",
	"orhfFRo",
	"orffFRo",
	".orfFRo",
	".orFRo.",
	"..orRo.",
	"..oRo..",
	"...o...",
]
## Where the shield sits for each of eight aims (east first, going round
## clockwise): [offset of its middle from the feet, view, in front of the body].
const PLACES := [
	[Vector2(12, -18), "side", true],
	[Vector2(8, -13), "front", true],
	[Vector2(0, -12), "front", true],
	[Vector2(-8, -13), "front", true],
	[Vector2(-12, -18), "side", true],
	[Vector2(-12, -25), "back", false],
	[Vector2(10, -27), "back", false],
	[Vector2(12, -25), "back", false],
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
	face = ItemDB.tier_color(item.tier_level()).darkened(0.3)
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
		"o": Color("1a1420"), "r": metal, "R": metal.darkened(0.35), "f": face, "F": face.darkened(0.3),
		"h": face.lightened(0.35), "b": Color("e8c070"), "w": Color("7a5a40"), "W": Color("4a3626"), "s": Color("2a2018"),
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
