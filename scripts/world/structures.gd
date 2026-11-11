class_name Structures
extends Node2D
## Builds the fixed and scattered structures of the world as chunks load:
## the temple at the start, camp fires, ruins with a chest, mini-boss lairs,
## cave mouths, and void portals. Where they stand comes from the world seed.
##
## Chests that have been opened and lairs that have been cleared are
## remembered in the save.

const T := TerrainTiles.Type
## Chance per chunk of each structure, checked in this order.
const CHANCES: Array[Array] = [["ruin", 0.07], ["cave", 0.035], ["lair", 0.03], ["portal", 0.02]]
## Lairs and portals only appear where the area is at least this level.
const MIN_LEVEL := {"lair": 3, "portal": 4}
## Nothing but the temple within this many tiles of the origin.
const CLEAR_RADIUS := 26.0
## Monsters that can rule a lair, by the ground it stands on.
const LAIR_BOSSES := {T.ASH: "crag_golem", T.CINDER: "crag_golem", T.SALT: "crag_golem", T.BOG: "spore_shambler", T.FUNGAL: "spore_shambler",
	T.DARK_GRASS: "thorn_stalker", T.THORN: "thorn_stalker", T.SNOW: "ash_wraith", T.VOIDSCAR: "ash_wraith", T.SAND: "bone_archer"}

## Keys of structures already used up, e.g. "ruin:12,-3".
var used: Dictionary = {}

var _world: World
var _player: Player
var _spawner: EnemySpawner
var _loot: Node2D
var _instances: Instances
var _by_chunk: Dictionary = {}


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
	return {"used": used.keys()}


func load_data(data: Dictionary) -> void:
	used.clear()
	for key: Variant in data.get("used", []):
		used[str(key)] = true


## Throws gold and items out of a chest. `richness` 1 is a modest ruin chest.
static func scatter_loot(loot: Node2D, at: Vector2, level: int, richness: float) -> void:
	loot.drop_gold(roundi(randf_range(8.0, 20.0) * pow(level, 0.9) * richness), at)
	var materials: Array[String] = ["stone", "copper_ore", "oak_wood", "healing_herb", "bone", "husk_fragment"]
	for i in randi_range(1, 2):
		loot.drop_item(Item.create(materials.pick_random(), randi_range(1, 3)), at)
	if randf() < 0.3 * richness:
		loot.drop_item(Item.create("health_potion"), at)
	# Plain chests rarely hold gear; rich ones always do, and better.
	if randf() < 0.15 * richness * richness:
		var rarity := LootGenerator.roll_rarity(0.0, (richness - 1.0) * 4.0)
		loot.drop_item(LootGenerator.make_equipment(level, maxi(rarity, 2 if richness >= 2.0 else 0)), at)
	if richness >= 2.0:
		loot.drop_item(Item.create("heart_shard"), at)


func _on_chunk_built(chunk: Vector2i) -> void:
	var placed: Array = []
	var origin := chunk * World.CHUNK_SIZE
	var bounds := Rect2i(origin, Vector2i(World.CHUNK_SIZE, World.CHUNK_SIZE))
	_build_temple(bounds, placed)
	_build_camp_fire(origin, bounds, placed)

	var random := RandomNumberGenerator.new()
	random.seed = hash(Vector3i(chunk.x, chunk.y, _world.generator.world_seed + 4242))
	var cell := origin + Vector2i(random.randi_range(4, World.CHUNK_SIZE - 5), random.randi_range(4, World.CHUNK_SIZE - 5))
	var roll := random.randf()
	if Vector2(cell).length() > CLEAR_RADIUS and _clear_ground(cell):
		var level := _world.generator.enemy_level_at(cell)
		for entry in CHANCES:
			roll -= entry[1]
			if roll < 0.0:
				var kind: String = entry[0]
				if level >= MIN_LEVEL.get(kind, 1):
					call("_build_" + kind, cell, "%s:%d,%d" % [kind, chunk.x, chunk.y], level, random, placed)
				break
	for node: Node in placed:
		if node.get_parent() == null:
			add_child(node)
	_by_chunk[chunk] = placed


func _on_chunk_freed(chunk: Vector2i) -> void:
	for node: Variant in _by_chunk.get(chunk, []):
		if is_instance_valid(node):
			node.queue_free()
	_by_chunk.erase(chunk)


## Open, dry ground for a few tiles around.
func _clear_ground(cell: Vector2i) -> bool:
	for offset: Vector2i in [Vector2i.ZERO, Vector2i(3, 0), Vector2i(-3, 0), Vector2i(0, 3), Vector2i(0, -3)]:
		if not _world.generator.is_dry_land(cell + offset):
			return false
	return true


func _at(cell: Vector2i) -> Vector2:
	return _world.cell_to_world(cell)


