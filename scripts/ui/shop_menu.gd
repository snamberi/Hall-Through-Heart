class_name ShopMenu
extends GameMenu
## Trading with a merchant: their wares on the left, your bag on the right.

var npc: Npc

var _gold: Label
var _restock: Label
var _stock_list: VBoxContainer
var _bag_list: VBoxContainer
var _details: RichTextLabel
var _action: Button
var _action_many: Button
var _message: Label
## The selected line: {"item", "price", "selling": bool, "entry": stock entry or null}.
var _choice: Dictionary = {}


func _build() -> void:
	var title := UITheme.heading("MERCHANT", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(top)
	top.add_child(UITheme.icon(ItemDB.GOLD_ICON, 24.0))
	_gold = UITheme.label("", 18, UITheme.GOLD)
	top.add_child(_gold)
	_restock = UITheme.label("", 14, UITheme.DIM)
	top.add_child(_restock)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	content.add_child(columns)
	_stock_list = _column(columns, "For sale")
	_bag_list = _column(columns, "Your bag  (sells for a quarter of its worth)")

	var right_panel := UITheme.inset_panel()
	columns.add_child(right_panel)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right_panel.add_child(right)
	_details = RichTextLabel.new()
	_details.bbcode_enabled = true
	_details.fit_content = true
	_details.scroll_active = false
	_details.custom_minimum_size = Vector2(280.0, 300.0)
	_details.add_theme_font_size_override("normal_font_size", 14)
	_details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(_details)
	_message = UITheme.label("", 13, UITheme.BAD)
	_message.custom_minimum_size = Vector2(280.0, 20.0)
	right.add_child(_message)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	right.add_child(buttons)
	_action = UITheme.button("Buy", _trade.bind(1), 136.0)
	_action_many = UITheme.button("Buy 5", _trade.bind(5), 136.0)
	buttons.add_child(_action)
	buttons.add_child(_action_many)
	player.inventory.changed.connect(refresh_if_open)


func refresh() -> void:
	if npc == null or not is_instance_valid(npc):
		return
	npc.restock_if_due(player)
	_gold.text = "%d gold" % player.inventory.gold
	_restock.text = "      New wares in %d min" % ceili(npc.restock_in() / 60.0)
	for list: VBoxContainer in [_stock_list, _bag_list]:
		for child in list.get_children():
			child.queue_free()
	for entry in npc.stock:
		_stock_list.add_child(_row(entry["item"], entry["price"], false, entry))
	for item in player.inventory.items:
		_bag_list.add_child(_row(item, Npc.sell_price(item), true, {}))
	_show()


func _column(parent: Control, title: String) -> VBoxContainer:
	var panel := UITheme.inset_panel()
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	box.add_child(UITheme.heading(title, 16))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(310.0, 380.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 3)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	return list


func _row(item: Item, price: int, selling: bool, entry: Dictionary) -> Button:
	var button := Button.new()
	var count := "  x%d" % item.count if item.count > 1 else ""
	button.text = " %s%s   -   %d g" % [item.display_name(), count, price]
	button.icon = item.icon()
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_NONE
	button.toggle_mode = true
	button.button_pressed = not _choice.is_empty() and _choice["item"] == item
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_constant_override("icon_max_width", 20)
	button.add_theme_color_override("font_color", item.color())
	for state: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color"]:
		button.add_theme_color_override(state, item.icon_tint())
	button.pressed.connect(func() -> void:
		_choice = {"item": item, "price": price, "selling": selling, "entry": entry}
		_message.text = ""
		refresh()
	)
	return button


func _show() -> void:
	var dim := UITheme.DIM.to_html(false)
	# Forget a choice that is gone (sold, or bought out).
	if not _choice.is_empty():
		var still_there: bool = _choice["item"] in player.inventory.items if _choice["selling"] else _choice["entry"] in npc.stock
		if not still_there:
			_choice = {}
	_action.disabled = _choice.is_empty()
	_action_many.disabled = _choice.is_empty() or (not _choice["selling"] and not _choice["entry"].get("endless", false)) or (_choice["selling"] and _choice["item"].count < 2)
	if _choice.is_empty():
		_details.text = "[color=#%s]Pick something to buy or sell.[/color]" % dim
		return
	var item: Item = _choice["item"]
	_action.text = "Sell" if _choice["selling"] else "Buy"
	_action_many.text = "Sell all" if _choice["selling"] else "Buy 5"
	var lines: PackedStringArray = []
	lines.append("[font_size=20][color=#%s]%s[/color][/font_size]" % [item.color().to_html(false), item.display_name()])
	lines.append("[color=#%s]%s[/color]" % [dim, ItemDB.RARITIES[item.rarity]["name"]])
	lines.append("")
	if item.is_equipment():
		lines.append("[color=#%s]Item level %d  -  %s[/color]" % [dim, item.level, ItemDB.SLOT_NAMES[item.slot()]])
		for modifier in item.all_modifiers():
			lines.append(ItemDB.describe_modifier(modifier))
	else:
		lines.append("[i][color=#%s]%s[/color][/i]" % [dim, item.definition()["text"]])
	lines.append("")
	lines.append("[color=#%s]%s for %d gold[/color]" % [UITheme.GOLD.to_html(false), "Sells" if _choice["selling"] else "Costs", _choice["price"]])
	_details.text = "\n".join(lines)


func _trade(times: int) -> void:
	if _choice.is_empty():
		return
	var item: Item = _choice["item"]
	var inventory := player.inventory
	_message.text = ""
	if _choice["selling"]:
		var amount := item.count if times > 1 else 1
		inventory.add_gold(_choice["price"] * amount)
		Events.codex_event.emit("sales", 1)
		if item.is_stackable():
			inventory.take(item.id, amount)
		else:
			inventory.remove(item)
	else:
		for i in times:
			if inventory.gold < _choice["price"]:
				_message.text = "Not enough gold."
				break
			var bought := Item.create(item.id) if _choice["entry"]["endless"] else item
			if not inventory.has_room_for(bought):
				_message.text = "Inventory is full."
				break
			inventory.add_gold(-_choice["price"])
			inventory.add(bought)
			Events.codex_event.emit("purchases", 1)
			if not _choice["entry"]["endless"]:
				npc.sold(_choice["entry"])
				break
	Audio.play("pickup", -6.0)
	refresh()
