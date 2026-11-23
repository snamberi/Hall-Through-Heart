extends Node
## Playing together on one network (LAN): one player hosts a world of
## theirs, others on the same Wi-Fi or cable join it and walk it with
## their own characters.
##
## The host's game is the server (ENet, PORT). While hosting it calls out
## on the network every second (a small UDP beacon on BEACON_PORT) so games
## on the network show up in the Join list; an address can be typed too.
##
## What is shared: the world itself (every game grows it from the host's
## seed), the hour and the day (the host's clock), where everyone is and
## how they move, their look, level and health, chat, and a share of the
## experience for a monster felled near a friend. Each player's monsters,
## loot and buildings are still their own game's.
##
## A guest's character comes along from one of their own worlds: what they
## carry, learn and earn goes home with them (SaveGame.guest), and the
## host's world is never written to their save.

## Loaded by path, so a game whose script cache predates these still runs.
const SharedWorld := preload("res://scripts/net/net_world.gd")
const Referee := preload("res://scripts/net/world_referee.gd")

signal status_changed(text: String)
## The host took us in: `world` holds what we need to load their world.
signal welcomed
signal roster_changed
signal chat_received(from_name: String, text: String, colour: Color)
## Someone's place and pose, about fifteen times a second.
signal state_received(peer: int, state: Dictionary)
## The host's hour, now and then (and its weather: how stormy, -1 unknown).
signal clock_received(day: int, time: float, storminess: int)
## The world's authority (the host's game or a dedicated server) is asked
## to change the shared world: it checks and applies it, then broadcast_op.
signal op_requested(op: Dictionary, peer: int)
## A change to the shared world, as the authority agreed it.
signal op_applied(op: Dictionary)
## A monster felled near the player by a friend: experience to share.
signal kill_shared(peer: int, xp: int, at: Vector2)
## A friend did something worth showing (a swing, a dash, a level up).
signal deed_received(peer: int, kind: String, data: Dictionary)
signal left_game(reason: String)
## The shared world (monsters, loot, chests, gathering): a message for this
## game. `from` is the peer it came from.
signal world_msg(kind: String, data: Variant, from: int)

const PORT := 24680
const BEACON_PORT := 24681
const MAX_PLAYERS := 8
## Games only meet games of the same make.
const PROTOCOL := 1
const BEACON_TAG := "hall-through-heart"
const COLOURS: Array[Color] = [Color("e8c878"), Color("6fb6ff"), Color("8fd66a"), Color("f08a5a"), Color("c890f0"), Color("60d0c0"), Color("f0a0c0"), Color("d0d070")]

## "off", "host", "joining" or "guest".
var mode := "off"
## The host's world: seed, name, difficulty, hardcore, day, time, spawn.
var world: Dictionary = {}
## peer id -> {"name", "look", "class", "level"}; the host is 1.
var roster: Dictionary = {}
## Games seen on the network: "address:port" -> {"address", "port", "name", "world", "players", "seen"}.
var found: Dictionary = {}
## Who we are to the others (set before hosting or joining).
var me: Dictionary = {}
## The host's: a function giving the world as it is now, for a joiner
## (called with the joiner's peer id and what they said of themselves).
var world_now: Callable
## A dedicated server: hosting with no player of its own.
var dedicated := false
var max_players := MAX_PLAYERS
## Joining needs this password (its hash; "" for none).
var password_hash := ""
## The host's own extra say on who comes in: returns "" or why not.
var admit: Callable
## Whether the game is called out on the network to be found.
var listed := true

## Joiners who knocked while the host's world was still loading.
var _waiting: Dictionary = {}
var _beacon: PacketPeerUDP
var _listen: PacketPeerUDP
var _beacon_left := 0.0
var _listening := false
## Why the host is closing, told just before it does.
var _parting := ""
## Where each player is, as the world's host hears it: peer -> {"p": Vector2,
## "i": instance key ("" out in the world, else the room they are in)}.
var places: Dictionary = {}
## The world's rules, set by its host: "pvp", "interest" (how far each
## player hears of monsters and loot), and so on.
var rules: Dictionary = {}
## The world's referee (who runs which monster, who gets which drop), kept
## by the host's game or the dedicated server.
var referee: Referee

