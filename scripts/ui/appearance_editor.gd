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
	["Design", ["skin"]],
	["Hair", ["hair_style", "hair", "beard"]],
	["Face", ["mark"]],
	["Clothes", ["outfit", "clothes", "trousers"]],
	["Wear", ["hat", "accessory", "neck"]],
]
## Rows that offer only some of their list: a human's real skin tones, and
## a few things worn rather than every one.
const ALLOWED := {
	"skin": Appearance.REAL_SKIN,
	"hat": [0, 1, 2, 3, 7, 8, 9],
	"accessory": [0, 1, 2, 4],
	"neck": [0, 1, 2, 4],
}
## Rows drawn as pictures; the rest of the shape rows are named buttons.
const PICTURED: Array[String] = ["hair_style", "beard", "mark", "ears", "horns", "tail", "wings", "hat", "accessory", "neck", "cape", "outfit"]
## Rows whose pictures show the whole figure rather than the head.
const WHOLE: Array[String] = ["tail", "wings", "neck", "cape", "outfit"]
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
		var button := UITheme.tab(title, show_tab.bind(title), width / (TABS.size() - (0 if allow_race else 1)) - 4.0)
		UITheme.font_size(button, 15)
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
		elif title == "Design":
			_build_designs(page)
			for key: String in tab[1]:
				_build_row(page, key)
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
	UITheme.font_size(_race_text, 14, "normal_font_size")
	_race_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(_race_text)


## The ten designs of the chosen race, as pictures; and, for humans only,
## the real skin tones beneath.
var _design_grid: GridContainer
var _design_buttons: Array[Button] = []
var _design_race := ""
var _skin_rows: Array[Control] = []


func _build_designs(page: VBoxContainer) -> void:
	page.add_child(UITheme.heading("Design  (%d)" % Appearance.DESIGNS_PER_RACE, 15))
	page.add_child(UITheme.paragraph("Each people has its own looks; choose yours. Hair, face and clothes are yours to change after.", width - 16.0, 13, UITheme.DIM))
	_design_grid = GridContainer.new()
	_design_grid.columns = 5
	_design_grid.add_theme_constant_override("h_separation", 4)
	_design_grid.add_theme_constant_override("v_separation", 4)
	page.add_child(_design_grid)
	for index in Appearance.DESIGNS_PER_RACE:
		var button := _picture_button(null, "", false)
		button.custom_minimum_size = Vector2(width / 5.0 - 6.0, THUMB + 6.0)
		button.pressed.connect(func() -> void:
			appearance["design"] = index
			var design: Dictionary = Appearance.designs(str(appearance.get("race", "human")))[index]
			for key: String in ["hair", "hair_style"]:
				if design.has(key):
					appearance[key] = design[key]
			# A human starts from the design's skin and may change it.
			appearance["skin"] = design["skin"]
			_stale = true
			_mark()
			changed.emit(appearance)
		)
		_design_grid.add_child(button)
		_design_buttons.append(button)


func _fill_designs() -> void:
	var race := str(Appearance.resolved(appearance)["race"])
	var all := Appearance.designs(race)
	for index in _design_buttons.size():
		var button := _design_buttons[index]
		button.set_pressed_no_signal(int(appearance.get("design", -1)) == index)
		button.tooltip_text = str(all[index]["name"])
		if race != _design_race or _stale:
			var look := Appearance.for_race(race, index)
			for key: String in ["clothes", "trousers", "outfit"]:
				look[key] = appearance.get(key, 0)
			(button.get_node("Picture") as TextureRect).texture = LookThumbs.texture(look)
	_design_race = race
	for row in _skin_rows:
		row.visible = race == "human"


