class_name ItemTooltip
extends PanelContainer
## A box of words that follows the mouse: what an item is, or what a recipe
## needs. Any screen can own one; add it as a child and call show_item,
## show_recipe or show_text when something is hovered and hide_tip when not.

const WIDTH := 300.0

var _icon: TextureRect
var _text: RichTextLabel


func _ready() -> void:
	top_level = true
	z_index = 100
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_theme_stylebox_override("panel", UITheme.tooltip_box())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(44.0, 44.0)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_icon)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.custom_minimum_size.x = WIDTH
	_text.add_theme_font_size_override("normal_font_size", 14)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_text)


func show_item(item: Item, player: Player, extra: String = "") -> void:
	if item == null:
		hide_tip()
		return
	_icon.visible = true
	_icon.texture = item.icon()
	_icon.modulate = item.icon_tint()
	_fill(ItemText.describe(item, player) + ("\n\n" + extra if extra != "" else ""), item.color().darkened(0.1))


func show_recipe(recipe: Dictionary, player: Player) -> void:
	var made: String = recipe.get("item", "")
	_icon.visible = made != "" and ItemDB.ITEMS.has(made)
	if _icon.visible:
		var sample := Item.create(made)
		_icon.texture = sample.icon()
		_icon.modulate = sample.icon_tint()
	_fill(ItemText.describe_recipe(recipe, player), Color("8a683a"))


func show_text(title: String, body: String) -> void:
	_icon.visible = false
	_fill("[font_size=17][color=#%s]%s[/color][/font_size]\n[color=#%s]%s[/color]" % [UITheme.HEADING.to_html(false), title, UITheme.TEXT.to_html(false), body], Color("8a683a"))


func hide_tip() -> void:
	visible = false


func _fill(bbcode: String, border: Color) -> void:
	_text.text = bbcode
	(get_theme_stylebox("panel") as StyleBoxTexture).modulate_color = Color.WHITE.lerp(border, 0.35)
	visible = true
	reset_size()
	_follow()


func _process(_delta: float) -> void:
	if visible:
		_follow()


## Sits beside the mouse, flipped to stay on screen.
func _follow() -> void:
	var mouse := get_viewport().get_mouse_position()
	var view := get_viewport().get_visible_rect().size
	var at := mouse + Vector2(18.0, 14.0)
	if at.x + size.x > view.x - 6.0:
		at.x = mouse.x - size.x - 14.0
	if at.y + size.y > view.y - 6.0:
		at.y = maxf(view.y - size.y - 6.0, 6.0)
	global_position = at.max(Vector2(6.0, 6.0))