## How far a player hears of the world around them, unless the host says.
const INTEREST := 1800.0


## What this process was started as: "" (the game), or "server",
## "supervise" or "tray" for a hosted world (with boot_server its id).
static var boot_role := ""
static var boot_server := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Started to host a world in the background: go straight to that.
	for arg in OS.get_cmdline_user_args():
		for role: String in ["server", "supervise", "tray"]:
			if arg.begins_with("--hth-%s=" % role):
				boot_role = role
				boot_server = arg.get_slice("=", 1)
	if boot_role != "":
		SaveGame.enabled = false
		get_tree().change_scene_to_file.call_deferred("res://scenes/server.tscn")
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)
	multiplayer.server_disconnected.connect(_on_server_gone)


func online() -> bool:
	return mode == "host" or mode == "guest"


func is_host() -> bool:
	return mode == "host"


func is_guest() -> bool:
	return mode == "guest"


func my_id() -> int:
	return multiplayer.get_unique_id() if online() else 1


## The name a player goes by, or "Wanderer".
func name_of(peer: int) -> String:
	return str(roster.get(peer, {}).get("name", "Wanderer"))


## Each player keeps one colour for their name and chat.
func colour_of(peer: int) -> Color:
	var ids := roster.keys()
	ids.sort()
	var index := ids.find(peer)
	return COLOURS[maxi(index, 0) % COLOURS.size()]


static func describe_character(meta: Dictionary, fallback_name: String) -> Dictionary:
	var name := str(GameSettings.player_name).strip_edges()
	if name == "":
		name = fallback_name
	return {"name": name.left(20), "look": meta.get("appearance", {}), "class": str(meta.get("class", meta.get("class_id", "warrior"))), "level": int(meta.get("level", 1))}


# --- hosting

## Opens this game to the network. Returns "" or what went wrong.
func host(info: Dictionary, port: int = PORT) -> String:
	leave("")
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, MAX_PLAYERS - 1)
	if error != OK:
		return "Could not open port %d: another game may be hosting on this device." % port
	multiplayer.multiplayer_peer = peer
	mode = "host"
	dedicated = false
	max_players = MAX_PLAYERS
	me = info
	roster = {1: info}
	rules = {"pvp": bool(info.get("pvp", false)), "interest": INTEREST}
	_start_referee({})
	_open_beacon()
	roster_changed.emit()
	status_changed.emit("Hosting on port %d" % port)
	return ""


## Opens a dedicated server: a world with nobody of its own playing it.
func host_dedicated(settings: Dictionary) -> String:
	leave("")
	var port := int(settings.get("port", PORT))
	max_players = clampi(int(settings.get("max_players", MAX_PLAYERS)), 2, 20)
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, max_players)
	if error != OK:
		return "Could not open port %d: another program may be using it." % port
	multiplayer.multiplayer_peer = peer
	mode = "host"
	dedicated = true
	password_hash = str(settings.get("password_hash", ""))
	listed = str(settings.get("visibility", "lan")) == "lan"
	me = {"name": str(settings.get("name", "Server"))}
	roster = {}
	# How far each player hears of the world: the monster distance, or the
	# chunks around them, whichever is further.
	var chunk_span := float(World.CHUNK_SIZE * TerrainTiles.TILE_SIZE)
	rules = {"pvp": bool(settings.get("pvp", false)),
		"interest": maxf(float(settings.get("enemy_sim_distance", INTEREST)), float(settings.get("chunk_sim_distance", 3)) * chunk_span)}
	_start_referee(settings)
	if listed:
		_open_beacon()
	roster_changed.emit()
	return ""


