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
var _tween: Tween
var _flip := false


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.hframes = FRAMES
	_sprite.visible = false
	add_child(_sprite)


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
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_sprite, "frame", FRAMES - 1, duration)
	_tween.tween_callback(_sprite.hide)
