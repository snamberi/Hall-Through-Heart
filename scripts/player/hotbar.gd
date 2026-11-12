class_name Hotbar
extends Node
## The nine quick slots along the bottom of the screen.
##
##   1        a staff or other magic weapon
##   2, 3     two more weapons
##   4, 5, 6  pickaxe, hatchet, fishing rod
##   7, 8     potions (or anything else that can be used or set down)
##   9        food
##
## Slots 1 to 6 are the belt (see Equipment): pressing the key takes that
## weapon or tool in hand. Slots 7 to 9 remember an item id and use
## whichever stack of it is in the bag. Q uses the quick item, chosen by
## hovering something in the inventory and pressing Q.

signal changed

const SIZE := 9
const BELT_SIZE := 6
## What each slot is for, shown in empty slots and in hints.
const LABELS: Array[String] = ["Magic", "Weapon", "Weapon", "Pickaxe", "Hatchet", "Rod", "Potion", "Potion", "Food"]
## Icon shown faintly in an empty slot.
const GHOST_ICONS: Array[int] = [27, 0, 0, 49, 50, 51, 44, 44, 66]

## Item ids for slots 7, 8 and 9.
var slots: Array[String] = ["", "", ""]
## The item Q uses; "" falls back to the best healing potion.
var quick_id := ""

var _player: Player


func _ready() -> void:
	_player = get_parent()
	SaveGame.register("hotbar", self)
	_player.equipment.changed.connect(func() -> void: changed.emit())
	_player.inventory.changed.connect(func() -> void: changed.emit())


## The belt slot behind a hotbar index, or "" for the item slots.
static func belt_slot(index: int) -> String:
	return Equipment.BELT[index] if index >= 0 and index < BELT_SIZE else ""


## Puts something in a slot: equips a weapon or tool onto the belt, or
## remembers a usable item for slots 7 to 9. Returns "" or why not.
func assign(index: int, item: Item) -> String:
	if index < 0 or index >= SIZE or item == null:
		return ""
	if index < BELT_SIZE:
		var slot := belt_slot(index)
		if not _player.equipment.fits(item, slot):
			return "Slot %d is for a %s." % [index + 1, ("staff or other magic weapon" if index == 0 else LABELS[index].to_lower())]
		if _player.equipment.slot_of(item) == slot:
			return ""
		return _player.equipment.equip(item, slot)
	if not (item.is_consumable() or item.is_placeable()):
		return "Slot %d is for things you can use: potions, food, torches." % (index + 1)
	# An item sits in one slot only.
	for other in slots.size():
		if slots[other] == item.id:
			slots[other] = ""
	slots[index - BELT_SIZE] = item.id
	changed.emit()
	SaveGame.request_save()
	return ""


func set_quick(item: Item) -> String:
	if not (item.is_consumable() or item.is_placeable()):
		return "Only things you can use can be the quick item."
	quick_id = item.id
	changed.emit()
	SaveGame.request_save()
	return ""


## The id remembered in a slot ("" for belt slots and empty ones).
func id_in(index: int) -> String:
	return slots[index - BELT_SIZE] if index >= BELT_SIZE and index < SIZE else ""


func item_in(index: int) -> Item:
	if index < BELT_SIZE:
		return _player.equipment.equipped.get(belt_slot(index))
	return _stack(id_in(index))


func count_in(index: int) -> int:
	var id := id_in(index)
	return _player.inventory.count_of(id) if id != "" else 0


func quick_item() -> Item:
	return _stack(quick_id)


## Whether a slot is the one in hand.
func is_active(index: int) -> bool:
	return index < BELT_SIZE and _player.equipment.active_slot == belt_slot(index) and _player.equipment.equipped.has(belt_slot(index))


## Uses what is in a slot. Returns "" or why not.
func activate(index: int) -> String:
	if index < BELT_SIZE:
		if not _player.equipment.select(belt_slot(index)):
			return "No %s on your belt." % LABELS[index].to_lower()
		Audio.play("swing", -12.0, 0.2)
		return ""
	var item := item_in(index)
	if item == null:
		return "Nothing in that slot." if id_in(index) == "" else "None left."
	return _player.use_item(item)


## Q: the chosen quick item, or the best healing potion if none is chosen.
func use_quick() -> String:
	if quick_id == "":
		_player.quick_potion()
		return ""
	var item := quick_item()
	if item == null:
		return "No %s left." % ItemDB.ITEMS[quick_id]["name"]
	return _player.use_item(item)


func _stack(id: String) -> Item:
	if id == "":
		return null
	for item in _player.inventory.items:
		if item and item.id == id:
			return item
	return null


func _unhandled_input(event: InputEvent) -> void:
	if _player.is_dead() or get_tree().paused:
		return
	for index in SIZE:
		if event.is_action_pressed("hotbar_%d" % (index + 1)):
			var problem := activate(index)
			if problem != "":
				DamageNumber.spawn_text(_player.get_parent(), _player.global_position + Vector2(0, -50), problem, UITheme.BAD, 13)
			get_viewport().set_input_as_handled()
			return


func save_data() -> Dictionary:
	return {"items": slots.duplicate(), "quick": quick_id}


func load_data(data: Dictionary) -> void:
	slots = ["", "", ""]
	var usable := func(id: String) -> bool:
		return ItemDB.ITEMS.has(id) and not ItemDB.ITEMS[id].has("slot") and not ItemDB.ITEMS[id].has("tool")
	var saved: Variant = data.get("items")
	if saved is Array:
		for index in mini(saved.size(), 3):
			slots[index] = str(saved[index]) if usable.call(str(saved[index])) else ""
	elif data.get("slots") is Array:
		# The old five-slot bar: keep its first three usable things.
		var next := 0
		for entry: Variant in data["slots"]:
			if next < 3 and usable.call(str(entry)):
				slots[next] = str(entry)
				next += 1
	quick_id = str(data.get("quick", ""))
	if not ItemDB.ITEMS.has(quick_id):
		quick_id = ""
	changed.emit()
