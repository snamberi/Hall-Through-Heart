class_name DedicatedServer
extends Node
## A world hosted in the background: a process of its own with no window
## and nothing drawn (it shows in Task Manager like any program), owning
## the world's save while it runs. Players, the host among them, join it
## as guests from their games; closing a game does not stop it.
##
## It keeps the world's clock and weather, lets in who may come (password,
## room, permadeath), keeps where each player left off, decides what is
## built and taken down and tells everyone, and saves: every few minutes,
## on the way out, and a dated backup now and then. With nobody on it
## rests (fewer updates a second; the clock can wait for them too).
##
## It listens for commands left by the game or the tray (stop, save,
## restart) and writes its heartbeat for them to see it by.

const DAY_SECONDS := 600.0
const BUSY_FPS := 20
const IDLE_FPS := 4
const STATUS_EVERY := 2.0
const BACKUP_EVERY := 1800.0
## Weather fronts: how long one lasts, and how often it is stormy.
const FRONT_SECONDS := Vector2(150.0, 320.0)

var id := ""
var config: Dictionary = {}
var world: Dictionary = {}

var _day := 1
var _time := 0.3
var _storminess := 0
var _front_left := 60.0
var _started := 0.0
var _last_save := 0.0
var _save_left := 0.0
var _backup_left := BACKUP_EVERY
var _status_left := 0.0
var _command_left := 0.0
var _clock_left := 0.0
## peer -> {"name", "position" [x, y], "joined"}
var _players: Dictionary = {}
var _stopping := false
var _memory_warned := false
## Set once the world is loaded and the server open: nothing is saved or
## done on request before then, so a half-started server never writes over
## the world.
var _live := false
## Run under a supervisor, which brings it back after a crash or restart.
var supervised := false


func start(server_id: String) -> void:
	id = server_id
	config = ServerStore.load_config(id)
	if config.is_empty():
		push_error("No server called %s." % id)
		get_tree().quit(2)
		return
	if not ServerStore.lock(id):
		ServerStore.log_line(id, "Another process is already hosting this world; this one stops.")
		get_tree().quit(3)
		return
	await get_tree().create_timer(0.6).timeout
	if not ServerStore.holds_lock(id):
		ServerStore.log_line(id, "Another process took this world at the same moment; this one stops.")
		get_tree().quit(3)
		return
	# A request left from before this start is not for it.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ServerStore.path_of(id, "control.json")))
	world = ServerStore.load_world(id)
	var clock: Dictionary = world.get("world", {})
	_day = maxi(int(clock.get("day", 1)), 1)
	_time = clampf(float(clock.get("time", 0.3)), 0.0, 0.999)
	_started = Time.get_unix_time_from_system()
	_save_left = float(config["autosave_minutes"]) * 60.0
	Engine.max_fps = BUSY_FPS
	OS.low_processor_usage_mode = true
	# Asked to close from outside: stop() saves, says goodbye and then quits.
	get_tree().auto_accept_quit = false
	var problem := Net.host_dedicated(config)
	if problem != "":
		ServerStore.log_line(id, "Could not open the server: " + problem)
		_write_status("crashed", problem)
		ServerStore.unlock(id)
		get_tree().quit(1)
		return
	Net.world = {"name": str(config["world_name"])}
	Net.admit = _admit
	Net.world_ready(world_now)
	Net.roster_changed.connect(_on_roster)
	Net.state_received.connect(_on_state)
	Net.op_requested.connect(_on_op)
	Net.deed_received.connect(_on_deed)
	# Players' chat goes in the log (joins and leaves are logged above).
	Net.chat_received.connect(func(from_name: String, text: String, _c: Color) -> void:
		if from_name != "":
			ServerStore.log_line(id, "%s: %s" % [from_name, text]))
	ServerStore.log_line(id, "Hosting %s on port %d (%s, up to %d players)." % [config["world_name"], config["port"], config["mode"], config["max_players"]])
	_live = true
	_write_status("running")


