class_name Villages
extends Node2D
## Builds villages as their chunks load: houses round a crossroads, a well,
## a market stall, lanterns, fences, a fire to rest at, the merchant and
## warden, and villagers going about their day. Where villages stand comes
## from WorldGenerator.village_center.

const T := TerrainTiles.Type
const HOUSE_ART := preload("res://scripts/world/house_art.gd")
## Where a castle stands in a village that has one, off the north road.
const CASTLE_SPOT := Vector2i(-11, -18)
## How often the king is in residence when you come by.
const KING_CHANCE := 0.3
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
	var festivals: Festivals = get_parent().get_node_or_null("Festivals")
	if festivals:
		festivals.changed.connect(func() -> void:
			for center: Vector2i in _built.keys():
				rebuild(center)
		)
	var projects := _projects()
	if projects:
		projects.changed.connect(func(key: String) -> void:
			var parts := key.split(",")
			rebuild(Vector2i(int(parts[0]), int(parts[1])))
		)


func _projects() -> VillageProjects:
	return get_parent().get_node_or_null("VillageProjects")


## Builds a village again (after a project is finished), if it stands now.
func rebuild(center: Vector2i) -> void:
	if not _built.has(center):
		return
	var chunk: Vector2i = _built[center]
	for node: Variant in _by_chunk.get(chunk, []):
		if is_instance_valid(node):
			node.queue_free()
	_by_chunk[chunk] = _build(center)


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


## Shuffles in place with the village's own dice, so it is the same each time.
static func _shuffle(list: Array, random: RandomNumberGenerator) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := random.randi_range(0, i)
		var held: Variant = list[i]
		list[i] = list[j]
		list[j] = held


## Someone of the village in a given role, standing at `at`.
func _person(center: Vector2i, index: int, people: String, job: String, at: Vector2, doors: Array[Vector2]) -> Npc:
	var person := VillagerLife.make(center, index, _world.generator.world_seed, people, job)
	var npc := Npc.create("villager", at)
	npc.lines = LINES
	npc.villager_name = person["name"]
	npc.job = person["job"]
	npc.look = (person["look"] as Dictionary).duplicate()
	npc.villager_key = person["key"]
	npc.square = _at(center)
	npc.door = doors[index % doors.size()] if not doors.is_empty() else Vector2.ZERO
	npc.home = at
	return npc


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


## Where finished projects may stand, from the centre, nearest first.
const PROJECT_SPOTS: Array[Vector2i] = [Vector2i(5, -10), Vector2i(-5, 10), Vector2i(5, 10), Vector2i(-5, -11), Vector2i(6, -13), Vector2i(-6, 13),
	Vector2i(6, 13), Vector2i(-6, -13), Vector2i(0, -17), Vector2i(0, 17),
	Vector2i(-17, 0), Vector2i(17, 0), Vector2i(14, -14), Vector2i(-14, 14), Vector2i(14, 14), Vector2i(-14, -14), Vector2i(20, 6), Vector2i(-20, -6)]
## The plot each built project stands on: "village key:project" -> cell.
var _plots: Dictionary = {}


## The cell a built project stands on, if its village is standing.
func plot_of(center: Vector2i, project: String) -> Variant:
	return _plots.get(VillageProjects.key_of(center) + ":" + project)


## The first project spot clear of everything placed and of other plots,
## on dry ground: a project takes about five tiles by three.
func _free_plot(center: Vector2i, placed: Array, taken: Array[Vector2i]) -> Vector2i:
	for spot in PROJECT_SPOTS:
		var plot := center + spot
		if plot in taken:
			continue
		var clear := true
		for dy in range(-2, 3):
			for dx in range(-3, 4):
				if not _world.generator.is_dry_land(plot + Vector2i(dx, dy)):
					clear = false
		var middle := _at(plot)
		for node: Variant in placed:
			if not clear or not is_instance_valid(node) or not node is Node2D or node is Npc:
				continue
			# Houses keep a wide berth; lanterns and barrels a small one.
			var house: bool = node is Prop and (node as Prop).is_house()
			if (node as Node2D).position.distance_to(middle) < (6.0 if house else 3.2) * TerrainTiles.TILE_SIZE:
				clear = false
		for other in taken:
			if Vector2(other - plot).length() < 7.0:
				clear = false
		if clear:
			return plot
	return center + PROJECT_SPOTS[taken.size() % PROJECT_SPOTS.size()]