## This device's addresses on the local network, for friends to type in.
func local_addresses() -> PackedStringArray:
	var out: PackedStringArray = []
	for address in IP.get_local_addresses():
		if address.count(".") == 3 and not address.begins_with("127.") and not address.begins_with("169.254."):
			out.append(address)
	return out


func _open_beacon() -> void:
	_beacon = PacketPeerUDP.new()
	_beacon.set_broadcast_enabled(true)
	_beacon.set_dest_address("255.255.255.255", BEACON_PORT)
	_beacon_left = 0.0


func _call_out() -> void:
	if _beacon == null or not is_host() or not listed:
		return
	var port := PORT
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer and (multiplayer.multiplayer_peer as ENetMultiplayerPeer).host:
		port = (multiplayer.multiplayer_peer as ENetMultiplayerPeer).host.get_local_port()
	var shout := {"tag": BEACON_TAG, "protocol": PROTOCOL, "name": str(me.get("name", "Host")), "world": str(world.get("name", "")),
		"port": port, "players": roster.size(), "most": max_players, "locked": password_hash != "", "dedicated": dedicated}
	_beacon.put_packet(JSON.stringify(shout).to_utf8_buffer())


# --- finding games

## Starts listening for games calling out on the network.
func listen() -> void:
	if _listening:
		return
	_listen = PacketPeerUDP.new()
	if _listen.bind(BEACON_PORT) != OK:
		_listen = null
		return
	_listening = true


func stop_listening() -> void:
	if _listen:
		_listen.close()
	_listen = null
	_listening = false
	found.clear()


# --- joining

## Asks to join the game at `address`. Answered by welcomed, or by
## status_changed with what went wrong.
func join(address: String, info: Dictionary, port: int = PORT) -> String:
	leave("")
	address = address.strip_edges()
	if address == "":
		return "Type the host's address (shown on their screen)."
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address, port)
	if error != OK:
		return "Could not reach %s." % address
	multiplayer.multiplayer_peer = peer
	mode = "joining"
	_parting = ""
	me = info
	status_changed.emit("Knocking on %s..." % address)
	return ""


## Leaves (or stops hosting) and goes back to playing alone.
func leave(reason: String = "") -> void:
	var was := mode
	if multiplayer.multiplayer_peer and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	if _beacon:
		_beacon.close()
	_beacon = null
	mode = "off"
	dedicated = false
	password_hash = ""
	admit = Callable()
	listed = true
	max_players = MAX_PLAYERS
	roster.clear()
	world.clear()
	_waiting.clear()
	world_now = Callable()
	places.clear()
	rules.clear()
	if referee:
		referee.queue_free()
		referee = null
	if was != "off":
		roster_changed.emit()
		left_game.emit(reason)


func _process(delta: float) -> void:
	if is_host() and _beacon:
		_beacon_left -= delta
		if _beacon_left <= 0.0:
			_beacon_left = 1.0
			_call_out()
	if _listen:
		while _listen.get_available_packet_count() > 0:
			var packet := _listen.get_packet()
			var from := _listen.get_packet_ip()
			var heard: Variant = JSON.parse_string(packet.get_string_from_utf8())
			if heard is Dictionary and heard.get("tag", "") == BEACON_TAG and int(heard.get("protocol", 0)) == PROTOCOL:
				var key := "%s:%d" % [from, int(heard.get("port", PORT))]
				found[key] = {"address": from, "port": int(heard.get("port", PORT)), "name": str(heard.get("name", "")),
					"world": str(heard.get("world", "")), "players": int(heard.get("players", 1)), "most": int(heard.get("most", MAX_PLAYERS)),
					"locked": bool(heard.get("locked", false)), "dedicated": bool(heard.get("dedicated", false)), "seen": Time.get_ticks_msec()}
		for key: String in found.keys():
			if Time.get_ticks_msec() - int(found[key]["seen"]) > 4000:
				found.erase(key)


