class_name InventoryMenu
extends GameMenu
## The bag, the equipment slots, and details of the selected item.
##
## Left-click selects an item; right-click equips or unequips it at once.

const COLUMNS := 8
const SLOT_SIZE := 52.0
const TEXT := "d9d4c7"
const DIM := "8a857c"
const GOOD := "8fd0ff"
const BAD := "e0555a"

var _header: Label
var _gold: Label
var _bag_buttons: Array[Button] = []
var _bag_counts: Array[Label] = []
var _slot_buttons: Dictionary[String, Button] = {}
var _details: RichTextLabel
var _compare: RichTextLabel
var _action_button: Button
var _discard_button: Button
var _message: Label

var _selected: Item
var _hovered: Item


func _build() -> void:
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 32)
	content.add_child(top)
	_header = UITheme.heading("", 28)
	top.add_child(_header)
	_gold = make_label("", 20, MenuColors.GOLD)
	_gold.size_flags_vertical = Control.SIZE_SHRINK_END
	top.add_child(_gold)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 36)
	content.add_child(columns)

	# Left: the bag
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	columns.add_child(left)
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	left.add_child(grid)
	for index in Inventory.CAPACITY:
		var button := _item_button(Vector2(SLOT_SIZE, SLOT_SIZE))
		button.pressed.connect(func() -> void: _select(_bag_item(index)))
		button.mouse_entered.connect(func() -> void: _hover(_bag_item(index)))
		button.mouse_exited.connect(func() -> void: _hover(null))
		button.gui_input.connect(func(event: InputEvent) -> void:
			if _is_right_click(event) and _bag_item(index):
				_select(_bag_item(index))
				_use_selected()
		)
		var count := make_label("", 13)
		count.add_theme_color_override("font_outline_color", Color.BLACK)
		count.add_theme_constant_override("outline_size", 4)
		count.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		count.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		count.grow_vertical = Control.GROW_DIRECTION_BEGIN
		count.position -= Vector2(4, 1)
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(count)
		grid.add_child(button)
		_bag_buttons.append(button)
		_bag_counts.append(count)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	left.add_child(actions)
	_action_button = UITheme.button("Equip", _use_selected)
	actions.add_child(_action_button)
	_discard_button = UITheme.button("Discard", _discard_selected)
	actions.add_child(_discard_button)
	actions.add_child(UITheme.button("Sort", func() -> void: player.inventory.sort()))
	_message = make_label("", 14, Color("e0555a"))
	actions.add_child(_message)

	# Middle: equipment slots
	var middle := VBoxContainer.new()
	middle.add_theme_constant_override("separation", 4)
	columns.add_child(middle)
	middle.add_child(UITheme.heading("Equipment"))
	for slot in ItemDB.SLOTS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var slot_label := make_label(ItemDB.SLOT_NAMES[slot], 14, MenuColors.DIM)
		slot_label.custom_minimum_size.x = 78.0
		row.add_child(slot_label)
		var button := _item_button(Vector2(230.0, 36.0))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 14)
		button.pressed.connect(func() -> void: _select(player.equipment.get_item(slot)))
		button.mouse_entered.connect(func() -> void: _hover(player.equipment.get_item(slot)))
		button.mouse_exited.connect(func() -> void: _hover(null))
		button.gui_input.connect(func(event: InputEvent) -> void:
			if _is_right_click(event) and player.equipment.get_item(slot):
				_select(player.equipment.get_item(slot))
				_use_selected()
		)
		row.add_child(button)
		middle.add_child(row)
		_slot_buttons[slot] = button

	var helmet_toggle := CheckBox.new()
	helmet_toggle.text = "Show helmet"
	helmet_toggle.focus_mode = Control.FOCUS_NONE
	helmet_toggle.button_pressed = player.show_helmet
	helmet_toggle.toggled.connect(func(shown: bool) -> void: player.show_helmet = shown)
	middle.add_child(helmet_toggle)

	# Right: details
	var details_frame := UITheme.inset_panel()
	columns.add_child(details_frame)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 12)
	details_frame.add_child(right)
	_details = _rich_text()
	right.add_child(_details)
	_compare = _rich_text()
	right.add_child(_compare)

	player.inventory.changed.connect(refresh_if_open)
	player.equipment.changed.connect(refresh_if_open)


func refresh() -> void:
	var inventory := player.inventory
	# Forget a selection that no longer exists (discarded or sold).
	if _selected and not _selected in inventory.items and _equipped_slot(_selected) == "":
		_selected = null
	_header.text = "Inventory  %d / %d" % [inventory.items.size(), Inventory.CAPACITY]
	_gold.text = "%d gold" % inventory.gold

	for index in Inventory.CAPACITY:
		var item := _bag_item(index)
		_style_button(_bag_buttons[index], item, 2)
		_bag_buttons[index].icon = item.icon() if item else null
		_bag_counts[index].text = str(item.count) if item and item.count > 1 else ""
	for slot in ItemDB.SLOTS:
		var item := player.equipment.get_item(slot)
		var button := _slot_buttons[slot]
		_style_button(button, item, 1)
		button.icon = item.icon() if item else null
		button.text = item.display_name() if item else "empty"
		button.add_theme_color_override("font_color", item.color() if item else MenuColors.DIM)
		button.add_theme_color_override("font_hover_color", item.color() if item else MenuColors.DIM)

	_refresh_details()


