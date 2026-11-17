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
var _sell_junk: Button
## What was sold on this visit, newest first, to buy back at the same
## price: [{"item", "price"}].
var _sold_back: Array = []
var _visiting: Npc
## Standing with merchants: the tier, a bar toward the next, what this
## merchant pays extra for, and the two ways to spend gold here.
var _standing: Label
var _standing_bar: ProgressBar
var _specialty: Label
var _invest: Button
var _reroll: Button
var _wanted: Label


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
	var title_right := HBoxContainer.new()
	title_right.custom_minimum_size.x = 300.0
	title_right.alignment = BoxContainer.ALIGNMENT_END
	title_right.add_theme_constant_override("separation", 8)
	title_row.add_child(title_right)
	_restock = UITheme.label("", 14, UITheme.DIM)
	title_right.add_child(_restock)
	var prices := UITheme.button("Village prices", func() -> void:
		Events.screen_requested.emit("trade_board")
	, 130.0)
	prices.tooltip_text = "What each village you know wants, and has plenty of."
	title_right.add_child(prices)
	_tip = ItemTooltip.new()
	_tip.side_by_side = true
	add_child(_tip)

	# --- standing with merchants, and gold sinks
	var standing_row := HBoxContainer.new()
	standing_row.add_theme_constant_override("separation", 10)
	content.add_child(standing_row)
	_standing = UITheme.strong("", 15, UITheme.GOLD)
	standing_row.add_child(_standing)
	_standing_bar = ProgressBar.new()
	_standing_bar.show_percentage = false
	_standing_bar.custom_minimum_size = Vector2(140.0, 12.0)
	_standing_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_standing_bar.max_value = 1.0
	_standing_bar.step = 0.001
	standing_row.add_child(_standing_bar)
	_specialty = UITheme.label("", 14, UITheme.DIM)
	_specialty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_specialty.clip_text = true
	standing_row.add_child(_specialty)
	_invest = UITheme.button("", func() -> void:
		if player.trade.invest():
			_say("The merchant pockets it with a nod. Your standing grows.", true)
			Audio.play("pickup", -6.0)
		refresh()
	, 190.0)
	standing_row.add_child(_invest)
	_reroll = UITheme.button("", func() -> void:
		if npc.pay_restock(player):
			_choice = {}
			_say("New wares are laid out.", true)
			Audio.play("pickup", -6.0)
		refresh()
	, 200.0)
	standing_row.add_child(_reroll)

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
	ware_scroll.custom_minimum_size = Vector2(318.0, 398.0)
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
	_wanted = UITheme.label("", 13, UITheme.GOOD)
	_wanted.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wanted.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_wanted.clip_text = true
	_wanted.mouse_filter = Control.MOUSE_FILTER_PASS
	sell_head.add_child(_wanted)
	_bag_grid = ItemGrid.new()
	_bag_grid.setup(player, _tip, 7, 7)
	_bag_grid.note_for = func(item: Item) -> String:
		var wanted := TradeDemand.factor(npc.village, item.id) if npc.village != null else 1.0
		var note := "" if wanted == 1.0 else ("  (wanted here: %s)" if wanted > 1.0 else "  (plenty here: %s)") % TradeDemand.percent(wanted)
		return "[color=#%s]Sells for %d gold%s%s[/color]" % [UITheme.GOLD.to_html(false), npc.buys_for(item, player), " each" if item.count > 1 else "", note]
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
		_choose(item, npc.buys_for(item, player), true, {})
		# Shift-click sells the whole stack at once.
		if Input.is_key_pressed(KEY_SHIFT) and not item.locked:
			_quantity = _most()
			_trade()
	)
	_bag_grid.alt_picked.connect(func(item: Item, _index: int) -> void:
		_choose(item, npc.buys_for(item, player), true, {})
		_quantity = 1
		_trade()
	)
	bag_box.add_child(_bag_grid)
	bag_box.add_child(UITheme.label("Right-click sells one; Shift-click sells the stack.", 14, UITheme.DIM))
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
	# Everything marked as junk in the bag (Delete over an item marks it).
	_sell_junk = UITheme.button("Sell junk", _sell_all_junk, 130.0)
	_sell_junk.tooltip_text = "Sells everything marked as junk. Mark items in the bag with %s." % GameSettings.describe("mark_junk").split(" / ")[0]
	bulk.add_child(_sell_junk)

	# --- the chosen thing, and the deal
	var right_panel := UITheme.inset_panel()
	columns.add_child(right_panel)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right_panel.add_child(right)
	_inspector = ItemInspector.new()
	_inspector.build(320.0, 130.0)
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
	_restock.text = "New in %d min" % ceili(npc.restock_in() / 60.0)
	_show_standing()
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
	if npc.village != null:
		var demand := TradeDemand.of(npc.village)
		var wants: PackedStringArray = []
		var lines: PackedStringArray = []
		for id: String in demand["wants"]:
			wants.append(ItemDB.ITEMS[id]["name"])
			lines.append("Wanted: %s %s" % [ItemDB.ITEMS[id]["name"], TradeDemand.percent(TradeDemand.factor(npc.village, id))])
		for id: String in demand["plenty"]:
			lines.append("Plenty: %s %s" % [ItemDB.ITEMS[id]["name"], TradeDemand.percent(demand["plenty"][id])])
		_wanted.text = "Wanted: " + ", ".join(wants)
		_wanted.tooltip_text = "\n".join(lines)
	else:
		_wanted.text = ""
	_bag_grid.selected = _choice["item"] if not _choice.is_empty() and _choice["selling"] else null
	_bag_grid.marked = _bag_grid.marked.filter(func(item: Item) -> bool: return item in player.inventory.items)
	_bag_grid.set_items(player.inventory.items, player.inventory.capacity())
	_pick_toggle.text = "Done" if _picking else "Select many"
	var total := 0
	for item: Item in _bag_grid.marked:
		total += npc.buys_for(item, player) * item.count
	var junk := player.inventory.junk_items()
	var junk_total := 0
	for item: Item in junk:
		junk_total += npc.buys_for(item, player) * item.count
	_sell_junk.disabled = junk.is_empty()
	_sell_junk.text = "Sell junk (%d)  %d g" % [junk.size(), junk_total] if not junk.is_empty() else "Sell junk"
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
	picture.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
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
	button.pressed.connect(func() -> void:
		_choose(item, price, false, entry)
		# Shift-click buys as many as you can carry and pay for.
		if Input.is_key_pressed(KEY_SHIFT):
			_quantity = _most()
			_trade()
	)
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


