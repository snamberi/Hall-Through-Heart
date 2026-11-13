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
const CHANCES: Array[Array] = [["ruin", 0.07], ["shrine", 0.03], ["cave", 0.035], ["lair", 0.03], ["portal", 0.02], ["dungeon", 0.014], ["boss", 0.009],
	["camp", 0.04], ["waystone", 0.025], ["obelisk", 0.015], ["merchant", 0.015],
	["watchtower", 0.02], ["graveyard", 0.02], ["henge", 0.015], ["farmstead", 0.02], ["library", 0.012], ["dojo", 0.006]]
## Notes left in abandoned camps.
const NOTES: Array[String] = [
	"Day nine. The husks came again at dusk. We burned the fence to keep them back. No fence now.",
	"To whoever finds this: the stones by the road still wake if you touch them. They took us halfway home.",
	"Marta says the Heart beats under the world. I say it's the ground settling. We'll see who's right.",
	"Left the good knife in the crate. If you're reading this, it's yours. We won't be back.",
	"The bounty board said ten gold for the beast. It took three of us. Ten gold.",
	"Rain for four days. The bog has crept to the tents. Something moves in it at night.",
	"Saw lights over the void scar. Not fires. They moved against the wind.",
	"Buried the rest of the coin where the map says. Burned the copy. Kept this one.",
	"The old ones built those crypts to keep something in, not out. Remember that.",
	"If the moon turns red, stay by the fire. Do not go out. Do not answer them.",
]
## How far an obelisk shows the land around it, in tiles.
const OBELISK_SIGHT := 90
## Lairs and portals only appear where the area is at least this level.
const MIN_LEVEL := {"lair": 3, "portal": 4, "dungeon": 4, "boss": 6, "watchtower": 2, "graveyard": 2}
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
## World boss arena key -> the day its boss was last beaten.
var boss_days: Dictionary = {}
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
	return {"used": used.keys(), "chests": chests.duplicate(true), "boss_days": boss_days.duplicate(), "broken": Prop.broken.keys()}


func load_data(data: Dictionary) -> void:
	used.clear()
	for key: Variant in data.get("used", []):
		used[str(key)] = true
	var saved: Variant = data.get("chests", {})
	chests = saved if saved is Dictionary else {}
	var days: Variant = data.get("boss_days", {})
	boss_days = days if days is Dictionary else {}
	Prop.broken.clear()
	for key: Variant in data.get("broken", []):
		Prop.broken[str(key)] = true


## What a chest holds: a few materials and gold, sometimes a potion, and gear
## if it is a rich one. `richness` 1 is a plain ruin chest.
static func roll_chest(level: int, richness: float) -> Array:
	var items: Array = [{"id": "gold_coins", "count": roundi(randf_range(8.0, 20.0) * pow(level, 0.9) * richness)}]
	var materials: Array[String] = ["stone", "copper_ore", "oak_wood", "healing_herb", "bone", "husk_fragment", "wild_berries", "torch", "wheat_seeds", "carrot_seeds", "pumpkin_seeds"]
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
	# The Altar of Magic has a chunk to itself.
	var altar := _world.generator.magic_altar_cell()
	if Vector2i((Vector2(altar) / World.CHUNK_SIZE).floor()) == chunk:
		site = {"kind": "altar", "cell": altar, "key": "altar", "level": _world.generator.enemy_level_at(altar), "seed": 7177}
		_sites[chunk] = site
		return site
	var random := RandomNumberGenerator.new()
	random.seed = hash(Vector3i(chunk.x, chunk.y, _world.generator.world_seed + 4242))
	var cell := chunk * World.CHUNK_SIZE + Vector2i(random.randi_range(4, World.CHUNK_SIZE - 5), random.randi_range(4, World.CHUNK_SIZE - 5))
	var roll := random.randf()
	if Vector2(cell).length() > CLEAR_RADIUS and _world.generator.is_island(cell) and _clear_ground(cell) and roll < 0.4:
		# Islands keep wrecks, and what the sea did not take.
		site = {"kind": "shipwreck", "cell": cell, "key": "shipwreck:%d,%d" % [chunk.x, chunk.y], "level": _world.generator.enemy_level_at(cell), "seed": random.randi()}
	elif Vector2(cell).length() > CLEAR_RADIUS and _clear_ground(cell):
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


