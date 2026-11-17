extends Control
## The title screen: continue the last world, pick another from the save
## list, make a new world with a difficulty, change settings, or quit.

const GAME := "res://scenes/main.tscn"
## The logo and the panorama behind everything (tools/generate_title.py):
## the sky stands still; the layers in front drift past at their own pace,
## a screen pixel at a time (so they glide rather than hop a whole art
## pixel at once), wrapping round.
const LOGO: Texture2D = preload("res://assets/ui/logo.png")
const SKY: Texture2D = preload("res://assets/ui/title_sky.png")
const SKY_SIZE := Vector2(427, 240)
const LAYER_WIDTH := 640.0
## [picture, art pixels a second]
const LAYERS := [
	[preload("res://assets/ui/title_far.png"), 1.5],
	[preload("res://assets/ui/title_hills.png"), 4.0],
	[preload("res://assets/ui/title_woods.png"), 10.0],
]

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
var _class := "warrior"
var _class_buttons: Dictionary[String, Button] = {}
var _class_text: RichTextLabel
var _figure: LookPreview
var _editor: AppearanceEditor


func _ready() -> void:
	theme = UITheme.get_theme()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
	# The night over the land, at the largest whole scale that fills the
	# window (cropped evenly), so each art pixel is a square of screen ones.
	var now := Time.get_ticks_msec() / 1000.0
	var scale := ceilf(maxf(size.y / SKY_SIZE.y, size.x / SKY_SIZE.x))
	var view := SKY_SIZE * scale
	var origin := ((size - view) / 2.0).floor()
	draw_rect(Rect2(Vector2.ZERO, size), Color("05070e"))
	draw_texture_rect(SKY, Rect2(origin, view), false)
	# A faint glow low in the sky, beating with the heart under the land.
	var beat := _beat(now)
	var middle := Vector2(size.x / 2.0, origin.y + 168.0 * scale)
	for ring in 7:
		draw_circle(middle, (150.0 - ring * 18.0 + beat * 4.0) * scale, Color(0.5, 0.08, 0.14, 0.025 + 0.012 * beat))
	for layer: Array in LAYERS:
		var picture: Texture2D = layer[0]
		var width := LAYER_WIDTH * scale
		var shift := fmod(floorf(now * float(layer[1]) * scale), width)
		var x := origin.x - shift
		while x < size.x:
			draw_texture_rect(picture, Rect2(Vector2(x, origin.y), Vector2(width, view.y)), false)
			x += width
	# Embers rising from the woods.
	for index in 24:
		var seed := float(index) * 37.13
		var drift := fmod(now * (0.02 + fmod(seed, 0.03)) + fmod(seed, 1.0), 1.0)
		var at := Vector2(fmod(seed * 91.7, size.x), size.y * 0.92 - drift * size.y * 0.7)
		draw_rect(Rect2(at.floor(), Vector2(scale, scale)), Color(1.0, 0.55, 0.3, 0.55 * (1.0 - drift)))


## The heartbeat: two quick thumps, then a rest (0 to 1).
static func _beat(now: float) -> float:
	var t := fmod(now, 1.4)
	return maxf(exp(-pow((t - 0.1) / 0.06, 2.0)), 0.7 * exp(-pow((t - 0.32) / 0.06, 2.0)))


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
	# The logo, drawn pixel by pixel, at three screen pixels to each of its own.
	var title := TextureRect.new()
	title.texture = LOGO
	title.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	title.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title.stretch_mode = TextureRect.STRETCH_SCALE
	title.custom_minimum_size = LOGO.get_size() * 3.0
	title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(title)
	var line := UITheme.label("The land is the corpse of a god. Its heart still beats.", 18, Color("c8c0b0"))
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Dark-edged, so it reads over the sky and the mountains behind.
	line.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.05, 0.95))
	line.add_theme_constant_override("outline_size", 6)
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
	# One way in: Play opens your worlds, with a new one at the bottom.
	var play := UITheme.primary_button("PLAY", show_page.bind("load"), 320.0)
	play.custom_minimum_size.y = 56.0
	UITheme.font_size(play, 24)
	buttons.add_child(play)
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
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(bottom)
	bottom.add_child(UITheme.button("Back", show_page.bind("home"), 160.0))
	bottom.add_child(UITheme.primary_button("+  Create New World", show_page.bind("new"), 300.0))
	return _framed(box)