## What a joining player needs: the world, and where they left off in it.
func world_now(_peer: int = 0, info: Dictionary = {}) -> Dictionary:
	var spot := Vector2.ZERO
	var mine := ServerStore.load_player(id, str(info.get("name", "")))
	if mine.get("position") is Array and (mine["position"] as Array).size() == 2:
		spot = Vector2(float(mine["position"][0]), float(mine["position"][1]))
	var built: Dictionary = world.get("buildings", {}).duplicate(true)
	built.erase("home")
	built.erase("recall_left")
	return {"seed": int(world.get("world", {}).get("seed", config["seed"])), "name": str(config["world_name"]),
		"difficulty": str(config["difficulty"]), "hardcore": false, "day": _day, "time": _time, "storminess": _storminess,
		"spawn": spot, "host_name": str(config["name"]), "dedicated": true, "pvp": bool(config["pvp"]),
		"sections": {"buildings": built}}


## Who may come in, beyond the password and the room.
func _admit(info: Dictionary) -> String:
	var name := str(info.get("name", ""))
	if config.get("permadeath", false) and name in world.get("fallen", []):
		return "%s fell in this world, and permadeath is on." % name
	if not config.get("allow_friends", true) and name != str(config.get("owner", name)):
		return "This world is not taking visitors."
	return ""


func _on_roster() -> void:
	for peer: int in Net.roster:
		if not _players.has(peer):
			_players[peer] = {"name": Net.name_of(peer), "joined": Time.get_unix_time_from_system()}
			ServerStore.log_line(id, "%s joined (%d on)." % [Net.name_of(peer), Net.roster.size()])
	for peer: int in _players.keys():
		if not Net.roster.has(peer):
			_keep_player(peer)
			ServerStore.log_line(id, "%s left (%d on)." % [_players[peer]["name"], Net.roster.size()])
			_players.erase(peer)
	if not _stopping:
		_write_status("running")


func _on_state(peer: int, state: Dictionary) -> void:
	if _players.has(peer) and not bool(state.get("in", false)) and state.get("p") is Vector2:
		var at: Vector2 = state["p"]
		_players[peer]["position"] = [at.x, at.y]


func _keep_player(peer: int) -> void:
	var entry: Dictionary = _players.get(peer, {})
	if entry.has("position"):
		var data := ServerStore.load_player(id, entry["name"])
		data["position"] = entry["position"]
		data["last_seen"] = Time.get_unix_time_from_system()
		ServerStore.save_player(id, entry["name"], data)


func _on_deed(peer: int, kind: String, _data: Dictionary) -> void:
	if kind == "died" and config.get("permadeath", false):
		var fallen: Array = world.get("fallen", [])
		var name := Net.name_of(peer)
		if not name in fallen:
			fallen.append(name)
			world["fallen"] = fallen
			ServerStore.log_line(id, "%s fell, and may not return (permadeath)." % name)
			save()


## Something built or taken down: checked against what stands, kept, and
## told to everyone.
func _on_op(op: Dictionary, peer: int) -> void:
	var record: Dictionary = op.get("record", {})
	var built: Dictionary = world.get("buildings", {})
	var records: Array = built.get("records", [])
	var rid := int(record.get("id", 0))
	match str(op.get("op", "")):
		"build":
			if not Buildings.KINDS.has(str(record.get("kind", ""))) or rid <= 0:
				return
			for other: Variant in records:
				if other is Dictionary and int(other.get("id", 0)) == rid:
					return
			var kept := record.duplicate(true)
			kept["owner"] = Net.name_of(peer)
			records.append(kept)
		"unbuild":
			var gone := {}
			for other: Variant in records:
				if other is Dictionary and int(other.get("id", 0)) == rid:
					gone = other
			if gone.is_empty():
				return
			var owner := str(gone.get("owner", ""))
			if owner != "" and owner != Net.name_of(peer):
				return
			records.erase(gone)
			if str(gone.get("kind", "")) == "house":
				records = records.filter(func(r: Variant) -> bool: return not (r is Dictionary and str(r.get("where", "")) == "house:%d" % rid))
		_:
			return
	built["records"] = records
	world["buildings"] = built
	Net.broadcast_op(op)


