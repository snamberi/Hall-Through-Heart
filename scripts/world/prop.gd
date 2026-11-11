class_name Prop
extends Node2D
## A thing standing in the world: a pillar, a chest, an altar, a cave mouth.
## Some are only scenery; others do something when the player presses F.

const SHEET: Texture2D = preload("res://assets/sprites/props.png")
const FRAMES := 14
const REACH := 70.0
const DECOR: Texture2D = preload("res://assets/sprites/decor.png")
const DECOR_FRAMES := 27
enum Decor { FLOOR, RUBBLE, STATUE, BRAZIER, BANNER, BONES, CRATE, BARREL, WELL, FENCE, LANTERN, STALL, SIGNPOST,
	RUG, SHELF, PLANT_POT, TABLE, CHAIR, CANDLES, CAGE, TENT, OBELISK, PALISADE, SPIKE_TRAP, BALLISTA, SOIL, SCARECROW }
static var LIGHT: Texture2D = _make_light()
## Frame numbers in the sheet.
enum Art { PILLAR, WALL, CHEST, CHEST_OPEN, ALTAR, CAVE, PORTAL, LADDER, TABLE, BED, DOOR, CAMPFIRE, TOTEM, HOUSE }

## What the prompt says, e.g. "Open the chest". Empty for scenery.
var prompt_text := ""
## Called with the player when they interact.
var on_interact: Callable
## How close the player must be to use it; big things reach further.
var reach := REACH
## Free text for whoever placed this (a structure key, a kind name).
var tag := ""

var _sprite: Sprite2D


## `solid` is the radius of the collision circle, or 0 to walk through.
static func create(art: Art, at: Vector2, solid: float = 0.0, prompt: String = "", action: Callable = Callable()) -> Prop:
	var prop := Prop.new()
	prop.position = at
	prop.prompt_text = prompt
	prop.on_interact = action
	prop._sprite = Sprite2D.new()
	prop._sprite.texture = SHEET
	prop._sprite.hframes = FRAMES
	prop._sprite.frame = art
	prop._sprite.position.y = -22.0
	prop._sprite.add_to_group("occluders")
	prop.add_child(prop._sprite)
	if solid > 0.0:
		var body := StaticBody2D.new()
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = solid
		shape.shape = circle
		body.add_child(shape)
		prop.add_child(body)
	if prompt != "":
		prop.add_to_group("props")
	return prop


## Things lying flat on the floor cast no shadow.
const FLAT_ART: Array[int] = [Art.CAVE, Art.LADDER, Art.DOOR, Art.PORTAL]
const FLAT_DECOR: Array[int] = [Decor.FLOOR, Decor.RUBBLE, Decor.BONES, Decor.RUG, Decor.SOIL, Decor.SPIKE_TRAP]


func _ready() -> void:
	if z_index < 0 or _sprite == null:
		return
	var flat: Array[int] = FLAT_DECOR if _sprite.texture == DECOR else FLAT_ART
	if not _sprite.frame in flat:
		SunShadow.cast(_sprite)


## A prop drawn from the decor sheet (tools/generate_flora.py) instead.
static var _decor_icons: Dictionary = {}


## One decor frame as an inventory icon.
static func decor_icon(index: int) -> Texture2D:
	if not _decor_icons.has(index):
		var atlas := AtlasTexture.new()
		atlas.atlas = DECOR
		atlas.region = Rect2(index * 64 + 4, 4, 56, 56)
		_decor_icons[index] = atlas
	return _decor_icons[index]


static func create_decor(index: int, at: Vector2, solid: float = 0.0, prompt: String = "", action: Callable = Callable()) -> Prop:
	var prop := create(Art.PILLAR, at, solid, prompt, action)
	prop._sprite.texture = DECOR
	prop._sprite.hframes = DECOR_FRAMES
	prop._sprite.frame = index
	return prop


## Adds a warm glow around the prop, for torches, braziers, and lanterns.
func add_light(strength: float = 0.9, reach: float = 1.6) -> void:
	var light := FlickerLight.new()
	light.texture = LIGHT
	light.texture_scale = reach
	light.energy = strength
	light.base_energy = strength
	light.base_scale = reach
	light.color = Color(1.0, 0.82, 0.55)
	light.position.y = -30.0
	add_child(light)


func set_art(art: Art) -> void:
	_sprite.frame = art


func sprite() -> Sprite2D:
	return _sprite


## Stops this prop being something to interact with.
func disarm() -> void:
	prompt_text = ""
	remove_from_group("props")


func interact(player: Player) -> void:
	if on_interact.is_valid():
		on_interact.call(player)


static func _make_light() -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 128
	return texture
