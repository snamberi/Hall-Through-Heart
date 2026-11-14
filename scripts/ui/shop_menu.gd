class_name ShopMenu
extends GameMenu
## Trading with a merchant. Buying is on the left (their wares as cards, and
## anything just sold to them, to buy back); selling is in the middle (your
## bag); the chosen thing is on the right, marked as bought or sold, with
## how many, what it comes to, and what gold you will have afterwards.

var npc: Npc

var _gold: Label
var _restock: Label
var _wares: VBoxContainer
var _bag_grid: ItemGrid
var _bag_title: Label
var _inspector: ItemInspector
var _deal: Label
var _amount: Label
var _less: Button
var _more: Button
var _all: Button
var _action: Button
var _message: Label
var _tip: ItemTooltip
## The selected line: {"item", "price", "selling": bool, "entry": stock entry or {}, "back": bool}.
var _choice: Dictionary = {}
var _quantity := 1
## Marking many things in the bag to sell together.
var _picking := false
var _pick_toggle: Button
var _sell_marked: Button
## What was sold on this visit, newest first, to buy back at the same
## price: [{"item", "price"}].
var _sold_back: Array = []
var _visiting: Npc


func _build() -> void:
	content.add_theme_constant_override("separation", 10)
	var title_row := HBoxContainer.new()
	content.add_child(title_row)
	var purse := HBoxContainer.new()
	purse.add_theme_constant_override("separation", 8)
	purse.custom_minimum_size.x = 300.0
	title_row.add_child(purse)
	purse.add_child(UITheme.icon(ItemDB.GOLD_ICON, 26.0))
	_gold = UITheme.strong("", 18, UITheme.GOLD)
	purse.add_child(_gold)
	var title := UITheme.heading("MERCHANT", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	_restock = UITheme.label("", 14, UITheme.DIM)
	_restock.custom_minimum_size.x = 300.0
	_restock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title_row.add_child(_restock)
	_tip = ItemTooltip.new()
	add_child(_tip)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	content.add_child(columns)

	# --- buying: the merchant's wares
	var ware_panel := UITheme.inset_panel()
	columns.add_child(ware_panel)
	var ware_box := VBoxContainer.new()
	ware_box.add_theme_constant_override("separation", 8)
	ware_panel.add_child(ware_box)
	var buy_head := HBoxContainer.new()
	buy_head.add_theme_constant_override("separation", 8)
	ware_box.add_child(buy_head)
	buy_head.add_child(UITheme.badge("BUY", "good"))
	buy_head.add_child(UITheme.heading("The merchant's wares", 16))
	var ware_scroll := ScrollContainer.new()
	ware_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ware_scroll.custom_minimum_size = Vector2(318.0, 430.0)
	ware_box.add_child(ware_scroll)
	_wares = VBoxContainer.new()
	_wares.add_theme_constant_override("separation", 6)
	_wares.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ware_scroll.add_child(_wares)

	# --- selling: the bag
	var bag_panel := UITheme.inset_panel()
	columns.add_child(bag_panel)
	var bag_box := VBoxContainer.new()
	bag_box.add_theme_constant_override("separation", 8)
	bag_panel.add_child(bag_box)
	var sell_head := HBoxContainer.new()
	sell_head.add_theme_constant_override("separation", 8)
	bag_box.add_child(sell_head)
	sell_head.add_child(UITheme.badge("SELL", "gold"))
	_bag_title = UITheme.heading("", 16)
	sell_head.add_child(_bag_title)
	_bag_grid = ItemGrid.new()
	_bag_grid.setup(player, _tip, 7, 7)
	_bag_grid.note_for = func(item: Item) -> String:
		return "[color=#%s]Sells for %d gold%s[/color]" % [UITheme.GOLD.to_html(false), Npc.sell_price(item), " each" if item.count > 1 else ""]
	_bag_grid.picked.connect(func(item: Item, _index: int) -> void:
		if _picking:
			if item.locked:
				_say("%s is locked. Unlock it in the inventory to sell it." % item.display_name(), false)
			elif item in _bag_grid.marked:
				_bag_grid.marked.erase(item)
			else:
				_bag_grid.marked.append(item)
			refresh()
			return
		_choose(item, Npc.sell_price(item), true, {})
	)
	_bag_grid.alt_picked.connect(func(item: Item, _index: int) -> void:
		_choose(item, Npc.sell_price(item), true, {})
		_quantity = 1
		_trade()
	)
	bag_box.add_child(_bag_grid)
	bag_box.add_child(UITheme.label("Things sell for a quarter of their worth. Right-click sells one.", 14, UITheme.DIM))
	var bulk := HBoxContainer.new()
	bulk.add_theme_constant_override("separation", 4)
	bag_box.add_child(bulk)
	_pick_toggle = UITheme.button("Select many", func() -> void:
		_picking = not _picking
		if not _picking:
			_bag_grid.marked.clear()
		refresh()
	, 108.0)
	bulk.add_child(_pick_toggle)
	var common := UITheme.button("Mark common", func() -> void:
		_picking = true
		for item: Item in player.inventory.items:
			if item.is_equipment() and item.rarity == 0 and not item.is_unique() and item.set_id == "" and not item.locked and not item in _bag_grid.marked:
				_bag_grid.marked.append(item)
		refresh()
	, 112.0)
	common.tooltip_text = "Marks every common piece of gear that is not locked."
	bulk.add_child(common)
	_sell_marked = UITheme.button("Sell marked", _sell_all_marked, 150.0)
	_sell_marked.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bulk.add_child(_sell_marked)

	# --- the chosen thing, and the deal
	var right_panel := UITheme.inset_panel()
	columns.add_child(right_panel)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right_panel.add_child(right)
	_inspector = ItemInspector.new()
	_inspector.build(320.0, 150.0)
	_inspector.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_inspector)
	right.add_child(UITheme.rule())
	# How many, with what it comes to and what is left.
	var amount_row := HBoxContainer.new()
	amount_row.add_theme_constant_override("separation", 6)
	right.add_child(amount_row)
	amount_row.add_child(UITheme.label("Quantity", 14, UITheme.DIM))
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	amount_row.add_child(fill)
	_less = UITheme.button("−", func() -> void: _set_quantity(_quantity - 1), 36.0)
	amount_row.add_child(_less)
	_amount = UITheme.strong("1", 18)
	_amount.custom_minimum_size.x = 44.0
	_amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amount_row.add_child(_amount)
	_more = UITheme.button("+", func() -> void: _set_quantity(_quantity + 1), 36.0)
	amount_row.add_child(_more)
	_all = UITheme.button("Max", func() -> void: _set_quantity(_most()), 56.0)
	amount_row.add_child(_all)
	_deal = UITheme.label("", 14)
	_deal.custom_minimum_size = Vector2(320.0, 40.0)
	right.add_child(_deal)
	_message = UITheme.reason("", 320.0)
	_message.custom_minimum_size.y = 20.0
	right.add_child(_message)
	_action = UITheme.primary_button("Buy", _trade, 320.0)
	right.add_child(_action)
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree():
			_tip.hide_tip()
	)
	player.inventory.changed.connect(refresh_if_open)


