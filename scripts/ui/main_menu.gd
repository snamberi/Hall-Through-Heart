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


## A step of the character creator: [id, title, hint].
const STEPS: Array[Array] = [["look", "Race & Look", "Who they are"], ["class", "Class", "Their calling"], ["world", "World", "Where they wake"]]


func _new_page() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var title := UITheme.heading("HALL THROUGH HEART", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var subtitle := UITheme.label("CHARACTER CREATION", 14, UITheme.DIM)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	box.add_child(body)

	# --- the steps, down the left side
	var steps := VBoxContainer.new()
	steps.add_theme_constant_override("separation", 6)
	body.add_child(steps)
	for index in STEPS.size():
		var step: Array = STEPS[index]
		var button := Button.new()
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(108.0, 70.0)
		button.text = "%d\n%s" % [index + 1, step[1]]
		UITheme.font_size(button, 15)
		button.tooltip_text = step[2]
		button.pressed.connect(_show_step.bind(step[0]))
		UITheme.sounds(button)
		steps.add_child(button)
		_step_buttons[step[0]] = button
	var pages := HBoxContainer.new()
	body.add_child(pages)

	# --- step 1: race, the figure, and every part of the look
	var look := HBoxContainer.new()
	look.add_theme_constant_override("separation", 10)
	pages.add_child(look)
	_step_pages["look"] = look
	var races_panel := UITheme.inset_panel()
	look.add_child(races_panel)
	var races_box := VBoxContainer.new()
	races_box.add_theme_constant_override("separation", 6)
	races_panel.add_child(races_box)
	races_box.add_child(UITheme.heading("Choose a race", 17))
	var races_scroll := ScrollContainer.new()
	races_scroll.custom_minimum_size = Vector2(300.0, 238.0)
	races_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	races_box.add_child(races_scroll)
	var race_grid := GridContainer.new()
	race_grid.columns = 3
	race_grid.add_theme_constant_override("h_separation", 5)
	race_grid.add_theme_constant_override("v_separation", 5)
	races_scroll.add_child(race_grid)
	for race: String in Appearance.RACES:
		var button := Button.new()
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(92.0, 92.0)
		var picture := TextureRect.new()
		picture.texture = AppearanceEditor.race_portrait(race)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 4)
		picture.offset_bottom = -20.0
		button.add_child(picture)
		var name_label := UITheme.label(Appearance.RACES[race]["name"], 14)
		name_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		name_label.offset_top = -22.0
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(name_label)
		button.pressed.connect(func() -> void:
			_editor.choose_race(race)
		)
		UITheme.sounds(button)
		race_grid.add_child(button)
		_race_buttons[race] = button
	_race_info = RichTextLabel.new()
	_race_info.bbcode_enabled = true
	_race_info.fit_content = true
	_race_info.scroll_active = false
	_race_info.custom_minimum_size = Vector2(300.0, 150.0)
	UITheme.font_size(_race_info, 14, "normal_font_size")
	_race_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	races_box.add_child(_race_info)
	# The figure: turn it, roll a new one, see it move.
	var figure_panel := UITheme.inset_panel()
	look.add_child(figure_panel)
	var middle := VBoxContainer.new()
	middle.add_theme_constant_override("separation", 6)
	figure_panel.add_child(middle)
	_figure = LookPreview.new()
	_figure.custom_minimum_size = Vector2(250.0, 290.0)
	middle.add_child(_figure)
	var turn_row := HBoxContainer.new()
	turn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	turn_row.add_theme_constant_override("separation", 6)
	middle.add_child(turn_row)
	turn_row.add_child(UITheme.button("<", func() -> void: _figure.turn(), 40.0))
	turn_row.add_child(UITheme.button("Randomise", _randomise, 130.0))
	turn_row.add_child(UITheme.button(">", func() -> void: _figure.turn(), 40.0))
	middle.add_child(UITheme.label("Preview", 14, UITheme.DIM))
	var poses := HBoxContainer.new()
	poses.add_theme_constant_override("separation", 2)
	middle.add_child(poses)
	for pose: String in ["idle", "walk", "attack", "hurt"]:
		var small := LookPreview.new()
		small.zoom = 1.5
		small.framed = false
		small.pose = pose
		small.custom_minimum_size = Vector2(61.0, 76.0)
		poses.add_child(small)
		_poses.append(small)
	var count := UITheme.label("%d choices" % Appearance.option_count(), 13, UITheme.DIM)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	middle.add_child(count)
	# Every part of the look.
	var look_panel := UITheme.inset_panel()
	look.add_child(look_panel)
	_editor = AppearanceEditor.new()
	_editor.allow_race = false
	_editor.width = 400.0
	_editor.changed.connect(_on_look_changed)
	look_panel.add_child(_editor)

	# --- step 2: the class
	var class_page := HBoxContainer.new()
	class_page.add_theme_constant_override("separation", 10)
	pages.add_child(class_page)
	_step_pages["class"] = class_page
	var class_panel := UITheme.inset_panel()
	class_page.add_child(class_panel)
	var class_box := VBoxContainer.new()
	class_box.add_theme_constant_override("separation", 6)
	class_panel.add_child(class_box)
	class_box.add_child(UITheme.heading("Choose a class", 17))
	var classes := GridContainer.new()
	classes.columns = 2
	classes.add_theme_constant_override("h_separation", 6)
	classes.add_theme_constant_override("v_separation", 6)
	class_box.add_child(classes)
	for id: String in HeroClasses.CLASSES:
		var data: Dictionary = HeroClasses.CLASSES[id]
		var button := Button.new()
		button.text = "  " + (data["name"] if id != "adventurer" else "Decide later")
		button.icon = ItemDB.icon(data["icon"])
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(240.0, 52.0)
		UITheme.font_size(button, 16)
		button.add_theme_constant_override("icon_max_width", 30)
		button.pressed.connect(_choose_class.bind(id))
		UITheme.sounds(button)
		classes.add_child(button)
		_class_buttons[id] = button
	var class_detail := UITheme.inset_panel()
	class_page.add_child(class_detail)
	var detail_box := VBoxContainer.new()
	class_detail.add_child(detail_box)
	_class_figure = LookPreview.new()
	_class_figure.custom_minimum_size = Vector2(300.0, 220.0)
	_class_figure.pose = "attack"
	detail_box.add_child(_class_figure)
	_class_text = RichTextLabel.new()
	_class_text.bbcode_enabled = true
	_class_text.fit_content = true
	_class_text.scroll_active = false
	_class_text.custom_minimum_size = Vector2(300.0, 180.0)
	UITheme.font_size(_class_text, 14, "normal_font_size")
	_class_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_box.add_child(_class_text)

	# --- step 3: the world
	var world_panel := UITheme.inset_panel()
	pages.add_child(world_panel)
	_step_pages["world"] = world_panel
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	left.custom_minimum_size = Vector2(560.0, 0.0)
	world_panel.add_child(left)
	left.add_child(UITheme.heading("The world", 17))
	left.add_child(UITheme.label("Name", 14, UITheme.DIM))
	_name_field = LineEdit.new()
	_name_field.placeholder_text = "World %d" % (SaveGame.list_slots().size() + 1)
	_name_field.custom_minimum_size = Vector2(560.0, 34.0)
	left.add_child(_name_field)
	left.add_child(UITheme.label("Seed", 14, UITheme.DIM))
	_seed_field = LineEdit.new()
	_seed_field.placeholder_text = "Empty for a random world"
	_seed_field.custom_minimum_size = Vector2(560.0, 34.0)
	left.add_child(_seed_field)
	left.add_child(UITheme.label("Difficulty", 14, UITheme.DIM))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	left.add_child(row)
	for level in Difficulty.LEVELS:
		var button := Button.new()
		button.text = Difficulty.display_name(level)
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(106.0, 36.0)
		UITheme.font_size(button, 15)
		button.pressed.connect(_choose_difficulty.bind(level))
		UITheme.sounds(button)
		row.add_child(button)
		_difficulty_buttons[level] = button
	_difficulty_text = UITheme.label("", 14, UITheme.DIM)
	_difficulty_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	_difficulty_text.custom_minimum_size = Vector2(560.0, 44.0)
	left.add_child(_difficulty_text)
	_hardcore = CheckBox.new()
	_hardcore.text = "Hardcore: one life, always Insane. Dying deletes the world."
	UITheme.font_size(_hardcore, 15)
	_hardcore.toggled.connect(func(on: bool) -> void:
		for level in _difficulty_buttons:
			_difficulty_buttons[level].disabled = on
		_choose_difficulty("insane" if on else "normal")
	)
	left.add_child(_hardcore)
	_summary = RichTextLabel.new()
	_summary.bbcode_enabled = true
	_summary.fit_content = true
	_summary.scroll_active = false
	_summary.custom_minimum_size = Vector2(560.0, 80.0)
	UITheme.font_size(_summary, 15, "normal_font_size")
	_summary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(_summary)

	# --- along the bottom
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	box.add_child(buttons)
	_back_button = UITheme.button("<  Back", _step_back, 180.0)
	buttons.add_child(_back_button)
	buttons.add_child(UITheme.button("Randomise", _randomise, 160.0))
	_next_button = UITheme.button("Next  >", _step_next, 220.0)
	buttons.add_child(_next_button)
	_choose_difficulty("normal")
	_choose_class("adventurer")
	_on_look_changed(_appearance)
	_show_step("look")
	return _framed(box)


