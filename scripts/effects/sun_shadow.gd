class_name SunShadow
extends AnimatedSprite2D
## Shadows cast across the ground by the sun, or faintly by the moon. Each is
## the silhouette of a sprite, laid down from its feet: they lean west in the
## morning, shrink toward noon, and stretch east toward dusk. All shadows
## share one material, so the sky moves them all at once.
##
## `cast` makes a still shadow for a tree or a prop; a SunShadow node follows
## an animated sprite (the player, monsters, villagers) frame by frame.

const SHADER := """
shader_type canvas_item;
uniform float skew = 0.5;
uniform float squash = 0.4;
uniform float strength = 0.3;

void vertex() {
	// Local y = 0 is the ground line. Everything above it is laid down
	// behind the caster and leaned by the sun; flipped casters lean the same way.
	float flip = sign(MODEL_MATRIX[0].x);
	float rise = min(VERTEX.y, 0.0);
	VERTEX.x -= rise * skew * flip;
	VERTEX.y = rise * squash + max(VERTEX.y, 0.0) * 0.3;
}

void fragment() {
	COLOR = vec4(0.03, 0.03, 0.08, texture(TEXTURE, UV).a * strength);
}
"""
static var shared: ShaderMaterial = _make_material()

## The animated sprite this shadow copies.
var source: AnimatedSprite2D
var _frames_size := Vector2.ZERO


static func _make_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


## Moves every shadow to suit the hour. `time` runs 0 to 1 through the day.
static func update(time: float, darkness: float, indoors: bool, lightning: float) -> void:
	if indoors:
		shared.set_shader_parameter("strength", 0.0)
		return
	var skew := 0.45
	var squash := 0.45
	var strength := 0.08 + (1.0 - darkness) * 0.28
	if time > 0.24 and time < 0.78:
		# The sun crosses from east to west: long shadows at either end of the day.
		var sun := clampf((time - 0.24) / 0.54, 0.0, 1.0)
		skew = lerpf(-1.25, 1.25, sun)
		squash = 0.3 + absf(sun - 0.5) * 0.7
	# Heavy cloud softens them.
	if Atmosphere.weather != "":
		strength *= 0.45
	strength = maxf(strength, lightning * 0.55)
	shared.set_shader_parameter("skew", skew)
	shared.set_shader_parameter("squash", squash)
	shared.set_shader_parameter("strength", strength)


## Gives a still sprite (a centred Sprite2D whose parent's origin is its foot)
## a shadow on the ground.
static func cast(sprite: Sprite2D) -> Sprite2D:
	var shadow := Sprite2D.new()
	shadow.texture = sprite.texture
	shadow.region_enabled = sprite.region_enabled
	shadow.region_rect = sprite.region_rect
	shadow.hframes = sprite.hframes
	shadow.vframes = sprite.vframes
	shadow.frame = sprite.frame
	shadow.flip_h = sprite.flip_h
	var size := sprite.region_rect.size if sprite.region_enabled else sprite.texture.get_size() / Vector2(sprite.hframes, sprite.vframes)
	shadow.centered = false
	shadow.offset = Vector2(-size.x / 2.0, -(size.y / 2.0 - sprite.position.y / sprite.scale.y))
	shadow.position = Vector2(sprite.position.x, 0.0)
	shadow.scale = sprite.scale
	shadow.material = shared
	shadow.z_as_relative = false
	shadow.z_index = -8
	sprite.get_parent().add_child(shadow)
	return shadow


## A shadow that follows an animated sprite; added beside it.
static func follow(sprite: AnimatedSprite2D) -> SunShadow:
	var shadow := SunShadow.new()
	shadow.source = sprite
	shadow.centered = false
	shadow.material = shared
	shadow.z_as_relative = false
	shadow.z_index = -8
	sprite.get_parent().add_child.call_deferred(shadow)
	return shadow


func _process(_delta: float) -> void:
	if not is_instance_valid(source):
		queue_free()
		return
	var shown := source.visible and source.sprite_frames != null
	if shown and source.has_method("casts_shadow"):
		shown = source.casts_shadow()
	visible = shown
	if not shown:
		return
	if sprite_frames != source.sprite_frames:
		sprite_frames = source.sprite_frames
		_frames_size = Vector2.ZERO
	if not sprite_frames.has_animation(source.animation):
		return
	if animation != source.animation:
		animation = source.animation
	frame = source.frame
	flip_h = source.flip_h
	if _frames_size == Vector2.ZERO:
		var texture := sprite_frames.get_frame_texture(animation, 0)
		if texture == null:
			return
		_frames_size = texture.get_size()
	scale = source.scale
	position = Vector2(source.position.x, 0.0)
	offset = Vector2(-_frames_size.x / 2.0, -(_frames_size.y / 2.0 - source.position.y / source.scale.y))