# --- the handshake

func _on_connected() -> void:
	_hello.rpc_id(1, PROTOCOL, me)


func _on_failed() -> void:
	leave("")
	status_changed.emit("Nobody answered. Check the address, and that both are on the same network.")


func _on_server_gone() -> void:
	var reason := _parting if _parting != "" else "The host closed the game."
	_parting = ""
	leave(reason)


## Tells everyone why the game is closing, just before it does (sent at
## once, not left waiting in the queue).
func farewell(reason: String) -> void:
	if not is_host() or reason == "":
		return
	_farewell.rpc(reason)
	var peer := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if peer and peer.host:
		peer.host.flush()


@rpc("authority", "reliable")
func _farewell(reason: String) -> void:
	_parting = reason


func _on_peer_connected(_peer: int) -> void:
	pass


func _on_peer_disconnected(peer: int) -> void:
	places.erase(peer)
	if referee:
		referee.peer_left(peer)
	if not roster.has(peer):
		return
	var name := name_of(peer)
	roster.erase(peer)
	roster_changed.emit()
	chat_received.emit("", "%s left." % name, UITheme.DIM)
	if is_host():
		_gone.rpc(peer)


@rpc("any_peer", "reliable")
func _hello(protocol: int, info: Dictionary) -> void:
	if not is_host():
		return
	var peer := multiplayer.get_remote_sender_id()
	if protocol != PROTOCOL:
		_refused.rpc_id(peer, "Your game is a different version from the host's.")
		return
	if roster.size() >= max_players:
		_refused.rpc_id(peer, "The game is full.")
		return
	if password_hash != "" and str(info.get("password_hash", "")) != password_hash:
		_refused.rpc_id(peer, "Wrong password.")
		return
	var clean := {"name": str(info.get("name", "Wanderer")).left(20), "look": info.get("look", {}), "class": str(info.get("class", "")), "level": int(info.get("level", 1))}
	for other: int in roster:
		if str(roster[other].get("name", "")) == clean["name"]:
			_refused.rpc_id(peer, "Someone called %s is already in this world." % clean["name"])
			return
	if admit.is_valid():
		var problem: String = admit.call(clean)
		if problem != "":
			_refused.rpc_id(peer, problem)
			return
	if not world_now.is_valid():
		# Still loading the world: they are let in once it stands.
		_waiting[peer] = clean
		return
	_let_in(peer, clean)


func _let_in(peer: int, info: Dictionary) -> void:
	roster[peer] = info
	_welcome.rpc_id(peer, world_now.call(peer, info), roster)
	_arrived.rpc(peer, info)


## The host's world is loaded: everyone who knocked meanwhile comes in.
func world_ready(now: Callable) -> void:
	world_now = now
	for peer: int in _waiting.keys():
		if peer in multiplayer.get_peers():
			_let_in(peer, _waiting[peer])
	_waiting.clear()


@rpc("authority", "reliable")
func _refused(reason: String) -> void:
	leave("")
	status_changed.emit(reason)


@rpc("authority", "reliable")
func _welcome(host_world: Dictionary, everyone: Dictionary) -> void:
	world = host_world
	rules = host_world.get("rules", {}) if host_world.get("rules") is Dictionary else {}
	roster = everyone
	mode = "guest"
	roster_changed.emit()
	status_changed.emit("Joined %s." % str(host_world.get("host_name", name_of(1))))
	welcomed.emit()


@rpc("authority", "reliable", "call_local")
func _arrived(peer: int, info: Dictionary) -> void:
	roster[peer] = info
	roster_changed.emit()
	if peer != my_id():
		chat_received.emit("", "%s joined." % str(info.get("name", "Someone")), UITheme.GOOD)


@rpc("authority", "reliable")
func _gone(peer: int) -> void:
	_on_peer_disconnected(peer)


# --- in play

