class_name SettingsPanel
extends VBoxContainer
## Every setting, in tabs: Audio, Display, Gameplay, and Controls (with key
## rebinding). Used on the title screen and in the pause menu.

signal closed

const TABS: Array[String] = ["Audio", "Display", "Gameplay", "Controls"]

var _pages: Dictionary[String, Control] = {}
var _tab_buttons: Dictionary[String, Button] = {}
var _binding_buttons: Dictionary[String, Button] = {}
## The action waiting for a key, or "".
var _listening := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_theme_constant_override("separation", 14)
	var title := UITheme.heading("SETTINGS", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 8)
	add_child(tabs)
	for tab in TABS:
		var button := Button.new()
		button.text = tab
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(140.0, 38.0)
		button.pressed.connect(show_tab.bind(tab))
		tabs.add_child(button)
		_tab_buttons[tab] = button
	var frame := UITheme.inset_panel()
	frame.custom_minimum_size = Vector2(720.0, 430.0)
	add_child(frame)
	var holder := Control.new()
	frame.add_child(holder)

	_pages["Audio"] = _page(holder, func(page: VBoxContainer) -> void:
		_slider(page, "master_volume", "Master volume")
		_slider(page, "music_volume", "Music")
		_slider(page, "sfx_volume", "Sound effects")
	)
	_pages["Display"] = _page(holder, func(page: VBoxContainer) -> void:
		_check(page, "fullscreen", "Full screen")
		_check(page, "vsync", "Vertical sync (smoother, may limit frame rate)")
		_slider(page, "ui_scale", "Interface size", 0.7, 1.3)
	)
	_pages["Gameplay"] = _page(holder, func(page: VBoxContainer) -> void:
		_check(page, "show_minimap", "Show the minimap")
		_check(page, "damage_numbers", "Show damage numbers")
		_check(page, "screen_shake", "Screen shake")
	)
	_pages["Controls"] = _controls_page(holder)

	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(bottom)
	bottom.add_child(UITheme.button("Done", func() -> void: closed.emit(), 200.0))
	GameSettings.changed.connect(_refresh_bindings)
	show_tab("Audio")


func show_tab(tab: String) -> void:
	_listening = ""
	for name in _pages:
		_pages[name].visible = name == tab
		_tab_buttons[name].set_pressed_no_signal(name == tab)
	_refresh_bindings()


func _input(event: InputEvent) -> void:
	if _listening == "" or not is_visible_in_tree():
		return
	var accepted: bool = event is InputEventKey or (event is InputEventMouseButton and event.button_index <= MOUSE_BUTTON_MIDDLE)
	if not accepted or not event.is_pressed():
		return
	get_viewport().set_input_as_handled()
	if event is InputEventKey and event.keycode == KEY_ESCAPE:
		_listening = ""
		_refresh_bindings()
		return
	var action := _listening
	_listening = ""
	GameSettings.rebind(action, event)


func _page(holder: Control, fill: Callable) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 14)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(page)
	fill.call(page)
	return page


func _slider(page: Control, setting: String, title: String, low: float = 0.0, high: float = 1.0) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var label := UITheme.label(title, 17)
	label.custom_minimum_size.x = 200.0
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = 0.05
	slider.value = GameSettings.get(setting)
	slider.custom_minimum_size = Vector2(320.0, 24.0)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var percent := UITheme.label("%d%%" % roundi(slider.value * 100.0), 17, UITheme.GOLD)
	slider.value_changed.connect(func(value: float) -> void:
		percent.text = "%d%%" % roundi(value * 100.0)
		# Resizing the interface under the mouse mid-drag would be dizzying.
		if setting == "ui_scale":
			return
		GameSettings.set_value(setting, value)
		if setting == "sfx_volume":
			Audio.play("pickup")
	)
	if setting == "ui_scale":
		slider.drag_ended.connect(func(_changed: bool) -> void: GameSettings.set_value(setting, slider.value))
	row.add_child(slider)
	row.add_child(percent)
	page.add_child(row)


func _check(page: Control, setting: String, title: String) -> void:
	var box := CheckBox.new()
	box.text = title
	UITheme.font_size(box, 17)
	box.button_pressed = GameSettings.get(setting)
	box.toggled.connect(func(on: bool) -> void: GameSettings.set_value(setting, on))
	page.add_child(box)


func _controls_page(holder: Control) -> Control:
	var page := VBoxContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override("separation", 8)
	holder.add_child(page)
	page.add_child(UITheme.label("Click a binding, then press the key or mouse button you want. Esc cancels.", 14, UITheme.DIM))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 4)
	scroll.add_child(grid)
	for entry in GameSettings.REBINDABLE:
		var action: String = entry[0]
		var label := UITheme.label(entry[1], 15)
		label.custom_minimum_size.x = 300.0
		grid.add_child(label)
		var button := Button.new()
		button.custom_minimum_size = Vector2(240.0, 30.0)
		UITheme.font_size(button, 14)
		button.pressed.connect(func() -> void:
			_listening = action
			_refresh_bindings()
		)
		grid.add_child(button)
		_binding_buttons[action] = button
	var reset := UITheme.button("Reset all to defaults", GameSettings.reset_bindings, 240.0)
	reset.size_flags_horizontal = Control.SIZE_SHRINK_END
	page.add_child(reset)
	return page


func _refresh_bindings() -> void:
	for action in _binding_buttons:
		var button := _binding_buttons[action]
		button.text = "Press a key..." if action == _listening else GameSettings.describe(action)
		button.add_theme_color_override("font_color", UITheme.GOLD if action == _listening else UITheme.TEXT)
