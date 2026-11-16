class_name RuneMenu
extends GameMenu
## Rune binding. Left: your gear (worn first, then the bag), each with the
## runeword it holds. Middle: the chosen piece, three rune places to fill
## from the bag, the runeword those runes make (or that they do not bind),
## what it costs, and Bind. Right: the book of runewords, each with its
## runes and what it gives at the chosen piece's level; picking one lays
## its runes if you hold them.

const LIST_WIDTH := 330.0
const MIDDLE_WIDTH := 370.0
const BOOK_WIDTH := 410.0

var _piece: Item
var _runes: Array = ["", "", ""]
var _list: VBoxContainer
var _middle: VBoxContainer
var _book: VBoxContainer
var _message: Label


func _build() -> void:
	content.add_theme_constant_override("separation", 10)
	var title := UITheme.heading("RUNE BINDING", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 12)
	content.add_child(columns)
	_list = _column(columns, LIST_WIDTH, true)
	_middle = _column(columns, MIDDLE_WIDTH, false)
	_book = _column(columns, BOOK_WIDTH, true)
	_message = UITheme.reason("", 0.0)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_message)
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree():
			_message.text = ""
	)


func _column(parent: Control, width: float, scrolls: bool) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.card("card", 10))
	panel.custom_minimum_size = Vector2(width, 460)
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if scrolls:
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		panel.add_child(scroll)
		scroll.add_child(box)
	else:
		panel.add_child(box)
	return box


func _icon(item: Item, side: float = 32.0) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = item.icon()
	icon.modulate = item.icon_tint()
	icon.custom_minimum_size = Vector2(side, side)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


## Gear that can hold a runeword: worn pieces, then the bag's.
func _gear() -> Array[Item]:
	var result: Array[Item] = []
	for slot: String in player.equipment.equipped:
		var item: Item = player.equipment.equipped[slot]
		if item and item.is_equipment() and not item in result:
			result.append(item)
	for item: Item in player.inventory.items:
		if item and item.is_equipment() and not item in result:
			result.append(item)
	return result


func refresh() -> void:
	for child in _list.get_children() + _middle.get_children() + _book.get_children():
		child.queue_free()
	var gear := _gear()
	if _piece == null or not _piece in gear:
		_piece = gear[0] if not gear.is_empty() else null
	_list.add_child(UITheme.heading("Your gear", 18))
	for item in gear:
		_list.add_child(_gear_row(item))
	if gear.is_empty():
		_list.add_child(UITheme.label("No weapons or armour.", 14, UITheme.DIM))
	_fill_middle()
	_fill_book()


func _gear_row(item: Item) -> Button:
	var chosen := item == _piece
	var button := Button.new()
	button.custom_minimum_size = Vector2(LIST_WIDTH - 34.0, 46.0)
	for state: String in ["normal", "pressed"]:
		button.add_theme_stylebox_override(state, UITheme.card("card_selected" if chosen else "card", 4))
	button.add_theme_stylebox_override("hover", UITheme.card("card_selected" if chosen else "card_hover", 4))
	button.pressed.connect(func() -> void:
		_piece = item
		refresh()
	)
	UITheme.sounds(button)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 4)
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(row)
	row.add_child(_icon(item))
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", -3)
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(words)
	var name_label := UITheme.strong(item.display_name(), 14, item.color())
	name_label.clip_text = true
	name_label.custom_minimum_size.x = LIST_WIDTH - 90.0
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(name_label)
	var held: String = Runes.WORDS[item.runeword]["name"] if item.runeword != "" else "no runeword"
	var worn := "worn  ·  " if player.equipment.slot_of(item) != "" else ""
	var line := UITheme.label("%slevel %d  ·  %s" % [worn, item.level, held], 12, Color("ffb070") if item.runeword != "" else UITheme.DIM)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(line)
	return button


