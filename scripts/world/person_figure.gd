class_name PersonFigure
extends Node2D
## A person in the world drawn like the player: the body sheet in their
## colours and size, every feature layer (hair, beard, ears...) on top, and
## something in hand for their work. Villagers are made of these.

## The tools of a trade, drawn at the size they are held (tools/generate_held.py).
const HELD_SHEET: Texture2D = preload("res://assets/sprites/held_tools.png")
const HELD_TOOLS: Array[String] = ["worn_hatchet", "worn_pickaxe", "fishing_rod", "spear", "bow", "wheat", "healing_herb", "bread"]
const HELD_CELL := Vector2(20, 32)
## The pixel of a tool's cell the hand closes on.
const HELD_GRIP := Vector2(10, 22)
## Where the right hand is at the middle height, standing (in the figure's
## own pixels), and how it moves frame by frame (generate_people.py).
const HAND := Vector2(7, -10)
const HAND_STEPS := {
	"idle": [Vector2(0, 0), Vector2(0, 0), Vector2(0, 1), Vector2(0, 1)],
	"walk": [Vector2(0, 0), Vector2(1, -1), Vector2(1, -1), Vector2(0, 0), Vector2(0, 0), Vector2(-1, -1), Vector2(-1, -1), Vector2(0, 0)],
	"run": [Vector2(1, 0), Vector2(4, -2), Vector2(4, -3), Vector2(4, -2), Vector2(1, 0), Vector2(1, 0), Vector2(1, -1), Vector2(1, 0)],
}

var _body: AnimatedSprite2D
var _layers: Dictionary = {}
var _held: Sprite2D
var _facing := 1.0
## A tool from the held sheet (kept on the hand) rather than an item icon.
var _tool := false
var _height := 2
## Which way it is seen while it moves (PlayerAnimator.view_of), and its
## stance at rest ("idle", or a class's own).
var _view := "front"
var stance := "idle"
## Worn gear over the body (armour, a cape, a shield, a weapon), as the
## player wears it: layer -> sprite.
var _gear: Dictionary = {}
var _fitted: Dictionary = {}
## The look layers a helmet hides.
const UNDER_HELMET: Array[String] = ["hair", "horns", "hat"]

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
	_held.scale = Vector2(0.5, 0.5)
	_held.visible = false
	add_child(_held)
	_body.animation_changed.connect(_sync)
	_body.frame_changed.connect(_sync)


## Dresses the figure from an appearance (see Appearance).
func dress(appearance: Dictionary, size: float = 1.0) -> void:
	_body.material = Appearance.make_material(appearance)
	# Children and grown-ups differ by drawn height, not by stretching: a
	# smaller `size` picks a shorter body.
	var fitted := appearance.duplicate()
	if size < 0.95:
		fitted["height"] = 0
	_height = int(fitted.get("height", 2))
	_fitted = fitted
	_body.sprite_frames = BodyFit.body(fitted)
	_body.scale = Vector2.ONE
	_body.self_modulate.a = Appearance.alpha(appearance)
	_body.position = Vector2(0, -23.0)
	var features := Appearance.layers(fitted)
	for slot: String in _layers:
		var sprite: AnimatedSprite2D = _layers[slot]
		sprite.visible = features.has(slot)
		if sprite.visible:
			BodyFit.wear(sprite, "looks/" + features[slot]["sheet"], "look_" + slot, fitted)
			Appearance.apply_tint(sprite.material as ShaderMaterial, features[slot])
	_body.play("idle")
	_sync()


## Dresses the figure in gear: [{"l": layer, "s": sheet, "t": tint}] as
## PlayerAnimator.worn() gives it (or a villager's own). Anything not
## listed comes off.
func wear(gear: Array) -> void:
	var wanted := {}
	for entry: Variant in gear:
		if entry is Dictionary and str(entry.get("s", "")) != "":
			wanted[str(entry.get("l", ""))] = entry
	for layer in PlayerAnimator.LAYERS:
		var name: String = layer["name"]
		if name.begins_with("look_"):
			continue
		if not wanted.has(name):
			if _gear.has(name):
				(_gear[name] as Node).visible = false
			continue
		if not _gear.has(name):
			var sprite := AnimatedSprite2D.new()
			var layer_material := ShaderMaterial.new()
			layer_material.shader = _shader
			sprite.material = layer_material
			sprite.show_behind_parent = layer["behind"]
			_body.add_child(sprite)
			_gear[name] = sprite
		var worn: AnimatedSprite2D = _gear[name]
		BodyFit.wear(worn, str(wanted[name]["s"]), name, _fitted if not _fitted.is_empty() else Appearance.DEFAULT)
		var tint: Variant = wanted[name].get("t", Color.WHITE)
		(worn.material as ShaderMaterial).set_shader_parameter("tint", tint if tint is Color else Color.WHITE)
		(worn.material as ShaderMaterial).set_shader_parameter("outline_mix", 0.0)
		(worn.material as ShaderMaterial).set_shader_parameter("upgrade", float(wanted[name].get("u", 0)))
		worn.flip_h = _body.flip_h
		worn.visible = true
		BodyFit.follow(worn, _body)
	# A helmet hides the hair and hat under it.
	var helmeted := wanted.has("helmet") or wanted.has("hood")
	for slot: String in UNDER_HELMET:
		if _layers.has(slot) and helmeted:
			(_layers[slot] as Node2D).visible = false
	# A weapon in hand replaces a carried tool.
	if wanted.has("weapon") and _held:
		_held.visible = false


