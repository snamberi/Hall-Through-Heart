class_name ProfessionsMenu
extends GameMenu
## Profession levels on the left; in the middle, the recipes of the selected
## crafting profession (or what a gathering profession can gather), each
## with the picture of what it makes; on the right, the chosen recipe: a
## large picture, and every ingredient shown with how many you hold.

const ROW_HEIGHT := 46.0

var _rows: Dictionary[String, Dictionary] = {}
var _selected := "blacksmithing"
var _right_title: Label
var _filter: CheckBox
var _list: VBoxContainer
var _icon: TextureRect
var _icon_frame: PanelContainer
var _name: Label
var _kind: Label
var _text: Label
var _needs: VBoxContainer
var _note: Label
var _craft: Button
var _craft_five: Button
var _message: Label
var _tip: ItemTooltip
var _recipe: Dictionary = {}

## Pictures of what recipes make, by recipe id.
static var _samples: Dictionary = {}


## An item like the one a recipe makes, for its picture and words.
static func sample(recipe: Dictionary) -> Item:
	if not _samples.has(recipe["id"]):
		_samples[recipe["id"]] = LootGenerator.make_equipment(recipe.get("item_level", 1), 0, recipe["equipment"]) if recipe.has("equipment") else Item.create(recipe["item"])
	return _samples[recipe["id"]]


func _build() -> void:
	var title := UITheme.heading("PROFESSIONS", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	_tip = ItemTooltip.new()
	add_child(_tip)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	content.add_child(columns)

	# --- left: the professions
	var left_panel := UITheme.inset_panel()
	columns.add_child(left_panel)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 5)
	left_panel.add_child(left)
	for group: Array in [["Gathering", Professions.GATHERING], ["Crafting", Professions.CRAFTING]]:
		left.add_child(UITheme.heading(group[0], 17))
		for id: String in group[1]:
			var button := Button.new()
			button.toggle_mode = true
			button.focus_mode = Control.FOCUS_NONE
			button.custom_minimum_size = Vector2(250.0, 40.0)
			button.pressed.connect(_select.bind(id))
			UITheme.sounds(button)
			left.add_child(button)
			var picture := TextureRect.new()
			picture.texture = ItemDB.icon(Professions.ICONS[id])
			picture.position = Vector2(8, 6)
			picture.size = Vector2(28, 28)
			picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(picture)
			var name_label := UITheme.label(Professions.NAMES[id], 15)
			name_label.position = Vector2(44, 3)
			name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(name_label)
			var level_label := UITheme.label("", 15, UITheme.GOLD)
			level_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
			level_label.offset_left = -70.0
			level_label.offset_right = -10.0
			level_label.offset_top = 3.0
			level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(level_label)
			# Experience toward the next level, along the bottom of the button.
			var bar := ProgressBar.new()
			bar.show_percentage = false
			bar.position = Vector2(44, 27)
			bar.size = Vector2(196, 7)
			bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var trough := StyleBoxFlat.new()
			trough.bg_color = Color(0.03, 0.035, 0.06)
			trough.border_color = Color("4a3a24")
			trough.set_border_width_all(1)
			var fill := StyleBoxFlat.new()
			fill.bg_color = Color("d9a441")
			fill.border_color = Color("f0d28a")
			fill.border_width_top = 1
			bar.add_theme_stylebox_override("background", trough)
			bar.add_theme_stylebox_override("fill", fill)
			button.add_child(bar)
			_rows[id] = {"button": button, "bar": bar, "level": level_label}

	# --- middle: recipes, or what can be gathered
	var middle_panel := UITheme.inset_panel()
	columns.add_child(middle_panel)
	var middle := VBoxContainer.new()
	middle.add_theme_constant_override("separation", 8)
	middle_panel.add_child(middle)
	var head := HBoxContainer.new()
	middle.add_child(head)
	_right_title = UITheme.heading("", 19)
	_right_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_right_title)
	_filter = CheckBox.new()
	_filter.text = "Can make now"
	_filter.focus_mode = Control.FOCUS_NONE
	_filter.add_theme_font_size_override("font_size", 13)
	_filter.toggled.connect(func(_on: bool) -> void: refresh())
	head.add_child(_filter)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(350.0, 420.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	middle.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 3)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	# --- right: the chosen recipe
	var right_panel := UITheme.inset_panel()
	columns.add_child(right_panel)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.custom_minimum_size = Vector2(310.0, 0.0)
	right_panel.add_child(right)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	right.add_child(top)
	_icon_frame = PanelContainer.new()
	_icon_frame.custom_minimum_size = Vector2(84.0, 84.0)
	_icon_frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(_icon_frame)
	_icon = UITheme.icon(0, 68.0)
	_icon_frame.add_child(_icon)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(words)
	_name = UITheme.heading("", 19)
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD
	_name.custom_minimum_size.x = 200.0
	words.add_child(_name)
	_kind = UITheme.label("", 13, UITheme.DIM)
	words.add_child(_kind)
	_text = UITheme.label("", 13, UITheme.DIM)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	_text.custom_minimum_size = Vector2(310.0, 0.0)
	right.add_child(_text)
	var needs_scroll := ScrollContainer.new()
	needs_scroll.custom_minimum_size = Vector2(310.0, 230.0)
	needs_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	needs_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(needs_scroll)
	_needs = VBoxContainer.new()
	_needs.add_theme_constant_override("separation", 4)
	_needs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	needs_scroll.add_child(_needs)
	_note = UITheme.label("", 13, UITheme.BAD)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD
	_note.custom_minimum_size = Vector2(310.0, 20.0)
	right.add_child(_note)
	_message = UITheme.label("", 13, UITheme.BAD)
	_message.custom_minimum_size = Vector2(310.0, 18.0)
	right.add_child(_message)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	right.add_child(buttons)
	_craft = UITheme.button("Craft", _make.bind(1), 151.0)
	_craft_five = UITheme.button("Craft 5", _make.bind(5), 151.0)
	buttons.add_child(_craft)
	buttons.add_child(_craft_five)

	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree():
			_tip.hide_tip()
	)
	player.professions.changed.connect(refresh_if_open)
	player.inventory.changed.connect(refresh_if_open)