## The creator's steps.
var _step := "look"
var _step_buttons: Dictionary[String, Button] = {}
var _step_pages: Dictionary[String, Control] = {}
var _race_buttons: Dictionary[String, Button] = {}
var _race_info: RichTextLabel
var _poses: Array[LookPreview] = []
var _class_figure: LookPreview
var _summary: RichTextLabel
var _back_button: Button
var _next_button: Button


func _show_step(step: String) -> void:
	_step = step
	for id in _step_pages:
		_step_pages[id].visible = id == step
		_step_buttons[id].set_pressed_no_signal(id == step)
	_next_button.text = "Create World  >" if step == "world" else "Next  >"
	_back_button.text = "<  Title" if step == "look" else "<  Back"
	if step == "world":
		_update_summary()


func _step_next() -> void:
	var index := STEPS.map(func(s: Array) -> String: return s[0]).find(_step)
	if index >= STEPS.size() - 1:
		_create()
	else:
		_show_step(STEPS[index + 1][0])


func _step_back() -> void:
	var index := STEPS.map(func(s: Array) -> String: return s[0]).find(_step)
	if index <= 0:
		show_page("home")
	else:
		_show_step(STEPS[index - 1][0])


func _randomise() -> void:
	_appearance = Appearance.random()
	_editor.set_appearance(_appearance)
	_on_look_changed(_appearance)


