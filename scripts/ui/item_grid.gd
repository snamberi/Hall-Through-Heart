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
## Items shown with a tick (marked to sell or throw away together).
var marked: Array = []

var _grid: GridContainer
var _buttons: Array[Button] = []
var _counts: Array[Label] = []
var _marks: Array[MarkOverlay] = []
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
		_marks[index].visible = item != null and item in marked


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
	_marks.append(MarkOverlay.attach(button))
	_grid.add_child(button)
	_buttons.append(button)
	_counts.append(count)


func _item(index: int) -> Item:
	return _items[index] if index < _items.size() else null


## A sunken pixel-art slot in the item's rarity look (see
## UITheme.rarity_slot), lit up while hovered; the chosen item's is gold.
static func frame_style(item: Item, chosen: bool, kind: String = "") -> StyleBoxTexture:
	if item and not chosen and kind in ["", "slot_hover"]:
		var framed := UITheme.rarity_slot(item.rarity)
		if kind == "slot_hover":
			framed.modulate_color = Color(1.35, 1.35, 1.35)
		return framed
	var style := UITheme.slot(kind if kind != "" else ("slot_active" if chosen else "slot"))
	style.set_content_margin_all(5)
	return style


## Dresses any button as an item slot, with the same four states everywhere:
## hover lifts the fill and brightens the edge, pressed sinks it, disabled
## greys it.
static func style_slot(button: Button, item: Item, chosen: bool = false) -> void:
	var style := frame_style(item, chosen)
	var hover := frame_style(item, chosen, "slot_active" if chosen else "slot_hover")
	var pressed := frame_style(item, chosen, "slot_active")
	var disabled := frame_style(item, chosen)
	disabled.modulate_color = Color(0.6, 0.6, 0.65)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("hover_pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.icon = item.icon() if item else null
	var tint := item.icon_tint() if item else Color.WHITE
	for state: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "icon_disabled_color"]:
		button.add_theme_color_override(state, tint)