## Paving laid flat under a structure, one flagstone tile per world tile
## (tools/generate_floors.py). The rim uses worn tiles with stones missing,
## so the floor crumbles into the ground around it.
const FLOORS: Texture2D = preload("res://assets/tiles/floors.png")
const FLOOR_STYLES: Array[String] = ["temple", "ruin", "shrine", "basalt"]


func _floor(placed: Array, center: Vector2i, reach: int, style: String = "ruin") -> void:
	var row := maxi(FLOOR_STYLES.find(style), 0)
	var inside := func(dx: int, dy: int) -> bool: return Vector2(dx, dy).length() <= reach + 0.3
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			if not inside.call(dx, dy):
				continue
			var rim: bool = not (inside.call(dx + 1, dy) and inside.call(dx - 1, dy) and inside.call(dx, dy + 1) and inside.call(dx, dy - 1))
			var pick := posmod(hash(Vector3i(center.x + dx, center.y + dy, row)), 97)
			# Now and then a worn tile inside too, so big floors look old.
			var worn := rim or (reach >= 3 and pick % 13 == 0 and style != "temple")
			var column := (4 if worn else 0) + pick % 4
			var slab := Sprite2D.new()
			slab.texture = FLOORS
			slab.region_enabled = true
			slab.region_rect = Rect2(column * 44, row * 44, 44, 44)
			slab.position = _at(center + Vector2i(dx, dy))
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
	_floor(placed, Vector2i(0, -1), 3, "temple")
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
	placed.append(_waystones().make_stone("sanctuary", "The Sanctuary", Vector2i(3, 4)))
	# A first weapon for the taking, so nobody has to fight bare-handed for long.
	if not used.has("temple:sword"):
		placed.append(_chest(Vector2i(0, -5), "temple:sword", 1, 0.0, [LootGenerator.make_equipment(1, 0, "sword").to_dict(), Item.create("bandage", 3).to_dict(), Item.create("torch", 4).to_dict()]))


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
	# Walls in runs with gaps where they have fallen, and a doorway to the south.
	var wall_cells: Array = []
	var fallen: Array[Vector2i] = []
	for dx in range(-4, 5):
		for dy: int in [-4, 4]:
			if absi(dx) <= 1 and dy == 4:
				continue
			if random.randf() < 0.8:
				wall_cells.append(cell + Vector2i(dx, dy))
			else:
				fallen.append(cell + Vector2i(dx, dy))
	for dy in range(-3, 4):
		for dx: int in [-4, 4]:
			if random.randf() < 0.75:
				wall_cells.append(cell + Vector2i(dx, dy))
			else:
				fallen.append(cell + Vector2i(dx, dy))
	for piece in StoneWall.build(wall_cells, func(c: Vector2i) -> Vector2: return _at(c)):
		placed.append(piece)
	# Where the wall came down, its blocks still lie in a heap.
	for gap: Vector2i in fallen:
		if random.randf() < 0.7:
			_decor(placed, Prop.Decor.RUBBLE, gap, 0.0, false, Vector2(random.randf_range(-6.0, 6.0), random.randf_range(-4.0, 6.0)))
	for corner: Vector2i in [Vector2i(-4, -4), Vector2i(4, -4), Vector2i(-4, 4), Vector2i(4, 4)]:
		placed.append(Prop.create(Prop.Art.PILLAR, _at(cell + corner + Vector2i(0, 1)), 9.0))
	for i in 3:
		_decor(placed, Prop.Decor.RUBBLE, cell + Vector2i(random.randi_range(-3, 3), random.randi_range(-3, 3)))
	_decor(placed, Prop.Decor.STATUE, cell + Vector2i(0, -3), 12.0)
	_decor(placed, Prop.Decor.BRAZIER, cell + Vector2i(-2, -2), 8.0, true)
	_decor(placed, Prop.Decor.BANNER, cell + Vector2i(2, -3), 4.0)
	placed.append(_chest(cell, key, level, 1.0))


