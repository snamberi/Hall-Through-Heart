extends Node2D
## The goblins' camps and their hermits, built as their chunks load.
##
## A camp is a ring of four kinds of patchwork tent round a fire, with the
## chief's great tent in the middle, and 6 to 12 goblins about it. Camp
## goblins leave travellers alone; strike one and the whole camp fights
## (Enemy, wild "neutral"). Raiders, the goblins cast out for breaking that
## peace, roam the wilds and attack on sight (EnemyDB "goblin_raider").
##
## Far from any camp, a few clever goblins live alone in houses they built
## the human way. Each has one lesson to teach a visitor, once.
## (Loaded by path.)

const T := TerrainTiles.Type
const CAMP_REGION := 120
const CAMP_CHANCE := 0.4
const HERMIT_REGION := 240
const HERMIT_CHANCE := 0.55
## Kept clear of villages and the start.
const KEEP_AWAY := 45.0
## Tents round the fire: [offset, tent].
const TENTS: Array = [[Vector2i(-5, -3), 0], [Vector2i(5, -3), 1], [Vector2i(-5, 4), 2], [Vector2i(5, 4), 3]]
const LEADER_TENT := 4

## What each hermit teaches: name, what they say, and what you come away
## with (a talent point always; items besides).
const LESSONS: Array[Dictionary] = [
	{"name": "Trap Lore", "say": "Monsters walk the same ways twice. Watch the ground, not the beast.", "items": [["bandage", 4], ["jerky", 3]]},
	{"name": "Fire Craft", "say": "Wet wood smokes, dry wood sings. A goblin fire never goes out.", "items": [["torch", 6], ["coal", 6]]},
	{"name": "Treasure Sense", "say": "Humans bury what they love. Dig where the grass grows thin.", "items": [["treasure_map", 1]]},
	{"name": "Beast Speech", "say": "A hungry beast is a friend you haven't fed yet.", "items": [["taming_treat", 3]]},
	{"name": "Herb Wisdom", "say": "Every weed is a medicine to someone. Taste, then wait. Then taste more.", "items": [["health_potion", 2], ["mana_potion", 2]]},
	{"name": "Hagglers' Tongue", "say": "Never take the first price. Never give the first price. Smile with all your teeth.", "items": [["enchanted_dust", 2]]},
]

var _world: World
## Built camps and hermits, by key: [chunk, nodes].
var _built: Dictionary = {}
## Each camp's goblins, by key.
var _goblins: Dictionary = {}


func setup(world: World) -> void:
	_world = world
	world.chunk_built.connect(_on_chunk_built)
	world.chunk_freed.connect(_on_chunk_freed)


## The camp in a region, or null.
func camp_center(region: Vector2i) -> Variant:
	return _site(region, CAMP_REGION, CAMP_CHANCE, 777)


## The hermit's house in a region, or null.
func hermit_home(region: Vector2i) -> Variant:
	return _site(region, HERMIT_REGION, HERMIT_CHANCE, 919)


func _site(region: Vector2i, size: int, chance: float, salt: int) -> Variant:
	var generator := _world.generator
	var random := RandomNumberGenerator.new()
	random.seed = hash(Vector3i(region.x, region.y, generator.world_seed + salt))
	if random.randf() > chance:
		return null
	var center := region * size + Vector2i(random.randi_range(20, size - 20), random.randi_range(20, size - 20))
	if Vector2(center).length() < 70.0:
		return null
	# Never in or by a village.
	var village_region := Vector2i((Vector2(center) / WorldGenerator.VILLAGE_REGION).floor())
	for y in range(-1, 2):
		for x in range(-1, 2):
			var village: Variant = generator.village_center(village_region + Vector2i(x, y))
			if village != null and Vector2(center - (village as Vector2i)).length() < KEEP_AWAY:
				return null
	for y in range(-6, 7, 3):
		for x in range(-7, 8, 3):
			var cell := center + Vector2i(x, y)
			if not generator.is_dry_land(cell) or generator.tile_type_at(cell) in [T.PATH, T.VOIDSCAR]:
				return null
	return center


func _at(cell: Vector2i) -> Vector2:
	return _world.cell_to_world(cell)


func _on_chunk_built(chunk: Vector2i) -> void:
	var middle := chunk * World.CHUNK_SIZE + Vector2i(World.CHUNK_SIZE / 2, World.CHUNK_SIZE / 2)
	for kind: String in ["camp", "hermit"]:
		var size := CAMP_REGION if kind == "camp" else HERMIT_REGION
		var region := Vector2i((Vector2(middle) / size).floor())
		var center: Variant = camp_center(region) if kind == "camp" else hermit_home(region)
		if center == null:
			continue
		var home_chunk := Vector2i((Vector2(center as Vector2i) / World.CHUNK_SIZE).floor())
		var key := "%s:%d,%d" % [kind, (center as Vector2i).x, (center as Vector2i).y]
		if home_chunk != chunk or _built.has(key):
			continue
		_built[key] = [chunk, _build_camp(center, key) if kind == "camp" else _build_hermit(center, key)]


func _on_chunk_freed(chunk: Vector2i) -> void:
	for key: String in _built.keys():
		if _built[key][0] != chunk:
			continue
		for node: Variant in _built[key][1]:
			if is_instance_valid(node):
				node.queue_free()
		_built.erase(key)