func refresh() -> void:
	if npc == null or not is_instance_valid(npc):
		return
	npc.restock_if_due(player)
	if npc != _visiting:
		# A new visit: nothing to buy back, nothing chosen yet.
		_visiting = npc
		_sold_back.clear()
		_choice = {}
		_picking = false
		_bag_grid.marked.clear()
	_gold.text = "%s gold" % InventoryMenu._thousands(player.inventory.gold)
	_restock.text = "New wares in %d min" % ceili(npc.restock_in() / 60.0)
	for child in _wares.get_children():
		child.queue_free()
	for entry in npc.stock:
		_wares.add_child(_card(entry))
	if npc.stock.is_empty():
		_wares.add_child(UITheme.label("Sold out. Come back when the wares change.", 14, UITheme.DIM))
	if not _sold_back.is_empty():
		_wares.add_child(UITheme.heading("Buy back", 15))
		for sold: Dictionary in _sold_back:
			_wares.add_child(_card({"item": sold["item"], "price": sold["price"], "endless": false, "back": true}))
	# Open on something worth looking at: the first ware that can be afforded.
	if _choice.is_empty() and not npc.stock.is_empty():
		var first: Dictionary = npc.stock[0]
		for entry in npc.stock:
			if player.inventory.gold >= int(entry["price"]):
				first = entry
				break
		_choice = {"item": first["item"], "price": first["price"], "selling": false, "entry": first, "back": false}
		_quantity = 1
	_bag_title.text = "Your bag   %d / %d" % [player.inventory.items.size(), player.inventory.capacity()]
	_bag_grid.selected = _choice["item"] if not _choice.is_empty() and _choice["selling"] else null
	_bag_grid.marked = _bag_grid.marked.filter(func(item: Item) -> bool: return item in player.inventory.items)
	_bag_grid.set_items(player.inventory.items, player.inventory.capacity())
	_pick_toggle.text = "Done" if _picking else "Select many"
	var total := 0
	for item: Item in _bag_grid.marked:
		total += Npc.sell_price(item) * item.count
	_sell_marked.disabled = _bag_grid.marked.is_empty()
	_sell_marked.text = "Sell %d for %d gold" % [_bag_grid.marked.size(), total] if not _bag_grid.marked.is_empty() else "Sell marked"
	_show()


