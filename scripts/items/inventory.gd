class_name Inventory
extends Node
## The player's bag and gold.

signal changed

## Slots in the bag itself; a backpack adds more.
const BASE := 60
## Extra slots from the backpack worn (kept up to date by Equipment).
var bonus_slots := 0

var items: Array[Item] = []
var gold := 0
## Whether the new-game starting gear has been handed out.
var starter_given := false
## Whether the basic gathering tools have been handed out.
var tools_given := false


func _ready() -> void:
	SaveGame.register("inventory", self)


func capacity() -> int:
	return BASE + bonus_slots


func free_slots() -> int:
	return capacity() - items.size()


func has_room_for(item: Item) -> bool:
	if item.is_stackable() and _find_stack(item.id) != null:
		return true
	return free_slots() > 0


## Adds an item, merging stackables. Returns false if the bag is full.
func add(item: Item) -> bool:
	# Coins go straight into the purse.
	if item.definition().get("currency", false):
		add_gold(item.count)
		return true
	if not has_room_for(item):
		return false
	if item.is_unique():
		Events.codex_event.emit("uniques", 1)
	elif item.set_id != "":
		Events.codex_event.emit("set_pieces", 1)
	var stack := _find_stack(item.id) if item.is_stackable() else null
	if stack:
		stack.count = mini(stack.count + item.count, ItemDB.MAX_STACK)
	else:
		items.append(item)
	changed.emit()
	SaveGame.request_save()
	return true


func remove(item: Item) -> void:
	items.erase(item)
	changed.emit()
	SaveGame.request_save()


func add_gold(amount: int) -> void:
	gold = maxi(gold + amount, 0)
	changed.emit()
	SaveGame.request_save()


func count_of(item_id: String) -> int:
	var total := 0
	for item in items:
		if item.id == item_id:
			total += item.count
	return total


## Removes `amount` of a stackable item. Returns false (taking nothing) if
## the bag holds fewer.
func take(item_id: String, amount: int) -> bool:
	if count_of(item_id) < amount:
		return false
	for item: Item in items.duplicate():
		if item.id != item_id or amount <= 0:
			continue
		var used := mini(item.count, amount)
		item.count -= used
		amount -= used
		if item.count <= 0:
			items.erase(item)
	changed.emit()
	SaveGame.request_save()
	return true


## The best tool of a kind in the bag ("pickaxe", "hatchet", "rod"), or null.
func best_tool(kind: String) -> Item:
	var best: Item = null
	for item in items:
		if item.is_tool() and item.definition()["tool"]["kind"] == kind:
			if best == null or item.definition()["tool"]["tier"] > best.definition()["tool"]["tier"]:
				best = item
	return best


## Equipment first, best rarity and level first, then materials by name.
func sort() -> void:
	items.sort_custom(func(a: Item, b: Item) -> bool:
		if a.is_equipment() != b.is_equipment():
			return a.is_equipment()
		if a.rarity != b.rarity:
			return a.rarity > b.rarity
		if a.level != b.level:
			return a.level > b.level
		return a.display_name() < b.display_name()
	)
	changed.emit()


func save_data() -> Dictionary:
	return {
		"gold": gold,
		"starter_given": starter_given,
		"tools_given": tools_given,
		"items": items.map(func(item: Item) -> Dictionary: return item.to_dict()),
	}


func load_data(data: Dictionary) -> void:
	gold = maxi(int(data.get("gold", 0)), 0)
	starter_given = bool(data.get("starter_given", false))
	tools_given = bool(data.get("tools_given", false))
	items.clear()
	var saved: Variant = data.get("items", [])
	if saved is Array:
		for entry: Variant in saved:
			var item := Item.from_dict(entry) if entry is Dictionary else null
			if item and items.size() < BASE + 60:
				items.append(item)


func _find_stack(item_id: String) -> Item:
	for item in items:
		if item.id == item_id and item.count < ItemDB.MAX_STACK:
			return item
	return null
