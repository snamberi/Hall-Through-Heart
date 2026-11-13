class_name RelicSlot
extends Control
## The relic in focus, under the ability column: its icon in a rarity
## frame, the relic key, and its cooldown sweeping down. Click to open the
## relic bag. Hidden until a relic is worn.

const SIZE := 52.0

var _player: Player
var _font: Font


func setup(player: Player) -> void:
	_player = player
	_font = UITheme.bold()
	custom_minimum_size = Vector2(SIZE + 70.0, SIZE + 4.0)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	player.relics.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	var item := _player.relics.focused()
	visible = item != null
	if item:
		var ability := _player.relics.ability_of(item)
		tooltip_text = "%s\n%s (G): %s\n%s worn. Click to open the relic bag." % [item.display_name(), ability["name"], ability["text"],
			"%d of %d relics" % [_player.relics.worn.size(), _player.relics.slots()]]


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		Events.screen_requested.emit("relics")
		accept_event()


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	var item := _player.relics.focused()
	if item == null:
		return
	var rect := Rect2(2, 2, SIZE, SIZE)
	var frame := UITheme.rarity_slot(item.rarity)
	draw_style_box(frame, rect)
	var icon := item.icon()
	if icon:
		draw_texture_rect(icon, rect.grow(-8.0), false, item.icon_tint())
	var left := _player.relics.cooldown_left(item)
	var ability := _player.relics.ability_of(item)
	if left > 0.0:
		var share := clampf(left / float(ability["cooldown"]), 0.0, 1.0)
		draw_rect(Rect2(rect.position.x + 3, rect.end.y - 3 - (rect.size.y - 6) * share, rect.size.x - 6, (rect.size.y - 6) * share), Color(0, 0, 0, 0.6))
		var seconds := str(ceili(left))
		draw_string_outline(_font, rect.position + Vector2(0, 33), seconds, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 17, 4, Color.BLACK)
		draw_string(_font, rect.position + Vector2(0, 33), seconds, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 17, Color.WHITE)
	# The key, in the corner.
	draw_rect(Rect2(rect.position.x - 1, rect.position.y - 1, 15, 15), Color(0.05, 0.05, 0.08, 0.9))
	draw_string(_font, rect.position + Vector2(2, 11), "G", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UITheme.GOLD)
	# Its name and the other relics' count beside it.
	var x := rect.end.x + 6.0
	draw_string_outline(_font, Vector2(x, 22), str(ability["name"]), HORIZONTAL_ALIGNMENT_LEFT, 90, 12, 3, Color.BLACK)
	draw_string(_font, Vector2(x, 22), str(ability["name"]), HORIZONTAL_ALIGNMENT_LEFT, 90, 12, item.color())
	var state := "ready" if left <= 0.0 else "%ds" % ceili(left)
	draw_string_outline(_font, Vector2(x, 38), state, HORIZONTAL_ALIGNMENT_LEFT, 90, 11, 3, Color.BLACK)
	draw_string(_font, Vector2(x, 38), state, HORIZONTAL_ALIGNMENT_LEFT, 90, 11, UITheme.GOOD if left <= 0.0 else UITheme.DIM)
