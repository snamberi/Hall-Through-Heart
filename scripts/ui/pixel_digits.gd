extends RefCounted
## Numbers drawn in hand-set pixel digits (3 by 5 cells, each cell a whole
## block of screen pixels) with a dark outline: the HUD's pools, experience
## and boss health read like the damage numbers. Words keep the type.
## (Loaded by path.)

const GLYPHS := {
	"0": ["111", "101", "101", "101", "111"], "1": ["010", "110", "010", "010", "111"],
	"2": ["111", "001", "111", "100", "111"], "3": ["111", "001", "111", "001", "111"],
	"4": ["101", "101", "111", "001", "001"], "5": ["111", "100", "111", "001", "111"],
	"6": ["111", "100", "111", "101", "111"], "7": ["111", "001", "010", "010", "010"],
	"8": ["111", "101", "111", "101", "111"], "9": ["111", "101", "111", "001", "111"],
	"/": ["001", "001", "010", "100", "100"], " ": ["0", "0", "0", "0", "0"],
	"-": ["000", "000", "111", "000", "000"], "+": ["000", "010", "111", "010", "000"],
	"%": ["101", "001", "010", "100", "101"], ".": ["0", "0", "0", "0", "1"],
	"k": ["100", "101", "110", "101", "101"], "m": ["000", "101", "111", "101", "101"],
}


## How wide `text` is drawn with blocks of `block` pixels.
static func width(text: String, block: int) -> int:
	var total := 0
	for ch in text:
		total += ((GLYPHS.get(ch, GLYPHS["0"]) as Array)[0] as String).length() * block + block
	return maxi(total - block, 0)


## Draws `text` with its top-left at `at` (rounded to whole pixels): an
## outline a pixel wide, then the digits, lit on the top row and shaded on
## the bottom one.
static func draw(canvas: CanvasItem, at: Vector2, text: String, block: int, colour: Color, outline: Color = Color(0.02, 0.01, 0.03, 0.9)) -> void:
	var origin := at.round()
	for pass_ in 2:
		var x := origin.x
		for ch in text:
			var rows: Array = GLYPHS.get(ch, GLYPHS["0"])
			for r in rows.size():
				var row: String = rows[r]
				for col in row.length():
					if row[col] != "1":
						continue
					var cell := Rect2(Vector2(x + col * block, origin.y + r * block), Vector2(block, block))
					if pass_ == 0:
						canvas.draw_rect(cell.grow(1.0), outline)
					else:
						var shade := colour.lightened(0.2) if r == 0 else colour.darkened(0.2) if r == rows.size() - 1 else colour
						canvas.draw_rect(cell, shade)
			x += (rows[0] as String).length() * block + block
