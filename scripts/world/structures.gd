class_name Structures
extends Node2D
## Builds the fixed and scattered structures of the world as chunks load:
## the temple at the start, walled ruins, shrines, mini-boss lairs, cave
## mouths, and void portals. Where they stand comes from the world seed.
##
## Chests hold real contents, opened in a loot window; whatever is left in
## them, cleared lairs, and used shrines are remembered in the save.

const T := TerrainTiles.Type
## Chance per chunk of each structure, checked in this order.
const CHANCES: Array[Array] = [["ruin", 0.07], ["shrine", 0.03], ["cave", 0.035], ["lair", 0.03], ["portal", 0.02]]
## Lairs and portals only appear where the area is at least this level.
const MIN_LEVEL := {"lair": 3, "portal": 4}
## Nothing but the temple within this many tiles of the origin.
const CLEAR_RADIUS := 26.0
## How far a structure's grounds reach, in tiles: nothing grows inside.
const GROUNDS := 6.0
## Monsters that can rule a lair, by the ground it stands on.
const LAIR_BOSSES := {T.ASH: "crag_golem", T.CINDER: "crag_golem", T.SALT: "crag_golem", T.BOG: "spore_shambler", T.FUNGAL: "spore_shambler",
	T.ROCK: "crag_golem", T.PEAK: "ash_wraith", T.DARK_GRASS: "thorn_stalker", T.THORN: "thorn_stalker", T.SNOW: "ash_wraith",
	T.VOIDSCAR: "ash_wraith", T.SAND: "bone_archer", T.CRIMSON: "rot_hound", T.FROSTPINE: "rot_hound"}

## Keys of structures already used up, e.g. "lair:12,-3".
var used: Dictionary = {}
## What is still inside each structure chest: key -> [saved items].
var chests: Dictionary = {}

var _world: World
var _player: Player
var _spawner: EnemySpawner
var _loot: Node2D
var _instances: Instances
var _by_chunk: Dictionary = {}
var _sites: Dictionary = {}


func _ready() -> void:
	SaveGame.register("structures", self)


func setup(world: World, player: Player, spawner: EnemySpawner, loot: Node2D, instances: Instances) -> void:
	_world = world
	_player = player
	_spawner = spawner
	_loot = loot
	_instances = instances
	world.chunk_built.connect(_on_chunk_built)
	world.chunk_freed.connect(_on_chunk_freed)


func save_data() -> Dictionary:
	return {"used": used.keys(), "chests": chests.duplicate(true)}


func load_data(data: Dictionary) -> void:
	used.clear()
	for key: Variant in data.get("used", []):
		used[str(key)] = true
	var saved: Variant = data.get("chests", {})
	chests = saved if saved is Dictionary else {}


## What a chest holds: a few materials and gold, sometimes a potion, and gear
## if it is a rich one. `richness` 1 is a plain ruin chest.
static func roll_chest(level: int, richness: float) -> Array:
	var items: Array = [{"id": "gold_coins", "count": roundi(randf_range(8.0, 20.0) * pow(level, 0.9) * richness)}]
	var materials: Array[String] = ["stone", "copper_ore", "oak_wood", "healing_herb", "bone", "husk_fragment", "wild_berries", "torch"]
	for i in randi_range(2, 3):
		items.append(Item.create(materials.pick_random(), randi_range(1, 4)).to_dict())
	if randf() < 0.35 * richness:
		items.append(Item.create("health_potion", randi_range(1, 2)).to_dict())
	if randf() < 0.15 * richness * richness:
		var rarity := LootGenerator.roll_rarity(0.0, (richness - 1.0) * 4.0)
		items.append(LootGenerator.make_equipment(level, maxi(rarity, 2 if richness >= 2.0 else 0)).to_dict())
	if richness >= 2.0:
		items.append(Item.create("heart_shard").to_dict())
	return items


