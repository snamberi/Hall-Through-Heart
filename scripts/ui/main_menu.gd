extends Control
## The title screen: continue the last world, pick another from the save
## list, make a new world with a difficulty, change settings, or quit.

const GAME := "res://scenes/main.tscn"

var _pages: Dictionary[String, Control] = {}
var _save_list: VBoxContainer
var _name_field: LineEdit
var _seed_field: LineEdit
var _difficulty := "normal"
var _appearance: Dictionary = Appearance.DEFAULT.duplicate()
var _difficulty_buttons: Dictionary[String, Button] = {}
var _difficulty_text: Label
var _armed_delete := ""
var _hardcore: CheckBox
var _class := "adventurer"
var _class_buttons: Dictionary[String, Button] = {}
var _class_text: RichTextLabel
var _figure: LookPreview
var _editor: AppearanceEditor


func _ready() -> void:
	theme = UITheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().paused = false
	Engine.time_scale = 1.0
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var stack := Control.new()
	center.add_child(stack)
	_pages["home"] = _home_page()
	_pages["load"] = _load_page()
	_pages["new"] = _new_page()
	var settings := SettingsPanel.new()
	settings.closed.connect(show_page.bind("home"))
	_pages["settings"] = _framed(settings)
	for page: Control in _pages.values():
		center.add_child(page)
	stack.queue_free()
	show_page("home")


func show_page(page: String) -> void:
	_armed_delete = ""
	for name in _pages:
		_pages[name].visible = name == page
	if page == "load":
		_fill_save_list()


func _draw() -> void:
	# A dark field with a faint glow where the heart would be.
	draw_rect(Rect2(Vector2.ZERO, size), Color("0a0c14"))
	var middle := Vector2(size.x / 2.0, size.y * 0.3)
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 900.0)
	for ring in 9:
		draw_circle(middle, 420.0 - ring * 44.0, Color(0.45, 0.08, 0.12, 0.03 + 0.01 * pulse))


func _process(_delta: float) -> void:
	queue_redraw()
	# A page too big for a small window (or a large interface size) shrinks to fit.
	var room := get_viewport().get_visible_rect().size - Vector2(24.0, 24.0)
	for page: Control in _pages.values():
		if page.visible:
			var need := page.get_combined_minimum_size()
			var fit := minf(1.0, minf(room.x / maxf(need.x, 1.0), room.y / maxf(need.y, 1.0)))
			page.pivot_offset = page.size / 2.0
			page.scale = Vector2(fit, fit)


func _framed(inner: Control) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_child(inner)
	return panel


func _home_page() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	var title := UITheme.heading("Hall Through Heart", 64)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var line := UITheme.label("The land is the corpse of a god. Its heart still beats.", 18, UITheme.DIM)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(line)
	var gap := Control.new()
	gap.custom_minimum_size.y = 24.0
	box.add_child(gap)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(panel)
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	panel.add_child(buttons)
	var last := GameSettings.last_slot
	if SaveGame.has_slot(last):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SaveGame.DIRECTORY.path_join(last + ".json")))
		var meta: Dictionary = parsed.get("meta", {}) if parsed is Dictionary else {}
		var resume := UITheme.button("Continue  -  %s" % meta.get("name", "your world"), _play.bind(last), 320.0)
		buttons.add_child(resume)
	if not SaveGame.list_slots().is_empty():
		buttons.add_child(UITheme.button("Load a World", show_page.bind("load"), 320.0))
	buttons.add_child(UITheme.button("New World", show_page.bind("new"), 320.0))
	buttons.add_child(UITheme.button("Settings", show_page.bind("settings"), 320.0))
	buttons.add_child(UITheme.button("Quit", get_tree().quit, 320.0))
	return box


