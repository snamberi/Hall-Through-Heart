class_name WorldReferee
extends Node
## The shared world's referee, kept by whoever hosts (the host's game, or
## the dedicated server): it does not run monsters itself, it decides.
##
## - Each monster is run by one player's game, its owner: the game of the
##   player nearest it. The owner tells the referee where it is and how it
##   fares; the referee passes that on only to the players near enough to
##   see it (and first tells them what it is). When a player leaves, the
##   monsters their game ran go to the next nearest player's game.
## - A monster that stands in a fixed place (a lair's guardian, a dungeon's
##   boss) is made by every game that loads its place; the first to say so
##   runs it, and the others' copies are turned away.
## - Every drop on the ground is one drop: the first to reach it gets it.
## - Changes to the world itself (chests, things used up, crates broken,
##   trees felled) go to everyone, and the dedicated server keeps them.
##
## Players hear of the world within the world's interest distance, which
## shrinks if together they would keep more ground active than the host
## allows. Players inside rooms (caves, dungeons) share them only while the
## number of rooms open at once is within the host's limit.

## A change to the world heard from a player: (kind, key, value).
signal fact_heard(kind: String, key: String, value: Variant)

const TICK := 0.4
## Further than the interest distance by this much before a player forgets
## a thing, so it does not flicker at the edge.
const FORGET_SLACK := 1.25
const LOOT_LIFE := 185.0

## id -> {"owner", "key", "spec", "p", "i", "s"}
var enemies: Dictionary = {}
## id -> {"data", "p", "i", "t"}
var loot: Dictionary = {}
var max_active_chunks := 400
var max_instances := 4

var _keys: Dictionary = {}
## peer -> {id: true}: what each player has been told of.
var _known: Dictionary = {}
var _left := 0.0
var _shrink := 1.0
## Rooms being shared, in the order they were opened.
var _rooms: Array[String] = []
var _active_chunks := 0


func configure(settings: Dictionary) -> void:
	max_active_chunks = clampi(int(settings.get("max_active_chunks", 400)), 50, 100000)
	max_instances = clampi(int(settings.get("max_instances", 4)), 1, 64)


func radius_for(_peer: int) -> float:
	return float(Net.rules.get("interest", Net.INTEREST)) * _shrink


## Whether players in this room see one another and its monsters.
func shares(instance: String) -> bool:
	return instance == "" or instance in _rooms


func active_chunks() -> int:
	return _active_chunks


func _tell(peer: int, kind: String, data: Variant, from: int = 1, reliable: bool = true) -> void:
	Net.send_down(peer, kind, data, from, reliable)


func _knows(peer: int, id: int) -> bool:
	return (_known.get(peer, {}) as Dictionary).has(id)


func _learn(peer: int, id: int) -> void:
	if not _known.has(peer):
		_known[peer] = {}
	_known[peer][id] = true


## Everyone who has been told of `id`, but not `except`.
func _knowers(id: int, except: int = 0) -> Array[int]:
	var out: Array[int] = []
	for peer: int in _known:
		if peer != except and (_known[peer] as Dictionary).has(id):
			out.append(peer)
	return out


func _forget_everywhere(id: int, except: int = 0) -> void:
	for peer in _knowers(id, except):
		_tell(peer, "forget", {"id": id})
	for peer: int in _known:
		(_known[peer] as Dictionary).erase(id)