## One of the merchant's wares: its picture, name, what it is, and its price.
func _card(entry: Dictionary) -> Button:
	var item: Item = entry["item"]
	var price: int = entry["price"]
	var chosen: bool = not _choice.is_empty() and not _choice["selling"] and _choice["item"] == item
	var button := Button.new()
	button.custom_minimum_size = Vector2(300.0, 64.0)
	var style := UITheme.card("card_selected" if chosen else "card")
	var hover := UITheme.card("card_selected" if chosen else "card_hover")
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
	var kind := "%s  ·  level %d" % [ItemDB.RARITIES[item.rarity]["name"], item.level] if item.is_equipment() else ("Always in stock" if entry["endless"] else "Only one")
	if entry.get("back", false):
		kind = "You sold this" + ("  ·  x%d" % item.count if item.count > 1 else "")
	var kind_label := UITheme.label(kind, 14, UITheme.DIM)
	kind_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(kind_label)
	var affordable := player.inventory.gold >= price
	var cost := UITheme.strong("%d g" % price, 16, UITheme.GOLD if affordable else UITheme.BAD)
	cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(cost)
	button.pressed.connect(func() -> void: _choose(item, price, false, entry))
	button.gui_input.connect(func(event: InputEvent) -> void:
		var click := event as InputEventMouseButton
		if click and click.pressed and click.button_index == MOUSE_BUTTON_RIGHT:
			_choose(item, price, false, entry)
			_quantity = 1
			_trade()
	)
	button.mouse_entered.connect(func() -> void: _tip.show_item(item, player, "[color=#%s]Costs %d gold[/color]" % [UITheme.GOLD.to_html(false), price]))
	button.mouse_exited.connect(func() -> void: _tip.hide_tip())
	UITheme.sounds(button)
	return button


func _choose(item: Item, price: int, selling: bool, entry: Dictionary) -> void:
	_choice = {"item": item, "price": price, "selling": selling, "entry": entry, "back": entry.get("back", false)}
	_quantity = 1
	_message.text = ""
	refresh()


func _say(text: String, good: bool) -> void:
	_message.text = text
	_message.add_theme_color_override("font_color", UITheme.GOOD if good else Color("e8a070"))


## The most that can be traded of the chosen thing at once.
func _most() -> int:
	if _choice.is_empty():
		return 1
	var item: Item = _choice["item"]
	if _choice["selling"]:
		return maxi(item.count, 1)
	if not _choice["entry"].get("endless", false):
		return 1
	return clampi(player.inventory.gold / maxi(int(_choice["price"]), 1), 1, 99)


func _set_quantity(value: int) -> void:
	_quantity = clampi(value, 1, _most())
	_show()


