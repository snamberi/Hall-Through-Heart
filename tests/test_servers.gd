extends RefCounted
## Worlds hosted in the background: their files, the lock that keeps two
## processes off one world, commands, what the server lets be built, who
## it lets in, and the My Servers form.


func _make(t: TestContext, extra: Dictionary = {}) -> String:
	var config := {"name": "Test Server", "world_name": "Testmere", "seed": 1234, "port": 24790}
	config.merge(extra, true)
	var id := ServerStore.create(config)
	t.check(id != "" and FileAccess.file_exists(ServerStore.path_of(id, "server.json")), "a server is made")
	return id


## Pretends another process is hosting it right now.
func _fake_running(id: String, fresh: bool = true) -> void:
	var now := Time.get_unix_time_from_system()
	ServerStore.write_json_atomic(ServerStore.path_of(id, "status.json"), {"state": "running", "pid": 999999, "heartbeat": now if fresh else now - 60.0})
	ServerStore.write_json_atomic(ServerStore.path_of(id, "lock.json"), {"pid": 999999, "at": now})


func test_a_server_keeps_its_world_safely(t: TestContext) -> void:
	var id := _make(t)
	var world := ServerStore.load_world(id)
	t.equal(int(world["world"]["seed"]), 1234, "the world takes the seed")
	t.equal(str(world["meta"]["name"]), "Testmere", "and its name")
	world["buildings"] = {"records": [{"id": 1, "kind": "crate", "x": 4.0, "y": 8.0, "where": "world"}]}
	t.check(ServerStore.save_world(id, world), "it saves")
	t.check(not FileAccess.file_exists(ServerStore.path_of(id, "world.json.tmp")), "nothing half-written is left behind")
	# A torn world file: the copy kept while writing is used instead.
	DirAccess.copy_absolute(ProjectSettings.globalize_path(ServerStore.path_of(id, "world.json")), ProjectSettings.globalize_path(ServerStore.path_of(id, "world.json.prev")))
	var file := FileAccess.open(ServerStore.path_of(id, "world.json"), FileAccess.WRITE)
	file.store_string("{\"world\": {\"se")
	file.close()
	t.equal((ServerStore.load_world(id).get("buildings", {}).get("records", []) as Array).size(), 1, "a torn save falls back to the last whole one")
	ServerStore.save_world(id, world)
	# Backups rotate, newest first, and one can be put back.
	for index in ServerStore.BACKUPS_KEPT + 2:
		var stamp := "world_2026-01-01_00-00-%02d.json" % index
		ServerStore.write_json_atomic(ServerStore.path_of(id, "backups").path_join(stamp), {"world": {"seed": 1234, "day": index + 1}})
	ServerStore.backup(id)
	var kept := ServerStore.backups(id)
	t.equal(kept.size(), ServerStore.BACKUPS_KEPT, "only the newest backups are kept")
	t.check(kept[0] > kept[kept.size() - 1], "newest first")
	t.equal(ServerStore.restore_backup(id, kept[1]), "", "a backup can be put back")
	t.equal(int(ServerStore.load_world(id)["world"]["day"]), ServerStore.BACKUPS_KEPT + 2, "and it is the world again")
	t.check(ServerStore.delete(id), "a stopped server can be deleted")
	t.check(not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(ServerStore.dir_of(id))), "and its folder is gone")


func test_only_one_process_writes_a_world(t: TestContext) -> void:
	var id := _make(t)
	t.check(ServerStore.lock(id), "a free world can be taken")
	t.check(ServerStore.holds_lock(id), "and this process holds it")
	ServerStore.unlock(id)
	_fake_running(id)
	t.check(ServerStore.is_running(id), "a fresh heartbeat means it runs")
	t.check(not ServerStore.lock(id), "a world another process hosts cannot be taken")
	t.check(not ServerStore.holds_lock(id), "and is not ours")
	t.check(not ServerStore.delete(id), "nor deleted while it runs")
	t.equal(ServerStore.launch(id), "That world is already being hosted.", "nor started twice")
	t.check(ServerStore.restore_backup(id, "x.json") != "", "nor rolled back under it")
	_fake_running(id, false)
	t.check(not ServerStore.is_running(id), "a heartbeat gone quiet means it is gone")
	t.check(ServerStore.lock(id), "and its world can be taken again")
	ServerStore.unlock(id)
	ServerStore.delete(id)


