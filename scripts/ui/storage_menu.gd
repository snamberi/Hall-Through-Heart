class_name StorageMenu
extends GameMenu
## A storage chest: click an item to move its whole stack to the other side.

## The chest's saved record; its "items" array holds saved items.
var chest: Dictionary = {}

var _title: Label
var _heading: Label
var _chest_list: VBoxContainer
var _bag_list: VBoxContainer
var _message: Label


func _build() -> void:
	_heading = UITheme.heading("STORAGE", 30)
	_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_heading)
	_title = UITheme.label("", 14, UITheme.DIM)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_title)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	content.add_child(columns)
	_chest_list = _column(columns, "Inside")
	_bag_list = _column(columns, "In your bag")
	var take_all := UITheme.button("Take everything", _take_all, 240.0)
	take_all.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(take_all)
	_message = UITheme.label("", 14, UITheme.BAD)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_message)


func refresh() -> void:
	if chest.is_empty():
		return
	var stored: Array = chest["items"]
	var take_only: bool = chest.get("take_only", false)
	_heading.text = str(chest.get("title", "Storage")).to_upper()
	_title.text = "Click an item to take it." if take_only else "%d of %d slots used. Click an item to move it across." % [stored.size(), Buildings.CHEST_SLOTS]
	for list: VBoxContainer in [_chest_list, _bag_list]:
		for child in list.get_children():
			child.queue_free()
	for saved: Variant in stored:
		var item := Item.from_dict(saved)
		if item:
			_chest_list.add_child(_row(item, func() -> void: _take(saved)))
	for item in player.inventory.items:
		var row := _row(item, func() -> void: _store(item))
		row.disabled = take_only
		_bag_list.add_child(row)


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
	SaveGame.request_save()
	refresh()


func _column(parent: Control, title: String) -> VBoxContainer:
	var panel := UITheme.inset_panel()
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	box.add_child(UITheme.heading(title, 16))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(340.0, 380.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 3)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	return list


func _row(item: Item, action: Callable) -> Button:
	var button := Button.new()
	button.text = " %s%s" % [item.display_name(), "  x%d" % item.count if item.count > 1 else ""]
	button.icon = item.icon()
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_constant_override("icon_max_width", 20)
	button.add_theme_color_override("font_color", item.color())
	for state: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color"]:
		button.add_theme_color_override(state, item.tint())
	button.pressed.connect(action)
	return button


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
