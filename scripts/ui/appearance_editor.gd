class_name AppearanceEditor
extends VBoxContainer
## Every choice that makes up a character's look, in tabs: body, hair,
## face, extras and clothes (and race, where it may still change). Shapes
## are chosen from pictures of the character wearing each one; colours
## from swatches. Used when a world is made and in the wardrobe. Emits
## `changed` with the whole appearance whenever anything is picked.

signal changed(appearance: Dictionary)

const TABS: Array[Array] = [
	["Race", []],
	["Body", ["skin", "height", "build"]],
	["Hair", ["hair_style", "hair", "beard"]],
	["Face", ["eyes", "mark", "ears"]],
	["Extras", ["horns", "tail", "wings"]],
	["Clothes", ["clothes", "trousers"]],
]
## Rows drawn as pictures; the rest of the shape rows are named buttons.
const PICTURED: Array[String] = ["hair_style", "beard", "mark", "ears", "horns", "tail", "wings"]
## Rows whose pictures show the whole figure rather than the head.
const WHOLE: Array[String] = ["tail", "wings"]
const THUMB := 62.0

var appearance: Dictionary = Appearance.DEFAULT.duplicate()
## False hides the Race tab (a character cannot change race later).
var allow_race := true
var width := 470.0

var _tab_buttons: Dictionary[String, Button] = {}
var _pages: Dictionary[String, Control] = {}
var _shown_tab := ""
## key -> buttons in list order, to mark the chosen one and redraw pictures.
var _choices: Dictionary = {}
var _race_buttons: Dictionary[String, Button] = {}
var _race_text: RichTextLabel
var _stale := true


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	add_child(tabs)
	var holder := PanelContainer.new()
	holder.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	holder.custom_minimum_size = Vector2(width, 346.0)
	add_child(holder)
	for tab: Array in TABS:
		var title: String = tab[0]
		if title == "Race" and not allow_race:
			continue
		var button := Button.new()
		button.text = title
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(width / (TABS.size() - (0 if allow_race else 1)) - 4.0, 34.0)
		button.add_theme_font_size_override("font_size", 15)
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
	_shown_tab = title
	for other in _pages:
		_pages[other].visible = other == title
		_tab_buttons[other].set_pressed_no_signal(other == title)
	_draw_pictures()


## Replaces the whole look (a random roll, or a loaded character).
func set_appearance(look: Dictionary) -> void:
	appearance = Appearance.DEFAULT.duplicate()
	appearance.merge(look, true)
	_stale = true
	_mark()


## A race's face, for the race buttons here and in the character creator.
static func race_portrait(race: String) -> Texture2D:
	return LookThumbs.texture(Appearance.for_race(race))


func _build_races(page: VBoxContainer) -> void:
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	page.add_child(grid)
	for race: String in Appearance.RACES:
		var button := _picture_button(race_portrait(race), Appearance.RACES[race]["name"])
		button.custom_minimum_size = Vector2(width / 4.0 - 6.0, 78.0)
		button.pressed.connect(func() -> void:
			choose_race(race)
		)
		grid.add_child(button)
		_race_buttons[race] = button
	_race_text = RichTextLabel.new()
	_race_text.bbcode_enabled = true
	_race_text.fit_content = true
	_race_text.scroll_active = false
	_race_text.custom_minimum_size = Vector2(width - 16.0, 120.0)
	_race_text.add_theme_font_size_override("normal_font_size", 14)
	_race_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(_race_text)


## A new race starts from that race's own look, keeping the clothes.
func choose_race(race: String) -> void:
	var clothes: int = appearance.get("clothes", 0)
	var trousers: int = appearance.get("trousers", 0)
	appearance = Appearance.for_race(race)
	appearance["clothes"] = clothes
	appearance["trousers"] = trousers
	_stale = true
	_mark()
	changed.emit(appearance)


