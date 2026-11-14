class_name UITheme
extends RefCounted
## The game's interface style: pixel-art panels of dark navy cloth in heavy
## riveted bronze frames, stone buttons, sunken slots, gold headings, and
## the Almendra typeface. The art is drawn by tools/generate_ui.py at twice
## size, so its pixels match the game's.
##
## Every screen uses this theme. New interface code should build from plain
## Controls and the helpers here rather than styling itself.
##
## Type: Almendra is the display face (titles and headings); everything
## meant to be read is set in Alegreya, with lining figures so numbers sit
## level. Gold has one job: it marks what is chosen. Ordinary cards and
## buttons wear quiet steel; keyboard focus is a bright double ring.

const TEXT := Color("e6dfcf")
const DIM := Color("8f8a80")
const GOLD := Color("f2c14e")
const HEADING := Color("e8c878")
const GOOD := Color("8fd66a")
const BAD := Color("e0555a")
const INFO := Color("6fb6ff")
## A quiet line colour for rules and neutral borders.
const LINE := Color("39415a")
## Text sizes: what is read, what is secondary, and the smallest allowed.
const BODY := 16
const SMALL := 14

static var _theme: Theme
static var _bold: Font
static var _body: Font
static var _body_bold: Font
## The reading-size setting (see GameSettings.text_scale): scales every
## piece of text set through this class, without resizing the panels.
static var text_scale := 1.0


static func get_theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme


## The heavier face, for titles.
static func bold() -> Font:
	if _bold == null:
		_bold = load("res://assets/fonts/almendra-bold.woff2")
	return _bold


## The reading face, at a comfortable weight.
static func body() -> Font:
	if _body == null:
		_body = _alegreya(520)
	return _body


## The reading face, heavier: for names and values that should stand out.
static func body_bold() -> Font:
	if _body_bold == null:
		_body_bold = _alegreya(720)
	return _body_bold


static func _alegreya(weight: int) -> Font:
	var font := FontVariation.new()
	font.base_font = load("res://assets/fonts/alegreya.ttf")
	var server := TextServerManager.get_primary_interface()
	font.variation_opentype = {server.name_to_tag("wght"): weight}
	# Lining figures: numbers all the same height.
	font.opentype_features = {server.name_to_tag("lnum"): 1}
	return font


## Sets a control's text size (a theme font-size item), kept at or above
## the smallest readable size and scaled by the player's text-size setting.
## Use this instead of add_theme_font_size_override so the setting reaches it.
static func font_size(target: Control, size: int, item: String = "font_size") -> void:
	target.set_meta("ui_size_" + item, size)
	target.add_theme_font_size_override(item, px(size))
	target.add_to_group("ui_text")


## A text size in pixels after the smallest-size rule and the text-size setting.
static func px(size: int) -> int:
	return roundi(maxi(size, MIN_TEXT) * text_scale)


## Applies a new text-size setting to everything already on screen.
static func set_text_scale(tree: SceneTree, scale: float) -> void:
	text_scale = scale
	if _theme:
		_theme.default_font_size = px(BODY)
	for node in tree.get_nodes_in_group("ui_text"):
		for meta: String in node.get_meta_list():
			if meta.begins_with("ui_size_"):
				(node as Control).add_theme_font_size_override(meta.trim_prefix("ui_size_"), px(int(node.get_meta(meta))))


## Gives every Control directly under a CanvasLayer the theme.
static func apply(layer: Node) -> void:
	for child in layer.get_children():
		if child is Control:
			child.theme = get_theme()


## The smallest text the game shows.
const MIN_TEXT := 14


static func label(text: String, size: int = BODY, color: Color = TEXT) -> Label:
	var result := Label.new()
	result.text = text
	font_size(result, size)
	result.add_theme_color_override("font_color", color)
	return result


## Body text that wraps within a width.
static func paragraph(text: String, width: float, size: int = BODY, color: Color = TEXT) -> Label:
	var result := label(text, size, color)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.custom_minimum_size = Vector2(width, 0)
	return result


## A section title: gold, in the display face.
static func heading(text: String, size: int = 20) -> Label:
	var result := label(text, size, HEADING)
	result.add_theme_font_override("font", bold())
	return result


## A name or value that should stand out within body text.
static func strong(text: String, size: int = BODY, color: Color = TEXT) -> Label:
	var result := label(text, size, color)
	result.add_theme_font_override("font", body_bold())
	return result


