class_name HoldButton
extends Button
## A button for things that cannot be undone. When `needs_hold` says so (a
## rare or better item, say) it must be held down for `hold_seconds`, a bar
## filling across it, before `on_confirm` runs; letting go early does
## nothing. Otherwise it acts on an ordinary press. Holding Enter or Space
## while it has focus counts as holding it.

var on_confirm: Callable
var needs_hold: Callable
var hold_seconds := 0.8
## What the button says while it waits to be held.
var hold_hint := "Hold to confirm"

var _held := 0.0
var _holding := false


func _init() -> void:
	button_down.connect(func() -> void:
		if _must_hold():
			_holding = true
			_held = 0.0
	)
	button_up.connect(_let_go)
	pressed.connect(func() -> void:
		if not _must_hold() and on_confirm.is_valid():
			on_confirm.call()
	)
	focus_exited.connect(_let_go)


func _must_hold() -> bool:
	return needs_hold.is_valid() and bool(needs_hold.call())


func _let_go() -> void:
	_holding = false
	_held = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	var keyboard := has_focus() and (Input.is_action_pressed("ui_accept")) and _must_hold() and not disabled
	if keyboard and not _holding:
		_holding = true
		_held = 0.0
	if not _holding:
		return
	if disabled or (not keyboard and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
		_let_go()
		return
	_held += delta
	queue_redraw()
	if _held >= hold_seconds:
		_let_go()
		if on_confirm.is_valid():
			on_confirm.call()


func _draw() -> void:
	if _holding and _held > 0.0:
		var fill := clampf(_held / hold_seconds, 0.0, 1.0)
		draw_rect(Rect2(Vector2(3, size.y - 6), Vector2((size.x - 6) * fill, 3)), Color(1.0, 0.55, 0.45, 0.95))


## Builds one in the danger style.
static func make(text: String, action: Callable, hold_when: Callable, minimum_width: float = 84.0) -> HoldButton:
	var button := HoldButton.new()
	button.text = text
	button.on_confirm = action
	button.needs_hold = hold_when
	button.theme_type_variation = &"DangerButton"
	button.custom_minimum_size = Vector2(minimum_width, 34.0)
	UITheme.font_size(button, UITheme.BODY)
	UITheme.sounds(button)
	return button
