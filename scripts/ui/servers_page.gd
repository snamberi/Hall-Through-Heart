class_name ServersPage
extends PanelContainer
## My Servers, from Multiplayer: worlds this computer hosts in the
## background. Each runs as a program of its own (it shows in Task Manager)
## that keeps going when the game is closed, until it is stopped here or
## from its tray icon. The game joins it like any other player.
##
## Three views: the list (start, play, rejoin, stop, settings, log,
## delete), the settings form (making a new server, or hosting a copy of a
## world you already have), and a server's log and backups.

signal back
## A world to load: the character's slot, joined as a guest.
signal play(slot_id: String, as_guest: bool)

const REFRESH_EVERY := 1.0
## How long to wait for a started server to come up before saying so.
const START_PATIENCE := 40.0
const VISIBILITY := [["lan", "LAN: shown to players on this network"], ["private", "Private: join by address only"]]
const MODES := [["background", "Background"], ["persistent", "Persistent"]]
const MODE_TEXT := {
	"background": "Keeps running when you close the game. Stop it here or from its tray icon.",
	"persistent": "Background, and comes back by itself if it crashes. It can also start with Windows (off unless you turn it on).",
}
const QUALITY := [["low", "Low"], ["normal", "Normal"], ["high", "High"]]

var _views: Dictionary[String, Control] = {}
var _list: VBoxContainer
var _character: OptionButton
var _slots: Array[Dictionary] = []
var _status: Label
var _refresh_left := 0.0
var _seen := ""
var _armed_delete := ""
## server id -> when it was started from here (waiting for it to come up).
var _starting: Dictionary = {}
## The server to join as soon as it is up.
var _join_when_up := ""
## The character waiting to be let in.
var _waiting_slot := ""

# The form.
var _editing := ""
var _form_title: Label
var _fields: Dictionary = {}
var _from: OptionButton
var _from_slots: Array[String] = []
var _mode_text: Label
var _form_status: Label
var _create_button: Button
var _create_play_button: Button

# The log.
var _log_id := ""
var _log_title: Label
var _log_text: TextEdit
var _backup_list: VBoxContainer
var _armed_restore := ""


func _ready() -> void:
	var stack := VBoxContainer.new()
	add_child(stack)
	_views["list"] = _list_view()
	_views["form"] = _form_view()
	_views["log"] = _log_view()
	for view: Control in _views.values():
		stack.add_child(view)
	Net.status_changed.connect(func(text: String) -> void:
		if visible and _waiting_slot != "":
			_status.text = text)
	Net.welcomed.connect(_on_welcomed)
	visibility_changed.connect(_on_shown)
	_show("list")


func _show(view: String) -> void:
	for name in _views:
		_views[name].visible = name == view
	_seen = ""
	_refresh_left = 0.0


func _on_shown() -> void:
	if not visible:
		return
	_status.text = ""
	_slots = MultiplayerPage.fill_characters(_character)
	_show("list")


# --- the list

func _list_view() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size.x = 820.0
	var title := UITheme.heading("MY SERVERS", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var line := UITheme.label("Worlds hosted in the background. They keep running when you close the game, and show in Task Manager and the tray, until you stop them.", 15, UITheme.DIM)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(line)
	var who := HBoxContainer.new()
	who.add_theme_constant_override("separation", 10)
	box.add_child(who)
	who.add_child(UITheme.label("Play as", 16))
	_character = OptionButton.new()
	_character.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.add_child(_character)
	box.add_child(UITheme.rule())
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 330)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	_status = UITheme.label("", 15, UITheme.INFO)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(bottom)
	bottom.add_child(UITheme.button("Back", func() -> void:
		if Net.mode == "joining":
			Net.leave("")
		_waiting_slot = ""
		_join_when_up = ""
		back.emit()
	, 140.0))
	bottom.add_child(UITheme.button("Host Existing World", _open_form.bind("", true), 230.0))
	bottom.add_child(UITheme.primary_button("+  Create Server", _open_form.bind("", false), 230.0))
	return box