## The Altar of Magic: a raised stone ring of obelisks and candles round an
## altar that burns violet, with a pillar of light that shows from afar.
## There the player takes up (or changes) their school of magic.
func _build_altar(cell: Vector2i, _key: String, _level: int, random: RandomNumberGenerator, placed: Array) -> void:
	_floor(placed, cell, 5, "shrine")
	for index in 8:
		var spot := cell + Vector2i(Vector2.from_angle(TAU * index / 8.0 + 0.2) * 4.6)
		if index % 2 == 0:
			_decor(placed, Prop.Decor.OBELISK, spot, 10.0)
		else:
			_decor(placed, Prop.Decor.CANDLES, spot, 0.0, true)
	for i in 3:
		_decor(placed, Prop.Decor.RUBBLE, cell + Vector2i(random.randi_range(-4, 4), random.randi_range(3, 5)))
	var altar := Prop.create(Prop.Art.ALTAR, _at(cell), 14.0, "Commune with the altar", func(_player: Player) -> void:
		Events.screen_requested.emit("magic")
	)
	altar.add_light(1.1, 2.6)
	placed.append(altar)
	var beam := AltarBeam.new()
	beam.position = _at(cell) + Vector2(0, -30)
	placed.append(beam)


## A standing stone ringed with candles. Praying there blesses the player
## for a while, once a day.
func _build_shrine(cell: Vector2i, key: String, _level: int, random: RandomNumberGenerator, placed: Array) -> void:
	_floor(placed, cell, 2, "shrine")
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
	placed.append(_tent(cell + Vector2i(-3, -2), key, level + 1, "Raiders' tent"))
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
	var portal := Prop.create(Prop.Art.PORTAL, _at(cell), 0.0, "Step into the void portal")
	portal.on_interact = func(_player: Player) -> void:
		_instances.enter_arena(arena_seed, level, func() -> void:
			used[key] = true
			SaveGame.request_save()
			# The portal burns out once its arena is beaten.
			if is_instance_valid(portal):
				portal.queue_free()
		)
	var tween := portal.create_tween().set_loops()
	tween.tween_property(portal.sprite(), "scale", Vector2(1.08, 1.08), 0.8)
	tween.tween_property(portal.sprite(), "scale", Vector2(0.95, 0.95), 0.8)
	placed.append(portal)


