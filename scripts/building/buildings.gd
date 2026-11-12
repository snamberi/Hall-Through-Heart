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
	"torch": {"item": "torch", "decor": Prop.Decor.LANTERN, "solid": 0.0, "prompt": "", "light": true},
	"rug": {"item": "rug", "decor": Prop.Decor.RUG, "solid": 0.0, "flat": true},
	"bookshelf": {"item": "bookshelf", "decor": Prop.Decor.SHELF, "solid": 12.0},
	"potted_plant": {"item": "potted_plant", "decor": Prop.Decor.PLANT_POT, "solid": 8.0},
	"dining_table": {"item": "dining_table", "decor": Prop.Decor.TABLE, "solid": 14.0},
	"chair": {"item": "chair", "decor": Prop.Decor.CHAIR, "solid": 0.0},
	"candles": {"item": "candles", "decor": Prop.Decor.CANDLES, "solid": 0.0, "light": true},
	"wall_banner": {"item": "wall_banner", "decor": Prop.Decor.BANNER, "solid": 6.0},
	"barrel": {"item": "barrel", "decor": Prop.Decor.BARREL, "solid": 10.0},
	"crate": {"item": "crate", "decor": Prop.Decor.CRATE, "solid": 10.0},
	"stone_statue": {"item": "stone_statue", "decor": Prop.Decor.STATUE, "solid": 14.0},
	"brazier": {"item": "brazier", "decor": Prop.Decor.BRAZIER, "solid": 10.0, "light": true},
	"fence": {"item": "fence", "decor": Prop.Decor.FENCE, "solid": 12.0},
	"lantern_post": {"item": "lantern_post", "decor": Prop.Decor.LANTERN, "solid": 6.0, "light": true},
	"plot": {"item": "farm_plot", "decor": Prop.Decor.SOIL, "solid": 0.0, "flat": true, "outdoors": true},
	"scarecrow": {"item": "scarecrow", "decor": Prop.Decor.SCARECROW, "solid": 6.0, "outdoors": true},
	"palisade": {"item": "palisade_wall", "decor": Prop.Decor.PALISADE, "solid": 24.0, "outdoors": true},
	"spikes": {"item": "spike_trap", "decor": Prop.Decor.SPIKE_TRAP, "solid": 0.0, "flat": true, "outdoors": true},
	"ballista": {"item": "ballista", "decor": Prop.Decor.BALLISTA, "solid": 14.0, "outdoors": true},
	## One tile of floor inside a house; the record keeps the item and tile.
	"floor": {"item": "", "solid": 0.0, "flat": true},
	## One tile of laid ground outdoors (path, decking, turf, pond...); the
	## record keeps the item and the terrain it lays.
	"ground": {"item": "", "solid": 0.0, "flat": true, "outdoors": true},
	## One tile of wall outdoors, joined to the walls beside it; the record
	## keeps the item and its style.
	"wall": {"item": "", "solid": 0.0, "outdoors": true},
}
## Inside of a house by tier, in tiles, not counting the walls.
const HOUSE_SIZES := {1: Vector2i(9, 6), 2: Vector2i(13, 8), 3: Vector2i(17, 11)}
const MAX_TIER := 3
## What it takes to raise a house to each tier.
const UPGRADE_COSTS := {
	2: {"oak_wood": 40, "stone": 40, "iron_ingot": 6},
	3: {"oak_wood": 80, "stone": 80, "silver_ingot": 8},
}
## How big the house looks from outside at each tier.
const HOUSE_SCALE := {1: 2.0, 2: 2.35, 3: 2.7}
const CHEST_SLOTS := 24
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
## Outdoor walls: cell -> the StoneWall piece drawn there.
var _wall_nodes: Dictionary = {}


func _ready() -> void:
	SaveGame.register("buildings", self)


func setup(player: Player, instances: Instances) -> void:
	_player = player
	_instances = instances
	instances.left.connect(func() -> void: _room_props.clear())
	var laid: Array = []
	for record in records:
		if record["kind"] == "ground":
			_world().generator.overrides[Vector2i(int(record["x"]), int(record["y"]))] = int(record["tile"])
			laid.append(Vector2i(int(record["x"]), int(record["y"])))
	if not laid.is_empty():
		_world().refresh_cells(laid)
	for record in records:
		if record["where"] == "world":
			_spawn(record)


var _tick_left := 0.0
var _ballista_left: Dictionary = {}


