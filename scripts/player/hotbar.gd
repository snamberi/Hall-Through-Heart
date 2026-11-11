class_name Hotbar
extends Node
## Five quick slots for items, on keys 5 to 9 by default. A slot remembers
## an item id and uses whichever stack of it is in the bag: placeables are
## taken in hand to be set down, food and potions are eaten or drunk, and
## gear is put on. Hover an item in the inventory and press a slot's key
## to put it there.

signal changed

const SIZE := 5

var slots: Array[String] = ["", "", "", "", ""]
var selected := -1

var _player: Player


func _ready() -> void:
	_player = get_parent()
	SaveGame.register("hotbar", self)


func assign(index: int, item_id: String) -> void:
	if index < 0 or index >= SIZE:
		return
	# An item sits in one slot only.
	for other in SIZE:
		if slots[other] == item_id:
			slots[other] = ""
	slots[index] = item_id
	changed.emit()
	SaveGame.request_save()


func clear(index: int) -> void:
	slots[index] = ""
	changed.emit()


func item_in(index: int) -> Item:
	var id := slots[index]
	if id == "":
		return null
	for item in _player.inventory.items:
		if item and item.id == id:
			return item
	return null


func count_in(index: int) -> int:
	return _player.inventory.count_of(slots[index]) if slots[index] != "" else 0


## Uses what is in a slot. Returns "" or why not.
func activate(index: int) -> String:
	var item := item_in(index)
	if item == null:
		return "Nothing in that slot." if slots[index] == "" else "None left."
	selected = index
	changed.emit()
	if item.is_equipment():
		return _player.equipment.equip(item)
	return _player.use_item(item)


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
	return {"slots": slots.duplicate()}


func load_data(data: Dictionary) -> void:
	var saved: Variant = data.get("slots", [])
	for index in SIZE:
		slots[index] = str(saved[index]) if saved is Array and index < saved.size() and ItemDB.ITEMS.has(str(saved[index])) else ""
	changed.emit()