## A message from a player's game for the referee.
func handle(kind: String, data: Variant, from: int) -> void:
	if not data is Dictionary:
		return
	var message: Dictionary = data
	var id := int(message.get("id", 0))
	match kind:
		"reg":
			# A monster made in a player's game: theirs to run, unless the
			# same fixed monster is already run by someone else.
			var key := str(message.get("key", ""))
			if key != "" and _keys.has(key) and enemies.has(_keys[key]) and int(enemies[_keys[key]]["owner"]) != from:
				_tell(from, "reg_no", {"id": id})
				return
			enemies[id] = {"owner": from, "key": key, "spec": message.get("spec", {}), "p": message.get("p", Vector2.ZERO),
				"i": str(message.get("i", "")), "s": []}
			if key != "":
				_keys[key] = id
			_learn(from, id)
		"es":
			_stream(message, from)
		"gone":
			if enemies.has(id) and int(enemies[id]["owner"]) == from:
				_drop_enemy(id)
				_forget_everywhere(id, from)
		"died":
			if not enemies.has(id):
				return
			for peer in _knowers(id, from):
				_tell(peer, "edie", {"id": id}, from)
			var killer := int(message.get("killer", from))
			if killer != from and Net.roster.has(killer):
				_tell(killer, "kill", {"info": message.get("info", {})}, from)
			_drop_enemy(id)
			for peer: int in _known:
				(_known[peer] as Dictionary).erase(id)
		"hit", "status", "stun", "expose":
			# A blow on someone else's monster: to its owner.
			if enemies.has(id) and int(enemies[id]["owner"]) != from:
				_tell(int(enemies[id]["owner"]), kind, message, from)
		"handover":
			var to := int(message.get("to", 0))
			if enemies.has(id) and int(enemies[id]["owner"]) == from and Net.roster.has(to):
				enemies[id]["owner"] = to
				_learn(to, id)
				_tell(to, "take", {"id": id, "full": message.get("full", {})}, from)
		"lreg":
			loot[id] = {"data": message.get("data", {}), "p": message.get("p", Vector2.ZERO), "i": str(message.get("i", "")),
				"t": Time.get_unix_time_from_system()}
			_learn(from, id)
		"ltake":
			if loot.has(id):
				loot.erase(id)
				_tell(from, "lyes", {"id": id})
				for peer in _knowers(id, from):
					_tell(peer, "lgone", {"id": id}, from)
				for peer: int in _known:
					(_known[peer] as Dictionary).erase(id)
			else:
				_tell(from, "lno", {"id": id})
		"lgone":
			if loot.has(id):
				loot.erase(id)
				_forget_everywhere(id, from)


## A change everyone is told of (passed on by Net); kept by the server.
func heard_all(kind: String, data: Variant, _from: int) -> void:
	if kind == "fact" and data is Dictionary:
		fact_heard.emit(str(data.get("k", "")), str(data.get("key", "")), data.get("v"))


## Where an owner's monsters are now: kept, and passed on to the players
## who have been told of them.
func _stream(message: Dictionary, from: int) -> void:
	var lines: Array = message.get("l", [])
	var mine: Array = []
	for line: Variant in lines:
		if not line is Array or (line as Array).size() < 3:
			continue
		var id := int(line[0])
		if not enemies.has(id) or int(enemies[id]["owner"]) != from:
			continue
		enemies[id]["p"] = Vector2(float(line[1]), float(line[2]))
		enemies[id]["s"] = line
		mine.append(line)
	if mine.is_empty():
		return
	for peer: int in Net.roster:
		if peer == from:
			continue
		var theirs: Array = []
		for line: Array in mine:
			if _knows(peer, int(line[0])):
				theirs.append(line)
		if not theirs.is_empty():
			_tell(peer, "es", {"l": theirs}, from, false)


func _drop_enemy(id: int) -> void:
	var entry: Dictionary = enemies.get(id, {})
	var key := str(entry.get("key", ""))
	if key != "" and _keys.get(key, -1) == id:
		_keys.erase(key)
	enemies.erase(id)


## A player has left: the monsters their game ran go to the nearest other
## player's game (it has been showing them already), or are let go.
func peer_left(peer: int) -> void:
	_known.erase(peer)
	for id: int in enemies.keys():
		var entry: Dictionary = enemies[id]
		if int(entry["owner"]) != peer:
			continue
		var heir := _nearest_player(entry["p"], str(entry["i"]), peer)
		if heir == 0:
			_drop_enemy(id)
			_forget_everywhere(id)
			continue
		entry["owner"] = heir
		_learn(heir, id)
		_tell(heir, "take", {"id": id, "full": {"spec": entry["spec"], "s": entry["s"]}}, peer)