## The structure placed in a chunk, if any: {"kind", "cell", "key", "level"}.
func site_for(chunk: Vector2i) -> Dictionary:
	if _sites.has(chunk):
		return _sites[chunk]
	var site := {}
	var random := RandomNumberGenerator.new()
	random.seed = hash(Vector3i(chunk.x, chunk.y, _world.generator.world_seed + 4242))
	var cell := chunk * World.CHUNK_SIZE + Vector2i(random.randi_range(4, World.CHUNK_SIZE - 5), random.randi_range(4, World.CHUNK_SIZE - 5))
	var roll := random.randf()
	if Vector2(cell).length() > CLEAR_RADIUS and _clear_ground(cell):
		var level := _world.generator.enemy_level_at(cell)
		for entry in CHANCES:
			roll -= entry[1]
			if roll < 0.0:
				if level >= MIN_LEVEL.get(entry[0], 1):
					site = {"kind": entry[0], "cell": cell, "key": "%s:%d,%d" % [entry[0], chunk.x, chunk.y], "level": level, "seed": random.randi()}
				break
	_sites[chunk] = site
	return site


## Whether a tile lies on a structure's grounds (the temple counts).
func is_reserved(cell: Vector2i) -> bool:
	if Vector2(cell).length() < 10.0:
		return true
	var chunk := Vector2i((Vector2(cell) / World.CHUNK_SIZE).floor())
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var site := site_for(chunk + Vector2i(dx, dy))
			if not site.is_empty() and Vector2(cell - site["cell"]).length() <= GROUNDS:
				return true
	return false


func _on_chunk_built(chunk: Vector2i) -> void:
	var placed: Array = []
	var bounds := Rect2i(chunk * World.CHUNK_SIZE, Vector2i(World.CHUNK_SIZE, World.CHUNK_SIZE))
	if bounds.has_point(Vector2i.ZERO):
		_build_temple(placed)
	var site := site_for(chunk)
	if not site.is_empty():
		var random := RandomNumberGenerator.new()
		random.seed = site["seed"]
		call("_build_" + site["kind"], site["cell"], site["key"], site["level"], random, placed)
	for node: Node in placed:
		if node.get_parent() == null:
			add_child(node)
	_by_chunk[chunk] = placed


func _on_chunk_freed(chunk: Vector2i) -> void:
	for node: Variant in _by_chunk.get(chunk, []):
		if is_instance_valid(node):
			node.queue_free()
	_by_chunk.erase(chunk)


## Open, dry ground for a few tiles around, and not in a village.
func _clear_ground(cell: Vector2i) -> bool:
	if _world.generator.village_near(cell) != null:
		return false
	for offset: Vector2i in [Vector2i.ZERO, Vector2i(3, 0), Vector2i(-3, 0), Vector2i(0, 3), Vector2i(0, -3)]:
		if not _world.generator.is_dry_land(cell + offset):
			return false
	return true


func _at(cell: Vector2i, offset: Vector2 = Vector2.ZERO) -> Vector2:
	return _world.cell_to_world(cell) + offset


## Paving laid flat under a structure.
func _floor(placed: Array, center: Vector2i, reach: int) -> void:
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			if Vector2(dx, dy).length() <= reach + 0.3:
				# One tile of the paving picture per tile, laid flat and dimmed.
				var slab := Sprite2D.new()
				slab.texture = Prop.DECOR
				slab.region_enabled = true
				var corner := Vector2(posmod(dx * 7 + dy * 3, 3) * 8 + 2, posmod(dx * 5 - dy, 2) * 10 + 2)
				slab.region_rect = Rect2(Vector2(Prop.Decor.FLOOR * 64, 0) + corner, Vector2(44, 44))
				slab.position = _at(center + Vector2i(dx, dy))
				slab.modulate = Color(0.78, 0.76, 0.8)
				slab.z_index = -8
				placed.append(slab)


