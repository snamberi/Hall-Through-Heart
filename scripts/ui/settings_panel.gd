class_name SettingsPanel
extends VBoxContainer
## Every setting, in tabs: Audio, Display (with interface and text size,
## previewed before it applies), Interface (the HUD's layout), Comfort
## (shake, damage numbers, contrast, flashes) and Controls (rebinding in
## groups, with a reset per action and a warning where keys are shared).
## Everything can be reached and changed with the keyboard. Used on the
## title screen and in the pause menu.

signal closed

const TABS: Array[String] = ["Audio", "Display", "Interface", "Comfort", "Controls"]
const FRAME := Vector2(760.0, 440.0)
## Controls, grouped: [heading, actions].
const GROUPS := [
	["Movement", ["move_up", "move_down", "move_left", "move_right", "dodge", "sprint", "mount"]],
	["Combat", ["attack", "parry", "ability_1", "ability_2", "ability_3", "ability_4", "ability_swap", "relic_ability", "quick_use"]],
	["World", ["interact", "build_mode", "recall_home"]],
	["Hotbar", ["hotbar_1", "hotbar_2", "hotbar_3", "hotbar_4", "hotbar_5", "hotbar_6", "hotbar_7", "hotbar_8", "hotbar_9", "hotbar_10"]],
	["Menus", ["toggle_menu", "open_inventory", "open_quests", "open_map"]],
]
## Pairs that share a key on purpose (one works in a menu, one in the world).
const SHARED_OK := [["attack", "interact"]]

var _pages: Dictionary[String, Control] = {}
var _tab_buttons: Dictionary[String, Button] = {}
var _binding_buttons: Dictionary[String, Button] = {}
var _conflict_labels: Dictionary[String, Label] = {}
var _listen_banner: Label
## The action waiting for a key, or "".
var _listening := ""
var _current := "Audio"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_theme_constant_override("separation", 12)
	var title := UITheme.heading("SETTINGS", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 8)
	add_child(tabs)
	for tab in TABS:
		var button := UITheme.button(tab, show_tab.bind(tab), 140.0)
		button.toggle_mode = true
		button.custom_minimum_size.y = 38.0
		tabs.add_child(button)
		_tab_buttons[tab] = button
	var frame := UITheme.inset_panel()
	frame.custom_minimum_size = FRAME
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
		_slider(page, "ui_scale", "Interface size", 0.7, 1.3, true)
		_text_size(page)
	)
	_pages["Interface"] = _page(holder, func(page: VBoxContainer) -> void:
		_choice(page, "hud_layout", "Ability slots", [["compact", "By the hotbar"], ["classic", "Column on the left"]])
		_choice(page, "tracker_mode", "Quest tracker", [["full", "Full"], ["compact", "Compact"], ["off", "Off"]])
		_check(page, "show_worn", "Show worn armour on the hotbar")
		_check(page, "show_minimap", "Show the minimap")
		_check(page, "damage_numbers", "Show damage numbers")
	)
	_pages["Comfort"] = _page(holder, func(page: VBoxContainer) -> void:
		_check(page, "screen_shake", "Screen shake")
		_slider(page, "shake_strength", "Shake strength", 0.0, 1.5)
		_slider(page, "damage_number_size", "Damage number size", 0.7, 1.6)
		_check(page, "high_contrast", "High contrast text (brighter quiet text, outlined letters)")
		_check(page, "reduce_flashes", "Reduce flashes (lightning and other bright bursts)")
		page.add_child(UITheme.label("High contrast applies to screens as they are next drawn.", 14, UITheme.DIM))
	)
	_pages["Controls"] = _controls_page(holder)

	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(bottom)
	bottom.add_child(UITheme.primary_button("Done", func() -> void: closed.emit(), 200.0))
	GameSettings.changed.connect(_refresh_bindings)
	show_tab("Audio")
	visibility_changed.connect(func() -> void:
		if is_visible_in_tree():
			_tab_buttons[_current].grab_focus.call_deferred()
	)


