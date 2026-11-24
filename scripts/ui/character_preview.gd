class_name CharacterPreview
extends Control
## A large, breathing copy of the player with their visible equipment, for
## the inventory screen. It mirrors the player's own sprite layers.

## Whole-number zoom, so the art keeps square pixels.
const SCALE := 4.0
const IDLE_FPS := 6.0

var _player: Player
var _sprites: Array[Sprite2D] = []
## 1 faces right, -1 left; turn() flips it.
var facing := 1.0


func turn() -> void:
	facing = -facing


func setup(player: Player) -> void:
	_player = player
	process_mode = Node.PROCESS_MODE_ALWAYS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## Where the figure's feet stand: placed so the figure, about 160 pixels
## tall, sits in the middle of the area with even room above and below.
func _feet() -> Vector2:
	return Vector2(size.x / 2.0, roundf(size.y / 2.0 + 84.0))


func _draw() -> void:
	# A stone niche and a plinth for the figure to stand on.
	var feet := _feet()
	var top := feet.y - 118.0
	draw_rect(Rect2(feet.x - 78.0, top, 156.0, feet.y - top), Color(UITheme.WELL))
	draw_circle(Vector2(feet.x, top), 78.0, Color(UITheme.WELL))
	draw_arc(Vector2(feet.x, top), 78.0, PI, TAU, 32, Color(UITheme.EDGE), 3.0)
	draw_set_transform(feet + Vector2(0, 6), 0.0, Vector2(1.0, 0.32))
	draw_circle(Vector2.ZERO, 92.0, Color(UITheme.SHADE))
	draw_circle(Vector2.ZERO, 76.0, Color(UITheme.SHADE))
	draw_set_transform(Vector2.ZERO)


func _process(_delta: float) -> void:
	if not is_visible_in_tree() or _player == null:
		return
	var body: AnimatedSprite2D = _player.get_node("Visual/Sprite")
	var sources: Array[AnimatedSprite2D] = []
	var behind: Array[bool] = []
	# Same order the game draws them: layers behind the body, body, the rest.
	for child in body.get_children():
		if child is AnimatedSprite2D and child.visible and child.show_behind_parent:
			sources.append(child)
	sources.append(body)
	for child in body.get_children():
		if child is AnimatedSprite2D and child.visible and not child.show_behind_parent:
			sources.append(child)

	while _sprites.size() < sources.size():
		var sprite := Sprite2D.new()
		sprite.scale = Vector2(SCALE, SCALE)
		add_child(sprite)
		_sprites.append(sprite)
	var frame := int(Time.get_ticks_msec() / 1000.0 * IDLE_FPS) % 4
	var feet := _feet()
	for index in _sprites.size():
		var sprite := _sprites[index]
		sprite.visible = index < sources.size()
		if sprite.visible:
			sprite.texture = sources[index].sprite_frames.get_frame_texture("idle", frame)
			sprite.material = sources[index].material
			sprite.scale = Vector2(SCALE * facing, SCALE)
			sprite.self_modulate.a = body.self_modulate.a if sources[index] == body else 1.0
			# Frames are 96px with the feet 23px below the middle; a layer
			# keeps its own whole-pixel fit to the body (see BodyFit).
			var fit: Vector2 = Vector2.ZERO if sources[index] == body else BodyFit.offset(sources[index].get_meta("fit_shift", Vector2i.ZERO), &"idle", frame)
			sprite.position = feet - Vector2(0, 23.0 * SCALE) + Vector2(fit.x * facing, fit.y) * SCALE
