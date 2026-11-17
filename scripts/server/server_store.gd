class_name ServerStore
extends RefCounted
## Hosted worlds kept on this computer: each in a folder of its own,
## user://servers/<id>/, holding
##   server.json    the host's settings (see DEFAULTS)
##   world.json     the server's own copy of the world (saved atomically)
##   players/       what each player has in this world (where they stood)
##   backups/       rotating copies of world.json
##   status.json    the running server's heartbeat (who is on, since when)
##   control.json   a command for it (stop, save, restart), from the game
##                  or the tray
##   lock.json      held while a server process owns the world: no two
##                  processes ever write the same world
##   server.log     what it did
##
## Nothing here runs anything by itself, and nothing starts with Windows
## unless the host turns that on.

const ROOT := "user://servers"
const BACKUPS_KEPT := 6
## A heartbeat older than this means the server is gone.
const HEARTBEAT_STALE := 8.0
const LOG_LIMIT := 1_000_000
const MAX_PLAYERS := 20
const PORT := 24680

## Every setting a server has, and its default.
const DEFAULTS := {
	"name": "My World",
	"world_name": "",
	"seed": 0,
	"max_players": 8,
	# "private" (direct address only), "lan" (found on the network). Public
	# listing would need a discovery service; it is not offered.
	"visibility": "lan",
	"password_hash": "",
	# "background" (keeps running when the game closes) or "persistent"
	# (and comes back after a crash, and with Windows if asked).
	"mode": "background",
	"pvp": false,
	"difficulty": "normal",
	"permadeath": false,
	"allow_friends": true,
	"autosave_minutes": 5,
	"port": PORT,
	"start_with_windows": false,
	"auto_restart": false,
	# The small manager by the clock (Windows/macOS tray; a window elsewhere).
	"show_tray": true,
	# Who made it; with allow_friends off, only they may join.
	"owner": "",
	"idle_mode": true,
	"pause_when_empty": false,
	# Simulation budgets (a guide for the server; Godot cannot cap its CPU).
	"max_active_chunks": 400,
	"chunk_sim_distance": 3,
	"enemy_sim_distance": 1600,
	"background_quality": "normal",
	"max_instances": 4,
	"memory_warning_mb": 1536,
	"created_at": 0,
}

## Sections of a world that belong to the world, not to a character.
const WORLD_SECTIONS: Array[String] = ["world", "meta", "buildings", "structures", "waystones", "memory", "exploration", "map", "treasure",
	"bounties", "settlers", "raids", "monster_town", "village_projects", "rifts", "gates", "factions", "saint_lull", "trade", "quest_book", "quests", "errands"]


static func dir_of(id: String) -> String:
	return ROOT.path_join(id)


static func path_of(id: String, file: String) -> String:
	return dir_of(id).path_join(file)


static func ensure(id: String) -> void:
	for sub: String in ["", "players", "backups"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_of(id).path_join(sub)))


## Every server on this computer, newest first: [{"id", "config", "status"}].
static func list() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT))
	var dir := DirAccess.open(ROOT)
	if dir == null:
		return out
	for id in dir.get_directories():
		var config := load_config(id)
		if config.is_empty():
			continue
		out.append({"id": id, "config": config, "status": status(id)})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["config"].get("created_at", 0)) > int(b["config"].get("created_at", 0)))
	return out


static func load_config(id: String) -> Dictionary:
	var data: Variant = read_json(path_of(id, "server.json"))
	if not data is Dictionary:
		return {}
	var config := DEFAULTS.duplicate(true)
	config.merge(data, true)
	config["max_players"] = clampi(int(config["max_players"]), 2, MAX_PLAYERS)
	config["autosave_minutes"] = clampi(int(config["autosave_minutes"]), 1, 60)
	config["port"] = clampi(int(config["port"]), 1024, 65535)
	return config


static func save_config(id: String, config: Dictionary) -> bool:
	ensure(id)
	return write_json_atomic(path_of(id, "server.json"), config)


static func hash_password(password: String) -> String:
	return "" if password == "" else (password + ":hall-through-heart").sha256_text()


## Makes a new server. With `from_slot`, it takes a copy of that world (the
## world itself, not the character): the original world stays as it was.
static func create(config: Dictionary, from_slot: String = "") -> String:
	var id := "server_%d_%d" % [int(Time.get_unix_time_from_system()), randi() % 10000]
	ensure(id)
	var settings := DEFAULTS.duplicate(true)
	settings.merge(config, true)
	settings["created_at"] = int(Time.get_unix_time_from_system())
	var world := {}
	if from_slot != "":
		var source: Variant = read_json("user://saves/%s.json" % from_slot)
		if source is Dictionary:
			for section: String in WORLD_SECTIONS:
				if (source as Dictionary).has(section):
					world[section] = source[section]
	if not world.has("world"):
		world["world"] = {"seed": int(settings["seed"]) if int(settings["seed"]) != 0 else int(randi()), "day": 1, "time": 0.3}
	settings["seed"] = int(world["world"].get("seed", 0))
	if str(settings["world_name"]) == "":
		settings["world_name"] = str(world.get("meta", {}).get("name", settings["name"]))
	world["meta"] = {"name": settings["world_name"], "difficulty": settings["difficulty"], "hardcore": settings["permadeath"]}
	save_config(id, settings)
	write_json_atomic(path_of(id, "world.json"), world)
	log_line(id, "Server made: %s (seed %d)%s" % [settings["name"], settings["seed"], (" from world " + from_slot) if from_slot != "" else ""])
	return id


