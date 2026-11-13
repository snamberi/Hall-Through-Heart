class_name Villages
extends Node2D
## Builds villages as their chunks load: houses round a crossroads, a well,
## a market stall, lanterns, fences, a fire to rest at, the merchant and
## warden, and villagers going about their day. Where villages stand comes
## from WorldGenerator.village_center.

const T := TerrainTiles.Type
const LINES: Array[String] = [
	"Stay off the roads after dark.",
	"The husks never come this close. Not yet.",
	"My grandmother said the ground used to be warm.",
	"Have you seen the lights out in the Voidscar?",
	"Trade's slow. Everyone's afraid to travel.",
	"If you find copper, the merchant pays fair.",
	"They say there's a heart under all of this.",
	"Sleep somewhere safe. The night is long.",
]

var _world: World
var _by_chunk: Dictionary = {}
var _built: Dictionary = {}
## Signposts along the roads, by the chunk they stand in.
var _signs: Dictionary = {}


func setup(world: World) -> void:
	_world = world
	world.chunk_built.connect(_on_chunk_built)
	world.chunk_freed.connect(_on_chunk_freed)


## Whether a tile is part of a village (so nothing grows there).
func is_built_up(cell: Vector2i) -> bool:
	return _world.generator.village_near(cell) != null


func _on_chunk_built(chunk: Vector2i) -> void:
	_place_road_signs(chunk)
	var origin := chunk * World.CHUNK_SIZE
	var middle := origin + Vector2i(World.CHUNK_SIZE / 2, World.CHUNK_SIZE / 2)
	var center: Variant = _world.generator.village_near(middle)
	if center == null:
		# A village may only touch this chunk at an edge; check the corners.
		for corner: Vector2i in [origin, origin + Vector2i(World.CHUNK_SIZE - 1, 0), origin + Vector2i(0, World.CHUNK_SIZE - 1), origin + Vector2i(World.CHUNK_SIZE - 1, World.CHUNK_SIZE - 1)]:
			center = _world.generator.village_near(corner)
			if center != null:
				break
	if center == null or _built.has(center):
		return
	# The whole village is built by the first of its chunks to load, and
	# belongs to that chunk.
	_built[center] = chunk
	_by_chunk[chunk] = _build(center)


func _on_chunk_freed(chunk: Vector2i) -> void:
	for sign: Variant in _signs.get(chunk, []):
		if is_instance_valid(sign):
			sign.queue_free()
	_signs.erase(chunk)
	if not _by_chunk.has(chunk):
		return
	for node: Variant in _by_chunk[chunk]:
		if is_instance_valid(node):
			node.queue_free()
	_by_chunk.erase(chunk)
	for center: Vector2i in _built.keys():
		if _built[center] == chunk:
			_built.erase(center)


## Every so often along a road, a signpost to the places nearby.
const SIGN_EVERY := 80.0


func _place_road_signs(chunk: Vector2i) -> void:
	var bounds := Rect2i(chunk * World.CHUNK_SIZE, Vector2i(World.CHUNK_SIZE, World.CHUNK_SIZE))
	var region := Vector2i((Vector2(bounds.get_center()) / WorldGenerator.VILLAGE_REGION).floor())
	var placed: Array = []
	for road: Array in _world.generator.roads_near(region):
		var length: float = (road[0] as Vector2).distance_to(road[1])
		# The road out of the Sanctuary gets a sign close to the temple.
		var along := 8.0 if (road[0] as Vector2).length() < 20.0 else WorldGenerator.VILLAGE_RADIUS + 30.0
		var structures: Structures = get_parent().get_node_or_null("Structures")
		while along < length - WorldGenerator.VILLAGE_RADIUS - 20.0:
			var t := along / length
			var spot := _beside_road(road, t)
			if bounds.has_point(spot) and not _world.generator.on_road(spot) and _world.generator.is_walkable(spot) \
					and (structures == null or not structures.is_reserved(spot) or along < 10.0):
				var sign := Signpost.create(_at(spot), spot, get_parent().get_node_or_null("Structures"))
				add_child(sign)
				placed.append(sign)
			along += SIGN_EVERY
	if not placed.is_empty():
		_signs[chunk] = placed


