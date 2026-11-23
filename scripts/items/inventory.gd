class_name Inventory
extends Node
## The player's bag and gold.

signal changed

## Slots in the bag itself; a backpack adds more.
const BASE := 100
## Extra slots from the backpack worn (kept up to date by Equipment).
var bonus_slots := 0
## Slots a race carries more (an orc) or fewer (a fairy) than others.
var race_slots := 0

var items: Array[Item] = []
var gold := 0
## Whether the new-game starting gear has been handed out.
var starter_given := false
## Whether the basic gathering tools have been handed out.
var tools_given := false
## The Bottomless Satchel, once bound: materials go into it, with no limit
## on how many, and everything that counts or takes materials (crafting,
## smelting, projects) reaches into it too.
var satchel := false
## Whether picked-up materials go straight into the satchel.
var satchel_auto := true
## What the satchel holds: "id|rarity" -> count.
var materials: Dictionary = {}


func _ready() -> void:
	SaveGame.register("inventory", self)


func capacity() -> int:
	return maxi(BASE + bonus_slots + race_slots, 10)


func free_slots() -> int:
	return capacity() - items.size()


func has_room_for(item: Item) -> bool:
	if item.definition().get("currency", false) or _to_satchel(item):
		return true
	if not item.is_stackable():
		return free_slots() > 0
	# Room left on stacks of it, and in empty slots, must hold all of it.
	var room := free_slots() * ItemDB.MAX_STACK
	for stack in items:
		if stack.id == item.id and stack.rarity == item.rarity:
			room += maxi(ItemDB.MAX_STACK - stack.count, 0)
	return room >= item.count


## Adds an item, merging stackables. Returns false if the bag is full.
## Puts an item in the bag. Something new to the bag (not an unequipped or
## stored piece, which pass `arriving` false) is marked fresh, unless it only
## joins a stack already there.
func add(item: Item, arriving: bool = true) -> bool:
	# Coins go straight into the purse.
	if item.definition().get("currency", false):
		add_gold(item.count)
		return true
	if _to_satchel(item):
		store_material(item)
		return true
	if not has_room_for(item):
		return false
	if item.is_unique():
		Events.codex_event.emit("uniques", 1)
	elif item.set_id != "":
		Events.codex_event.emit("set_pieces", 1)
	if item.is_stackable():
		# Top up the stacks already here, then start new ones of up to
		# MAX_STACK each, so nothing past a full stack is lost.
		var left := item.count
		for stack in items:
			if left <= 0:
				break
			if stack.id == item.id and stack.rarity == item.rarity and stack.count < ItemDB.MAX_STACK:
				var moved := mini(ItemDB.MAX_STACK - stack.count, left)
				stack.count += moved
				left -= moved
		var first := true
		while left > 0:
			var piece := item if first else Item.from_dict(item.to_dict())
			first = false
			piece.count = mini(left, ItemDB.MAX_STACK)
			piece.fresh = arriving
			items.append(piece)
			left -= piece.count
	else:
		item.fresh = arriving
		# Plain common gear can be marked as junk as it comes in.
		if arriving and GameSettings.auto_junk and item.is_equipment() and item.rarity == 0 and not item.is_unique() and item.set_id == "" and not item.locked:
			item.junk = true
		items.append(item)
	changed.emit()
	SaveGame.request_save()
	return true


## How many items in the bag are new.
func fresh_count() -> int:
	var total := 0
	for item in items:
		if item and item.fresh:
			total += 1
	return total


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
	if not materials.is_empty():
		for key: String in materials:
			if key.get_slice("|", 0) == item_id:
				total += int(materials[key])
	return total


# --- the Bottomless Satchel

## Whether something picked up goes straight into the satchel.
func _to_satchel(item: Item) -> bool:
	return satchel and satchel_auto and ItemDB.is_satchel_material(item.id)


## Binds the satchel: from now on materials have somewhere to go.
func bind_satchel(item: Item) -> String:
	if satchel:
		return "You already carry a Bottomless Satchel."
	satchel = true
	remove(item)
	store_all_materials()
	Events.announcement.emit("BOTTOMLESS SATCHEL", "Materials now go into it, and there is no end to it")
	return ""


## Puts a stack of a material into the satchel.
func store_material(item: Item) -> void:
	var key := "%s|%d" % [item.id, item.rarity]
	materials[key] = int(materials.get(key, 0)) + item.count
	changed.emit()
	SaveGame.request_save()


## Moves every material in the bag into the satchel. Returns how many stacks.
func store_all_materials() -> int:
	var moved := 0
	for item in items.duplicate():
		if item and not item.locked and ItemDB.is_satchel_material(item.id):
			items.erase(item)
			var key := "%s|%d" % [item.id, item.rarity]
			materials[key] = int(materials.get(key, 0)) + item.count
			moved += 1
	if moved > 0:
		changed.emit()
		SaveGame.request_save()
	return moved


## The satchel's contents as items (counts can be far over a stack), best
## first, then by name.
func satchel_items() -> Array[Item]:
	var result: Array[Item] = []
	for key: String in materials:
		var id := key.get_slice("|", 0)
		if not ItemDB.ITEMS.has(id) or int(materials[key]) <= 0:
			continue
		var item := Item.create(id, int(materials[key]))
		item.rarity = int(key.get_slice("|", 1))
		result.append(item)
	result.sort_custom(func(a: Item, b: Item) -> bool: return a.display_name() < b.display_name() if a.display_name() != b.display_name() else a.rarity > b.rarity)
	return result