func _process(delta: float) -> void:
	if not visible:
		return
	_refresh_left -= delta
	if _refresh_left > 0.0:
		return
	_refresh_left = REFRESH_EVERY
	if _views["log"].visible:
		_fill_log(false)
		return
	if not _views["list"].visible:
		return
	var servers := ServerStore.list()
	var now := Time.get_unix_time_from_system()
	for id: String in _starting.keys():
		if ServerStore.is_running(id):
			_starting.erase(id)
			if _join_when_up == id:
				_join_when_up = ""
				rejoin(id)
		elif now - float(_starting[id]) > START_PATIENCE:
			_starting.erase(id)
			if _join_when_up == id:
				_join_when_up = ""
			_status.text = "The server did not come up. Its log may say why."
	# Redrawn when something shown changes.
	var key := "|".join(servers.map(func(server: Dictionary) -> String:
		var state: Dictionary = server["status"]
		return "%s/%s/%s/%s/%s/%s" % [server["id"], _state_of(server["id"]), state.get("player_count", 0), state.get("day", 0), server["config"].hash(), _armed_delete]))
	if key == _seen:
		return
	_seen = key
	_fill_list(servers)


## "running", "starting", "stopped", "crashed" or "new".
func _state_of(id: String) -> String:
	if ServerStore.is_running(id):
		return "running"
	if _starting.has(id):
		return "starting"
	var state := str(ServerStore.status(id).get("state", ""))
	if state == "":
		return "new"
	# A heartbeat that stopped without a goodbye: it was cut off.
	return state if state in ["stopped", "crashed"] else "crashed"


func _fill_list(servers: Array[Dictionary]) -> void:
	for child in _list.get_children():
		child.queue_free()
	if servers.is_empty():
		var none := UITheme.label("No servers yet. Create one below, or host a copy of a world you already have.", 16, UITheme.DIM)
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_list.add_child(none)
	for server: Dictionary in servers:
		_list.add_child(_server_card(server))


func _server_card(server: Dictionary) -> Control:
	var id: String = server["id"]
	var config: Dictionary = server["config"]
	var status: Dictionary = server["status"]
	var state := _state_of(id)
	var card := UITheme.inset_panel()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	text.add_child(top)
	top.add_child(UITheme.heading(str(config["name"]), 20))
	var badges := {"running": ["Running", "good"], "starting": ["Starting...", "info"], "stopped": ["Stopped", "plain"], "crashed": ["Stopped unexpectedly", "bad"], "new": ["Not started yet", "plain"]}
	top.add_child(UITheme.badge(badges[state][0], badges[state][1]))
	if str(config["password_hash"]) != "":
		top.add_child(UITheme.badge("Password", "gold"))
	if str(config["mode"]) == "persistent":
		top.add_child(UITheme.badge("Persistent", "info"))
	text.add_child(UITheme.label("World %s  -  seed %d  -  %s%s  -  up to %d players  -  %s  -  port %d" % [
		config["world_name"], int(config["seed"]), Difficulty.display_name(str(config["difficulty"])), ", permadeath" if config["permadeath"] else "",
		int(config["max_players"]), "LAN" if config["visibility"] == "lan" else "private", int(config["port"])], 14, UITheme.DIM))
	if state == "running":
		var up := int(Time.get_unix_time_from_system() - float(status.get("started", 0.0)))
		var names: Array = status.get("players", [])
		text.add_child(UITheme.label("Day %d  -  %s  -  up %dh %02dm  -  address %s" % [
			int(status.get("day", 1)), ("%d on: %s" % [names.size(), ", ".join(names)]) if not names.is_empty() else "nobody on (resting)",
			up / 3600, (up / 60) % 60, ", ".join(status.get("addresses", []))], 14, UITheme.GOOD))
		text.add_child(UITheme.label("Load %d%%  -  %d MB  -  %d monsters, %d drops shared  -  %d chunks active" % [
			int(status.get("load", 0)), int(status.get("memory_mb", 0)), int(status.get("monsters", 0)), int(status.get("drops", 0)),
			int(status.get("active_chunks", 0))], 14, UITheme.DIM))
	elif state != "starting" and float(status.get("last_save", 0.0)) > 0.0:
		var note := str(status.get("note", ""))
		text.add_child(UITheme.label("Last saved %s%s" % [Time.get_datetime_string_from_unix_time(int(status["last_save"]), true), ("  -  " + note) if note != "" and state == "stopped" else ""], 14, UITheme.BAD if state == "crashed" else UITheme.DIM))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	buttons.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(buttons)
	match state:
		"running":
			buttons.add_child(UITheme.primary_button("Rejoin", rejoin.bind(id), 96.0))
			buttons.add_child(UITheme.button("Save", func() -> void:
				ServerStore.send(id, "save")
				_status.text = "Saving %s." % config["name"]
			, 70.0))
			buttons.add_child(UITheme.danger_button("Stop", _stop.bind(id), 70.0))
		"starting":
			var wait := UITheme.button("Starting...", func() -> void: pass, 120.0)
			wait.disabled = true
			buttons.add_child(wait)
		_:
			buttons.add_child(UITheme.primary_button("Play", _start.bind(id, true), 80.0))
			var start := UITheme.button("Start", _start.bind(id, false), 70.0)
			start.tooltip_text = "Start hosting without joining. Friends can come in; you can join later."
			buttons.add_child(start)
	buttons.add_child(UITheme.button("Settings", _open_form.bind(id, false), 96.0))
	buttons.add_child(UITheme.button("Log", _open_log.bind(id), 60.0))
	if state != "running" and state != "starting":
		var delete := UITheme.danger_button("Sure?" if _armed_delete == id else "Delete", _delete.bind(id), 80.0)
		buttons.add_child(delete)
	return card


