extends CanvasLayer
## Every pause-time screen, and the wheel that leads to them.
##
## M (or `) opens the menu wheel; clicking a wedge opens that screen by
## itself, and every screen has a Back button to the wheel. No screen has a
## key of its own: the wheel is the one way in. Shops and boards open by
## talking to people. Esc closes whatever is open, or opens the pause menu
## if nothing is. The game is paused while anything here is showing.
##
## To add a screen: write a GameMenu subclass and add a line to SCREENS.

## "icon" is an index into the item icon atlas; "text" is the line shown in
## the wheel's hub. "wheel": false keeps a screen off the wheel.
## Main screens go on the wheel (exactly eight, clockwise from the top);
## the rest ("side") are listed in the panel to its left.
const SCREENS: Array[Dictionary] = [
	{"id": "inventory", "title": "Inventory", "icon": 17, "text": "Bags, gear,\nand crafting by hand"},
	{"id": "abilities", "title": "Abilities", "icon": 27, "text": "Choose and rank up\nyour active skills"},
	{"id": "class", "title": "Class", "icon": 6, "text": "Your calling\nand its path"},
	{"id": "magic", "title": "Magic", "icon": 33, "text": "Schools of magic\nand their spells"},
	{"id": "build", "title": "Build", "icon": 56, "text": "Walls, ground,\nfurniture and more"},
	{"id": "professions", "title": "Professions", "icon": 49, "text": "Mining, smithing,\ncooking and the rest"},
	{"id": "journal", "title": "Quests", "icon": 41, "text": "The quest book:\nevery chapter and goal"},
	{"id": "map", "title": "Map", "icon": 12, "text": "The land as far\nas you have walked"},
	{"id": "attributes", "title": "Character", "icon": 38, "text": "Attribute points", "side": true, "group": "Character"},
	{"id": "talents", "title": "Talents", "icon": 28, "text": "Passive gifts", "side": true, "group": "Character"},
	{"id": "mastery", "title": "Mastery", "icon": 0, "text": "Weapon skill", "side": true, "group": "Character"},
	{"id": "evolution", "title": "Evolution", "icon": 39, "text": "Your race's paths", "side": true, "group": "Character"},
	{"id": "codex", "title": "Codex", "icon": 53, "text": "Bestiary and feats", "side": true, "group": "Collection"},
	{"id": "pets", "title": "Pets", "icon": 95, "text": "Companions, mounts", "side": true, "group": "Collection"},
	{"id": "relics", "title": "Relics", "icon": 102, "text": "Boss relics and powers", "side": true, "group": "Collection"},
	{"id": "wardrobe", "title": "Wardrobe", "icon": 7, "text": "Looks and colours", "side": true, "group": "Collection"},
	{"id": "pause", "title": "Settings", "icon": 5, "text": "Options and saving", "side": true, "group": "System"},
]
## Screens with a key of their own (rebindable): action -> screen id.
const SHORTCUTS := {"open_inventory": "inventory", "open_quests": "journal", "open_map": "map"}
## Where a screen's Back button leads, when not to the wheel. "" closes.
const BACK := {"settings": "pause", "teacher": "", "villager": "", "furnace": "", "shop": "", "quest_board": "", "bounty_board": "", "waystones": "", "recruit": "", "storage": ""}

