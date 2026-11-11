class_name SlashEffect
extends Node2D
## The swoosh of a melee swing: a pixel-art crescent that sweeps and fades.
##
## Wide swings (over 200 degrees) use a full-circle swoosh instead.

const CRESCENT: Texture2D = preload("res://assets/effects/slash.png")
const SPIN: Texture2D = preload("res://assets/effects/spin.png")
const FRAMES := 6
## Radius of the art in its texture, and the arc the crescent was drawn at.
const ART_RADIUS := 29.0
const ART_ARC := deg_to_rad(130.0)

var _sprite: Sprite2D
## A bright, additive copy inside the swoosh: the hot edge of the blade.
var _core: Sprite2D
var _sparks: CPUParticles2D
var _tween: Tween
var _flip := false


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.hframes = FRAMES
	_sprite.visible = false
	add_child(_sprite)
	_core = Sprite2D.new()
	_core.hframes = FRAMES
	_core.visible = false
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_core.material = additive
	add_child(_core)
	_sparks = CPUParticles2D.new()
	_sparks.emitting = false
	_sparks.one_shot = true
	_sparks.amount = 8
	_sparks.lifetime = 0.25
	_sparks.explosiveness = 0.7
	_sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_sparks.emission_sphere_radius = 6.0
	_sparks.direction = Vector2.RIGHT
	_sparks.spread = 70.0
	_sparks.gravity = Vector2.ZERO
	_sparks.initial_velocity_min = 80.0
	_sparks.initial_velocity_max = 160.0
	_sparks.damping_min = 300.0
	_sparks.damping_max = 400.0
	_sparks.scale_amount_min = 1.0
	_sparks.scale_amount_max = 2.0
	add_child(_sparks)


func play(
	direction: Vector2, radius: float, arc_radians: float, duration: float,
	color: Color = Color(0.95, 0.9, 0.8)
) -> void:
	var full_circle := arc_radians > deg_to_rad(200.0)
	_sprite.texture = SPIN if full_circle else CRESCENT
	_sprite.frame = 0
	_sprite.visible = true
	_sprite.modulate = color
	rotation = direction.angle()
	var size := radius / ART_RADIUS
	# Narrow thrusts squeeze the crescent; alternate swings mirror it.
	var squeeze := 1.0 if full_circle else clampf(arc_radians / ART_ARC, 0.4, 1.25)
	_flip = not _flip
	_sprite.scale = Vector2(size, size * squeeze * (-1.0 if _flip and not full_circle else 1.0))
	_core.texture = _sprite.texture
	_core.frame = 0
	_core.visible = true
	_core.scale = _sprite.scale * 0.92
	_core.modulate = Color(color.lightened(0.5), 0.75)
	_sparks.position = Vector2(radius * 0.8, 0)
	_sparks.color = color.lightened(0.4)
	_sparks.restart()
	_sparks.emitting = true
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel()
	_tween.tween_property(_sprite, "frame", FRAMES - 1, duration)
	_tween.tween_property(_core, "frame", FRAMES - 1, duration)
	_tween.tween_property(_core, "modulate:a", 0.0, duration * 0.8)
	_tween.chain().tween_callback(func() -> void:
		_sprite.hide()
		_core.hide()
	)