## The look changed: the figures, the race buttons, the race's words.
func _on_look_changed(look: Dictionary) -> void:
	_appearance = look.duplicate()
	_figure.show_look(_appearance)
	_class_figure.show_look(_appearance)
	for small in _poses:
		small.show_look(_appearance)
		small.play(small.pose)
	var race: String = Appearance.resolved(_appearance)["race"]
	for id in _race_buttons:
		_race_buttons[id].set_pressed_no_signal(id == race)
	_race_info.text = AppearanceEditor.race_text(race)


func _update_summary() -> void:
	var worn := Appearance.resolved(_appearance)
	_summary.text = "[color=#%s]You will begin as a[/color] [color=#%s]%s %s[/color][color=#%s], on %s.[/color]" % [
		UITheme.DIM.to_html(false), UITheme.GOLD.to_html(false), Appearance.RACES[worn["race"]]["name"],
		HeroClasses.CLASSES[_class]["name"] if _class != "adventurer" else "Adventurer", UITheme.DIM.to_html(false),
		"Hardcore" if _hardcore.button_pressed else Difficulty.display_name(_difficulty)]


func _choose_difficulty(level: String) -> void:
	_difficulty = level
	for other in _difficulty_buttons:
		_difficulty_buttons[other].set_pressed_no_signal(other == level)
	_difficulty_text.text = Difficulty.DATA[level]["text"]
	if _hardcore and _hardcore.button_pressed:
		_difficulty_text.text = "One life. When you die the world is deleted. " + Difficulty.DATA["insane"]["text"]


func _choose_class(id: String) -> void:
	_class = id
	if _class_figure:
		_class_figure.play("attack" if id != "adventurer" else "idle")
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
