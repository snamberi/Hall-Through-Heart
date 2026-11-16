class_name BodyFit
extends RefCounted
## Fits worn layers to a character's height and build in whole pixels.
##
## The body has its own sheet per height and build (see BodyFrames, written
## by tools/generate_people.py). Layers are drawn for the average figure:
## those on the head or body move up for taller legs, those held in a hand
## also move out for a broader build, armour fitted to the torso has a sheet
## per build and leg armour a sheet per height. Nothing is scaled, so every
## pixel stays one pixel.

## How each layer is worn, by layer name (look slots carry "look_").
const KINDS := {
	"look_tail": "torso", "look_wings": "torso", "look_cape": "fitted", "look_neck": "torso",
	"cape": "fitted", "chest": "fitted", "shoulders": "fitted",
	"legs": "legs", "boots": "feet",
	"shield": "hand_l", "weapon": "hand_r",
}

static var _frames: Dictionary = {}


static func height_of(appearance: Dictionary) -> int:
	return int(Appearance.resolved(appearance)["height"])


static func build_of(appearance: Dictionary) -> int:
	return int(Appearance.resolved(appearance)["build"])


## How a layer is worn: "head", "torso", "fitted", "legs", "feet",
## "hand_l" or "hand_r".
static func kind_of(layer: String) -> String:
	return KINDS.get(layer, "head")


## The body's frames for this height and build.
static func body(appearance: Dictionary) -> SpriteFrames:
	return frames("people/body_h%d_b%d" % [height_of(appearance), build_of(appearance)])


## The sheet a layer uses for this figure: a build or height variant when
## the piece has one.
static func sheet_for(path: String, layer: String, appearance: Dictionary) -> String:
	match kind_of(layer):
		"legs":
			var height := height_of(appearance)
			if height != BodyFrames.AVERAGE_HEIGHT and _exists("%s_h%d" % [path, height]):
				return "%s_h%d" % [path, height]
		"fitted":
			var build := build_of(appearance)
			if build != BodyFrames.AVERAGE_BUILD and _exists("%s_b%d" % [path, build]):
				return "%s_b%d" % [path, build]
	return path


## How far a layer moves for this figure, before any turn of the frame.
static func shift_for(layer: String, appearance: Dictionary) -> Vector2i:
	var lift := BodyFrames.lift(height_of(appearance))
	var out := BodyFrames.arm_out(build_of(appearance))
	match kind_of(layer):
		"legs", "feet":
			return Vector2i.ZERO
		"hand_r":
			return Vector2i(out, -lift)
		"hand_l":
			return Vector2i(-out, -lift)
	return Vector2i(0, -lift)


## A layer's offset in one frame: its shift, turned with a turned frame.
static func offset(shift: Vector2i, animation: StringName, frame: int) -> Vector2:
	if shift == Vector2i.ZERO:
		return Vector2.ZERO
	var turns: Array = BodyFrames.TURNS.get(String(animation), [])
	var turn: int = turns[frame] if frame < turns.size() else 0
	return Vector2(BodyFrames.turned(shift, turn))


## Frames from a sheet under assets/sprites, built once.
static func frames(path: String) -> SpriteFrames:
	if not _frames.has(path):
		_frames[path] = SheetAnimations.build(load("res://assets/sprites/%s.png" % path), PlayerAnimator.FRAME_SIZE, PlayerAnimator.ROWS)
	return _frames[path]


## Puts a layer sprite on: the right sheet and its whole-pixel shift.
static func wear(sprite: AnimatedSprite2D, path: String, layer: String, appearance: Dictionary) -> void:
	sprite.sprite_frames = frames(sheet_for(path, layer, appearance))
	sprite.set_meta("fit_shift", shift_for(layer, appearance))
	sprite.set_meta("fit_path", path)


## Keeps a layer on its body's animation and frame, shifted to fit.
static func follow(sprite: AnimatedSprite2D, body: AnimatedSprite2D) -> void:
	sprite.animation = body.animation
	sprite.frame = body.frame
	sprite.offset = offset(sprite.get_meta("fit_shift", Vector2i.ZERO), body.animation, body.frame)


static func _exists(path: String) -> bool:
	return ResourceLoader.exists("res://assets/sprites/%s.png" % path)
