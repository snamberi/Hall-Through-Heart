class_name Prop
extends Node2D
## A thing standing in the world: a pillar, a chest, an altar, a cave mouth.
## Some are only scenery; others do something when the player presses F.

const SHEET: Texture2D = preload("res://assets/sprites/props.png")
const FRAMES := 14
const REACH := 70.0
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