func _build_project(project: String, plot: Vector2i, center: Vector2i, add: Callable) -> void:
	var tile := _world.generator.tile_type_at(center + Vector2i(3, 3))
	match project:
		"smithy":
			var forge := Prop.create_decor(Prop.Decor.FURNACE, _at(plot), 20.0)
			forge.add_light(0.6, 0.8, Color(1.0, 0.6, 0.3))
			add.call(forge)
			add.call(Prop.create_decor(Prop.Decor.STALL, _at(plot + Vector2i(-3, 0)), 18.0))
			var smith := Npc.create("settler", _at(plot + Vector2i(-3, 1), Vector2(0, 16)))
			smith.title_text = "Village Smith"
			smith.prompt_text = "Trade with the smith"
			smith.stock_kind = "smith"
			smith.tint = Color(0.8, 0.8, 0.9)
			smith.home = _at(plot + Vector2i(-3, 1))
			smith.village = center
			add.call(smith)
		"inn":
			var inn := Prop.create_building(Prop.People.HUMAN, 4, _at(plot), 34.0, "Rest at the inn", func(player: Player) -> void:
				player.health.heal_full()
				player.stamina.fill()
				player.mana.fill()
				player.buffs.add("well_rested", "Well Rested", 1200.0, {"xp_gain": {"flat": 0.1}})
				Events.announcement.emit("WELL RESTED", "+10% experience for 20 minutes")
			)
			inn.sprite().material = Wind.roof
			add.call(inn)
			var sign := Prop.create_decor(Prop.Decor.BANNER, _at(plot + Vector2i(3, 1)), 5.0)
			sign.sprite().modulate = Color(0.9, 0.75, 0.5)
			add.call(sign)
		"chapel":
			var shrine := Prop.create_decor(Prop.Decor.STATUE, _at(plot), 14.0, "Pray at the shrine", func(player: Player) -> void:
				player.health.heal_full()
				player.buffs.add("blessed", "Blessed", 1200.0, {"max_health": {"percent": 0.06}})
				RingBurst.spawn(get_parent(), player.global_position + Vector2(0, -14), Color(1.0, 0.95, 0.7), 60.0)
				Events.announcement.emit("BLESSED", "+6% maximum health for 20 minutes")
			)
			shrine.add_light(0.8, 1.4, Color(1.0, 0.92, 0.7))
			add.call(shrine)
			for side: int in [-2, 2]:
				var candles := Prop.create_decor(Prop.Decor.CANDLES, _at(plot + Vector2i(side, 1)), 0.0)
				candles.add_light(0.6, 1.0)
				add.call(candles)
			add.call(Prop.create_decor(Prop.Decor.CARVED_PILLAR, _at(plot + Vector2i(0, -2)), 10.0))
		"market":
			for offset: Vector2i in [Vector2i(-2, 0), Vector2i(2, 0)]:
				add.call(Prop.create_decor(Prop.Decor.STALL, _at(plot + offset), 18.0))
			add.call(Prop.create_decor(Prop.Decor.CRATE, _at(plot + Vector2i(0, 1)), 10.0))
			add.call(Prop.create_decor(Prop.Decor.BARREL, _at(plot + Vector2i(4, 1)), 10.0))
		"garden":
			for offset: Vector2i in [Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]:
				var soil := Prop.create_decor(Prop.Decor.SOIL, _at(plot + offset), 0.0)
				soil.z_index = -5
				soil.set_meta("flat", true)
				add.call(soil)
			var pot := Prop.create_decor(Prop.Decor.PLANT_POT, _at(plot + Vector2i(0, -1)), 8.0, "Gather from the herb garden", func(player: Player) -> void:
				var day_night: DayNight = get_parent().get_node("DayNight")
				var found := _projects().harvest_garden(center, player, day_night.day)
				if found.is_empty():
					DamageNumber.spawn_text(get_parent(), player.global_position + Vector2(0, -40), "Picked clean today", UITheme.DIM, 12)
				for pair: Array in found:
					Events.pickup_noted.emit(ItemDB.ITEMS[pair[0]]["name"], pair[1], UITheme.GOOD)
			)
			add.call(pot)


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
	var people := _world.generator.village_culture(center)
	var capital := _world.generator.is_capital(center)
	var castle := _world.generator.has_castle(center)
	var town_name := _world.generator.village_name(center)
	# Tiles already taken, so the dressing below never piles up or lands on a road.
	var used := {}
	for offset: Vector2i in [Vector2i(3, -3), Vector2i(-3, -3), Vector2i(-5, -3), Vector2i(-5, -2), Vector2i(3, 3), Vector2i(-3, -2),
			Vector2i(-3, 3), Vector2i(-5, 3), Vector2i(5, 4), Vector2i(5, -3), Vector2i(2, -6), Vector2i(-6, -7), Vector2i(-7, 3)]:
		used[center + offset] = true
	var decor := func(kind: int, cell: Vector2i, solid: float = 8.0) -> Prop:
		if used.has(cell) or _world.generator.tile_type_at(cell) in [T.PATH, T.TRACK] or not _world.generator.is_dry_land(cell):
			return null
		used[cell] = true
		return add.call(Prop.create_decor(kind, _at(cell), solid))

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
	var merchant := Npc.create("merchant", _at(center + Vector2i(-3, -2), Vector2(0, 16)))
	merchant.village = center
	if _projects() and _projects().has(center, "market"):
		merchant.extra_shelf = 1
		merchant.discount = 0.05
	add.call(merchant)
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
		add.call(stones.make_stone("village:%d,%d" % [center.x, center.y], ("%s (capital)" if capital else "%s") % town_name, center + Vector2i(5, -3)))

	# The square: benches by the fire, flowers at its corners, hay by the stall.
	decor.call(Prop.Decor.BENCH, center + Vector2i(5, 2), 8.0)
	decor.call(Prop.Decor.BENCH, center + Vector2i(2, 5), 8.0)
	decor.call(Prop.Decor.FLOWER_BED, center + Vector2i(2, 2), 6.0)
	decor.call(Prop.Decor.FLOWER_BED, center + Vector2i(-2, -2), 6.0)
	decor.call(Prop.Decor.STONE_PLANTER, center + Vector2i(2, -2), 8.0)
	decor.call(Prop.Decor.HAY_BALE, center + Vector2i(-6, -4), 10.0)
	decor.call(Prop.Decor.CART, center + Vector2i(-7, -2), 14.0)
	# The warden's corner: an anvil and a rack of arms (a full smithy is a
	# village project).
	decor.call(Prop.Decor.ANVIL, center + Vector2i(-4, 6), 10.0)
	decor.call(Prop.Decor.WEAPON_RACK, center + Vector2i(-6, 6), 10.0)
	# A field outside, its rows tilled, a scarecrow and hay at its edge.
	var field_quarter: Vector2i = [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)][random.randi_range(0, 2 if castle else 3)]
	var field := Vector2i(field_quarter.x * 15, field_quarter.y * 15)
	for row in 3:
		for column in 4:
			decor.call(Prop.Decor.SOIL, center + field + Vector2i(column, row), 0.0)
	decor.call(Prop.Decor.SCARECROW, center + field + Vector2i(2, -1), 6.0)
	decor.call(Prop.Decor.HAY_BALE, center + field + Vector2i(-1, 1), 10.0)
	decor.call(Prop.Decor.HAY_BALE, center + field + Vector2i(-1, 2), 10.0)

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
	# The race post: a gold banner where the village's mount race starts.
	var post_at := _at(center + Vector2i(-6, -7))
	var course_key := "race:%d,%d" % [center.x, center.y]
	var race_post := Prop.create_decor(Prop.Decor.BANNER, post_at, 5.0, "Race the village course", func(player: Player) -> void:
		var problem := RaceCourse.start(player, course_key, post_at, RaceCourse.plan(_world, center, post_at))
		if problem != "":
			DamageNumber.spawn_text(get_parent(), player.global_position + Vector2(0, -50), problem, UITheme.BAD, 13)
	)
	race_post.sprite().modulate = Color(1.0, 0.86, 0.45)
	race_post.set_meta("race_course", course_key)
	add.call(race_post)
	# The project board, and whatever the village has built with your help.
	var projects := _projects()
	var asking := projects.current(center) if projects else ""
	var project_board := Prop.create_decor(Prop.Decor.SIGNPOST, _at(center + Vector2i(-7, 3)), 6.0,
		("Village project: %s" % VillageProjects.PROJECTS[asking]["name"]) if asking != "" else "Read the village's story", func(_player: Player) -> void:
			Events.project_board_opened.emit(center)
	)
	project_board.sprite().modulate = Color(0.8, 0.9, 1.0)
	add.call(project_board)

	# Houses in each quarter between the roads, each different, in the
	# people's own way of building; a capital has a second ring of them.
	var doors: Array[Vector2] = []
	var building := {"human": Prop.People.HUMAN, "elf": Prop.People.ELF, "dwarf": Prop.People.DWARF}[people] as int
	var variants: Array = range(Prop.HOUSE_VARIANTS)
	_shuffle(variants, random)
	var spots: Array[Vector2i] = []
	for quarter: Vector2i in [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		for house_index in random.randi_range(1, 2):
			spots.append(Vector2i(quarter.x * random.randi_range(8, 12), quarter.y * random.randi_range(3, 5) if house_index == 0 else quarter.y * random.randi_range(9, 12)))
		if capital:
			spots.append(Vector2i(quarter.x * random.randi_range(16, 19), quarter.y * random.randi_range(4, 6)))
			spots.append(Vector2i(quarter.x * random.randi_range(4, 6), quarter.y * random.randi_range(16, 19)))
			if quarter.y > 0 or not castle:
				spots.append(Vector2i(quarter.x * random.randi_range(14, 17), quarter.y * random.randi_range(13, 16)))
	for spot: Vector2i in spots:
		if true:
			if absi(spot.x) <= 2 or absi(spot.y) <= 2:
				continue
			if castle and spot.x < -3 and spot.y < -13:
				continue
			var house_key := "house:%d,%d" % [center.x + spot.x, center.y + spot.y]
			var variant: int = variants[doors.size() % variants.size()]
			var house := Prop.create_building(building, variant, _at(center + spot), 34.0, "Enter the house", func(_player: Player) -> void:
				var structures: Structures = get_parent().get_node_or_null("Structures")
				var instances: Instances = get_parent().get_node_or_null("Instances")
				if structures == null or instances == null:
					return
				instances.enter_dwelling("cottage", "A villager's house", _world.generator.enemy_level_at(center), hash(house_key), structures.used.has(house_key), func() -> void:
					structures.used[house_key] = true
					SaveGame.request_save()
				, "", people)
			)
			doors.append(_at(center + spot, Vector2(0, 10)))
			if people == "human":
				HouseStyles.dress(house, tile)
			else:
				house.sprite().material = Wind.roof
			add.call(house)
			# Someone is home: smoke from the chimney.
			var chimney: Variant = HOUSE_ART.CHIMNEYS.get("%d,%d" % [building, variant])
			if chimney != null and random.randf() < 0.8 and house.sprite().texture == Prop.HOUSES:
				var smoke := ChimneySmoke.new()
				smoke.position = house.sprite().position + (chimney as Vector2)
				house.add_child(smoke)
			for k in range(-1, 2):
				used[center + spot + Vector2i(k, 0)] = true
				used[center + spot + Vector2i(k, 1)] = true
			# A yard: a fence along its front with a gap at the door, a
			# garden or flowers to one side, barrels and crates to the other,
			# and a lamp at the gate.
			if people == "human":
				for k in [-3, -2, 2, 3]:
					decor.call(Prop.Decor.FENCE, center + spot + Vector2i(k, 2), 0.0)
				decor.call(Prop.Decor.FENCE, center + spot + Vector2i(-3, 1), 0.0)
				decor.call(Prop.Decor.FENCE, center + spot + Vector2i(3, 1), 0.0)
			elif people == "dwarf":
				decor.call(Prop.Decor.ANVIL if random.randf() < 0.4 else Prop.Decor.BARREL, center + spot + Vector2i(-3, 1), 8.0)
			match random.randi_range(0, 2):
				0:
					decor.call(Prop.Decor.FLOWER_BED, center + spot + Vector2i(-2, 1), 6.0)
				1:
					decor.call(Prop.Decor.SOIL, center + spot + Vector2i(-2, 1), 0.0)
					decor.call(Prop.Decor.SOIL, center + spot + Vector2i(-2, 0), 0.0)
				_:
					decor.call(Prop.Decor.PLANT_POT, center + spot + Vector2i(-2, 1), 6.0)
			decor.call(Prop.Decor.BARREL if random.randf() < 0.5 else Prop.Decor.CRATE, center + spot + Vector2i(2, 1), 8.0)
			if random.randf() < 0.5:
				decor.call(Prop.Decor.CRATE, center + spot + Vector2i(2, 0), 8.0)
			if random.randf() < 0.4:
				decor.call(Prop.Decor.BENCH, center + spot + Vector2i(-2, 3), 8.0)
			var lamp: Prop = decor.call(Prop.Decor.LANTERN, center + spot + Vector2i(1, 3), 5.0)
			if lamp:
				lamp.add_light(0.8, 1.3)

	# Villagers about the place, each with a name, a trade and a door.
	var folk := random.randi_range(9, 12) if capital else random.randi_range(5, 7)
	for i in folk:
		var person := VillagerLife.make(center, i, _world.generator.world_seed, people)
		var villager := Npc.create("villager", _at(center + Vector2i(random.randi_range(-6, 6), random.randi_range(-6, 6))))
		villager.lines = LINES
		# What happened near the village is on everyone's lips.
		var memory: WorldMemory = get_parent().get_node_or_null("WorldMemory")
		if memory:
			var said: Array[String] = LINES.duplicate()
			for rumour: String in memory.rumours(center):
				said.append_array([rumour, rumour])
			# And what the monsters are saying about the player.
			var factions: Factions = get_parent().get_node_or_null("Factions")
			if factions:
				for line: String in factions.rumours():
					said.append(line)
			villager.lines = said
		villager.villager_name = person["name"]
		villager.job = person["job"]
		villager.look = (person["look"] as Dictionary).duplicate()
		villager.villager_key = person["key"]
		# Those who inform for the Lull Court wear a small porcelain charm at
		# the throat (the pendant), and no one else does. While Saint Lull's
		# plan is under way they ask where you are going.
		if SaintLull.is_informer(person["key"]):
			var lull: SaintLull = get_parent().get_node_or_null("SaintLull")
			if lull == null or not person["key"] in lull.informers_caught:
				villager.look["neck"] = 4
				if lull and lull.stage >= 2 and lull.stage < 5:
					var probing: Array[String] = villager.lines.duplicate()
					probing.append_array(SaintLull.INFORMER_LINES)
					villager.lines = probing
		elif int(villager.look.get("neck", 0)) == 4:
			villager.look["neck"] = 1
		villager.square = _at(center)
		villager.door = doors[i % doors.size()] if not doors.is_empty() else Vector2.ZERO
		villager.home = villager.door + Vector2(0, 30) if villager.door != Vector2.ZERO else villager.position
		if person["job"] == "fisher" or person["job"] == "farmer":
			villager.home = _at(center + Vector2i(random.randi_range(-9, 9), random.randi_range(6, 11)))
		add.call(villager)
	# A capital keeps more guards, at its gates.
	if capital:
		var keeper: String = VillagerLife.KEEPERS.get(people, VillagerLife.KEEPERS["human"])[0]
		for k in 2:
			var gate: Vector2i = [Vector2i(2, 20), Vector2i(-2, -20)][k]
			add.call(_person(center, folk + k, people, keeper, _at(center + gate), doors))
	# The castle, its guards at the gate, and now and then the king himself
	# with his household, walking the village.
	if castle:
		var keep := Prop.create_castle(_at(center + CASTLE_SPOT))
		add.call(keep)
		for side: int in [-3, 3]:
			var royal_guard := _person(center, 40 + side, people, "royal_guard", _at(center + CASTLE_SPOT + Vector2i(side, 1)), doors)
			royal_guard.home = royal_guard.position
			add.call(royal_guard)
		for side: int in [-5, 5]:
			var torch := Prop.create_decor(Prop.Decor.LANTERN, _at(center + CASTLE_SPOT + Vector2i(side, 1)), 5.0)
			torch.add_light(1.0, 1.8)
			add.call(torch)
		if randf() < KING_CHANCE:
			var king := _person(center, 50, people, "king", _at(center + Vector2i(1, -2)), doors)
			king.home = _at(center + Vector2i(0, -4))
			add.call(king)
			for k in randi_range(1, 2):
				var royal := _person(center, 51 + k, people, "royal", _at(center + Vector2i(-1 - k, -2)), doors)
				royal.home = king.home
				add.call(royal)
			Events.announcement.emit("THE KING IS IN %s" % town_name.to_upper(), "His guards walk with him. Mind your manners.")
	# A festival: the village's colours out, and the Festival Keeper.
	var festivals: Festivals = get_parent().get_node_or_null("Festivals")
	var festival := festivals.current() if festivals else ""
	if festival != "":
		var colour: Color = Festivals.FESTIVALS[festival]["color"]
		for spot: Vector2i in [Vector2i(-1, -5), Vector2i(5, -1), Vector2i(-5, 1), Vector2i(1, 5)]:
			var flag := Prop.create_decor(Prop.Decor.BANNER, _at(center + spot), 5.0)
			flag.sprite().modulate = colour
			add.call(flag)
		for spot: Vector2i in [Vector2i(-3, 6), Vector2i(3, -7), Vector2i(7, 2)]:
			var lamp := Prop.create_decor(Prop.Decor.LANTERN, _at(center + spot), 5.0)
			lamp.add_light(0.9, 1.6, colour.lightened(0.3))
			add.call(lamp)
		var stall := Prop.create_decor(Prop.Decor.STALL, _at(center + Vector2i(0, -4)), 18.0)
		stall.sprite().modulate = colour.lightened(0.2)
		add.call(stall)
		var keeper := Npc.create("festival", _at(center + Vector2i(0, -3), Vector2(0, 16)))
		keeper.offer = {"festival": festival}
		keeper.title_text = "%s Keeper" % Festivals.FESTIVALS[festival]["name"]
		keeper.prompt_text = "Visit the %s" % Festivals.FESTIVALS[festival]["name"]
		keeper.tint = colour.lightened(0.3)
		keeper.home = _at(center + Vector2i(0, -3))
		add.call(keeper)
	# What the village has built with your help, each on the first free plot.
	if projects:
		var taken: Array[Vector2i] = []
		for project: String in projects.done(center):
			var plot := _free_plot(center, placed, taken)
			taken.append(plot)
			_plots[VillageProjects.key_of(center) + ":" + project] = plot
			_build_project(project, plot, center, add)
	return placed
