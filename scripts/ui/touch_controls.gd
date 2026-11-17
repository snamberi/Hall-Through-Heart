class_name TouchControls
extends CanvasLayer
## Playing on a phone or tablet: a stick for the left thumb, and for the
## right a big attack button (drag it to aim, tap to strike at the nearest
## foe), the four abilities in an arc round it, dash, parry and use, and a
## few small buttons for the menus. Shown on Android and iOS by itself, or
## anywhere with Settings > Controls > Touch controls.
##
## Every button sends the same input action a key would, so the rest of the
## game cannot tell a thumb from a keyboard.

## True while the controls are in use: the player then aims with them
## rather than with the mouse (see Player.aim_direction).
static var active := false
## Where the attack thumb aims, or zero to aim at the nearest foe.
static var drag_aim := Vector2.ZERO

const STICK_RADIUS := 64.0
const DEAD_ZONE := 0.18
## How far round the player a tap looks for something to strike.
const AUTO_AIM := 320.0
const NAVY := Color(0.06, 0.08, 0.16, 0.55)
const NAVY_HELD := Color(0.16, 0.12, 0.08, 0.7)
const BRONZE := Color(0.83, 0.66, 0.35, 0.9)
const BRONZE_DIM := Color(0.52, 0.33, 0.15, 0.75)

var _player: Player
var _root: Control
## touch index -> what it holds: "stick" or a button id.
var _touches: Dictionary = {}
var _stick_home := Vector2.ZERO
var _stick_base := Vector2.ZERO
var _stick_knob := Vector2.ZERO
var _attack_drag := Vector2.ZERO
## Button id -> {"at": Vector2, "r": float, "action" or "call", "label"}.
var _buttons: Dictionary = {}
var _blockers: Dictionary = {}
var _size := Vector2.ZERO


## Whether the touch controls should show: on by setting, or by itself on a
## phone or tablet.
static func wanted() -> bool:
	match GameSettings.touch_controls:
		"on":
			return true
		"off":
			return false
	return OS.has_feature("mobile") and DisplayServer.is_touchscreen_available()


## The way to aim when playing by touch: the dragged attack button, else the
## nearest foe close by, else the way the player faces.
static func aim_for(player: Player) -> Vector2:
	if drag_aim.length() > 0.2:
		return drag_aim.normalized()
	var best: Node2D = null
	var best_distance := AUTO_AIM
	for node in player.get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.state == Enemy.State.DEAD or enemy.is_wild() or enemy._at_peace():
			continue
		var distance := enemy.global_position.distance_to(player.global_position)
		if distance < best_distance:
			best_distance = distance
			best = enemy
	if best:
		return (best.global_position - player.global_position).normalized()
	return player.facing


func setup(player: Player) -> void:
	_player = player


func _ready() -> void:
	layer = 18
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.draw.connect(_draw_controls)
	add_child(_root)
	GameSettings.changed.connect(_apply)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_apply()


func _exit_tree() -> void:
	_release_all()
	active = false
	drag_aim = Vector2.ZERO


func _apply() -> void:
	var on := wanted()
	if on == active and _root.visible == on:
		return
	active = on
	_root.visible = on
	_set_mouse_attack(not on)
	if not on:
		_release_all()


## While playing by touch the first finger also moves the mouse; a mouse
## click must not swing the sword or the thumb on the stick would.
func _set_mouse_attack(allowed: bool) -> void:
	for action: String in ["attack", "parry"]:
		if not InputMap.has_action(action):
			continue
		for event in InputMap.action_get_events(action):
			if event is InputEventMouseButton and not allowed:
				InputMap.action_erase_event(action, event)
		if allowed:
			var has_mouse := false
			for event in InputMap.action_get_events(action):
				has_mouse = has_mouse or event is InputEventMouseButton
			if not has_mouse:
				var click := InputEventMouseButton.new()
				click.button_index = MOUSE_BUTTON_LEFT if action == "attack" else MOUSE_BUTTON_RIGHT
				InputMap.action_add_event(action, click)