static func delete(id: String) -> bool:
	if is_running(id):
		return false
	_remove_tree(ProjectSettings.globalize_path(dir_of(id)))
	return true


static func _remove_tree(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for file in dir.get_files():
		dir.remove(file)
	for sub in dir.get_directories():
		_remove_tree(path.path_join(sub))
	DirAccess.remove_absolute(path)


# --- files, safely

static func read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	# A torn file is null (the caller falls back), without a console error.
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return null
	return json.data


## Writes to a temporary file first and then puts it in place, so a crash
## mid-write never leaves half a world: the old file stays until the new
## one is whole.
static func write_json_atomic(path: String, data: Variant) -> bool:
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	var global := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		var previous := global + ".prev"
		DirAccess.remove_absolute(previous)
		DirAccess.rename_absolute(global, previous)
		if DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), global) != OK:
			DirAccess.rename_absolute(previous, global)
			return false
		DirAccess.remove_absolute(previous)
		return true
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), global) == OK


static func load_world(id: String) -> Dictionary:
	var data: Variant = read_json(path_of(id, "world.json"))
	if data is Dictionary:
		return data
	# A torn save: the copy kept while writing, or the newest backup.
	var previous: Variant = read_json(path_of(id, "world.json") + ".prev")
	if previous is Dictionary:
		return previous
	for backup: String in backups(id):
		var copy: Variant = read_json(path_of(id, "backups").path_join(backup))
		if copy is Dictionary:
			return copy
	return {}


static func save_world(id: String, world: Dictionary) -> bool:
	return write_json_atomic(path_of(id, "world.json"), world)


## Keeps a dated copy of the world and drops the oldest past BACKUPS_KEPT.
static func backup(id: String) -> void:
	ensure(id)
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	DirAccess.copy_absolute(ProjectSettings.globalize_path(path_of(id, "world.json")), ProjectSettings.globalize_path(path_of(id, "backups").path_join("world_%s.json" % stamp)))
	var kept := backups(id)
	for old in kept.slice(BACKUPS_KEPT):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path_of(id, "backups").path_join(old)))


## Backups, newest first.
static func backups(id: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(path_of(id, "backups"))
	if dir == null:
		return out
	for file in dir.get_files():
		if file.begins_with("world_") and file.ends_with(".json"):
			out.append(file)
	out.sort()
	out.reverse()
	return out


## Puts a backup back as the world (only while the server is not running).
## The world as it was is kept as a backup first, so this can be undone.
static func restore_backup(id: String, file: String) -> String:
	if is_running(id):
		return "Stop the server first."
	var copy: Variant = read_json(path_of(id, "backups").path_join(file.get_file()))
	if not copy is Dictionary:
		return "That backup could not be read."
	backup(id)
	if not save_world(id, copy):
		return "The world could not be written."
	log_line(id, "Restored the backup %s." % file.get_file())
	return ""


## The last lines of the server's log.
static func log_tail(id: String, lines: int = 200) -> String:
	var path := path_of(id, "server.log")
	if not FileAccess.file_exists(path):
		return ""
	var all := FileAccess.get_file_as_string(path).strip_edges().split("\n")
	return "\n".join(all.slice(maxi(all.size() - lines, 0)))


static func load_player(id: String, player: String) -> Dictionary:
	var data: Variant = read_json(path_of(id, "players").path_join(_safe(player) + ".json"))
	return data if data is Dictionary else {}


static func save_player(id: String, player: String, data: Dictionary) -> void:
	ensure(id)
	write_json_atomic(path_of(id, "players").path_join(_safe(player) + ".json"), data)


static func _safe(name: String) -> String:
	var out := ""
	for c in name.to_lower():
		out += c if c in "abcdefghijklmnopqrstuvwxyz0123456789_-" else "_"
	return out.left(32) if out != "" else "player"


# --- the running server, as seen from outside

static func status(id: String) -> Dictionary:
	var data: Variant = read_json(path_of(id, "status.json"))
	return data if data is Dictionary else {}


## Whether a server process is alive for this world (its heartbeat is fresh).
static func is_running(id: String) -> bool:
	var state := status(id)
	if state.is_empty() or str(state.get("state", "")) in ["stopped", "crashed"]:
		return false
	return Time.get_unix_time_from_system() - float(state.get("heartbeat", 0.0)) < HEARTBEAT_STALE


## The first of our servers that is running, or {}.
static func running() -> Dictionary:
	for server: Dictionary in list():
		if is_running(server["id"]):
			return server
	return {}


## Asks the running server to "stop", "save" or "restart".
## Commands older than this are from before; they are dropped, not done.
const COMMAND_FRESH := 60.0


## Asks the running server to "stop", "save" or "restart". Nothing is left
## for a server that is not running (it would find it when next started).
static func send(id: String, command: String) -> bool:
	if not is_running(id):
		return false
	ensure(id)
	return write_json_atomic(path_of(id, "control.json"), {"command": command, "at": Time.get_unix_time_from_system()})


## The command waiting for the server, if any, and fresh; taken once.
static func take_command(id: String) -> String:
	var path := path_of(id, "control.json")
	var data: Variant = read_json(path)
	if data == null:
		return ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if not data is Dictionary:
		return ""
	if Time.get_unix_time_from_system() - float((data as Dictionary).get("at", 0.0)) > COMMAND_FRESH:
		log_line(id, "Ignored an old \"%s\" request." % str((data as Dictionary).get("command", "")))
		return ""
	return str((data as Dictionary).get("command", ""))


## Takes the world for this process; false if another process holds it.
static func lock(id: String) -> bool:
	if is_running(id):
		var held: Variant = read_json(path_of(id, "lock.json"))
		if held is Dictionary and int((held as Dictionary).get("pid", -1)) != OS.get_process_id():
			return false
	return write_json_atomic(path_of(id, "lock.json"), {"pid": OS.get_process_id(), "at": Time.get_unix_time_from_system()})


## Whether this process is the one holding the world's lock. Asked again a
## moment after taking it: two servers started at the same instant both
## write it, the later write stands, and the other steps back.
static func holds_lock(id: String) -> bool:
	var held: Variant = read_json(path_of(id, "lock.json"))
	return held is Dictionary and int((held as Dictionary).get("pid", -1)) == OS.get_process_id()


static func unlock(id: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path_of(id, "lock.json")))