func _decor(placed: Array, art: Prop.Decor, cell: Vector2i, solid: float = 0.0, lit: bool = false, offset: Vector2 = Vector2.ZERO) -> Prop:
	var prop := Prop.create_decor(art, _at(cell, offset), solid)
	if lit:
		prop.add_light(0.9, 1.8)
	placed.append(prop)
	return prop


## The Sanctuary: paving, a ring of pillars, statues, braziers, and the altar.
func _build_temple(placed: Array) -> void:
	_floor(placed, Vector2i(0, -1), 3)
	for index in 10:
		var angle := TAU * index / 10.0 + 0.3
		# Leave the south side open as the way out.
		if absf(angle_difference(angle, PI / 2.0)) > 0.5:
			placed.append(Prop.create(Prop.Art.PILLAR, _at(Vector2i(Vector2.from_angle(angle) * 6.5)), 9.0))
	_decor(placed, Prop.Decor.STATUE, Vector2i(-3, -5), 12.0)
	_decor(placed, Prop.Decor.STATUE, Vector2i(3, -5), 12.0)
	_decor(placed, Prop.Decor.BRAZIER, Vector2i(-2, -3), 8.0, true)
	_decor(placed, Prop.Decor.BRAZIER, Vector2i(2, -3), 8.0, true)
	_decor(placed, Prop.Decor.BANNER, Vector2i(-5, 1), 4.0)
	_decor(placed, Prop.Decor.BANNER, Vector2i(5, 1), 4.0)
	placed.append(_rest_spot(Prop.Art.ALTAR, Vector2i(0, -3), "the Sanctuary"))
	# A first weapon for the taking, so nobody has to fight bare-handed for long.
	if not used.has("temple:sword"):
		placed.append(_chest(Vector2i(0, -5), "temple:sword", 1, 0.0, [LootGenerator.make_equipment(1, 0, "sword").to_dict(), Item.create("bandage", 3).to_dict()]))


## Somewhere to rest: heals, and becomes where the player wakes after dying.
func _rest_spot(art: Prop.Art, cell: Vector2i, place_name: String) -> Prop:
	var spot := Prop.create(art, _at(cell), 11.0, "Rest here", func(player: Player) -> void:
		player.health.heal_full()
		player.stamina.fill()
		player.mana.fill()
		Events.checkpoint_set.emit(_at(cell) + Vector2(0, 40), place_name)
		Events.announcement.emit("RESTED", "You will wake at %s" % place_name)
		RingBurst.spawn(self, _at(cell) + Vector2(0, -14), Color(1.0, 0.8, 0.4), 70.0)
	)
	spot.add_light(1.0, 2.0)
	return spot


## A roofless stone hall: paving, broken walls with a doorway, pillars at the
## corners, rubble, a statue, a brazier, and a chest at the heart.
func _build_ruin(cell: Vector2i, key: String, level: int, random: RandomNumberGenerator, placed: Array) -> void:
	_floor(placed, cell, 3)
	for dx in range(-4, 5):
		for dy: int in [-4, 4]:
			if absi(dx) <= 1 and dy == 4:
				continue
			if random.randf() < 0.75:
				placed.append(Prop.create(Prop.Art.WALL, _at(cell + Vector2i(dx, dy)), 14.0))
	for dy in range(-3, 4):
		for dx: int in [-4, 4]:
			if random.randf() < 0.7:
				placed.append(Prop.create(Prop.Art.WALL, _at(cell + Vector2i(dx, dy)), 14.0))
	for corner: Vector2i in [Vector2i(-4, -4), Vector2i(4, -4), Vector2i(-4, 4), Vector2i(4, 4)]:
		placed.append(Prop.create(Prop.Art.PILLAR, _at(cell + corner + Vector2i(0, 1)), 9.0))
	for i in 3:
		_decor(placed, Prop.Decor.RUBBLE, cell + Vector2i(random.randi_range(-3, 3), random.randi_range(-3, 3)))
	_decor(placed, Prop.Decor.STATUE, cell + Vector2i(0, -3), 12.0)
	_decor(placed, Prop.Decor.BRAZIER, cell + Vector2i(-2, -2), 8.0, true)
	_decor(placed, Prop.Decor.BANNER, cell + Vector2i(2, -3), 4.0)
	placed.append(_chest(cell, key, level, 1.0))


