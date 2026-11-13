class_name RelicsMenu
extends GameMenu
## The relic bag: up to 15 relics won from bosses, the ones worn (one, or
## up to three with a good belt), and the one whose power the relic key
## (G) calls on.

const BIG_SLOT := 76.0
const BELT_FOR_SLOT := ["", "Leather Belt", "Reliquary Belt"]

var _tip: ItemTooltip
var _bag: ItemGrid
var _bag_title: Label
var _worn_title: Label
var _belt_line: Label
var _worn_buttons: Array[Button] = []
var _worn_notes: Array[Label] = []
var _details: RichTextLabel
var _wear_button: Button
var _focus_button: Button
var _discard_button: Button
var _message: Label
var _selected: Item
var _confirm_discard := false


func _build() -> void:
	var title := UITheme.heading("RELIC BAG", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var note := UITheme.label("Relics are won from bosses (now and then from Ancients). They have no level: a rarer relic gives stronger boons. Each lends one power, used with G. Wear one; a Leather Belt makes room for two, a Reliquary Belt for three.", 14, UITheme.DIM)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD
	note.custom_minimum_size = Vector2(960, 40)
	content.add_child(note)
	_tip = ItemTooltip.new()
	add_child(_tip)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	columns.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(columns)

	# Worn relics, one above the other, with the belt that unlocks them.
	var worn_panel := UITheme.inset_panel()
	worn_panel.custom_minimum_size = Vector2(250, 420)
	columns.add_child(worn_panel)
	var worn_box := VBoxContainer.new()
	worn_box.add_theme_constant_override("separation", 10)
	worn_panel.add_child(worn_box)
	_worn_title = UITheme.heading("Worn", 18)
	worn_box.add_child(_worn_title)
	for index in 3:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		worn_box.add_child(row)
		var button := Button.new()
		button.custom_minimum_size = Vector2(BIG_SLOT, BIG_SLOT)
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		button.pressed.connect(_on_worn_pressed.bind(index))
		button.gui_input.connect(_on_worn_input.bind(index))
		button.mouse_entered.connect(_on_worn_hover.bind(index))
		button.mouse_exited.connect(func() -> void: _tip.hide_tip())
		row.add_child(button)
		_worn_buttons.append(button)
		var label := UITheme.label("", 13, UITheme.DIM)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		label.custom_minimum_size = Vector2(140, 0)
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(label)
		_worn_notes.append(label)
	_belt_line = UITheme.label("", 13, UITheme.DIM)
	_belt_line.autowrap_mode = TextServer.AUTOWRAP_WORD
	_belt_line.custom_minimum_size = Vector2(220, 0)
	worn_box.add_child(_belt_line)

	# The bag.
	var bag_panel := UITheme.inset_panel()
	columns.add_child(bag_panel)
	var bag_box := VBoxContainer.new()
	bag_box.add_theme_constant_override("separation", 8)
	bag_panel.add_child(bag_box)
	_bag_title = UITheme.heading("Bag", 18)
	bag_box.add_child(_bag_title)
	_bag = ItemGrid.new()
	_bag.setup(player, _tip, 5, 3)
	_bag.custom_minimum_size.y += 6.0
	_bag.note_for = func(_item: Item) -> String: return "[color=#%s]Click to choose, right-click to wear[/color]" % UITheme.GOOD.to_html(false)
	_bag.picked.connect(func(item: Item, _index: int) -> void: _select(item))
	_bag.alt_picked.connect(func(item: Item, _index: int) -> void:
		_select(item)
		_wear_or_remove()
	)
	bag_box.add_child(_bag)
	var hint := UITheme.label("Found relics go here, not into your bag.\nA relic picked up while this is full\nstays in your bag until there is room.", 12, UITheme.DIM)
	bag_box.add_child(hint)

	# The chosen relic.
	var detail_panel := UITheme.inset_panel()
	detail_panel.custom_minimum_size = Vector2(360, 420)
	columns.add_child(detail_panel)
	var detail_box := VBoxContainer.new()
	detail_box.add_theme_constant_override("separation", 8)
	detail_panel.add_child(detail_box)
	_details = RichTextLabel.new()
	_details.bbcode_enabled = true
	_details.fit_content = false
	_details.scroll_active = true
	_details.custom_minimum_size = Vector2(340, 330)
	_details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_box.add_child(_details)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	detail_box.add_child(buttons)
	_wear_button = UITheme.button("Wear", _wear_or_remove, 110.0)
	buttons.add_child(_wear_button)
	_focus_button = UITheme.button("Focus (G)", _focus_selected, 110.0)
	_focus_button.tooltip_text = "The relic in focus is the one G uses."
	buttons.add_child(_focus_button)
	_discard_button = UITheme.button("Discard", _discard_selected, 100.0)
	buttons.add_child(_discard_button)

	_message = UITheme.label("", 14, UITheme.BAD)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_message)
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree():
			_tip.hide_tip()
			_confirm_discard = false
	)
	player.relics.changed.connect(refresh_if_open)


