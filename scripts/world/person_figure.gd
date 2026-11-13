class_name PersonFigure
extends Node2D
## A person in the world drawn like the player: the body sheet in their
## colours and size, every feature layer (hair, beard, ears...) on top, and
## something in hand for their work. Villagers are made of these.

var _body: AnimatedSprite2D
var _layers: Dictionary = {}
var _held: Sprite2D
var _facing := 1.0

static var _frames: Dictionary = {}
static var _shader: Shader


static func _sheet(path: String) -> SpriteFrames:
	if not _frames.has(path):
		_frames[path] = SheetAnimations.build(load("res://assets/sprites/%s.png" % path), PlayerAnimator.FRAME_SIZE, PlayerAnimator.ROWS)
	return _frames[path]


func _init() -> void:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = PlayerAnimator.LAYER_SHADER
	_body = AnimatedSprite2D.new()
	_body.sprite_frames = _sheet("player_sheet")
	add_child(_body)
	for entry: Array in Appearance.LAYER_ORDER:
		var sprite := AnimatedSprite2D.new()
		var layer_material := ShaderMaterial.new()
		layer_material.shader = _shader
		sprite.material = layer_material
		sprite.show_behind_parent = entry[1]
		sprite.visible = false
		_body.add_child(sprite)
		_layers[entry[0]] = sprite
	_held = Sprite2D.new()
	_held.scale = Vector2(0.55, 0.55)
	_held.visible = false
	add_child(_held)
	_body.animation_changed.connect(_sync)
	_body.frame_changed.connect(_sync)


## Dresses the figure from an appearance (see Appearance).
func dress(appearance: Dictionary, size: float = 1.0) -> void:
	_body.material = Appearance.make_material(appearance)
	_body.scale = Appearance.body_scale(appearance) * size
	_body.self_modulate.a = Appearance.alpha(appearance)
	_body.position = Vector2(0, -23.0 * _body.scale.y)
	var features := Appearance.layers(appearance)
	for slot: String in _layers:
		var sprite: AnimatedSprite2D = _layers[slot]
		sprite.visible = features.has(slot)
		if sprite.visible:
			sprite.sprite_frames = _sheet("looks/" + features[slot]["sheet"])
			(sprite.material as ShaderMaterial).set_shader_parameter("tint", features[slot]["tint"])
	_body.play("idle")
	_sync()


## Something carried for their work: an item's picture held at the hip.
func hold(texture: Texture2D, tint: Color = Color.WHITE) -> void:
	_held.texture = texture
	_held.modulate = tint
	_held.visible = texture != null
	_place_held()


## "idle", "walk" or "run"; looping.
func pose(animation_name: String, speed: float = 1.0) -> void:
	_body.speed_scale = speed
	if _body.animation != animation_name:
		_body.play(animation_name)


func face(direction_x: float) -> void:
	if absf(direction_x) < 0.01:
		return
	_facing = signf(direction_x)
	_body.flip_h = _facing < 0.0
	for sprite: AnimatedSprite2D in _layers.values():
		sprite.flip_h = _body.flip_h
	_place_held()


## The top of the head, for name tags and speech.
func head_height() -> float:
	return 44.0 * _body.scale.y


func _place_held() -> void:
	_held.position = Vector2(7.0 * _facing * _body.scale.x, -14.0 * _body.scale.y)
	_held.flip_h = _facing < 0.0


func _sync() -> void:
	for sprite: AnimatedSprite2D in _layers.values():
		if sprite.visible:
			sprite.animation = _body.animation
			sprite.frame = _body.frame