func _nearest_player(at: Vector2, instance: String, except: int) -> int:
	var best := 0
	var nearest := INF
	for peer: int in Net.places:
		if peer == except or not Net.roster.has(peer) or Net.dedicated and peer == Net.my_id():
			continue
		var place: Dictionary = Net.places[peer]
		if str(place["i"]) != instance or bool(place.get("dead", false)):
			continue
		var distance := (place["p"] as Vector2).distance_to(at)
		if distance < nearest and distance < radius_for(peer):
			nearest = distance
			best = peer
	return best


func _process(delta: float) -> void:
	_left -= delta
	if _left > 0.0:
		return
	_left = TICK
	_measure()
	var now := Time.get_unix_time_from_system()
	for id: int in loot.keys():
		if now - float(loot[id]["t"]) > LOOT_LIFE:
			loot.erase(id)
			_forget_everywhere(id)
	for peer: int in Net.roster:
		if Net.dedicated and peer == Net.my_id():
			continue
		_update_interest(peer)


## What each player should know of: told of monsters and drops coming near,
## told to forget those gone far.
func _update_interest(peer: int) -> void:
	if not Net.places.has(peer):
		return
	var place: Dictionary = Net.places[peer]
	var at: Vector2 = place["p"]
	var instance := str(place["i"])
	var radius := radius_for(peer)
	var sharing := shares(instance)
	var known: Dictionary = _known.get(peer, {})
	for id: int in enemies:
		var entry: Dictionary = enemies[id]
		if int(entry["owner"]) == peer:
			continue
		var near := sharing and str(entry["i"]) == instance and (entry["p"] as Vector2).distance_to(at) < radius
		if near and not known.has(id):
			_learn(peer, id)
			_tell(peer, "espec", {"id": id, "spec": entry["spec"], "s": entry["s"], "owner": entry["owner"]})
		elif known.has(id) and (not sharing or str(entry["i"]) != instance or (entry["p"] as Vector2).distance_to(at) > radius * FORGET_SLACK):
			known.erase(id)
			_tell(peer, "forget", {"id": id})
	for id: int in loot:
		var drop: Dictionary = loot[id]
		var near := sharing and str(drop["i"]) == instance and (drop["p"] as Vector2).distance_to(at) < radius
		if near and not known.has(id):
			_learn(peer, id)
			_tell(peer, "lspec", {"id": id, "data": drop["data"], "p": drop["p"]})
		elif known.has(id) and (not sharing or (drop["p"] as Vector2).distance_to(at) > radius * FORGET_SLACK):
			known.erase(id)
			_tell(peer, "forget", {"id": id})


## How much ground the players keep active together; if more than the host
## allows, everyone's distance shrinks. Rooms beyond the limit are not
## shared (they are played alone).
func _measure() -> void:
	var span := float(World.CHUNK_SIZE * TerrainTiles.TILE_SIZE)
	var base := float(Net.rules.get("interest", Net.INTEREST))
	var reach := ceili(base / span)
	var chunks := {}
	var open_rooms := {}
	for peer: int in Net.places:
		if Net.dedicated and peer == Net.my_id():
			continue
		var place: Dictionary = Net.places[peer]
		var instance := str(place["i"])
		if instance != "":
			open_rooms[instance] = true
			continue
		var center := Vector2i(((place["p"] as Vector2) / span).floor())
		for dx in range(-reach, reach + 1):
			for dy in range(-reach, reach + 1):
				if Vector2(dx, dy).length() * span <= base + span:
					chunks[center + Vector2i(dx, dy)] = true
	_active_chunks = chunks.size()
	_shrink = 1.0 if _active_chunks <= max_active_chunks else clampf(sqrt(float(max_active_chunks) / float(_active_chunks)), 0.35, 1.0)
	# Rooms closed are let go; new ones are shared while there is room.
	_rooms = _rooms.filter(func(room: String) -> bool: return open_rooms.has(room))
	for room: String in open_rooms:
		if not room in _rooms and _rooms.size() < max_instances:
			_rooms.append(room)