func _physics_process(delta: float) -> void:
	recall_left = maxf(recall_left - delta, 0.0)
	_tick_left -= delta
	if _tick_left > 0.0:
		return
	_tick_left = 0.5
	_grow_crops(0.5)
	_defend(0.5)


## Crops grow wherever they are, watered or not, faster near a scarecrow.
func _grow_crops(seconds: float) -> void:
	var raining := Atmosphere.weather in ["Rain", "Thunderstorm"]
	var scarecrows: Array = records.filter(func(r: Dictionary) -> bool: return r["kind"] == "scarecrow")
	for record in records:
		if record["kind"] != "plot" or record.get("crop", "") == "":
			continue
		if raining:
			record["watered"] = true
		var rate := 1.0 / float(Crops.CROPS[record["crop"]]["days"])
		if record.get("watered", false):
			rate *= Crops.WATERED
		var at := Vector2(record["x"], record["y"])
		if scarecrows.any(func(r: Dictionary) -> bool: return Vector2(r["x"], r["y"]).distance_to(at) < Crops.SCARECROW_REACH):
			rate *= Crops.SCARECROW
		record["growth"] = minf(float(record.get("growth", 0.0)) + seconds / DayNight.DAY_SECONDS * rate, 1.0)
		var prop: Variant = _props.get(record["id"])
		if is_instance_valid(prop):
			prop.prompt_text = _plot_prompt(record)


## Spike traps hurt monsters that cross them; ballistas shoot what comes near.
func _defend(seconds: float) -> void:
	var power := 8.0 + _player.leveling.level * 2.5
	for record in records:
		if record["where"] != "world" or not record["kind"] in ["spikes", "ballista"]:
			continue
		var at := Vector2(record["x"], record["y"])
		if at.distance_to(_player.global_position) > 1400.0:
			continue
		if record["kind"] == "spikes":
			for node in get_tree().get_nodes_in_group("enemies"):
				var enemy := node as Enemy
				if enemy and not enemy.has_trait("flying") and not EnemyDB.ENEMIES[enemy.enemy_id].get("flying", false) and enemy.global_position.distance_to(at) < 30.0:
					enemy.take_damage(power * 0.6, Vector2.ZERO)
					enemy.apply_status("bleed", 3.0, power * 0.1)
			continue
		var left: float = _ballista_left.get(record["id"], 0.0) - seconds
		_ballista_left[record["id"]] = left
		if left > 0.0:
			continue
		var target: Enemy = null
		var best := 340.0
		for node in get_tree().get_nodes_in_group("enemies"):
			var enemy := node as Enemy
			if enemy and not enemy.health.is_dead() and enemy.global_position.distance_to(at) < best:
				best = enemy.global_position.distance_to(at)
				target = enemy
		if target:
			_ballista_left[record["id"]] = 1.5
			Uniques._bolt(_player, at + Vector2(0, -20), target.global_position, Color(0.85, 0.75, 0.55))
			target.take_damage(power * 1.4, (target.global_position - at).normalized() * 200.0)


func _plot_prompt(record: Dictionary) -> String:
	var crop: String = record.get("crop", "")
	if crop == "":
		return "Sow seeds in the plot"
	var name: String = Crops.CROPS[crop]["name"]
	var growth: float = record.get("growth", 0.0)
	if growth >= 1.0:
		return "Harvest the %s" % name.to_lower()
	if not record.get("watered", false):
		return "Water the %s  (%d%% grown)" % [name.to_lower(), roundi(growth * 100.0)]
	return "%s growing  (%d%%)" % [name, roundi(growth * 100.0)]


