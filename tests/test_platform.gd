extends RefCounted
## Builds for Windows and Android, and playing by touch.


func test_export_presets_are_ready_for_windows_and_android(t: TestContext) -> void:
	var config := ConfigFile.new()
	t.equal(config.load("res://export_presets.cfg"), OK, "export_presets.cfg is in the project")
	var platforms: Array[String] = []
	for section: String in config.get_sections():
		if section.ends_with(".options") or not section.begins_with("preset."):
			continue
		platforms.append(str(config.get_value(section, "platform")))
	t.check("Windows Desktop" in platforms, "a Windows preset")
	t.check("Android" in platforms, "an Android preset")
	for path: String in ["res://assets/icon/icon.png", "res://assets/icon/icon.ico", "res://assets/icon/android_192.png",
			"res://assets/icon/android_foreground.png", "res://assets/icon/android_background.png", "res://assets/icon/android_monochrome.png"]:
		t.check(FileAccess.file_exists(path), "%s is drawn" % path.get_file())
	t.equal(str(ProjectSettings.get_setting("application/config/icon")), "res://assets/icon/icon.png", "the window wears the icon")
	t.check(bool(ProjectSettings.get_setting("rendering/textures/vram_compression/import_etc2_astc")), "textures can go to phones")
	t.equal(int(ProjectSettings.get_setting("display/window/handheld/orientation")), 4, "phones hold it sideways either way")
	var android := ""
	for section: String in config.get_sections():
		if section.begins_with("preset.") and not section.ends_with(".options") and config.get_value(section, "platform") == "Android":
			android = section + ".options"
	t.check(bool(config.get_value(android, "permissions/internet", false)), "Android may use the network (for LAN play)")


func test_touch_controls_send_the_same_actions_as_keys(t: TestContext) -> void:
	var main := await t.game()
	var player: Player = main.get_node("Player")
	var touch: TouchControls = main.get_node("TouchControls")
	var was: String = GameSettings.touch_controls
	GameSettings.touch_controls = "on"
	touch._apply()
	await t.frames(1)
	t.check(TouchControls.active, "the touch controls show")
	var mouse_attacks := false
	for event in InputMap.action_get_events("attack"):
		mouse_attacks = mouse_attacks or event is InputEventMouseButton
	t.check(not mouse_attacks, "a finger moving the mouse does not swing the sword")
	# A thumb on the attack button.
	var press := InputEventScreenTouch.new()
	press.index = 1
	press.pressed = true
	press.position = touch._buttons["attack"]["at"]
	touch._input(press)
	await t.frames(1)
	t.check(Input.is_action_pressed("attack"), "the attack button attacks")
	# Dragging it aims.
	var drag := InputEventScreenDrag.new()
	drag.index = 1
	drag.position = press.position + Vector2(0, -60)
	touch._input(drag)
	t.check(player.aim_direction().y < -0.9, "dragging the attack button aims (%s)" % player.aim_direction())
	press.pressed = false
	touch._input(press)
	# A quick tap is held through a physics frame so the blow lands.
	for step in 4:
		await t.tree.physics_frame
	await t.frames(1)
	t.check(not Input.is_action_pressed("attack"), "and letting go stops")
	# The stick.
	var thumb := InputEventScreenTouch.new()
	thumb.index = 0
	thumb.pressed = true
	thumb.position = touch._stick_home
	touch._input(thumb)
	var move := InputEventScreenDrag.new()
	move.index = 0
	move.position = thumb.position + Vector2(TouchControls.STICK_RADIUS, 0)
	touch._input(move)
	t.check(Input.get_action_strength("move_right") > 0.9, "pushing the stick right walks right")
	thumb.pressed = false
	touch._input(thumb)
	t.equal(Input.get_vector("move_left", "move_right", "move_up", "move_down"), Vector2.ZERO, "letting go stops")
	# Every ability has its button.
	for k in 4:
		t.check(touch._buttons.has("ability_%d" % (k + 1)), "ability %d has a button" % (k + 1))
	GameSettings.touch_controls = "off"
	touch._apply()
	t.check(not TouchControls.active, "and they can be turned off")
	mouse_attacks = false
	for event in InputMap.action_get_events("attack"):
		mouse_attacks = mouse_attacks or event is InputEventMouseButton
	t.check(mouse_attacks, "giving the mouse its attack back")
	GameSettings.touch_controls = was
	touch._apply()
	t.close_game()


