class_name ResourceSpawner
extends Node2D
## Fills each chunk as it loads, the same way every time for a given seed:
## ore, herbs, and fishing spots to gather; woods of choppable trees where
## the forest noise is high; bushes and scenery; flowers and grass; and
## wildlife.
##
## Gathered nodes stay gone for REGROW_SECONDS, tracked only while the game
## is running.

const REGROW_SECONDS := 240.0
## Nothing grows this close to the world origin, in tiles.
const CLEAR_RADIUS := 6.0
const CRITTERS_PER_CHUNK := 2

var _world: World
var _forest := FastNoiseLite.new()
## chunk -> nodes placed for it
var _by_chunk: Dictionary = {}
## cell -> time it was gathered (seconds since start)
var _gathered: Dictionary = {}


func setup(world: World) -> void:
	_world = world
	_forest.seed = world.generator.world_seed + 3131
	_forest.frequency = 0.03
	_forest.fractal_octaves = 2
	world.chunk_built.connect(_on_chunk_built)
	world.chunk_freed.connect(_on_chunk_freed)


## How wooded a tile is, 0 to 1.
func forest_at(cell: Vector2i) -> float:
	return clampf(_forest.get_noise_2d(cell.x, cell.y) * 1.6 + 0.35, 0.0, 1.0)


func _on_chunk_built(chunk: Vector2i) -> void:
	var generator := _world.generator
	var random := RandomNumberGenerator.new()
	random.seed = hash(Vector3i(chunk.x, chunk.y, generator.world_seed))
	var placed: Array = []
	var used := {}
	var origin := chunk * World.CHUNK_SIZE
	var cover := GroundCover.new()

	# Village and structure grounds stay clear of growth.
	var villages: Villages = get_parent().get_node_or_null("Villages")
	var structures: Structures = get_parent().get_node_or_null("Structures")
	# Nothing grows on built-up ground, nor on the face of a cliff.
	var keep_clear := func(c: Vector2i) -> bool:
		return (villages != null and villages.is_built_up(c)) or (structures != null and structures.is_reserved(c)) or generator.is_cliff_base(c)

	# Things to gather, a few per chunk.
	for kind: String in GatherDB.PER_CHUNK:
		for attempt: int in GatherDB.PER_CHUNK[kind]:
			var cell := origin + Vector2i(random.randi_range(0, World.CHUNK_SIZE - 1), random.randi_range(0, World.CHUNK_SIZE - 1))
			var id := GatherDB.pick(kind, generator.tile_type_at(cell), generator.enemy_level_at(cell), random)
			if id == "" or used.has(cell) or Vector2(cell).length() < CLEAR_RADIUS or keep_clear.call(cell):
				continue
			used[cell] = true
			_place_node(placed, id, cell, -1)

	# Woods, bushes, scenery, and ground cover, tile by tile.
	for y in World.CHUNK_SIZE:
		for x in World.CHUNK_SIZE:
			var cell := origin + Vector2i(x, y)
			if used.has(cell) or Vector2(cell).length() < CLEAR_RADIUS or keep_clear.call(cell):
				continue
			var tile := generator.tile_type_at(cell)
			var biome: Dictionary = Flora.BIOMES.get(tile, {})
			if biome.is_empty():
				continue
			var roll := random.randf()
			var tree_chance: float = biome["forest"] * (0.08 + 0.55 * forest_at(cell) * forest_at(cell))
			var jitter := Vector2(random.randf_range(-14, 14), random.randf_range(-12, 12))
			if roll < tree_chance and not biome["trees"].is_empty():
				used[cell] = true
				var look: int = biome["trees"][random.randi_range(0, biome["trees"].size() - 1)]
				if look in Flora.WOODEN:
					var id := GatherDB.pick("tree", tile, generator.enemy_level_at(cell), random)
					_place_node(placed, id if id != "" else "oak", cell, look, jitter)
				else:
					placed.append(_scenery(look, _world.cell_to_world(cell) + jitter, 10.0))
			elif roll < tree_chance + 0.035 and not biome["bushes"].is_empty():
				used[cell] = true
				var bush: int = biome["bushes"][random.randi_range(0, biome["bushes"].size() - 1)]
				# Berry bushes can be picked.
				if bush == Flora.Tall.BERRY_BUSH:
					_place_node(placed, "berry_bush", cell, bush, jitter)
				elif bush == Flora.Tall.THORN_BUSH and random.randf() < 0.5:
					_place_node(placed, "thornberry_bush", cell, bush, jitter)
				else:
					placed.append(_scenery(bush, _world.cell_to_world(cell) + jitter, 0.0))
			# Ground detail uses its own hash, so it never moves anything else.
			var detail := absi(hash(Vector3i(cell.x, cell.y, 77)))
			if detail % 100 < 7 and biome.has("decals"):
				var decals: Array = biome["decals"]
				cover.decals.append([_world.cell_to_world(cell) + Vector2(detail % 23 - 11, detail / 23 % 19 - 9), decals[detail / 437 % decals.size()], detail % 2 == 0])
			if used.has(cell):
				continue
			elif random.randf() < biome["cover"]:
				var ground: Array = biome["ground"]
				for k in (1 if random.randf() < 0.6 else 2):
					var spot := _world.cell_to_world(cell) + Vector2(random.randf_range(-18, 18), random.randf_range(-14, 18))
					cover.plants.append([spot, ground[random.randi_range(0, ground.size() - 1)], random.randf() < 0.5])
	add_child(cover)
	placed.append(cover)

	# A little wildlife.
	for i in CRITTERS_PER_CHUNK:
		var cell := origin + Vector2i(random.randi_range(0, World.CHUNK_SIZE - 1), random.randi_range(0, World.CHUNK_SIZE - 1))
		var biome: Dictionary = Flora.BIOMES.get(generator.tile_type_at(cell), {})
		if biome.is_empty() or biome["critters"].is_empty() or random.randf() < 0.4:
			continue
		var kind: String = biome["critters"][random.randi_range(0, biome["critters"].size() - 1)]
		var critter := Critter.create(kind, _world.cell_to_world(cell))
		add_child(critter)
		placed.append(critter)
	_by_chunk[chunk] = placed


func _place_node(placed: Array, id: String, cell: Vector2i, look: int, offset: Vector2 = Vector2.ZERO) -> void:
	if _gathered.has(cell) and _now() - _gathered[cell] < REGROW_SECONDS:
		return
	var node := ResourceNode.create(id, cell, _world.cell_to_world(cell) + offset)
	node.tall_look = look
	node.harvested.connect(func(gone: ResourceNode) -> void: _gathered[gone.cell] = _now())
	add_child(node)
	placed.append(node)


## A tree or bush that is only there to look at. `solid` > 0 blocks movement.
func _scenery(look: int, at: Vector2, solid: float) -> Node2D:
	var holder := Node2D.new()
	holder.position = at
	var sprite := Sprite2D.new()
	sprite.texture = Flora.TALL
	sprite.region_enabled = true
	sprite.region_rect = Flora.tall_region(look)
	sprite.position.y = -42.0
	sprite.flip_h = hash(at) % 2 == 0
	sprite.material = Wind.material
	holder.add_child(sprite)
	SunShadow.cast(sprite)
	if solid > 0.0:
		var body := StaticBody2D.new()
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = solid
		shape.shape = circle
		body.add_child(shape)
		holder.add_child(body)
	add_child(holder)
	return holder


func _on_chunk_freed(chunk: Vector2i) -> void:
	for node: Variant in _by_chunk.get(chunk, []):
		if is_instance_valid(node):
			node.queue_free()
	_by_chunk.erase(chunk)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