## A new race starts from that race's first design, keeping the clothes.
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
	var shown_count: int = (ALLOWED[key] as Array).size() if ALLOWED.has(key) else Appearance.list(row[2]).size()
	var heading := UITheme.heading("%s  (%d)" % [row[1], shown_count], 15)
	page.add_child(heading)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 4)
	flow.add_theme_constant_override("v_separation", 4)
	flow.custom_minimum_size.x = width - 16.0
	page.add_child(flow)
	if key == "skin":
		_skin_rows.append(heading)
		_skin_rows.append(flow)
	var entries := Appearance.list(row[2])
	var buttons: Dictionary = {}
	for index in entries.size():
		if ALLOWED.has(key) and not index in ALLOWED[key]:
			continue
		var button: Button
		var title := Appearance.option_name(row[2], index)
		if row[3] == "colour":
			button = Button.new()
			button.toggle_mode = true
			button.tooltip_text = title
			button.custom_minimum_size = Vector2(34.0, 30.0)
			var style := StyleBoxFlat.new()
			style.bg_color = Color(entries[index][0])
			style.border_color = Color(entries[index][2])
			style.set_border_width_all(2)
			style.set_corner_radius_all(3)
			var chosen := style.duplicate() as StyleBoxFlat
			chosen.border_color = Color.WHITE
			chosen.set_border_width_all(2)
			var hover := style.duplicate() as StyleBoxFlat
			hover.border_color = UITheme.GOLD
			button.add_theme_stylebox_override("normal", style)
			button.add_theme_stylebox_override("hover", hover)
			button.add_theme_stylebox_override("pressed", chosen)
			button.add_theme_stylebox_override("hover_pressed", chosen)
			# The chosen colour wears a second, gold ring outside the white
			# one and a tick, so it never rests on border contrast alone.
			var ring := ReferenceRect.new()
			ring.name = "Ring"
			ring.border_color = UITheme.GOLD
			ring.border_width = 2.0
			ring.editor_only = false
			ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			ring.offset_left = -3.0
			ring.offset_top = -3.0
			ring.offset_right = 3.0
			ring.offset_bottom = 3.0
			ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ring.visible = false
			button.add_child(ring)
			var tick := TextureRect.new()
			tick.name = "Tick"
			tick.texture = UITheme.tick_texture()
			tick.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			tick.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tick.position = Vector2(9, 7)
			tick.size = Vector2(16, 16)
			tick.modulate = Color.WHITE if Color(entries[index][0]).get_luminance() < 0.6 else Color(0.1, 0.1, 0.12)
			tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tick.visible = false
			button.add_child(tick)
			UITheme.sounds(button)
		elif key in PICTURED:
			button = _picture_button(null, title, false)
			button.custom_minimum_size = Vector2(THUMB, THUMB)
		else:
			button = Button.new()
			button.toggle_mode = true
			button.text = title
			# A short list (heights, builds) sits on one deliberate row.
			var across := 88.0
			if entries.size() <= 6:
				across = floorf((width - 16.0 - 4.0 * (entries.size() - 1)) / entries.size())
			button.custom_minimum_size = Vector2(maxf(across, 64.0), 32.0)
			UITheme.font_size(button, 14)
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
		buttons[index] = button
	_choices[key] = buttons


## Presses the buttons that match the current appearance.
func _mark() -> void:
	var worn := Appearance.resolved(appearance)
	for key: String in _choices:
		var buttons: Dictionary = _choices[key]
		for index: int in buttons:
			var button := buttons[index] as Button
			var on := index == int(worn[key])
			button.set_pressed_no_signal(on)
			for part in ["Ring", "Tick"]:
				var marker := button.get_node_or_null(part)
				if marker:
					marker.visible = on
	for race in _race_buttons:
		_race_buttons[race].set_pressed_no_signal(race == worn["race"])
	if _race_text:
		_race_text.text = race_text(worn["race"])
	if _design_grid:
		_fill_designs()
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
		var buttons: Dictionary = _choices[key]
		for index: int in buttons:
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
	# What only this race does.
	for line: Variant in RaceTraits.of(race).get("lines", []):
		lines.append("[color=#%s]%s[/color]" % [UITheme.INFO.to_html(false), str(line)])
	return "\n".join(lines)
