extends CanvasLayer
## Owns the pause menus and makes sure only one is open at a time.
##
## The game is paused while any menu is open. Switching from one menu to
## another keeps it paused.


## input action -> menu
var _menus: Dictionary[String, GameMenu] = {}
var _open: GameMenu
var _player: Player
var _dim: ColorRect
var _center: CenterContainer


func _ready() -> void:
	# Keep handling input while the rest of the game is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func setup(player: Player) -> void:
	_player = player
	_dim = ColorRect.new()
	_dim.color = Color(0.0, 0.0, 0.0, 0.6)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)
	_center = CenterContainer.new()
	_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_center)

	var hint := GameMenu.make_label("C Character     M Mastery     Esc Close", 14, Color(0.6, 0.58, 0.54))
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint.position.y -= 24.0
	hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(hint)

	_add("toggle_character", CharacterMenu.new())
	_add("toggle_mastery", MasteryMenu.new())


func is_open() -> bool:
	return _open != null


## Opens the menu bound to an input action, closing any other.
func open(action: String) -> void:
	if _player.is_dead() or not _menus.has(action):
		return
	if _open:
		_open.visible = false
	_open = _menus[action]
	_open.visible = true
	_open.refresh()
	visible = true
	get_tree().paused = true


func close() -> void:
	if _open:
		_open.visible = false
	_open = null
	visible = false
	get_tree().paused = false


func _input(event: InputEvent) -> void:
	if _player == null:
		return
	if _open and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
		return
	for action in _menus:
		if event.is_action_pressed(action):
			if _open == _menus[action]:
				close()
			else:
				open(action)
			get_viewport().set_input_as_handled()
			return


func _add(action: String, menu: GameMenu) -> void:
	menu.visible = false
	_center.add_child(menu)
	menu.setup(_player)
	_menus[action] = menu