## A world boss's arena: a paved ring of braziers and banners. The boss
## waits in the middle, and comes back some days after it is beaten.
func _build_boss(cell: Vector2i, key: String, level: int, random: RandomNumberGenerator, placed: Array) -> void:
	var boss_id := BossDB.for_site(_world.generator.tile_type_at(cell), level, hash(key))
	var data: Dictionary = BossDB.BOSSES[boss_id]
	_floor(placed, cell, 5, "basalt")
	for index in 10:
		var spot := cell + Vector2i(Vector2.from_angle(TAU * index / 10.0) * 6.0)
		if index % 2 == 0:
			_decor(placed, Prop.Decor.BRAZIER, spot, 10.0, true)
		else:
			_decor(placed, Prop.Decor.OBELISK, spot, 10.0)
	_decor(placed, Prop.Decor.BANNER, cell + Vector2i(-2, -6), 4.0)
	_decor(placed, Prop.Decor.BANNER, cell + Vector2i(2, -6), 4.0)
	for i in 4:
		_decor(placed, Prop.Decor.BONES, cell + Vector2i(random.randi_range(-4, 4), random.randi_range(-4, 4)))
	var day: int = (get_parent().get_node("DayNight") as DayNight).day
	var beaten: int = int(boss_days.get(key, -999))
	var sign := Prop.create_decor(Prop.Decor.SIGNPOST, _at(cell + Vector2i(0, 7)), 0.0, "%s's arena" % data["name"] if day - beaten >= BossDB.RESPAWN_DAYS else "%s returns in %d days" % [data["name"], BossDB.RESPAWN_DAYS - (day - beaten)])
	placed.append(sign)
	if day - beaten < BossDB.RESPAWN_DAYS:
		# Treasure left behind is still waiting.
		var left_key := "%s:%d" % [key, beaten]
		if chests.has(left_key) and not (chests[left_key] as Array).is_empty():
			placed.append(_chest(cell, left_key, level, 3.0))
		return
	var boss: Enemy = _spawner.enemy_scene.instantiate()
	boss.boss_id = boss_id
	boss.position = _at(cell)
	boss.target = _player
	boss.configure(level + 3, Enemy.Rank.BOSS, data["monster"])
	boss.lair_home = _at(cell)
	boss.wants_minion.connect(func(from: Enemy) -> void:
		_spawner.spawn_at(from.global_position + Vector2.from_angle(randf() * TAU) * 70.0, from.level, Enemy.Rank.NORMAL, from.enemy_id)
	)
	_spawner.add_child(boss)
	placed.append(boss)
	boss.died.connect(func(_enemy: Enemy) -> void:
		var now: int = (get_parent().get_node("DayNight") as DayNight).day
		boss_days[key] = now
		var chest_key := "%s:%d" % [key, now]
		var chest := _chest(cell, chest_key, level, 3.0, BossDB.drops(boss_id, level + 3))
		add_child(chest)
		placed.append(chest)
		LightPillar.spawn(get_parent(), _at(cell), data["color"])
		Events.announcement.emit("%s HAS FALLEN" % (data["name"] as String).to_upper(), "Its treasure lies in the arena")
		Events.boss_defeated.emit(boss_id)
		SaveGame.request_save()
	)


func _waystones() -> Waystones:
	return get_parent().get_node("Waystones")


## An abandoned camp: a cold fire, a torn tent, crates, and a note.
func _build_camp(cell: Vector2i, key: String, level: int, random: RandomNumberGenerator, placed: Array) -> void:
	placed.append(_tent(cell + Vector2i(-2, -1), key, level, "Abandoned tent"))
	var fire := Prop.create(Prop.Art.CAMPFIRE, _at(cell + Vector2i(1, 1)), 11.0)
	fire.sprite().modulate = Color(0.55, 0.5, 0.5)
	placed.append(fire)
	_decor(placed, Prop.Decor.CRATE, cell + Vector2i(2, -1), 10.0)
	_decor(placed, Prop.Decor.BARREL, cell + Vector2i(3, 0), 10.0)
	_decor(placed, Prop.Decor.BONES, cell + Vector2i(-1, 2))
	var note: String = NOTES[random.randi_range(0, NOTES.size() - 1)]
	placed.append(Prop.create_decor(Prop.Decor.SIGNPOST, _at(cell + Vector2i(0, 2)), 0.0, "Read the note", func(_p: Player) -> void:
		Events.announcement.emit("A NOTE", note)
		Events.codex_event.emit("notes", 1)
	))
	var contents: Array = roll_chest(level, 1.2)
	if random.randf() < 0.3:
		contents.append(Item.create("treasure_map").to_dict())
	placed.append(_chest(cell + Vector2i(2, 1), key, level, 1.2, contents))


## A waystone in the wilds.
func _build_waystone(cell: Vector2i, key: String, _level: int, _random: RandomNumberGenerator, placed: Array) -> void:
	_floor(placed, cell, 1)
	var biome: String = TerrainTiles.Type.keys()[_world.generator.tile_type_at(cell + Vector2i(2, 2))].capitalize()
	placed.append(_waystones().make_stone(key, "Waystone (%s, %d, %d)" % [biome, cell.x, cell.y], cell))
	_decor(placed, Prop.Decor.CANDLES, cell + Vector2i(-1, 1))
	_decor(placed, Prop.Decor.CANDLES, cell + Vector2i(1, 1))