func refresh_if_open() -> void:
	if is_visible_in_tree():
		refresh()


func refresh() -> void:
	var relics := player.relics
	if _selected and not (_selected in relics.bag or _selected in relics.worn):
		_selected = null
	var slots := relics.slots()
	_worn_title.text = "Worn  (%d / %d)" % [relics.worn.size(), slots]
	for index in 3:
		var button := _worn_buttons[index]
		var item: Item = relics.worn[index] if index < relics.worn.size() else null
		ItemGrid.style_slot(button, item, item != null and item == _selected)
		button.disabled = index >= slots
		var note := _worn_notes[index]
		if index >= slots:
			note.text = "Locked: needs a %s." % BELT_FOR_SLOT[index]
			note.add_theme_color_override("font_color", UITheme.DIM)
		elif item == null:
			note.text = "Empty: choose a relic in the bag and wear it."
			note.add_theme_color_override("font_color", UITheme.DIM)
		else:
			var ability := relics.ability_of(item)
			var left := relics.cooldown_left(item)
			var focus_mark := "[G] " if index == relics.focus else ""
			note.text = "%s%s\n%s%s" % [focus_mark, item.display_name(), ability["name"], "  (%ds)" % ceili(left) if left > 0.0 else "  ready"]
			note.add_theme_color_override("font_color", UITheme.GOLD if index == relics.focus else item.color())
	var belt := player.equipment.get_item("belt")
	_belt_line.text = ("Belt: %s" % belt.display_name()) if belt else "No belt worn. Wear one in the inventory's belt slot for more bag room and relic places."
	_bag.selected = _selected
	_bag.set_items(relics.bag, RelicDB.BAG_SIZE)
	_bag_title.text = "Bag  (%d / %d)" % [relics.bag.size(), RelicDB.BAG_SIZE]
	_show_details()


func _show_details() -> void:
	var item := _selected
	_wear_button.disabled = item == null
	_focus_button.disabled = item == null or not item in player.relics.worn
	_discard_button.disabled = item == null
	_discard_button.text = "Sure?" if _confirm_discard else "Discard"
	if item == null:
		_details.text = "[color=#%s]Choose a relic to see its boons and power.[/color]" % UITheme.DIM.to_html(false)
		_wear_button.text = "Wear"
		return
	_wear_button.text = "Take off" if item in player.relics.worn else "Wear"
	var data: Dictionary = RelicDB.RELICS[item.definition()["relic"]]
	var lines: PackedStringArray = []
	lines.append("[font_size=20][color=#%s]%s[/color][/font_size]" % [item.color().to_html(false), item.display_name()])
	lines.append("[color=#%s]%s relic[/color]" % [item.color().to_html(false), ItemDB.RARITIES[item.rarity]["name"]])
	lines.append("")
	lines.append("[i][color=#%s]%s[/color][/i]" % [UITheme.DIM.to_html(false), data["text"]])
	lines.append("")
	lines.append(ItemText.relic_text(item))
	_details.text = "\n".join(lines)


func _select(item: Item) -> void:
	_selected = item
	_confirm_discard = false
	_message.text = ""
	refresh()


func _wear_or_remove() -> void:
	if _selected == null:
		return
	var problem := player.relics.take_off(_selected) if _selected in player.relics.worn else player.relics.wear(_selected)
	_message.text = problem
	refresh()


func _focus_selected() -> void:
	var index := player.relics.worn.find(_selected)
	if index >= 0:
		player.relics.set_focus(index)
		refresh()


func _discard_selected() -> void:
	if _selected == null:
		return
	if not _confirm_discard:
		_confirm_discard = true
		_show_details()
		return
	player.relics.discard(_selected)
	_selected = null
	_confirm_discard = false
	refresh()


func _worn_item(index: int) -> Item:
	return player.relics.worn[index] if index < player.relics.worn.size() else null


func _on_worn_pressed(index: int) -> void:
	var item := _worn_item(index)
	if item:
		Audio.play("ui_click", -10.0, 0.05)
		if item == _selected:
			player.relics.set_focus(index)
		_select(item)


func _on_worn_input(event: InputEvent, index: int) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_RIGHT and _worn_item(index):
		_select(_worn_item(index))
		_wear_or_remove()


func _on_worn_hover(index: int) -> void:
	var item := _worn_item(index)
	if item:
		_tip.show_item(item, player, "[color=#%s]Click twice to focus it, right-click to take it off[/color]" % UITheme.GOOD.to_html(false))