func test_a_guest_keeps_their_own_world_and_takes_their_character_home(t: TestContext) -> void:
	t.check("inventory" in SaveGame.CARRIED and "leveling" in SaveGame.CARRIED and "equipment" in SaveGame.CARRIED, "what a character carries goes with them")
	t.check(not "buildings" in SaveGame.CARRIED and not "world" in SaveGame.CARRIED and not "structures" in SaveGame.CARRIED, "the world's own things stay in the world")


func test_shared_play_shows_friends_and_shares_the_hunt(t: TestContext) -> void:
	var main := await t.game()
	var player: Player = main.get_node("Player")
	var party: Party = main.get_node("Party")
	t.check(party.chat != null, "the chat box is there")
	# A friend appears where they say they are, and glides as they move.
	Net.roster[7] = {"name": "Friend", "look": {"race": "orc"}, "class": "warrior", "level": 12}
	party._on_state(7, {"p": player.global_position + Vector2(100, 0), "v": Vector2.ZERO, "fx": 1.0, "a": "idle", "hp": 50.0, "mhp": 100.0, "lv": 12})
	await t.frames(2)
	t.check(party.players.has(7), "a friend's figure stands in the world")
	var friend: RemotePlayer = party.players[7]
	t.equal(friend.level, 12, "with their level")
	t.check(absf(friend.health_share - 0.5) < 0.01, "and their health")
	for k in 6:
		party._on_state(7, {"p": player.global_position + Vector2(100 + 10 * (k + 1), 0), "v": Vector2(150, 0), "fx": 1.0, "a": "walk", "hp": 50.0, "mhp": 100.0, "lv": 12})
		await t.frames(4)
	t.check(friend.global_position.x > player.global_position.x + 110.0, "and walks smoothly after them (%s)" % friend.global_position)
	# A monster felled close by shares its experience.
	var xp_before := player.leveling.xp
	var level_before := player.leveling.level
	party._on_kill_shared(7, 100, player.global_position + Vector2(200, 0))
	t.check(player.leveling.xp > xp_before or player.leveling.level > level_before, "a share of a friend's kill nearby")
	xp_before = player.leveling.xp
	party._on_kill_shared(7, 100, player.global_position + Vector2(5000, 0))
	t.equal(player.leveling.xp, xp_before, "but not from far away")
	# Gone from the game, gone from the world.
	Net.roster.erase(7)
	party._on_roster()
	await t.frames(2)
	t.check(not party.players.has(7), "a friend who leaves disappears")
	# Typing a message does not walk.
	ChatBox.typing = true
	player.velocity = Vector2(200, 0)
	Input.action_press("move_right")
	for k in 10:
		await t.frames(1)
	Input.action_release("move_right")
	t.check(player.velocity.length() < 200.0, "typing a message stops the feet")
	ChatBox.typing = false
	t.close_game()


func test_hosting_opens_a_port_and_leaving_closes_it(t: TestContext) -> void:
	var problem := Net.host({"name": "Tester", "look": {}, "class": "warrior", "level": 1}, 24690)
	t.equal(problem, "", "hosting opens")
	t.check(Net.is_host() and Net.roster.has(1), "the host is player one")
	Net.leave("")
	t.check(not Net.online(), "and leaving ends it")
	var again := Net.host({"name": "Tester"}, 24690)
	t.equal(again, "", "the port is free again after")
	Net.leave("")