## Starts a server (and, with `join`, joins it once it is up).
func _start(id: String, join: bool) -> void:
	if join and _chosen().is_empty():
		_status.text = "Make a character first (Play, then Create New World)."
		return
	var problem := ServerStore.launch(id)
	if problem != "":
		_status.text = problem
		return
	var config := ServerStore.load_config(id)
	if config.get("show_tray", true):
		ServerStore.launch_tray(id)
	_starting[id] = Time.get_unix_time_from_system()
	_join_when_up = id if join else ""
	_status.text = "Starting %s...%s" % [config["name"], "  You will join when it is ready." if join else ""]
	_refresh_left = 0.0


func _stop(id: String) -> void:
	if ServerStore.send(id, "stop"):
		_status.text = "Stopping %s: everyone is sent home and the world saved." % ServerStore.load_config(id)["name"]
	_refresh_left = 0.0


func _delete(id: String) -> void:
	if _armed_delete != id:
		_armed_delete = id
		_status.text = "Press again to delete this server, its world and its backups for good."
		_refresh_left = 0.0
		return
	_armed_delete = ""
	if not ServerStore.delete(id):
		_status.text = "Stop the server before deleting it."
	else:
		_status.text = "Deleted."
	_refresh_left = 0.0


## Joins a running server of ours with the chosen character.
func rejoin(id: String) -> void:
	var slot := _chosen()
	if slot.is_empty():
		_status.text = "Make a character first (Play, then Create New World)."
		return
	var config := ServerStore.load_config(id)
	var info := Net.describe_character(slot.get("meta", {}), "Wanderer")
	# Our own server: its password is ours already.
	info["password_hash"] = str(config.get("password_hash", ""))
	_waiting_slot = slot["id"]
	var problem := Net.join("127.0.0.1", info, int(config.get("port", ServerStore.PORT)))
	if problem != "":
		_waiting_slot = ""
		_status.text = problem


func _chosen() -> Dictionary:
	var index := _character.selected
	return _slots[index] if index >= 0 and index < _slots.size() else {}


