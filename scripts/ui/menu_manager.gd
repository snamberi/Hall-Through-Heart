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
const SCREENS: Array[Dictionary] = [
	{"id": "inventory", "title": "Inventory", "icon": 17, "text": "Bags, gear,\nand crafting by hand"},
	{"id": "attributes", "title": "Attributes", "icon": 38, "text": "Spend points on\nstrength, vigour, ..."},
	{"id": "mastery", "title": "Mastery", "icon": 0, "text": "Skill with each\nkind of weapon"},
	{"id": "talents", "title": "Talents", "icon": 28, "text": "Passive gifts bought\nwith talent points"},
	{"id": "abilities", "title": "Abilities", "icon": 27, "text": "Choose and rank up\nyour active skills"},
	{"id": "class", "title": "Class", "icon": 6, "text": "Your calling\nand its path"},
	{"id": "professions", "title": "Professions", "icon": 49, "text": "Mining, smithing,\ncooking and the rest"},
	{"id": "journal", "title": "Quests", "icon": 41, "text": "The quest book:\nevery chapter and goal"},
	{"id": "map", "title": "Map", "icon": 12, "text": "The land as far\nas you have walked"},
	{"id": "codex", "title": "Codex", "icon": 53, "text": "Bestiary, feats,\ntitles and lore"},
	{"id": "pets", "title": "Pets", "icon": 36, "text": "Companions\nand mounts"},
	{"id": "wardrobe", "title": "Wardrobe", "icon": 7, "text": "Looks and colours"},
	{"id": "pause", "title": "Settings", "icon": 5, "text": "Options, save,\nand quit"},
]
## Where a screen's Back button leads, when not to the wheel. "" closes.
const BACK := {"settings": "pause", "shop": "", "quest_board": "", "bounty_board": "", "waystones": "", "recruit": "", "storage": ""}

var _menus: Dictionary[String, GameMenu] = {}
## "" when closed, "wheel", or a screen id.
var _open_id := ""
var _player: Player
var _root: Control
var _wheel: MenuWheel
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
		if screen.get("wheel", true):
			_wheel.entries.append(screen)
	_wheel.chosen.connect(open)
	_wheel.badge_for = badge_for
	_wheel.hub_text = func() -> Array:
		return ["Menu", "Level %d\n%d gold" % [_player.leveling.level, _player.inventory.gold]]
	_root.add_child(_wheel)

	_holder = CenterContainer.new()
	_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_holder)

	_back = UITheme.button("<  Menu", _go_back, 118.0)
	_back.position = Vector2(18.0, 16.0)
	_back.custom_minimum_size.y = 38.0
	_back.add_theme_font_size_override("font_size", 17)
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
	get_tree().paused = false


func _show(id: String) -> void:
	var changed := id != _open_id
	_open_id = id
	_wheel.visible = id == "wheel"
	for other in _menus:
		_menus[other].visible = other == id
	_back.visible = id != "wheel"
	_back.text = "<  Menu" if BACK.get(id, "wheel") == "wheel" else "<  Back" if BACK[id] != "" else "x  Close"
	_hint.text = "%s  Close" % GameSettings.describe("toggle_menu").split(" / ")[0] if id == "wheel" else "Esc  Close"
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
	elif event.is_action_pressed("toggle_menu"):
		if _open_id == "wheel":
			close()
		else:
			open_wheel()
		get_viewport().set_input_as_handled()


func _add(id: String, menu: GameMenu) -> void:
	menu.visible = false
	_holder.add_child(menu)
	menu.setup(_player)
	_menus[id] = menu