## A standing stone ringed with candles. Praying there blesses the player
## for a while, once a day.
func _build_shrine(cell: Vector2i, key: String, _level: int, random: RandomNumberGenerator, placed: Array) -> void:
	_floor(placed, cell, 2)
	for index in 6:
		_decor(placed, Prop.Decor.CANDLES, cell + Vector2i(Vector2.from_angle(TAU * index / 6.0) * 2.2), 0.0, index % 2 == 0)
	_decor(placed, Prop.Decor.STATUE, cell + Vector2i(-2, -2), 12.0)
	_decor(placed, Prop.Decor.STATUE, cell + Vector2i(2, -2), 12.0)
	var stone := Prop.create_decor(Prop.Decor.OBELISK, _at(cell), 12.0, "Pray at the shrine")
	stone.add_light(0.7, 1.4)
	stone.on_interact = func(player: Player) -> void:
		var day: int = get_parent().get_node("DayNight").day
		var today := "%s:day%d" % [key, day]
		if used.has(today):
			Events.announcement.emit("", "The shrine is silent. Come back tomorrow.")
			return
		used[today] = true
		var blessings := [
			["Blessing of Might", {"physical_damage": {"percent": 0.12}}],
			["Blessing of Vigor", {"max_health": {"percent": 0.15}, "health_regen": {"flat": 1.0}}],
			["Blessing of Fortune", {"magic_find": {"flat": 0.2}, "gold_find": {"percent": 0.2}}],
			["Blessing of Haste", {"move_speed": {"percent": 0.1}, "attack_speed": {"percent": 0.08}}],
		]
		var blessing: Array = blessings[random.randi_range(0, blessings.size() - 1)]
		player.buffs.add("blessing", blessing[0], 300.0, blessing[1])
		Events.announcement.emit(blessing[0].to_upper(), "For five minutes")
		RingBurst.spawn(self, stone.global_position + Vector2(0, -20), Color(0.75, 0.55, 1.0), 90.0)
		SaveGame.request_save()
	placed.append(stone)


## A war camp: totems, cages, bone piles, a tent and fire, and a sealed
## chest guarded by a mini-boss.
func _build_lair(cell: Vector2i, key: String, level: int, random: RandomNumberGenerator, placed: Array) -> void:
	for index in 8:
		placed.append(Prop.create(Prop.Art.TOTEM, _at(cell + Vector2i(Vector2.from_angle(TAU * index / 8.0 + 0.4) * 5.0)), 6.0))
	_decor(placed, Prop.Decor.TENT, cell + Vector2i(-3, -2), 22.0)
	_decor(placed, Prop.Decor.CAGE, cell + Vector2i(3, -2), 16.0)
	_decor(placed, Prop.Decor.CAGE, cell + Vector2i(3, 2), 16.0)
	for i in 3:
		_decor(placed, Prop.Decor.BONES, cell + Vector2i(random.randi_range(-3, 3), random.randi_range(-1, 3)))
	_decor(placed, Prop.Decor.BANNER, cell + Vector2i(-1, -3), 4.0)
	_decor(placed, Prop.Decor.BANNER, cell + Vector2i(1, -3), 4.0)
	var fire := Prop.create(Prop.Art.CAMPFIRE, _at(cell + Vector2i(-2, 2)), 11.0)
	fire.add_light(1.0, 2.0)
	placed.append(fire)
	var chest := _chest(cell + Vector2i(0, -1), key, level, 2.0)
	placed.append(chest)
	if used.has(key + ":boss"):
		return
	var boss_id: String = LAIR_BOSSES.get(_world.generator.tile_type_at(cell), "husk")
	var boss := _spawner.spawn_at(_at(cell + Vector2i(0, 1)), level + 1, Enemy.Rank.MINIBOSS, boss_id)
	boss.lair_home = _at(cell)
	placed.append(boss)
	# The chest is sealed while its guardian lives.
	var open_prompt := chest.prompt_text
	var open_action := chest.on_interact
	chest.prompt_text = "Sealed while the guardian lives"
	chest.on_interact = Callable()
	boss.died.connect(func(_enemy: Enemy) -> void:
		used[key + ":boss"] = true
		if is_instance_valid(chest):
			chest.prompt_text = open_prompt
			chest.on_interact = open_action
	)


