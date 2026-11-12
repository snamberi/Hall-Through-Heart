class_name FlameFX
extends Node2D
## A fire burning on something: a looping pixel-art flame (drawn by
## tools/generate_fire.py at the game's own pixel size), with a few square
## sparks lifting off it and, for bigger fires, a thread of smoke.
## Also in the "fires" group, so the world knows where fires burn.

## Overall size; 1 is a brazier's flame. Picks which flame sheet to play.
var size := 1.0
var smoke := true
## Which sheet; set from `size` unless given.
var kind := ""

const SHEETS := {
	"candle": [preload("res://assets/effects/fire_candle.png"), 6],
	"torch": [preload("res://assets/effects/fire_torch.png"), 8],
	"brazier": [preload("res://assets/effects/fire_brazier.png"), 8],
	"campfire": [preload("res://assets/effects/fire_campfire.png"), 8],
	"hearth": [preload("res://assets/effects/fire_hearth.png"), 8],
}
static var _frames: Dictionary = {}

var _sprite: AnimatedSprite2D
## [position, age, life, drift]
var _sparks: Array = []
## [position, age, life, size]
var _smoke: Array = []


func _ready() -> void:
	add_to_group("fires")
	if kind == "":
		kind = "candle" if size <= 0.4 else "torch" if size <= 0.65 else "brazier" if size <= 1.05 else "campfire"
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = _frames_for(kind)
	_sprite.centered = false
	var frame_size: Vector2 = _sprite.sprite_frames.get_frame_texture("burn", 0).get_size()
	# The flame stands on this point: its base centred, on whole pixels.
	_sprite.position = Vector2(-floorf(frame_size.x / 2.0), -frame_size.y + 1.0)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	_sprite.play("burn")
	_sprite.frame = randi() % _sprite.sprite_frames.get_frame_count("burn")
	_sprite.speed_scale = randf_range(0.85, 1.15)


static func _frames_for(sheet_kind: String) -> SpriteFrames:
	if not _frames.has(sheet_kind):
		var entry: Array = SHEETS[sheet_kind]
		var sheet: Texture2D = entry[0]
		var count: int = entry[1]
		var frames := SpriteFrames.new()
		frames.remove_animation("default")
		frames.add_animation("burn")
		frames.set_animation_speed("burn", 10.0)
		frames.set_animation_loop("burn", true)
		var width := sheet.get_width() / count
		for index in count:
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(index * width, 0, width, sheet.get_height())
			frames.add_frame("burn", atlas)
		_frames[sheet_kind] = frames
	return _frames[sheet_kind]


func _process(delta: float) -> void:
	var height := float(SHEETS[kind][0].get_height())
	if randf() < delta * (2.0 + size * 4.0) and _sparks.size() < 6:
		_sparks.append([Vector2(randi_range(-3, 3) * size, -height * 0.6), 0.0, randf_range(0.5, 1.1), randf_range(-10.0, 10.0)])
	if smoke and size >= 0.9 and randf() < delta * 1.6 and _smoke.size() < 5:
		_smoke.append([Vector2(randi_range(-2, 2), -height), 0.0, randf_range(1.4, 2.2), randf_range(2.0, 3.0)])
	for spark: Array in _sparks:
		spark[1] += delta
		spark[0] += Vector2(spark[3] * delta, -32.0 * delta)
	_sparks = _sparks.filter(func(s: Array) -> bool: return s[1] < s[2])
	for puff: Array in _smoke:
		puff[1] += delta
		puff[0] += Vector2(sin(puff[1] * 2.0) * 6.0 * delta, -14.0 * delta)
	_smoke = _smoke.filter(func(s: Array) -> bool: return s[1] < s[2])
	queue_redraw()


func _draw() -> void:
	# Smoke as soft square puffs, sparks as single pixels: kept on the grid.
	for puff: Array in _smoke:
		var share: float = puff[1] / puff[2]
		var side: float = roundf(puff[3] * (1.0 + share))
		draw_rect(Rect2(puff[0].round() - Vector2(side, side) / 2.0, Vector2(side, side)), Color(0.24, 0.23, 0.25, 0.3 * (1.0 - share)))
	for spark: Array in _sparks:
		var share: float = spark[1] / spark[2]
		draw_rect(Rect2(spark[0].round(), Vector2(1, 1)), Color(1.0, 0.82 - share * 0.4, 0.3, 1.0 - share))
