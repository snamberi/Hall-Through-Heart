extends Node2D
## Turns enemy deaths into pickups on the ground.

var _player: Player


func setup(player: Player) -> void:
	_player = player
	Events.enemy_killed.connect(_on_enemy_killed)


func drop_item(item: Item, at: Vector2) -> void:
	_spawn(Pickup.create(_player, item), at)


func drop_gold(amount: int, at: Vector2) -> void:
	_spawn(Pickup.create(_player, null, amount), at)


func _on_enemy_killed(info: Dictionary) -> void:
	var drops := LootGenerator.roll_enemy_drops(info, _player.stats.get_stat("magic_find"))
	if drops["gold"] > 0:
		drop_gold(drops["gold"], info["position"])
	for item: Item in drops["items"]:
		drop_item(item, info["position"])


func _spawn(pickup: Pickup, at: Vector2) -> void:
	pickup.position = at
	add_child(pickup)
	pickup.scatter()
