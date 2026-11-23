extends RefCounted
## The mark of a Hardcore world: a black heart with two horns, crimson veins
## that pulse with each beat, and a drop of blood forming at its tip. Drawn
## whole-pixel at any whole scale onto any canvas (the health medal, menu
## frames, the loading screen). (Loaded by path.)

## One character a pixel: H horn, # body, v vein, + glint, - rim shadow.
const SHAPE: Array[String] = [
	"H.........H",
	"HH.......HH",
	".H##...##H.",
	"#+v##.##v##",
	"#+#v###v##-",
	"##v#vvv#v#-",
	"###v#v#v##-",
	".###vvv##-.",
	"..###v##-..",
	"...##v#-...",
	"....##-....",
	".....#.....",
]
const BODY := Color("1a0c10")
const RIM := Color("0a0406")
const HORN := Color("5a4a50")
const GLINT := Color("6a4048")
const VEIN := Color("b8202e")
const VEIN_LIT := Color("ff5060")
const DROP := Color("c0202c")


## Draws it centred on `centre`, `px` screen pixels to a heart pixel, at
## time `t` (seconds), so the veins pulse and the drop gathers and falls.
static func draw(canvas: CanvasItem, centre: Vector2, px: int, t: float, alpha: float = 1.0) -> void:
	var beat := fmod(t, 1.1)
	var lit := beat < 0.12 or (beat > 0.24 and beat < 0.34)
	var size := Vector2(SHAPE[0].length(), SHAPE.size()) * px
	var origin := (centre - size / 2.0).round()
	for y in SHAPE.size():
		for x in SHAPE[y].length():
			var mark := SHAPE[y][x]
			var colour: Color
			match mark:
				"H":
					colour = HORN
				"#":
					colour = BODY
				"v":
					colour = VEIN_LIT if lit else VEIN
				"+":
					colour = GLINT
				"-":
					colour = RIM
				_:
					continue
			canvas.draw_rect(Rect2(origin + Vector2(x, y) * px, Vector2(px, px)), Color(colour, alpha))
	# A drop gathers at the tip, then falls and is gone.
	var cycle := fmod(t, 2.6) / 2.6
	var tip := origin + Vector2(5 * px, size.y)
	if cycle < 0.55:
		var swell := int(cycle / 0.55 * 2.0) + 1
		canvas.draw_rect(Rect2(tip, Vector2(px, px * swell)), Color(DROP, alpha))
	elif cycle < 0.85:
		var fall := (cycle - 0.55) / 0.3
		canvas.draw_rect(Rect2((tip + Vector2(0, roundf(fall * px * 8.0) + px)).round(), Vector2(px, px * 2)), Color(DROP, alpha * (1.0 - fall)))