static func button(text: String, action: Callable, minimum_width: float = 84.0) -> Button:
	var result := Button.new()
	result.text = text
	result.custom_minimum_size = Vector2(minimum_width, 34.0)
	result.pressed.connect(action)
	sounds(result)
	return result


## The one main action of a screen or panel: a gold button.
static func primary_button(text: String, action: Callable, minimum_width: float = 120.0) -> Button:
	var result := button(text, action, minimum_width)
	result.theme_type_variation = "PrimaryButton"
	result.custom_minimum_size.y = 40.0
	return result


## Something that destroys or cannot be undone: set apart in red.
static func danger_button(text: String, action: Callable, minimum_width: float = 84.0) -> Button:
	var result := button(text, action, minimum_width)
	result.theme_type_variation = "DangerButton"
	return result


## A small label in a box that states one fact about a thing: "Equipped",
## "Active", "Locked". `kind` is "gold" (chosen), "good", "bad", "info" or
## "plain".
static func badge(text: String, kind: String = "plain") -> PanelContainer:
	var colors := {"gold": GOLD, "good": GOOD, "bad": BAD, "info": INFO, "plain": Color("aab0c4")}
	var color: Color = colors.get(kind, colors["plain"])
	var box := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color, 0.14)
	style.border_color = color
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.content_margin_left = 7
	style.content_margin_right = 7
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	box.add_theme_stylebox_override("panel", style)
	box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var text_label := label(text, SMALL, color.lightened(0.25))
	text_label.add_theme_font_override("font", body_bold())
	box.add_child(text_label)
	return box


## A key on the keyboard, drawn as a small cap: for hints like [Tab] Switch.
static func key_cap(text: String) -> PanelContainer:
	var box := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1a2032")
	style.border_color = Color("8a90a4")
	style.set_border_width_all(1)
	style.border_width_bottom = 3
	style.set_corner_radius_all(3)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	box.add_theme_stylebox_override("panel", style)
	box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var text_label := label(text, SMALL, Color.WHITE)
	text_label.add_theme_font_override("font", body_bold())
	box.add_child(text_label)
	return box