## An ancient obelisk: touching it shows the land for miles around.
func _build_obelisk(cell: Vector2i, key: String, _level: int, _random: RandomNumberGenerator, placed: Array) -> void:
	_floor(placed, cell, 2)
	var read := used.has(key)
	var obelisk := Prop.create_decor(Prop.Decor.OBELISK, _at(cell), 12.0, "The obelisk is silent" if read else "Lay a hand on the obelisk")
	obelisk.sprite().scale = Vector2(1.5, 1.5)
	obelisk.sprite().position.y *= 1.5
	obelisk.sprite().modulate = Color(0.9, 0.8, 1.0) if not read else Color(0.6, 0.6, 0.65)
	if not read:
		obelisk.add_light(0.9, 1.6)
		obelisk.on_interact = func(player: Player) -> void:
			if used.has(key):
				return
			used[key] = true
			(get_parent().get_node("Exploration") as Exploration).reveal(cell, OBELISK_SIGHT)
			player.leveling.add_xp(30 * level_xp(_level), "explore")
			LightPillar.spawn(get_parent(), _at(cell), Color(0.85, 0.75, 1.0))
			Events.announcement.emit("THE LAND IS REVEALED", "Your map shows the country around the obelisk")
			Events.codex_event.emit("obelisks", 1)
			obelisk.prompt_text = "The obelisk is silent"
			obelisk.on_interact = Callable()
			SaveGame.request_save()
	placed.append(obelisk)
	for index in 4:
		_decor(placed, Prop.Decor.RUBBLE, cell + Vector2i(Vector2.from_angle(TAU * index / 4.0 + 0.7) * 3.0))


static func level_xp(level: int) -> int:
	return maxi(level, 1)


## A wandering merchant's camp: rarer wares than any village stall.
func _build_merchant(cell: Vector2i, _key: String, _level: int, _random: RandomNumberGenerator, placed: Array) -> void:
	_decor(placed, Prop.Decor.STALL, cell + Vector2i(0, -1), 18.0)
	_decor(placed, Prop.Decor.TENT, cell + Vector2i(-3, -1), 22.0)
	_decor(placed, Prop.Decor.BARREL, cell + Vector2i(2, -1), 10.0)
	_decor(placed, Prop.Decor.LANTERN, cell + Vector2i(2, 1), 5.0, true)
	var fire := Prop.create(Prop.Art.CAMPFIRE, _at(cell + Vector2i(-1, 2)), 11.0)
	fire.add_light(1.0, 2.0)
	placed.append(fire)
	var npc := Npc.create("merchant", _at(cell, Vector2(0, 16)))
	npc.wandering = true
	placed.append(npc)


## A wreck on an island shore: broken planks, spilled cargo, and a sea chest.
func _build_shipwreck(cell: Vector2i, key: String, level: int, random: RandomNumberGenerator, placed: Array) -> void:
	for i in 6:
		_decor(placed, [Prop.Decor.CRATE, Prop.Decor.BARREL, Prop.Decor.RUBBLE][random.randi_range(0, 2)], cell + Vector2i(random.randi_range(-4, 4), random.randi_range(-3, 3)), 0.0)
	_decor(placed, Prop.Decor.BANNER, cell + Vector2i(-2, -2), 4.0)
	_decor(placed, Prop.Decor.BONES, cell + Vector2i(1, 2))
	var contents: Array = roll_chest(level + 5, 2.5)
	contents.append(Item.create("treasure_map").to_dict())
	if random.randf() < 0.25:
		contents.append(LootGenerator.make_unique(level + 5).to_dict())
	placed.append(_chest(cell, key, level + 5, 2.5, contents))
	if not used.has(key + ":guard"):
		var guard := _spawner.spawn_at(_at(cell + Vector2i(2, 0)), level + 5, Enemy.Rank.CHAMPION, "bog_lurker" if random.randf() < 0.5 else "crimson_fiend")
		guard.lair_home = _at(cell)
		placed.append(guard)
		guard.died.connect(func(_e: Enemy) -> void: used[key + ":guard"] = true)


