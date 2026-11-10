extends CanvasLayer
## The main menu: a row of tabs across the top, one screen per tab.
##
## M (or Tab) opens it on the last tab used. E, C, and K jump straight to
## Inventory, Attributes, and Talents. The game is paused while it is open,
## and switching tabs keeps it paused.
##
## To add a screen: write a GameMenu subclass and add a line to TABS.

## "action" is an optional input action that opens the tab directly.
## "icon" is an index into the item icon atlas.
const TABS: Array[Dictionary] = [
	{"id": "inventory", "title": "Inventory", "icon": 17, "action": "toggle_inventory"},
	{"id": "attributes", "title": "Attributes", "icon": 38, "action": "toggle_character"},
	{"id": "mastery", "title": "Mastery", "icon": 0, "action": ""},
	{"id": "talents", "title": "Talents", "icon": 28, "action": "toggle_talents"},
	{"id": "class", "title": "Class", "icon": 6, "action": ""},
	{"id": "map", "title": "Map", "icon": 12, "action": ""},
	{"id": "system", "title": "System", "icon": 5, "action": ""},
]

var _menus: Dictionary[String, GameMenu] = {}
var _buttons: Dictionary[String, Button] = {}
var _open_id := ""
var _last_id := "inventory"
var _player: Player
var _root: Control
var _holder: CenterContainer


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

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	_root.add_child(margin)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	margin.add_child(rows)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	rows.add_child(bar)
	var title := UITheme.heading("Hall Through Heart", 26)
	title.custom_minimum_size.x = 250.0
	bar.add_child(title)
	for tab in TABS:
		var button := Button.new()
		button.text = " " + tab["title"]
		button.icon = ItemDB.icon(tab["icon"])
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(118.0, 40.0)
		button.add_theme_constant_override("icon_max_width", 22)
		button.pressed.connect(open.bind(tab["id"]))
		bar.add_child(button)
		_buttons[tab["id"]] = button

	_holder = CenterContainer.new()
	_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(_holder)

	var hint := UITheme.label("E Inventory     C Attributes     K Talents     M Menu     Esc Close", 14, UITheme.DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(hint)

	_add("inventory", InventoryMenu.new())
	_add("attributes", CharacterMenu.new())
	_add("mastery", MasteryMenu.new())
	_add("talents", TalentMenu.new())
	_add("class", ClassMenu.new())
	_add("map", MapMenu.new())
	_add("system", SystemMenu.new())


func is_open() -> bool:
	return _open_id != ""


func get_menu(id: String) -> GameMenu:
	return _menus[id]


## Opens a tab by id, closing whichever was showing.
func open(id: String) -> void:
	if _player.is_dead() or not _menus.has(id):
		return
	for other in _menus:
		_menus[other].visible = other == id
		_buttons[other].set_pressed_no_signal(other == id)
	_open_id = id
	_last_id = id
	_menus[id].refresh()
	visible = true
	get_tree().paused = true


func close() -> void:
	_open_id = ""
	visible = false
	get_tree().paused = false


func _input(event: InputEvent) -> void:
	if _player == null:
		return
	if is_open() and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("toggle_menu"):
		if is_open():
			close()
		else:
			open(_last_id)
		get_viewport().set_input_as_handled()
		return
	for tab in TABS:
		if tab["action"] != "" and event.is_action_pressed(tab["action"]):
			if _open_id == tab["id"]:
				close()
			else:
				open(tab["id"])
			get_viewport().set_input_as_handled()
			return


func _add(id: String, menu: GameMenu) -> void:
	menu.visible = false
	_holder.add_child(menu)
	menu.setup(_player)
	_menus[id] = menu