func _process(delta: float) -> void:
	if not _live or _stopping:
		return
	var empty := Net.roster.is_empty()
	# Resting with nobody on: fewer updates a second.
	Engine.max_fps = IDLE_FPS if empty and config.get("idle_mode", true) else BUSY_FPS
	if not (empty and config.get("pause_when_empty", false)):
		_time += delta / DAY_SECONDS
		if _time >= 1.0:
			_time -= 1.0
			_day += 1
		_front_left -= delta
		if _front_left <= 0.0:
			_front_left = randf_range(FRONT_SECONDS.x, FRONT_SECONDS.y)
			var roll := randf()
			_storminess = 0 if roll < 0.62 else 1 if roll < 0.9 else 2
	_clock_left -= delta
	if _clock_left <= 0.0 and not empty:
		_clock_left = 2.0
		Net.send_clock(_day, _time, _storminess)
	_save_left -= delta
	if _save_left <= 0.0:
		_save_left = float(config["autosave_minutes"]) * 60.0
		save()
	_backup_left -= delta
	if _backup_left <= 0.0:
		_backup_left = BACKUP_EVERY
		ServerStore.backup(id)
	_status_left -= delta
	if _status_left <= 0.0:
		_status_left = STATUS_EVERY
		_write_status("running")
	_command_left -= delta
	if _command_left <= 0.0:
		_command_left = 0.5
		match ServerStore.take_command(id):
			"stop":
				stop("Stopped by the host.")
			"save":
				save()
				ServerStore.log_line(id, "Saved on request.")
			"restart":
				stop("Restarting.", true)


func save() -> void:
	if not _live:
		return
	world["world"] = {"seed": int(world.get("world", {}).get("seed", config["seed"])), "day": _day, "time": _time}
	for peer: int in _players:
		_keep_player(peer)
	if ServerStore.save_world(id, world):
		_last_save = Time.get_unix_time_from_system()
	else:
		ServerStore.log_line(id, "Saving failed: the disk may be full or the folder locked.")


## Stops for good (or, with `again`, comes straight back up): everyone is
## told and sent home, the world is saved, and the lock let go.
func stop(reason: String, again: bool = false) -> void:
	if _stopping or not _live:
		return
	_stopping = true
	ServerStore.log_line(id, reason)
	save()
	ServerStore.backup(id)
	# Everyone is told why, then sent home.
	Net.farewell("The server %s: %s" % ["is restarting" if again else "was stopped", reason])
	await get_tree().create_timer(0.3).timeout
	Net.leave(reason)
	_write_status("stopped" if not again else "restarting", reason)
	ServerStore.unlock(id)
	if again and not supervised:
		ServerStore.launch(id)
	get_tree().quit(0)


func _notification(what: int) -> void:
	# Closed from outside (the window manager, Ctrl+C): still save first.
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _live and not _stopping:
		stop("Closed.")


func _write_status(state: String, note: String = "") -> void:
	var names: Array = []
	for peer: int in Net.roster:
		names.append(Net.name_of(peer))
	var memory := float(OS.get_static_memory_usage()) / 1048576.0
	if memory > float(config.get("memory_warning_mb", 1536)) and not _memory_warned:
		_memory_warned = true
		ServerStore.log_line(id, "Memory use is high: %d MB." % roundi(memory))
	ServerStore.write_json_atomic(ServerStore.path_of(id, "status.json"), {
		"state": state, "note": note, "pid": OS.get_process_id(), "heartbeat": Time.get_unix_time_from_system(),
		"started": _started, "last_save": _last_save, "port": int(config.get("port", ServerStore.PORT)),
		"players": names, "player_count": names.size(), "max_players": int(config.get("max_players", 8)),
		"world": str(config.get("world_name", "")), "day": _day, "idle": Net.roster.is_empty(),
		"memory_mb": roundi(memory), "fps": Engine.get_frames_per_second(),
		"addresses": Net.local_addresses(),
	})