## A crypt's entrance: steps down into a dungeon of locked rooms.
func _build_dungeon(cell: Vector2i, key: String, level: int, random: RandomNumberGenerator, placed: Array) -> void:
	var dungeon_seed := random.randi()
	var boss_id := BossDB.for_site(_world.generator.tile_type_at(cell), level, dungeon_seed)
	_floor(placed, cell, 3, "basalt")
	_decor(placed, Prop.Decor.OBELISK, cell + Vector2i(-2, -1), 10.0)
	_decor(placed, Prop.Decor.OBELISK, cell + Vector2i(2, -1), 10.0)
	_decor(placed, Prop.Decor.STATUE, cell + Vector2i(-3, 1), 12.0)
	_decor(placed, Prop.Decor.STATUE, cell + Vector2i(3, 1), 12.0)
	_decor(placed, Prop.Decor.BRAZIER, cell + Vector2i(-1, 2), 8.0, true)
	_decor(placed, Prop.Decor.BRAZIER, cell + Vector2i(1, 2), 8.0, true)
	var cleared := used.has(key + ":cleared")
	var entrance := Prop.create(Prop.Art.CAVE, _at(cell), 0.0, "Descend into the crypt" + ("  (cleared)" if cleared else ""), func(_player: Player) -> void:
		_instances.enter_dungeon(dungeon_seed, level + 1, boss_id, func() -> void:
			used[key + ":cleared"] = true
			SaveGame.request_save()
		)
	)
	entrance.sprite().modulate = Color(0.7, 0.65, 0.8)
	placed.append(entrance)


## A ruined watchtower: the stump of a round tower on old paving, fallen
## blocks, a lookout's brazier, and archers holding it until its chest is
## taken.
func _build_watchtower(cell: Vector2i, key: String, level: int, random: RandomNumberGenerator, placed: Array) -> void:
	_floor(placed, cell + Vector2i(0, 1), 2)
	_decor(placed, Prop.Decor.RUINED_TOWER, cell, 26.0)
	for i in 4:
		_decor(placed, Prop.Decor.RUBBLE, cell + Vector2i(random.randi_range(-3, 3), random.randi_range(1, 3)), 0.0, false, Vector2(random.randf_range(-8.0, 8.0), 0))
	_decor(placed, Prop.Decor.BRAZIER, cell + Vector2i(2, 2), 8.0, true)
	_decor(placed, Prop.Decor.BANNER, cell + Vector2i(-2, 1), 4.0)
	_decor(placed, Prop.Decor.CRATE, cell + Vector2i(-2, 3), 10.0)
	placed.append(_chest(cell + Vector2i(1, 3), key, level, 1.3))
	if used.has(key):
		return
	for spot: Vector2i in [Vector2i(-3, 2), Vector2i(3, 1)]:
		placed.append(_spawner.spawn_at(_at(cell + spot), level, Enemy.Rank.NORMAL, "bone_archer"))


## An old graveyard: rows of headstones inside a broken fence, candles on
## a few graves, and a crypt chest the dead still guard.
func _build_graveyard(cell: Vector2i, key: String, level: int, random: RandomNumberGenerator, placed: Array) -> void:
	for dx in range(-4, 5):
		for dy: int in [-4, 4]:
			if absi(dx) > 1 or dy == -4:
				if random.randf() < 0.8:
					_decor(placed, Prop.Decor.FENCE, cell + Vector2i(dx, dy), 8.0)
	for dy in range(-3, 4):
		for dx: int in [-4, 4]:
			if random.randf() < 0.8:
				_decor(placed, Prop.Decor.FENCE, cell + Vector2i(dx, dy), 8.0)
	for row in 3:
		for column in 4:
			if random.randf() < 0.85:
				var grave := cell + Vector2i(-3 + column * 2, -3 + row * 2)
				if grave == cell + Vector2i(1, -1):
					continue
				_decor(placed, Prop.Decor.GRAVESTONE, grave, 8.0, false, Vector2(random.randf_range(-4.0, 4.0), 0))
				if random.randf() < 0.25:
					_decor(placed, Prop.Decor.CANDLES, grave + Vector2i(0, 1), 0.0, true)
	_floor(placed, cell + Vector2i(0, 2), 1)
	_decor(placed, Prop.Decor.BONES, cell + Vector2i(-1, 2))
	var contents: Array = roll_chest(level, 1.5)
	contents.append(Item.create("bone", random.randi_range(2, 5)).to_dict())
	placed.append(_chest(cell + Vector2i(0, 2), key, level, 1.5, contents))
	if used.has(key):
		return
	for spot: Vector2i in [Vector2i(-2, 1), Vector2i(2, 1), Vector2i(0, -2)]:
		placed.append(_spawner.spawn_at(_at(cell + spot), level, Enemy.Rank.NORMAL, "husk" if spot.y > 0 else "bone_archer"))