## Sows, waters, or harvests a plot.
func tend_plot(player: Player, record: Dictionary, seed_id: String = "") -> String:
	var crop: String = record.get("crop", "")
	if crop == "":
		if seed_id == "":
			for item in player.inventory.items:
				if item and Crops.by_seed(item.id) != "":
					seed_id = item.id
					break
		if seed_id == "":
			return "You have no seeds."
		player.inventory.take(seed_id, 1)
		record["crop"] = Crops.by_seed(seed_id)
		record["growth"] = 0.0
		record["watered"] = false
		player.professions.add_xp("cooking", 3.0)
	elif float(record.get("growth", 0.0)) >= 1.0:
		var data: Dictionary = Crops.CROPS[crop]
		var count := randi_range(data["yield"][0], data["yield"][1])
		player.inventory.add(Item.create(data["item"], count))
		if randf() < 0.6:
			player.inventory.add(Item.create(data["seed"], randi_range(1, 2)))
		DamageNumber.spawn_text(get_parent(), player.global_position + Vector2(0, -36), "%s x%d" % [ItemDB.ITEMS[data["item"]]["name"], count], Color(0.9, 0.85, 0.5), 13)
		record["crop"] = ""
		record["growth"] = 0.0
		player.professions.add_xp("cooking", 12.0 * data["days"])
		Events.codex_event.emit("harvests", 1)
		Events.codex_event.emit("harvest_" + crop, 1)
	elif not record.get("watered", false):
		record["watered"] = true
		Events.splash.emit(Vector2(record["x"], record["y"]))
	else:
		return "It is growing. Come back later."
	var prop: Variant = _props.get(record["id"])
	if is_instance_valid(prop):
		prop.prompt_text = _plot_prompt(record)
	SaveGame.request_save()
	return ""


## A new day: the ground dries out.
func dry_plots() -> void:
	for record in records:
		if record["kind"] == "plot":
			record["watered"] = false


## Which house the player is inside ("house:3"), or "world".
func current_place() -> String:
	if _instances.is_inside() and _instances.room.has_meta("house"):
		return "house:%d" % _instances.room.get_meta("house")
	return "world"


func _world() -> World:
	return get_parent().get_node("World")


## The outdoor wall or laid ground record on a cell, if any.
func _cell_record(kind: String, cell: Vector2i) -> Dictionary:
	for record in records:
		if record["kind"] == kind and record["where"] == "world" and int(record["x"]) == cell.x and int(record["y"]) == cell.y:
			return record
	return {}


## Why a kind of building cannot go at a world position, or "".
func placement_problem(kind: String, at: Vector2) -> String:
	if kind in ["ground", "wall"]:
		if _instances.is_inside():
			return "This belongs outdoors"
		if at.distance_to(_player.global_position) > 6.0 * TerrainTiles.TILE_SIZE:
			return "Too far away"
		var cell := _world().world_to_cell(at)
		var type := _world().generator.tile_type_at(cell)
		if TerrainTiles.is_solid(type) or type == TerrainTiles.Type.DEEP_WATER or type in TerrainTiles.HIGH:
			return "Not on this ground"
		if Vector2(cell).length() < 6.0:
			return "Not on the temple's ground"
		if kind == "wall":
			if not _cell_record("wall", cell).is_empty():
				return "There is a wall here already"
			if TerrainTiles.is_water(type):
				return "Not in water"
			if at.distance_to(_player.global_position) < 30.0:
				return "You are standing there"
		return ""
	if at.distance_to(_player.global_position) > 5.0 * TerrainTiles.TILE_SIZE:
		return "Too far away"
	var place := current_place()
	if _instances.is_inside():
		if place == "world":
			return "Not here"
		if kind == "house" or KINDS[kind].get("outdoors", false):
			return "This belongs outdoors"
		if not _instances.room.is_floor(_room_cell(at)):
			return "Needs open floor"
		if kind == "floor":
			return "" if at.distance_to(_player.global_position) <= 5.0 * TerrainTiles.TILE_SIZE else "Too far away"
	elif kind == "floor":
		return "Floors go inside a house"
	else:
		var world: World = get_parent().get_node("World")
		var reach := 1 if kind == "house" else 0
		for y in range(-reach, reach + 1):
			for x in range(-reach, reach + 1):
				if not world.generator.is_dry_land(world.world_to_cell(at) + Vector2i(x, y)):
					return "Needs dry, open ground"
	var gap := 90.0 if kind == "house" else 30.0 if _instances.is_inside() else 40.0
	if not KINDS[kind].get("flat", false):
		for group: String in ["props", "npcs", "resource_nodes", "crafting_tables"]:
			for node in get_tree().get_nodes_in_group(group):
				if node.global_position.distance_to(at) < gap and not (node is Prop and node.get_meta("flat", false)):
					return "Something is in the way"
	if at.distance_to(_player.global_position) < 30.0 and KINDS[kind]["solid"] > 0.0:
		return "You are standing there"
	return ""


