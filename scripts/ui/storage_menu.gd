class_name StorageMenu
extends GameMenu
## A chest: what is inside on the left, the bag on the right, both laid out
## as grids like the inventory, each headed with how full it is and which
## way a click moves things. Click moves a whole stack across, Shift-click
## half of it, right-click a single one. One search box narrows both sides.

## The chest's saved record; its "items" array holds saved items.
var chest: Dictionary = {}

var _title: Label
var _heading: Label
var _chest_title: Label
var _chest_way: Label
var _bag_title: Label
var _bag_way: Label
var _chest_grid: ItemGrid
var _bag_grid: ItemGrid
var _message: Label
var _search: LineEdit
var _tip: ItemTooltip
var _keys: HBoxContainer
var _store_buttons: Array[Button] = []
## The saved dictionaries behind the chest grid, slot by slot.
var _saved: Array = []


func _build() -> void:
	content.add_theme_constant_override("separation", 10)
	_heading = UITheme.heading("STORAGE", 28)
	_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_heading)
	_tip = ItemTooltip.new()
	add_child(_tip)
	# What a click does, said once with the keys shown, and a search.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 18)
	content.add_child(top)
	_keys = HBoxContainer.new()
	_keys.add_theme_constant_override("separation", 18)
	top.add_child(_keys)
	_keys.add_child(UITheme.key_hint("Click", "whole stack"))
	_keys.add_child(UITheme.key_hint("Shift + Click", "half"))
	_keys.add_child(UITheme.key_hint("Right-click", "one"))
	_title = UITheme.label("", 14, UITheme.DIM)
	top.add_child(_title)
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(fill)
	_search = UITheme.search_box("Search both...", 220.0, refresh)
	top.add_child(_search)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	content.add_child(columns)
	var chest_side := _column(columns)
	_chest_title = chest_side[0]
	_chest_way = chest_side[2]
	_chest_grid = chest_side[1]
	_chest_grid.note_for = func(_item: Item) -> String: return "[color=#%s]Click to take it into your bag[/color]" % UITheme.GOOD.to_html(false)
	_chest_grid.picked.connect(func(item: Item, index: int) -> void: _take(_saved[index], item.count / 2 if Input.is_key_pressed(KEY_SHIFT) and item.count > 1 else item.count))
	_chest_grid.alt_picked.connect(func(_item: Item, index: int) -> void: _take(_saved[index], 1))
	var bag_side := _column(columns)
	_bag_title = bag_side[0]
	_bag_way = bag_side[2]
	_bag_grid = bag_side[1]
	_bag_grid.note_for = func(_item: Item) -> String:
		return "" if chest.get("take_only", false) else "[color=#%s]Click to put it in the chest[/color]" % UITheme.GOOD.to_html(false)
	_bag_grid.picked.connect(func(item: Item, _index: int) -> void: _store(item, item.count / 2 if Input.is_key_pressed(KEY_SHIFT) and item.count > 1 else item.count))
	_bag_grid.alt_picked.connect(func(item: Item, _index: int) -> void: _store(item, 1))

	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 8)
	content.add_child(bottom)
	bottom.add_child(UITheme.button("Take everything", _take_all, 170.0))
	var sort := UITheme.button("Sort chest", _sort_chest, 120.0)
	bottom.add_child(sort)
	var gap := Control.new()
	gap.custom_minimum_size.x = 30.0
	bottom.add_child(gap)
	var matching := UITheme.button("Store matching", _store_matching, 170.0)
	matching.tooltip_text = "Stores everything in your bag that the chest already holds some of."
	bottom.add_child(matching)
	var materials := UITheme.button("Store all materials", _store_materials, 190.0)
	bottom.add_child(materials)
	_store_buttons = [sort, matching, materials]
	_message = UITheme.reason("")
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.custom_minimum_size.y = 20.0
	content.add_child(_message)
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree():
			_tip.hide_tip()
	)
	player.inventory.changed.connect(refresh_if_open)


func _matches(item: Item) -> bool:
	var words := _search.text.strip_edges().to_lower()
	return words == "" or item.display_name().to_lower().contains(words) or ItemText.type_name(item).to_lower().contains(words)


func refresh() -> void:
	if chest.is_empty():
		return
	var stored: Array = chest["items"]
	var take_only: bool = chest.get("take_only", false)
	var searching := _search.text.strip_edges() != ""
	_heading.text = str(chest.get("title", "Storage")).to_upper()
	_title.text = "This can only be taken from." if take_only else ""
	_saved = []
	var items: Array = []
	var total := 0
	for saved: Variant in stored:
		var item := Item.from_dict(saved)
		if item:
			total += 1
			if _matches(item):
				items.append(item)
				_saved.append(saved)
	var capacity := Buildings.CHEST_SLOTS
	_chest_title.text = "Inside   %d / %d" % [total, capacity] if not take_only else "Inside   %d" % total
	_chest_title.add_theme_color_override("font_color", UITheme.BAD if total >= capacity and not take_only else UITheme.HEADING)
	_chest_way.text = "click  →  to your bag"
	_chest_grid.set_items(items, items.size() if searching else (maxi(capacity, items.size()) if not take_only else maxi(items.size(), 8)))
	var bag: Array = player.inventory.items.filter(func(item: Item) -> bool: return item != null and _matches(item)) if searching else player.inventory.items
	var full := player.inventory.items.size() >= player.inventory.capacity()
	_bag_title.text = "Your bag   %d / %d" % [player.inventory.items.size(), player.inventory.capacity()]
	_bag_title.add_theme_color_override("font_color", UITheme.BAD if full else UITheme.HEADING)
	_bag_way.text = "" if take_only else "to the chest  ←  click"
	_bag_grid.set_items(bag, bag.size() if searching else player.inventory.capacity())
	_bag_grid.modulate.a = 0.5 if take_only else 1.0
	for button in _store_buttons:
		button.disabled = take_only
		button.tooltip_text = "This can only be taken from." if take_only else button.tooltip_text


