class_name MagicMenu
extends GameMenu
## The schools of magic. On the left, one row per school with its colour
## and a one-line role, to compare at a glance. On the right, the chosen
## school: what it is and its four spells in a table (opens at, mana,
## cooldown). At the Altar of Magic the player takes up a school (or changes
## to one already learned); elsewhere the screen says where the altar lies
## and offers to show it on the map.

const ROW := Vector2(400.0, 66.0)
const DETAIL_WIDTH := 680.0
## How near the altar counts as standing at it, in pixels.
const ALTAR_REACH := 160.0
## Spell table columns: name, opens at, mana, cooldown.
const COLUMNS: Array[float] = [380.0, 84.0, 70.0, 96.0]

var _selected := ""
var _status: Label
var _list: VBoxContainer
var _icon: TextureRect
var _name: Label
var _mine: Control
var _role: Label
var _text: Label
var _spells: VBoxContainer
var _action: Button
var _where: Label
var _map: Button


func _build() -> void:
	var title := UITheme.heading("MAGIC", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	_status = UITheme.label("", 15, UITheme.TEXT)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	_status.custom_minimum_size.x = ROW.x + DETAIL_WIDTH
	content.add_child(_status)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	content.add_child(columns)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	columns.add_child(_list)

	var right := PanelContainer.new()
	right.add_theme_stylebox_override("panel", UITheme.card("card", 14))
	right.custom_minimum_size = Vector2(DETAIL_WIDTH, 0.0)
	columns.add_child(right)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	right.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	box.add_child(head)
	_icon = _picture(48.0)
	head.add_child(_icon)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 0)
	head.add_child(words)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 10)
	words.add_child(name_row)
	_name = UITheme.heading("", 24)
	name_row.add_child(_name)
	_mine = UITheme.badge("Your magic", "gold")
	_mine.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_row.add_child(_mine)
	_role = UITheme.label("", 15, UITheme.DIM)
	words.add_child(_role)
	_text = UITheme.paragraph("", DETAIL_WIDTH - 30.0, 15, UITheme.TEXT)
	box.add_child(_text)
	box.add_child(UITheme.rule())

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 0)
	box.add_child(header)
	for index in COLUMNS.size():
		var cell := UITheme.label(["Spell", "Opens at", "Mana", "Cooldown"][index], 14, UITheme.DIM)
		cell.custom_minimum_size.x = COLUMNS[index]
		if index > 0:
			cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		header.add_child(cell)
	_spells = VBoxContainer.new()
	_spells.add_theme_constant_override("separation", 6)
	box.add_child(_spells)

	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(fill)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	box.add_child(foot)
	_where = UITheme.label("", 14, UITheme.DIM)
	_where.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_where.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_where.autowrap_mode = TextServer.AUTOWRAP_WORD
	foot.add_child(_where)
	_map = UITheme.button("Show altar on map", _show_altar, 190.0)
	foot.add_child(_map)
	_action = UITheme.primary_button("", func() -> void: _take_up(_selected), 220.0)
	foot.add_child(_action)
	visibility_changed.connect(func() -> void:
		if not visible:
			_selected = ""
	)


func refresh() -> void:
	if _selected == "":
		_selected = player.magic_school if player.magic_school != "" else MagicDB.SCHOOLS.keys()[0]
	var at_altar := _at_altar()
	var world: World = player.get_parent().get_node_or_null("World")
	var where := ""
	if world:
		var offset := world.cell_to_world(world.generator.magic_altar_cell()) - player.global_position
		where = "The Altar of Magic is about %d tiles to the %s." % [roundi(offset.length() / TerrainTiles.TILE_SIZE), _compass(offset)]
	if at_altar:
		_status.text = "The altar hums. Choose the magic you will carry." if player.magic_school == "" else "The altar hums. Change to any magic; you can come back at any time."
	elif player.magic_school == "":
		_status.text = "You have no magic yet. Take up a school at the Altar of Magic."
	else:
		_status.text = "Your magic: %s. Hold a magic weapon in slot 1 to cast its spells with the ability keys." % MagicDB.SCHOOLS[player.magic_school]["name"]
	for child in _list.get_children():
		child.queue_free()
	for school: String in MagicDB.SCHOOLS:
		_list.add_child(_row(school))
	_show(_selected, at_altar, where)


