class_name ItemInspector
extends VBoxContainer
## The inspector for one item, the same wherever items are looked at: its
## picture, name, rarity and kind with badges for its state; its headline
## numbers in a row of cells (with how they differ from what is worn); then
## what it needs, what it gives and its story, which scroll.

var width := 320.0
var _frame: PanelContainer
var _icon: TextureRect
var _name: Label
var _kind: Label
var _badges: HBoxContainer
var _numbers: HBoxContainer
var _body: RichTextLabel


func build(p_width: float, body_height: float) -> void:
	width = p_width
	add_theme_constant_override("separation", 8)
	custom_minimum_size.x = width
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	add_child(top)
	_frame = PanelContainer.new()
	_frame.custom_minimum_size = Vector2(64.0, 64.0)
	_frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(_frame)
	_icon = UITheme.icon(0, 50.0)
	_frame.add_child(_icon)
	var naming := VBoxContainer.new()
	naming.add_theme_constant_override("separation", 1)
	naming.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(naming)
	_name = UITheme.heading("", 20)
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name.custom_minimum_size.x = width - 80.0
	naming.add_child(_name)
	_kind = UITheme.label("", 14, UITheme.DIM)
	naming.add_child(_kind)
	_badges = HBoxContainer.new()
	_badges.add_theme_constant_override("separation", 6)
	naming.add_child(_badges)
	_numbers = HBoxContainer.new()
	_numbers.add_theme_constant_override("separation", 0)
	add_child(_numbers)
	add_child(UITheme.rule())
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = false
	_body.scroll_active = true
	_body.custom_minimum_size = Vector2(width, body_height)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for item: String in ["normal_font_size", "bold_font_size", "italics_font_size"]:
		UITheme.font_size(_body, 14, item)
	add_child(_body)


## Shows an item. `badges` is [[text, kind]] (see UITheme.badge); `empty`
## is what to say when there is nothing to show.
func show_item(item: Item, player: Player, badges: Array = [], empty: String = "Nothing chosen", extra: String = "") -> void:
	_frame.visible = item != null
	_numbers.visible = item != null
	for child in _badges.get_children() + _numbers.get_children():
		child.queue_free()
	if item == null:
		_name.text = empty
		_name.add_theme_color_override("font_color", UITheme.DIM)
		_kind.text = ""
		_body.text = "[color=#%s]%s[/color]" % [UITheme.DIM.to_html(false), extra]
		return
	_icon.texture = item.icon()
	_icon.modulate = item.icon_tint()
	_frame.add_theme_stylebox_override("panel", ItemGrid.frame_style(item, false))
	_name.text = item.display_name()
	_name.add_theme_color_override("font_color", item.color())
	_kind.text = ItemText.headline(item)
	for badge: Array in badges:
		_badges.add_child(UITheme.badge(badge[0], badge[1]))
	if item.locked:
		_badges.add_child(UITheme.badge("Locked", "info"))
	var cells := ItemText.numbers(item, player)
	for index in cells.size():
		_numbers.add_child(number_cell(cells[index], index > 0))
	_body.text = ItemText.describe(item, player, true) + ("\n\n" + extra if extra != "" else "")


## One headline number: its name small above, the value large, and how it
## differs from what is worn beneath.
static func number_cell(cell: Array, divided: bool) -> Control:
	var box := HBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 0)
	if divided:
		var line := ColorRect.new()
		line.color = UITheme.LINE
		line.custom_minimum_size = Vector2(1, 0)
		box.add_child(line)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", -2)
	box.add_child(column)
	var title := UITheme.label(cell[0], 14, UITheme.DIM)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var value := UITheme.strong(cell[1], 22)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(value)
	var note := UITheme.label(("%s vs worn" % cell[2]) if cell[2] != "" else " ", 14, UITheme.GOOD if cell[3] else UITheme.BAD)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(note)
	return box
