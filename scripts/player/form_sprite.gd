class_name FormSprite
extends AnimatedSprite2D
## The body the player wears while transformed: a creature's sheet, moved by
## what the player is doing (standing, running, striking, reeling).

var _player: Player
var _busy := 0.0


func setup(player: Player) -> void:
	_player = player
	visible = false


## Shows a form's body ("" hides it again).
func wear(id: String) -> void:
	if id == "":
		visible = false
		return
	var form: Dictionary = Transformations.FORMS[id]
	sprite_frames = SheetAnimations.build(load("res://assets/sprites/enemies/%s.png" % form["sheet"]), 96, EnemyAnimator.ROWS)
	modulate = form["tint"]
	var size: float = form["scale"]
	scale = Vector2(size, size)
	position = Vector2(0, -23.0 * size + 2.0)
	visible = true
	play("idle")


## A strike or a blow taken: play it through before going back to moving.
func act(animation_name: String, seconds: float) -> void:
	if not visible or not sprite_frames.has_animation(animation_name):
		return
	_busy = seconds
	play(animation_name)
	speed_scale = SheetAnimations.seconds(sprite_frames, animation_name) / maxf(seconds, 0.05)


func _process(delta: float) -> void:
	if not visible:
		return
	_busy = maxf(_busy - delta, 0.0)
	if _busy > 0.0:
		return
	speed_scale = 1.0
	var wanted := "walk" if _player.velocity.length() > 20.0 else "idle"
	if animation != wanted:
		play(wanted)
