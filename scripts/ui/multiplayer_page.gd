class_name MultiplayerPage
extends PanelContainer
## Multiplayer, from the title screen: on the same Wi-Fi or cable, one
## player hosts one of their worlds and the others join it, each bringing a
## character from a world of their own. Games being hosted nearby show up
## by themselves; an address (and a password, if it has one) can be typed
## too. My Servers keeps worlds hosted in the background.

signal back
## Open My Servers.
signal servers
## Make a new character to bring along (the title screen's creator).
signal create_character
## A world to load: the slot, and whether as a guest in someone else's.
signal play(slot_id: String, as_guest: bool)

var _name_field: LineEdit
var _character: OptionButton
var _slots: Array[Dictionary] = []
var _games: VBoxContainer
var _address: LineEdit
var _password: LineEdit
var _status: Label
var _host_button: Button
var _pvp: CheckBox
var _seen := ""
var _waiting_slot := ""


func _ready() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size.x = 720.0
	add_child(box)
	var title := UITheme.heading("MULTIPLAYER", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var line := UITheme.label("On the same Wi-Fi or network cable, or by address. One hosts a world; the others join with a character of their own.", 15, UITheme.DIM)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(line)
	# Who you are.
	var who := HBoxContainer.new()
	who.add_theme_constant_override("separation", 10)
	box.add_child(who)
	var name_label := UITheme.label("Your name", 16)
	name_label.custom_minimum_size.x = 120.0
	who.add_child(name_label)
	_name_field = LineEdit.new()
	_name_field.max_length = 20
	_name_field.custom_minimum_size.x = 200.0
	_name_field.placeholder_text = "Wanderer"
	_name_field.text = GameSettings.player_name
	_name_field.text_changed.connect(func(text: String) -> void: GameSettings.set_value("player_name", text.strip_edges()))
	who.add_child(_name_field)
	var bring := UITheme.label("Character", 16)
	who.add_child(bring)
	_character = OptionButton.new()
	_character.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.add_child(_character)
	who.add_child(UITheme.button("New character", func() -> void: create_character.emit()))
	box.add_child(UITheme.rule())
	# Host.
	var host_row := HBoxContainer.new()
	host_row.add_theme_constant_override("separation", 10)
	box.add_child(host_row)
	var host_text := VBoxContainer.new()
	host_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host_row.add_child(host_text)
	host_text.add_child(UITheme.heading("Host", 20))
	var addresses := Net.local_addresses()
	host_text.add_child(UITheme.label("Opens the chosen character's world to friends nearby.%s" % (("  Your address: " + ", ".join(addresses)) if not addresses.is_empty() else ""), 14, UITheme.DIM))
	_pvp = CheckBox.new()
	_pvp.text = "PvP"
	_pvp.tooltip_text = "Players' blows and shots can hurt one another (at 60%)."
	_pvp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	host_row.add_child(_pvp)
	_host_button = UITheme.primary_button("Host this world", _host, 200.0)
	_host_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_host_button.tooltip_text = "Hosting stops when you leave the world. For a world that stays up, use My Servers."
	host_row.add_child(_host_button)
	var mine := UITheme.button("My Servers", func() -> void:
		Net.stop_listening()
		servers.emit()
	, 150.0)
	mine.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mine.tooltip_text = "Worlds hosted in the background: they keep running when the game is closed."
	host_row.add_child(mine)
	box.add_child(UITheme.rule())
	# Join.
	box.add_child(UITheme.heading("Join", 20))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 150)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_games = VBoxContainer.new()
	_games.add_theme_constant_override("separation", 6)
	_games.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_games)
	var by_hand := HBoxContainer.new()
	by_hand.add_theme_constant_override("separation", 10)
	box.add_child(by_hand)
	by_hand.add_child(UITheme.label("Address", 16))
	_address = LineEdit.new()
	_address.placeholder_text = "e.g. 192.168.1.20"
	_address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_address.text_submitted.connect(func(_text: String) -> void: _join(_address.text))
	by_hand.add_child(_address)
	by_hand.add_child(UITheme.label("Password", 16))
	_password = LineEdit.new()
	_password.secret = true
	_password.placeholder_text = "if it has one"
	_password.custom_minimum_size.x = 150.0
	_password.text_submitted.connect(func(_text: String) -> void: _join(_address.text))
	by_hand.add_child(_password)
	by_hand.add_child(UITheme.button("Join", func() -> void: _join(_address.text), 110.0))
	_status = UITheme.label("", 15, UITheme.INFO)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status)
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(bottom)
	bottom.add_child(UITheme.button("Back", _back, 160.0))
	Net.status_changed.connect(func(text: String) -> void: _status.text = text)
	Net.welcomed.connect(_on_welcomed)
	visibility_changed.connect(_on_shown)