func _build_camp(center: Vector2i, key: String) -> Array:
	var placed: Array = []
	var random := RandomNumberGenerator.new()
	random.seed = hash(key + str(_world.generator.world_seed))
	var leader := Prop.create_building(Prop.People.GOBLIN, LEADER_TENT, _at(center), 40.0)
	add_child(leader)
	placed.append(leader)
	for tent: Array in TENTS:
		var offset: Vector2i = tent[0] + Vector2i(random.randi_range(-1, 1), random.randi_range(-1, 1))
		var hut := Prop.create_building(Prop.People.GOBLIN, int(tent[1]), _at(center + offset), 26.0)
		add_child(hut)
		placed.append(hut)
	var fire := Prop.create(Prop.Art.CAMPFIRE, _at(center + Vector2i(0, 3)), 11.0)
	fire.add_light(1.0, 2.0)
	add_child(fire)
	placed.append(fire)
	for spot: Vector2i in [Vector2i(-2, 5), Vector2i(3, 6), Vector2i(-7, 0), Vector2i(7, 1)]:
		var junk := Prop.create_decor([Prop.Decor.CRATE, Prop.Decor.BARREL, Prop.Decor.BONES, Prop.Decor.HAY_BALE][random.randi() % 4], _at(center + spot), 8.0)
		add_child(junk)
		placed.append(junk)
	var banner := Prop.create_decor(Prop.Decor.BANNER, _at(center + Vector2i(-2, -6)), 5.0)
	banner.sprite().modulate = Color(0.55, 0.85, 0.45)
	add_child(banner)
	placed.append(banner)
	# The goblins, if the camp is empty (a camp wiped out fills again).
	var alive: Array = (_goblins.get(key, []) as Array).filter(func(g: Variant) -> bool: return is_instance_valid(g) and (g as Enemy).state != Enemy.State.DEAD)
	if alive.is_empty():
		var spawner: EnemySpawner = get_parent().get_node_or_null("Enemies")
		if spawner:
			var level := _world.generator.enemy_level_at(center)
			var home := _at(center)
			var chief := spawner.spawn_at(home + Vector2(0, 40), level + 2, Enemy.Rank.NORMAL, "goblin_chief")
			alive.append(chief)
			for k in random.randi_range(5, 11):
				var spot := home + Vector2.from_angle(random.randf() * TAU) * random.randf_range(60.0, 220.0)
				if _world.generator.is_dry_land(_world.world_to_cell(spot)):
					alive.append(spawner.spawn_at(spot, level, Enemy.Rank.NORMAL, "goblin"))
			for goblin: Enemy in alive:
				goblin.camp = key
				goblin.home_spot = home
	_goblins[key] = alive
	return placed


func _build_hermit(center: Vector2i, key: String) -> Array:
	var placed: Array = []
	var random := RandomNumberGenerator.new()
	random.seed = hash(key + str(_world.generator.world_seed))
	var lesson: Dictionary = LESSONS[random.randi() % LESSONS.size()]
	var house := Prop.create_building(Prop.People.HUMAN, random.randi() % Prop.HOUSE_VARIANTS, _at(center), 34.0)
	house.sprite().material = Wind.roof
	add_child(house)
	placed.append(house)
	for spot: Vector2i in [Vector2i(-3, 1), Vector2i(3, 1)]:
		var pot := Prop.create_decor(Prop.Decor.PLANT_POT if spot.x < 0 else Prop.Decor.CRATE, _at(center + spot), 8.0)
		add_child(pot)
		placed.append(pot)
	var lamp := Prop.create_decor(Prop.Decor.LANTERN, _at(center + Vector2i(1, 2)), 5.0)
	lamp.add_light(0.8, 1.4)
	add_child(lamp)
	placed.append(lamp)
	var hermit := Npc.create("story", _at(center + Vector2i(-1, 2)))
	var look := Appearance.for_race("goblin")
	look["hat"] = 4
	look["beard"] = random.randi() % Appearance.BEARDS.size()
	look["accessory"] = 1
	hermit.look = look
	hermit.villager_name = ["Nib", "Grizzle", "Old Squint", "Pell-Mell", "Wort", "Sage Knuckle"][random.randi() % 6]
	hermit.title_text = "%s the Goblin Sage" % hermit.villager_name
	hermit.prompt_text = "Talk to %s" % hermit.villager_name
	hermit.offer = {"talk": func(npc: Npc) -> void: _teach(npc, key, lesson)}
	add_child(hermit)
	placed.append(hermit)
	return placed


## The hermit's one lesson: a talent point and something to take away,
## once per hermit (remembered with the structures).
func _teach(npc: Npc, key: String, lesson: Dictionary) -> void:
	var structures: Structures = get_parent().get_node_or_null("Structures")
	var player: Player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	if structures and structures.used.has(key):
		npc.say("I've taught you all I know. Go and use it.")
		return
	npc.say(str(lesson["say"]), 6.0)
	player.leveling.talent_points += 1
	for entry: Array in lesson["items"]:
		if ItemDB.ITEMS.has(entry[0]):
			player.inventory.add(Item.create(entry[0], int(entry[1])))
	if structures:
		structures.used[key] = true
	Events.announcement.emit("LESSON: %s" % str(lesson["name"]).to_upper(), "%s teaches you. +1 talent point" % npc.villager_name)
	SaveGame.request_save()
