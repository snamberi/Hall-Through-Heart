class_name EnemyAnimator
extends AnimatedSprite2D
## Plays an enemy's animation from its state.
##
## Works for any enemy whose sheet has the rows below, in order. Rows must
## match HUSK_ANIMATIONS in tools/generate_art.py.

const ROWS: Array[Dictionary] = [
	{"name": "idle", "frames": 4, "fps": 6.0, "loop": true},
	{"name": "walk", "frames": 8, "fps": 10.0, "loop": true},
	{"name": "windup", "frames": 6, "fps": 13.0, "loop": false},
	{"name": "lunge", "frames": 6, "fps": 16.0, "loop": false},
	{"name": "hurt", "frames": 3, "fps": 12.0, "loop": false},
	{"name": "death", "frames": 8, "fps": 10.0, "loop": false},
]

@export var sheet: Texture2D
@export var frame_size := 96

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
		Enemy.State.STAGGER:
			_play_for("hurt", 0.22)
		Enemy.State.DEAD:
			_play_for("death", death_seconds())
		_:
			var moving := _enemy.velocity.length() > 8.0
			speed_scale = 1.5 if _enemy.state == Enemy.State.CHASE else 1.0
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