func _on_shown() -> void:
	if not visible:
		return
	_status.text = ""
	_fill_characters()
	Net.listen()


func _back() -> void:
	Net.stop_listening()
	if Net.mode == "joining":
		Net.leave("")
	back.emit()


func _fill_characters() -> void:
	_slots = fill_characters(_character)
	_host_button.disabled = _slots.is_empty()


## Fills a picker with the characters that can go visiting (a hardcore
## life is lived in its own world), the last played chosen. Returns the
## slots in the picker's order.
static func fill_characters(picker: OptionButton) -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	picker.clear()
	for slot: Dictionary in SaveGame.list_slots():
		var meta: Dictionary = slot["meta"]
		if meta.get("hardcore", false):
			continue
		slots.append(slot)
		var race := str(Appearance.RACES.get(str((meta.get("appearance", {}) as Dictionary).get("race", "human")), Appearance.RACES["human"])["name"])
		var calling := str(HeroClasses.CLASSES.get(str(meta.get("class", meta.get("class_id", "warrior"))), HeroClasses.CLASSES["warrior"])["name"])
		var place := str(meta.get("name", "World")) + (", made for servers" if meta.get("server_character", false) else "")
		picker.add_item("%s %s, level %d   (%s)" % [race, calling, int(meta.get("level", 1)), place])
	if slots.is_empty():
		picker.add_item("No characters yet: press New character")
		picker.disabled = true
	else:
		picker.disabled = false
		var last := slots.map(func(s: Dictionary) -> String: return s["id"]).find(GameSettings.last_slot)
		picker.select(maxi(last, 0))
	return slots


func _chosen() -> Dictionary:
	var index := _character.selected
	return _slots[index] if index >= 0 and index < _slots.size() else {}


func _info(slot: Dictionary) -> Dictionary:
	var info := Net.describe_character(slot.get("meta", {}), "Wanderer")
	info["password_hash"] = ServerStore.hash_password(_password.text)
	return info


func _host() -> void:
	var slot := _chosen()
	if slot.is_empty():
		return
	var info := _info(slot)
	info["pvp"] = _pvp.button_pressed
	var problem := Net.host(info)
	if problem != "":
		_status.text = problem
		return
	Net.world = {"name": str(slot["meta"].get("name", "World"))}
	Net.stop_listening()
	play.emit(slot["id"], false)


func _join(address: String, port: int = Net.PORT, locked: bool = false) -> void:
	address = address.strip_edges()
	if locked and _password.text == "":
		_status.text = "That game has a password: type it beside the address, then Join."
		_password.grab_focus()
		return
	if address.count(":") == 1:
		# "192.168.1.20:24680"
		port = int(address.get_slice(":", 1)) if address.get_slice(":", 1).is_valid_int() else port
		address = address.get_slice(":", 0)
	var slot := _chosen()
	if slot.is_empty():
		_status.text = "Make a character first (Play, then Create New World)."
		return
	_waiting_slot = slot["id"]
	var problem := Net.join(address, _info(slot), port)
	if problem != "":
		_status.text = problem


func _on_welcomed() -> void:
	if _waiting_slot == "" or not visible:
		return
	Net.stop_listening()
	var slot := _waiting_slot
	_waiting_slot = ""
	play.emit(slot, true)


func _process(_delta: float) -> void:
	if not visible:
		return
	# The games heard on the network, refreshed as they come and go.
	var keys := Net.found.keys()
	keys.sort()
	var now := "|".join(keys.map(func(k: String) -> String: return "%s/%d" % [k, int(Net.found[k]["players"])]))
	if now == _seen:
		return
	_seen = now
	for child in _games.get_children():
		child.queue_free()
	if keys.is_empty():
		_games.add_child(UITheme.label("Looking for games on this network...  (none yet: type the host's address below)", 14, UITheme.DIM))
	for key: String in keys:
		var game: Dictionary = Net.found[key]
		var card := UITheme.inset_panel()
		_games.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		card.add_child(row)
		var owner := ("%s (server)" % game["name"]) if game.get("dedicated", false) else ("%s's world" % game["name"])
		var words := UITheme.label("%s  %s   -   %d/%d players   -   %s" % [owner, game["world"], game["players"], game["most"], game["address"]], 15)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(words)
		if game.get("dedicated", false):
			row.add_child(UITheme.badge("Server", "info"))
		if game.get("locked", false):
			row.add_child(UITheme.badge("Password", "gold"))
		var join := UITheme.button("Join", _join.bind(str(game["address"]), int(game["port"]), bool(game.get("locked", false))), 100.0)
		join.disabled = int(game["players"]) >= int(game["most"])
		row.add_child(join)