func _refresh_details() -> void:
	var shown := _hovered if _hovered else _selected
	_details.text = _describe(shown) if shown else "[color=#%s]Select an item to see what it does.[/color]" % DIM
	_compare.text = ""
	if shown and shown.is_equipment() and _equipped_slot(shown) == "":
		var current := player.equipment.get_item(player.equipment.target_slot(shown))
		if current:
			_compare.text = "[color=#%s]Currently equipped[/color]\n%s" % [DIM, _describe(current)]

	var equipped := _selected != null and _equipped_slot(_selected) != ""
	_action_button.text = "Unequip" if equipped else "Equip"
	_action_button.disabled = _selected == null or not _selected.is_equipment()
	_discard_button.disabled = _selected == null or equipped


## BBCode description of an item.
func _describe(item: Item) -> String:
	var lines: PackedStringArray = []
	var def := item.definition()
	lines.append("[font_size=20][color=#%s]%s[/color][/font_size]" % [item.color().to_html(false), item.display_name()])
	if not item.is_equipment():
		lines.append("[color=#%s]%s material[/color]" % [DIM, ItemDB.RARITIES[item.rarity]["name"]])
		lines.append("[color=#%s]%s[/color]" % [TEXT, def["text"]])
		lines.append("[color=#%s]You have %d.[/color]" % [DIM, player.inventory.count_of(item.id)])
		return "\n".join(lines)

	var kind: String = ItemDB.SLOT_NAMES[item.slot()]
	if def.get("two_handed", false):
		kind = "Two-handed"
	lines.append("[color=#%s]%s  -  %s  -  item level %d[/color]" % [DIM, ItemDB.RARITIES[item.rarity]["name"], kind, item.level])
	if def.has("damage"):
		var weapon: Dictionary = def["weapon"]
		lines.append("[color=#%s]%d damage%s[/color]" % [TEXT, roundi(item.base_power("damage")), "  (scales with magic damage)" if def.get("magic", false) else ""])
		var action := "shots, range" if weapon.has("projectile") else "swings, reach"
		lines.append("[color=#%s]%.2fs between %s %d[/color]" % [DIM, weapon["cooldown"], action, roundi(weapon["range"])])
	if def.has("on_hit"):
		var effect: Dictionary = def["on_hit"]
		var status: Dictionary = ItemDB.STATUSES[effect["status"]]
		var detail := "slows by %d%%" % roundi(effect["power"] * 100.0) if effect["status"] == "chill" else "%d%% of the hit per second" % roundi(effect["power"] * 100.0)
		lines.append("[color=#%s]Hits inflict %s: %s for %.1fs[/color]" % [status["color"].to_html(false), status["name"], detail, effect["duration"]])
	if def.has("life_steal"):
		lines.append("[color=#%s]Heals you for %d%% of damage dealt[/color]" % [GOOD, roundi(def["life_steal"] * 100.0)])
	if def.has("armor"):
		lines.append("[color=#%s]%d armor[/color]" % [TEXT, roundi(item.base_power("armor"))])
	for modifier in item.implicit_modifiers():
		lines.append("[color=#%s]%s[/color]" % [TEXT, ItemDB.describe_modifier(modifier)])
	for modifier in item.mods:
		lines.append("[color=#%s]%s[/color]" % [GOOD, ItemDB.describe_modifier(modifier)])

	var level_ok := player.leveling.level >= item.level
	lines.append("[color=#%s]Requires level %d[/color]" % [DIM if level_ok else BAD, item.level])
	var requirements := item.attribute_requirements()
	for attribute: String in requirements:
		var met: bool = player.attributes.points[attribute] >= requirements[attribute]
		lines.append("[color=#%s]Requires %d %s[/color]" % [DIM if met else BAD, requirements[attribute], Attributes.NAMES[attribute]])
	return "\n".join(lines)


func _select(item: Item) -> void:
	_selected = item
	_message.text = ""
	refresh()


func _hover(item: Item) -> void:
	_hovered = item
	_refresh_details()


## Equips the selected bag item, or unequips the selected worn item.
func _use_selected() -> void:
	if _selected == null or not _selected.is_equipment():
		return
	var slot := _equipped_slot(_selected)
	_message.text = player.equipment.unequip(slot) if slot != "" else player.equipment.equip(_selected)
	refresh()


func _discard_selected() -> void:
	if _selected and _selected in player.inventory.items:
		var item := _selected
		_selected = null
		player.inventory.remove(item)


func _bag_item(index: int) -> Item:
	return player.inventory.items[index] if index < player.inventory.items.size() else null


func _equipped_slot(item: Item) -> String:
	for slot in player.equipment.equipped:
		if player.equipment.equipped[slot] == item:
			return slot
	return ""


func _is_right_click(event: InputEvent) -> bool:
	var click := event as InputEventMouseButton
	return click != null and click.pressed and click.button_index == MOUSE_BUTTON_RIGHT


func _item_button(minimum_size: Vector2) -> Button:
	var button := Button.new()
	button.custom_minimum_size = minimum_size
	button.focus_mode = Control.FOCUS_NONE
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER if minimum_size.x == minimum_size.y else HORIZONTAL_ALIGNMENT_LEFT
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return button


func _text_button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(84.0, 32.0)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	return button


func _rich_text() -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.custom_minimum_size = Vector2(290.0, 0.0)
	label.add_theme_font_size_override("normal_font_size", 14)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## Frames a slot in the item's rarity colour; the selected item gets a bright frame.
func _style_button(button: Button, item: Item, border: int) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.12, 0.15)
	style.border_color = Color(0.25, 0.23, 0.26)
	style.set_border_width_all(border)
	style.set_content_margin_all(5)
	if item:
		style.border_color = item.color().darkened(0.25)
		style.bg_color = item.color().darkened(0.82)
		if item == _selected:
			style.border_color = Color.WHITE
			style.set_border_width_all(border + 1)
	var hover := style.duplicate()
	hover.bg_color = style.bg_color.lightened(0.08)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_stylebox_override("hover", hover)
