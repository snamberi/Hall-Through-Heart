class_name ShopMenu
extends GameMenu
## Trading with a merchant: their five wares laid out as cards on the left,
## your bag as a grid in the middle, and the chosen thing on the right.

var npc: Npc

var _gold: Label
var _restock: Label
var _wares: VBoxContainer
var _bag_grid: ItemGrid
var _bag_title: Label
var _icon: TextureRect
var _icon_frame: PanelContainer
var _details: RichTextLabel
var _action: Button
var _action_many: Button
var _message: Label
var _tip: ItemTooltip
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
	_tip = ItemTooltip.new()
	add_child(_tip)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	content.add_child(columns)

	# --- the merchant's wares
	var ware_panel := UITheme.inset_panel()
	columns.add_child(ware_panel)
	var ware_box := VBoxContainer.new()
	ware_box.add_theme_constant_override("separation", 8)
	ware_panel.add_child(ware_box)
	ware_box.add_child(UITheme.heading("For sale", 16))
	_wares = VBoxContainer.new()
	_wares.add_theme_constant_override("separation", 6)
	_wares.custom_minimum_size = Vector2(300.0, 380.0)
	ware_box.add_child(_wares)

	# --- the bag
	var bag_panel := UITheme.inset_panel()
	columns.add_child(bag_panel)
	var bag_box := VBoxContainer.new()
	bag_box.add_theme_constant_override("separation", 8)
	bag_panel.add_child(bag_box)
	_bag_title = UITheme.heading("", 16)
	bag_box.add_child(_bag_title)
	_bag_grid = ItemGrid.new()
	_bag_grid.setup(player, _tip, 7, 7)
	_bag_grid.note_for = func(item: Item) -> String:
		return "[color=#%s]Sells for %d gold%s[/color]" % [UITheme.GOLD.to_html(false), Npc.sell_price(item), " each" if item.count > 1 else ""]
	_bag_grid.picked.connect(func(item: Item, _index: int) -> void: _choose(item, Npc.sell_price(item), true, {}))
	_bag_grid.alt_picked.connect(func(item: Item, _index: int) -> void:
		_choose(item, Npc.sell_price(item), true, {})
		_trade(1)
	)
	bag_box.add_child(_bag_grid)
	bag_box.add_child(UITheme.label("Sells for a quarter of its worth. Right-click to sell one at once.", 12, UITheme.DIM))

	# --- the chosen thing
	var right_panel := UITheme.inset_panel()
	columns.add_child(right_panel)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right_panel.add_child(right)
	_icon_frame = PanelContainer.new()
	_icon_frame.custom_minimum_size = Vector2(72.0, 72.0)
	_icon_frame.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	right.add_child(_icon_frame)
	_icon = UITheme.icon(0, 56.0)
	_icon_frame.add_child(_icon)
	_details = RichTextLabel.new()
	_details.bbcode_enabled = true
	_details.fit_content = false
	_details.scroll_active = true
	_details.custom_minimum_size = Vector2(280.0, 250.0)
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
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree():
			_tip.hide_tip()
	)
	player.inventory.changed.connect(refresh_if_open)


func refresh() -> void:
	if npc == null or not is_instance_valid(npc):
		return
	npc.restock_if_due(player)
	_gold.text = "%d gold" % player.inventory.gold
	_restock.text = "      New wares in %d min" % ceili(npc.restock_in() / 60.0)
	for child in _wares.get_children():
		child.queue_free()
	for entry in npc.stock:
		_wares.add_child(_card(entry))
	if npc.stock.is_empty():
		_wares.add_child(UITheme.label("Sold out. Come back when the wares change.", 14, UITheme.DIM))
	_bag_title.text = "Your bag   %d / %d" % [player.inventory.items.size(), player.inventory.capacity()]
	_bag_grid.selected = _choice["item"] if not _choice.is_empty() and _choice["selling"] else null
	_bag_grid.set_items(player.inventory.items, player.inventory.capacity())
	_show()


## One of the merchant's wares: its picture, name, what it is, and its price.
func _card(entry: Dictionary) -> Button:
	var item: Item = entry["item"]
	var price: int = entry["price"]
	var chosen: bool = not _choice.is_empty() and not _choice["selling"] and _choice["entry"] == entry
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(300.0, 68.0)
	var style := ItemGrid.frame_style(item, chosen)
	var hover := style.duplicate()
	hover.bg_color = style.bg_color.lightened(0.08)
	for state: String in ["normal", "pressed"]:
		button.add_theme_stylebox_override(state, style)
	button.add_theme_stylebox_override("hover", hover)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(row)
	var picture := TextureRect.new()
	picture.texture = item.icon()
	picture.modulate = item.icon_tint()
	picture.custom_minimum_size = Vector2(48.0, 48.0)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(picture)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(words)
	var name_label := UITheme.label(item.display_name(), 15, item.color())
	name_label.clip_text = true
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(name_label)
	var kind := "%s, item level %d" % [ItemDB.RARITIES[item.rarity]["name"], item.level] if item.is_equipment() else ("Always in stock" if entry["endless"] else "Only one")
	var kind_label := UITheme.label(kind, 12, UITheme.DIM)
	kind_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(kind_label)
	var affordable := player.inventory.gold >= price
	var cost := UITheme.label("%d g" % price, 16, UITheme.GOLD if affordable else UITheme.BAD)
	cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(cost)
	button.pressed.connect(func() -> void: _choose(item, price, false, entry))
	button.mouse_entered.connect(func() -> void: _tip.show_item(item, player, "[color=#%s]Costs %d gold[/color]" % [UITheme.GOLD.to_html(false), price]))
	button.mouse_exited.connect(func() -> void: _tip.hide_tip())
	UITheme.sounds(button)
	return button


func _choose(item: Item, price: int, selling: bool, entry: Dictionary) -> void:
	_choice = {"item": item, "price": price, "selling": selling, "entry": entry}
	_message.text = ""
	refresh()


func _show() -> void:
	var dim := UITheme.DIM.to_html(false)
	# Forget a choice that is gone (sold, or bought out).
	if not _choice.is_empty():
		var still_there: bool = _choice["item"] in player.inventory.items if _choice["selling"] else _choice["entry"] in npc.stock
		if not still_there:
			_choice = {}
	_action.disabled = _choice.is_empty()
	_action_many.disabled = _choice.is_empty() or (not _choice["selling"] and not _choice["entry"].get("endless", false)) or (_choice["selling"] and _choice["item"].count < 2)
	_icon_frame.visible = not _choice.is_empty()
	if _choice.is_empty():
		_details.text = "[color=#%s]Pick something to buy or sell.[/color]" % dim
		return
	var item: Item = _choice["item"]
	_icon.texture = item.icon()
	_icon.modulate = item.icon_tint()
	_icon_frame.add_theme_stylebox_override("panel", ItemGrid.frame_style(item, false))
	_action.text = "Sell" if _choice["selling"] else "Buy"
	_action_many.text = "Sell all" if _choice["selling"] else "Buy 5"
	_details.text = ItemText.describe(item, player) + "\n\n[color=#%s]%s for %d gold[/color]" % [UITheme.GOLD.to_html(false), "Sells" if _choice["selling"] else "Costs", _choice["price"]]


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
