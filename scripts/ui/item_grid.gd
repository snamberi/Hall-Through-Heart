class_name ItemGrid
extends ScrollContainer
## A scrolling grid of item slots, like the bag in the inventory: each slot
## framed in its item's rarity colour, with a count, and a tooltip that
## follows the mouse. Used wherever a pile of items is shown (chests, the
## bag while trading).

signal picked(item: Item, index: int)
signal alt_picked(item: Item, index: int)
signal hovered(item: Item)

const SLOT := 50.0
const GAP := 3.0

## The player whose stats tooltips compare against.
var player: Player
var tooltip: ItemTooltip
## Extra line for the tooltip, per item (a price, say). Optional.
var note_for: Callable
## The item drawn as chosen, if any.
var selected: Item

var _grid: GridContainer
var _buttons: Array[Button] = []
var _counts: Array[Label] = []
var _items: Array = []


func setup(p_player: Player, p_tooltip: ItemTooltip, columns: int = 8, rows: int = 6) -> void:
	player = p_player
	tooltip = p_tooltip
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	custom_minimum_size = Vector2(columns * (SLOT + GAP) + 12.0, rows * (SLOT + GAP))
	_grid = GridContainer.new()
	_grid.columns = columns
	_grid.add_theme_constant_override("h_separation", int(GAP))
	_grid.add_theme_constant_override("v_separation", int(GAP))
	add_child(_grid)


## Shows `items` (Item or null per slot) in at least `capacity` slots.
func set_items(items: Array, capacity: int) -> void:
	_items = items
	var count := maxi(capacity, items.size())
	while _buttons.size() < count:
		_add_slot()
	for index in _buttons.size():
		var button := _buttons[index]
		button.visible = index < count
		var item: Item = items[index] if index < items.size() else null
		style_slot(button, item, item != null and item == selected)
		_counts[index].text = str(item.count) if item and item.count > 1 else ""


func _add_slot() -> void:
	var index := _buttons.size()
	var button := Button.new()
	button.custom_minimum_size = Vector2(SLOT, SLOT)
	button.focus_mode = Control.FOCUS_NONE
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.pressed.connect(func() -> void:
		var item := _item(index)
		if item:
			Audio.play("ui_click", -10.0, 0.05)
			picked.emit(item, index)
	)
	button.gui_input.connect(func(event: InputEvent) -> void:
		var click := event as InputEventMouseButton
		if click and click.pressed and click.button_index == MOUSE_BUTTON_RIGHT and _item(index):
			alt_picked.emit(_item(index), index)
	)
	button.mouse_entered.connect(func() -> void:
		var item := _item(index)
		hovered.emit(item)
		if item and tooltip:
			tooltip.show_item(item, player, note_for.call(item) if note_for.is_valid() else "")
			Audio.play("ui_hover", -18.0, 0.03)
	)
	button.mouse_exited.connect(func() -> void:
		hovered.emit(null)
		if tooltip:
			tooltip.hide_tip()
	)
	var count := UITheme.label("", 13)
	count.add_theme_color_override("font_outline_color", Color.BLACK)
	count.add_theme_constant_override("outline_size", 4)
	count.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	count.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	count.grow_vertical = Control.GROW_DIRECTION_BEGIN
	count.position -= Vector2(4, 1)
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(count)
	_grid.add_child(button)
	_buttons.append(button)
	_counts.append(count)


func _item(index: int) -> Item:
	return _items[index] if index < _items.size() else null


## A slot frame in the item's rarity colour; the chosen item's is bright.
static func frame_style(item: Item, chosen: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	# Empty slots are lighter than the panel behind them, so they read as slots.
	style.bg_color = Color("1a1e2b")
	style.border_color = Color("4a4f64")
	style.set_border_width_all(2)
	style.set_content_margin_all(5)
	if item:
		style.border_color = item.color().darkened(0.2)
		style.bg_color = item.color().darkened(0.84)
		if chosen:
			style.border_color = Color.WHITE
			style.set_border_width_all(3)
	return style


## Dresses any button as an item slot, with the same four states everywhere:
## hover lifts the fill and brightens the edge, pressed sinks it, disabled
## greys it.
static func style_slot(button: Button, item: Item, chosen: bool = false) -> void:
	var style := frame_style(item, chosen)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = style.bg_color.lightened(0.1)
	if not chosen:
		hover.border_color = style.border_color.lightened(0.35)
	var pressed := style.duplicate() as StyleBoxFlat
	pressed.bg_color = style.bg_color.darkened(0.3)
	var disabled := style.duplicate() as StyleBoxFlat
	disabled.bg_color = style.bg_color.darkened(0.25)
	disabled.border_color = style.border_color.darkened(0.4)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("hover_pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.icon = item.icon() if item else null
	var tint := item.icon_tint() if item else Color.WHITE
	for state: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "icon_disabled_color"]:
		button.add_theme_color_override(state, tint)