func test_commands_reach_only_a_running_server_and_never_go_stale(t: TestContext) -> void:
	var id := _make(t)
	t.check(not ServerStore.send(id, "stop"), "nothing is sent to a server that is not running")
	t.check(not FileAccess.file_exists(ServerStore.path_of(id, "control.json")), "so a later start finds nothing waiting")
	_fake_running(id)
	t.check(ServerStore.send(id, "save"), "a running server is asked")
	t.equal(ServerStore.take_command(id), "save", "and hears it")
	t.equal(ServerStore.take_command(id), "", "once")
	ServerStore.write_json_atomic(ServerStore.path_of(id, "control.json"), {"command": "stop", "at": Time.get_unix_time_from_system() - 3600.0})
	t.equal(ServerStore.take_command(id), "", "an old request is dropped, not done")
	ServerStore.unlock(id)
	_fake_running(id, false)
	ServerStore.delete(id)


func test_a_half_started_server_never_saves_over_the_world(t: TestContext) -> void:
	var id := _make(t)
	var world := ServerStore.load_world(id)
	world["buildings"] = {"records": [{"id": 9, "kind": "crate", "x": 0.0, "y": 0.0, "where": "world"}]}
	ServerStore.save_world(id, world)
	var server := DedicatedServer.new()
	server.id = id
	server.config = ServerStore.load_config(id)
	# Not live yet: the world is not loaded, so nothing may be written.
	server.save()
	server.stop("too early")
	t.equal((ServerStore.load_world(id)["buildings"]["records"] as Array).size(), 1, "the world is untouched")
	server.free()
	ServerStore.delete(id)


func test_the_server_decides_what_is_built(t: TestContext) -> void:
	var server := DedicatedServer.new()
	server.config = ServerStore.DEFAULTS.duplicate(true)
	server.world = {"buildings": {"records": []}}
	var roster_was: Dictionary = Net.roster.duplicate()
	Net.roster = {5: {"name": "Ana"}, 6: {"name": "Bo"}}
	var crate := {"id": 70, "kind": "crate", "x": 10.0, "y": 20.0, "where": "world"}
	server._on_op({"op": "build", "record": crate}, 5)
	var records: Array = server.world["buildings"]["records"]
	t.equal(records.size(), 1, "a build is kept")
	t.equal(str(records[0]["owner"]), "Ana", "under whoever built it")
	server._on_op({"op": "build", "record": crate}, 6)
	server._on_op({"op": "build", "record": {"id": 71, "kind": "no such thing"}}, 6)
	t.equal((server.world["buildings"]["records"] as Array).size(), 1, "the same piece twice, or a made-up one, is not")
	server._on_op({"op": "unbuild", "record": {"id": 70}}, 6)
	t.equal((server.world["buildings"]["records"] as Array).size(), 1, "nobody takes down what someone else built")
	server._on_op({"op": "unbuild", "record": {"id": 70}}, 5)
	t.equal((server.world["buildings"]["records"] as Array).size(), 0, "the builder can")
	Net.roster = roster_was
	server.free()