func _load_page() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	var title := UITheme.heading("YOUR WORLDS", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(720.0, 420.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_save_list = VBoxContainer.new()
	_save_list.add_theme_constant_override("separation", 8)
	_save_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_save_list)
	var back := UITheme.button("Back", show_page.bind("home"), 200.0)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(back)
	return _framed(box)


func _fill_save_list() -> void:
	for child in _save_list.get_children():
		child.queue_free()
	for slot in SaveGame.list_slots():
		var meta: Dictionary = slot["meta"]
		var card := UITheme.inset_panel()
		_save_list.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		var heading := UITheme.heading(str(meta.get("name", "World")), 20)
		if slot["id"] == GameSettings.last_slot:
			heading.text += "   (last played)"
		text.add_child(heading)
		var played := Time.get_datetime_string_from_unix_time(int(meta.get("played_at", 0)), true)
		var race := str(Appearance.RACES.get(str((meta.get("appearance", {}) as Dictionary).get("race", "human")), Appearance.RACES["human"])["name"])
		var calling := str(HeroClasses.CLASSES.get(str(meta.get("class", meta.get("class_id", "adventurer"))), HeroClasses.CLASSES["adventurer"])["name"])
		text.add_child(UITheme.label("%s%s  -  %s %s  -  Level %d  -  Day %d  -  last played %s" % [
			"HARDCORE  -  " if meta.get("hardcore", false) else "", Difficulty.display_name(str(meta.get("difficulty", "normal"))), race, calling,
			int(meta.get("level", 1)), int(meta.get("day", 1)), played], 14, UITheme.BAD if meta.get("hardcore", false) else UITheme.DIM))
		var play := UITheme.button("Play", _play.bind(slot["id"]), 100.0)
		play.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(play)
		var delete := UITheme.button("Delete", func() -> void: _delete(slot["id"]), 100.0)
		delete.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		delete.name = "Delete"
		row.add_child(delete)
		if _armed_delete == slot["id"]:
			delete.text = "Sure?"
			delete.add_theme_color_override("font_color", UITheme.BAD)


func _delete(id: String) -> void:
	if _armed_delete != id:
		_armed_delete = id
	else:
		_armed_delete = ""
		SaveGame.delete_slot(id)
	_fill_save_list()


func _new_page() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var title := UITheme.heading("NEW WORLD", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	box.add_child(columns)

	# --- left: the world, and the class
	var world_panel := UITheme.inset_panel()
	columns.add_child(world_panel)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	left.custom_minimum_size = Vector2(330.0, 0.0)
	world_panel.add_child(left)
	left.add_child(UITheme.heading("The world", 17))
	_name_field = LineEdit.new()
	_name_field.placeholder_text = "World %d" % (SaveGame.list_slots().size() + 1)
	_name_field.custom_minimum_size = Vector2(330.0, 32.0)
	left.add_child(_name_field)
	_seed_field = LineEdit.new()
	_seed_field.placeholder_text = "Seed (empty for a random world)"
	_seed_field.custom_minimum_size = Vector2(330.0, 32.0)
	left.add_child(_seed_field)
	left.add_child(UITheme.label("Difficulty", 14, UITheme.DIM))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 4)
	row.add_theme_constant_override("v_separation", 4)
	left.add_child(row)
	for level in Difficulty.LEVELS:
		var button := Button.new()
		button.text = Difficulty.display_name(level)
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(62.0, 32.0)
		button.add_theme_font_size_override("font_size", 13)
		button.pressed.connect(_choose_difficulty.bind(level))
		UITheme.sounds(button)
		row.add_child(button)
		_difficulty_buttons[level] = button
	_hardcore = CheckBox.new()
	_hardcore.text = "Hardcore: one life, always Insane"
	_hardcore.focus_mode = Control.FOCUS_NONE
	_hardcore.add_theme_font_size_override("font_size", 14)
	_hardcore.toggled.connect(func(on: bool) -> void:
		for level in _difficulty_buttons:
			_difficulty_buttons[level].disabled = on
		_choose_difficulty("insane" if on else "normal")
	)
	left.add_child(_hardcore)
	_difficulty_text = UITheme.label("", 13, UITheme.DIM)
	_difficulty_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	_difficulty_text.custom_minimum_size = Vector2(330.0, 36.0)
	left.add_child(_difficulty_text)
	left.add_child(UITheme.heading("Your class", 17))
	var classes := GridContainer.new()
	classes.columns = 2
	classes.add_theme_constant_override("h_separation", 4)
	classes.add_theme_constant_override("v_separation", 4)
	left.add_child(classes)
	for id: String in HeroClasses.CLASSES:
		var data: Dictionary = HeroClasses.CLASSES[id]
		var button := Button.new()
		button.text = "  " + (data["name"] if id != "adventurer" else "Decide later")
		button.icon = ItemDB.icon(data["icon"])
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(163.0, 34.0)
		button.add_theme_font_size_override("font_size", 14)
		button.add_theme_constant_override("icon_max_width", 20)
		button.pressed.connect(_choose_class.bind(id))
		UITheme.sounds(button)
		classes.add_child(button)
		_class_buttons[id] = button
	_class_text = RichTextLabel.new()
	_class_text.bbcode_enabled = true
	_class_text.fit_content = true
	_class_text.scroll_active = false
	_class_text.custom_minimum_size = Vector2(330.0, 92.0)
	_class_text.add_theme_font_size_override("normal_font_size", 14)
	_class_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(_class_text)

	# --- middle: the character, alive
	var figure_panel := UITheme.inset_panel()
	columns.add_child(figure_panel)
	var middle := VBoxContainer.new()
	middle.add_theme_constant_override("separation", 8)
	figure_panel.add_child(middle)
	_figure = LookPreview.new()
	_figure.custom_minimum_size = Vector2(270.0, 356.0)
	middle.add_child(_figure)
	var figure_buttons := HBoxContainer.new()
	figure_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	figure_buttons.add_theme_constant_override("separation", 6)
	middle.add_child(figure_buttons)
	figure_buttons.add_child(UITheme.button("Randomise", func() -> void:
		_appearance = Appearance.random()
		_editor.set_appearance(_appearance)
		_figure.show_look(_appearance)
	, 130.0))
	var walk := Button.new()
	walk.text = "Walk"
	walk.toggle_mode = true
	walk.focus_mode = Control.FOCUS_NONE
	walk.custom_minimum_size = Vector2(90.0, 32.0)
	walk.toggled.connect(func(on: bool) -> void: _figure.set_walking(on))
	UITheme.sounds(walk)
	figure_buttons.add_child(walk)
	var count := UITheme.label("%d choices to make them yours" % Appearance.option_count(), 12, UITheme.DIM)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	middle.add_child(count)

	# --- right: every part of their look
	var look_panel := UITheme.inset_panel()
	columns.add_child(look_panel)
	_editor = AppearanceEditor.new()
	_editor.changed.connect(func(look: Dictionary) -> void:
		_appearance = look.duplicate()
		_figure.show_look(_appearance)
	)
	look_panel.add_child(_editor)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	box.add_child(buttons)
	buttons.add_child(UITheme.button("Back", show_page.bind("home"), 200.0))
	buttons.add_child(UITheme.button("Create World", _create, 200.0))
	_choose_difficulty("normal")
	_choose_class("adventurer")
	return _framed(box)


func _choose_difficulty(level: String) -> void:
	_difficulty = level
	for other in _difficulty_buttons:
		_difficulty_buttons[other].set_pressed_no_signal(other == level)
	_difficulty_text.text = Difficulty.DATA[level]["text"]
	if _hardcore and _hardcore.button_pressed:
		_difficulty_text.text = "One life. When you die the world is deleted. " + Difficulty.DATA["insane"]["text"]


func _choose_class(id: String) -> void:
	_class = id
	for other in _class_buttons:
		_class_buttons[other].set_pressed_no_signal(other == id)
	var data: Dictionary = HeroClasses.CLASSES[id]
	var lines: PackedStringArray = []
	if id == "adventurer":
		lines.append("[color=#%s]Start as an Adventurer and choose a class at level %d, in the Class screen.[/color]" % [UITheme.DIM.to_html(false), HeroClasses.CHOICE_LEVEL])
	else:
		lines.append("[color=#%s]%s[/color]" % [UITheme.TEXT.to_html(false), data["text"]])
		for stat: String in data["mods"]:
			for kind: String in data["mods"][stat]:
				lines.append("[color=#%s]%s[/color]" % [UITheme.GOOD.to_html(false), ItemDB.describe_modifier({"stat": stat, "kind": kind, "value": data["mods"][stat][kind]})])
		var weapons: PackedStringArray = []
		for weapon: String in data["weapons"]:
			weapons.append(weapon.capitalize())
		lines.append("[color=#%s]Favours %s. Its abilities open from level %d.[/color]" % [UITheme.DIM.to_html(false), ", ".join(weapons).to_lower(), HeroClasses.CHOICE_LEVEL])
	_class_text.text = "\n".join(lines)


func _create() -> void:
	var world_name := _name_field.text.strip_edges()
	if world_name == "":
		world_name = _name_field.placeholder_text
	var seed_text := _seed_field.text.strip_edges()
	var world_seed := 0
	if seed_text != "":
		world_seed = int(seed_text) if seed_text.is_valid_int() else hash(seed_text)
	var id := SaveGame.create_slot(world_name, _difficulty, world_seed, _appearance, _class, _hardcore.button_pressed)
	_play(id)


func _play(id: String) -> void:
	SaveGame.use_slot(id)
	get_tree().change_scene_to_file(GAME)