func _show_standing() -> void:
	var trade := player.trade
	var info := trade.tier_info()
	var next := trade.to_next()
	_standing.text = "%s  ·  %s standing" % [info["name"], InventoryMenu._thousands(trade.standing())]
	_standing.tooltip_text = "Gold spent here counts in full, gold earned counts half.\n%s: %d wares, %d%% off, sells at %d%% of worth." % [
		info["name"], int(info["shelf"]), roundi(float(info["discount"]) * 100.0), roundi(float(info["share"]) * 100.0)]
	_standing_bar.value = trade.progress()
	_standing_bar.tooltip_text = ("%s more to become a %s" % [InventoryMenu._thousands(next), Trade.TIERS[trade.tier() + 1]["name"]]) if next > 0 else "The best standing there is."
	var kinds: Array = ["epic or better"] if npc.wandering else Trade.SPECIALTIES.get(npc.stock_kind, [])
	if npc.stock_kind == "smith":
		kinds = ["Arms", "Armour"] + kinds
	_specialty.text = "Pays +%d%% for: %s" % [roundi(Trade.SPECIALTY_BONUS * 100.0), ", ".join(kinds.slice(0, 5))] if not kinds.is_empty() else ""
	var step := trade.invest_step()
	_invest.text = "Put in %s g" % InventoryMenu._thousands(step)
	_invest.disabled = player.inventory.gold < step or next == 0
	_invest.tooltip_text = "Gold given to the shop for standing. It does not come back." if next > 0 else "Your standing cannot rise further."
	var fee := npc.restock_fee(player)
	_reroll.text = "New wares now: %s g" % InventoryMenu._thousands(fee)
	_reroll.disabled = player.inventory.gold < fee
	_reroll.tooltip_text = "Lay out a fresh shelf. The fee doubles each time until the wares change on their own."


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
func _sell_all_junk() -> void:
	_bag_grid.marked.clear()
	for item: Item in player.inventory.junk_items():
		_bag_grid.marked.append(item)
	_sell_all_marked()


func _sell_all_marked() -> void:
	var gold := 0
	var count := 0
	for item: Item in _bag_grid.marked.duplicate():
		if not item in player.inventory.items or item.locked:
			continue
		gold += npc.buys_for(item, player) * item.count
		npc.note_sold(item, item.count)
		count += 1
		_remember(item, item.count, npc.buys_for(item, player))
		player.inventory.remove(item)
	_bag_grid.marked.clear()
	_picking = false
	if count > 0:
		player.inventory.add_gold(gold)
		player.trade.note_earned(gold)
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
		player.trade.note_earned(int(_choice["price"]) * amount)
		npc.note_sold(item, amount)
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
		player.trade.note_earned(-int(_choice["price"]))
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
			player.trade.note_spent(int(_choice["price"]))
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