func test_who_the_server_lets_in(t: TestContext) -> void:
	var server := DedicatedServer.new()
	server.config = ServerStore.DEFAULTS.duplicate(true)
	server.world = {"fallen": ["Cass"]}
	t.equal(server._admit({"name": "Cass"}), "", "a fall does not count without permadeath")
	server.config["permadeath"] = true
	t.check(server._admit({"name": "Cass"}) != "", "with permadeath, the fallen stay out")
	t.equal(server._admit({"name": "Dag"}), "", "everyone else is welcome")
	server.config["allow_friends"] = false
	server.config["owner"] = "Dag"
	t.check(server._admit({"name": "Eli"}) != "", "a world closed to visitors keeps them out")
	t.equal(server._admit({"name": "Dag"}), "", "but not its owner")
	var spot := server.world_now(0, {"name": "Nobody"})
	t.check(spot.get("dedicated", false) and spot.get("sections", {}).has("buildings"), "joiners get the world and what is built in it")
	server.free()
	t.check(ServerStore.hash_password("ember") != "" and ServerStore.hash_password("ember") != "ember", "passwords are kept hashed")
	t.equal(ServerStore.hash_password(""), "", "and none means none")


func test_settings_stay_in_bounds(t: TestContext) -> void:
	var id := _make(t, {"max_players": 99, "autosave_minutes": 0, "port": 80})
	var config := ServerStore.load_config(id)
	t.equal(int(config["max_players"]), ServerStore.MAX_PLAYERS, "at most twenty players")
	t.equal(int(config["autosave_minutes"]), 1, "autosave at least every minute")
	t.check(int(config["port"]) >= 1024, "no system ports")
	t.check(not config["start_with_windows"], "nothing starts with Windows unless asked")
	t.check(not config["auto_restart"], "nor restarts itself unless asked")
	ServerStore.delete(id)


func test_a_server_build_can_be_exported(t: TestContext) -> void:
	var config := ConfigFile.new()
	config.load("res://export_presets.cfg")
	var found := ""
	for section: String in config.get_sections():
		if section.begins_with("preset.") and not section.ends_with(".options") and config.get_value(section, "name") == "Windows Server":
			found = section
	t.check(found != "", "a Windows Server preset")
	t.check(found != "" and bool(config.get_value(found, "dedicated_server", false)), "built as a dedicated server (no window)")
	t.check(found != "" and str(config.get_value(found, "export_path", "")).ends_with("HTH_Server.exe"), "named HTH_Server.exe, beside the game")


func test_the_my_servers_form_makes_a_server(t: TestContext) -> void:
	var page := ServersPage.new()
	t.tree.root.add_child(page)
	await t.frames(2)
	page._open_form("", false)
	(page._fields["name"] as LineEdit).text = "Form Made"
	(page._fields["world_name"] as LineEdit).text = "Formhold"
	(page._fields["seed"] as LineEdit).text = "777"
	(page._fields["password"] as LineEdit).text = "secret"
	(page._fields["max_players"] as SpinBox).value = 12
	(page._fields["port"] as SpinBox).value = 24791
	(page._fields["mode"] as OptionButton).select(1)
	page._on_mode_changed()
	page._submit(false)
	var made := {}
	for server: Dictionary in ServerStore.list():
		if server["config"]["name"] == "Form Made":
			made = server
	t.check(not made.is_empty(), "the form makes the server")
	if not made.is_empty():
		var config: Dictionary = made["config"]
		t.equal(int(config["seed"]), 777, "with its seed")
		t.equal(int(config["max_players"]), 12, "its room")
		t.equal(str(config["mode"]), "persistent", "its mode")
		t.check(bool(config["auto_restart"]), "persistent comes back after a crash")
		t.equal(str(config["password_hash"]), ServerStore.hash_password("secret"), "and its password, hashed")
		# Editing keeps the password unless it is changed.
		page._open_form(made["id"], false)
		(page._fields["max_players"] as SpinBox).value = 6
		page._submit(false)
		var edited := ServerStore.load_config(made["id"])
		t.equal(int(edited["max_players"]), 6, "settings can be changed")
		t.equal(str(edited["password_hash"]), ServerStore.hash_password("secret"), "and the password stays")
		ServerStore.delete(made["id"])
	page.queue_free()
