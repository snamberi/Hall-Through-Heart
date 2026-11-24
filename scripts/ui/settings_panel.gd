class_name SettingsPanel
extends VBoxContainer
## Every setting, in tabs: Audio, Display (with interface and text size,
## previewed before it applies), Interface (the HUD's layout), Comfort
## (shake, damage numbers, contrast, flashes) and Controls (rebinding in
## groups, with a reset per action and a warning where keys are shared).
## Everything can be reached and changed with the keyboard. Used on the
## title screen and in the pause menu.

signal closed

const TABS: Array[String] = ["Audio", "Display", "Graphics", "Interface", "Comfort", "Controls"]
const FRAME := Vector2(760.0, 440.0)
## Controls, grouped: [heading, actions].
const GROUPS := [
	["Movement", ["move_up", "move_down", "move_left", "move_right", "dodge", "sprint", "mount"]],
	["Combat", ["attack", "parry", "ability_1", "ability_2", "ability_3", "ability_4", "ability_swap", "relic_ability", "quick_use", "loadout_next", "release_aura", "shadow_swap", "raise_shadow"]],
	["World", ["interact", "build_mode", "recall_home"]],
	["Interface", ["photo_mode", "mark_junk", "lock_item"]],
	["Hotbar", ["hotbar_1", "hotbar_2", "hotbar_3", "hotbar_4", "hotbar_5", "hotbar_6", "hotbar_7", "hotbar_8", "hotbar_9", "hotbar_10"]],
	["Menus", ["toggle_menu", "open_inventory", "open_quests", "open_map", "open_system", "open_chat"]],
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
## What to bring up to date when a setting changes elsewhere. Run from one
## method bound to this panel, so the connection goes when the panel does
## (a lambda connected straight to GameSettings outlived the title screen
## and crashed the game on the next change).
var _listeners: Array[Callable] = []


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
		var button := UITheme.tab(tab, show_tab.bind(tab), 118.0)
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
	_pages["Graphics"] = _scroll_page(holder, func(page: VBoxContainer) -> void:
		_preset_row(page)
		_choice(page, "world_detail", "World detail", [[0, "Minimal"], [1, "Medium"], [2, "High"], [3, "Maximum"]], 112.0)
		_choice(page, "particles", "Particles", [[0.25, "25%"], [0.5, "50%"], [1.0, "100%"], [1.5, "150%"]], 112.0)
		_choice(page, "shaders", "Shaders", [["off", "Off"], ["basic", "Basic"], ["full", "Full"]], 112.0)
		_choice(page, "lighting", "Lighting", [[0, "Simple"], [1, "Normal"], [2, "Enhanced"], [3, "Maximum"]], 112.0)
		_choice(page, "weather_fx", "Weather effects", [[0, "Minimal"], [1, "Medium"], [2, "Full"]], 112.0)
		_choice(page, "grass_density", "Grass density", [[0.25, "25%"], [0.5, "50%"], [1.0, "100%"], [1.5, "150%"]], 112.0)
		_choice(page, "view_distance", "View distance", [[0, "Short"], [1, "Medium"], [2, "Long"], [3, "Maximum"]], 112.0)
		_choice(page, "fps_limit", "FPS limit", [[30, "30"], [60, "60"], [120, "120"], [144, "144"], [0, "None"]], 86.0)
		_check(page, "bloom", "Bloom (a soft glow round fire and magic; with Full shaders)")
		_check(page, "fog", "Fog and haze")
		_check(page, "screen_shake", "Screen shake")
		_check(page, "damage_numbers", "Damage numbers")
	)
	_pages["Interface"] = _scroll_page(holder, func(page: VBoxContainer) -> void:
		_style_choice(page)
		_choice(page, "hud_layout", "Ability slots", [["compact", "By the hotbar"], ["classic", "Column on the left"]])
		_choice(page, "tracker_mode", "Quest tracker", [["full", "Full"], ["compact", "Compact"], ["off", "Off"]])
		_check(page, "show_worn", "Show worn armour on the hotbar")
		_check(page, "show_minimap", "Show the minimap")
		_check(page, "damage_numbers", "Show damage numbers")
		_choice(page, "wing_display", "Wings of flight", [["flight", "While flying"], ["always", "Always"], ["never", "Never"]], 130.0)
		_check(page, "quest_arrows", "Arrows at the screen's edge to the waypoint, pins, bounties and treasure")
		_check(page, "enemy_info", "Show what a monster is when the mouse rests on it")
		_check(page, "inner_voice", "The Still Voice: quiet advice and analysis of monsters")
		_check(page, "remnants", "Fallen monsters leave remnants to devour")
		_check(page, "system_window", "The Pact: the Tenday Road and its messages")
		_check(page, "dps_meter", "Damage-per-second meter")
		_choice(page, "pickup_radius", "Loot pulled in from", [[0.5, "Close"], [1.0, "Normal"], [1.5, "Far"], [2.0, "Very far"]], 112.0)
		_choice(page, "loot_filter", "Pick gear up by walking over", [[0, "All"], [1, "Uncommon+"], [2, "Rare+"], [3, "Epic+"]], 112.0)
		_check(page, "auto_junk", "Mark plain common gear as junk when it is picked up")
	)
	_pages["Comfort"] = _scroll_page(holder, func(page: VBoxContainer) -> void:
		_choice(page, "sprint_mode", "Sprint key", [["toggle", "Press to toggle"], ["hold", "Hold to sprint"]])
		_choice(page, "touch_controls", "Touch controls", [["auto", "On phones"], ["on", "Always"], ["off", "Never"]])
		_check(page, "screen_shake", "Screen shake")
		_slider(page, "shake_strength", "Shake strength", 0.0, 1.5)
		_slider(page, "damage_number_size", "Damage number size", 0.7, 1.6)
		_check(page, "high_contrast", "High contrast text (brighter quiet text, outlined letters)")
		_check(page, "reduce_flashes", "Reduce flashes (lightning and other bright bursts)")
		_choice(page, "colorblind", "Attack warning colours", [["off", "Standard"], ["deuteranopia", "Deuteranopia"], ["protanopia", "Protanopia"], ["tritanopia", "Tritanopia"]], 112.0)
		_check(page, "pause_unfocused", "Pause when the game window loses focus")
	)
	_pages["Controls"] = _controls_page(holder)

	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(bottom)
	bottom.add_child(UITheme.primary_button("Done", func() -> void: closed.emit(), 200.0))
	GameSettings.changed.connect(_on_settings_changed)
	show_tab("Audio")
	visibility_changed.connect(func() -> void:
		if is_visible_in_tree():
			_tab_buttons[_current].grab_focus.call_deferred()
	)


func _on_settings_changed() -> void:
	_refresh_bindings()
	for listener: Callable in _listeners:
		listener.call()


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


## A page that scrolls, for one with more rows than the frame holds.
func _scroll_page(holder: Control, fill: Callable) -> Control:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	holder.add_child(scroll)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(page)
	fill.call(page)
	return scroll


## The four presets, and which is in use ("Custom" once a value is changed alone).
func _preset_row(page: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	page.add_child(row)
	var label := UITheme.strong("Preset", 17, UITheme.GOLD)
	label.custom_minimum_size.x = 220.0
	row.add_child(label)
	var buttons: Dictionary = {}
	for preset: String in ["low", "normal", "high", "ultra"]:
		var button := UITheme.button(preset.capitalize(), func() -> void: GameSettings.apply_preset(preset), 112.0)
		button.toggle_mode = true
		row.add_child(button)
		buttons[preset] = button
	var custom := UITheme.label("", 15, UITheme.DIM)
	row.add_child(custom)
	var show := func() -> void:
		for preset: String in buttons:
			(buttons[preset] as Button).set_pressed_no_signal(GameSettings.graphics_preset == preset)
		custom.text = "Custom" if GameSettings.graphics_preset == "custom" else ""
	show.call()
	_listeners.append(show)


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
	_listeners.append(func() -> void: apply.disabled = is_equal_approx(slider.value, GameSettings.text_scale))


func _check(page: Control, setting: String, title: String) -> CheckBox:
	var box := CheckBox.new()
	box.text = title
	UITheme.font_size(box, 17)
	box.button_pressed = GameSettings.get(setting)
	box.focus_mode = Control.FOCUS_ALL
	box.toggled.connect(func(on: bool) -> void: GameSettings.set_value(setting, on))
	# Kept true to the setting when it is changed elsewhere (the same
	# toggle can be on two tabs).
	_listeners.append(func() -> void: box.set_pressed_no_signal(GameSettings.get(setting)))
	page.add_child(box)
	return box


## A row of buttons for a setting with a few named values.
## The interface style: six looks, each with a swatch of its frame; picking
## one rebuilds the screen in it.
func _style_choice(page: Control) -> void:
	page.add_child(UITheme.label("Interface style", 17))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	page.add_child(grid)
	for id: String in UITheme.STYLES:
		var button := Button.new()
		button.toggle_mode = true
		button.text = "  " + str(UITheme.STYLES[id]["name"])
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(250.0, 48.0)
		UITheme.font_size(button, 15)
		var swatch := load("res://assets/ui/themes/%s/panel.png" % id) as Texture2D
		if swatch:
			var atlas := AtlasTexture.new()
			atlas.atlas = swatch
			atlas.region = Rect2(0, 0, 40, 40)
			button.icon = atlas
			button.add_theme_constant_override("icon_max_width", 32)
		button.set_pressed_no_signal(GameSettings.ui_style == id)
		button.pressed.connect(func() -> void: GameSettings.restyle(id))
		UITheme.sounds(button)
		grid.add_child(button)
	page.add_child(UITheme.label("Changing style saves the game and redraws the screen.", 14, UITheme.DIM))


func _choice(page: Control, setting: String, title: String, options: Array, width: float = 150.0) -> void:
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
		, width)
		button.toggle_mode = true
		button.set_pressed_no_signal(GameSettings.get(setting) == option[0])
		row.add_child(button)
		buttons.append(button)
	# A preset changes many at once: keep the buttons showing the values.
	_listeners.append(func() -> void:
		for index in buttons.size():
			buttons[index].set_pressed_no_signal(GameSettings.get(setting) == options[index][0])
	)


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
