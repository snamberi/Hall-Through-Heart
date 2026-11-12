class_name StorageMenu
extends GameMenu
## A chest: its slots on the left, the bag on the right, both laid out as
## grids like the inventory. Click an item to move its whole stack across.

## The chest's saved record; its "items" array holds saved items.
var chest: Dictionary = {}

var _title: Label
var _heading: Label
var _chest_title: Label
var _bag_title: Label
var _chest_grid: ItemGrid
var _bag_grid: ItemGrid
var _message: Label
var _tip: ItemTooltip
## The saved dictionaries behind the chest grid, slot by slot.
var _saved: Array = []


func _build() -> void:
	_heading = UITheme.heading("STORAGE", 30)
	_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_heading)
	_title = UITheme.label("", 14, UITheme.DIM)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_title)
	_tip = ItemTooltip.new()
	add_child(_tip)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	content.add_child(columns)
	var chest_side := _column(columns)
	_chest_title = chest_side[0]
	_chest_grid = chest_side[1]
	_chest_grid.note_for = func(_item: Item) -> String: return "[color=#%s]Click to take it[/color]" % UITheme.GOOD.to_html(false)
	_chest_grid.picked.connect(func(_item: Item, index: int) -> void: _take(_saved[index]))
	var bag_side := _column(columns)
	_bag_title = bag_side[0]
	_bag_grid = bag_side[1]
	_bag_grid.note_for = func(_item: Item) -> String:
		return "" if chest.get("take_only", false) else "[color=#%s]Click to put it in the chest[/color]" % UITheme.GOOD.to_html(false)
	_bag_grid.picked.connect(func(item: Item, _index: int) -> void: _store(item))
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 12)
	content.add_child(bottom)
	bottom.add_child(UITheme.button("Take everything", _take_all, 220.0))
	bottom.add_child(UITheme.button("Store all materials", _store_materials, 220.0))
	_message = UITheme.label("", 14, UITheme.BAD)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_message)
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree():
			_tip.hide_tip()
	)
	player.inventory.changed.connect(refresh_if_open)


func refresh() -> void:
	if chest.is_empty():
		return
	var stored: Array = chest["items"]
	var take_only: bool = chest.get("take_only", false)
	_heading.text = str(chest.get("title", "Storage")).to_upper()
	_title.text = "Click an item to take it." if take_only else "Click an item to move its whole stack across."
	_saved = []
	var items: Array = []
	for saved: Variant in stored:
		var item := Item.from_dict(saved)
		if item:
			items.append(item)
			_saved.append(saved)
	_chest_title.text = "Inside   %d / %d" % [items.size(), Buildings.CHEST_SLOTS]
	_chest_grid.set_items(items, maxi(Buildings.CHEST_SLOTS, items.size()) if not take_only else maxi(items.size(), 8))
	_bag_title.text = "Your bag   %d / %d" % [player.inventory.items.size(), player.inventory.capacity()]
	_bag_grid.set_items(player.inventory.items, player.inventory.capacity())
	_bag_grid.modulate.a = 0.5 if take_only else 1.0


func _store(item: Item) -> void:
	if chest.is_empty() or chest.get("take_only", false):
		return
	var stored: Array = chest["items"]
	_message.text = ""
	# Stackables join a matching stack; everything else needs its own slot.
	if item.is_stackable():
		for saved: Dictionary in stored:
			if saved["id"] == item.id:
				saved["count"] = int(saved["count"]) + item.count
				player.inventory.remove(item)
				_changed()
				return
	if stored.size() >= Buildings.CHEST_SLOTS:
		_message.text = "The chest is full."
		return
	stored.append(item.to_dict())
	player.inventory.remove(item)
	_changed()


func _take(saved: Dictionary) -> void:
	var item := Item.from_dict(saved)
	_message.text = ""
	if item == null or not player.inventory.add(item):
		_message.text = "Inventory is full."
		return
	(chest["items"] as Array).erase(saved)
	_changed()


func _changed() -> void:
	_tip.hide_tip()
	SaveGame.request_save()
	refresh()


## One side of the screen: a heading over a grid. Returns [heading, grid].
func _column(parent: Control) -> Array:
	var panel := UITheme.inset_panel()
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var heading := UITheme.heading("", 16)
	box.add_child(heading)
	var grid := ItemGrid.new()
	grid.setup(player, _tip, 8, 7)
	box.add_child(grid)
	return [heading, grid]


func _take_all() -> void:
	if chest.is_empty():
		return
	for saved: Dictionary in (chest["items"] as Array).duplicate():
		var item := Item.from_dict(saved)
		if item == null or not player.inventory.add(item):
			_message.text = "Inventory is full."
			break
		(chest["items"] as Array).erase(saved)
	_changed()


## Puts every stack of plain materials into the chest at once.
func _store_materials() -> void:
	if chest.is_empty() or chest.get("take_only", false):
		return
	for item: Item in player.inventory.items.duplicate():
		if item.is_stackable() and not item.is_consumable() and not item.is_placeable():
			_store(item)
			if _message.text != "":
				break