## Takes up to `amount` of a satchel stack out into the bag. Returns how
## many came out (fewer if the bag filled up).
func withdraw(item_id: String, rarity: int, amount: int) -> int:
	var key := "%s|%d" % [item_id, rarity]
	var have := int(materials.get(key, 0))
	var moved := 0
	amount = mini(amount, have)
	while moved < amount:
		var piece := Item.create(item_id, mini(amount - moved, ItemDB.MAX_STACK))
		piece.rarity = rarity
		# Into the bag itself, not back through add (which would store it again).
		var room := free_slots() * ItemDB.MAX_STACK
		for stack in items:
			if stack.id == item_id and stack.rarity == rarity:
				room += maxi(ItemDB.MAX_STACK - stack.count, 0)
		if room <= 0:
			break
		piece.count = mini(piece.count, room)
		var left := piece.count
		for stack in items:
			if left > 0 and stack.id == item_id and stack.rarity == rarity and stack.count < ItemDB.MAX_STACK:
				var into := mini(ItemDB.MAX_STACK - stack.count, left)
				stack.count += into
				left -= into
		if left > 0:
			piece.count = left
			items.append(piece)
		moved += mini(amount - moved, room)
	if moved > 0:
		materials[key] = have - moved
		if int(materials[key]) <= 0:
			materials.erase(key)
		changed.emit()
		SaveGame.request_save()
	return moved


## Removes `amount` of a stackable item, the plainest first (or the finest
## first with `best_first`). Returns false (taking nothing) if the bag holds
## fewer. `last_rarity` keeps the average rarity of what was taken.
func take(item_id: String, amount: int, best_first: bool = false) -> bool:
	if count_of(item_id) < amount:
		return false
	# Every stack of it, in the bag and in the satchel, worst first (or best).
	var sources: Array = []
	for item in items:
		if item.id == item_id:
			sources.append([item.rarity, item, ""])
	for key: String in materials:
		if key.get_slice("|", 0) == item_id:
			sources.append([int(key.get_slice("|", 1)), null, key])
	sources.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0] if best_first else a[0] < b[0])
	var total := 0.0
	var taken := amount
	for source: Array in sources:
		if amount <= 0:
			break
		if source[1] != null:
			var item: Item = source[1]
			var used := mini(item.count, amount)
			item.count -= used
			amount -= used
			total += used * item.rarity
			if item.count <= 0:
				items.erase(item)
		else:
			var key: String = source[2]
			var used := mini(int(materials[key]), amount)
			materials[key] = int(materials[key]) - used
			amount -= used
			total += used * int(source[0])
			if int(materials[key]) <= 0:
				materials.erase(key)
	last_rarity = total / maxf(taken, 1.0)
	changed.emit()
	SaveGame.request_save()
	return true


## Average rarity of the last thing taken (see take()).
var last_rarity := 0.0


## The best tool of a kind in the bag ("pickaxe", "hatchet", "rod"), or null.
func best_tool(kind: String) -> Item:
	var best: Item = null
	for item in items:
		if item.is_tool() and item.definition()["tool"]["kind"] == kind:
			if best == null or item.definition()["tool"]["tier"] > best.definition()["tool"]["tier"]:
				best = item
	return best


## Equipment first, best rarity and level first, then materials by name;
## junk always sinks to the end.
func sort() -> void:
	items.sort_custom(func(a: Item, b: Item) -> bool:
		if a.junk != b.junk:
			return b.junk
		if a.is_equipment() != b.is_equipment():
			return a.is_equipment()
		if a.rarity != b.rarity:
			return a.rarity > b.rarity
		if a.level != b.level:
			return a.level > b.level
		return a.display_name() < b.display_name()
	)
	changed.emit()


## Everything marked as junk.
func junk_items() -> Array[Item]:
	return items.filter(func(item: Item) -> bool: return item.junk and not item.locked)


## Splits a stack: `amount` of it goes into a new stack in a free slot.
## Returns "" or why it could not.
func split(item: Item, amount: int) -> String:
	if not item in items or not item.is_stackable() or item.count < 2:
		return "Only a stack of two or more can be split."
	if items.size() >= capacity():
		return "No free slot to split into."
	amount = clampi(amount, 1, item.count - 1)
	var piece := Item.from_dict(item.to_dict())
	piece.count = amount
	piece.fresh = false
	item.count -= amount
	items.insert(items.find(item) + 1, piece)
	changed.emit()
	SaveGame.request_save()
	return ""


func save_data() -> Dictionary:
	return {
		"gold": gold,
		"starter_given": starter_given,
		"tools_given": tools_given,
		"items": items.map(func(item: Item) -> Dictionary: return item.to_dict()),
		"satchel": satchel,
		"satchel_auto": satchel_auto,
		"materials": materials.duplicate(),
	}


func load_data(data: Dictionary) -> void:
	gold = maxi(int(data.get("gold", 0)), 0)
	starter_given = bool(data.get("starter_given", false))
	tools_given = bool(data.get("tools_given", false))
	satchel = bool(data.get("satchel", false))
	satchel_auto = bool(data.get("satchel_auto", true))
	materials.clear()
	var stored: Variant = data.get("materials", {})
	if stored is Dictionary:
		for key: Variant in stored:
			if ItemDB.ITEMS.has(str(key).get_slice("|", 0)) and int(stored[key]) > 0:
				materials[str(key)] = int(stored[key])
	items.clear()
	var saved: Variant = data.get("items", [])
	if saved is Array:
		for entry: Variant in saved:
			var item := Item.from_dict(entry) if entry is Dictionary else null
			if item and items.size() < BASE + 60:
				items.append(item)


func _find_stack(item_id: String, rarity: int = -1) -> Item:
	for item in items:
		if item.id == item_id and item.count < ItemDB.MAX_STACK and (rarity < 0 or item.rarity == rarity):
			return item
	return null
