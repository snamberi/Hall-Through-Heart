class_name PhotoMode
extends Node
## Photo mode: the interface hides and the world holds still. Look around
## with the movement keys, zoom with + and - (whole steps only, so pixels
## stay square), F12 saves a picture to the screenshots folder, and the
## photo key or Escape goes back.

var active := false
var _player: Player
var _offset := Vector2.ZERO
var _zoom := 2.0
var _was_smooth := true
var _hidden: Array[CanvasLayer] = []
var _banner: CanvasLayer
var _banner_label: Label


func setup(player: Player) -> void:
	_player = player
	process_mode = Node.PROCESS_MODE_ALWAYS
	_banner = CanvasLayer.new()
	_banner.layer = 20
	_banner.visible = false
	add_child(_banner)
	_banner_label = UITheme.label("", 15, UITheme.HEADING)
	_banner_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner_label.position.y = 14.0
	_banner_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_banner_label.add_theme_constant_override("outline_size", 6)
	_banner.add_child(_banner_label)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("photo_mode"):
		toggle()
		get_viewport().set_input_as_handled()
		return
	if not active:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_ESCAPE:
			toggle()
		KEY_F12:
			_save_picture()
		KEY_EQUAL, KEY_KP_ADD, KEY_PLUS:
			_zoom = minf(_zoom + 1.0, 4.0)
		KEY_MINUS, KEY_KP_SUBTRACT:
			_zoom = maxf(_zoom - 1.0, 1.0)
	get_viewport().set_input_as_handled()


func toggle() -> void:
	var menus: Node = _player.get_parent().get_node_or_null("Menus")
	if not active and (menus == null or menus.is_open() or _player.is_dead()):
		return
	active = not active
	if active:
		_hidden.clear()
		for child in _player.get_parent().get_children():
			if child is CanvasLayer and child != _banner and (child as CanvasLayer).visible and child.name in ["HUD", "OverlayHUD", "Menus", "DebugHUD"]:
				_hidden.append(child)
				(child as CanvasLayer).visible = false
		_offset = _player.camera.offset
		_zoom = roundf(_player.camera.zoom.x)
		_was_smooth = _player.camera.position_smoothing_enabled
		_player.camera.position_smoothing_enabled = false
		get_tree().paused = true
		_banner.visible = true
		_banner_label.text = "PHOTO MODE   ·   %s: look around   ·   + / -: zoom   ·   F12: save a picture   ·   %s or Esc: back" % [
			"WASD", GameSettings.describe("photo_mode").split(" / ")[0]]
		_banner_label.modulate.a = 1.0
		create_tween().tween_property(_banner_label, "modulate:a", 0.0, 1.2).set_delay(3.0)
	else:
		for layer in _hidden:
			if is_instance_valid(layer):
				layer.visible = true
		_hidden.clear()
		_player.camera.offset = Vector2.ZERO
		_player.camera.position_smoothing_enabled = _was_smooth
		_banner.visible = false
		get_tree().paused = false


func _process(delta: float) -> void:
	if not active:
		return
	var move := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_offset += move * 420.0 * delta / _zoom
	_offset = _offset.limit_length(900.0)
	_player.camera.offset = _offset.round()
	_player.camera.zoom = Vector2(_zoom, _zoom)


## Saves what is on screen (without the interface) as a picture.
func _save_picture() -> void:
	DirAccess.make_dir_recursive_absolute("user://screenshots")
	_banner.visible = false
	await RenderingServer.frame_post_draw
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var path := "user://screenshots/hall_through_heart_%s.png" % stamp
	get_viewport().get_texture().get_image().save_png(path)
	_banner.visible = true
	_banner_label.text = "Saved: %s" % ProjectSettings.globalize_path(path)
	_banner_label.modulate.a = 1.0
	create_tween().tween_property(_banner_label, "modulate:a", 0.0, 1.0).set_delay(2.5)