func _on_welcomed() -> void:
	if _waiting_slot == "" or not visible:
		return
	var slot := _waiting_slot
	_waiting_slot = ""
	play.emit(slot, true)


# --- the settings form

func _form_view() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size.x = 820.0
	_form_title = UITheme.heading("CREATE SERVER", 30)
	_form_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_form_title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 470)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var form := VBoxContainer.new()
	form.add_theme_constant_override("separation", 6)
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(form)

	var world := _section(form, "World", "")
	_field_text(world, "name", "Server name", "My World", 32)
	_from = OptionButton.new()
	_from.item_selected.connect(func(_index: int) -> void: _on_from_changed())
	_row(world, "Start from", _from, "from")
	_field_text(world, "world_name", "World name", "named after the server", 32)
	_field_text(world, "seed", "Seed", "random", 12)
	var difficulty := OptionButton.new()
	for level: String in Difficulty.LEVELS:
		difficulty.add_item(Difficulty.display_name(level))
	_row(world, "Difficulty", difficulty, "difficulty")
	_field_check(world, "permadeath", "Permadeath", "A player who dies may not come back to this world.")
	_field_check(world, "pvp", "Player versus player", "Players' blows and shots can hurt one another (at 60%).")

	var who := _section(form, "Who can join", "")
	_field_spin(who, "max_players", "Most players", 2, ServerStore.MAX_PLAYERS, 1)
	var visibility := OptionButton.new()
	for entry: Array in VISIBILITY:
		visibility.add_item(entry[1])
	visibility.add_item("Public: needs a listing service (not available)")
	visibility.set_item_disabled(VISIBILITY.size(), true)
	_row(who, "Visibility", visibility, "visibility")
	var password := LineEdit.new()
	password.secret = true
	password.max_length = 64
	password.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_row(who, "Password", password, "password")
	_field_check(who, "clear_password", "Remove the password", "Anyone who finds the server may join.")
	_field_check(who, "allow_friends", "Let others join", "Off: only you (by the name you play under) may come in.")
	_field_spin(who, "port", "Port", 1024, 65535, 1)

	var hosting := _section(form, "Hosting", "")
	var mode := OptionButton.new()
	for entry: Array in MODES:
		mode.add_item(entry[1])
	mode.item_selected.connect(func(_index: int) -> void: _on_mode_changed())
	_row(hosting, "Mode", mode, "mode")
	_mode_text = UITheme.label("", 14, UITheme.DIM)
	_mode_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mode_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_row(hosting, "", _mode_text, "")
	_field_check(hosting, "auto_restart", "Restart after a crash", "If the server stops without being told to, it is started again (a few times at most).")
	_field_check(hosting, "start_with_windows", "Start with Windows", "Starts this server when you sign in to Windows. Off unless you turn it on." if OS.get_name() == "Windows" else "Only offered on Windows.")
	_field_check(hosting, "show_tray", "Tray icon", "A small manager by the clock: see who is on, save, restart or stop, open the log.")
	_field_spin(hosting, "autosave_minutes", "Autosave every (minutes)", 1, 60, 1)
	_field_check(hosting, "idle_mode", "Rest when nobody is on", "Far fewer updates a second while the world is empty.")
	_field_check(hosting, "pause_when_empty", "Pause time when empty", "The day and the weather wait for someone to come back.")

	var limits := _section(form, "Resources", "Each monster is run by the game of the player nearest it; the server referees, and tells each player only of what is near them. These limits set how far that reaches and how much the server keeps track of.")
	_field_spin(limits, "max_active_chunks", "Most active chunks (all players)", 50, 4000, 50)
	_field_spin(limits, "chunk_sim_distance", "Shared distance (chunks)", 1, 8, 1)
	_field_spin(limits, "enemy_sim_distance", "Monster distance (pixels)", 400, 4000, 100)
	_field_spin(limits, "max_instances", "Most shared dungeons at once", 1, 16, 1)
	var quality := OptionButton.new()
	for entry: Array in QUALITY:
		quality.add_item(entry[1])
	_row(limits, "Background quality", quality, "background_quality")
	_field_spin(limits, "memory_warning_mb", "Warn when memory passes (MB)", 256, 16384, 128)
	(_fields["background_quality"] as Control).tooltip_text = "Updates a second while players are on: Low 10, Normal 20, High 30."

	_form_status = UITheme.label("", 15, UITheme.INFO)
	_form_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_form_status)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(bottom)
	bottom.add_child(UITheme.button("Cancel", _show.bind("list"), 140.0))
	_create_button = UITheme.button("Create", _submit.bind(false), 180.0)
	bottom.add_child(_create_button)
	_create_play_button = UITheme.primary_button("Create and Play", _submit.bind(true), 220.0)
	bottom.add_child(_create_play_button)
	return box


