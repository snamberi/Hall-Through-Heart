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
	if style == "igloo":
		house.sprite().texture = IGLOO
		house.sprite().hframes = 1
		house.sprite().frame = 0


static var IGLOO: Texture2D = _draw_igloo()


static func _draw_igloo() -> Texture2D:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var outline := Color("0c0a10")
	for y in 64:
		for x in 64:
			var dx := (x - 32) / 28.0
			var dy := (y - 58) / 30.0
			var inside := dx * dx + dy * dy <= 1.0 and y <= 58
			if inside:
				var shade := Color("eef2f6") if dx < -0.2 and dy < -0.5 else Color("c8d4e0") if dx > 0.4 or dy > -0.25 else Color("dde6ee")
				# Rows of snow blocks.
				if (y - 30) % 7 == 0 or ((x + (y / 7) * 4) % 9 == 0 and y > 30):
					shade = Color("aab8c6")
				image.set_pixel(x, y, shade)
	for y in range(46, 59):
		for x in range(25, 40):
			var dx := (x - 32) / 7.5
			var dy := (y - 58) / 12.0
			if dx * dx + dy * dy <= 1.0:
				image.set_pixel(x, y, Color("1a2030"))
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