func refresh() -> void:
	var professions := player.professions
	for id in _rows:
		var level := professions.level(id)
		var button: Button = _rows[id]["button"]
		button.set_pressed_no_signal(id == _selected)
		(_rows[id]["level"] as Label).text = str(level)
		var bar: ProgressBar = _rows[id]["bar"]
		bar.max_value = Professions.xp_required(level)
		bar.value = professions.xp[id]

	for child in _list.get_children():
		child.queue_free()
	var level := professions.level(_selected)
	_right_title.text = "%s  -  level %d / %d" % [Professions.NAMES[_selected], level, Professions.MAX_LEVEL]
	var gathering := _selected in Professions.GATHERING
	_filter.visible = not gathering
	if _recipe.is_empty() or _recipe["profession"] != _selected:
		_recipe = {}
	if gathering:
		_list_resources(level)
	else:
		for recipe in RecipeDB.for_profession(_selected):
			# Hide recipes far above the player's skill to keep the list short.
			if recipe["level"] > level + 15:
				continue
			var reason := Crafting.blocked_reason(player, recipe)
			if _filter.button_pressed and reason != "":
				continue
			_list.add_child(_recipe_row(recipe, reason))
	_show_details()


## One recipe in the list: picture, name, level, and whether it can be made.
func _recipe_row(recipe: Dictionary, reason: String) -> Button:
	var made := sample(recipe)
	var chosen: bool = not _recipe.is_empty() and recipe["id"] == _recipe["id"]
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(330.0, ROW_HEIGHT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("2a2416") if chosen else Color("151823")
	style.border_color = UITheme.GOLD if chosen else Color("3a3e50")
	style.set_border_width_all(2 if chosen else 1)
	var hover := style.duplicate()
	hover.bg_color = style.bg_color.lightened(0.08)
	for state: String in ["normal", "pressed"]:
		button.add_theme_stylebox_override(state, style)
	button.add_theme_stylebox_override("hover", hover)
	var slot := Panel.new()
	slot.position = Vector2(4, 4)
	slot.size = Vector2(ROW_HEIGHT - 8.0, ROW_HEIGHT - 8.0)
	slot.add_theme_stylebox_override("panel", ItemGrid.frame_style(made, false))
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(slot)
	var picture := TextureRect.new()
	picture.texture = made.icon()
	picture.modulate = made.icon_tint() if reason == "" else Color(made.icon_tint(), 0.55)
	picture.position = Vector2(8, 8)
	picture.size = Vector2(ROW_HEIGHT - 16.0, ROW_HEIGHT - 16.0)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(picture)
	var color := UITheme.TEXT if reason == "" else UITheme.BAD if reason.begins_with("Requires") else UITheme.DIM
	var name_label := UITheme.label(RecipeDB.display_name(recipe), 14, color)
	name_label.position = Vector2(ROW_HEIGHT + 4.0, 4)
	name_label.size = Vector2(230.0, 20.0)
	name_label.clip_text = true
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(name_label)
	# The ingredients, as little pictures with counts.
	var x := ROW_HEIGHT + 4.0
	for item_id: String in recipe["inputs"]:
		var need: int = recipe["inputs"][item_id]
		var have := player.inventory.count_of(item_id)
		var part := Item.create(item_id)
		var small := TextureRect.new()
		small.texture = part.icon()
		small.modulate = part.icon_tint()
		small.position = Vector2(x, 25)
		small.size = Vector2(16, 16)
		small.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		small.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		small.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(small)
		var count := UITheme.label("%d/%d" % [mini(have, 999), need], 11, UITheme.GOOD if have >= need else UITheme.BAD)
		count.position = Vector2(x + 21.0, 24)
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(count)
		x += 66.0
	var level_label := UITheme.label("lv %d" % recipe["level"], 12, UITheme.DIM if player.professions.level(_selected) >= recipe["level"] else UITheme.BAD)
	level_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	level_label.offset_left = -52.0
	level_label.offset_right = -8.0
	level_label.offset_top = 4.0
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(level_label)
	button.pressed.connect(func() -> void:
		_recipe = recipe
		_message.text = ""
		refresh()
	)
	button.mouse_entered.connect(func() -> void: _tip.show_recipe(recipe, player))
	button.mouse_exited.connect(func() -> void: _tip.hide_tip())
	UITheme.sounds(button)
	return button


## What a gathering profession can gather, with pictures of what each gives.
func _list_resources(level: int) -> void:
	var entries: Array = []
	for id: String in GatherDB.RESOURCES:
		var data: Dictionary = GatherDB.RESOURCES[id]
		if GatherDB.KINDS[data["kind"]]["profession"] != _selected or data["kind"] == "fish":
			continue
		entries.append([data["level"], GatherDB.display_name(id), data["item"], "" if data["tier"] <= 1 else "needs a tier %d tool" % data["tier"]])
	if _selected == "fishing":
		for fish in GatherDB.FISH:
			entries.append([fish[1], ItemDB.ITEMS[fish[0]]["name"], fish[0], ""])
	entries.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for entry: Array in entries:
		var known: bool = level >= entry[0]
		var given := Item.create(entry[2])
		var row := Panel.new()
		row.custom_minimum_size = Vector2(330.0, 38.0)
		var style := StyleBoxFlat.new()
		style.bg_color = Color("151823")
		style.border_color = Color("3a3e50")
		style.set_border_width_all(1)
		row.add_theme_stylebox_override("panel", style)
		var picture := TextureRect.new()
		picture.texture = given.icon()
		picture.modulate = Color(given.icon_tint(), 1.0 if known else 0.35)
		picture.position = Vector2(6, 4)
		picture.size = Vector2(30, 30)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		row.add_child(picture)
		var name_label := UITheme.label(entry[1], 14, UITheme.TEXT if known else UITheme.DIM)
		name_label.position = Vector2(44, 2)
		row.add_child(name_label)
		var detail := UITheme.label(("gives %s" % given.display_name()) + ("  -  %s" % entry[3] if entry[3] != "" else ""), 11, UITheme.DIM)
		detail.position = Vector2(44, 20)
		row.add_child(detail)
		var level_label := UITheme.label("lv %d" % entry[0], 12, UITheme.GOOD if known else UITheme.BAD)
		level_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		level_label.offset_left = -52.0
		level_label.offset_right = -8.0
		level_label.offset_top = 10.0
		level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(level_label)
		_list.add_child(row)


func _select(id: String) -> void:
	_selected = id
	_recipe = {}
	_message.text = ""
	refresh()


func _show_details() -> void:
	var professions := player.professions
	var has_recipe := not _recipe.is_empty()
	for child in _needs.get_children():
		child.queue_free()
	_craft.disabled = not has_recipe or Crafting.blocked_reason(player, _recipe) != ""
	_craft_five.disabled = _craft.disabled
	_craft.visible = not _selected in Professions.GATHERING
	_craft_five.visible = _craft.visible
	_icon_frame.visible = true
	_note.text = ""
	if has_recipe:
		var made := sample(_recipe)
		_icon.texture = made.icon()
		_icon.modulate = made.icon_tint()
		_icon_frame.add_theme_stylebox_override("panel", ItemGrid.frame_style(made, false))
		var count: int = _recipe.get("count", 1)
		_name.text = RecipeDB.display_name(_recipe)
		_kind.text = "%s level %d%s" % [Professions.NAMES[_recipe["profession"]], _recipe["level"], "   makes %d" % count if count > 1 else ""]
		if _recipe.has("equipment"):
			_text.text = "Item level %d. Rarity and bonuses are rolled when it is made; skill improves the odds." % _recipe["item_level"]
		else:
			_text.text = ItemDB.ITEMS[_recipe["item"]].get("text", "")
		_needs.add_child(UITheme.heading("Needs", 15))
		for item_id: String in _recipe["inputs"]:
			_needs.add_child(_need_row(item_id, _recipe["inputs"][item_id]))
		_note.text = Crafting.blocked_reason(player, _recipe)
	else:
		_icon.texture = ItemDB.icon(Professions.ICONS[_selected])
		_icon.modulate = Color.WHITE
		_icon_frame.add_theme_stylebox_override("panel", ItemGrid.frame_style(null, false))
		_name.text = Professions.NAMES[_selected]
		_kind.text = "Level %d of %d" % [professions.level(_selected), Professions.MAX_LEVEL]
		if _selected in Professions.GATHERING:
			_text.text = "Works %d%% faster, with a %d%% chance of a double yield.\n\nPoint at a %s and left click; the right tool comes to hand." % [
				roundi((professions.speed_multiplier(_selected) - 1.0) * 100.0), roundi(professions.double_chance(_selected) * 100.0),
				{"mining": "rock", "woodcutting": "tree", "herbalism": "plant", "fishing": "fishing spot"}.get(_selected, "node")]
		else:
			_text.text = "Pick a recipe to see what it needs."
			if not player.near_crafting_table():
				_note.text = "You are not next to a crafting table. Only a few simple things can be made by hand."
			if _selected in ["blacksmithing", "enchanting", "salvaging"]:
				_text.text += "\n\nUpgrade, Enchant and Salvage are buttons on the Inventory screen: select a piece of equipment there."
	var title := professions.title(_selected)
	if title != "":
		_kind.text += "   -   %s" % title


## One ingredient: its picture, name, and how many are held of how many needed.
func _need_row(item_id: String, need: int) -> Control:
	var have := player.inventory.count_of(item_id)
	var part := Item.create(item_id)
	var row := Panel.new()
	row.custom_minimum_size = Vector2(300.0, 40.0)
	row.add_theme_stylebox_override("panel", ItemGrid.frame_style(part, false))
	var picture := TextureRect.new()
	picture.texture = part.icon()
	picture.modulate = part.icon_tint()
	picture.position = Vector2(6, 5)
	picture.size = Vector2(30, 30)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(picture)
	var name_label := UITheme.label(part.display_name(), 14)
	name_label.position = Vector2(44, 9)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name_label)
	var count := UITheme.label("%d / %d" % [have, need], 15, UITheme.GOOD if have >= need else UITheme.BAD)
	count.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	count.offset_left = -90.0
	count.offset_right = -10.0
	count.offset_top = 8.0
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(count)
	row.mouse_entered.connect(func() -> void: _tip.show_item(part, player))
	row.mouse_exited.connect(func() -> void: _tip.hide_tip())
	return row


func _make(times: int) -> void:
	if _recipe.is_empty():
		return
	var result := ""
	for i in times:
		result = Crafting.craft(player, _recipe)
		if result != "":
			break
	_message.text = result
	if result == "":
		Audio.play("pickup", -6.0)
	refresh()