func _section(form: VBoxContainer, title: String, note: String) -> GridContainer:
	form.add_child(UITheme.heading(title, 20))
	if note != "":
		var words := UITheme.label(note, 14, UITheme.DIM)
		words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		form.add_child(words)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 6)
	form.add_child(grid)
	return grid


func _row(grid: GridContainer, title: String, control: Control, key: String) -> void:
	var words := UITheme.label(title, 16)
	words.custom_minimum_size.x = 290.0
	grid.add_child(words)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(control)
	if key != "":
		_fields[key] = control
		control.set_meta("row_label", words)


func _field_text(grid: GridContainer, key: String, title: String, hint: String, most: int) -> void:
	var field := LineEdit.new()
	field.placeholder_text = hint
	field.max_length = most
	_row(grid, title, field, key)


func _field_check(grid: GridContainer, key: String, title: String, hint: String) -> void:
	var box := CheckBox.new()
	box.text = hint
	box.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_row(grid, title, box, key)


func _field_spin(grid: GridContainer, key: String, title: String, low: float, high: float, step: float) -> void:
	var spin := SpinBox.new()
	spin.min_value = low
	spin.max_value = high
	spin.step = step
	spin.rounded = true
	_row(grid, title, spin, key)


func _shown_field(key: String, shown: bool) -> void:
	var control: Control = _fields[key]
	control.visible = shown
	(control.get_meta("row_label") as Control).visible = shown


## Opens the form: for a new server (`existing` true: hosting a copy of one
## of your worlds) or, with an id, that server's settings.
func _open_form(id: String, existing: bool) -> void:
	_editing = id
	var config := ServerStore.load_config(id) if id != "" else ServerStore.DEFAULTS.duplicate(true)
	_form_status.text = ""
	_from.clear()
	_from_slots.clear()
	_from.add_item("A new world")
	_from_slots.append("")
	for slot: Dictionary in SaveGame.list_slots():
		var meta: Dictionary = slot["meta"]
		_from.add_item("A copy of %s  (day %d)" % [meta.get("name", "World"), int(meta.get("day", 1))])
		_from_slots.append(slot["id"])
	if id == "":
		_form_title.text = "HOST EXISTING WORLD" if existing else "CREATE SERVER"
		config["name"] = "%s's Server" % (GameSettings.player_name if GameSettings.player_name != "" else "My")
		_from.select(1 if existing and _from_slots.size() > 1 else 0)
	else:
		_form_title.text = "SERVER SETTINGS"
	(_fields["name"] as LineEdit).text = str(config["name"])
	(_fields["world_name"] as LineEdit).text = str(config["world_name"]) if id != "" else ""
	(_fields["seed"] as LineEdit).text = ""
	(_fields["difficulty"] as OptionButton).select(maxi(Difficulty.LEVELS.find(str(config["difficulty"])), 0))
	(_fields["visibility"] as OptionButton).select(maxi(VISIBILITY.map(func(e: Array) -> String: return e[0]).find(str(config["visibility"])), 0))
	(_fields["mode"] as OptionButton).select(maxi(MODES.map(func(e: Array) -> String: return e[0]).find(str(config["mode"])), 0))
	(_fields["background_quality"] as OptionButton).select(maxi(QUALITY.map(func(e: Array) -> String: return e[0]).find(str(config["background_quality"])), 0))
	var password := _fields["password"] as LineEdit
	password.text = ""
	password.placeholder_text = "unchanged (type to change)" if str(config["password_hash"]) != "" else "none"
	for key: String in ["permadeath", "pvp", "allow_friends", "auto_restart", "start_with_windows", "show_tray", "idle_mode", "pause_when_empty"]:
		(_fields[key] as CheckBox).button_pressed = bool(config[key])
	(_fields["clear_password"] as CheckBox).button_pressed = false
	(_fields["start_with_windows"] as CheckBox).disabled = OS.get_name() != "Windows"
	for key: String in ["max_players", "port", "autosave_minutes", "max_active_chunks", "chunk_sim_distance", "enemy_sim_distance", "max_instances", "memory_warning_mb"]:
		(_fields[key] as SpinBox).value = float(config[key])
	# A world is chosen once, when the server is made.
	for key: String in ["from", "seed"]:
		_shown_field(key, id == "")
	_shown_field("world_name", true)
	(_fields["world_name"] as LineEdit).editable = id == ""
	_shown_field("clear_password", str(config["password_hash"]) != "")
	_create_button.text = "Create" if id == "" else "Save"
	_create_play_button.text = "Create and Play" if id == "" else "Save and Restart"
	_create_play_button.visible = id == "" or ServerStore.is_running(id)
	_on_from_changed()
	_on_mode_changed()
	_show("form")


