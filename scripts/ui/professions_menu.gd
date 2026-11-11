class_name ProfessionsMenu
extends GameMenu
## Profession levels on the left; on the right, the recipes of the selected
## crafting profession or what the selected gathering profession unlocks.

var _rows: Dictionary[String, Dictionary] = {}
var _selected := "blacksmithing"
var _right_title: Label
var _list: VBoxContainer
var _details: RichTextLabel
var _craft: Button
var _craft_five: Button
var _message: Label
var _recipe: Dictionary = {}


func _build() -> void:
	var title := UITheme.heading("PROFESSIONS", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	content.add_child(columns)

	var left_panel := UITheme.inset_panel()
	columns.add_child(left_panel)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 4)
	left_panel.add_child(left)
	for group: Array in [["Gathering", Professions.GATHERING], ["Crafting", Professions.CRAFTING]]:
		left.add_child(UITheme.heading(group[0], 18))
		for id: String in group[1]:
			var button := Button.new()
			button.toggle_mode = true
			button.focus_mode = Control.FOCUS_NONE
			button.icon = ItemDB.icon(Professions.ICONS[id])
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.custom_minimum_size = Vector2(250.0, 34.0)
			button.add_theme_constant_override("icon_max_width", 20)
			button.pressed.connect(_select.bind(id))
			left.add_child(button)
			var bar := ProgressBar.new()
			bar.custom_minimum_size = Vector2(250.0, 5.0)
			bar.show_percentage = false
			left.add_child(bar)
			_rows[id] = {"button": button, "bar": bar}

	var middle_panel := UITheme.inset_panel()
	columns.add_child(middle_panel)
	var middle := VBoxContainer.new()
	middle.add_theme_constant_override("separation", 8)
	middle_panel.add_child(middle)
	_right_title = UITheme.heading("", 20)
	middle.add_child(_right_title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(300.0, 400.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	middle.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 3)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	var right_panel := UITheme.inset_panel()
	columns.add_child(right_panel)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right_panel.add_child(right)
	_details = RichTextLabel.new()
	_details.bbcode_enabled = true
	_details.fit_content = true
	_details.scroll_active = false
	_details.custom_minimum_size = Vector2(300.0, 330.0)
	_details.add_theme_font_size_override("normal_font_size", 14)
	_details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(_details)
	_message = UITheme.label("", 13, UITheme.BAD)
	_message.custom_minimum_size = Vector2(300.0, 20.0)
	right.add_child(_message)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	right.add_child(buttons)
	_craft = UITheme.button("Craft", _make.bind(1), 146.0)
	_craft_five = UITheme.button("Craft 5", _make.bind(5), 146.0)
	buttons.add_child(_craft)
	buttons.add_child(_craft_five)

	player.professions.changed.connect(refresh_if_open)
	player.inventory.changed.connect(refresh_if_open)


func refresh() -> void:
	var professions := player.professions
	for id in _rows:
		var level := professions.level(id)
		var button: Button = _rows[id]["button"]
		button.text = "  %s   %d" % [Professions.NAMES[id], level]
		button.set_pressed_no_signal(id == _selected)
		var bar: ProgressBar = _rows[id]["bar"]
		bar.max_value = Professions.xp_required(level)
		bar.value = professions.xp[id]

	for child in _list.get_children():
		child.queue_free()
	var level := professions.level(_selected)
	_right_title.text = "%s  -  level %d / %d" % [Professions.NAMES[_selected], level, Professions.MAX_LEVEL]
	var recipes := RecipeDB.for_profession(_selected)
	if _recipe.is_empty() or _recipe["profession"] != _selected:
		_recipe = {}
	for recipe in recipes:
		# Hide recipes far above the player's skill to keep the list short.
		if recipe["level"] > level + 15:
			continue
		var reason := Crafting.blocked_reason(player, recipe)
		var button := Button.new()
		button.text = "%s   (lv %d)" % [RecipeDB.display_name(recipe), recipe["level"]]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_mode = Control.FOCUS_NONE
		button.toggle_mode = true
		button.button_pressed = not _recipe.is_empty() and recipe["id"] == _recipe["id"]
		button.add_theme_font_size_override("font_size", 14)
		var color := UITheme.TEXT if reason == "" else UITheme.BAD if reason.begins_with("Requires") else UITheme.DIM
		button.add_theme_color_override("font_color", color)
		button.pressed.connect(func() -> void:
			_recipe = recipe
			_message.text = ""
			refresh()
		)
		_list.add_child(button)
	_show_details()


func _select(id: String) -> void:
	_selected = id
	_recipe = {}
	_message.text = ""
	refresh()


func _show_details() -> void:
	var dim := UITheme.DIM.to_html(false)
	var lines: PackedStringArray = []
	var professions := player.professions
	var has_recipe := not _recipe.is_empty()
	_craft.disabled = not has_recipe or Crafting.blocked_reason(player, _recipe) != ""
	_craft_five.disabled = _craft.disabled
	if has_recipe:
		lines.append("[font_size=20][color=#%s]%s[/color][/font_size]" % [UITheme.HEADING.to_html(false), RecipeDB.display_name(_recipe)])
		lines.append("[color=#%s]%s level %d[/color]" % [dim, Professions.NAMES[_recipe["profession"]], _recipe["level"]])
		if _recipe.has("equipment"):
			lines.append("[color=#%s]Item level %d. Rarity and bonuses are rolled when made; skill improves the odds.[/color]" % [dim, _recipe["item_level"]])
		else:
			lines.append("[i][color=#%s]%s[/color][/i]" % [dim, ItemDB.ITEMS[_recipe["item"]]["text"]])
		lines.append("")
		lines.append("[color=#%s]Needs:[/color]" % dim)
		for item_id: String in _recipe["inputs"]:
			var have := player.inventory.count_of(item_id)
			var need: int = _recipe["inputs"][item_id]
			lines.append("[color=#%s]%d / %d  %s[/color]" % [(UITheme.GOOD if have >= need else UITheme.BAD).to_html(false), have, need, ItemDB.ITEMS[item_id]["name"]])
		var reason := Crafting.blocked_reason(player, _recipe)
		if reason != "":
			lines.append("")
			lines.append("[color=#%s]%s[/color]" % [UITheme.BAD.to_html(false), reason])
	elif _selected in Professions.GATHERING:
		lines.append("[color=#%s]Works %d%% faster. %d%% chance of a double yield.[/color]" % [UITheme.GOOD.to_html(false), roundi((professions.speed_multiplier(_selected) - 1.0) * 100.0), roundi(professions.double_chance(_selected) * 100.0)])
		lines.append("")
		lines.append("[color=#%s]Stand next to a node and press F.[/color]" % dim)
		lines.append("")
		for id: String in GatherDB.RESOURCES:
			var data: Dictionary = GatherDB.RESOURCES[id]
			if GatherDB.KINDS[data["kind"]]["profession"] != _selected:
				continue
			var known: bool = professions.level(_selected) >= data["level"]
			var tool := "" if data["tier"] <= 1 else "  (tier %d tool)" % data["tier"]
			lines.append("[color=#%s]Lv %d  %s%s[/color]" % [(UITheme.TEXT if known else UITheme.DIM).to_html(false), data["level"], GatherDB.display_name(id), tool])
		if _selected == "fishing":
			for fish in GatherDB.FISH:
				lines.append("[color=#%s]Lv %d  %s[/color]" % [(UITheme.TEXT if professions.level("fishing") >= fish[1] else UITheme.DIM).to_html(false), fish[1], ItemDB.ITEMS[fish[0]]["name"]])
	else:
		lines.append("[color=#%s]Pick a recipe on the left.[/color]" % dim)
		if not player.near_crafting_table():
			lines.append("")
			lines.append("[color=#%s]You are not next to a crafting table. Only the table itself can be made by hand.[/color]" % UITheme.BAD.to_html(false))
		if _selected in ["blacksmithing", "enchanting", "salvaging"]:
			lines.append("")
			lines.append("[color=#%s]Upgrade, Enchant, and Salvage are buttons on the Inventory screen: select a piece of equipment there.[/color]" % dim)
	var title := professions.title(_selected)
	if title != "":
		lines.append("")
		lines.append("[color=#%s]Title earned: %s[/color]" % [UITheme.GOLD.to_html(false), title])
	_details.text = "\n".join(lines)


func _make(times: int) -> void:
	if _recipe.is_empty():
		return
	var result := ""
	for i in times:
		result = Crafting.craft(player, _recipe)
		if result != "":
			break
	_message.text = result
	refresh()
