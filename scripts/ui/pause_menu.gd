class_name PauseMenu
extends GameMenu
## The pause menu (Esc): resume, settings, save and quit, and the controls.

const CONTROLS: Array[Array] = [
	["Move", "W A S D or arrow keys"],
	["Attack", "Left mouse button (aims at the cursor)"],
	["Dodge", "Space or Shift"],
	["Abilities", "1  2  3  4  5"],
	["Gather / interact", "F"],
	["Drink health potion", "Q"],
	["Menu wheel", "M or Tab"],
	["Inventory", "E"],
	["Attributes / Talents / Professions", "C / K / P"],
	["Pause", "Esc"],
	["Debug screen", "F3"],
]

var _status: Label
var _new_game: Button
var _armed := false
var _sliders: Dictionary[String, HSlider] = {}
var _percent: Dictionary[String, Label] = {}
var _minimap: CheckBox
var _helmet: CheckBox


func _build() -> void:
	var title := UITheme.heading("Paused", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 44)
	content.add_child(columns)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	columns.add_child(left)
	left.add_child(UITheme.button("Resume", _close, 240.0))
	left.add_child(UITheme.button("Save", _save, 240.0))
	left.add_child(UITheme.button("Save & Quit", _quit, 240.0))
	_new_game = UITheme.button("New game", _on_new_game, 240.0)
	left.add_child(_new_game)
	_status = UITheme.label("", 14, UITheme.DIM)
	_status.custom_minimum_size = Vector2(240.0, 60.0)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	left.add_child(_status)

	var middle := VBoxContainer.new()
	middle.add_theme_constant_override("separation", 10)
	columns.add_child(middle)
	middle.add_child(UITheme.heading("Settings"))
	_add_slider(middle, "music_volume", "Music")
	_add_slider(middle, "sfx_volume", "Sound effects")
	_minimap = _add_check(middle, "Show minimap", func(on: bool) -> void: GameSettings.set_value("show_minimap", on))
	_helmet = _add_check(middle, "Show helmet on character", func(on: bool) -> void: player.show_helmet = on)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	columns.add_child(right)
	right.add_child(UITheme.heading("Controls"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 3)
	right.add_child(grid)
	for row in CONTROLS:
		grid.add_child(UITheme.label(row[0], 14, UITheme.DIM))
		grid.add_child(UITheme.label(row[1], 14))


func refresh() -> void:
	_armed = false
	_new_game.text = "New game"
	_status.text = "The game saves by itself every 30 seconds and when you quit."
	for setting in _sliders:
		_sliders[setting].set_value_no_signal(GameSettings.get(setting))
		_percent[setting].text = "%d%%" % roundi(GameSettings.get(setting) * 100.0)
	_minimap.set_pressed_no_signal(GameSettings.show_minimap)
	_helmet.set_pressed_no_signal(player.show_helmet)


func _add_slider(parent: Control, setting: String, title: String) -> void:
	parent.add_child(UITheme.label(title, 15))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.custom_minimum_size = Vector2(220.0, 22.0)
	slider.focus_mode = Control.FOCUS_NONE
	var percent := UITheme.label("", 15, UITheme.GOLD)
	percent.custom_minimum_size.x = 48.0
	slider.value_changed.connect(func(value: float) -> void:
		GameSettings.set_value(setting, value)
		percent.text = "%d%%" % roundi(value * 100.0)
		if setting == "sfx_volume":
			Audio.play("pickup")
	)
	row.add_child(slider)
	row.add_child(percent)
	parent.add_child(row)
	_sliders[setting] = slider
	_percent[setting] = percent


func _add_check(parent: Control, title: String, on_toggled: Callable) -> CheckBox:
	var box := CheckBox.new()
	box.text = title
	box.focus_mode = Control.FOCUS_NONE
	box.toggled.connect(on_toggled)
	parent.add_child(box)
	return box


func _close() -> void:
	var node := get_parent()
	while node and not node.has_method("close"):
		node = node.get_parent()
	if node:
		node.close()


func _save() -> void:
	SaveGame.save_now()
	_status.text = "Saved."


func _quit() -> void:
	SaveGame.save_now()
	get_tree().quit()


func _on_new_game() -> void:
	if not _armed:
		_armed = true
		_new_game.text = "Click again to erase everything"
		_status.text = "This deletes your character and world. It cannot be undone."
		return
	SaveGame.delete_save()
	get_tree().paused = false
	get_tree().reload_current_scene()