var _menus: Dictionary[String, GameMenu] = {}
## "" when closed, "wheel", or a screen id.
var _open_id := ""
var _player: Player
var _root: Control
var _wheel: MenuWheel
## The panel left of the wheel, listing the other screens.
var _side: PanelContainer
var _side_badges: Dictionary = {}
var _holder: CenterContainer
var _hint: Label
var _back: Button
var _fade: Tween


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
		if not screen.get("side", false):
			_wheel.entries.append(screen)
	_wheel.chosen.connect(open)
	_wheel.badge_for = badge_for
	_wheel.hub_text = func() -> Array:
		return ["Menu", "Level %d\n%d gold" % [_player.leveling.level, _player.inventory.gold]]
	_root.add_child(_wheel)
	_side = _make_side_panel()
	_root.add_child(_side)

	_holder = CenterContainer.new()
	_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_holder)

	_back = UITheme.button("<  Menu", _go_back, 118.0)
	_back.position = Vector2(18.0, 16.0)
	_back.custom_minimum_size.y = 38.0
	UITheme.font_size(_back, 17)
	_root.add_child(_back)

	_hint = UITheme.label("", 14, UITheme.DIM)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -30.0
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_hint)

	_add("inventory", InventoryMenu.new())
	_add("attributes", CharacterMenu.new())
	_add("mastery", MasteryMenu.new())
	_add("talents", TalentMenu.new())
	_add("abilities", AbilitiesMenu.new())
	_add("class", ClassMenu.new())
	_add("professions", ProfessionsMenu.new())
	_add("journal", QuestBookMenu.new())
	_add("shop", ShopMenu.new())
	_add("quest_board", QuestBoardMenu.new())
	_add("bounty_board", BountyBoardMenu.new())
	_add("waystones", WaystoneMenu.new())
	_add("recruit", RecruitMenu.new())
	_add("codex", CodexMenu.new())
	_add("pets", PetsMenu.new())
	_add("relics", RelicsMenu.new())
	_add("teacher", TeacherMenu.new())
	_add("villager", VillagerMenu.new())
	_add("furnace", FurnaceMenu.new())
	_add("magic", MagicMenu.new())
	_add("evolution", EvolutionMenu.new())
	_add("build", BuildMenu.new())
	_add("wardrobe", WardrobeMenu.new())
	_add("storage", StorageMenu.new())
	Events.screen_requested.connect(func(id: String) -> void:
		if id == "wheel":
			open_wheel()
		else:
			open(id)
	)
	get_viewport().size_changed.connect(_fit)
	Events.loot_opened.connect(func(container: Dictionary) -> void:
		(_menus["storage"] as StorageMenu).chest = container
		open("storage")
	)
	Events.storage_opened.connect(func(building: Dictionary) -> void:
		(_menus["storage"] as StorageMenu).chest = building
		open("storage")
	)
	Events.npc_interacted.connect(_on_npc_interacted)
	Events.furnace_opened.connect(func(record: Dictionary) -> void:
		(_menus["furnace"] as FurnaceMenu).record = record
		open("furnace")
	)
	_add("map", MapMenu.new())
	_add("pause", PauseMenu.new())
	_add("settings", SettingsMenu.new())


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
	var focused := get_viewport().gui_get_focus_owner()
	if focused:
		focused.release_focus()
	get_tree().paused = false


func _show(id: String) -> void:
	var changed := id != _open_id
	_open_id = id
	_wheel.visible = id == "wheel"
	_side.visible = id == "wheel"
	if _side.visible:
		_refresh_side()
	for other in _menus:
		_menus[other].visible = other == id
	_back.visible = id != "wheel"
	_back.text = "<  Menu" if BACK.get(id, "wheel") == "wheel" else "<  Back" if BACK[id] != "" else "x  Close"
	_hint.text = "%s  Close      Tab  More list" % GameSettings.describe("toggle_menu").split(" / ")[0] if id == "wheel" else "Esc  Close"
	visible = true
	get_tree().paused = true
	if id != "wheel" and changed:
		# Screens ease in rather than snapping onto the screen.
		if _fade:
			_fade.kill()
		_holder.modulate.a = 0.0
		_fade = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_fade.tween_property(_holder, "modulate:a", 1.0, 0.12)
	_fit.call_deferred()


func _process(_delta: float) -> void:
	# Screens can change size as they fill in; keep them inside the window.
	if is_open() and _open_id != "wheel":
		_fit()
	elif _open_id == "wheel":
		_refresh_side()


## Where the Back button leads from the open screen.
func _go_back() -> void:
	var target: String = BACK.get(_open_id, "wheel")
	if target == "wheel":
		open_wheel()
	elif target == "":
		close()
	else:
		open(target)


## Shrinks a screen that is too big for the window (a large interface size
## on a small window) so nothing runs off the edge.
func _fit() -> void:
	if _holder == null or not is_open() or _open_id == "wheel":
		return
	var menu: GameMenu = _menus[_open_id]
	var room := _root.size - Vector2(24.0, 70.0)
	var need := menu.get_combined_minimum_size().max(menu.size)
	var scale_by := minf(1.0, minf(room.x / maxf(need.x, 1.0), room.y / maxf(need.y, 1.0)))
	_holder.pivot_offset = _root.size / 2.0
	_holder.scale = Vector2(scale_by, scale_by)