## A tile just off the side of a road, partway along it.
func _beside_road(road: Array, t: float) -> Vector2i:
	var direction := ((road[1] as Vector2) - (road[0] as Vector2)).normalized()
	var point := WorldGenerator.road_point(road, t) + direction.orthogonal() * 2.6
	return Vector2i(point.round())


func _at(cell: Vector2i, offset: Vector2 = Vector2.ZERO) -> Vector2:
	return _world.cell_to_world(cell) + offset


func _build(center: Vector2i) -> Array:
	var random := RandomNumberGenerator.new()
	random.seed = hash(Vector3i(center.x, center.y, _world.generator.world_seed + 99))
	var placed: Array = []
	var add := func(node: Node2D) -> Node2D:
		add_child(node)
		placed.append(node)
		return node
	var tile := _world.generator.tile_type_at(center + Vector2i(3, 3))

	# The square: a well, a market stall, a fire to rest at.
	add.call(Prop.create_decor(Prop.Decor.WELL, _at(center + Vector2i(3, -3)), 20.0))
	add.call(Prop.create_decor(Prop.Decor.STALL, _at(center + Vector2i(-3, -3)), 18.0))
	add.call(Prop.create_decor(Prop.Decor.BARREL, _at(center + Vector2i(-5, -3)), 10.0))
	add.call(Prop.create_decor(Prop.Decor.CRATE, _at(center + Vector2i(-5, -2)), 10.0))
	var fire := Prop.create(Prop.Art.CAMPFIRE, _at(center + Vector2i(3, 3)), 11.0, "Rest here", func(player: Player) -> void:
		player.health.heal_full()
		player.stamina.fill()
		player.mana.fill()
		Events.checkpoint_set.emit(_at(center + Vector2i(3, 4)), "the village")
		Events.announcement.emit("RESTED", "You will wake in the village")
	)
	fire.add_light(1.0, 2.2)
	add.call(fire)
	add.call(Npc.create("merchant", _at(center + Vector2i(-3, -2), Vector2(0, 16))))
	add.call(Npc.create("warden", _at(center + Vector2i(-3, 3))))
	var board := Prop.create_decor(Prop.Decor.SIGNPOST, _at(center + Vector2i(-5, 3)), 6.0, "Read the bounty board", func(_player: Player) -> void:
		Events.screen_requested.emit("bounty_board")
	)
	board.sprite().modulate = Color(1.0, 0.8, 0.7)
	add.call(board)
	# Someone here would move to the player's home, given a bed.
	var recruit := Npc.create("recruit", _at(center + Vector2i(5, 4)))
	recruit.offer = Settlers.offer_for(center, _world.generator.world_seed)
	recruit.title_text = "%s the %s" % [recruit.offer["name"], Settlers.ROLES[recruit.offer["role"]]["title"]]
	recruit.prompt_text = "Talk to %s" % recruit.offer["name"]
	recruit.tint = Settlers.ROLES[recruit.offer["role"]]["tint"]
	add.call(recruit)
	var stones: Waystones = get_parent().get_node_or_null("Waystones")
	if stones:
		add.call(stones.make_stone("village:%d,%d" % [center.x, center.y], "Village (%d, %d)" % [center.x, center.y], center + Vector2i(5, -3)))

	# Lanterns along the roads.
	for distance in [4, 9, 13]:
		for side: Vector2i in [Vector2i(2, distance), Vector2i(-2, -distance), Vector2i(distance, -2), Vector2i(-distance, 2)]:
			var lantern := Prop.create_decor(Prop.Decor.LANTERN, _at(center + side), 5.0)
			lantern.add_light(0.9, 1.5)
			add.call(lantern)
	# Signposts where the roads leave the village, pointing to what is near.
	var site_book: Structures = get_parent().get_node_or_null("Structures")
	var exits := 0
	for road: Array in _world.generator.roads_near(Vector2i((Vector2(center) / WorldGenerator.VILLAGE_REGION).floor())):
		var length: float = (road[0] as Vector2).distance_to(road[1])
		var t := -1.0
		if (road[0] as Vector2).distance_to(Vector2(center)) < 1.0:
			t = (WorldGenerator.VILLAGE_RADIUS + 3.0) / length
		elif (road[1] as Vector2).distance_to(Vector2(center)) < 1.0:
			t = 1.0 - (WorldGenerator.VILLAGE_RADIUS + 3.0) / length
		if t > 0.0:
			var spot := _beside_road(road, t)
			add.call(Signpost.create(_at(spot), spot, site_book))
			exits += 1
	if exits == 0:
		add.call(Signpost.create(_at(center + Vector2i(3, 15)), center + Vector2i(3, 15), site_book))
	add.call(Prop.create_decor(Prop.Decor.BANNER, _at(center + Vector2i(2, -6)), 5.0))

	# Houses in each quarter between the roads.
	var doors: Array[Vector2] = []
	for quarter: Vector2i in [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		for house_index in random.randi_range(1, 2):
			var spot := Vector2i(quarter.x * random.randi_range(8, 12), quarter.y * random.randi_range(3, 5) if house_index == 0 else quarter.y * random.randi_range(9, 12))
			if absi(spot.x) <= 2 or absi(spot.y) <= 2:
				continue
			var house_key := "house:%d,%d" % [center.x + spot.x, center.y + spot.y]
			var house := Prop.create(Prop.Art.HOUSE, _at(center + spot), 34.0, "Enter the house", func(_player: Player) -> void:
				var structures: Structures = get_parent().get_node_or_null("Structures")
				var instances: Instances = get_parent().get_node_or_null("Instances")
				if structures == null or instances == null:
					return
				instances.enter_dwelling("cottage", "A villager's house", _world.generator.enemy_level_at(center), hash(house_key), structures.used.has(house_key), func() -> void:
					structures.used[house_key] = true
					SaveGame.request_save()
				)
			)
			doors.append(_at(center + spot, Vector2(0, 10)))
			house.sprite().scale = Vector2(2.0, 2.0)
			house.sprite().position.y = -50.0
			HouseStyles.dress(house, tile)
			add.call(house)
			# A yard: fences, a barrel, a plant.
			add.call(Prop.create_decor(Prop.Decor.FENCE, _at(center + spot + Vector2i(-2, 2)), 0.0))
			add.call(Prop.create_decor(Prop.Decor.FENCE, _at(center + spot + Vector2i(2, 2)), 0.0))
			add.call(Prop.create_decor(Prop.Decor.BARREL if random.randf() < 0.5 else Prop.Decor.PLANT_POT, _at(center + spot + Vector2i(2, 1)), 8.0))

	# Villagers about the place, each with a name, a trade and a door.
	for i in random.randi_range(5, 7):
		var person := VillagerLife.make(center, i, _world.generator.world_seed)
		var villager := Npc.create("villager", _at(center + Vector2i(random.randi_range(-6, 6), random.randi_range(-6, 6))))
		villager.lines = LINES
		villager.villager_name = person["name"]
		villager.job = person["job"]
		villager.look = person["look"]
		villager.villager_key = person["key"]
		villager.square = _at(center)
		villager.door = doors[i % doors.size()] if not doors.is_empty() else Vector2.ZERO
		villager.home = villager.door + Vector2(0, 30) if villager.door != Vector2.ZERO else villager.position
		if person["job"] == "fisher" or person["job"] == "farmer":
			villager.home = _at(center + Vector2i(random.randi_range(-9, 9), random.randi_range(6, 11)))
		add.call(villager)
	return placed