## The Sanctuary: a ring of pillars around an altar where the player wakes.
func _build_temple(bounds: Rect2i, placed: Array) -> void:
	for index in 10:
		var angle := TAU * index / 10.0 + 0.3
		var cell := Vector2i(Vector2.from_angle(angle) * 6.5)
		# Leave the south side open as the way out.
		if bounds.has_point(cell) and absf(angle_difference(angle, PI / 2.0)) > 0.5:
			placed.append(Prop.create(Prop.Art.PILLAR, _at(cell), 9.0))
	if bounds.has_point(Vector2i(0, -3)):
		placed.append(_rest_spot(Prop.Art.ALTAR, Vector2i(0, -3), "the Sanctuary"))


## Each camp has a fire to rest at.
func _build_camp_fire(origin: Vector2i, bounds: Rect2i, placed: Array) -> void:
	var npcs: NpcSpawner = get_parent().get_node_or_null("Npcs")
	if npcs == null:
		return
	var camp: Variant = npcs.camp_cell(Vector2i((Vector2(origin) / NpcSpawner.REGION).floor()))
	if camp != null and bounds.has_point(camp + Vector2i(2, 1)):
		placed.append(_rest_spot(Prop.Art.CAMPFIRE, camp + Vector2i(2, 1), "a camp"))


## Somewhere to rest: heals, and becomes where the player wakes after dying.
func _rest_spot(art: Prop.Art, cell: Vector2i, place_name: String) -> Prop:
	return Prop.create(art, _at(cell), 11.0, "Rest here", func(player: Player) -> void:
		player.health.heal_full()
		player.stamina.fill()
		player.mana.fill()
		Events.checkpoint_set.emit(_at(cell) + Vector2(0, 40), place_name)
		Events.announcement.emit("RESTED", "You will wake at %s" % place_name)
		RingBurst.spawn(self, _at(cell) + Vector2(0, -14), Color(1.0, 0.8, 0.4), 70.0)
	)


func _build_ruin(cell: Vector2i, key: String, level: int, random: RandomNumberGenerator, placed: Array) -> void:
	for index in 7:
		if random.randf() < 0.3:
			continue
		var spot := cell + Vector2i(Vector2.from_angle(TAU * index / 7.0) * 3.0)
		placed.append(Prop.create(Prop.Art.PILLAR if random.randf() < 0.25 else Prop.Art.WALL, _at(spot), 12.0))
	placed.append(_chest(cell, key, level, 1.0))


## A ring of totems, a mini-boss, and a rich chest that only opens once the
## boss is dead.
func _build_lair(cell: Vector2i, key: String, level: int, _random: RandomNumberGenerator, placed: Array) -> void:
	for index in 6:
		placed.append(Prop.create(Prop.Art.TOTEM, _at(cell + Vector2i(Vector2.from_angle(TAU * index / 6.0 + 0.5) * 4.0)), 6.0))
	var chest := _chest(cell + Vector2i(0, -1), key, level, 2.0)
	placed.append(chest)
	if used.has(key):
		return
	var boss_id: String = LAIR_BOSSES.get(_world.generator.tile_type_at(cell), "husk")
	var boss := _spawner.spawn_at(_at(cell + Vector2i(0, 1)), level + 1, Enemy.Rank.MINIBOSS, boss_id)
	boss.lair_home = _at(cell)
	placed.append(boss)
	# The chest is sealed while its guardian lives.
	var open_prompt := chest.prompt_text
	chest.prompt_text = "Sealed while the guardian lives"
	chest.on_interact = Callable()
	boss.died.connect(func(_enemy: Enemy) -> void:
		if is_instance_valid(chest):
			chest.prompt_text = open_prompt
			chest.on_interact = _open_chest.bind(chest, key, level, 2.0)
	)


func _build_cave(cell: Vector2i, key: String, level: int, random: RandomNumberGenerator, placed: Array) -> void:
	var cave_seed := random.randi()
	var lair := random.randf() < 0.4 and not used.has(key + ":boss")
	placed.append(Prop.create(Prop.Art.CAVE, _at(cell), 0.0, "Enter the cave", func(_player: Player) -> void:
		_instances.enter_cave(cave_seed, level, lair and not used.has(key + ":boss"), func() -> void:
			used[key + ":boss"] = true
			SaveGame.request_save()
		)
	))


func _build_portal(cell: Vector2i, key: String, level: int, random: RandomNumberGenerator, placed: Array) -> void:
	if used.has(key):
		return
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


func _chest(cell: Vector2i, key: String, level: int, richness: float) -> Prop:
	var chest := Prop.create(Prop.Art.CHEST_OPEN if used.has(key) else Prop.Art.CHEST, _at(cell), 12.0, "" if used.has(key) else "Open the chest")
	chest.on_interact = _open_chest.bind(chest, key, level, richness)
	return chest


func _open_chest(_player: Player, chest: Prop, key: String, level: int, richness: float) -> void:
	chest.set_art(Prop.Art.CHEST_OPEN)
	chest.disarm()
	used[key] = true
	scatter_loot(_loot, chest.global_position, level, richness)
	SaveGame.request_save()
