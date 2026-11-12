class_name CharacterPreview
extends Control
## A large, breathing copy of the player with their visible equipment, for
## the inventory screen. It mirrors the player's own sprite layers.

const SCALE := 3.6
const IDLE_FPS := 6.0

var _player: Player
var _sprites: Array[Sprite2D] = []


func setup(player: Player) -> void:
	_player = player
	process_mode = Node.PROCESS_MODE_ALWAYS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _draw() -> void:
	# A stone niche and a plinth for the figure to stand on.
	var center := size / 2.0
	draw_rect(Rect2(center.x - 78.0, 26.0, 156.0, size.y - 84.0), Color("0b0e17"))
	draw_circle(Vector2(center.x, 104.0), 78.0, Color("0b0e17"))
	draw_arc(Vector2(center.x, 104.0), 78.0, PI, TAU, 32, Color("403020"), 3.0)
	draw_set_transform(Vector2(center.x, size.y - 64.0), 0.0, Vector2(1.0, 0.32))
	draw_circle(Vector2.ZERO, 92.0, Color("2a2c36"))
	draw_circle(Vector2.ZERO, 76.0, Color("3a3c48"))
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
	var feet := Vector2(size.x / 2.0, size.y - 70.0)
	for index in _sprites.size():
		var sprite := _sprites[index]
		sprite.visible = index < sources.size()
		if sprite.visible:
			sprite.texture = sources[index].sprite_frames.get_frame_texture("idle", frame)
			sprite.material = sources[index].material
			# The figure keeps its own height and build.
			sprite.scale = body.scale * SCALE
			sprite.self_modulate.a = body.self_modulate.a if sources[index] == body else 1.0
			# Frames are 96px with the feet 23px below the middle.
			sprite.position = feet - Vector2(0, 23.0 * SCALE * body.scale.y)
