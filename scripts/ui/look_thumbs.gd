class_name LookThumbs
extends RefCounted
## Small still pictures of a character's look, for choosing between options
## at a glance: the body in its colours, with hair, ears, horns, tail and the
## rest laid over it, cut to the head (or the whole figure, for wings and
## tails). Drawn once per look and kept.

## Where to cut from a 96px frame.
const HEAD := Rect2i(27, 22, 42, 38)
const FIGURE := Rect2i(12, 16, 72, 60)

static var _cache: Dictionary = {}
static var _sheets: Dictionary = {}


static func _frame(path: String, column: int = 0, row: int = 0) -> Image:
	var key := "%s:%d:%d" % [path, column, row]
	if not _sheets.has(key):
		var sheet := (load("res://assets/sprites/%s.png" % path) as Texture2D).get_image()
		if sheet.is_compressed():
			sheet.decompress()
		sheet.convert(Image.FORMAT_RGBA8)
		_sheets[key] = sheet.get_region(Rect2i(column * 96, row * 96, 96, 96))
	return _sheets[key]


## A look's portrait. `whole` shows the full figure rather than the head.
static func texture(appearance: Dictionary, whole: bool = false) -> Texture2D:
	var worn := Appearance.resolved(appearance)
	var key := "%s|%s" % [JSON.stringify(worn), whole]
	if _cache.has(key):
		return _cache[key]
	var cut := FIGURE if whole else HEAD
	var canvas := Image.create(cut.size.x, cut.size.y, false, Image.FORMAT_RGBA8)
	var layers := Appearance.layers(worn)
	var behind: Array = []
	var front: Array = []
	for feature in Appearance.FEATURES:
		if layers.has(feature[0]):
			(behind if feature[3] else front).append(layers[feature[0]])
	for layer: Dictionary in behind:
		_lay(canvas, _frame("looks/" + layer["sheet"]).get_region(cut), layer["tint"])
	_lay(canvas, _recolour(_frame("player_sheet").get_region(cut), worn), Color.WHITE)
	for layer: Dictionary in front:
		_lay(canvas, _frame("looks/" + layer["sheet"]).get_region(cut), layer["tint"])
	var result := ImageTexture.create_from_image(canvas)
	_cache[key] = result
	return result


## The body's own colours swapped for the look's (as the body shader does).
static func _recolour(image: Image, worn: Dictionary) -> Image:
	var targets: Array[Color] = []
	for hex: String in Appearance.SKIN_TONES[worn["skin"]]:
		targets.append(Color(hex))
	for hex: String in Appearance.HAIR[worn["hair"]]:
		targets.append(Color(hex))
	for hex: String in Appearance.CLOTHES[worn["clothes"]]:
		targets.append(Color(hex))
	for hex: String in Appearance.TROUSERS[worn["trousers"]]:
		targets.append(Color(hex))
	var sources: Array[Color] = []
	for hex in Appearance.SOURCE:
		sources.append(Color(hex))
	var alpha := Appearance.alpha(worn)
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			if pixel.a <= 0.0:
				continue
			for index in sources.size():
				var source := sources[index]
				if absf(pixel.r - source.r) + absf(pixel.g - source.g) + absf(pixel.b - source.b) < 0.04:
					pixel = Color(targets[index], pixel.a)
					break
			pixel.a *= alpha
			image.set_pixel(x, y, pixel)
	return image


## Lays one image over another, tinted (multiplied) first.
static func _lay(canvas: Image, layer: Image, tint: Color) -> void:
	for y in layer.get_height():
		for x in layer.get_width():
			var pixel := layer.get_pixel(x, y)
			if pixel.a <= 0.0:
				continue
			var coloured := Color(pixel.r * tint.r, pixel.g * tint.g, pixel.b * tint.b, pixel.a)
			var under := canvas.get_pixel(x, y)
			canvas.set_pixel(x, y, under.blend(coloured))
