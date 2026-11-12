class_name UITheme
extends RefCounted
## The game's interface style: dark navy panels with worked bronze frames,
## gold headings, and the Almendra typeface.
##
## Every screen uses this theme. New interface code should build from plain
## Controls and the helpers here rather than styling itself.

const TEXT := Color("e6dfcf")
const DIM := Color("8f8a80")
const GOLD := Color("f2c14e")
const HEADING := Color("e8c878")
const GOOD := Color("8fd66a")
const BAD := Color("e0555a")
const INFO := Color("6fb6ff")

static var _theme: Theme
static var _bold: Font


static func get_theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme


## The heavier face, for titles.
static func bold() -> Font:
	if _bold == null:
		_bold = load("res://assets/fonts/almendra-bold.woff2")
	return _bold


## Gives every Control directly under a CanvasLayer the theme.
static func apply(layer: Node) -> void:
	for child in layer.get_children():
		if child is Control:
			child.theme = get_theme()


static func label(text: String, font_size: int = 16, color: Color = TEXT) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	return result


## A section title: gold, bold, with a small diamond in front.
static func heading(text: String, font_size: int = 20) -> Label:
	var result := label(text, font_size, HEADING)
	result.add_theme_font_override("font", bold())
	return result


static func button(text: String, action: Callable, minimum_width: float = 84.0) -> Button:
	var result := Button.new()
	result.text = text
	result.custom_minimum_size = Vector2(minimum_width, 32.0)
	result.focus_mode = Control.FOCUS_NONE
	result.pressed.connect(action)
	sounds(result)
	return result


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
	return box


static func _build() -> Theme:
	var theme := Theme.new()
	theme.default_font = load("res://assets/fonts/almendra-regular.woff2")
	theme.default_font_size = 16

	theme.set_stylebox("panel", "PanelContainer", _frame("panel", 20, 26))
	theme.set_type_variation("InsetPanel", "PanelContainer")
	theme.set_stylebox("panel", "InsetPanel", _frame("inset", 16, 16))

	for state: Array in [["normal", "button"], ["hover", "button_hover"], ["pressed", "button_pressed"], ["disabled", "button_disabled"]]:
		var box := _frame(state[1], 6, 6)
		box.content_margin_left = 12.0
		box.content_margin_right = 12.0
		theme.set_stylebox(state[0], "Button", box)
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", Color("ffe7a8"))
	theme.set_color("font_hover_pressed_color", "Button", Color("ffe7a8"))
	theme.set_color("font_disabled_color", "Button", Color("5c5a58"))

	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_color", "CheckBox", TEXT)
	theme.set_color("font_pressed_color", "CheckBox", TEXT)
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		theme.set_stylebox(state, "CheckBox", StyleBoxEmpty.new())
	theme.set_color("default_color", "RichTextLabel", TEXT)

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
