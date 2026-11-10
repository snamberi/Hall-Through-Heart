class_name SheetAnimations
extends RefCounted
## Builds SpriteFrames from a sprite sheet with one animation per row.

const FRAMES_PER_ANIMATION := 12


## `rows` lists the animations top to bottom: [{"name", "seconds", "loop"}].
## "seconds" is how long the 12 frames take at normal speed.
static func build(sheet: Texture2D, frame_size: int, rows: Array[Dictionary]) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for row in rows.size():
		var animation: String = rows[row]["name"]
		frames.add_animation(animation)
		frames.set_animation_speed(animation, FRAMES_PER_ANIMATION / float(rows[row]["seconds"]))
		frames.set_animation_loop(animation, rows[row]["loop"])
		for column in FRAMES_PER_ANIMATION:
			var frame := AtlasTexture.new()
			frame.atlas = sheet
			frame.region = Rect2(column * frame_size, row * frame_size, frame_size, frame_size)
			frames.add_frame(animation, frame)
	return frames


## Default length of an animation in seconds.
static func seconds(frames: SpriteFrames, animation: String) -> float:
	return FRAMES_PER_ANIMATION / frames.get_animation_speed(animation)