func _row(school: String) -> Button:
	var data: Dictionary = MagicDB.SCHOOLS[school]
	var chosen := school == _selected
	var button := Button.new()
	button.custom_minimum_size = ROW
	for state: String in ["normal", "pressed"]:
		button.add_theme_stylebox_override(state, UITheme.card("card_selected" if chosen else "card", 6))
	button.add_theme_stylebox_override("hover", UITheme.card("card_selected" if chosen else "card_hover", 6))
	button.pressed.connect(func() -> void:
		_selected = school
		refresh()
	)
	UITheme.sounds(button)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(row)
	var icon := _picture(40.0)
	icon.texture = AbilityDB.icon(data["spells"][0])
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(words)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(top)
	var name_label := UITheme.strong(data["name"], 17, data["color"])
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(name_label)
	if school == player.magic_school:
		var badge := UITheme.badge("Yours", "gold")
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_child(badge)
	var role := UITheme.label(data["role"], 14, UITheme.DIM)
	role.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(role)
	return button


func _show(school: String, at_altar: bool, where: String) -> void:
	var data: Dictionary = MagicDB.SCHOOLS[school]
	var current := school == player.magic_school
	_icon.texture = AbilityDB.icon(data["spells"][0])
	_name.text = data["name"]
	_name.add_theme_color_override("font_color", data["color"])
	_mine.visible = current
	_role.text = "%s magic  ·  %s" % [data["short"], data["role"]]
	_text.text = data["text"]
	for child in _spells.get_children():
		child.queue_free()
	var level := player.leveling.level
	for spell: String in data["spells"]:
		var ability: Dictionary = AbilityDB.ABILITIES[spell]
		var opens := int(ability.get("level", 1))
		var open := level >= opens
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 0)
		row.tooltip_text = "%s\n%s" % [ability["name"], ability["text"]]
		var name_cell := HBoxContainer.new()
		name_cell.add_theme_constant_override("separation", 8)
		name_cell.custom_minimum_size.x = COLUMNS[0]
		row.add_child(name_cell)
		var icon := _picture(30.0)
		icon.texture = AbilityDB.icon(spell)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		name_cell.add_child(icon)
		var words := VBoxContainer.new()
		words.add_theme_constant_override("separation", -2)
		name_cell.add_child(words)
		words.add_child(UITheme.strong(ability["name"], 15, UITheme.HEADING))
		var text := UITheme.label(ability["text"], 14, UITheme.DIM)
		text.custom_minimum_size.x = COLUMNS[0] - 42.0
		text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		text.clip_text = true
		words.add_child(text)
		var cells := ["Lv %d" % opens, "%d" % roundi(ability.get("mana", 0.0)), "%ss" % str(ability["cooldown"])]
		for index in cells.size():
			var cell := UITheme.strong(cells[index], 15, (UITheme.GOOD if open else UITheme.TEXT) if index == 0 else UITheme.TEXT)
			cell.custom_minimum_size.x = COLUMNS[index + 1]
			cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(cell)
		_spells.add_child(row)
	# The action: take it up here, or find the altar.
	_action.visible = at_altar
	_map.visible = not at_altar
	if at_altar:
		_where.text = "Your current magic." if current else "You can change back at any time."
		_action.text = "Your magic" if current else ("Take up %s" % data["name"] if player.magic_school == "" else "Change to %s" % data["name"])
		_action.disabled = current
	else:
		_where.text = "%s Take up a school there." % where if not current else "Change school at the Altar of Magic. %s" % where


func _take_up(school: String) -> void:
	if not _at_altar():
		return
	player.take_up_magic(school)
	player.equipment.select("weapon_1")
	RingBurst.spawn(player.get_parent(), player.global_position + Vector2(0, -14), MagicDB.SCHOOLS[school]["color"], 120.0)
	Audio.play("level_up", -6.0, 0.0)
	Events.announcement.emit(str(MagicDB.SCHOOLS[school]["name"]).to_upper(), "Press 2 to hold your magic: your hand fires its bolts and the ability keys cast its spells.")
	refresh()


## Opens the map on the altar, marked.
func _show_altar() -> void:
	var world: World = player.get_parent().get_node_or_null("World")
	if world == null:
		return
	MapMenu.focus_on(world.cell_to_world(world.generator.magic_altar_cell()), "Altar of Magic")
	Events.screen_requested.emit("map")


func _at_altar() -> bool:
	var world: World = player.get_parent().get_node_or_null("World")
	if world == null:
		return false
	return player.global_position.distance_to(world.cell_to_world(world.generator.magic_altar_cell())) < ALTAR_REACH


static func _picture(side: float) -> TextureRect:
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(side, side)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


static func _compass(offset: Vector2) -> String:
	var names := ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"]
	return names[posmod(roundi(offset.angle() / (PI / 4.0)), 8)]
