class_name Npc
extends Node2D
## Someone to talk to: a merchant who trades, or a warden who hands out work.

const REACH := 66.0
const KINDS := {
	"merchant": {"name": "Merchant", "prompt": "Trade with the Merchant", "sheet": "res://assets/sprites/npc_merchant.png"},
	"warden": {"name": "Warden", "prompt": "Ask the Warden for work", "sheet": "res://assets/sprites/npc_warden.png"},
	"villager": {"name": "Villager", "prompt": "Talk", "sheet": "res://assets/sprites/npc_merchant.png"},
}
## A merchant's wares change this often, in seconds.
const RESTOCK_SECONDS := 600.0
## Share of an item's value a merchant pays for it.
const SELL_SHARE := 0.25
const STAPLES: Array[String] = ["health_potion", "mana_potion", "stamina_tonic", "grilled_minnow", "copper_ingot", "oak_wood"]

var kind := "merchant"
## What a merchant has for sale: [{"item": Item, "price": int, "endless": bool}].
var stock: Array[Dictionary] = []

var _stocked_at := -RESTOCK_SECONDS
## Villagers: what they might say, and where they wander from.
var lines: Array[String] = []
var home := Vector2.ZERO
var _sprite: AnimatedSprite2D
var _walk_to := Vector2.ZERO
var _think := 0.0


static func create(p_kind: String, at: Vector2) -> Npc:
	var npc := Npc.new()
	npc.kind = p_kind
	npc.position = at
	return npc


func _ready() -> void:
	add_to_group("npcs")
	var sprite := AnimatedSprite2D.new()
	_sprite = sprite
	sprite.sprite_frames = SheetAnimations.build(load(KINDS[kind]["sheet"]), 96, [{"name": "idle", "frames": 4, "fps": 5.0, "loop": true}])
	sprite.position = Vector2(0, -23)
	sprite.play("idle")
	add_child(sprite)
	if kind == "villager":
		# Each villager dresses a little differently.
		sprite.modulate = Color.from_hsv(randf(), 0.25, 1.0).lerp(Color.WHITE, 0.4)
		_walk_to = position

	var label := Label.new()
	label.text = KINDS[kind]["name"]
	label.add_theme_font_override("font", UITheme.bold())
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", UITheme.GOLD)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.scale = Vector2.ONE / 2.0
	label.position = Vector2(-label.get_minimum_size().x / 4.0, -66.0)
	add_child(label)

	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 9.0
	shape.shape = circle
	body.add_child(shape)
	add_child(body)


func prompt() -> String:
	return KINDS[kind]["prompt"]


## Fills the shelves if it is time, with gear suited to the player's level.
func restock_if_due(player: Player) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _stocked_at < RESTOCK_SECONDS and not stock.is_empty():
		return
	_stocked_at = now
	stock.clear()
	for item_id in STAPLES:
		var item := Item.create(item_id)
		stock.append({"item": item, "price": item.value(), "endless": true})
	for tool_id: String in ["bronze_pickaxe", "bronze_hatchet"]:
		var tool := Item.create(tool_id)
		stock.append({"item": tool, "price": tool.value(), "endless": false})
	for i in 5:
		var level := maxi(player.leveling.level + randi_range(-2, 1), 1)
		var gear := LootGenerator.make_equipment(level, LootGenerator.roll_rarity(0.0, 1.0))
		stock.append({"item": gear, "price": gear.value(), "endless": false})


## Seconds until the wares change.
func restock_in() -> float:
	return maxf(RESTOCK_SECONDS - (Time.get_ticks_msec() / 1000.0 - _stocked_at), 0.0)


## Gold a merchant pays for one of an item.
static func sell_price(item: Item) -> int:
	return maxi(roundi(item.value() * SELL_SHARE), 1)


func _process(delta: float) -> void:
	if kind != "villager":
		return
	_think -= delta
	if _think <= 0.0:
		_think = randf_range(2.0, 6.0)
		_walk_to = home + Vector2.from_angle(randf() * TAU) * randf_range(0.0, 160.0)
	var step := _walk_to - position
	if step.length() > 4.0:
		position += step.normalized() * 34.0 * delta
		_sprite.flip_h = step.x < 0.0


## A villager's passing remark.
func say_something() -> String:
	return lines.pick_random() if not lines.is_empty() else "..."
