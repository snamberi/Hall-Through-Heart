extends Control
## The title screen: continue, start over, adjust the sound, or leave.

const GAME := "res://scenes/main.tscn"

var _status: Label
var _new_game: Button
var _armed := false


func _ready() -> void:
	theme = UITheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().paused = false
	SaveGame.reload()

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)

	var title := UITheme.heading("Hall Through Heart", 64)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var line := UITheme.label("The land is the corpse of a god. Its heart still beats.", 18, UITheme.DIM)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(line)
	var gap := Control.new()
	gap.custom_minimum_size.y = 28.0
	box.add_child(gap)

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(panel)
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	panel.add_child(buttons)
	var has_save := SaveGame.has_save()
	if has_save:
		buttons.add_child(UITheme.button("Continue", _play, 300.0))
	_new_game = UITheme.button("New game", _on_new_game.bind(has_save), 300.0)
	buttons.add_child(_new_game)
	for setting: Array in [["music_volume", "Music"], ["sfx_volume", "Sound effects"]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var name_label := UITheme.label(setting[1], 15)
		name_label.custom_minimum_size.x = 110.0
		row.add_child(name_label)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = GameSettings.get(setting[0])
		slider.custom_minimum_size = Vector2(180.0, 22.0)
		slider.focus_mode = Control.FOCUS_NONE
		slider.value_changed.connect(func(value: float) -> void: GameSettings.set_value(setting[0], value))
		row.add_child(slider)
		buttons.add_child(row)
	buttons.add_child(UITheme.button("Quit", get_tree().quit, 300.0))
	_status = UITheme.label("", 14, UITheme.BAD)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_status)


func _draw() -> void:
	# A dark field with a faint glow where the heart would be.
	draw_rect(Rect2(Vector2.ZERO, size), Color("0a0c14"))
	var middle := Vector2(size.x / 2.0, size.y * 0.3)
	for ring in 9:
		draw_circle(middle, 420.0 - ring * 44.0, Color(0.45, 0.08, 0.12, 0.035))


func _play() -> void:
	get_tree().change_scene_to_file(GAME)


func _on_new_game(has_save: bool) -> void:
	if has_save and not _armed:
		_armed = true
		_new_game.text = "Click again to erase your save"
		_status.text = "Starting over deletes your character and world."
		return
	SaveGame.delete_save()
	_play()
