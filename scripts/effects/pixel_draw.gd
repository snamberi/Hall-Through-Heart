extends RefCounted
## Shapes drawn in whole pixels, for effects in the world: discs, rings,
## arcs, lines and filled polygons, each pixel either fully in or out, so
## an effect looks like the pixel art around it rather than a smooth
## vector drawing laid over it. The calls take the same arguments as the
## CanvasItem ones they replace, with the item to draw on first:
##     PX.disc(self, centre, radius, colour)        for draw_circle
##     PX.arc(self, centre, radius, from, to, n, colour, width)  for draw_arc
##     PX.line(self, a, b, colour, width)            for draw_line
##     PX.polyline(self, points, colour, width)      for draw_polyline
##     PX.poly(self, points, colour)                 for draw_colored_polygon
## Shapes are drawn a row at a time (one rectangle per run of pixels), so
## big rings stay cheap; translucent colours never overlap themselves.
## (Loaded by path.)


## A filled disc (or, with filled false, a ring `width` pixels thick).
static func disc(ci: CanvasItem, centre: Vector2, radius: float, colour: Color, filled: bool = true, width: float = -1.0, _antialiased: bool = false) -> void:
	if not filled:
		arc(ci, centre, radius, 0.0, TAU, 0, colour, maxf(width, 1.0))
		return
	var c := centre.floor()
	var r := maxf(radius, 0.5)
	var rows := ceili(r)
	for dy in range(-rows, rows + 1):
		var span := r * r - float(dy * dy)
		if span < 0.0:
			continue
		var half := floori(sqrt(span))
		ci.draw_rect(Rect2(c.x - half, c.y + dy, half * 2 + 1, 1), colour)


## A ring of `width` pixels round `centre`, from angle `from` to `to`
## (all the way round when they span TAU or more).
static func arc(ci: CanvasItem, centre: Vector2, radius: float, from: float, to: float, _points: int, colour: Color, width: float = 1.0, _antialiased: bool = false) -> void:
	var c := centre.floor()
	var outer := radius + maxf(width, 1.0) * 0.5
	var inner := maxf(radius - maxf(width, 1.0) * 0.5, 0.0)
	var full := absf(to - from) >= TAU - 0.001
	if not full:
		# Part of the way round: step along the arc a pixel at a time across
		# its width, gathering only the pixels it covers, then draw them a
		# row at a time.
		var pixels := {}
		var steps := maxi(ceili(absf(to - from) * outer * 1.5), 1)
		for k in steps + 1:
			var way := Vector2.from_angle(from + (to - from) * k / steps)
			var rr := inner
			while rr <= outer:
				var p := (centre + way * rr).floor()
				pixels[Vector2i(int(p.x), int(p.y))] = true
				rr += 0.5
		_flush(ci, pixels, colour)
		return
	var rows := ceili(outer)
	for dy in range(-rows, rows + 1):
		var o2 := outer * outer - float(dy * dy)
		if o2 < 0.0:
			continue
		var oh := floori(sqrt(o2))
		var i2 := inner * inner - float(dy * dy)
		var ih := floori(sqrt(i2)) if i2 >= 0.0 else -1
		if ih < 0:
			ci.draw_rect(Rect2(c.x - oh, c.y + dy, oh * 2 + 1, 1), colour)
		else:
			ci.draw_rect(Rect2(c.x - oh, c.y + dy, oh - ih, 1), colour)
			ci.draw_rect(Rect2(c.x + ih + 1, c.y + dy, oh - ih, 1), colour)


## A straight line `width` pixels wide.
static func line(ci: CanvasItem, a: Vector2, b: Vector2, colour: Color, width: float = 1.0, _antialiased: bool = false) -> void:
	var pixels := {}
	_line_pixels(pixels, a, b, maxi(roundi(width), 1))
	_flush(ci, pixels, colour)


## Joined lines through `points`.
static func polyline(ci: CanvasItem, points: PackedVector2Array, colour: Color, width: float = 1.0, _antialiased: bool = false) -> void:
	var pixels := {}
	for k in range(1, points.size()):
		_line_pixels(pixels, points[k - 1], points[k], maxi(roundi(width), 1))
	_flush(ci, pixels, colour)


## A filled polygon (any outline that does not cross itself).
static func poly(ci: CanvasItem, points: PackedVector2Array, colour: Color, _uvs: PackedVector2Array = PackedVector2Array(), _texture: Texture2D = null) -> void:
	if points.size() < 3:
		return
	var top := INF
	var bottom := -INF
	for p in points:
		top = minf(top, p.y)
		bottom = maxf(bottom, p.y)
	for y in range(floori(top), ceili(bottom)):
		var cy := float(y) + 0.5
		var cuts: Array[float] = []
		for k in points.size():
			var p := points[k]
			var q := points[(k + 1) % points.size()]
			if (p.y <= cy) != (q.y <= cy):
				cuts.append(p.x + (cy - p.y) / (q.y - p.y) * (q.x - p.x))
		cuts.sort()
		for k in range(0, cuts.size() - 1, 2):
			var x0 := roundi(cuts[k])
			var x1 := roundi(cuts[k + 1])
			if x1 > x0:
				ci.draw_rect(Rect2(x0, y, x1 - x0, 1), colour)


static func _line_pixels(into: Dictionary, a: Vector2, b: Vector2, width: int) -> void:
	var x0 := floori(a.x)
	var y0 := floori(a.y)
	var x1 := floori(b.x)
	var y1 := floori(b.y)
	var dx := absi(x1 - x0)
	var dy := -absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy
	var lo := -(width - 1) / 2
	while true:
		for ox in range(lo, lo + width):
			for oy in range(lo, lo + width):
				into[Vector2i(x0 + ox, y0 + oy)] = true
		if x0 == x1 and y0 == y1:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy


## Draws a set of pixels, joining each row's neighbours into one rectangle.
static func _flush(ci: CanvasItem, pixels: Dictionary, colour: Color) -> void:
	var rows := {}
	for p: Vector2i in pixels:
		if not rows.has(p.y):
			rows[p.y] = []
		(rows[p.y] as Array).append(p.x)
	for y: int in rows:
		var xs: Array = rows[y]
		xs.sort()
		var start: int = xs[0]
		var last: int = xs[0]
		for k in range(1, xs.size()):
			var x: int = xs[k]
			if x != last + 1:
				ci.draw_rect(Rect2(start, y, last - start + 1, 1), colour)
				start = x
			last = x
		ci.draw_rect(Rect2(start, y, last - start + 1, 1), colour)