## Standing stones: a ring of carved menhirs round a capstone. Laying a
## hand on it blesses the traveller for a while.
func _build_henge(cell: Vector2i, _key: String, _level: int, random: RandomNumberGenerator, placed: Array) -> void:
	_floor(placed, cell, 1)
	for index in 8:
		var spot := cell + Vector2i((Vector2.from_angle(TAU * index / 8.0 + 0.2) * Vector2(4.2, 3.6)).round())
		if random.randf() < 0.85:
			_decor(placed, Prop.Decor.WAYSTONE, spot, 10.0)
		else:
			_decor(placed, Prop.Decor.RUBBLE, spot)
	var stone := Prop.create_decor(Prop.Decor.OBELISK, _at(cell), 12.0, "Lay a hand on the old stone", func(player: Player) -> void:
		player.buffs.add("henge", "Blessing of the Stones", 300.0, {"physical_damage": {"percent": 0.08}, "magic_power": {"percent": 0.08}, "health_regen": {"flat": 1.0}}, null, "blessing")
		Events.announcement.emit("BLESSING OF THE STONES", "Stronger blows and spells, and wounds that close, for five minutes.")
		Audio.play("level_up", -8.0, 0.0)
	)
	stone.add_light(0.5, 1.2, Waystones.GLOW)
	placed.append(stone)


## An abandoned farmstead: a cottage, plots gone to weeds, a scarecrow, a
## well and a tipped cart, with seed and food left in the store.
func _build_farmstead(cell: Vector2i, key: String, level: int, random: RandomNumberGenerator, placed: Array) -> void:
	var house := Prop.create(Prop.Art.HOUSE, _at(cell + Vector2i(-2, -2)), 30.0, "Enter the farmhouse", func(_p: Player) -> void:
		_instances.enter_dwelling("cottage", "Farmhouse", level, hash(key), used.has(key + ":inside"), func() -> void: used[key + ":inside"] = true)
	)
	HouseStyles.dress(house, _world.generator.tile_type_at(cell))
	placed.append(house)
	for row in 2:
		for column in 3:
			_decor(placed, Prop.Decor.SOIL, cell + Vector2i(1 + column, row))
	_decor(placed, Prop.Decor.SCARECROW, cell + Vector2i(2, 2), 6.0)
	_decor(placed, Prop.Decor.WELL, cell + Vector2i(-3, 2), 14.0)
	_decor(placed, Prop.Decor.CART, cell + Vector2i(0, 3), 14.0)
	_decor(placed, Prop.Decor.BARREL, cell + Vector2i(-1, 0), 10.0)
	for dx in range(0, 5):
		if random.randf() < 0.7:
			_decor(placed, Prop.Decor.FENCE, cell + Vector2i(dx, -2), 8.0)
	var seeds: Array[String] = ["wheat_seeds", "carrot_seeds", "potato_seeds", "pumpkin_seeds"]
	var contents: Array = roll_chest(level, 0.8)
	for i in 2:
		contents.append(Item.create(seeds[random.randi_range(0, seeds.size() - 1)], random.randi_range(2, 5)).to_dict())
	contents.append(Item.create("bread", random.randi_range(1, 3)).to_dict())
	placed.append(_chest(cell + Vector2i(-2, 0), key, level, 0.8, contents))


