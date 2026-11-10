class_name Pickup
extends Node2D
## An item or pile of gold on the ground. Flies to the player when close.

const MAGNET_RADIUS := 110.0
const COLLECT_RADIUS := 22.0
const MAGNET_SPEED := 460.0
const LIFETIME := 180.0

var item: Item
var gold := 0

var _player: Player
var _age := 0.0
var _blocked_left := 0.0
var _sprite: Sprite2D


static func create(player: Player, p_item: Item, p_gold: int = 0) -> Pickup:
	var pickup := Pickup.new()
	pickup._player = player
	pickup.item = p_item
	pickup.gold = p_gold
	return pickup


func _ready() -> void:
	add_to_group("pickups")
	_sprite = Sprite2D.new()
	_sprite.texture = item.icon() if item else ItemDB.icon(ItemDB.GOLD_ICON)
	add_child(_sprite)


## Tosses the pickup a short way from where it appeared.
func scatter() -> void:
	var landing := position + Vector2.from_angle(randf() * TAU) * randf_range(14.0, 44.0)
	create_tween().tween_property(self, "position", landing, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func _physics_process(delta: float) -> void:
	_age += delta
	_blocked_left = maxf(_blocked_left - delta, 0.0)
	_sprite.position.y = -8.0 + sin(_age * 4.0) * 2.0
	if _age > LIFETIME:
		queue_free()
		return
	if _age < 0.35 or _blocked_left > 0.0 or _player.is_dead():
		return
	var offset := _player.global_position - global_position
	if offset.length() < COLLECT_RADIUS:
		_collect()
	elif offset.length() < MAGNET_RADIUS:
		global_position += offset.normalized() * MAGNET_SPEED * delta


func _draw() -> void:
	var glow := item.color() if item else Color(0.95, 0.8, 0.3)
	draw_circle(Vector2(0, 4), 9.0, Color(glow, 0.3))
	draw_arc(Vector2(0, 4), 9.0, 0.0, TAU, 20, Color(glow, 0.8), 1.0)


func _collect() -> void:
	var text_position := _player.global_position + Vector2(0, -20)
	Audio.play("pickup", -8.0)
	if item == null:
		_player.inventory.add_gold(gold)
		DamageNumber.spawn_text(get_parent(), text_position, "+%d gold" % gold, Color(0.95, 0.8, 0.3), 12)
		queue_free()
		return
	var label := item.display_name() if item.count == 1 else "%s x%d" % [item.display_name(), item.count]
	if _player.inventory.add(item):
		DamageNumber.spawn_text(get_parent(), text_position, label, item.color(), 12)
		Events.item_acquired.emit(item.to_dict())
		queue_free()
	else:
		DamageNumber.spawn_text(get_parent(), text_position, "Inventory full", Color(0.9, 0.4, 0.4), 12)
		_blocked_left = 2.5