## Sets a building down. The caller has already checked placement_problem.
## `flip` mirrors it left to right.
func place(kind: String, at: Vector2, item_id: String = "", flip: bool = false) -> void:
	var where := current_place()
	var record := {"id": _next_id, "kind": kind, "where": where, "x": at.x, "y": at.y, "items": []}
	if flip:
		record["flip"] = true
	if kind in ["ground", "wall"]:
		_place_tile(kind, _world().world_to_cell(at), item_id)
		return
	if kind == "house":
		record["tier"] = 1
	if kind == "floor":
		var cell := _room_cell(at)
		# A new floor replaces the one already there, and hands it back.
		for old in records.duplicate():
			if old["kind"] == "floor" and old["where"] == where and int(old["x"]) == cell.x and int(old["y"]) == cell.y:
				records.erase(old)
				_player.inventory.add(Item.create(old["item"]))
		record["item"] = item_id
		record["tile"] = ItemDB.ITEMS[item_id]["floor"]
		record["x"] = cell.x
		record["y"] = cell.y
		_next_id += 1
		records.append(record)
		_instances.room.set_tile(cell, record["tile"])
		_player.professions.add_xp("building", 2.0)
		SaveGame.request_save()
		return
	if where != "world":
		var cell := _room_cell(at)
		record["x"] = cell.x
		record["y"] = cell.y
	_next_id += 1
	records.append(record)
	_spawn(record)
	_player.professions.add_xp("building", 15.0 if kind != "house" else 80.0)
	if kind == "house":
		Events.codex_event.emit("houses", 1)
	SaveGame.request_save()


## Lays ground or raises a wall on one outdoor cell.
func _place_tile(kind: String, cell: Vector2i, item_id: String) -> void:
	var record := {"id": _next_id, "kind": kind, "where": "world", "x": cell.x, "y": cell.y, "items": [], "item": item_id}
	_next_id += 1
	if kind == "ground":
		# New ground replaces what was laid there, and hands it back.
		var old := _cell_record("ground", cell)
		if not old.is_empty():
			records.erase(old)
			_player.inventory.add(Item.create(old["item"]))
		record["tile"] = int(ItemDB.ITEMS[item_id]["ground"])
		records.append(record)
		_world().generator.overrides[cell] = record["tile"]
		_world().refresh_cells([cell])
		_player.professions.add_xp("building", 2.0)
	else:
		record["style"] = str(ItemDB.ITEMS[item_id]["wall"])
		records.append(record)
		_rebuild_walls(cell)
		_player.professions.add_xp("building", 4.0)
	Events.codex_event.emit("built_tiles", 1)
	SaveGame.request_save()