func show_tab(tab: String) -> void:
	if not _pages.has(tab):
		return
	_listening = ""
	_current = tab
	# Keyboard users moving along the tabs keep the focus on the shown one.
	var focused := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if focused != null and focused in _tab_buttons.values():
		_tab_buttons[tab].grab_focus.call_deferred()
	for name in _pages:
		_pages[name].visible = name == tab
		_tab_buttons[name].set_pressed_no_signal(name == tab)
	_refresh_bindings()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if _listening == "":
		# Q and E (or Page Up / Down) step through the tabs.
		if event is InputEventKey and event.pressed and not event.echo and not get_viewport().gui_get_focus_owner() is LineEdit:
			var step := 0
			if event.keycode in [KEY_PAGEUP] or (event.keycode == KEY_Q and event.ctrl_pressed):
				step = -1
			elif event.keycode in [KEY_PAGEDOWN] or (event.keycode == KEY_E and event.ctrl_pressed):
				step = 1
			if step != 0:
				show_tab(TABS[posmod(TABS.find(_current) + step, TABS.size())])
				_tab_buttons[_current].grab_focus()
				get_viewport().set_input_as_handled()
		return
	var accepted: bool = event is InputEventKey or (event is InputEventMouseButton and event.button_index <= MOUSE_BUTTON_MIDDLE)
	if not accepted or not event.is_pressed():
		return
	get_viewport().set_input_as_handled()
	if event is InputEventKey and event.keycode == KEY_ESCAPE:
		var cancelled := _listening
		_listening = ""
		_refresh_bindings()
		_binding_buttons[cancelled].grab_focus()
		return
	var action := _listening
	_listening = ""
	GameSettings.rebind(action, event)
	_binding_buttons[action].grab_focus()


func _page(holder: Control, fill: Callable) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 14)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(page)
	fill.call(page)
	return page


## A slider with its value beside it. `on_release` waits for the drag to end
## (the interface resizing under the mouse would be dizzying).
func _slider(page: Control, setting: String, title: String, low: float = 0.0, high: float = 1.0, on_release: bool = false) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var label := UITheme.label(title, 17)
	label.custom_minimum_size.x = 220.0
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = 0.05
	slider.value = GameSettings.get(setting)
	slider.custom_minimum_size = Vector2(320.0, 28.0)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_ALL
	var percent := UITheme.strong("%d%%" % roundi(slider.value * 100.0), 17, UITheme.GOLD)
	percent.custom_minimum_size.x = 64.0
	slider.value_changed.connect(func(value: float) -> void:
		percent.text = "%d%%" % roundi(value * 100.0)
		if on_release and slider.has_focus() and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			return
		GameSettings.set_value(setting, value)
		if setting == "sfx_volume":
			Audio.play("pickup")
	)
	if on_release:
		slider.drag_ended.connect(func(_changed: bool) -> void: GameSettings.set_value(setting, slider.value))
	row.add_child(slider)
	row.add_child(percent)
	page.add_child(row)
	return slider


