class_name EnemyAnimator
extends AnimatedSprite2D
## Plays an enemy's animation from its state.
##
## Works for any enemy whose sheet has these rows of 12 frames, in order:
## idle, walk, windup, lunge, death.

const ROWS: Array[Dictionary] = [
	{"name": "idle", "seconds": 1.2, "loop": true},
	{"name": "walk", "seconds": 0.7, "loop": true},
	{"name": "windup", "seconds": 0.45, "loop": false},
	{"name": "lunge", "seconds": 0.22, "loop": false},
	{"name": "death", "seconds": 0.6, "loop": false},
]

@export var sheet: Texture2D
@export var frame_size := 64

@onready var _enemy: Enemy = owner


func _ready() -> void:
	sprite_frames = SheetAnimations.build(sheet, frame_size, ROWS)
	play("idle")


func _process(_delta: float) -> void:
	match _enemy.state:
		Enemy.State.WINDUP:
			_play_for("windup", _enemy.windup_time)
		Enemy.State.LUNGE:
			_play_for("lunge", _enemy.lunge_time)
		Enemy.State.DEAD:
			_play_for("death", death_seconds())
		_:
			var moving := _enemy.velocity.length() > 8.0
			speed_scale = 1.6 if _enemy.state == Enemy.State.CHASE else 1.0
			var wanted := "walk" if moving else "idle"
			if animation != wanted:
				play(wanted)


func death_seconds() -> float:
	return SheetAnimations.seconds(sprite_frames, "death")


func _play_for(animation_name: String, duration: float) -> void:
	if animation == animation_name:
		return
	speed_scale = SheetAnimations.seconds(sprite_frames, animation_name) / maxf(duration, 0.05)
	play(animation_name)