func _show() -> void:
	# Forget a choice that is gone (sold, or bought out).
	if not _choice.is_empty():
		var still_there: bool = _choice["item"] in player.inventory.items if _choice["selling"] else (
			_sold_back.any(func(sold: Dictionary) -> bool: return sold["item"] == _choice["item"]) if _choice["back"] else _choice["entry"] in npc.stock)
		if not still_there:
			_choice = {}
	_action.disabled = _choice.is_empty()
	for control: Button in [_less, _more, _all]:
		control.disabled = _choice.is_empty() or _most() <= 1
	if _choice.is_empty():
		_inspector.show_item(null, player, [], "Nothing chosen", "Pick one of the merchant's wares to buy it, or something in your bag to sell it.")
		_amount.text = "-"
		_deal.text = ""
		_action.text = "Buy or sell"
		_action.tooltip_text = "Choose something first."
		return
	var item: Item = _choice["item"]
	var selling: bool = _choice["selling"]
	_quantity = clampi(_quantity, 1, _most())
	_amount.text = str(_quantity)
	var badges: Array = [["Selling from your bag", "gold"]] if selling else [["Buying back" if _choice["back"] else "Buying", "good"]]
	_inspector.show_item(item, player, badges)
	# A buy-back returns the whole stack that was sold, at what was paid.
	var total: int = int(_choice["price"]) * _quantity
	var gold := player.inventory.gold
	var after := gold + total if selling else gold - total
	_deal.text = "%s %d:  %s gold\nYou have %s  →  %s after" % ["Sell" if selling else "Buy", _quantity, InventoryMenu._thousands(total),
		InventoryMenu._thousands(gold), InventoryMenu._thousands(after)]
	_deal.add_theme_color_override("font_color", UITheme.BAD if after < 0 else UITheme.TEXT)
	_action.text = "%s %s for %s gold" % ["Sell" if selling else "Buy", "it" if _quantity == 1 else str(_quantity), InventoryMenu._thousands(total)]
	# Say why a deal cannot be done, beside the button that would do it.
	var problem := ""
	if selling and item.locked:
		problem = "Locked. Unlock it in the inventory to sell it."
	elif not selling and after < 0:
		problem = "Not enough gold: %s short." % InventoryMenu._thousands(-after)
	elif not selling and not player.inventory.has_room_for(item):
		problem = "Your bag is full."
	_action.disabled = problem != ""
	_action.tooltip_text = problem
	if problem != "":
		_say(problem, false)
	elif _message.text.begins_with("Not enough") or _message.text.begins_with("Locked") or _message.text.begins_with("Your bag"):
		_message.text = ""


## Remembers something sold, so a mistake can be bought back this visit.
func _remember(item: Item, amount: int, price_each: int) -> void:
	var copy := Item.from_dict(item.to_dict())
	if copy == null:
		return
	copy.count = amount
	_sold_back.push_front({"item": copy, "price": price_each * amount})
	while _sold_back.size() > 6:
		_sold_back.pop_back()


## Sells every marked stack at once.
func _sell_all_marked() -> void:
	var gold := 0
	var count := 0
	for item: Item in _bag_grid.marked.duplicate():
		if not item in player.inventory.items or item.locked:
			continue
		gold += Npc.sell_price(item) * item.count
		count += 1
		_remember(item, item.count, Npc.sell_price(item))
		player.inventory.remove(item)
	_bag_grid.marked.clear()
	_picking = false
	if count > 0:
		player.inventory.add_gold(gold)
		Events.codex_event.emit("sales", count)
		Audio.play("pickup", -6.0)
		_say("Sold %d for %d gold. They can be bought back until you leave." % [count, gold], true)
	refresh()


func _trade() -> void:
	if _choice.is_empty():
		return
	var item: Item = _choice["item"]
	var inventory := player.inventory
	_message.text = ""
	if _choice["selling"]:
		if item.locked:
			_say("Locked. Unlock it in the inventory to sell it.", false)
			return
		var amount := clampi(_quantity, 1, item.count)
		inventory.add_gold(int(_choice["price"]) * amount)
		Events.codex_event.emit("sales", 1)
		_remember(item, amount, int(_choice["price"]))
		if item.is_stackable():
			inventory.take(item.id, amount)
		else:
			inventory.remove(item)
		_say("Sold for %d gold." % (int(_choice["price"]) * amount), true)
	elif _choice["back"]:
		if inventory.gold < int(_choice["price"]):
			_say("Not enough gold.", false)
			return
		if not inventory.has_room_for(item):
			_say("Your bag is full.", false)
			return
		inventory.add_gold(-int(_choice["price"]))
		inventory.add(item)
		_sold_back = _sold_back.filter(func(sold: Dictionary) -> bool: return sold["item"] != item)
		_say("Bought back.", true)
	else:
		var bought_count := 0
		for i in _quantity:
			if inventory.gold < int(_choice["price"]):
				_say("Not enough gold.", false)
				break
			var bought := Item.create(item.id) if _choice["entry"]["endless"] else item
			if not inventory.has_room_for(bought):
				_say("Your bag is full.", false)
				break
			inventory.add_gold(-int(_choice["price"]))
			inventory.add(bought)
			bought_count += 1
			Events.codex_event.emit("purchases", 1)
			if not _choice["entry"]["endless"]:
				npc.sold(_choice["entry"])
				break
		if bought_count > 0 and _message.text == "":
			_say("Bought %s." % ("it" if bought_count == 1 else str(bought_count)), true)
	Audio.play("pickup", -6.0)
	refresh()
