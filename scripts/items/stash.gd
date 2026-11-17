class_name Stash
extends RefCounted
## The player's own storage chests standing near them: crafting draws on
## what is in them as if it were in the bag, and the bag can be quick-
## stacked into them (each thing goes to a chest that already holds some).

## How near a chest must be, in pixels.
const REACH := 420.0


## The records of the player's storage chests within reach.
static func chests_near(player: Player) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var buildings: Node = player.get_parent().get_node_or_null("Buildings") if player.get_parent() else null
	if buildings == null:
		return out
	var place: String = buildings.current_place()
	for record: Dictionary in buildings.records:
		if record.get("kind", "") != "chest" or str(record.get("where", "world")) != place:
			continue
		var prop: Variant = buildings._props.get(record["id"])
		var at: Vector2 = (prop as Node2D).global_position if prop != null and is_instance_valid(prop) else Vector2(float(record.get("x", 0.0)), float(record.get("y", 0.0)))
		if at.distance_to(player.global_position) <= REACH:
			out.append(record)
	return out


## How many of a thing the nearby chests hold.
static func count(player: Player, item_id: String) -> int:
	var total := 0
	for record in chests_near(player):
		for saved: Dictionary in record["items"]:
			if str(saved.get("id", "")) == item_id:
				total += int(saved.get("count", 1))
	return total


## What the player has of a thing: the bag, the satchel and nearby chests.
static func available(player: Player, item_id: String) -> int:
	return player.inventory.count_of(item_id) + count(player, item_id)


## Takes `amount` of a thing from the nearby chests (plainest first);
## returns [taken, average rarity].
static func take(player: Player, item_id: String, amount: int) -> Array:
	var sources: Array = []
	for record in chests_near(player):
		for saved: Dictionary in record["items"]:
			if str(saved.get("id", "")) == item_id:
				sources.append([record, saved])
	sources.sort_custom(func(a: Array, b: Array) -> bool: return int(a[1].get("rarity", 0)) < int(b[1].get("rarity", 0)))
	var taken := 0
	var rarity_sum := 0.0
	for source: Array in sources:
		if taken >= amount:
			break
		var saved: Dictionary = source[1]
		var used := mini(int(saved.get("count", 1)), amount - taken)
		saved["count"] = int(saved.get("count", 1)) - used
		taken += used
		rarity_sum += used * int(saved.get("rarity", 0))
		if int(saved["count"]) <= 0:
			(source[0]["items"] as Array).erase(saved)
	if taken > 0:
		SaveGame.request_save()
	return [taken, rarity_sum / maxf(taken, 1.0)]


## Takes `amount` of a thing, the bag first and then the chests nearby;
## returns the average rarity of what was taken.
static func take_anywhere(player: Player, item_id: String, amount: int, best_first: bool = false) -> float:
	var from_bag := mini(player.inventory.count_of(item_id), amount)
	var rarity_sum := 0.0
	if from_bag > 0:
		player.inventory.take(item_id, from_bag, best_first)
		rarity_sum += player.inventory.last_rarity * from_bag
	var rest := amount - from_bag
	if rest > 0:
		var result := take(player, item_id, rest)
		rarity_sum += float(result[1]) * int(result[0])
	return rarity_sum / maxf(amount, 1.0)


## Quick stack: every unlocked thing in the bag that a nearby chest already
## holds some of goes into that chest (onto its stacks first, then into
## free slots). Returns how many stacks moved.
static func quick_stack(player: Player) -> int:
	var chests := chests_near(player)
	if chests.is_empty():
		return 0
	var moved := 0
	for item in player.inventory.items.duplicate():
		if item.locked or item.is_equipment() or item.is_tool() or item.is_backpack():
			continue
		for record in chests:
			var stored: Array = record["items"]
			var holds := stored.any(func(saved: Dictionary) -> bool: return str(saved.get("id", "")) == item.id)
			if not holds:
				continue
			var left: int = item.count
			# Onto the chest's own stacks of the same thing first.
			for saved: Dictionary in stored:
				if left <= 0:
					break
				if str(saved.get("id", "")) == item.id and int(saved.get("rarity", item.rarity)) == item.rarity:
					var room := ItemDB.MAX_STACK - int(saved.get("count", 1))
					var put := mini(room, left)
					if put > 0:
						saved["count"] = int(saved.get("count", 1)) + put
						left -= put
			if left > 0 and stored.size() < Buildings.CHEST_SLOTS:
				var rest := Item.from_dict(item.to_dict())
				rest.count = left
				rest.fresh = false
				stored.append(rest.to_dict())
				left = 0
			if left < item.count:
				moved += 1
				if left <= 0:
					player.inventory.remove(item)
				else:
					item.count = left
			if left <= 0:
				break
	if moved > 0:
		player.inventory.changed.emit()
		SaveGame.request_save()
	return moved
