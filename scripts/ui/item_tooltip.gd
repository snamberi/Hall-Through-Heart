class_name ItemTooltip
extends PanelContainer
## A box of words that follows the mouse: what an item is, or what a recipe
## needs. Any screen can own one; add it as a child and call show_item,
## show_recipe or show_text when something is hovered and hide_tip when not.
## With `side_by_side` on (the shop and storage), gear not worn gets a
## second box beside it showing the piece worn in its place, headed
## "Worn now", so the two can be read together.

const WIDTH := 300.0

var _icon: TextureRect
var _text: RichTextLabel
## Show the worn piece beside hovered gear.
var side_by_side := false
var _worn: ItemTooltip


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
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_icon)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.custom_minimum_size.x = WIDTH
	UITheme.font_size(_text, 14, "normal_font_size")
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_text)


## The item's picture shown large, at a whole multiple of its own size so
## every pixel stays square (about 64 on screen).
static func _set_icon(rect: TextureRect, texture: Texture2D) -> void:
	rect.texture = texture
	if texture == null:
		return
	var side := maxf(texture.get_width(), texture.get_height())
	var times := maxf(floorf(64.0 / maxf(side, 1.0)), 1.0)
	rect.custom_minimum_size = Vector2(texture.get_width(), texture.get_height()) * times
	rect.stretch_mode = TextureRect.STRETCH_SCALE


func show_item(item: Item, player: Player, extra: String = "") -> void:
	if item == null:
		hide_tip()
		return
	_icon.visible = true
	_set_icon(_icon, item.icon())
	_icon.modulate = item.icon_tint()
	_fill(ItemText.describe(item, player) + ("\n\n" + extra if extra != "" else ""), item.color().darkened(0.1))
	_show_worn(item, player)


## The piece worn where this one would go, in its own box beside this one.
func _show_worn(item: Item, player: Player) -> void:
	if not side_by_side:
		return
	var rival: Item = ItemText.rival(item, player) if item.is_equipment() else null
	if rival == null or rival == item or player.equipment.slot_of(item) != "":
		if _worn:
			_worn.visible = false
		return
	if _worn == null:
		_worn = ItemTooltip.new()
		add_child(_worn)
	_worn._icon.visible = true
	_set_icon(_worn._icon, rival.icon())
	_worn._icon.modulate = rival.icon_tint()
	_worn._fill("[color=#%s]WORN NOW[/color]\n%s" % [UITheme.DIM.to_html(false), ItemText.describe(rival, player)], rival.color().darkened(0.1))
	_place_worn()


func _place_worn() -> void:
	if _worn == null or not _worn.visible:
		return
	var view := get_viewport().get_visible_rect().size
	var at := global_position + Vector2(size.x + 8.0, 0.0)
	if at.x + _worn.size.x > view.x - 6.0:
		at.x = global_position.x - _worn.size.x - 8.0
	_worn.global_position = Vector2(maxf(at.x, 6.0), minf(at.y, maxf(view.y - _worn.size.y - 6.0, 6.0)))


func show_recipe(recipe: Dictionary, player: Player) -> void:
	if _worn:
		_worn.visible = false
	var made: String = recipe.get("item", "")
	_icon.visible = made != "" and ItemDB.ITEMS.has(made)
	if _icon.visible:
		var sample := Item.create(made)
		_set_icon(_icon, sample.icon())
		_icon.modulate = sample.icon_tint()
	_fill(ItemText.describe_recipe(recipe, player), Color("8a683a"))


func show_text(title: String, body: String) -> void:
	if _worn:
		_worn.visible = false
	_icon.visible = false
	_fill("[font_size=17][color=#%s]%s[/color][/font_size]\n[color=#%s]%s[/color]" % [UITheme.HEADING.to_html(false), title, UITheme.TEXT.to_html(false), body], Color("8a683a"))


func hide_tip() -> void:
	visible = false
	if _worn:
		_worn.visible = false


func _fill(bbcode: String, border: Color) -> void:
	_text.text = bbcode
	(get_theme_stylebox("panel") as StyleBoxTexture).modulate_color = Color.WHITE.lerp(border, 0.35)
	visible = true
	reset_size()
	_follow()


func _process(_delta: float) -> void:
	if visible and not _is_worn_box():
		_follow()
		_place_worn()


func _is_worn_box() -> bool:
	return get_parent() is ItemTooltip


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