## A slim panel to the left of the wheel: every screen that is not on the
## wheel, one row each with its icon and a badge when something waits.
func _make_side_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = Vector2(26.0, 120.0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var group := ""
	for screen in SCREENS:
		if not screen.get("side", false):
			continue
		if screen.get("group", "") != group:
			# A quiet heading over each group, so nine rows scan as three.
			group = screen["group"]
			var heading := UITheme.heading(group, 15)
			if box.get_child_count() > 0:
				var gap := Control.new()
				gap.custom_minimum_size = Vector2(0, 4)
				box.add_child(gap)
			box.add_child(heading)
		var row := Button.new()
		row.text = screen["title"]
		row.icon = MenuIcons.icon(screen["id"])
		row.expand_icon = false
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.custom_minimum_size = Vector2(176.0, 34.0)
		row.add_theme_constant_override("icon_max_width", 22)
		UITheme.font_size(row, 16)
		row.tooltip_text = screen.get("text", "")
		var id: String = screen["id"]
		row.pressed.connect(func() -> void: open(id))
		UITheme.sounds(row)
		var badge := Label.new()
		badge.add_theme_color_override("font_color", Color(1.0, 0.6, 0.5))
		UITheme.font_size(badge, 15)
		badge.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
		badge.offset_left = -30.0
		badge.offset_right = -8.0
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(badge)
		_side_badges[id] = badge
		box.add_child(row)
	return panel


func _refresh_side() -> void:
	for id: String in _side_badges:
		var waiting := badge_for(id)
		(_side_badges[id] as Label).text = str(waiting) if waiting > 0 else ""
	var room := _root.size
	_side.position = Vector2(maxf(16.0, room.x / 2.0 - MenuWheel.OUTER - _side.size.x - 40.0), (room.y - _side.size.y) / 2.0)


## How many things wait for the player on a screen (points to spend...).
func badge_for(id: String) -> int:
	match id:
		"attributes":
			return _player.attributes.unspent
		"talents":
			return _player.leveling.talent_points
		"class":
			return 1 if _player.class_id == "adventurer" and _player.leveling.level >= HeroClasses.CHOICE_LEVEL else 0
		"abilities":
			return _player.abilities.unspent_points() if _player.abilities.has_method("unspent_points") else 0
	return 0


## Everything waiting, across all screens: the number on the HUD's menu button.
func badge_total() -> int:
	var total := 0
	for screen in SCREENS:
		total += badge_for(screen["id"])
	return total


## Talking to someone opens their screen.
func _on_npc_interacted(npc: Node) -> void:
	if npc.kind == "master":
		(_menus["teacher"] as TeacherMenu).style = npc.offer.get("style", "fist")
		(_menus["teacher"] as TeacherMenu).master = npc.title_text
		open("teacher")
		return
	if npc.kind == "recruit":
		(_menus["recruit"] as RecruitMenu).offer = npc.offer
		open("recruit")
		return
	if npc.kind == "settler":
		if npc.stock_kind != "":
			(_menus["shop"] as ShopMenu).npc = npc
			open("shop")
		else:
			(_player.get_parent().get_node("Settlers") as Settlers).talk(npc)
		return
	if npc.kind == "villager":
		if npc.villager_name != "":
			npc.attend(_player.global_position)
			(_menus["villager"] as VillagerMenu).npc = npc
			open("villager")
		else:
			Events.announcement.emit("", "\"%s\"" % npc.say_something())
		return
	if npc.kind == "merchant":
		(_menus["shop"] as ShopMenu).npc = npc
		open("shop")
	else:
		open("quest_board")


func _input(event: InputEvent) -> void:
	if _player == null:
		return
	if event.is_action_pressed("ui_cancel"):
		if is_open():
			close()
		else:
			open("pause")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_menu") and not get_viewport().gui_get_focus_owner() is LineEdit:
		if _open_id == "wheel":
			close()
		else:
			open_wheel()
		get_viewport().set_input_as_handled()
	elif _shortcut(event):
		get_viewport().set_input_as_handled()
	elif _open_id == "wheel" and event is InputEventKey and event.pressed and not event.echo and _wheel_key(event):
		get_viewport().set_input_as_handled()
	elif is_open() and event is InputEventKey and event.pressed and get_viewport().gui_get_focus_owner() == null:
		# The first arrow or Tab press on a screen picks up its first control,
		# so every screen can be worked from the keyboard.
		for action: String in ["ui_focus_next", "ui_focus_prev", "ui_up", "ui_down", "ui_left", "ui_right"]:
			if event.is_action_pressed(action, true):
				var root: Control = _side if _open_id == "wheel" else _menus[_open_id]
				if UITheme.focus_first(root):
					get_viewport().set_input_as_handled()
				break


## A screen's own key: opens it, or closes it if it is the one showing.
func _shortcut(event: InputEvent) -> bool:
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return false
	for action: String in SHORTCUTS:
		if InputMap.has_action(action) and event.is_action_pressed(action):
			if _open_id == SHORTCUTS[action]:
				close()
			elif not is_open() or _open_id == "wheel" or SHORTCUTS.values().has(_open_id):
				open(SHORTCUTS[action])
			return true
	return false


## The wheel from the keyboard: numbers open a wedge, the arrows step
## round it and Enter opens the lit one.
func _wheel_key(event: InputEventKey) -> bool:
	if get_viewport().gui_get_focus_owner() != null:
		return false
	var number := event.keycode - KEY_0 if event.keycode >= KEY_1 and event.keycode <= KEY_8 else 0
	if number > 0:
		return _wheel.open_lit(number)
	if event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down"):
		_wheel.step(1)
		return true
	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"):
		_wheel.step(-1)
		return true
	if event.is_action_pressed("ui_accept"):
		return _wheel.open_lit()
	return false


func _add(id: String, menu: GameMenu) -> void:
	menu.visible = false
	_holder.add_child(menu)
	menu.setup(_player)
	_menus[id] = menu
