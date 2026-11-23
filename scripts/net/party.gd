class_name Party
extends Node
## The shared game, inside the world: sends where this player is and what
## they are doing, shows everyone else (RemotePlayer), keeps the host's
## hour, shares experience for monsters felled near friends, carries the
## chat, and sees a guest home when the host leaves.

## How often this player's place goes out.
const SEND_EVERY := 1.0 / 15.0
const CLOCK_EVERY := 2.0
## Felled within this of a friend, they share in it.
const SHARE_RANGE := 900.0
const SHARE := 0.3

var players: Dictionary = {}
var chat: ChatBox

var _player: Player
var _day_night: DayNight
var _instances: Instances
var _send_left := 0.0
var _clock_left := 0.0
## What this player wears, as last told; checked now and then.
var _gear_told := ""
var _gear_left := 1.0
## Gear heard before the figure was made.
var _gear_heard: Dictionary = {}
var _world_name := ""


func setup(player: Player, day_night: DayNight, instances: Instances) -> void:
	_player = player
	_day_night = day_night
	_instances = instances
	_world_name = str(SaveGame.get_section("meta").get("name", "a world"))


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	chat = ChatBox.new()
	chat.name = "Chat"
	add_child(chat)
	Net.state_received.connect(_on_state)
	Net.roster_changed.connect(_on_roster)
	Net.clock_received.connect(_on_clock)
	Net.kill_shared.connect(_on_kill_shared)
	Net.op_requested.connect(_on_op_requested)
	Net.op_applied.connect(_on_op_applied)
	Events.player_died.connect(func(_xp: int) -> void: Net.send_deed("died"))
	Net.deed_received.connect(_on_deed)
	Net.left_game.connect(_on_left)
	Net.world_msg.connect(_on_world_msg)
	Events.enemy_killed.connect(_on_local_kill)
	Events.level_up.connect(func(level: int) -> void: Net.send_deed("level", {"lv": level}))
	if Net.is_host():
		Net.world["name"] = _world_name
		Net.world_ready(world_now)
	if Net.online():
		chat.add_line("", _welcome_line(), UITheme.DIM)


func _exit_tree() -> void:
	# Leaving the world leaves the shared game too.
	if Net.online():
		Net.leave("")


func _welcome_line() -> String:
	if Net.is_host():
		var where := ", ".join(Net.local_addresses())
		return "Hosting %s. Friends on this network can join from Multiplayer%s. Enter to chat." % [_world_name, (" (address: %s)" % where) if where != "" else ""]
	if Net.world.get("dedicated", false):
		return "You are on %s, in the world %s. What you carry and learn goes home with you. Enter to chat." % [Net.world.get("host_name", "a server"), Net.world.get("name", "")]
	return "You are in %s's world. What you carry and learn goes home with you. Enter to chat." % Net.name_of(1)


## What a joining player needs to walk this world: told by the host. What
## is built in it comes too, so everyone sees the same houses and walls.
func world_now(_peer: int = 0, _info: Dictionary = {}) -> Dictionary:
	var meta := SaveGame.get_section("meta")
	var built: Dictionary = _buildings().save_data() if _buildings() else {}
	built.erase("home")
	built.erase("recall_left")
	var sections := {"buildings": built}
	# The world as it stands: chests, things used up, what was gathered.
	if NetWorld.current:
		sections.merge(NetWorld.current.world_sections())
	return {"seed": _seed(), "name": _world_name, "difficulty": Difficulty.current, "hardcore": false,
		"day": _day_night.day, "time": _day_night.time, "storminess": Atmosphere._storminess,
		"spawn": _player.global_position if not _instances.is_inside() else _instances.return_position(),
		"meta_name": str(meta.get("name", "")), "host_name": Net.name_of(1), "sections": sections, "rules": Net.rules}


func _buildings() -> Buildings:
	return get_parent().get_node_or_null("Buildings") as Buildings


## The host's game decides on a change to the shared world: something built
## or taken down. Checked, made here, and then made everywhere.
func _on_op_requested(op: Dictionary, peer: int) -> void:
	var buildings := _buildings()
	if buildings == null:
		return
	var record: Dictionary = op.get("record", {})
	if not str(op.get("op", "")) in ["build", "unbuild"] or record.is_empty():
		return
	if op["op"] == "build" and not Buildings.KINDS.has(str(record.get("kind", ""))):
		return
	if peer != Net.my_id():
		buildings.apply_remote(op)
	Net.broadcast_op(op)


func _on_op_applied(op: Dictionary) -> void:
	if _buildings():
		_buildings().apply_remote(op)


func _seed() -> int:
	var main := get_parent()
	return int(main.get("_active_seed")) if main and main.get("_active_seed") != null else 0


