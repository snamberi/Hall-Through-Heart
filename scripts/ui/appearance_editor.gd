class_name AppearanceEditor
extends VBoxContainer
## Every choice that makes up a character's look, in tabs: who they are,
## their body, hair, face, extras and clothes. Used when a world is made
## and in the wardrobe. Emits `changed` with the whole appearance whenever
## anything is picked.

signal changed(appearance: Dictionary)

const TABS: Array[Array] = [
	["Race", []],
	["Body", ["skin", "height", "build"]],
	["Hair", ["hair_style", "hair", "beard"]],
	["Face", ["eyes", "mark", "ears"]],
	["Extras", ["horns", "tail", "wings"]],
	["Clothes", ["clothes", "trousers"]],
]
const WIDTH := 470.0

var appearance: Dictionary = Appearance.DEFAULT.duplicate()
## False hides the Race tab (a character cannot change race later).
var allow_race := true

var _tab_buttons: Dictionary[String, Button] = {}
var _pages: Dictionary[String, Control] = {}
## key -> buttons in list order, to mark the chosen one.
var _choices: Dictionary = {}
var _race_buttons: Dictionary[String, Button] = {}
var _race_text: RichTextLabel


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	add_child(tabs)
	var holder := PanelContainer.new()
	holder.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	holder.custom_minimum_size = Vector2(WIDTH, 346.0)
	add_child(holder)
	for tab: Array in TABS:
		var title: String = tab[0]
		if title == "Race" and not allow_race:
			continue
		var button := Button.new()
		button.text = title
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(72.0, 34.0)
		button.add_theme_font_size_override("font_size", 14)
		button.pressed.connect(show_tab.bind(title))
		UITheme.sounds(button)
		tabs.add_child(button)
		_tab_buttons[title] = button
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		holder.add_child(scroll)
		var page := VBoxContainer.new()
		page.add_theme_constant_override("separation", 6)
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(page)
		_pages[title] = scroll
		if title == "Race":
			_build_races(page)
		else:
			for key: String in tab[1]:
				_build_row(page, key)
	show_tab(_tab_buttons.keys()[0])
	_mark()


func show_tab(title: String) -> void:
	for other in _pages:
		_pages[other].visible = other == title
		_tab_buttons[other].set_pressed_no_signal(other == title)


## Replaces the whole look (a random roll, or a loaded character).
func set_appearance(look: Dictionary) -> void:
	appearance = Appearance.DEFAULT.duplicate()
	appearance.merge(look, true)
	_mark()


func _build_races(page: VBoxContainer) -> void:
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	page.add_child(grid)
	for race: String in Appearance.RACES:
		var button := Button.new()
		button.text = Appearance.RACES[race]["name"]
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(112.0, 36.0)
		button.add_theme_font_size_override("font_size", 14)
		button.pressed.connect(func() -> void:
			# A new race starts from that race's own look, keeping the clothes.
			var clothes: int = appearance.get("clothes", 0)
			var trousers: int = appearance.get("trousers", 0)
			appearance = Appearance.for_race(race)
			appearance["clothes"] = clothes
			appearance["trousers"] = trousers
			_mark()
			changed.emit(appearance)
		)
		UITheme.sounds(button)
		grid.add_child(button)
		_race_buttons[race] = button
	_race_text = RichTextLabel.new()
	_race_text.bbcode_enabled = true
	_race_text.fit_content = true
	_race_text.scroll_active = false
	_race_text.custom_minimum_size = Vector2(WIDTH - 16.0, 150.0)
	_race_text.add_theme_font_size_override("normal_font_size", 14)
	_race_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(_race_text)


## One row of choices: a heading, then swatches (colours) or named buttons.
func _build_row(page: VBoxContainer, key: String) -> void:
	var row: Array = []
	for option in Appearance.OPTIONS:
		if option[0] == key:
			row = option
	var heading := UITheme.heading(row[1], 15)
	heading.name = "Heading_" + key
	page.add_child(heading)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 4)
	flow.add_theme_constant_override("v_separation", 4)
	flow.custom_minimum_size.x = WIDTH - 16.0
	page.add_child(flow)
	var entries := Appearance.list(row[2])
	var buttons: Array[Button] = []
	for index in entries.size():
		var button := Button.new()
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.tooltip_text = Appearance.option_name(row[2], index)
		if row[3] == "colour":
			button.custom_minimum_size = Vector2(36.0, 30.0)
			var style := StyleBoxFlat.new()
			style.bg_color = Color(entries[index][0])
			style.border_color = Color(entries[index][2])
			style.set_border_width_all(2)
			style.set_corner_radius_all(3)
			var chosen := style.duplicate() as StyleBoxFlat
			chosen.border_color = Color.WHITE
			chosen.set_border_width_all(3)
			var hover := style.duplicate() as StyleBoxFlat
			hover.border_color = UITheme.GOLD
			button.add_theme_stylebox_override("normal", style)
			button.add_theme_stylebox_override("hover", hover)
			button.add_theme_stylebox_override("pressed", chosen)
			button.add_theme_stylebox_override("hover_pressed", chosen)
		else:
			button.text = Appearance.option_name(row[2], index)
			button.custom_minimum_size = Vector2(88.0, 30.0)
			button.add_theme_font_size_override("font_size", 13)
		button.pressed.connect(func() -> void:
			appearance[key] = index
			_mark()
			changed.emit(appearance)
		)
		UITheme.sounds(button)
		flow.add_child(button)
		buttons.append(button)
	_choices[key] = buttons


## Presses the buttons that match the current appearance.
func _mark() -> void:
	var worn := Appearance.resolved(appearance)
	for key: String in _choices:
		var buttons: Array = _choices[key]
		for index in buttons.size():
			(buttons[index] as Button).set_pressed_no_signal(index == int(worn[key]))
	for race in _race_buttons:
		_race_buttons[race].set_pressed_no_signal(race == worn["race"])
	if _race_text:
		var data: Dictionary = Appearance.RACES[worn["race"]]
		var lines: PackedStringArray = []
		lines.append("[font_size=20][color=#%s]%s[/color][/font_size]" % [UITheme.HEADING.to_html(false), data["name"]])
		lines.append("[color=#%s]%s[/color]" % [UITheme.TEXT.to_html(false), data["text"]])
		lines.append("")
		for stat: String in data["mods"]:
			for kind: String in data["mods"][stat]:
				var value: float = data["mods"][stat][kind]
				var words := ItemDB.describe_modifier({"stat": stat, "kind": kind, "value": absf(value)})
				lines.append("[color=#%s]%s[/color]" % [(UITheme.GOOD if value >= 0.0 else UITheme.BAD).to_html(false), words if value >= 0.0 else "-" + words.substr(1)])
		lines.append("")
		lines.append("[color=#%s]Everything about a race's look can still be changed in the other tabs.[/color]" % UITheme.DIM.to_html(false))
		_race_text.text = "\n".join(lines)
