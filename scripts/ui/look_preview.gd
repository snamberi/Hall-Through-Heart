class_name LookPreview
extends Control
## A large, living figure dressed from an appearance dictionary: the body in
## its colours and size, and every feature layer (hair, beard, ears, horns,
## tail, wings, marks, eyes). Needs no player, so the character creator can
## show a character that does not exist yet.

const SCALE := 4.0

## How large the figure is drawn, and whether it stands on a niche and plinth.
var zoom := SCALE
var framed := true
## The animation it plays ("idle", "walk", "attack", "hurt"...).
var pose := "idle"
var _facing := 1.0

var _holder: Node2D
var _body: AnimatedSprite2D
var _layers: Dictionary = {}
var _shader: Shader
var _appearance: Dictionary = Appearance.DEFAULT.duplicate()
var _walking := false

static var _frames: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_holder = Node2D.new()
	add_child(_holder)
	_shader = Shader.new()
	_shader.code = PlayerAnimator.LAYER_SHADER
	_body = AnimatedSprite2D.new()
	_body.sprite_frames = _sheet("player_sheet")
	_holder.add_child(_body)
	for entry: Array in Appearance.LAYER_ORDER:
		var sprite := AnimatedSprite2D.new()
		var layer_material := ShaderMaterial.new()
		layer_material.shader = _shader
		sprite.material = layer_material
		sprite.show_behind_parent = entry[1]
		sprite.visible = false
		_body.add_child(sprite)
		_layers[entry[0]] = sprite
	_body.play(pose)
	resized.connect(_place)
	show_look(_appearance)


static func _sheet(path: String) -> SpriteFrames:
	if not _frames.has(path):
		_frames[path] = SheetAnimations.build(load("res://assets/sprites/%s.png" % path), PlayerAnimator.FRAME_SIZE, PlayerAnimator.ROWS)
	return _frames[path]


## Dresses the figure.
func show_look(appearance: Dictionary) -> void:
	_appearance = appearance.duplicate()
	if _body == null:
		return
	_body.material = Appearance.make_material(_appearance)
	_body.scale = Appearance.body_scale(_appearance)
	_body.self_modulate.a = Appearance.alpha(_appearance)
	var features := Appearance.layers(_appearance)
	for slot: String in _layers:
		var sprite: AnimatedSprite2D = _layers[slot]
		sprite.visible = features.has(slot)
		if sprite.visible:
			sprite.sprite_frames = _sheet("looks/" + features[slot]["sheet"])
			(sprite.material as ShaderMaterial).set_shader_parameter("tint", features[slot]["tint"])
	_place()


## Walks on the spot (true) or stands (false).
func set_walking(walking: bool) -> void:
	_walking = walking
	play(("walk" if walking else "idle"))


## Plays one of the body's animations, looping it.
func play(animation_name: String) -> void:
	pose = animation_name
	if _body and _body.sprite_frames.has_animation(animation_name):
		_body.sprite_frames.set_animation_loop(animation_name, true)
		_body.play(animation_name)


## Turns the figure to face the other way.
func turn() -> void:
	_facing = -_facing
	_place()


func _place() -> void:
	if _holder == null:
		return
	_holder.scale = Vector2(zoom * _facing, zoom)
	# Feet on the plinth: frames are 96px with the feet 23px below the middle.
	_holder.position = Vector2(size.x / 2.0, size.y - (64.0 if framed else 14.0))
	_body.position = Vector2(0, -23.0 * _body.scale.y)


func _process(_delta: float) -> void:
	if _body == null:
		return
	for sprite: AnimatedSprite2D in _layers.values():
		if sprite.visible:
			sprite.animation = _body.animation
			sprite.frame = _body.frame
	queue_redraw()


func _draw() -> void:
	if not framed:
		draw_set_transform(Vector2(size.x / 2.0, size.y - 12.0), 0.0, Vector2(1.0, 0.32))
		draw_circle(Vector2.ZERO, size.x * 0.36, Color("2a2c36"))
		draw_set_transform(Vector2.ZERO)
		return
	# A stone niche and a plinth for the figure to stand on.
	var center := size / 2.0
	draw_rect(Rect2(center.x - 96.0, 30.0, 192.0, size.y - 90.0), Color("0b0e17"))
	draw_circle(Vector2(center.x, 126.0), 96.0, Color("0b0e17"))
	draw_arc(Vector2(center.x, 126.0), 96.0, PI, TAU, 40, Color("403020"), 3.0)
	draw_set_transform(Vector2(center.x, size.y - 58.0), 0.0, Vector2(1.0, 0.32))
	draw_circle(Vector2.ZERO, 110.0, Color("2a2c36"))
	draw_circle(Vector2.ZERO, 92.0, Color("3a3c48"))
	draw_set_transform(Vector2.ZERO)