## Text size on its own, with a line of sample text that shows the size
## before it is applied.
func _text_size(page: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	page.add_child(row)
	var label := UITheme.label("Text size", 17)
	label.custom_minimum_size.x = 220.0
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.9
	slider.max_value = 1.25
	slider.step = 0.05
	slider.value = GameSettings.text_scale
	slider.custom_minimum_size = Vector2(320.0, 28.0)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var percent := UITheme.strong("%d%%" % roundi(slider.value * 100.0), 17, UITheme.GOLD)
	percent.custom_minimum_size.x = 64.0
	row.add_child(percent)
	var sample := Label.new()
	sample.text = "Sample: the Heart beats slower in the dark."
	sample.add_theme_font_override("font", UITheme.body())
	sample.add_theme_color_override("font_color", UITheme.TEXT)
	sample.add_theme_font_size_override("font_size", roundi(16 * slider.value))
	page.add_child(sample)
	var apply := UITheme.button("Apply text size", func() -> void: GameSettings.set_value("text_scale", slider.value), 200.0)
	apply.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	apply.disabled = true
	page.add_child(apply)
	slider.value_changed.connect(func(value: float) -> void:
		percent.text = "%d%%" % roundi(value * 100.0)
		sample.add_theme_font_size_override("font_size", roundi(16 * value))
		apply.disabled = is_equal_approx(value, GameSettings.text_scale)
	)
	GameSettings.changed.connect(func() -> void: apply.disabled = is_equal_approx(slider.value, GameSettings.text_scale))


func _check(page: Control, setting: String, title: String) -> CheckBox:
	var box := CheckBox.new()
	box.text = title
	UITheme.font_size(box, 17)
	box.button_pressed = GameSettings.get(setting)
	box.focus_mode = Control.FOCUS_ALL
	box.toggled.connect(func(on: bool) -> void: GameSettings.set_value(setting, on))
	page.add_child(box)
	return box


## A row of buttons for a setting with a few named values.
func _choice(page: Control, setting: String, title: String, options: Array) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	page.add_child(row)
	var label := UITheme.label(title, 17)
	label.custom_minimum_size.x = 220.0
	row.add_child(label)
	var buttons: Array[Button] = []
	for option: Array in options:
		var button := UITheme.button(option[1], func() -> void:
			GameSettings.set_value(setting, option[0])
			for other in buttons:
				other.set_pressed_no_signal(other.text == option[1])
		, 150.0)
		button.toggle_mode = true
		button.set_pressed_no_signal(GameSettings.get(setting) == option[0])
		row.add_child(button)
		buttons.append(button)


func _controls_page(holder: Control) -> Control:
	var page := VBoxContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override("separation", 8)
	holder.add_child(page)
	_listen_banner = UITheme.strong("", 16, UITheme.GOLD)
	page.add_child(_listen_banner)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	page.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for group: Array in GROUPS:
		list.add_child(UITheme.heading(group[0], 17))
		for action: String in group[1]:
			if not InputMap.has_action(action):
				continue
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			list.add_child(row)
			var label := UITheme.label(GameSettings.action_name(action), 15)
			label.custom_minimum_size.x = 240.0
			row.add_child(label)
			var button := Button.new()
			button.custom_minimum_size = Vector2(200.0, 30.0)
			UITheme.font_size(button, 15)
			UITheme.sounds(button)
			button.pressed.connect(func() -> void:
				_listening = action
				_refresh_bindings()
			)
			row.add_child(button)
			_binding_buttons[action] = button
			var reset := UITheme.button("Reset", func() -> void: GameSettings.reset_action(action), 70.0)
			reset.custom_minimum_size.y = 30.0
			reset.tooltip_text = "Put this action back to its default key."
			row.add_child(reset)
			var conflict := UITheme.label("", 14, Color("e8a070"))
			conflict.custom_minimum_size.x = 190.0
			conflict.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			conflict.clip_text = true
			row.add_child(conflict)
			_conflict_labels[action] = conflict
	var reset_all := UITheme.danger_button("Reset all to defaults", GameSettings.reset_bindings, 240.0)
	reset_all.size_flags_horizontal = Control.SIZE_SHRINK_END
	page.add_child(reset_all)
	return page


func _refresh_bindings() -> void:
	if _listen_banner:
		_listen_banner.text = "Press a key or mouse button for \"%s\".   Esc cancels." % GameSettings.action_name(_listening) if _listening != "" else "Click or press Enter on a binding, then press the new key. Shared keys are marked."
		_listen_banner.add_theme_color_override("font_color", UITheme.GOLD if _listening != "" else UITheme.DIM)
	for action in _binding_buttons:
		var button := _binding_buttons[action]
		var listening := action == _listening
		button.text = "Press a key..." if listening else GameSettings.describe(action)
		button.theme_type_variation = &"PrimaryButton" if listening else &""
		button.add_theme_color_override("font_color", Color("1a1408") if listening else UITheme.TEXT)
		var shared: PackedStringArray = []
		for other in GameSettings.conflicts(action):
			if [action, other] in SHARED_OK or [other, action] in SHARED_OK:
				continue
			shared.append(GameSettings.action_name(other))
		_conflict_labels[action].text = "" if shared.is_empty() else "Also: " + ", ".join(shared)
		_conflict_labels[action].tooltip_text = _conflict_labels[action].text
