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

signal status_changed(text: String)
## The host took us in: `world` holds what we need to load their world.
signal welcomed
signal roster_changed
signal chat_received(from_name: String, text: String, colour: Color)
## Someone's place and pose, about fifteen times a second.
signal state_received(peer: int, state: Dictionary)
## The host's hour, now and then.
signal clock_received(day: int, time: float)
## A monster felled near the player by a friend: experience to share.
signal kill_shared(peer: int, xp: int, at: Vector2)
## A friend did something worth showing (a swing, a dash, a level up).
signal deed_received(peer: int, kind: String, data: Dictionary)
signal left_game(reason: String)

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
## The host's: a function giving the world as it is now, for a joiner.
var world_now: Callable

## Joiners who knocked while the host's world was still loading.
var _waiting: Dictionary = {}
var _beacon: PacketPeerUDP
var _listen: PacketPeerUDP
var _beacon_left := 0.0
var _listening := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	me = info
	roster = {1: info}
	_open_beacon()
	roster_changed.emit()
	status_changed.emit("Hosting on port %d" % port)
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
	if _beacon == null or not is_host():
		return
	var shout := {"tag": BEACON_TAG, "protocol": PROTOCOL, "name": str(me.get("name", "Host")), "world": str(world.get("name", "")),
		"port": PORT, "players": roster.size(), "most": MAX_PLAYERS}
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
	roster.clear()
	world.clear()
	_waiting.clear()
	world_now = Callable()
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
					"seen": Time.get_ticks_msec()}
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
	leave("The host closed the game.")


func _on_peer_connected(_peer: int) -> void:
	pass


func _on_peer_disconnected(peer: int) -> void:
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
	if roster.size() >= MAX_PLAYERS:
		_refused.rpc_id(peer, "The game is full.")
		return
	var clean := {"name": str(info.get("name", "Wanderer")).left(20), "look": info.get("look", {}), "class": str(info.get("class", "")), "level": int(info.get("level", 1))}
	if not world_now.is_valid():
		# Still loading the world: they are let in once it stands.
		_waiting[peer] = clean
		return
	_let_in(peer, clean)


func _let_in(peer: int, info: Dictionary) -> void:
	roster[peer] = info
	_welcome.rpc_id(peer, world_now.call(), roster)
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
	roster = everyone
	mode = "guest"
	roster_changed.emit()
	status_changed.emit("Joined %s." % name_of(1))
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
		_state.rpc(state)


@rpc("any_peer", "unreliable_ordered")
func _state(state: Dictionary) -> void:
	var peer := multiplayer.get_remote_sender_id()
	if roster.has(peer):
		if state.has("lv"):
			roster[peer]["level"] = int(state["lv"])
		state_received.emit(peer, state)


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


## The host's clock, for everyone else to follow.
func send_clock(day: int, time: float) -> void:
	if is_host():
		_clock.rpc(day, time)


@rpc("authority", "unreliable")
func _clock(day: int, time: float) -> void:
	clock_received.emit(day, time)


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