func _process(delta: float) -> void:
	if not Net.online() or _player == null or not is_instance_valid(_player):
		return
	_send_left -= delta
	if _send_left <= 0.0:
		_send_left = SEND_EVERY
		var sprite := _player.get_node_or_null("Visual/Sprite") as AnimatedSprite2D
		Net.send_state({
			"p": _player.global_position, "v": _player.velocity, "fx": _player.facing.x,
			"a": sprite.animation if sprite else "idle",
			"hp": _player.health.current, "mhp": _player.health.max_health,
			"lv": _player.leveling.level, "d": _player.is_dead(), "in": _instances.is_inside(),
			"ik": NetWorld.current.instance_key() if NetWorld.current else "",
		})
	if Net.is_host():
		_clock_left -= delta
		if _clock_left <= 0.0:
			_clock_left = CLOCK_EVERY
			Net.send_clock(_day_night.day, _day_night.time, Atmosphere._storminess)
	_gear_left -= delta
	if _gear_left <= 0.0:
		_gear_left = 1.0
		_tell_gear(false)
	var here := NetWorld.current.instance_key() if NetWorld.current else ""
	for peer in players:
		(players[peer] as RemotePlayer).local_place = here


func _on_state(peer: int, state: Dictionary) -> void:
	if not players.has(peer):
		if not Net.roster.has(peer):
			return
		var figure := RemotePlayer.new()
		figure.name = "Remote%d" % peer
		figure.setup(peer, Net.roster[peer])
		figure.z_index = _player.z_index
		_player.get_parent().add_child(figure)
		figure.global_position = state.get("p", _player.global_position)
		players[peer] = figure
		if _gear_heard.has(peer):
			figure.wear(_gear_heard[peer])
		# The first we see of them is the first they can see of us: what we
		# told on their joining may have come while their world was loading.
		var animator := _player.get_node_or_null("Visual/Sprite") as PlayerAnimator
		if animator:
			Net.sync_to(peer, "gear", {"w": animator.worn()})
	(players[peer] as RemotePlayer).hear(state)


## Tells everyone what this player wears when it changes (or someone new
## arrives and has not seen it).
func _tell_gear(again: bool) -> void:
	var animator := _player.get_node_or_null("Visual/Sprite") as PlayerAnimator
	if animator == null:
		return
	var gear := animator.worn()
	var said := var_to_str(gear)
	if said != _gear_told or again:
		_gear_told = said
		Net.sync_all("gear", {"w": gear})


func _on_world_msg(kind: String, data: Variant, from: int) -> void:
	if kind != "gear" or not data is Dictionary:
		return
	var gear: Array = data.get("w", []) if data.get("w") is Array else []
	_gear_heard[from] = gear
	if players.has(from):
		(players[from] as RemotePlayer).wear(gear)


func _on_roster() -> void:
	# Someone new: they have not seen what this player wears.
	if Net.online():
		_tell_gear.call_deferred(true)
	for peer: int in players.keys():
		if not Net.roster.has(peer):
			(players[peer] as Node).queue_free()
			players.erase(peer)


func _on_clock(day: int, time: float, storminess: int = -1) -> void:
	if Net.is_host():
		return
	# The host's weather: the same storms for everyone.
	if storminess >= 0:
		Atmosphere._storminess = storminess
		var atmosphere := get_parent().get_node_or_null("Atmosphere")
		if atmosphere:
			atmosphere.set("_front_left", 9999.0)
	_day_night.day = day
	# Follow the host's hour, smoothly unless it is far off.
	var gap := time - _day_night.time
	if absf(gap) > 0.02:
		_day_night.time = time
	else:
		_day_night.time += gap * 0.5


func _on_local_kill(info: Dictionary) -> void:
	Net.share_kill(int(info.get("xp", 0)), info.get("position", _player.global_position))


func _on_kill_shared(peer: int, xp: int, at: Vector2) -> void:
	if _player.is_dead() or _instances.is_inside() or _player.global_position.distance_to(at) > SHARE_RANGE:
		return
	var share := maxi(1, int(xp * SHARE))
	_player.leveling.add_xp(share, "party")
	DamageNumber.spawn_text(_player.get_parent(), _player.global_position + Vector2(0, -58), "+%d XP  (%s)" % [share, Net.name_of(peer)], Color(0.45, 0.7, 1.0), 12)


func _on_deed(peer: int, kind: String, data: Dictionary) -> void:
	match kind:
		"level":
			chat.add_line("", "%s reached level %d." % [Net.name_of(peer), int(data.get("lv", 1))], UITheme.GOLD)


func _on_left(reason: String) -> void:
	for peer in players:
		(players[peer] as Node).queue_free()
	players.clear()
	if reason == "":
		return
	chat.add_line("", reason, UITheme.BAD)
	if SaveGame.guest:
		# The world was theirs: take the character home.
		Events.announcement.emit("The server has stopped" if reason.begins_with("The server") else "The host has gone", "Taking your character home.")
		SaveGame.save_now()
		await get_tree().create_timer(2.5, true, false, true).timeout
		SaveGame.guest = false
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