## Sends our place and pose to everyone.
func send_state(state: Dictionary) -> void:
	if online():
		_note_place(my_id(), state)
		_state.rpc(state)


@rpc("any_peer", "unreliable_ordered")
func _state(state: Dictionary) -> void:
	var peer := multiplayer.get_remote_sender_id()
	if roster.has(peer):
		if state.has("lv"):
			roster[peer]["level"] = int(state["lv"])
		_note_place(peer, state)
		state_received.emit(peer, state)


func _note_place(peer: int, state: Dictionary) -> void:
	if state.get("p") is Vector2:
		places[peer] = {"p": state["p"], "i": str(state.get("ik", "")), "dead": bool(state.get("d", false))}


func place_of(peer: int) -> Vector2:
	return places[peer]["p"] if places.has(peer) else Vector2.INF


func instance_of(peer: int) -> String:
	return str(places[peer]["i"]) if places.has(peer) else "?"


## How far `peer` hears of the world around them.
func interest_of(peer: int) -> float:
	if referee:
		return referee.radius_for(peer)
	return float(rules.get("interest", INTEREST))


## Whether `peer` stands near `at`, in the same place.
func hears(peer: int, at: Vector2, instance: String, slack: float = 1.0) -> bool:
	if not places.has(peer) or str(places[peer]["i"]) != instance:
		return false
	if referee and not referee.shares(instance):
		return false
	return (places[peer]["p"] as Vector2).distance_to(at) < interest_of(peer) * slack


# --- the shared world: monsters, loot, chests, gathering
#
# Everything goes through the host (the referee), which passes it on only
# to the players near enough to care. On the host's own game a message to
# itself is simply emitted.

func _start_referee(settings: Dictionary) -> void:
	if referee:
		referee.queue_free()
	referee = Referee.new()
	referee.name = "Referee"
	referee.configure(settings)
	add_child(referee)


## To the players near `at` (in the same place), not back to us.
func sync_near(kind: String, data: Variant, at: Vector2, instance: String, reliable: bool = true) -> void:
	if not online():
		return
	if is_host():
		deliver_near(my_id(), kind, data, at, instance, reliable)
	elif reliable:
		_up_near_r.rpc_id(1, kind, data, at, instance)
	else:
		_up_near_u.rpc_id(1, kind, data, at, instance)


## To every player in the world, not back to us.
func sync_all(kind: String, data: Variant) -> void:
	if not online():
		return
	if is_host():
		deliver_all(my_id(), kind, data)
	else:
		_up_all.rpc_id(1, kind, data)


## To one player.
func sync_to(peer: int, kind: String, data: Variant) -> void:
	if not online():
		return
	if peer == my_id():
		world_msg.emit(kind, data, peer)
	elif is_host():
		send_down(peer, kind, data, my_id(), true)
	else:
		_up_to.rpc_id(1, peer, kind, data)


## To the referee, which decides (who gets a drop, who runs a monster).
func sync_ask(kind: String, data: Variant, reliable: bool = true) -> void:
	if not online():
		return
	if is_host():
		if referee:
			referee.handle(kind, data, my_id())
	elif reliable:
		_up_ask_r.rpc_id(1, kind, data)
	else:
		_up_ask_u.rpc_id(1, kind, data)


func deliver_near(from: int, kind: String, data: Variant, at: Vector2, instance: String, reliable: bool) -> void:
	for peer: int in roster:
		if peer != from and hears(peer, at, instance):
			send_down(peer, kind, data, from, reliable)


func deliver_all(from: int, kind: String, data: Variant) -> void:
	for peer: int in roster:
		if peer != from:
			send_down(peer, kind, data, from, true)


## Hands a message to one player (the host's own game hears it at once).
func send_down(peer: int, kind: String, data: Variant, from: int, reliable: bool) -> void:
	if peer == my_id():
		world_msg.emit(kind, data, from)
	elif peer in multiplayer.get_peers():
		if reliable:
			_down_r.rpc_id(peer, kind, data, from)
		else:
			_down_u.rpc_id(peer, kind, data, from)


