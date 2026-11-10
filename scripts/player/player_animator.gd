class_name PlayerAnimator
extends AnimatedSprite2D
## Picks and plays the player's animation from what the player is doing.
##
## Sheet rows (12 frames each) must match ROWS; see tools/generate_art.py.

signal rebirth_finished

const SHEET: Texture2D = preload("res://assets/sprites/player_sheet.png")
const FRAME_SIZE := 64
const ROWS: Array[Dictionary] = [
	{"name": "idle", "seconds": 1.2, "loop": true},
	{"name": "run", "seconds": 0.6, "loop": true},
	{"name": "attack", "seconds": 0.3, "loop": false},
	{"name": "dodge", "seconds": 0.22, "loop": false},
	{"name": "death", "seconds": 1.3, "loop": false},
	{"name": "rebirth", "seconds": 1.3, "loop": false},
]
## Seconds between fading after-images while dodging.
const GHOST_INTERVAL := 0.04

## An animation that must finish before movement animations resume.
var _busy := ""
var _ghost_left := 0.0

@onready var _player: Player = owner


func _ready() -> void:
	sprite_frames = SheetAnimations.build(SHEET, FRAME_SIZE, ROWS)
	animation_finished.connect(_on_animation_finished)
	play("idle")


func _process(delta: float) -> void:
	match _player.state:
		Player.State.DEAD, Player.State.REVIVING:
			return
		Player.State.DODGE:
			_play_for("dodge", _player.dodge_duration)
			_busy = ""
			_ghost_left -= delta
			if _ghost_left <= 0.0:
				_ghost_left = GHOST_INTERVAL
				_spawn_ghost()
			return
	if _busy != "":
		return
	if _player.velocity.length() > 20.0:
		# Legs keep pace with how fast the player actually moves.
		speed_scale = clampf(_player.velocity.length() / 200.0, 0.6, 1.8)
		if animation != "run":
			play("run")
	else:
		speed_scale = 1.0
		if animation != "idle":
			play("idle")


## Plays the swing, fitted into `duration` seconds.
func play_attack(duration: float) -> void:
	_busy = "attack"
	_play_for("attack", duration, true)


func play_death() -> void:
	_busy = "death"
	_play_for("death", SheetAnimations.seconds(sprite_frames, "death"), true)


func play_rebirth() -> void:
	_busy = "rebirth"
	_play_for("rebirth", SheetAnimations.seconds(sprite_frames, "rebirth"), true)


func _play_for(animation_name: String, duration: float, restart: bool = false) -> void:
	if animation == animation_name and not restart:
		return
	speed_scale = SheetAnimations.seconds(sprite_frames, animation_name) / maxf(duration, 0.05)
	stop()
	play(animation_name)


func _on_animation_finished() -> void:
	if animation == "rebirth":
		rebirth_finished.emit()
	if animation == _busy and animation != "death":
		_busy = ""


func _spawn_ghost() -> void:
	var ghost := Sprite2D.new()
	ghost.texture = sprite_frames.get_frame_texture(animation, frame)
	ghost.global_position = global_position
	ghost.scale = global_scale
	ghost.modulate = Color(0.7, 0.85, 1.0, 0.45)
	_player.get_parent().add_child(ghost)
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.25)
	tween.tween_callback(ghost.queue_free)