## Redraws the outdoor wall pieces on and around a cell, each joined to
## the walls beside it.
func _rebuild_walls(cell: Vector2i) -> void:
	for offset: Vector2i in [Vector2i.ZERO, Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var here: Vector2i = cell + offset
		if is_instance_valid(_wall_nodes.get(here)):
			(_wall_nodes[here] as Node).queue_free()
		_wall_nodes.erase(here)
		var record := _cell_record("wall", here)
		if record.is_empty():
			continue
		var piece := StoneWall.new()
		piece.style = str(record.get("style", "wood"))
		piece.north = not _cell_record("wall", here + Vector2i.UP).is_empty()
		piece.south = not _cell_record("wall", here + Vector2i.DOWN).is_empty()
		piece.east = not _cell_record("wall", here + Vector2i.RIGHT).is_empty()
		piece.west = not _cell_record("wall", here + Vector2i.LEFT).is_empty()
		piece.variation = absi(hash(here * 31 + Vector2i(7, 3)))
		piece.position = _world().cell_to_world(here) + Vector2(0, StoneWall.THICK / 2.0)
		add_child(piece)
		_wall_nodes[here] = piece


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
	return take_down(best)


## The placed thing under a point (the mouse), if the player standing at
## `from` can reach it. {} if there is none.
func record_at(point: Vector2, from: Vector2) -> Dictionary:
	# Walls and laid ground: whatever is on the tile under the point.
	if not _instances.is_inside() and point.distance_to(from) < 4.0 * TerrainTiles.TILE_SIZE:
		var cell := _world().world_to_cell(point)
		var wall := _cell_record("wall", cell)
		if wall.is_empty():
			wall = _cell_record("wall", _world().world_to_cell(point + Vector2(0, 18)))
		if not wall.is_empty():
			return wall
	var best: Dictionary = {}
	var best_distance := 34.0
	for record in records:
		var prop: Variant = _props.get(record["id"])
		if not is_instance_valid(prop):
			continue
		var here: Vector2 = prop.global_position
		if here.distance_to(from) > maxf(prop.reach, 80.0):
			continue
		# Houses and other big things can be pointed at anywhere on them.
		var size := 60.0 if record["kind"] == "house" else 30.0
		var distance := minf(here.distance_to(point), (here + Vector2(0, -24)).distance_to(point))
		if distance < maxf(best_distance, size) and (best.is_empty() or distance < best_distance):
			best_distance = distance
			best = record
	return best


## Why something placed cannot be taken down now, or "".
func take_down_problem(record: Dictionary) -> String:
	if not (record["items"] as Array).is_empty():
		return "Empty the chest first."
	if record["kind"] == "house" and not records.filter(func(r: Dictionary) -> bool: return r["where"] == "house:%d" % record["id"] and r["kind"] != "floor").is_empty():
		return "Clear out the house first."
	if not _player.inventory.has_room_for(Item.create(_item_of(record))):
		return "Inventory is full."
	return ""


## The item a placed thing came from (walls and ground keep their own).
func _item_of(record: Dictionary) -> String:
	return str(record.get("item", "")) if record.has("item") and str(record.get("item", "")) != "" else KINDS[record["kind"]]["item"]


## Takes up the laid ground on a cell (the land returns to what it was).
func take_up_ground(cell: Vector2i) -> String:
	var record := _cell_record("ground", cell)
	if record.is_empty():
		return "Nothing laid here."
	return take_down(record)


## Packs up something placed and hands its item back. Returns "" or why not.
func take_down(record: Dictionary) -> String:
	var problem := take_down_problem(record)
	if problem != "":
		return problem
	if record["kind"] == "house":
		# Floors and upgrades are lost with the house.
		records = records.filter(func(r: Dictionary) -> bool: return r["where"] != "house:%d" % record["id"])
	_player.inventory.add(Item.create(_item_of(record)))
	if record["kind"] == "ground":
		var cell := Vector2i(int(record["x"]), int(record["y"]))
		records.erase(record)
		_world().generator.overrides.erase(cell)
		_world().generator.forget(cell)
		_world().refresh_cells([cell])
		SaveGame.request_save()
		return ""
	if record["kind"] == "wall":
		var cell := Vector2i(int(record["x"]), int(record["y"]))
		records.erase(record)
		_rebuild_walls(cell)
		Audio.play("pickup", -6.0, 0.1)
		SaveGame.request_save()
		return ""
	if is_instance_valid(_props.get(record["id"])):
		_props[record["id"]].queue_free()
	_props.erase(record["id"])
	records.erase(record)
	Audio.play("pickup", -6.0, 0.1)
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
	var tier: int = clampi(int(record.get("tier", 1)), 1, MAX_TIER)
	var size: Vector2i = HOUSE_SIZES[tier]
	_instances.prepare_room()
	var house := Room.new()
	house.wall_style = "wood"
	house.title = "Home  -  %s" % ["Cottage", "House", "Manor"][tier - 1]
	house.set_meta("house", record["id"])
	var place := "house:%d" % record["id"]
	for y in range(-1, size.y + 1):
		for x in range(-1, size.x + 1):
			var wall := x < 0 or y < 0 or x >= size.x or y >= size.y
			house.cells[Vector2i(x, y)] = TerrainTiles.Type.WALL if wall else TerrainTiles.Type.PLANK
	for floor_record in records:
		if floor_record["where"] == place and floor_record["kind"] == "floor":
			var cell := Vector2i(int(floor_record["x"]), int(floor_record["y"]))
			if house.is_floor(cell):
				house.cells[cell] = int(floor_record["tile"])
	house.entry = Vector2i(size.x / 2, size.y - 1)
	house.build((get_parent().get_node("World") as World).tile_set())
	_room_props.clear()
	_instances.enter(house)
	house.add_prop(Prop.create(Prop.Art.DOOR, house.cell_position(Vector2i(size.x / 2, size.y)) + Vector2(0, 6), 0.0, "Leave the house", func(_p: Player) -> void: _instances.leave()))
	# The house plans by the door: what the next tier needs.
	var plans := Prop.create_decor(Prop.Decor.SIGNPOST, house.cell_position(Vector2i(size.x / 2 - 2, size.y - 1)), 0.0, upgrade_prompt(record), func(_p: Player) -> void:
		var problem := upgrade_house(record)
		if problem != "":
			Events.announcement.emit("CANNOT UPGRADE", problem)
	)
	house.add_prop(plans)
	for inside in records:
		if inside["where"] == place and inside["kind"] != "floor":
			_spawn(inside)


func upgrade_prompt(record: Dictionary) -> String:
	var tier := int(record.get("tier", 1))
	if tier >= MAX_TIER:
		return "A manor: as large as a house can grow"
	var parts: PackedStringArray = []
	for id: String in UPGRADE_COSTS[tier + 1]:
		if UPGRADE_COSTS[tier + 1][id] > 0:
			parts.append("%d %s" % [UPGRADE_COSTS[tier + 1][id], ItemDB.ITEMS[id]["name"]])
	return "Enlarge the house (%s)" % ", ".join(parts)


## Raises a house one tier, taking the materials. Returns "" or why not.
func upgrade_house(record: Dictionary) -> String:
	var tier := int(record.get("tier", 1))
	if tier >= MAX_TIER:
		return "This house is as large as it can be."
	var cost: Dictionary = UPGRADE_COSTS[tier + 1]
	var missing: PackedStringArray = []
	for id: String in cost:
		if _player.inventory.count_of(id) < cost[id]:
			missing.append("%d %s" % [cost[id] - _player.inventory.count_of(id), ItemDB.ITEMS[id]["name"]])
	if not missing.is_empty():
		return "Still need " + ", ".join(missing)
	for id: String in cost:
		if cost[id] > 0:
			_player.inventory.take(id, cost[id])
	record["tier"] = tier + 1
	if record["tier"] >= MAX_TIER:
		Events.codex_event.emit("manors", 1)
	_player.professions.add_xp("building", 150.0 * tier)
	SaveGame.request_save()
	if is_instance_valid(_props.get(record["id"])):
		_props[record["id"]].queue_free()
	_props.erase(record["id"])
	# The bigger house outside.
	_spawn(record)
	if current_place() == "house:%d" % record["id"]:
		enter_house(record)
	Events.announcement.emit("HOUSE ENLARGED", ["", "Cottage", "House", "Manor"][record["tier"]])
	return ""


func _room_cell(at: Vector2) -> Vector2i:
	return Vector2i(((at - Room.ORIGIN) / TerrainTiles.TILE_SIZE).floor())


## Makes the prop for a record, in the world or in the room being shown.
func _spawn(record: Dictionary) -> void:
	var kind: Dictionary = KINDS[record["kind"]]
	if record["kind"] in ["floor", "ground"]:
		return
	if record["kind"] == "wall":
		_rebuild_walls(Vector2i(int(record["x"]), int(record["y"])))
		return
	var in_room: bool = record["where"] != "world"
	if in_room and (not _instances.is_inside() or current_place() != record["where"]):
		return
	var at := _instances.room.cell_position(Vector2i(int(record["x"]), int(record["y"]))) if in_room else Vector2(record["x"], record["y"])
	var prop: Prop
	if kind.has("decor"):
		prop = Prop.create_decor(kind["decor"], at, kind["solid"])
		if record["kind"] == "plot":
			prop.prompt_text = _plot_prompt(record)
			prop.on_interact = func(player: Player) -> void:
				var problem := tend_plot(player, record)
				if problem != "":
					DamageNumber.spawn_text(get_parent(), player.global_position + Vector2(0, -36), problem, UITheme.DIM, 12)
			var view := CropView.new()
			view.record = record
			prop.add_child(view)
		if kind.get("light", false):
			prop.add_light()
		if kind.get("flat", false):
			prop.set_meta("flat", true)
			prop.z_index = -5
		# Your own scenery still counts as yours for taking down.
		prop.add_to_group("my_buildings")
	else:
		prop = Prop.create(kind["art"], at, kind["solid"], kind["prompt"], _use.bind(record))
	if record["kind"] == "house":
		var tier: int = clampi(int(record.get("tier", 1)), 1, MAX_TIER)
		prop.sprite().scale = Vector2.ONE * HOUSE_SCALE[tier]
		prop.sprite().position.y = -25.0 * HOUSE_SCALE[tier]
		if not in_room:
			var world: World = get_parent().get_node("World")
			HouseStyles.dress(prop, world.tile_type_at_position(at), str(record.get("style", "")))
		prop.reach = 110.0 + 20.0 * (int(record.get("tier", 1)) - 1)
	if record["kind"] == "table":
		prop.add_to_group("crafting_tables")
	if record.get("flip", false) and prop.sprite():
		prop.sprite().flip_h = true
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
