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


func setup(world: World) -> void:
	_world = world
	world.chunk_built.connect(_on_chunk_built)
	world.chunk_freed.connect(_on_chunk_freed)


## Whether a tile is part of a village (so nothing grows there).
func is_built_up(cell: Vector2i) -> bool:
	return _world.generator.village_near(cell) != null


func _on_chunk_built(chunk: Vector2i) -> void:
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
	if not _by_chunk.has(chunk):
		return
	for node: Variant in _by_chunk[chunk]:
		if is_instance_valid(node):
			node.queue_free()
	_by_chunk.erase(chunk)
	for center: Vector2i in _built.keys():
		if _built[center] == chunk:
			_built.erase(center)


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

	# Lanterns along the roads.
	for distance in [4, 9, 13]:
		for side: Vector2i in [Vector2i(2, distance), Vector2i(-2, -distance), Vector2i(distance, -2), Vector2i(-distance, 2)]:
			var lantern := Prop.create_decor(Prop.Decor.LANTERN, _at(center + side), 5.0)
			lantern.add_light(0.9, 1.5)
			add.call(lantern)
	add.call(Prop.create_decor(Prop.Decor.SIGNPOST, _at(center + Vector2i(2, 15)), 6.0))
	add.call(Prop.create_decor(Prop.Decor.BANNER, _at(center + Vector2i(2, -6)), 5.0))

	# Houses in each quarter between the roads.
	for quarter: Vector2i in [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		for house_index in random.randi_range(1, 2):
			var spot := Vector2i(quarter.x * random.randi_range(8, 12), quarter.y * random.randi_range(3, 5) if house_index == 0 else quarter.y * random.randi_range(9, 12))
			if absi(spot.x) <= 2 or absi(spot.y) <= 2:
				continue
			var house := Prop.create(Prop.Art.HOUSE, _at(center + spot), 34.0, "The door is barred")
			house.sprite().scale = Vector2(2.0, 2.0)
			house.sprite().position.y = -50.0
			HouseStyles.dress(house, tile)
			add.call(house)
			# A yard: fences, a barrel, a plant.
			add.call(Prop.create_decor(Prop.Decor.FENCE, _at(center + spot + Vector2i(-2, 2)), 0.0))
			add.call(Prop.create_decor(Prop.Decor.FENCE, _at(center + spot + Vector2i(2, 2)), 0.0))
			add.call(Prop.create_decor(Prop.Decor.BARREL if random.randf() < 0.5 else Prop.Decor.PLANT_POT, _at(center + spot + Vector2i(2, 1)), 8.0))

	# Villagers about the place.
	for i in random.randi_range(3, 5):
		var villager := Npc.create("villager", _at(center + Vector2i(random.randi_range(-6, 6), random.randi_range(-6, 6))))
		villager.lines = LINES
		villager.home = villager.position
		add.call(villager)
	return placed