func _say(text: String) -> void:
	_message.text = text


## Moves `amount` of a bag stack into the chest. Returns whether it fitted.
func _store(item: Item, amount: int) -> bool:
	if chest.is_empty() or chest.get("take_only", false):
		_say("Nothing can be put in here; it can only be taken from.")
		return false
	var stored: Array = chest["items"]
	amount = clampi(amount, 1, item.count)
	_say("")
	# Stackables join a matching stack; everything else needs its own slot.
	var joined := false
	if item.is_stackable():
		for saved: Dictionary in stored:
			if saved["id"] == item.id and Item.from_dict(saved).rarity == item.rarity:
				saved["count"] = int(saved["count"]) + amount
				joined = true
				break
	if not joined:
		if stored.size() >= Buildings.CHEST_SLOTS:
			_say("The chest is full: all %d slots hold something. Take things out, or add to a stack it already has." % Buildings.CHEST_SLOTS)
			return false
		var record := item.to_dict()
		record["count"] = amount
		stored.append(record)
	if amount >= item.count:
		player.inventory.remove(item)
	else:
		item.count -= amount
		player.inventory.changed.emit()
	_changed()
	return true


## Takes `amount` of a chest stack into the bag.
func _take(saved: Dictionary, amount: int) -> bool:
	var item := Item.from_dict(saved)
	_say("")
	if item == null:
		return false
	amount = clampi(amount, 1, item.count)
	item.count = amount
	if not player.inventory.add(item):
		_say("Your bag is full: %d of %d slots used. Store or drop something first." % [player.inventory.items.size(), player.inventory.capacity()])
		return false
	if amount >= int(saved.get("count", 1)):
		(chest["items"] as Array).erase(saved)
	else:
		saved["count"] = int(saved["count"]) - amount
	_changed()
	return true


func _changed() -> void:
	_tip.hide_tip()
	SaveGame.request_save()
	refresh()


## One side of the screen: a heading and which way a click moves things,
## over a grid. Returns [heading, grid, direction label].
func _column(parent: Control) -> Array:
	var panel := UITheme.inset_panel()
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	var heading := UITheme.heading("", 17)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(heading)
	var way := UITheme.label("", 14, UITheme.INFO)
	head.add_child(way)
	var grid := ItemGrid.new()
	grid.setup(player, _tip, 8, 7)
	box.add_child(grid)
	return [heading, grid, way]


func _take_all() -> void:
	if chest.is_empty():
		return
	for saved: Dictionary in (chest["items"] as Array).duplicate():
		if not _take(saved, int(saved.get("count", 1))):
			break


## Puts the chest in order: gear, then supplies, then materials, by name.
func _sort_chest() -> void:
	if chest.is_empty() or chest.get("take_only", false):
		return
	var order := {"gear": 0, "supplies": 1, "materials": 2}
	(chest["items"] as Array).sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var item_a := Item.from_dict(a)
		var item_b := Item.from_dict(b)
		if item_a == null or item_b == null:
			return item_a != null
		var kind_a: int = order[InventoryMenu.category(item_a)]
		var kind_b: int = order[InventoryMenu.category(item_b)]
		if kind_a != kind_b:
			return kind_a < kind_b
		if item_a.rarity != item_b.rarity:
			return item_a.rarity > item_b.rarity
		return item_a.display_name() < item_b.display_name()
	)
	_changed()


## Stores every bag stack the chest already holds some of.
func _store_matching() -> void:
	if chest.is_empty() or chest.get("take_only", false):
		return
	var held := {}
	for saved: Dictionary in chest["items"]:
		held[saved["id"]] = true
	var moved := 0
	for item: Item in player.inventory.items.duplicate():
		if item and held.has(item.id) and not item.locked:
			if not _store(item, item.count):
				return
			moved += 1
	_say("Stored %d matching stack%s." % [moved, "" if moved == 1 else "s"] if moved > 0 else "Nothing in your bag matches what the chest holds.")


## Puts every stack of plain materials into the chest at once.
func _store_materials() -> void:
	if chest.is_empty() or chest.get("take_only", false):
		return
	var moved := 0
	for item: Item in player.inventory.items.duplicate():
		if item.is_stackable() and not item.is_consumable() and not item.is_placeable():
			if not _store(item, item.count):
				return
			moved += 1
	_say("Stored %d stack%s of materials." % [moved, "" if moved == 1 else "s"] if moved > 0 else "You carry no materials to store.")