func _on_from_changed() -> void:
	var slot := _from_slots[_from.selected] if _from.selected >= 0 and _from.selected < _from_slots.size() else ""
	if _editing == "":
		_shown_field("seed", slot == "")
		var name := _fields["world_name"] as LineEdit
		name.placeholder_text = "named after the server" if slot == "" else "as it is called now"


func _on_mode_changed() -> void:
	var mode: String = MODES[maxi((_fields["mode"] as OptionButton).selected, 0)][0]
	_mode_text.text = MODE_TEXT[mode]
	var restart := _fields["auto_restart"] as CheckBox
	if mode == "persistent":
		restart.button_pressed = true


## What the form says, as server settings.
func _read_form() -> Dictionary:
	var config := {
		"name": (_fields["name"] as LineEdit).text.strip_edges(),
		"world_name": (_fields["world_name"] as LineEdit).text.strip_edges(),
		"difficulty": Difficulty.LEVELS[maxi((_fields["difficulty"] as OptionButton).selected, 0)],
		"visibility": VISIBILITY[clampi((_fields["visibility"] as OptionButton).selected, 0, VISIBILITY.size() - 1)][0],
		"mode": MODES[maxi((_fields["mode"] as OptionButton).selected, 0)][0],
		"background_quality": QUALITY[maxi((_fields["background_quality"] as OptionButton).selected, 0)][0],
	}
	for key: String in ["permadeath", "pvp", "allow_friends", "auto_restart", "start_with_windows", "show_tray", "idle_mode", "pause_when_empty"]:
		config[key] = (_fields[key] as CheckBox).button_pressed
	for key: String in ["max_players", "port", "autosave_minutes", "max_active_chunks", "chunk_sim_distance", "enemy_sim_distance", "max_instances", "memory_warning_mb"]:
		config[key] = int((_fields[key] as SpinBox).value)
	if config["name"] == "":
		config["name"] = "My World"
	return config


