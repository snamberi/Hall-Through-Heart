class_name ServerTray
extends Node
## The hosted world's little manager, apart from the game and the server:
## an icon in the Windows system tray (and a small window) to see how the
## world is doing and to save, restart or stop it, open its log, or open
## the game, even when the game is closed. It draws next to nothing.

const ICON: Texture2D = preload("res://assets/icon/icon.png")

var id := ""
var _indicator: StatusIndicator
var _menu: PopupMenu
var _label: Label
var _refresh_left := 0.0
## Started alongside the server: it is given a while to come up before a
## "stopped" from its last run is taken to mean it is gone.
var _seen_running := false
var _born := 0.0


func start(server_id: String) -> void:
	id = server_id
	_born = Time.get_unix_time_from_system()
	Engine.max_fps = 4
	OS.low_processor_usage_mode = true
	var window := get_window()
	window.title = "Hall Through Heart - %s (server)" % str(ServerStore.load_config(id).get("name", id))
	window.size = Vector2i(420, 240)
	window.min_size = Vector2i(320, 180)
	var panel := PanelContainer.new()
	panel.theme = UITheme.get_theme()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	_label = UITheme.label("", 15)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	for entry: Array in [["Save", _act.bind(1)], ["Restart", _act.bind(2)], ["Stop hosting", _act.bind(3)], ["Log", _act.bind(4)]]:
		row.add_child(UITheme.button(entry[0], entry[1], 80.0))
	_menu = PopupMenu.new()
	for entry: Array in [["View server status", 0], ["Save world", 1], ["Restart server", 2], ["Stop hosting", 3], ["Open server logs", 4], ["Open Hall Through Heart", 5], ["Hide this icon", 6]]:
		_menu.add_item(entry[0], entry[1])
	_menu.id_pressed.connect(_act)
	add_child(_menu)
	if DisplayServer.has_feature(DisplayServer.FEATURE_STATUS_INDICATOR):
		_indicator = StatusIndicator.new()
		_indicator.icon = ICON
		_indicator.tooltip = window.title
		_indicator.menu = _menu.get_path()
		_indicator.pressed.connect(func(_button: int, _at: Vector2i) -> void: _act(0))
		add_child(_indicator)
		window.mode = Window.MODE_MINIMIZED
	_refresh()


func _act(what: int) -> void:
	match what:
		0:
			get_window().mode = Window.MODE_WINDOWED
			get_window().grab_focus()
		1:
			ServerStore.send(id, "save")
		2:
			ServerStore.send(id, "restart")
		3:
			ServerStore.send(id, "stop")
		4:
			OS.shell_open(ProjectSettings.globalize_path(ServerStore.path_of(id, "server.log")))
		5:
			var command := ServerStore.server_command(id, "tray")
			var args: PackedStringArray = (command[1] as PackedStringArray).slice(0, (command[1] as PackedStringArray).find("--"))
			OS.create_process(command[0], args, false)
		6:
			get_tree().quit(0)


func _process(delta: float) -> void:
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_left = 1.0
		_refresh()


func _refresh() -> void:
	var config := ServerStore.load_config(id)
	var state := ServerStore.status(id)
	var running := ServerStore.is_running(id)
	var lines: PackedStringArray = []
	lines.append("%s  -  %s" % [config.get("name", id), "online" if running else str(state.get("state", "not running"))])
	if running:
		var up := int(Time.get_unix_time_from_system() - float(state.get("started", 0.0)))
		lines.append("Up %dh %02dm  -  day %d  -  %d MB" % [up / 3600, (up / 60) % 60, int(state.get("day", 1)), int(state.get("memory_mb", 0))])
		var names: Array = state.get("players", [])
		lines.append("Players (%d/%d): %s" % [names.size(), int(state.get("max_players", 8)), ", ".join(names) if not names.is_empty() else "nobody (resting)"])
		lines.append("Port %d  -  %s" % [int(state.get("port", 0)), ", ".join(state.get("addresses", []))])
	elif str(state.get("note", "")) != "":
		lines.append(str(state["note"]))
	_label.text = "\n".join(lines)
	if _indicator:
		_indicator.tooltip = lines[0]
	# Once the server is gone for good, the tray goes too.
	_seen_running = _seen_running or running
	var waited := Time.get_unix_time_from_system() - _born > 30.0
	if not running and str(state.get("state", "")) in ["stopped", "crashed"] and (_seen_running or waited):
		get_tree().quit(0)
