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
		drop_gold(roundi(drops["gold"] * _player.stats.get_stat("gold_find")), info["position"])
	for item: Item in drops["items"]:
		drop_item(item, info["position"])
	# Relics: always from a boss, now and then from an Ancient or Champion.
	var rank := str(info.get("rank", "normal"))
	var relic_chance: float = {"boss": 1.0, "miniboss": 0.2, "champion": 0.03}.get(rank, 0.0)
	if relic_chance > 0.0 and randf() < relic_chance and not info.get("fragment", false):
		drop_item(RelicDB.make("", RelicDB.roll_rarity(rank, _player.stats.get_stat("magic_find"))), info["position"] + Vector2(0, 10))
	if str(info.get("named", "")) != "":
		for item: Item in MinibossDB.drops(info["level"]):
			drop_item(item, info["position"])
		Events.codex_event.emit("named", 1)


func _spawn(pickup: Pickup, at: Vector2) -> void:
	pickup.position = at
	add_child(pickup)
	pickup.scatter()