func _fill_save_list() -> void:
	for child in _save_list.get_children():
		child.queue_free()
	if SaveGame.list_slots().is_empty():
		var none := UITheme.label("No worlds yet. Create one below.", 16, UITheme.DIM)
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_save_list.add_child(none)
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
		var backups := SaveGame.backups_for(slot["id"])
		var history := UITheme.button("Backups (%d)" % backups.size(), func() -> void:
			_backups_open = "" if _backups_open == slot["id"] else slot["id"]
			_fill_save_list()
		, 120.0)
		history.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		history.disabled = backups.is_empty()
		history.tooltip_text = "Copies of this world saved every ten minutes of play. The newest five are kept."
		row.add_child(history)
		var delete := UITheme.button("Delete", func() -> void: _delete(slot["id"]), 100.0)
		delete.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		delete.name = "Delete"
		row.add_child(delete)
		if _armed_delete == slot["id"]:
			delete.text = "Sure?"
			delete.add_theme_color_override("font_color", UITheme.BAD)
		# The world's backups, each with a button to bring it back.
		if _backups_open == slot["id"]:
			var list := VBoxContainer.new()
			list.add_theme_constant_override("separation", 4)
			_save_list.add_child(list)
			for backup: Dictionary in backups:
				var line := HBoxContainer.new()
				line.add_theme_constant_override("separation", 10)
				list.add_child(line)
				var words := UITheme.label("      %s   -   Level %d  -  Day %d" % [backup["when"], backup["level"], backup["day"]], 15, UITheme.TEXT)
				words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				line.add_child(words)
				var key := "%s|%s" % [slot["id"], backup["file"]]
				var restore := UITheme.button("Sure? Restore" if _armed_restore == key else "Restore", func() -> void:
					if _armed_restore != key:
						_armed_restore = key
					else:
						_armed_restore = ""
						SaveGame.restore_backup(slot["id"], backup["file"])
						_backups_open = ""
					_fill_save_list()
				, 130.0)
				line.add_child(restore)


## The world whose backups are listed, and a restore waiting to be confirmed.
var _backups_open := ""
var _armed_restore := ""


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
	# --- the steps, as one line: 1 Look > 2 Class > 3 World
	var steps := HBoxContainer.new()
	steps.alignment = BoxContainer.ALIGNMENT_CENTER
	steps.add_theme_constant_override("separation", 8)
	box.add_child(steps)
	for index in STEPS.size():
		var step: Array = STEPS[index]
		if index > 0:
			var arrow := UITheme.strong(">", 18, UITheme.DIM)
			arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			steps.add_child(arrow)
		var button := UITheme.button("%d  %s" % [index + 1, step[1]], _show_step.bind(step[0]), 170.0)
		button.toggle_mode = true
		button.tooltip_text = step[2]
		steps.add_child(button)
		_step_buttons[step[0]] = button
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	box.add_child(body)
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
	var roll := UITheme.button("Randomise look", _randomise_look, 150.0)
	roll.tooltip_text = "New colours, hair and clothes. Keeps your race."
	turn_row.add_child(roll)
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
	for id: String in HeroClasses.CHOICES:
		var data: Dictionary = HeroClasses.CLASSES[id]
		var button := Button.new()
		button.text = "  " + data["name"]
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
	_class_text.custom_minimum_size = Vector2(320.0, 150.0)
	UITheme.font_size(_class_text, 15, "normal_font_size")
	_class_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_box.add_child(_class_text)
	_class_skills = HBoxContainer.new()
	_class_skills.add_theme_constant_override("separation", 8)
	detail_box.add_child(_class_skills)

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
	_name_field.text_changed.connect(func(_text: String) -> void: _update_summary())
	left.add_child(_name_field)
	left.add_child(UITheme.label("Seed", 14, UITheme.DIM))
	_seed_field = LineEdit.new()
	_seed_field.placeholder_text = "Empty for a random world"
	_seed_field.custom_minimum_size = Vector2(560.0, 34.0)
	_seed_field.text_changed.connect(func(_text: String) -> void: _update_summary())
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
	_difficulty_text.custom_minimum_size = Vector2(560.0, 46.0)
	left.add_child(_difficulty_text)
	var hardcore_card := PanelContainer.new()
	hardcore_card.add_theme_stylebox_override("panel", UITheme.card("card", 8))
	left.add_child(hardcore_card)
	var hardcore_box := VBoxContainer.new()
	hardcore_box.add_theme_constant_override("separation", 2)
	hardcore_card.add_child(hardcore_box)
	_hardcore = CheckBox.new()
	_hardcore.text = "Hardcore"
	UITheme.font_size(_hardcore, 17)
	hardcore_box.add_child(_hardcore)
	hardcore_box.add_child(UITheme.paragraph("One life, always Insane. When you die, this world is deleted for good.", 520.0, 15, Color("e8a070")))
	_hardcore.toggled.connect(func(on: bool) -> void:
		for level in _difficulty_buttons:
			_difficulty_buttons[level].disabled = on
		_choose_difficulty("insane" if on else "normal")
	)
	_summary = RichTextLabel.new()
	_summary.bbcode_enabled = true
	_summary.fit_content = true
	_summary.scroll_active = false
	_summary.custom_minimum_size = Vector2(560.0, 96.0)
	UITheme.font_size(_summary, 15, "normal_font_size")
	_summary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(_summary)

	# --- along the bottom
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	box.add_child(buttons)
	_back_button = UITheme.button("<  Back", _step_back, 140.0)
	_back_button.flat = true
	buttons.add_child(_back_button)
	var roll_all := UITheme.button("Randomise all", _randomise_all, 170.0)
	roll_all.tooltip_text = "A new race, look and class at once."
	buttons.add_child(roll_all)
	_undo_button = UITheme.button("Undo", _undo, 100.0)
	_undo_button.tooltip_text = "Back to how it was before the last Randomise."
	_undo_button.disabled = true
	buttons.add_child(_undo_button)
	_next_button = UITheme.primary_button("Next  >", _step_next, 240.0)
	buttons.add_child(_next_button)
	_choose_difficulty("normal")
	_choose_class("warrior")
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
var _undo_button: Button
var _class_skills: HBoxContainer
## What Undo puts back: [appearance, class] before each Randomise.
var _history: Array = []


