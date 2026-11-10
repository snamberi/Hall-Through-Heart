extends CanvasLayer
## Every pause-time screen, and the wheel that leads to them.
##
## M (or Tab) opens the menu wheel; clicking a wedge opens that screen by
## itself. E, C, K, and P open Inventory, Attributes, Talents, and
## Professions directly. Esc closes whatever is open, or opens the pause
## menu if nothing is. The game is paused while anything here is showing.
##
## To add a screen: write a GameMenu subclass and add a line to SCREENS.

## "action" is an optional input action that opens the screen directly.
## "icon" is an index into the item icon atlas. "wheel": false keeps a
## screen off the wheel.
const SCREENS: Array[Dictionary] = [
	{"id": "inventory", "title": "Inventory", "icon": 17, "action": "toggle_inventory"},
	{"id": "attributes", "title": "Attributes", "icon": 38, "action": "toggle_character"},
	{"id": "mastery", "title": "Mastery", "icon": 0, "action": ""},
	{"id": "talents", "title": "Talents", "icon": 28, "action": "toggle_talents"},
	{"id": "class", "title": "Class", "icon": 6, "action": ""},
	{"id": "professions", "title": "Professions", "icon": 49, "action": "toggle_professions"},
	{"id": "map", "title": "Map", "icon": 12, "action": ""},
	{"id": "pause", "title": "Settings", "icon": 5, "action": ""},
]

var _menus: Dictionary[String, GameMenu] = {}
## "" when closed, "wheel", or a screen id.
var _open_id := ""
var _player: Player
var _root: Control
var _wheel: MenuWheel
var _holder: CenterContainer
var _hint: Label


func _ready() -> void:
	# Keep handling input while the rest of the game is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func setup(player: Player) -> void:
	_player = player
	_root = Control.new()
	_root.theme = UITheme.get_theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.05, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	_wheel = MenuWheel.new()
	for screen in SCREENS:
		if screen.get("wheel", true):
			_wheel.entries.append(screen)
	_wheel.chosen.connect(open)
	_root.add_child(_wheel)

	_holder = CenterContainer.new()
	_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_holder)

	_hint = UITheme.label("", 14, UITheme.DIM)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -30.0
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_hint)

	_add("inventory", InventoryMenu.new())
	_add("attributes", CharacterMenu.new())
	_add("mastery", MasteryMenu.new())
	_add("talents", TalentMenu.new())
	_add("class", ClassMenu.new())
	_add("professions", ProfessionsMenu.new())
	_add("map", MapMenu.new())
	_add("pause", PauseMenu.new())


func is_open() -> bool:
	return _open_id != ""


func open_id() -> String:
	return _open_id


func get_menu(id: String) -> GameMenu:
	return _menus[id]


## Opens one screen by id, alone.
func open(id: String) -> void:
	if _player.is_dead() or not _menus.has(id):
		return
	_show(id)
	_menus[id].refresh()


func open_wheel() -> void:
	if not _player.is_dead():
		_show("wheel")


func close() -> void:
	_open_id = ""
	visible = false
	get_tree().paused = false


func _show(id: String) -> void:
	_open_id = id
	_wheel.visible = id == "wheel"
	for other in _menus:
		_menus[other].visible = other == id
	_hint.text = "M Close" if id == "wheel" else "M Menu wheel     Esc Close"
	visible = true
	get_tree().paused = true


func _input(event: InputEvent) -> void:
	if _player == null:
		return
	if event.is_action_pressed("ui_cancel"):
		if is_open():
			close()
		else:
			open("pause")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_menu"):
		if _open_id == "wheel":
			close()
		else:
			open_wheel()
		get_viewport().set_input_as_handled()
	else:
		for screen in SCREENS:
			if screen["action"] != "" and event.is_action_pressed(screen["action"]):
				if _open_id == screen["id"]:
					close()
				else:
					open(screen["id"])
				get_viewport().set_input_as_handled()
				return


func _add(id: String, menu: GameMenu) -> void:
	menu.visible = false
	_holder.add_child(menu)
	menu.setup(_player)
	_menus[id] = menu
