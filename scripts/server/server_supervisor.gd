class_name ServerSupervisor
extends Node
## Keeps a persistent world up: starts its server and, if the server dies
## without being told to stop (a crash), starts it again, a few times at
## most in a short while so a world that cannot start does not spin. When
## the host stops the server, the supervisor ends too. Headless, like the
## server; both show in Task Manager.

const MOST_RESTARTS := 5
const WITHIN := 600.0

var id := ""
var _pid := -1
var _restarts: Array[float] = []
var _check_left := 1.0


func start(server_id: String) -> void:
	id = server_id
	Engine.max_fps = 2
	OS.low_processor_usage_mode = true
	if ServerStore.is_running(id):
		ServerStore.log_line(id, "Supervisor: the world is already hosted; nothing to watch over.")
		get_tree().quit(0)
		return
	ServerStore.log_line(id, "Supervisor watching over the server.")
	_launch()
	# Started with Windows: the tray icon comes up with it.
	if "--hth-with-tray" in OS.get_cmdline_user_args() and ServerStore.load_config(id).get("show_tray", true):
		ServerStore.launch_tray(id)


func _launch() -> void:
	var command := ServerStore.server_command(id, "server")
	var args: PackedStringArray = command[1]
	args.append("--hth-supervised")
	_pid = OS.create_process(command[0], args, false)
	if _pid <= 0:
		ServerStore.log_line(id, "Supervisor: could not start the server.")
		get_tree().quit(1)


func _process(delta: float) -> void:
	_check_left -= delta
	if _check_left > 0.0 or _pid <= 0:
		return
	_check_left = 1.0
	if OS.is_process_running(_pid):
		return
	var state := str(ServerStore.status(id).get("state", ""))
	if state == "stopped":
		ServerStore.log_line(id, "Supervisor: the server was stopped; done.")
		get_tree().quit(0)
		return
	var now := Time.get_unix_time_from_system()
	if state == "restarting":
		ServerStore.log_line(id, "Supervisor: restarting the server, as asked.")
		ServerStore.unlock(id)
		_launch()
		return
	# Gone without being stopped: a crash.
	_restarts = _restarts.filter(func(at: float) -> bool: return now - at < WITHIN)
	if _restarts.size() >= MOST_RESTARTS:
		ServerStore.log_line(id, "Supervisor: the server keeps failing; giving up. See the log above.")
		ServerStore.write_json_atomic(ServerStore.path_of(id, "status.json"), {"state": "crashed", "note": "Kept failing to stay up.", "heartbeat": now})
		ServerStore.unlock(id)
		get_tree().quit(1)
		return
	_restarts.append(now)
	ServerStore.log_line(id, "Supervisor: the server ended unexpectedly (%s); starting it again." % (state if state != "" else "no status"))
	ServerStore.unlock(id)
	_launch()
