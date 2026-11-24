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
## A container's look for the slots ("pack", "chest"...; see UITheme.skin_slot).
var skin := ""
## The item drawn as chosen, if any.
var selected: Item
## Items shown with a tick (marked to sell or throw away together).
var marked: Array = []

var _grid: GridContainer
var _buttons: Array[Button] = []
var _counts: Array[Label] = []
var _marks: Array[MarkOverlay] = []
var _locks: Array[TextureRect] = []
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
		style_slot(button, item, item != null and item == selected, skin)
		_counts[index].text = str(item.count) if item and item.count > 1 else ""
		_marks[index].visible = item != null and item in marked
		_locks[index].visible = item != null and item.locked


func _add_slot() -> void:
	var index := _buttons.size()
	var button := Button.new()
	button.custom_minimum_size = Vector2(SLOT, SLOT)
	# The 32-pixel pictures at their own size, so every pixel stays one.
	button.expand_icon = false
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
	var count := UITheme.label("", 14)
	count.add_theme_font_override("font", UITheme.body_bold())
	count.add_theme_color_override("font_outline_color", Color.BLACK)
	count.add_theme_constant_override("outline_size", 5)
	count.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	count.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	count.grow_vertical = Control.GROW_DIRECTION_BEGIN
	count.position -= Vector2(4, 0)
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(count)
	# A small padlock on pieces the player has locked.
	var lock := TextureRect.new()
	lock.texture = UITheme.lock_texture()
	lock.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	lock.position = Vector2(1, 1)
	lock.size = Vector2(14, 14)
	lock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lock.visible = false
	button.add_child(lock)
	_locks.append(lock)
	_marks.append(MarkOverlay.attach(button))
	_grid.add_child(button)
	_buttons.append(button)
	_counts.append(count)


func _item(index: int) -> Item:
	return _items[index] if index < _items.size() else null


## A sunken pixel-art slot in the item's rarity look (see
## UITheme.rarity_slot), lit up while hovered; the chosen item's is gold.
static func frame_style(item: Item, chosen: bool, kind: String = "", skin: String = "") -> StyleBoxTexture:
	# In a container's own look, plain things sit in its slots; finer ones
	# keep their rarity's frame.
	if skin != "" and (item == null or item.rarity == 0 or chosen or kind == "slot_active"):
		var skinned := UITheme.skin_slot(skin, kind if kind != "" else ("slot_active" if chosen else "slot"))
		skinned.set_content_margin_all(5)
		return skinned
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
static func style_slot(button: Button, item: Item, chosen: bool = false, skin: String = "") -> void:
	var style := frame_style(item, chosen, "", skin)
	var hover := frame_style(item, chosen, "slot_active" if chosen else "slot_hover", skin)
	var pressed := frame_style(item, chosen, "slot_active", skin)
	var disabled := frame_style(item, chosen, "", skin)
	disabled.modulate_color = Color(0.6, 0.6, 0.65)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("hover_pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.icon = item.icon() if item else null
	_grade_pips(button, item)
	var tint := item.icon_tint() if item else Color.WHITE
	for state: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "icon_disabled_color"]:
		button.add_theme_color_override(state, tint)


## A weapon's grade (honed, gilded, runed: see PlayerAnimator.weapon_grade)
## as little gold pips along the top of its slot.
static func _grade_pips(button: Button, item: Item) -> void:
	var pips: Control = button.get_node_or_null("GradePips")
	var grade := PlayerAnimator.weapon_grade(item) if item and item.is_equipment() and item.definition().has("weapon") else 0
	if grade == 0:
		if pips:
			pips.visible = false
		return
	if pips == null:
		pips = Control.new()
		pips.name = "GradePips"
		pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pips.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pips.draw.connect(func() -> void:
			var shown: int = pips.get_meta("grade", 0)
			for k in shown:
				var at := Vector2(pips.size.x - 6.0 - k * 5.0, 3.0)
				pips.draw_rect(Rect2(at - Vector2(1, 1), Vector2(5, 5)), Color(0.12, 0.08, 0.04))
				pips.draw_rect(Rect2(at, Vector2(3, 3)), Color(0.98, 0.8, 0.36) if shown < 3 else Color(0.6, 0.95, 1.0))
				pips.draw_rect(Rect2(at, Vector2.ONE), Color(1, 1, 0.92)))
		button.add_child(pips)
	pips.set_meta("grade", grade)
	pips.visible = true
	pips.queue_redraw()