## A square button showing a picture, with its name under it when `named`.
func _picture_button(picture: Texture2D, title: String, named: bool = true) -> Button:
	var button := Button.new()
	button.toggle_mode = true
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = title
	button.custom_minimum_size = Vector2(THUMB, THUMB + (16.0 if named else 0.0))
	var image := TextureRect.new()
	image.name = "Picture"
	image.texture = picture
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 4)
	if named:
		image.offset_bottom = -16.0
		var label := UITheme.label(title, 13, UITheme.TEXT)
		label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		label.offset_top = -18.0
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.clip_text = true
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(label)
	button.add_child(image)
	UITheme.sounds(button)
	return button


## One row of choices: a heading, then pictures, swatches or named buttons.
func _build_row(page: VBoxContainer, key: String) -> void:
	var row: Array = []
	for option in Appearance.OPTIONS:
		if option[0] == key:
			row = option
	var heading := UITheme.heading("%s  (%d)" % [row[1], Appearance.list(row[2]).size()], 15)
	page.add_child(heading)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 4)
	flow.add_theme_constant_override("v_separation", 4)
	flow.custom_minimum_size.x = width - 16.0
	page.add_child(flow)
	var entries := Appearance.list(row[2])
	var buttons: Array[Button] = []
	for index in entries.size():
		var button: Button
		var title := Appearance.option_name(row[2], index)
		if row[3] == "colour":
			button = Button.new()
			button.toggle_mode = true
			button.focus_mode = Control.FOCUS_NONE
			button.tooltip_text = title
			button.custom_minimum_size = Vector2(34.0, 30.0)
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
			UITheme.sounds(button)
		elif key in PICTURED:
			button = _picture_button(null, title, false)
			button.custom_minimum_size = Vector2(THUMB, THUMB)
		else:
			button = Button.new()
			button.toggle_mode = true
			button.focus_mode = Control.FOCUS_NONE
			button.text = title
			button.custom_minimum_size = Vector2(88.0, 32.0)
			button.add_theme_font_size_override("font_size", 14)
			UITheme.sounds(button)
		button.pressed.connect(func() -> void:
			appearance[key] = index
			# Colours change every picture; shapes only their own row.
			if row[3] == "colour" or key == "hair_style":
				_stale = true
			_mark()
			changed.emit(appearance)
		)
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
		_race_text.text = race_text(worn["race"])
	_draw_pictures()


## Draws the pictures on the shown tab: each option worn by this character.
func _draw_pictures() -> void:
	if _shown_tab == "" or not is_inside_tree():
		return
	var keys: Array = []
	for tab: Array in TABS:
		if tab[0] == _shown_tab:
			keys = tab[1]
	for key: String in keys:
		if not key in PICTURED or not _choices.has(key):
			continue
		var buttons: Array = _choices[key]
		for index in buttons.size():
			var look := appearance.duplicate()
			look[key] = index
			# Show a beard or a mark clearly, without hair falling over it.
			if key in ["beard", "mark"] and int(look.get("hair_style", 0)) in [2, 8, 9]:
				look["hair_style"] = 1
			var picture := (buttons[index] as Button).get_node("Picture") as TextureRect
			picture.texture = LookThumbs.texture(look, key in WHOLE)
	_stale = false


## A race's words and gifts, as BBCode.
static func race_text(race: String) -> String:
	var data: Dictionary = Appearance.RACES[race]
	var lines: PackedStringArray = []
	lines.append("[font_size=20][color=#%s]%s[/color][/font_size]" % [UITheme.HEADING.to_html(false), data["name"]])
	lines.append("[color=#%s]%s[/color]" % [UITheme.TEXT.to_html(false), data["text"]])
	lines.append("")
	for stat: String in data["mods"]:
		for kind: String in data["mods"][stat]:
			var value: float = data["mods"][stat][kind]
			var words := ItemDB.describe_modifier({"stat": stat, "kind": kind, "value": absf(value)})
			lines.append("[color=#%s]%s[/color]" % [(UITheme.GOOD if value >= 0.0 else UITheme.BAD).to_html(false), words if value >= 0.0 else "-" + words.substr(1)])
	return "\n".join(lines)
