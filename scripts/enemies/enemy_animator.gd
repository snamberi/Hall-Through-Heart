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


static var _cache: Dictionary = {}


func _ready() -> void:
	if sheet:
		rebuild()


## Builds the animations from `sheet`; call again after changing it.
func rebuild() -> void:
	if not _cache.has(sheet):
		_cache[sheet] = SheetAnimations.build(sheet, frame_size, ROWS)
	sprite_frames = _cache[sheet]
	play("idle")


var _time := 0.0
var _base_position := Vector2.ZERO
var _base_ready := false


func _process(delta: float) -> void:
	if sprite_frames == null:
		return
	if not _base_ready:
		_base_position = position
		_base_ready = true
	_time += delta
	_choose_animation()
	_add_motion()


## Body motion on top of the frames, so nothing ever stands frozen: a
## breath while idle, a bob while walking, a coiling tremble while winding
## up (and the last frames rocking if the wind-up outlasts them), a
## stretch into the strike, and a jolt when staggered.
func _add_motion() -> void:
	var offset := Vector2.ZERO
	var squash := Vector2.ONE
	var tilt := 0.0
	match _enemy.state:
		Enemy.State.WINDUP:
			var progress := clampf(1.0 - _enemy._state_time_left / maxf(_enemy.windup_time, 0.05), 0.0, 1.0)
			tilt = -0.14 * progress
			offset = Vector2(randf_range(-1.6, 1.6) * progress, randf_range(-0.8, 0.8) * progress)
			squash = Vector2(1.0 + 0.08 * progress, 1.0 - 0.07 * progress)
			if not is_playing() and animation == "windup":
				var count := sprite_frames.get_frame_count("windup")
				frame = count - 1 - (int(_time * 10.0) % 2)
		Enemy.State.LUNGE:
			tilt = 0.16
			squash = Vector2(1.12, 0.92)
			offset = Vector2(3.0, 0.0)
		Enemy.State.RECOVER:
			tilt = 0.05 * sin(_time * 12.0)
		Enemy.State.STAGGER:
			tilt = -0.22
			offset = Vector2(-3.0, 0.0)
		Enemy.State.DEAD:
			pass
		_:
			if _enemy.velocity.length() > 8.0:
				var pace := 9.0 if _enemy.state == Enemy.State.CHASE else 6.5
				offset.y = -absf(sin(_time * pace)) * 2.5
				tilt = 0.045 * sin(_time * pace)
				squash = Vector2(1.0 - 0.02 * absf(sin(_time * pace)), 1.0 + 0.03 * absf(sin(_time * pace)))
			else:
				var breath := sin(_time * 2.6)
				squash = Vector2(1.0 - 0.015 * breath, 1.0 + 0.025 * breath)
	position = _base_position + offset
	scale = scale.lerp(squash, 0.35)
	rotation = lerp_angle(rotation, tilt, 0.3)


func _choose_animation() -> void:
	match _enemy.state:
		Enemy.State.WINDUP:
			_play_for("windup", _enemy.windup_time)
		Enemy.State.LUNGE:
			_play_for("lunge", _enemy.lunge_time)
		Enemy.State.RECOVER:
			# Shooters and slammers show their strike as they recover from it.
			if animation == "windup":
				_play_for("lunge", 0.3)
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