@rpc("any_peer", "reliable")
func _up_near_r(kind: String, data: Variant, at: Vector2, instance: String) -> void:
	if is_host():
		deliver_near(multiplayer.get_remote_sender_id(), kind, data, at, instance, true)


@rpc("any_peer", "unreliable_ordered")
func _up_near_u(kind: String, data: Variant, at: Vector2, instance: String) -> void:
	if is_host():
		deliver_near(multiplayer.get_remote_sender_id(), kind, data, at, instance, false)


@rpc("any_peer", "reliable")
func _up_all(kind: String, data: Variant) -> void:
	if is_host():
		var from := multiplayer.get_remote_sender_id()
		if referee:
			referee.heard_all(kind, data, from)
		deliver_all(from, kind, data)


@rpc("any_peer", "reliable")
func _up_to(peer: int, kind: String, data: Variant) -> void:
	if is_host() and roster.has(peer):
		send_down(peer, kind, data, multiplayer.get_remote_sender_id(), true)


@rpc("any_peer", "reliable")
func _up_ask_r(kind: String, data: Variant) -> void:
	if is_host() and referee:
		referee.handle(kind, data, multiplayer.get_remote_sender_id())


@rpc("any_peer", "unreliable_ordered")
func _up_ask_u(kind: String, data: Variant) -> void:
	if is_host() and referee:
		referee.handle(kind, data, multiplayer.get_remote_sender_id())


@rpc("authority", "reliable")
func _down_r(kind: String, data: Variant, from: int) -> void:
	world_msg.emit(kind, data, from)


@rpc("authority", "unreliable_ordered")
func _down_u(kind: String, data: Variant, from: int) -> void:
	world_msg.emit(kind, data, from)


func say(text: String) -> void:
	text = text.strip_edges().left(200)
	if text == "" or not online():
		return
	_chat.rpc(text)


@rpc("any_peer", "reliable", "call_local")
func _chat(text: String) -> void:
	var peer := multiplayer.get_remote_sender_id()
	if peer == 0:
		peer = my_id()
	chat_received.emit(name_of(peer), text.left(200), colour_of(peer))


## The host's clock and weather, for everyone else to follow.
func send_clock(day: int, time: float, storminess: int = -1) -> void:
	if is_host():
		_clock.rpc(day, time, storminess)


@rpc("authority", "unreliable")
func _clock(day: int, time: float, storminess: int) -> void:
	clock_received.emit(day, time, storminess)


# --- the shared world

## Asks for a change to the shared world (building, taking down). The
## host decides; a host's own change is decided at once.
func world_op(op: Dictionary) -> void:
	if not online():
		return
	if is_host():
		op_requested.emit(op, my_id())
	else:
		_op.rpc_id(1, op)


@rpc("any_peer", "reliable")
func _op(op: Dictionary) -> void:
	if is_host():
		op_requested.emit(op, multiplayer.get_remote_sender_id())


## The host has agreed a change: everyone makes it.
func broadcast_op(op: Dictionary) -> void:
	if is_host():
		_op_applied.rpc(op)


@rpc("authority", "reliable")
func _op_applied(op: Dictionary) -> void:
	op_applied.emit(op)


func share_kill(xp: int, at: Vector2) -> void:
	if online():
		_kill.rpc(xp, at)


@rpc("any_peer", "reliable")
func _kill(xp: int, at: Vector2) -> void:
	kill_shared.emit(multiplayer.get_remote_sender_id(), clampi(xp, 0, 1000000), at)


func send_deed(kind: String, data: Dictionary = {}) -> void:
	if online():
		_deed.rpc(kind, data)


@rpc("any_peer", "unreliable")
func _deed(kind: String, data: Dictionary) -> void:
	deed_received.emit(multiplayer.get_remote_sender_id(), kind, data)
