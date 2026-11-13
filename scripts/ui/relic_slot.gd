class_name RelicSlot
extends Control
## The relic in focus, under the ability column: its icon in a rarity
## frame, the relic key, and its cooldown sweeping down. Click to open the
## relic bag. Hidden until a relic is worn.

const SIZE := 48.0

var _player: Player
var _font: Font


func setup(player: Player) -> void:
	_player = player
	_font = UITheme.bold()
	custom_minimum_size = Vector2(SIZE + 104.0, SIZE + 12.0)
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
	# The same light plate and dark slot as the ability dock, edged in the
	# relic's rarity colour.
	draw_style_box(ActionBar._make_light_plate(), Rect2(Vector2.ZERO, size))
	var rect := Rect2(6, 6, SIZE, SIZE)
	draw_style_box(UITheme.slot("slot"), rect.grow(3.0))
	draw_rect(rect, Color(0.05, 0.06, 0.1))
	draw_rect(rect, Color(item.color(), 0.9), false, 2.0)
	var icon := item.icon()
	if icon:
		draw_texture_rect(icon, rect.grow(-6.0), false, item.icon_tint())
	var left := _player.relics.cooldown_left(item)
	var ability := _player.relics.ability_of(item)
	if left > 0.0:
		var share := clampf(left / float(ability["cooldown"]), 0.0, 1.0)
		draw_rect(Rect2(rect.position.x + 3, rect.end.y - 3 - (rect.size.y - 6) * share, rect.size.x - 6, (rect.size.y - 6) * share), Color(0, 0, 0, 0.6))
		var seconds := str(ceili(left))
		draw_string_outline(_font, rect.position + Vector2(0, 33), seconds, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 17, 4, Color.BLACK)
		draw_string(_font, rect.position + Vector2(0, 33), seconds, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 17, Color.WHITE)
	# The key, in the corner.
	var key := GameSettings.describe("relic_ability").split(" / ")[0]
	var body := UITheme.get_theme().default_font
	var key_width := maxf(body.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 6.0, 14.0)
	var cap := Rect2(rect.position + Vector2(-2, -2), Vector2(key_width, 15))
	draw_rect(cap, Color(0.04, 0.045, 0.07, 0.95))
	draw_rect(cap, Color("8a683a"), false, 1.0)
	draw_string(body, cap.position + Vector2(3, 12), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UITheme.HEADING)
	# Its power's name, and whether it is ready.
	var x := rect.end.x + 9.0
	draw_string(UITheme.body_bold(), Vector2(x, 26), str(ability["name"]), HORIZONTAL_ALIGNMENT_LEFT, size.x - x - 6.0, 14, UITheme.TEXT)
	var state := "Ready" if left <= 0.0 else "%ds" % ceili(left)
	draw_string(body, Vector2(x, 45), state, HORIZONTAL_ALIGNMENT_LEFT, size.x - x - 6.0, 14, UITheme.GOOD if left <= 0.0 else UITheme.DIM)