func _layout() -> void:
	_size = get_viewport().get_visible_rect().size
	var w := _size.x
	var h := _size.y
	var attack := Vector2(w - 116.0, h - 128.0)
	# The small menu buttons in a row along the top, between the bars and
	# the minimap.
	var top_row := roundf(w / 2.0 - 112.0)
	_buttons = {
		"attack": {"at": attack, "r": 56.0, "action": "attack", "label": ""},
		"dash": {"at": Vector2(w - 232.0, h - 40.0), "r": 34.0, "action": "dodge", "label": "Dash"},
		"use": {"at": Vector2(w - 38.0, h - 196.0), "r": 28.0, "action": "interact", "label": "Use"},
		"parry": {"at": Vector2(w - 300.0, h - 212.0), "r": 30.0, "action": "parry", "label": "Parry"},
		"swap": {"at": attack + Vector2.from_angle(deg_to_rad(290.0)) * 132.0, "r": 20.0, "action": "ability_swap", "label": "Set"},
		"menu": {"at": Vector2(top_row + 0.0, 34.0), "r": 24.0, "action": "toggle_menu", "label": "", "icon": "pause"},
		"bag": {"at": Vector2(top_row + 56.0, 34.0), "r": 24.0, "action": "open_inventory", "label": "", "icon": "inventory"},
		"map": {"at": Vector2(top_row + 112.0, 34.0), "r": 24.0, "action": "open_map", "label": "", "icon": "map"},
		"quick": {"at": Vector2(top_row + 168.0, 34.0), "r": 24.0, "action": "quick_use", "label": "Drink"},
		"chat": {"at": Vector2(top_row + 224.0, 34.0), "r": 24.0, "action": "open_chat", "label": "Chat", "online": true},
		"run": {"at": Vector2(40.0, h - 250.0), "r": 24.0, "action": "sprint", "label": "Run"},
		"ride": {"at": Vector2(40.0, h - 194.0), "r": 24.0, "action": "mount", "label": "Ride"},
	}
	for k in 4:
		var angle := deg_to_rad(180.0 + 27.0 * k)
		_buttons["ability_%d" % (k + 1)] = {"at": attack + Vector2.from_angle(angle) * 128.0, "r": 30.0, "action": "ability_%d" % (k + 1), "label": "", "slot": k}
	_stick_home = Vector2(150.0, h - 190.0)
	if not _touches.values().has("stick"):
		_stick_base = _stick_home
		_stick_knob = _stick_home
	# Something under each button to catch the mouse click a touch also
	# makes, so the HUD underneath is not pressed through it.
	for id in _blockers:
		(_blockers[id] as Control).queue_free()
	_blockers.clear()
	for id: String in _buttons:
		var blocker := Control.new()
		var r: float = _buttons[id]["r"]
		blocker.position = (_buttons[id]["at"] as Vector2) - Vector2(r, r)
		blocker.size = Vector2(r, r) * 2.0
		blocker.mouse_filter = Control.MOUSE_FILTER_STOP
		_root.add_child(blocker)
		_blockers[id] = blocker
	_root.queue_redraw()


func _process(_delta: float) -> void:
	if not active:
		return
	var show := not get_tree().paused and _player != null and is_instance_valid(_player)
	if _root.visible != show:
		_root.visible = show
		if not show:
			_release_all()
	if show:
		_root.queue_redraw()


func _input(event: InputEvent) -> void:
	if not active or not _root.visible:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			var id := _button_at(touch.position)
			if id != "":
				_touches[touch.index] = id
				if id == "attack":
					_attack_drag = Vector2.ZERO
					drag_aim = Vector2.ZERO
				_send(_buttons[id]["action"], true)
				get_viewport().set_input_as_handled()
			elif _in_stick_zone(touch.position):
				_touches[touch.index] = "stick"
				_stick_base = touch.position
				_stick_knob = touch.position
				get_viewport().set_input_as_handled()
		elif _touches.has(touch.index):
			var held: String = _touches[touch.index]
			_touches.erase(touch.index)
			if held == "stick":
				_stick_base = _stick_home
				_stick_knob = _stick_home
				_move(Vector2.ZERO)
			else:
				if held == "attack":
					drag_aim = Vector2.ZERO
				_send(_buttons[held]["action"], false)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if not _touches.has(drag.index):
			return
		var held: String = _touches[drag.index]
		if held == "stick":
			var offset := drag.position - _stick_base
			if offset.length() > STICK_RADIUS:
				# The base follows a thumb that runs past it.
				_stick_base = drag.position - offset.normalized() * STICK_RADIUS
				offset = offset.normalized() * STICK_RADIUS
			_stick_knob = _stick_base + offset
			_move(offset / STICK_RADIUS)
		elif held == "attack":
			_attack_drag = drag.position - (_buttons["attack"]["at"] as Vector2)
			drag_aim = _attack_drag / 60.0 if _attack_drag.length() > 18.0 else Vector2.ZERO
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	# The phone's back button: out of a menu, or into the pause screen.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		var back := InputEventAction.new()
		back.action = "ui_cancel"
		back.pressed = true
		Input.parse_input_event(back)
		var up := InputEventAction.new()
		up.action = "ui_cancel"
		up.pressed = false
		Input.parse_input_event(up)


func _shown(button: Dictionary) -> bool:
	return not button.get("online", false) or Net.online()


func _button_at(point: Vector2) -> String:
	for id: String in _buttons:
		var button: Dictionary = _buttons[id]
		if _shown(button) and point.distance_to(button["at"]) <= float(button["r"]) + 8.0:
			return id
	return ""


func _in_stick_zone(point: Vector2) -> bool:
	return point.x < _size.x * 0.42 and point.y > _size.y * 0.3 and point.y < _size.y - 96.0


func _send(action: String, pressed: bool) -> void:
	if not InputMap.has_action(action):
		return
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(event)


