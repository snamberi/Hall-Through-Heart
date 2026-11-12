class_name BuildPalette
extends Control
## Build mode (B): most of the interface steps aside, the view pulls back a
## little, and everything in the bag that can be set down is listed down
## the right side. Click an entry (or turn the mouse wheel) to take it in
## hand; place it with the usual blueprint. B or Esc leaves.

signal toggled(on: bool)

const ROW := Vector2(214.0, 46.0)
const WIDTH := 240.0

var active := false
## Whether build mode is on, for the parts of the interface that hide.
static var on := false
var _player: Player
var _builder: Builder
var _font: Font
## [item id, item] for each kind of placeable thing in the bag.
var _entries: Array = []
var _hover := -1
var _scroll := 0
var _check_left := 0.0
var _panel_style: StyleBox = UITheme._frame("panel", 20, 0)
var _slots := {"slot": UITheme.slot("slot"), "slot_hover": UITheme.slot("slot_hover"), "slot_active": UITheme.slot("slot_active")}


func setup(player: Player, builder: Builder) -> void:
	_player = player
	_builder = builder
	_font = UITheme.get_theme().default_font
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	mouse_exited.connect(func() -> void:
		_hover = -1
		HudMenuButton.hovered = false
	)


func toggle() -> void:
	set_active(not active)


func set_active(on: bool) -> void:
	if on == active:
		return
	active = on
	BuildPalette.on = on
	visible = on
	if not on and _builder.is_active():
		_builder.cancel()
	HudMenuButton.hovered = false
	_refresh()
	toggled.emit(on)


func _refresh() -> void:
	_entries.clear()
	var seen := {}
	for item in _player.inventory.items:
		if item and item.is_placeable() and not seen.has(item.id):
			seen[item.id] = true
			_entries.append([item.id, item])
	_entries.sort_custom(func(a: Array, b: Array) -> bool: return _rank(a[0]) < _rank(b[0]))
	_scroll = clampi(_scroll, 0, maxi(_entries.size() - _rows_fit(), 0))


## Order: structures, walls, ground, furniture, light, farm (as the Build
## screen lists them).
func _rank(id: String) -> int:
	var kind := str(ItemDB.ITEMS[id].get("place", ""))
	var index := 0
	for category: Array in BuildMenu.CATEGORIES:
		if kind in category[2]:
			return index * 100 + (category[2] as Array).find(kind)
		index += 1
	return 999


func _rows_fit() -> int:
	return maxi(int((size.y - 110.0) / (ROW.y + 4.0)), 1)


func _process(delta: float) -> void:
	if not active:
		return
	if _player.is_dead():
		set_active(false)
		return
	var room := get_viewport().get_visible_rect().size
	size = Vector2(WIDTH, room.y * 0.78)
	position = Vector2(room.x - WIDTH - 14.0, (room.y - size.y) / 2.0)
	_check_left -= delta
	if _check_left <= 0.0:
		_check_left = 0.3
		_refresh()
	queue_redraw()


func _row_rect(index: int) -> Rect2:
	return Rect2(Vector2(13.0, 74.0 + (index - _scroll) * (ROW.y + 4.0)), ROW)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		HudMenuButton.hovered = true
		_hover = -1
		for index in range(_scroll, mini(_entries.size(), _scroll + _rows_fit())):
			if _row_rect(index).has_point(event.position):
				_hover = index
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and _hover >= 0:
			_take(_hover)
			Audio.play("ui_click", -10.0, 0.05)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll = mini(_scroll + 1, maxi(_entries.size() - _rows_fit(), 0))
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll = maxi(_scroll - 1, 0)
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event.is_action_pressed("ui_cancel") and not _builder.is_active():
		set_active(false)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and not _entries.is_empty():
		# Over the world, the wheel steps through what to place.
		var current := _current_index()
		var step := 1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1
		_take(posmod(current + step, _entries.size()) if current >= 0 else 0)
		get_viewport().set_input_as_handled()


func _current_index() -> int:
	if not _builder.is_active():
		return -1
	for index in _entries.size():
		if _entries[index][0] == _builder.held_id():
			return index
	return -1


func _take(index: int) -> void:
	if index < 0 or index >= _entries.size():
		return
	for item in _player.inventory.items:
		if item and item.id == _entries[index][0]:
			_builder.begin(item)
			return


func _draw() -> void:
	if not active:
		return
	draw_style_box(_panel_style, Rect2(Vector2.ZERO, size))
	draw_string_outline(UITheme.bold(), Vector2(0, 38), "BUILD", HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, 4, Color.BLACK)
	draw_string(UITheme.bold(), Vector2(0, 38), "BUILD", HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, UITheme.HEADING)
	draw_string(_font, Vector2(0, 58), "B or Esc to leave", HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, UITheme.DIM)
	if _entries.is_empty():
		draw_multiline_string(_font, Vector2(20, 96), "Nothing to place. Make walls, ground, furniture and more at a crafting table (Build in the menu).", HORIZONTAL_ALIGNMENT_LEFT, size.x - 40.0, 14, 8, UITheme.TEXT)
		return
	var current := _current_index()
	for index in range(_scroll, mini(_entries.size(), _scroll + _rows_fit())):
		var rect := _row_rect(index)
		var item: Item = _entries[index][1]
		draw_style_box(_slots["slot_active" if index == current else "slot_hover" if index == _hover else "slot"], rect)
		var icon_rect := Rect2(rect.position + Vector2(7, 7), Vector2(32, 32))
		var tint := Color.WHITE if item.definition().has("decor") or item.definition().has("ground") else item.icon_tint()
		draw_texture_rect(item.icon(), icon_rect, false, tint)
		var color := UITheme.GOLD if index == current else UITheme.TEXT
		draw_string(_font, rect.position + Vector2(46, 21), item.display_name(), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 54.0, 14, color)
		draw_string(_font, rect.position + Vector2(46, 38), "x%d" % _player.inventory.count_of(item.id), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UITheme.DIM)
	if _scroll > 0:
		draw_string(_font, Vector2(0, 72), "more above", HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, UITheme.DIM)
	if _scroll + _rows_fit() < _entries.size():
		draw_string(_font, Vector2(0, size.y - 16.0), "more below - turn the wheel", HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, UITheme.DIM)