## Something carried for their work: an item's picture held at the hip.
func hold(texture: Texture2D, tint: Color = Color.WHITE) -> void:
	_tool = false
	_held.centered = true
	# Held at the world's pixel size: a 16-pixel picture as it is.
	_held.scale = Vector2.ONE if texture == null or texture.get_width() <= 16 else Vector2(0.5, 0.5)
	_held.texture = texture
	_held.modulate = tint
	_held.visible = texture != null
	_place_held()


## The tool of a trade in the hand, at its own size, if one is drawn for
## this item. Returns whether it was.
func hold_tool(item_id: String) -> bool:
	var index := HELD_TOOLS.find(item_id)
	if index < 0:
		return false
	var cell := AtlasTexture.new()
	cell.atlas = HELD_SHEET
	cell.region = Rect2(Vector2(index * HELD_CELL.x, 0), HELD_CELL)
	_tool = true
	_held.texture = cell
	_held.modulate = Color.WHITE
	_held.scale = Vector2.ONE
	_held.centered = false
	_held.visible = true
	_place_held()
	return true


## "idle", "walk" or "run" (seen from the way it is heading, see
## set_heading), or any other row; looping.
func pose(animation_name: String, speed: float = 1.0) -> void:
	_body.speed_scale = speed
	if (animation_name in ["walk", "run", "idle"] or animation_name in PlayerAnimator.BLOWS) and _view != "front":
		animation_name += "_" + _view
	elif animation_name == "idle" and stance != "idle" and _body.sprite_frames.has_animation(stance):
		animation_name = stance
	if not _body.sprite_frames.has_animation(animation_name):
		animation_name = animation_name.get_slice("_", 0)
	if _body.animation != animation_name:
		_body.play(animation_name)
		var from_behind := animation_name.ends_with("_back") or animation_name.ends_with("_bq")
		for entry in Appearance.LAYER_ORDER:
			if entry[1] and _layers.has(entry[0]):
				(_layers[entry[0]] as CanvasItem).show_behind_parent = not from_behind
		for layer in PlayerAnimator.LAYERS:
			if layer["behind"] and _gear.has(layer["name"]):
				(_gear[layer["name"]] as CanvasItem).show_behind_parent = not from_behind


## Which way it is going: seen from behind going up, in profile going
## sideways (and facing that way), from the front otherwise.
func set_heading(heading: Vector2) -> void:
	_view = PlayerAnimator.view_of(heading)
	if absf(heading.x) > 0.5:
		face(heading.x)


func face(direction_x: float) -> void:
	if absf(direction_x) < 0.01:
		return
	_facing = signf(direction_x)
	_body.flip_h = _facing < 0.0
	for sprite: AnimatedSprite2D in _layers.values():
		sprite.flip_h = _body.flip_h
	for sprite: AnimatedSprite2D in _gear.values():
		sprite.flip_h = _body.flip_h
	_place_held()


## The top of the head, for name tags and speech.
func head_height() -> float:
	return 44.0 * _body.scale.y


func _place_held() -> void:
	_held.flip_h = _facing < 0.0
	if not _tool:
		_held.position = Vector2(roundf(7.0 * _facing), -14.0)
		return
	# Kept on the hand as it swings, in whole pixels; mirrored when facing left.
	var steps: Array = HAND_STEPS.get(_body.animation, HAND_STEPS["idle"])
	var hand: Vector2 = HAND + steps[mini(_body.frame, steps.size() - 1)] + Vector2(0, -(_height - 2))
	if _facing < 0.0:
		hand.x = -hand.x - 1.0
		_held.offset = -Vector2(HELD_CELL.x - 1.0 - HELD_GRIP.x, HELD_GRIP.y)
	else:
		_held.offset = -HELD_GRIP
	_held.position = hand


func _sync() -> void:
	for sprite: AnimatedSprite2D in _layers.values():
		if sprite.visible:
			BodyFit.follow(sprite, _body)
	for sprite: AnimatedSprite2D in _gear.values():
		if sprite.visible:
			BodyFit.follow(sprite, _body)
	if _tool and _held:
		_place_held()
