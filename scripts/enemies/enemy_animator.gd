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

## Walking away (tools/generate_back_views.py): sheets eleven rows tall
## have these two, seen from behind.
const BACK_ROWS: Array[Dictionary] = [
	{"name": "idle_back", "frames": 4, "fps": 6.0, "loop": true, "row": 9},
	{"name": "walk_back", "frames": 8, "fps": 10.0, "loop": true, "row": 10},
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
		var rows: Array[Dictionary] = ROWS.duplicate()
		if sheet.get_height() >= (BACK_ROWS[1]["row"] + 1) * frame_size:
			rows.append_array(BACK_ROWS)
		_cache[sheet] = SheetAnimations.build(sheet, frame_size, rows)
	sprite_frames = _cache[sheet]
	_has_back = sprite_frames.has_animation("walk_back")
	play("idle")


var _time := 0.0
## Whether this sheet has walking-away rows, and whether it last moved away.
var _has_back := false
var _away := false
var _base_position := Vector2.ZERO
var _base_ready := false
## A blow just landed: the hurt frames (drawn squashed on the impact and
## stretched as it recoils) play for this long.
var _flinch_left := 0.0
## Knocked a pixel or two back along the blow, for a moment.
var _knock := Vector2.ZERO


## Shows a blow landing: the hurt frames, and a jolt away from it.
func flinch(push: Vector2 = Vector2.ZERO) -> void:
	_flinch_left = 0.22
	var away := push.normalized() if push.length() > 1.0 else Vector2.ZERO
	# Into the sprite's own space (it is mirrored when facing left).
	var mirrored := signf(get_parent().scale.x) if get_parent() is Node2D and (get_parent() as Node2D).scale.x != 0.0 else 1.0
	_knock = Vector2(roundf(away.x * 2.0) * mirrored, roundf(away.y))


func _process(delta: float) -> void:
	if sprite_frames == null:
		return
	if not _base_ready:
		_base_position = position
		_base_ready = true
	_time += delta
	_flinch_left = maxf(_flinch_left - delta, 0.0)
	if _flinch_left == 0.0:
		_knock = Vector2.ZERO
	_choose_animation()
	_add_motion()


## Body motion on top of the frames, in whole pixels only (the art is never
## stretched or turned in the game): a tremble while winding up (and the last
## frames rocking if the wind-up outlasts them), a step into the strike, a
## jolt when staggered or struck, and a bob while walking.
func _add_motion() -> void:
	var offset := Vector2.ZERO
	match _enemy.state:
		Enemy.State.WINDUP:
			var progress := clampf(1.0 - _enemy._state_time_left / maxf(_enemy.windup_time, 0.05), 0.0, 1.0)
			# The tremble grows as the strike comes: a pixel, then two.
			var shake := roundi(progress * 2.0)
			if shake > 0 and int(_time * 30.0) % 2 == 0:
				offset = Vector2(float(shake) * (1.0 if int(_time * 60.0) % 2 == 0 else -1.0), 0.0)
			if not is_playing() and animation == "windup":
				var count := sprite_frames.get_frame_count("windup")
				frame = count - 1 - (int(_time * 10.0) % 2)
		Enemy.State.LUNGE:
			offset = Vector2(2.0, 0.0)
		Enemy.State.STAGGER:
			offset = Vector2(-2.0, 0.0)
		Enemy.State.DEAD:
			pass
		_:
			if _enemy.velocity.length() > 8.0:
				var pace := 9.0 if _enemy.state == Enemy.State.CHASE else 6.5
				offset.y = -roundf(absf(sin(_time * pace)) * 2.0)
	if _flinch_left > 0.0:
		offset += _knock
	position = _base_position + offset
	scale = Vector2.ONE
	rotation = 0.0


func _choose_animation() -> void:
	# A blow shows its hurt frames, unless it is mid-attack or falling.
	if _flinch_left > 0.0 and not _enemy.state in [Enemy.State.WINDUP, Enemy.State.LUNGE, Enemy.State.DEAD, Enemy.State.STAGGER]:
		_play_for("hurt", 0.22)
		return
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
			if moving:
				# Heading up the screen: seen from behind.
				_away = _has_back and _enemy.velocity.y < -0.55 * _enemy.velocity.length()
			var wanted := ("walk" if moving else "idle") + ("_back" if _away else "")
			if animation != wanted:
				play(wanted)


func death_seconds() -> float:
	return SheetAnimations.seconds(sprite_frames, "death")


func _play_for(animation_name: String, duration: float) -> void:
	if animation == animation_name:
		return
	speed_scale = SheetAnimations.seconds(sprite_frames, animation_name) / maxf(duration, 0.05)
	play(animation_name)