func _show_step(step: String) -> void:
	_step = step
	for id in _step_pages:
		_step_pages[id].visible = id == step
		_step_buttons[id].set_pressed_no_signal(id == step)
	_next_button.text = "Create World  >" if step == "world" else "Next  >"
	_back_button.text = "<  Worlds" if step == "look" else "<  Back"
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
		show_page("load")
	else:
		_show_step(STEPS[index - 1][0])


## New colours, hair and clothes; the race stays.
func _randomise_look() -> void:
	_remember()
	var race: String = Appearance.resolved(_appearance)["race"]
	var look := Appearance.random()
	for attempt in 40:
		if Appearance.resolved(look)["race"] == race:
			break
		look = Appearance.random()
	if Appearance.resolved(look)["race"] != race:
		look["race"] = race
	_set_look(look)


## A new race, look and class.
func _randomise_all() -> void:
	_remember()
	_set_look(Appearance.random())
	_choose_class(HeroClasses.CHOICES.pick_random())


func _remember() -> void:
	_history.append([_appearance.duplicate(), _class])
	if _history.size() > 20:
		_history.pop_front()
	_undo_button.disabled = false


func _undo() -> void:
	if _history.is_empty():
		return
	var last: Array = _history.pop_back()
	_set_look(last[0])
	_choose_class(last[1])
	_undo_button.disabled = _history.is_empty()


func _set_look(look: Dictionary) -> void:
	_appearance = look
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
	if _summary == null or _hardcore == null:
		return
	var worn := Appearance.resolved(_appearance)
	var dim := UITheme.DIM.to_html(false)
	var gold := UITheme.GOLD.to_html(false)
	var world_name := _name_field.text.strip_edges() if _name_field.text.strip_edges() != "" else _name_field.placeholder_text
	var seed_words := _seed_field.text.strip_edges() if _seed_field.text.strip_edges() != "" else "random"
	var lines: PackedStringArray = []
	lines.append("[color=#%s]Race[/color]  [color=#%s]%s[/color]  [color=#%s](for life)[/color]" % [dim, gold, Appearance.RACES[worn["race"]]["name"], dim])
	lines.append("[color=#%s]Class[/color]  [color=#%s]%s[/color]  [color=#%s](for life; its first ability is yours from the start)[/color]" % [dim, gold, HeroClasses.CLASSES[_class]["name"], dim])
	lines.append("[color=#%s]World[/color]  [color=#%s]%s[/color]  [color=#%s]·  seed %s  ·[/color]  [color=#%s]%s[/color]" % [dim, gold, world_name, dim, seed_words,
		UITheme.BAD.to_html(false) if _hardcore.button_pressed else gold, "Hardcore (Insane)" if _hardcore.button_pressed else Difficulty.display_name(_difficulty)])
	_summary.text = "\n".join(lines)