## A key cap and what it does, side by side.
static func key_hint(key: String, action: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(key_cap(key))
	row.add_child(label(action, SMALL, DIM))
	return row


## Why an action cannot be taken: a short line to sit beside its button.
static func reason(text: String = "", width: float = 0.0) -> Label:
	var result := label(text, SMALL, Color("e8a070"))
	if width > 0.0:
		result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		result.custom_minimum_size = Vector2(width, 0)
	return result


## A one-line text box for searching, with a hint shown while empty.
static func search_box(hint: String, width: float, on_change: Callable) -> LineEdit:
	var box := LineEdit.new()
	box.placeholder_text = hint
	box.clear_button_enabled = true
	box.custom_minimum_size = Vector2(width, 32.0)
	font_size(box, BODY)
	box.text_changed.connect(func(_text: String) -> void: on_change.call())
	return box


## A thin plain rule between groups.
static func rule(width: float = 0.0) -> ColorRect:
	var line := ColorRect.new()
	line.color = LINE
	line.custom_minimum_size = Vector2(width, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


## The small padlock and tick pictures used for locked and done things.
static func lock_texture() -> Texture2D:
	return load("res://assets/ui/lock.png")


static func tick_texture() -> Texture2D:
	return load("res://assets/ui/tick.png")


## Puts keyboard focus on the first thing in `root` that can take it.
static func focus_first(root: Control) -> bool:
	for node in root.find_children("*", "Control", true, false):
		var control := node as Control
		if control.focus_mode == Control.FOCUS_ALL and control.is_visible_in_tree() and not (control is BaseButton and (control as BaseButton).disabled):
			control.grab_focus()
			return true
	return false


## Gives any button the soft tick on hover and click on press.
static func sounds(target: BaseButton) -> void:
	target.mouse_entered.connect(func() -> void:
		if not target.disabled:
			Audio.play("ui_hover", -16.0, 0.03)
	)
	target.pressed.connect(func() -> void: Audio.play("ui_click", -10.0, 0.05))


static func icon(index: int, size: float = 22.0) -> TextureRect:
	var result := TextureRect.new()
	result.texture = ItemDB.icon(index)
	result.custom_minimum_size = Vector2(size, size)
	result.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	result.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	result.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return result


## A recessed box for details inside a panel.
static func inset_panel() -> PanelContainer:
	var result := PanelContainer.new()
	result.theme_type_variation = "InsetPanel"
	return result


static func _frame(file: String, margin: int, content: int) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = load("res://assets/ui/%s.png" % file)
	box.set_texture_margin_all(margin)
	box.set_content_margin_all(content)
	# The middles and edges repeat rather than stretch, so no pixel smears.
	box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	return box


## A framed card for a list or grid entry: "card", "card_hover",
## "card_selected" (gold, with gem corners) or "card_dim" (iron, for
## locked or closed things).
static func card(kind: String = "card", content: int = 10) -> StyleBoxTexture:
	return _frame(kind, 12, content)


## An item slot: "slot", "slot_hover" or "slot_active".
static func slot(kind: String = "slot") -> StyleBoxTexture:
	return _frame(kind, 8, 4)


## An item slot in its rarity's look (0 common .. 5 mythic): the lip in
## that rarity's metal, the well glowing its colour, gems and filigree on
## the finer ones. Stretched, not tiled, so the glow stays centred.
static func rarity_slot(rarity: int) -> StyleBoxTexture:
	var box := _frame("slot_r%d" % clampi(rarity, 0, 5), 8, 5)
	box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	return box


## The box tooltips sit in.
static func tooltip_box() -> StyleBoxTexture:
	return _frame("tooltip", 6, 10)


## A worked rule to put under a heading.
static func divider(width: float = 160.0) -> TextureRect:
	var rule := TextureRect.new()
	rule.texture = load("res://assets/ui/divider.png")
	rule.custom_minimum_size = Vector2(width, 10.0)
	rule.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return rule


static func _flat(fill: Color, border: Color, width: int = 1, margin: int = 6) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.set_content_margin_all(margin)
	return box


## The ring drawn round whatever has keyboard focus.
static func focus_box() -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = load("res://assets/ui/focus.png")
	box.set_texture_margin_all(6)
	box.set_expand_margin_all(3)
	box.draw_center = false
	return box


static func _build() -> Theme:
	var theme := Theme.new()
	theme.default_font = body()
	theme.default_font_size = px(BODY)

	theme.set_stylebox("panel", "PanelContainer", _frame("panel", 20, 26))
	theme.set_type_variation("InsetPanel", "PanelContainer")
	theme.set_stylebox("panel", "InsetPanel", _frame("inset", 6, 14))
	theme.set_stylebox("panel", "TooltipPanel", tooltip_box())

	for state: Array in [["normal", "button"], ["hover", "button_hover"], ["pressed", "button_pressed"], ["disabled", "button_disabled"]]:
		var box := _frame(state[1], 6, 6)
		box.content_margin_left = 12.0
		box.content_margin_right = 12.0
		theme.set_stylebox(state[0], "Button", box)
	theme.set_stylebox("focus", "Button", focus_box())
	# The main action: a gold face with dark lettering.
	theme.set_type_variation("PrimaryButton", "Button")
	for state: Array in [["normal", "button_primary"], ["hover", "button_primary_hover"], ["pressed", "button_primary_pressed"]]:
		var box := _frame(state[1], 6, 6)
		box.content_margin_left = 14.0
		box.content_margin_right = 14.0
		theme.set_stylebox(state[0], "PrimaryButton", box)
	theme.set_color("font_color", "PrimaryButton", Color("201404"))
	theme.set_color("font_hover_color", "PrimaryButton", Color("140c02"))
	theme.set_color("font_pressed_color", "PrimaryButton", Color("140c02"))
	theme.set_color("font_focus_color", "PrimaryButton", Color("140c02"))
	theme.set_color("font_hover_pressed_color", "PrimaryButton", Color("140c02"))
	theme.set_font("font", "PrimaryButton", body_bold())
	# Destructive actions: red-rimmed.
	theme.set_type_variation("DangerButton", "Button")
	for state: Array in [["normal", "button_danger"], ["hover", "button_danger_hover"], ["pressed", "button_danger_hover"]]:
		var box := _frame(state[1], 6, 6)
		box.content_margin_left = 12.0
		box.content_margin_right = 12.0
		theme.set_stylebox(state[0], "DangerButton", box)
	theme.set_color("font_color", "DangerButton", Color("f0a0a4"))
	theme.set_color("font_hover_color", "DangerButton", Color("ffd0d2"))
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_focus_color", "Button", Color.WHITE)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", Color("ffe7a8"))
	theme.set_color("font_hover_pressed_color", "Button", Color("ffe7a8"))
	# Disabled labels stay legible: dim, not invisible.
	theme.set_color("font_disabled_color", "Button", Color("7a7c86"))

	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_color", "CheckBox", TEXT)
	theme.set_color("font_pressed_color", "CheckBox", TEXT)
	theme.set_color("font_hover_color", "CheckBox", Color.WHITE)
	theme.set_color("font_hover_pressed_color", "CheckBox", Color.WHITE)
	theme.set_color("font_focus_color", "CheckBox", Color.WHITE)
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var pad := StyleBoxEmpty.new()
		pad.set_content_margin_all(4)
		theme.set_stylebox(state, "CheckBox", pad)
	theme.set_stylebox("focus", "CheckBox", focus_box())
	theme.set_icon("checked", "CheckBox", load("res://assets/ui/check_on.png"))
	theme.set_icon("unchecked", "CheckBox", load("res://assets/ui/check_off.png"))
	theme.set_icon("checked_disabled", "CheckBox", load("res://assets/ui/check_on.png"))
	theme.set_icon("unchecked_disabled", "CheckBox", load("res://assets/ui/check_off.png"))
	theme.set_constant("h_separation", "CheckBox", 10)
	theme.set_color("default_color", "RichTextLabel", TEXT)
	theme.set_font("bold_font", "RichTextLabel", body_bold())

	# Sliders: a clear track, a filled part, and a handle big enough to catch.
	var track := _flat(Color("0a0c14"), Color("39415a"), 1, 0)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	var filled := _flat(Color("8a6234"), Color("0a0c14"), 1, 0)
	var filled_lit := _flat(Color("c8902e"), Color("0a0c14"), 1, 0)
	theme.set_stylebox("slider", "HSlider", track)
	theme.set_stylebox("grabber_area", "HSlider", filled)
	theme.set_stylebox("grabber_area_highlight", "HSlider", filled_lit)
	theme.set_icon("grabber", "HSlider", load("res://assets/ui/grabber.png"))
	theme.set_icon("grabber_highlight", "HSlider", load("res://assets/ui/grabber_hover.png"))
	theme.set_icon("grabber_disabled", "HSlider", load("res://assets/ui/grabber.png"))

	# Text boxes.
	var field := _flat(Color("0a0d15"), Color("4e5876"), 1, 5)
	field.content_margin_left = 9
	field.content_margin_right = 9
	var field_focus := _flat(Color("0c1019"), GOLD, 2, 4)
	field_focus.content_margin_left = 8
	field_focus.content_margin_right = 8
	theme.set_stylebox("normal", "LineEdit", field)
	theme.set_stylebox("focus", "LineEdit", field_focus)
	theme.set_stylebox("read_only", "LineEdit", field)
	theme.set_color("font_color", "LineEdit", TEXT)
	theme.set_color("font_placeholder_color", "LineEdit", Color("6c7080"))
	theme.set_color("caret_color", "LineEdit", GOLD)

	# Slim scroll bars that do not shout.
	for bar: String in ["VScrollBar", "HScrollBar"]:
		var groove := _flat(Color("0a0c14", 0.6), Color("0a0c14", 0.0), 0, 3)
		theme.set_stylebox("scroll", bar, groove)
		theme.set_stylebox("scroll_focus", bar, groove)
		theme.set_stylebox("grabber", bar, _flat(Color("39415a"), Color("0a0c14"), 1, 3))
		theme.set_stylebox("grabber_highlight", bar, _flat(Color("8a6234"), Color("0a0c14"), 1, 3))
		theme.set_stylebox("grabber_pressed", bar, _flat(Color("c8902e"), Color("0a0c14"), 1, 3))

	# Drop-down lists.
	theme.set_stylebox("focus", "OptionButton", focus_box())
	theme.set_stylebox("panel", "PopupMenu", _flat(Color("0e1220"), Color("8a6234"), 2, 6))
	theme.set_stylebox("hover", "PopupMenu", _flat(Color("2a2414"), GOLD, 1, 4))
	theme.set_color("font_color", "PopupMenu", TEXT)
	theme.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	theme.set_font_size("font_size", "PopupMenu", px(BODY))
	theme.set_stylebox("panel", "TooltipPanel", tooltip_box())
	theme.set_font_size("font_size", "TooltipLabel", px(SMALL))

	var bar_back := StyleBoxFlat.new()
	bar_back.bg_color = Color("0a0c14")
	bar_back.border_color = Color("403020")
	bar_back.set_border_width_all(1)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color("9aa3b4")
	bar_fill.set_border_width_all(1)
	bar_fill.border_color = Color("0a0c14")
	theme.set_stylebox("background", "ProgressBar", bar_back)
	theme.set_stylebox("fill", "ProgressBar", bar_fill)
	return theme