func _build_cave(cell: Vector2i, key: String, level: int, random: RandomNumberGenerator, placed: Array) -> void:
	var cave_seed := random.randi()
	var lair := random.randf() < 0.12 and not used.has(key + ":boss")
	_decor(placed, Prop.Decor.RUBBLE, cell + Vector2i(-2, 1))
	_decor(placed, Prop.Decor.RUBBLE, cell + Vector2i(2, 1))
	_decor(placed, Prop.Decor.BONES, cell + Vector2i(1, 2))
	_decor(placed, Prop.Decor.LANTERN, cell + Vector2i(-2, 0), 5.0, true)
	placed.append(Prop.create(Prop.Art.CAVE, _at(cell), 0.0, "Enter the cave", func(_player: Player) -> void:
		_instances.enter_cave(cave_seed, level, lair and not used.has(key + ":boss"), func() -> void:
			used[key + ":boss"] = true
			SaveGame.request_save()
		)
	))


func _build_portal(cell: Vector2i, key: String, level: int, random: RandomNumberGenerator, placed: Array) -> void:
	if used.has(key):
		_decor(placed, Prop.Decor.RUBBLE, cell)
		return
	_decor(placed, Prop.Decor.OBELISK, cell + Vector2i(-2, 0), 10.0, true)
	_decor(placed, Prop.Decor.OBELISK, cell + Vector2i(2, 0), 10.0, true)
	_decor(placed, Prop.Decor.CANDLES, cell + Vector2i(-1, 2))
	_decor(placed, Prop.Decor.CANDLES, cell + Vector2i(1, 2))
	var arena_seed := random.randi()
	var portal: Prop
	portal = Prop.create(Prop.Art.PORTAL, _at(cell), 0.0, "Step into the void portal", func(_player: Player) -> void:
		_instances.enter_arena(arena_seed, level, func() -> void:
			used[key] = true
			SaveGame.request_save()
			# The portal burns out once its arena is beaten.
			if is_instance_valid(portal):
				portal.queue_free()
		)
	)
	var tween := portal.create_tween().set_loops()
	tween.tween_property(portal.sprite(), "scale", Vector2(1.08, 1.08), 0.8)
	tween.tween_property(portal.sprite(), "scale", Vector2(0.95, 0.95), 0.8)
	placed.append(portal)


## A chest whose contents are rolled the first time it is opened (or given
## in `contents`) and kept in the save until taken.
func _chest(cell: Vector2i, key: String, level: int, richness: float, contents: Array = []) -> Prop:
	var emptied := chests.has(key) and (chests[key] as Array).is_empty()
	var chest := Prop.create(Prop.Art.CHEST_OPEN if emptied else Prop.Art.CHEST, _at(cell), 12.0, "Open the chest")
	chest.on_interact = func(_player: Player) -> void:
		if not chests.has(key):
			chests[key] = contents if not contents.is_empty() else roll_chest(level, richness)
			used[key] = true
		chest.set_art(Prop.Art.CHEST_OPEN)
		Events.loot_opened.emit({"items": chests[key], "title": "Chest", "take_only": true})
		SaveGame.request_save()
	return chest