func _move(direction: Vector2) -> void:
	var strength := direction.length()
	if strength < DEAD_ZONE:
		direction = Vector2.ZERO
	for pair: Array in [["move_right", maxf(direction.x, 0.0)], ["move_left", maxf(-direction.x, 0.0)], ["move_down", maxf(direction.y, 0.0)], ["move_up", maxf(-direction.y, 0.0)]]:
		if float(pair[1]) > 0.0:
			Input.action_press(pair[0], clampf(float(pair[1]), 0.0, 1.0))
		else:
			Input.action_release(pair[0])


func _release_all() -> void:
	for index in _touches:
		var held: String = _touches[index]
		if held != "stick" and _buttons.has(held):
			_send(_buttons[held]["action"], false)
	_touches.clear()
	_move(Vector2.ZERO)
	drag_aim = Vector2.ZERO
	_stick_base = _stick_home
	_stick_knob = _stick_home


func _draw_controls() -> void:
	if not active or _player == null or not is_instance_valid(_player):
		return
	var held_ids: Array = _touches.values()
	# The stick.
	var stick_held := held_ids.has("stick")
	_ring(_stick_base, STICK_RADIUS, NAVY if not stick_held else NAVY_HELD, BRONZE_DIM if not stick_held else BRONZE)
	_ring(_stick_knob.round(), 26.0, Color(0.83, 0.66, 0.35, 0.35 if not stick_held else 0.6), BRONZE)
	var font := UITheme.bold()
	var slots: Array[String] = _player.abilities.slots()
	for id: String in _buttons:
		var button: Dictionary = _buttons[id]
		if not _shown(button):
			continue
		var at: Vector2 = (button["at"] as Vector2).round()
		var r: float = button["r"]
		var held := held_ids.has(id)
		_ring(at, r, NAVY_HELD if held else NAVY, BRONZE if held else BRONZE_DIM)
		if button.has("slot"):
			var ability_id: String = slots[button["slot"]] if int(button["slot"]) < slots.size() else ""
			if ability_id == "" or not AbilityDB.ABILITIES.has(ability_id):
				continue
			var icon := AbilityDB.icon(ability_id)
			var reason := _player.abilities.blocked_reason(ability_id)
			_icon(icon, at, Color.WHITE if reason == "" else Color(0.5, 0.5, 0.55))
			if reason == "cooldown":
				var left: float = _player.abilities.cooldowns.get(ability_id, 0.0)
				var share := clampf(left / maxf(float(AbilityDB.ABILITIES[ability_id].get("cooldown", 1.0)), 0.01), 0.0, 1.0)
				_root.draw_arc(at, r - 3.0, -PI / 2.0, -PI / 2.0 + TAU * share, 24, Color(0.0, 0.0, 0.0, 0.7), 5.0)
				var seconds := "%.1f" % left if left < 10.0 else "%d" % ceili(left)
				_root.draw_string_outline(font, at + Vector2(-r, 6), seconds, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 15, 4, Color.BLACK)
				_root.draw_string(font, at + Vector2(-r, 6), seconds, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 15, UITheme.TEXT)
			continue
		if id == "attack":
			var weapon := _player.equipment.weapon()
			if weapon:
				_icon(weapon.icon(), at, Color.WHITE, 2)
			else:
				_label(font, at, "Strike", 16)
			if _attack_drag.length() > 18.0:
				var tip := at + _attack_drag.limit_length(r + 18.0)
				_root.draw_line(at, tip, BRONZE, 3.0)
				_root.draw_circle(tip, 6.0, BRONZE)
			continue
		if button.has("icon"):
			_icon(MenuIcons.icon(button["icon"]), at, Color.WHITE)
		else:
			var text: String = button["label"]
			if id == "run" and _player.sprinting:
				text = "Walk"
			_label(font, at, text, 13 if r < 26.0 else 15)


func _ring(at: Vector2, r: float, fill: Color, edge: Color) -> void:
	_root.draw_circle(at, r, fill)
	_root.draw_arc(at, r, 0.0, TAU, maxi(24, int(r)), Color(0.04, 0.05, 0.09, 0.8), 4.0)
	_root.draw_arc(at, r - 2.0, 0.0, TAU, maxi(24, int(r)), edge, 2.0)


## A picture drawn whole-pixel: at its own size, or `scale` times it.
func _icon(texture: Texture2D, at: Vector2, tint: Color, scale: int = 1) -> void:
	if texture == null:
		return
	var size := texture.get_size() * scale
	_root.draw_texture_rect(texture, Rect2((at - size / 2.0).round(), size), false, tint)


func _label(font: Font, at: Vector2, text: String, size: int) -> void:
	var width := 90.0
	var origin := (at + Vector2(-width / 2.0, size * 0.35)).round()
	_root.draw_string_outline(font, origin, text, HORIZONTAL_ALIGNMENT_CENTER, width, size, 4, Color(0.02, 0.02, 0.05))
	_root.draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_CENTER, width, size, UITheme.TEXT)
