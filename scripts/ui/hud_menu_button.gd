class_name HudMenuButton
extends Control
## The Menu button in the corner of the HUD: shows the key that opens the
## menu wheel, can be clicked, and wears a badge counting everything that
## waits for the player inside (points to spend, a class to choose).

## True while the mouse is over any clickable piece of the HUD, so a click
## there is not also a sword swing.
static var hovered := false

var _player: Player
var _over := false
var _waiting := 0
var _check := 0.0


func setup(player: Player) -> void:
	_player = player
	custom_minimum_size = Vector2(132.0, 34.0)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "Open the menu wheel: inventory, quests, map and everything else"
	mouse_entered.connect(func() -> void:
		_over = true
		hovered = true
		Audio.play("ui_hover", -16.0, 0.03)
	)
	mouse_exited.connect(func() -> void:
		_over = false
		hovered = false
	)
	tree_exited.connect(func() -> void: hovered = false)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Audio.play("ui_click", -10.0, 0.05)
		Events.screen_requested.emit("wheel")
		accept_event()


func _process(delta: float) -> void:
	_check -= delta
	if _check <= 0.0:
		_check = 0.4
		var menus: Node = _player.get_parent().get_node_or_null("Menus") if _player else null
		_waiting = menus.badge_total() if menus else 0
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var font := UITheme.get_theme().default_font
	draw_rect(rect.grow(2.0), Color(0.02, 0.02, 0.04, 0.85))
	draw_rect(rect, Color(0.16, 0.14, 0.1, 0.96) if _over else Color(0.07, 0.08, 0.13, 0.94))
	draw_rect(rect, UITheme.GOLD if _over else Color("8a683a"), false, 1.5)
	# Three bars: the sign for a menu.
	for k in 3:
		draw_rect(Rect2(10.0, 10.0 + k * 6.0, 16.0, 2.5), UITheme.HEADING)
	draw_string(font, Vector2(34.0, 23.0), "Menu", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UITheme.HEADING if _over else UITheme.TEXT)
	# The key, on a little keycap.
	var key := GameSettings.describe("toggle_menu").split(" / ")[0]
	var cap := Rect2(size.x - 44.0, 6.0, 34.0, 22.0)
	draw_rect(cap, Color(0.2, 0.22, 0.3))
	draw_rect(cap, Color(0.55, 0.58, 0.7), false, 1.0)
	draw_string(UITheme.bold(), cap.position + Vector2(0, 16.0), key, HORIZONTAL_ALIGNMENT_CENTER, cap.size.x, 14, Color.WHITE)
	if _waiting > 0:
		var at := Vector2(size.x - 2.0, 2.0)
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 220.0)
		draw_circle(at, 12.0 + pulse * 3.0, Color(0.95, 0.3, 0.25, 0.3))
		draw_circle(at, 10.0, Color(0.78, 0.16, 0.16))
		draw_arc(at, 10.0, 0.0, TAU, 20, Color(1.0, 0.85, 0.6), 1.5)
		draw_string(UITheme.bold(), at + Vector2(-10.0, 5.0), str(mini(_waiting, 99)), HORIZONTAL_ALIGNMENT_CENTER, 20.0, 13, Color.WHITE)
