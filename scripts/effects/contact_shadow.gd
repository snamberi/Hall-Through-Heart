class_name ContactShadow
extends Node2D
## A small soft shadow right under something standing on the ground, like
## the ones under characters, so props and plants look set down rather than
## pasted on. Its width comes from the sprite's own footprint: the widest
## solid row near its base.

## Half-width and half-height of the shadow.
var radius := Vector2(10, 3)

static var _footprints: Dictionary = {}
static var _images: Dictionary = {}


func _ready() -> void:
	z_as_relative = false
	z_index = -8


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, radius.y / radius.x))
	draw_circle(Vector2.ZERO, radius.x, Color(0.02, 0.02, 0.06, 0.16))
	draw_circle(Vector2.ZERO, radius.x * 0.68, Color(0.02, 0.02, 0.06, 0.16))


## Puts a contact shadow under a still sprite (one whose parent's origin is
## its foot), unless its art already has one drawn in.
static func under(sprite: Sprite2D) -> ContactShadow:
	var region := sprite.region_rect if sprite.region_enabled else Rect2(Vector2.ZERO, sprite.texture.get_size() / Vector2(sprite.hframes, sprite.vframes))
	if not sprite.region_enabled and (sprite.hframes > 1 or sprite.vframes > 1):
		region.position = Vector2(sprite.frame % sprite.hframes, sprite.frame / sprite.hframes) * region.size
	var width := footprint(sprite.texture, Rect2i(region)) * absf(sprite.scale.x)
	if width <= 0.0:
		return null
	var shadow := ContactShadow.new()
	shadow.radius = Vector2(clampf(width * 0.62, 5.0, 40.0), clampf(width * 0.16, 2.0, 8.0))
	shadow.position = Vector2(sprite.position.x, 0.0)
	sprite.get_parent().add_child(shadow)
	return shadow


## The width of a picture's base: its widest fully solid row among the
## bottom few. 0 when the picture already has a shadow baked in below it.
static func footprint(texture: Texture2D, region: Rect2i) -> float:
	var key := "%d:%s" % [texture.get_rid().get_id(), region]
	if _footprints.has(key):
		return _footprints[key]
	if not _images.has(texture):
		_images[texture] = texture.get_image()
	var image: Image = _images[texture]
	var result := 0.0
	if image != null:
		if image.is_compressed():
			image.decompress()
		var bottom := -1
		var baked := 0
		for y in range(region.end.y - 1, region.position.y - 1, -1):
			for x in range(region.position.x, region.end.x):
				var pixel := image.get_pixel(x, y)
				if pixel.a > 0.85:
					bottom = y
					break
				if pixel.a > 0.15 and pixel.v < 0.12:
					baked += 1
			if bottom >= 0:
				break
		# A row or more of dark see-through pixels under the art is a shadow
		# already drawn in.
		if bottom >= 0 and baked < 6:
			for y in range(bottom, maxi(bottom - 6, region.position.y - 1), -1):
				var left := -1
				var right := -1
				for x in range(region.position.x, region.end.x):
					if image.get_pixel(x, y).a > 0.85:
						if left < 0:
							left = x
						right = x
				if left >= 0:
					result = maxf(result, float(right - left + 1))
	_footprints[key] = result
	return result
