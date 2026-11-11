class_name Buildings
extends Node2D
## Everything the player has built: crafting tables, chests, beds, houses.
##
## Each is a saved record: {"id", "kind", "where", "x", "y", "items"}.
## "where" is "world" (x, y are a world position) or "house:<id>" (x, y are
## a cell inside that house). Chests keep their contents in "items".

const KINDS := {
	"table": {"item": "crafting_table", "art": Prop.Art.TABLE, "solid": 13.0, "prompt": "Use the crafting table"},
	"chest": {"item": "storage_chest", "art": Prop.Art.CHEST, "solid": 12.0, "prompt": "Open storage"},
	"bed": {"item": "bed", "art": Prop.Art.BED, "solid": 13.0, "prompt": "Sleep here and make this home"},
	"house": {"item": "house_kit", "art": Prop.Art.HOUSE, "solid": 34.0, "prompt": "Enter your house"},
}
const CHEST_SLOTS := 24
## Inside of a house, in tiles, not counting the walls.
const HOUSE_SIZE := Vector2i(9, 6)
## Seconds between uses of the recall home.
const RECALL_COOLDOWN := 300.0

var records: Array[Dictionary] = []
## Where the player's home is: {"position": [x, y], "name"}; empty until they sleep in a bed.
var home: Dictionary = {}
var recall_left := 0.0

var _player: Player
var _instances: Instances
var _props: Dictionary = {}
var _next_id := 1
## Furniture props standing in the room the player is in.
var _room_props: Array = []


func _ready() -> void:
	SaveGame.register("buildings", self)


func setup(player: Player, instances: Instances) -> void:
	_player = player
	_instances = instances
	instances.left.connect(func() -> void: _room_props.clear())
	for record in records:
		if record["where"] == "world":
			_spawn(record)
	# A table at the Sanctuary so nobody starts stuck.
	var table := Prop.create(Prop.Art.TABLE, Vector2(-4.5, 2.5) * TerrainTiles.TILE_SIZE, 13.0, KINDS["table"]["prompt"],
		func(_p: Player) -> void: Events.screen_requested.emit("professions"))
	table.add_to_group("crafting_tables")
	add_child(table)


func _physics_process(delta: float) -> void:
	recall_left = maxf(recall_left - delta, 0.0)


## Which house the player is inside ("house:3"), or "world".
func current_place() -> String:
	if _instances.is_inside() and _instances.room.has_meta("house"):
		return "house:%d" % _instances.room.get_meta("house")
	return "world"


## Why a kind of building cannot go at a world position, or "".
func placement_problem(kind: String, at: Vector2) -> String:
	if at.distance_to(_player.global_position) > 5.0 * TerrainTiles.TILE_SIZE:
		return "Too far away"
	var place := current_place()
	if _instances.is_inside():
		if place == "world":
			return "Not here"
		if kind == "house":
			return "Not inside a house"
		if not _instances.room.is_floor(_room_cell(at)):
			return "Needs open floor"
	else:
		var world: World = get_parent().get_node("World")
		var reach := 1 if kind == "house" else 0
		for y in range(-reach, reach + 1):
			for x in range(-reach, reach + 1):
				if not world.generator.is_dry_land(world.world_to_cell(at) + Vector2i(x, y)):
					return "Needs dry, open ground"
	var gap := 90.0 if kind == "house" else 40.0
	for group: String in ["props", "npcs", "resource_nodes", "crafting_tables"]:
		for node in get_tree().get_nodes_in_group(group):
			if node.global_position.distance_to(at) < gap:
				return "Something is in the way"
	if at.distance_to(_player.global_position) < 30.0:
		return "You are standing there"
	return ""


## Sets a building down. The caller has already checked placement_problem.
func place(kind: String, at: Vector2) -> void:
	var where := current_place()
	var record := {"id": _next_id, "kind": kind, "where": where, "x": at.x, "y": at.y, "items": []}
	if where != "world":
		var cell := _room_cell(at)
		record["x"] = cell.x
		record["y"] = cell.y
	_next_id += 1
	records.append(record)
	_spawn(record)
	_player.professions.add_xp("building", 15.0 if kind != "house" else 80.0)
	SaveGame.request_save()


## Takes down the player's nearest building and hands the item back.
## Returns "" or why it could not be done.
func dismantle_nearest() -> String:
	var best: Dictionary = {}
	var best_distance := INF
	for record in records:
		var prop: Variant = _props.get(record["id"])
		if not is_instance_valid(prop):
			continue
		var distance: float = prop.global_position.distance_to(_player.global_position)
		if distance < prop.reach and distance < best_distance:
			best_distance = distance
			best = record
	if best.is_empty():
		return "Nothing of yours within reach."
	if not (best["items"] as Array).is_empty():
		return "Empty the chest first."
	if best["kind"] == "house" and not records.filter(func(r: Dictionary) -> bool: return r["where"] == "house:%d" % best["id"]).is_empty():
		return "Clear out the house first."
	if not _player.inventory.add(Item.create(KINDS[best["kind"]]["item"])):
		return "Inventory is full."
	_props[best["id"]].queue_free()
	_props.erase(best["id"])
	records.erase(best)
	SaveGame.request_save()
	return ""