static func log_line(id: String, text: String) -> void:
	ensure(id)
	var path := path_of(id, "server.log")
	if FileAccess.file_exists(path) and FileAccess.get_file_as_bytes(path).size() > LOG_LIMIT:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".1"))
		DirAccess.rename_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + ".1"))
	var file := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_line("[%s] %s" % [Time.get_datetime_string_from_system(false, true), text])
	file.close()


# --- starting it

## The program a server runs as: HTH_Server beside the game when it was
## exported, else the game itself, without its window.
static func server_command(id: String, role: String) -> Array:
	var exe := OS.get_executable_path()
	var args: PackedStringArray = []
	var windows := OS.get_name() == "Windows"
	var beside := exe.get_base_dir().path_join("HTH_Server.exe" if windows else "HTH_Server")
	# The tray draws, so it runs in the game's program even when asked for
	# by the server's (which has no window to draw in).
	var game := exe.get_base_dir().path_join("HallThroughHeart.exe" if windows else "HallThroughHeart")
	if role == "tray" and exe.get_file().begins_with("HTH_Server") and FileAccess.file_exists(game):
		exe = game
	elif role != "tray" and FileAccess.file_exists(beside):
		exe = beside
	else:
		if OS.has_feature("editor"):
			args.append_array(["--path", ProjectSettings.globalize_path("res://")])
		if role != "tray":
			args.append("--headless")
	args.append("--")
	args.append("--hth-%s=%s" % [role, id])
	return [exe, args]


## Starts the server for a world (through its supervisor when it should
## come back after a crash). Returns "" or what went wrong.
static func launch(id: String) -> String:
	if is_running(id):
		return "That world is already being hosted."
	var config := load_config(id)
	if config.is_empty():
		return "That server's settings are missing."
	var role := "supervise" if config.get("auto_restart", false) or config.get("mode", "") == "persistent" else "server"
	var command := server_command(id, role)
	var pid := OS.create_process(command[0], command[1], false)
	if pid <= 0:
		return "Could not start the server program."
	log_line(id, "Started by the game (%s, pid %d)" % [role, pid])
	return ""


## Shows (or hides) the server's tray manager, a small program of its own.
static func launch_tray(id: String) -> int:
	var command := server_command(id, "tray")
	return OS.create_process(command[0], command[1], false)


## Turns starting with Windows on or off for a server (Windows only; off
## unless the host asks).
static func set_start_with_windows(id: String, on: bool) -> String:
	if OS.get_name() != "Windows":
		return "Starting with the computer is only offered on Windows."
	var key := "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run"
	var entry := "HallThroughHeart_%s" % id
	var output: Array = []
	if on:
		var command := server_command(id, "supervise")
		# Started with Windows, nothing else would show its tray icon.
		var args: PackedStringArray = command[1]
		args.append("--hth-with-tray")
		var line := "\"%s\" %s" % [command[0], " ".join(args)]
		if OS.execute("reg", ["add", key, "/v", entry, "/t", "REG_SZ", "/d", line, "/f"], output) != 0:
			return "Windows would not add it to startup."
	else:
		OS.execute("reg", ["delete", key, "/v", entry, "/f"], output)
	return ""
