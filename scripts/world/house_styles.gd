class_name HouseStyles
extends RefCounted
## Houses take after the land they stand on: snow-bound igloos, sandstone
## in the desert, black timber in the ash, and plain wood elsewhere.

const T := TerrainTiles.Type
## style id -> [name, roof tint, wall tint]
const STYLES := {
	"wood": ["Timber House", Color.WHITE, Color.WHITE],
	"igloo": ["Igloo", Color(0.92, 0.96, 1.0), Color(0.95, 0.98, 1.0)],
	"sandstone": ["Sandstone House", Color(0.95, 0.75, 0.45), Color(1.15, 1.0, 0.75)],
	"blackwood": ["Blackwood House", Color(0.6, 0.35, 0.3), Color(0.55, 0.5, 0.5)],
	"mushroom": ["Mushroom House", Color(1.2, 0.6, 1.0), Color(1.0, 0.95, 0.85)],
	"crystal": ["Crystal House", Color(0.8, 0.6, 1.3), Color(0.75, 0.7, 1.0)],
}


static func style_for(tile: int) -> String:
	match tile:
		T.SNOW, T.FROSTPINE, T.PEAK, T.SALT:
			return "igloo"
		T.SAND:
			return "sandstone"
		T.ASH, T.CINDER, T.TAR:
			return "blackwood"
		T.FUNGAL:
			return "mushroom"
		T.VOIDSCAR:
			return "crystal"
	return "wood"


## Repaints a house prop for the ground it stands on.
static func dress(house: Prop, tile: int, style: String = "") -> void:
	if style == "":
		style = style_for(tile)
	var colours: Array = STYLES[style]
	house.sprite().modulate = colours[2]
	# Snow settles on the roof and icicles hang from the eaves.
	house.sprite().material = Wind.roof
	if style == "igloo":
		house.sprite().texture = IGLOO
		house.sprite().hframes = 1
		house.sprite().frame = 0


static var IGLOO: Texture2D = _draw_igloo()


static func _draw_igloo() -> Texture2D:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var outline := Color("222238")
	var facet := Color("accacf")
	var pale := Color("dbe7dc")
	var shade := Color("7a9fb0")
	var mortar := Color("627e9b")
	for y in 64:
		for x in 64:
			var dx := (x - 32) / 28.0
			var dy := (y - 58) / 30.0
			if y < 28 or y > 58 or dx * dx + dy * dy > 1.0:
				continue
			# Staggered joints follow the curve of the dome. The upper edge
			# of each block holds a thin, light snow lip.
			var course := floori((y - 28) / 6.0)
			var course_edge := (y - 28) % 6
			var joint := posmod(x + 5 * (course % 2), 11)
			var block := facet
			if x < 31 - floori((y - 29) / 3.0):
				block = pale
			elif dx > 0.32 + dy * 0.16 or y > 53:
				block = shade
			if course_edge == 0 or joint == 0:
				block = mortar
			elif course_edge == 1 or joint == 1:
				block = block.lerp(pale, 0.57)
			image.set_pixel(x, y, block)
	# An ice arch and a timber screen in its recess. Amber pixels pick out
	# the light from within against the blue shadow.
	for y in range(39, 59):
		for x in range(19, 46):
			var u := (x - 32) / 12.0
			var v := (y - 57) / 16.0
			if u * u + v * v > 1.0:
				continue
			var inside := (x - 32) / 8.0
			var up := (y - 57) / 11.0
			var arch := pale if x < 33 else shade
			if inside * inside + up * up <= 1.0:
				arch = Color("372c42")
				if x >= 28 and x <= 35 and y >= 51:
					arch = Color("775052") if x != 31 else Color("9e6560")
				if x == 28 and y >= 52 and y <= 55:
					arch = Color("e7b481")
			image.set_pixel(x, y, arch)
	image.set_pixel(33, 54, Color("e3ad78"))
	for y in 64:
		for x in 64:
			if image.get_pixel(x, y).a > 0.0:
				continue
			for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var near := Vector2i(x, y) + step
				if near.x >= 0 and near.y >= 0 and near.x < 64 and near.y < 64 and image.get_pixelv(near).a > 0.5 and image.get_pixelv(near) != outline:
					image.set_pixel(x, y, outline)
					break
	return ImageTexture.create_from_image(image)