## Sends the player home after a short wait, if the cooldown allows.
## Returns "" or why not.
func recall_problem() -> String:
	if home.is_empty():
		return "Sleep in a bed first to make a home."
	if recall_left > 0.0:
		return "Recall ready in %d:%02d" % [int(recall_left) / 60, int(recall_left) % 60]
	if _player.state != Player.State.MOVE or _player.swimming:
		return "You cannot recall right now."
	return ""


func recall() -> void:
	recall_left = RECALL_COOLDOWN
	var at := Vector2(home["position"][0], home["position"][1])
	RingBurst.spawn(_player.get_parent(), _player.global_position + Vector2(0, -14), Color(0.6, 0.85, 1.0), 80.0)
	if _instances.is_inside():
		_instances.leave(at)
	else:
		_player.global_position = at
		var world: World = get_parent().get_node("World")
		world.load_around_now(at)
		_player.camera.reset_smoothing()
	RingBurst.spawn(_player.get_parent(), at + Vector2(0, -14), Color(0.6, 0.85, 1.0), 80.0)
	Events.announcement.emit("HOME", "")
	SaveGame.request_save()


func save_data() -> Dictionary:
	return {"records": records.duplicate(true), "next_id": _next_id, "home": home.duplicate(true), "recall_left": recall_left}


func load_data(data: Dictionary) -> void:
	records.clear()
	_next_id = maxi(int(data.get("next_id", 1)), 1)
	recall_left = maxf(float(data.get("recall_left", 0.0)), 0.0)
	var saved_home: Variant = data.get("home", {})
	home = saved_home if saved_home is Dictionary else {}
	for saved: Variant in data.get("records", []):
		if saved is Dictionary and KINDS.has(saved.get("kind", "")):
			var record: Dictionary = saved
			record["id"] = int(record["id"])
			if not record.get("items") is Array:
				record["items"] = []
			records.append(record)
			_next_id = maxi(_next_id, record["id"] + 1)


## Builds a house's inside and takes the player in.
func enter_house(record: Dictionary) -> void:
	var house := Room.new()
	house.title = "Home"
	house.set_meta("house", record["id"])
	for y in range(-1, HOUSE_SIZE.y + 1):
		for x in range(-1, HOUSE_SIZE.x + 1):
			var wall := x < 0 or y < 0 or x >= HOUSE_SIZE.x or y >= HOUSE_SIZE.y
			house.cells[Vector2i(x, y)] = TerrainTiles.Type.WALL if wall else TerrainTiles.Type.PLANK
	house.entry = Vector2i(HOUSE_SIZE.x / 2, HOUSE_SIZE.y - 1)
	house.build((get_parent().get_node("World") as World).tile_set())
	_instances.enter(house)
	house.add_prop(Prop.create(Prop.Art.DOOR, house.cell_position(Vector2i(HOUSE_SIZE.x / 2, HOUSE_SIZE.y)) + Vector2(0, 6), 0.0, "Leave the house", func(_p: Player) -> void: _instances.leave()))
	for inside in records:
		if inside["where"] == "house:%d" % record["id"]:
			_spawn(inside)


func _room_cell(at: Vector2) -> Vector2i:
	return Vector2i(((at - Room.ORIGIN) / TerrainTiles.TILE_SIZE).floor())


## Makes the prop for a record, in the world or in the room being shown.
func _spawn(record: Dictionary) -> void:
	var kind: Dictionary = KINDS[record["kind"]]
	var in_room: bool = record["where"] != "world"
	if in_room and (not _instances.is_inside() or current_place() != record["where"]):
		return
	var at := _instances.room.cell_position(Vector2i(int(record["x"]), int(record["y"]))) if in_room else Vector2(record["x"], record["y"])
	var prop := Prop.create(kind["art"], at, kind["solid"], kind["prompt"], _use.bind(record))
	if record["kind"] == "house":
		prop.sprite().scale = Vector2(2.0, 2.0)
		prop.sprite().position.y = -50.0
		prop.reach = 110.0
	if record["kind"] == "table":
		prop.add_to_group("crafting_tables")
	_props[record["id"]] = prop
	if in_room:
		_instances.room.add_prop(prop)
		_room_props.append(prop)
	else:
		add_child(prop)


func _use(player: Player, record: Dictionary) -> void:
	if player.is_dead():
		return
	match record["kind"]:
		"table":
			Events.screen_requested.emit("professions")
		"chest":
			Events.storage_opened.emit(record)
		"house":
			enter_house(record)
		"bed":
			# Home is the bed, or the door of the house it stands in.
			var at := player.global_position
			if record["where"] != "world":
				at = _instances.return_position()
			home = {"position": [at.x, at.y], "name": "home"}
			player.health.heal_full()
			player.stamina.fill()
			player.mana.fill()
			var day_night: DayNight = get_parent().get_node("DayNight")
			if day_night.is_night():
				day_night.time = 0.3
			Events.checkpoint_set.emit(at, "home")
			Events.announcement.emit("HOME SET", "Press H to recall here")
			SaveGame.request_save()