func _choose_difficulty(level: String) -> void:
	_difficulty = level
	for other in _difficulty_buttons:
		_difficulty_buttons[other].set_pressed_no_signal(other == level)
	var data: Dictionary = Difficulty.DATA[level]
	_difficulty_text.text = "%s\nMonster damage x%s, health x%s  ·  XP x%s, loot x%s  ·  dying costs %d%%" % [data["text"], str(data["damage"]), str(data["health"]), str(data["xp"]), str(data["loot"]), roundi(float(data["death_loss"]) * 100.0)]
	if _hardcore and _hardcore.button_pressed:
		_difficulty_text.text = "One life: when you die the world is deleted.\n" + _difficulty_text.text
	_update_summary()


func _choose_class(id: String) -> void:
	_class = id
	if _class_figure:
		_class_figure.play("attack" if id != "adventurer" else "idle")
	for other in _class_buttons:
		_class_buttons[other].set_pressed_no_signal(other == id)
	var data: Dictionary = HeroClasses.CLASSES[id]
	var lines: PackedStringArray = []
	if id == "adventurer":
		lines.append("[color=#%s]Decide later[/color]" % UITheme.HEADING.to_html(false))
		lines.append("[color=#%s]Start as an Adventurer with no class bonuses. At level %d the Class screen lets you choose one for good, once you know how you like to fight.[/color]" % [UITheme.TEXT.to_html(false), HeroClasses.CHOICE_LEVEL])
	else:
		lines.append("[color=#%s]%s[/color]  [color=#%s]·  for life[/color]" % [UITheme.HEADING.to_html(false), data["name"], UITheme.DIM.to_html(false)])
		lines.append("[color=#%s]%s[/color]" % [UITheme.TEXT.to_html(false), data["text"]])
		for stat: String in data["mods"]:
			for kind: String in data["mods"][stat]:
				lines.append("[color=#%s]%s[/color]" % [UITheme.GOOD.to_html(false), ItemDB.describe_modifier({"stat": stat, "kind": kind, "value": data["mods"][stat][kind]})])
		var weapons: PackedStringArray = []
		for weapon: String in data["weapons"]:
			weapons.append(weapon.capitalize())
		var penalty := HeroClasses.off_class_penalty("normal")
		lines.append("[color=#%s]Trains with %s (+%d%% damage). Any other weapon: %d%% damage, %d%% slower (on Normal).[/color]" % [UITheme.DIM.to_html(false), ", ".join(weapons).to_lower(),
			roundi(HeroClasses.WEAPON_BONUS * 100.0), roundi(float(penalty[0]) * 100.0), roundi(float(penalty[1]) * 100.0)])
		var kit: PackedStringArray = []
		for entry: Array in data.get("kit", []):
			if ItemDB.ITEMS.has(entry[0]):
				kit.append(("%s x%d" % [ItemDB.ITEMS[entry[0]]["name"], int(entry[1])]) if int(entry[1]) > 1 else str(ItemDB.ITEMS[entry[0]]["name"]))
		lines.append("[color=#%s]Starts with: %s.[/color]" % [UITheme.INFO.to_html(false), ", ".join(kit)])
		lines.append("[color=#%s]Class abilities, opening as the class levels up:[/color]" % UITheme.DIM.to_html(false))
	_class_text.text = "\n".join(lines)
	if _class_skills:
		for child in _class_skills.get_children():
			child.queue_free()
		if id != "adventurer" and HeroClasses.TREES.has(id):
			for entry: Array in HeroClasses.TREES[id]["abilities"]:
				var cell := VBoxContainer.new()
				cell.add_theme_constant_override("separation", 0)
				cell.custom_minimum_size.x = 74.0
				var picture := TextureRect.new()
				picture.texture = AbilityDB.icon(entry[0])
				picture.custom_minimum_size = Vector2(32, 32)
				picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				picture.tooltip_text = AbilityDB.ABILITIES[entry[0]]["text"]
				cell.add_child(picture)
				var name_label := UITheme.label(AbilityDB.ABILITIES[entry[0]]["name"], 14, UITheme.INFO)
				name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
				name_label.custom_minimum_size.x = 74.0
				cell.add_child(name_label)
				_class_skills.add_child(cell)
	_update_summary()


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