## A ruined library: broken walls round shelves of rotten books, a reading
## table lit by candles, and one book still worth reading.
## A master's shrine: a quiet paved square with braziers and banners where
## a master of one legendary combat style waits to teach it.
func _build_dojo(cell: Vector2i, key: String, level: int, random: RandomNumberGenerator, placed: Array) -> void:
	_floor(placed, cell, 3, "shrine")
	var legendary: Array = CombatStyles.STYLES.keys().filter(func(id: String) -> bool: return id != "fist")
	var style: String = legendary[absi(hash(key)) % legendary.size()]
	var info: Dictionary = CombatStyles.STYLES[style]
	for dx: int in [-3, 3]:
		_decor(placed, Prop.Decor.BRAZIER, cell + Vector2i(dx, -2), 8.0, true)
		_decor(placed, Prop.Decor.BANNER, cell + Vector2i(dx, 1), 6.0)
	_decor(placed, Prop.Decor.STATUE, cell + Vector2i(0, -3), 12.0)
	_decor(placed, Prop.Decor.RUG, cell + Vector2i(0, 1))
	var master := Npc.create("master", _at(cell + Vector2i(0, -1)))
	master.offer = {"style": style}
	master.title_text = info["teacher"]
	master.prompt_text = "Speak with %s" % info["teacher"]
	master.tint = (info["color"] as Color).lightened(0.2)
	placed.append(master)


func _build_library(cell: Vector2i, key: String, level: int, random: RandomNumberGenerator, placed: Array) -> void:
	_floor(placed, cell, 3, "temple")
	var wall_cells: Array = []
	for dx in range(-4, 5):
		if random.randf() < 0.75:
			wall_cells.append(cell + Vector2i(dx, -4))
	for dy in range(-3, 3):
		for dx: int in [-4, 4]:
			if random.randf() < 0.6:
				wall_cells.append(cell + Vector2i(dx, dy))
	for piece in StoneWall.build(wall_cells, func(c: Vector2i) -> Vector2: return _at(c)):
		placed.append(piece)
	for dx: int in [-3, -1, 1, 3]:
		_decor(placed, Prop.Decor.SHELF, cell + Vector2i(dx, -3), 12.0)
	_decor(placed, Prop.Decor.CHAIR, cell + Vector2i(-1, 1))
	_decor(placed, Prop.Decor.CANDLES, cell + Vector2i(1, 1), 0.0, true)
	_decor(placed, Prop.Decor.RUBBLE, cell + Vector2i(3, 2))
	var read_key := key + ":read"
	var table := Prop.create_decor(Prop.Decor.TABLE, _at(cell), 14.0, "The book is read" if used.has(read_key) else "Read the old book")
	table.on_interact = func(player: Player) -> void:
		if used.has(read_key):
			return
		used[read_key] = true
		var gained := maxi(40, roundi(player.leveling.xp_to_next() * 0.2))
		player.leveling.add_xp(gained, "library")
		table.prompt_text = "The book is read"
		Events.announcement.emit("AN OLD BOOK", "You read until the candles gutter. +%d experience." % gained)
		Events.codex_event.emit("notes", 1)
		SaveGame.request_save()
	placed.append(table)
	placed.append(_chest(cell + Vector2i(2, -1), key, level, 1.2))


## A tent that can be entered: inside are a bedroll, candles, a crate and
## a chest worth opening once.
func _tent(cell: Vector2i, key: String, level: int, title: String) -> Prop:
	var inside := key + ":tent"
	return Prop.create_decor(Prop.Decor.TENT, _at(cell), 22.0, "Enter the tent", func(_p: Player) -> void:
		_instances.enter_dwelling("tent", title, level, hash(inside), used.has(inside), func() -> void:
			used[inside] = true
			SaveGame.request_save()
		)
	)


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
		# Found chests keep what is left in them (and what the player puts in).
		Events.loot_opened.emit({"items": chests[key], "title": "Chest"})
		SaveGame.request_save()
	return chest