func _fill_middle() -> void:
	if _piece == null:
		_middle.add_child(UITheme.paragraph("Choose a weapon or a piece of armour to bind runes into.", MIDDLE_WIDTH - 30.0, 15, UITheme.DIM))
		return
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	_middle.add_child(top)
	top.add_child(_icon(_piece, 48.0))
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", -2)
	top.add_child(words)
	var name_label := UITheme.strong(_piece.display_name(), 17, _piece.color())
	name_label.clip_text = true
	name_label.custom_minimum_size.x = MIDDLE_WIDTH - 90.0
	words.add_child(name_label)
	words.add_child(UITheme.label("Level %d  ·  %s" % [_piece.level, ItemText.type_name(_piece)], 14, UITheme.DIM))
	if _piece.runeword != "":
		_middle.add_child(UITheme.paragraph("Holds %s: %s. Binding new runes replaces it." % [Runes.WORDS[_piece.runeword]["name"], Runes.describe(_piece.runeword, _piece.level)], MIDDLE_WIDTH - 30.0, 13, Color("ffb070")))
	_middle.add_child(UITheme.rule())
	_middle.add_child(UITheme.label("Lay two or three runes", 15, UITheme.HEADING))
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 10)
	slots.alignment = BoxContainer.ALIGNMENT_CENTER
	_middle.add_child(slots)
	for index in 3:
		slots.add_child(_rune_slot(index))
	var laid := _runes.filter(func(rune: String) -> bool: return rune != "")
	var word := Runes.word_for(laid)
	if laid.size() >= 2:
		if word != "":
			_middle.add_child(UITheme.strong(Runes.WORDS[word]["name"], 20, Color("ffb070")))
			_middle.add_child(UITheme.paragraph(Runes.describe(word, _piece.level), MIDDLE_WIDTH - 30.0, 15, UITheme.GOOD))
		else:
			_middle.add_child(UITheme.label("These runes do not bind together.", 15, UITheme.BAD))
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_middle.add_child(fill)
	var price := Runes.cost(_piece, laid)
	_middle.add_child(UITheme.label("Costs %d Rift Shard%s and %s gold  ·  you hold %d shards" % [price["shards"], "" if price["shards"] == 1 else "s",
		InventoryMenu._thousands(price["gold"]), player.inventory.count_of("rift_shard")], 13, UITheme.DIM))
	var problem := Runes.problem(player, _piece, laid)
	var bind := UITheme.primary_button("Bind the runes" if problem == "" else problem, func() -> void:
		var result := Runes.bind(player, _piece, laid)
		if result == "":
			_message.text = "%s is bound into %s." % [Runes.WORDS[_piece.runeword]["name"], _piece.display_name()]
			_runes = ["", "", ""]
			Audio.play("level_up", -8.0)
		else:
			_message.text = result
		refresh()
	, MIDDLE_WIDTH - 30.0)
	bind.disabled = problem != ""
	bind.clip_text = true
	_middle.add_child(bind)


## A rune place: the rune laid there, or empty. Click to choose a rune from
## the bag; right-click to clear it.
func _rune_slot(index: int) -> Button:
	var rune: String = _runes[index]
	var button := Button.new()
	button.custom_minimum_size = Vector2(64, 64)
	button.add_theme_stylebox_override("normal", UITheme.slot("slot_active" if rune != "" else "slot"))
	button.add_theme_stylebox_override("hover", UITheme.slot("slot_hover"))
	button.add_theme_stylebox_override("pressed", UITheme.slot("slot_hover"))
	button.tooltip_text = (Runes.RUNES[rune]["name"] + " rune. Right-click to clear.") if rune != "" else "Choose a rune from your bag."
	if rune != "":
		var icon := _icon(Item.create(rune), 44.0)
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 10.0
		icon.offset_top = 10.0
		icon.offset_right = -10.0
		icon.offset_bottom = -10.0
		button.add_child(icon)
	button.pressed.connect(func() -> void: _pick_rune(index))
	button.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			_runes[index] = ""
			refresh()
	)
	UITheme.sounds(button)
	return button


func _pick_rune(index: int) -> void:
	var menu := PopupMenu.new()
	var ids: Array = []
	for rune: String in Runes.RUNES:
		var have := player.inventory.count_of(rune)
		if have <= 0:
			continue
		menu.add_icon_item(Item.create(rune).icon(), "%s Rune  (%d)" % [Runes.RUNES[rune]["name"], have], ids.size())
		ids.append(rune)
	if ids.is_empty():
		_message.text = "You hold no runes. Elites, bosses and Heart Rifts give them."
		return
	menu.id_pressed.connect(func(id: int) -> void:
		_runes[index] = ids[id]
		refresh()
	)
	menu.popup_hide.connect(menu.queue_free)
	add_child(menu)
	menu.popup(Rect2i(Vector2i(get_global_mouse_position()), Vector2i.ZERO))


func _fill_book() -> void:
	_book.add_child(UITheme.heading("Runewords", 18))
	var level := _piece.level if _piece else player.leveling.level
	for word: String in Runes.WORDS:
		var data: Dictionary = Runes.WORDS[word]
		var button := Button.new()
		button.custom_minimum_size = Vector2(BOOK_WIDTH - 34.0, 54.0)
		for state: String in ["normal", "pressed"]:
			button.add_theme_stylebox_override(state, UITheme.card("card", 4))
		button.add_theme_stylebox_override("hover", UITheme.card("card_hover", 4))
		button.tooltip_text = "Lay these runes"
		button.pressed.connect(func() -> void:
			_runes = ["", "", ""]
			for index in (data["runes"] as Array).size():
				_runes[index] = data["runes"][index]
			refresh()
		)
		UITheme.sounds(button)
		var row := HBoxContainer.new()
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 4)
		row.add_theme_constant_override("separation", 2)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(row)
		var marks := HBoxContainer.new()
		marks.add_theme_constant_override("separation", 0)
		marks.custom_minimum_size.x = 66.0
		marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(marks)
		for rune: String in data["runes"]:
			var icon := _icon(Item.create(rune), 22.0)
			icon.modulate.a = 1.0 if player.inventory.count_of(rune) > 0 else 0.4
			marks.add_child(icon)
		var words := VBoxContainer.new()
		words.add_theme_constant_override("separation", -3)
		words.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(words)
		var name_label := UITheme.strong(data["name"], 15, Color("ffb070"))
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		words.add_child(name_label)
		var text := UITheme.label(Runes.describe(word, level), 12, UITheme.DIM)
		text.clip_text = true
		text.custom_minimum_size.x = BOOK_WIDTH - 110.0
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		words.add_child(text)
		_book.add_child(button)