func _submit(and_play: bool) -> void:
	var config := _read_form()
	var password := (_fields["password"] as LineEdit).text
	var problem := ""
	# The port must not be another of our servers' while both could run.
	for server: Dictionary in ServerStore.list():
		if server["id"] != _editing and int(server["config"]["port"]) == int(config["port"]):
			problem = "%s already uses port %d. Pick another, so both can run at once." % [server["config"]["name"], config["port"]]
	if problem != "":
		_form_status.text = problem
		return
	var id := _editing
	if id == "":
		var slot := _from_slots[maxi(_from.selected, 0)]
		var seed_text := (_fields["seed"] as LineEdit).text.strip_edges()
		config["seed"] = (int(seed_text) if seed_text.is_valid_int() else seed_text.hash()) if seed_text != "" else 0
		config["password_hash"] = ServerStore.hash_password(password)
		config["owner"] = GameSettings.player_name if GameSettings.player_name != "" else "Wanderer"
		id = ServerStore.create(config, slot)
	else:
		var kept := ServerStore.load_config(id)
		# The world itself does not change with the settings.
		config.erase("world_name")
		kept.merge(config, true)
		if (_fields["clear_password"] as CheckBox).button_pressed:
			kept["password_hash"] = ""
		elif password != "":
			kept["password_hash"] = ServerStore.hash_password(password)
		ServerStore.save_config(id, kept)
		ServerStore.log_line(id, "Settings changed.")
	var windows := ServerStore.set_start_with_windows(id, bool(config["start_with_windows"])) if OS.get_name() == "Windows" else ""
	_show("list")
	_status.text = windows if windows != "" else ("Saved. Changes reach a running server when it restarts." if _editing != "" and ServerStore.is_running(id) else "")
	if and_play:
		if _editing != "" and ServerStore.is_running(id):
			ServerStore.send(id, "restart")
			_status.text = "Restarting with the new settings."
		else:
			_start(id, true)


# --- the log and backups

func _log_view() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size.x = 820.0
	_log_title = UITheme.heading("LOG", 26)
	_log_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_log_title)
	_log_text = TextEdit.new()
	_log_text.editable = false
	_log_text.custom_minimum_size = Vector2(0, 300)
	_log_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	UITheme.font_size(_log_text, 14)
	box.add_child(_log_text)
	box.add_child(UITheme.heading("Backups", 18))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 120)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_backup_list = VBoxContainer.new()
	_backup_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_backup_list)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(bottom)
	bottom.add_child(UITheme.button("Back", _show.bind("list"), 140.0))
	bottom.add_child(UITheme.button("Open Folder", func() -> void:
		OS.shell_open(ProjectSettings.globalize_path(ServerStore.dir_of(_log_id)))
	, 170.0))
	return box


func _open_log(id: String) -> void:
	_log_id = id
	_armed_restore = ""
	_log_title.text = "%s: LOG" % str(ServerStore.load_config(id).get("name", id)).to_upper()
	_show("log")
	_fill_log(true)


func _fill_log(everything: bool) -> void:
	var text := ServerStore.log_tail(_log_id, 300)
	if text != _log_text.text:
		_log_text.text = text
		_log_text.scroll_vertical = _log_text.get_line_count()
	if not everything:
		return
	for child in _backup_list.get_children():
		child.queue_free()
	var running := ServerStore.is_running(_log_id)
	var files := ServerStore.backups(_log_id)
	if files.is_empty():
		_backup_list.add_child(UITheme.label("None yet: one is kept each time the server stops, and every half hour while it runs.", 14, UITheme.DIM))
	for file: String in files:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_backup_list.add_child(row)
		var when := file.trim_prefix("world_").trim_suffix(".json").replace("_", "  ")
		var words := UITheme.label(when, 15)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(words)
		var restore := UITheme.button("Sure? Restore" if _armed_restore == file else "Restore", _restore.bind(file), 140.0)
		restore.disabled = running
		restore.tooltip_text = "Stop the server first." if running else "Puts this copy back as the world. The world as it is now is kept as a backup first."
		row.add_child(restore)


func _restore(file: String) -> void:
	if _armed_restore != file:
		_armed_restore = file
		_fill_log(true)
		return
	_armed_restore = ""
	var problem := ServerStore.restore_backup(_log_id, file)
	_fill_log(true)
	_log_text.text += "\n" + (problem if problem != "" else "Restored.")
