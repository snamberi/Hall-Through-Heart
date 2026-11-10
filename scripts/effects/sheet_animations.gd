class_name SheetAnimations
extends RefCounted
## Builds SpriteFrames from a sprite sheet with one animation per row.


## `rows` lists the animations top to bottom:
## [{"name", "frames", "fps", "loop"}]. Frames run left to right.
static func build(sheet: Texture2D, frame_size: int, rows: Array[Dictionary]) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for row in rows.size():
		var animation: String = rows[row]["name"]
		frames.add_animation(animation)
		frames.set_animation_speed(animation, rows[row]["fps"])
		frames.set_animation_loop(animation, rows[row]["loop"])
		for column: int in rows[row]["frames"]:
			var frame := AtlasTexture.new()
			frame.atlas = sheet
			frame.region = Rect2(column * frame_size, row * frame_size, frame_size, frame_size)
			frames.add_frame(animation, frame)
	return frames


## Length of an animation in seconds at normal speed.
static func seconds(frames: SpriteFrames, animation: String) -> float:
	return frames.get_frame_count(animation) / frames.get_animation_speed(animation)
