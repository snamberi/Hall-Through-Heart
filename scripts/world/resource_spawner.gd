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
## Where flowers grow in colonies.
var _patches := FastNoiseLite.new()
## chunk -> nodes placed for it
var _by_chunk: Dictionary = {}
## cell -> time it was gathered (seconds since start)
var _gathered: Dictionary = {}


func setup(world: World) -> void:
	_world = world
	_forest.seed = world.generator.world_seed + 3131
	_forest.frequency = 0.03
	_forest.fractal_octaves = 2
	_patches.seed = world.generator.world_seed + 5151
	_patches.frequency = 0.11
	_patches.fractal_octaves = 1
	world.chunk_built.connect(_on_chunk_built)
	world.chunk_freed.connect(_on_chunk_freed)


## The flowers, grass, stones and bones on one tile, in patterns rather
## than evenly: flowers grow in colonies of one kind, stones gather at the
## foot of cliffs, bones lie about old sites, mushrooms crowd round trees.
func _cover_tile(cover: GroundCover, cell: Vector2i, local: Vector2i, tile: int, biome: Dictionary, type_at: Callable,
		sites: Array[Vector2i], trees_at: Dictionary, random: RandomNumberGenerator) -> void:
	var center := _world.cell_to_world(cell)
	var spot := func() -> Vector2:
		return center + Vector2(random.randf_range(-18, 18), random.randf_range(-14, 18))
	var ground: Array = biome["ground"]
	# Under a cliff: rock fallen from above.
	var under_cliff := false
	for offset: Vector2i in [Vector2i(0, -1), Vector2i(0, -2), Vector2i(-1, -1), Vector2i(1, -1)]:
		if (type_at.call(local + offset) as int) in TerrainTiles.HIGH:
			under_cliff = not tile in TerrainTiles.HIGH
			break
	if under_cliff and random.randf() < 0.55:
		for k in random.randi_range(1, 3):
			cover.plants.append([spot.call(), Flora.STONES[0] if random.randf() < 0.8 else Flora.STONES[1], random.randf() < 0.5])
		if random.randf() < 0.4:
			cover.decals.append([spot.call(), Flora.PEBBLE_DECAL, random.randf() < 0.5])
		return
	# About an old site: bones, thicker the closer.
	for site: Vector2i in sites:
		var away := Vector2(cell - site).length()
		if away > Structures.GROUNDS and away < Structures.GROUNDS + 5.0 and random.randf() < 0.14 * (1.0 - (away - Structures.GROUNDS) / 5.0):
			cover.plants.append([spot.call(), Flora.BONES, random.randf() < 0.5])
			if random.randf() < 0.3:
				cover.decals.append([spot.call(), Flora.DUST_DECAL, random.randf() < 0.5])
			return
	var flowers: Array = ground.filter(func(index: int) -> bool: return index in Flora.FLOWERS)
	var mushrooms: Array = ground.filter(func(index: int) -> bool: return index in Flora.MUSHROOMS)
	var plain: Array = ground.filter(func(index: int) -> bool: return not index in Flora.FLOWERS and not index in Flora.MUSHROOMS)
	# Beside a tree: mushrooms in its shade.
	if not mushrooms.is_empty() and random.randf() < 0.45:
		for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if trees_at.has(cell + offset):
				for k in random.randi_range(1, 2):
					cover.plants.append([spot.call(), mushrooms[random.randi_range(0, mushrooms.size() - 1)], random.randf() < 0.5])
				return
	var patch := _patches.get_noise_2d(cell.x, cell.y)
	if patch > 0.22 and not flowers.is_empty():
		# A colony: one kind of flower across the patch, thick in its middle.
		if random.randf() < biome["cover"] * 1.5:
			var region := Vector2i((Vector2(cell) / 7.0).floor())
			var kind: int = flowers[posmod(hash(region), flowers.size())]
			for k in (2 if patch > 0.4 else 1) + random.randi_range(0, 1):
				var pick: int = kind if random.randf() < 0.8 else ground[random.randi_range(0, ground.size() - 1)]
				cover.plants.append([spot.call(), pick, random.randf() < 0.5])
		return
	# Between patches: grass, stones and the like, and only a stray flower.
	if random.randf() < biome["cover"] * 0.8:
		var choices: Array = plain if not plain.is_empty() and random.randf() < 0.88 else ground
		for k in (1 if random.randf() < 0.6 else 2):
			cover.plants.append([spot.call(), choices[random.randi_range(0, choices.size() - 1)], random.randf() < 0.5])


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

	# The chunk's terrain with a two-tile border, looked up once, so the
	# ground cover can see what is around each tile.
	var span := World.CHUNK_SIZE + 4
	var types: PackedInt32Array = []
	types.resize(span * span)
	for y in span:
		for x in span:
			types[y * span + x] = generator.tile_type_at(origin + Vector2i(x - 2, y - 2))
	var type_at := func(local: Vector2i) -> int:
		return types[(local.y + 2) * span + local.x + 2]
	# Old sites nearby, where bones lie scattered.
	var sites: Array[Vector2i] = []
	if structures:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var site := structures.site_for(chunk + Vector2i(dx, dy))
				if not site.is_empty() and site["kind"] in ["ruin", "lair", "boss", "shipwreck", "camp"]:
					sites.append(site["cell"])
	var trees_at := {}

	# Woods, bushes, scenery, and ground cover, tile by tile.
	for y in World.CHUNK_SIZE:
		for x in World.CHUNK_SIZE:
			var cell := origin + Vector2i(x, y)
			if used.has(cell) or Vector2(cell).length() < CLEAR_RADIUS or keep_clear.call(cell):
				continue
			var tile: int = type_at.call(Vector2i(x, y))
			var biome: Dictionary = Flora.BIOMES.get(tile, {})
			if biome.is_empty():
				continue
			var roll := random.randf()
			var tree_chance: float = biome["forest"] * (0.08 + 0.55 * forest_at(cell) * forest_at(cell))
			var jitter := Vector2(random.randf_range(-14, 14), random.randf_range(-12, 12))
			if roll < tree_chance and not biome["trees"].is_empty():
				used[cell] = true
				trees_at[cell] = true
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
			_cover_tile(cover, cell, Vector2i(x, y), tile, biome, type_at, sites, trees_at, random)
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
