extends Node
## The scene a hosting process runs instead of the game: the server
## itself, its supervisor, or its tray manager (Net.boot_role).


func _ready() -> void:
	match Net.boot_role:
		"server":
			var server := DedicatedServer.new()
			server.name = "Server"
			server.supervised = "--hth-supervised" in OS.get_cmdline_user_args()
			add_child(server)
			server.start(Net.boot_server)
		"supervise":
			var supervisor := ServerSupervisor.new()
			supervisor.name = "Supervisor"
			add_child(supervisor)
			supervisor.start(Net.boot_server)
		"tray":
			var tray := ServerTray.new()
			tray.name = "Tray"
			add_child(tray)
			tray.start(Net.boot_server)
		_:
			get_tree().quit(0)
