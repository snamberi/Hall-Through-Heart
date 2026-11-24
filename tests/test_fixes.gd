extends RefCounted
## Bugs players hit, kept fixed: points planned for several attributes all
## land, anything set down fits a supply slot, deserts stay flat, and the
## places of the world stand apart from one another.


func test_planned_points_all_land(t: TestContext) -> void:
	var main := await t.game()
	var player: Player = main.get_node("Player")
	var menu: CharacterMenu = main.get_node("Menus").get_menu("attributes")
	var attributes := player.attributes
	attributes.unspent = 4
	var ids: Array = Attributes.IDS.slice(0, 2)
	var before: Array = ids.map(func(id: String) -> int: return int(attributes.points[id]))
	menu._plan = {ids[0]: 2, ids[1]: 2}
	menu._apply_plan()
	t.equal(int(attributes.points[ids[0]]), int(before[0]) + 2, "the first attribute takes its points")
	t.equal(int(attributes.points[ids[1]]), int(before[1]) + 2, "and so does the second")
	t.equal(attributes.unspent, 0, "nothing is left over")


func test_anything_set_down_fits_a_supply_slot(t: TestContext) -> void:
	for id: String in ["crafting_table", "torch"]:
		t.check(Hotbar.is_supply(id), "%s goes in a supply slot" % id)
	t.check(not Hotbar.is_supply("worn_hatchet"), "a tool does not")


func test_flat_ground_stays_flat(t: TestContext) -> void:
	t.check(not TerrainTiles.Type.SAND in WorldGenerator.RAISABLE, "desert sand never rises into terraces")
	t.check(TerrainTiles.Type.DARK_GRASS in WorldGenerator.RAISABLE, "grassland still has its plateaus")


func test_places_stand_apart(t: TestContext) -> void:
	var main := await t.game()
	var structures: Structures = main.get_node("Structures")
	var holding: Array[Vector2i] = []
	for y in range(-10, 11):
		for x in range(-10, 11):
			var chunk := Vector2i(x, y)
			var site := structures.site_for(chunk)
			if not site.is_empty() and site["key"].contains(":"):
				holding.append(chunk)
	var crowded := 0
	for a in holding:
		for b in holding:
			if a != b and maxi(absi(a.x - b.x), absi(a.y - b.y)) <= 1:
				crowded += 1
	t.equal(crowded, 0, "no two places in neighbouring chunks")
	t.check(holding.size() > 4 and holding.size() < 441 / 8, "places are rare but still found (%d in 441 chunks)" % holding.size())


func test_a_character_can_be_made_for_servers(t: TestContext) -> void:
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	t.tree.root.add_child(menu)
	await t.frames(2)
	var before := SaveGame.list_slots().size()
	menu.create_for_server("servers")
	t.check(menu._pages["new"].visible, "New character opens the creator")
	t.equal(menu._next_button.text if menu._step == "world" else "Create Character  >", "Create Character  >", "which makes a character, not a world")
	menu._name_field.text = "Server Hero"
	menu._create()
	await t.frames(2)
	var made: Array = SaveGame.list_slots().filter(func(s: Dictionary) -> bool: return (s["meta"] as Dictionary).get("server_character", false))
	t.equal(SaveGame.list_slots().size(), before + 1, "a character is made")
	t.check(not made.is_empty(), "marked as made for servers")
	t.check(menu._pages["servers"].visible, "and you are back on the servers page")
	var servers: ServersPage = menu._pages["servers"]
	t.equal((servers._chosen() as Dictionary).get("id", ""), (made[0] as Dictionary)["id"] if not made.is_empty() else "?", "with it chosen to play as")
	for slot: Dictionary in made:
		SaveGame.delete_slot(slot["id"])
	menu.queue_free()


func test_a_built_waygate_joins_the_waystones(t: TestContext) -> void:
	var main := await t.game()
	var player: Player = main.get_node("Player")
	var buildings: Buildings = main.get_node("Buildings")
	var stones: Waystones = main.get_node("Waystones")
	t.check(RecipeDB.all().any(func(r: Dictionary) -> bool: return r.get("item", "") == "waygate"), "a waygate can be crafted")
	buildings.place("waygate", player.global_position + Vector2(80, 0), "waygate")
	var record: Dictionary = buildings.records.back()
	var key := "gate:%d" % int(record["id"])
	t.check(stones.known.has(key), "it is a stone you can travel to at once")
	t.equal(str(stones.known[key]["name"]), "Your Waygate", "named for you")
	t.equal(buildings.take_down(record), "", "it can be taken down")
	t.check(not stones.known.has(key), "and then it is no longer on the list")


func test_quality_of_life_extras(t: TestContext) -> void:
	var main := await t.game()
	var player: Player = main.get_node("Player")
	# Craft again remembers the last recipe made.
	var recipe := RecipeDB.find("bandage")
	if not recipe.is_empty():
		for item_id: String in recipe["inputs"]:
			player.inventory.add(Item.create(item_id, int(recipe["inputs"][item_id]) * 2))
		t.equal(Crafting.craft(player, recipe), "", "a bandage can be made")
		t.equal(Crafting.last_recipe, "bandage", "and is remembered for craft-again")
	# Travel between your own waygates costs nothing.
	var stones: Waystones = main.get_node("Waystones")
	stones.known["gate:900"] = {"name": "A", "cell": [5, 5]}
	stones.known["gate:901"] = {"name": "B", "cell": [400, 400]}
	stones.current = "gate:900"
	t.equal(stones.fee("gate:901"), 0, "waygate to waygate is free")
	stones.current = "sanctuary"
	t.check(stones.fee("gate:901") > 0, "from a waystone it still costs")
	# The tooltip says what a merchant pays.
	t.check(ItemText.describe(Item.create("oak_wood", 5), player).contains("Sells for"), "tooltips show the sell price")
	# Auto-run stops when struck.
	player.auto_running = true
	player.take_damage(1.0, player.global_position + Vector2(20, 0))
	t.check(not player.auto_running, "a blow stops auto-run")


func test_eight_directions_and_walls(t: TestContext) -> void:
	var views := {Vector2(0, 1): "front", Vector2(1, 1): "fq", Vector2(1, 0): "side", Vector2(1, -1): "bq", Vector2(0, -1): "back",
		Vector2(-1, -1): "bq", Vector2(-1, 0): "side", Vector2(-1, 1): "fq"}
	for heading: Vector2 in views:
		t.equal(PlayerAnimator.view_of(heading * 100.0), views[heading], "heading %s is seen %s" % [heading, views[heading]])
	var frames := SheetAnimations.build(PlayerAnimator.SHEET, PlayerAnimator.FRAME_SIZE, PlayerAnimator.ROWS)
	for name in ["walk_fq", "walk_bq", "attack_side", "shoot_back", "cast_bq", "thrust_fq"]:
		t.check(frames.has_animation(name), "the sheet has %s" % name)
	var main := await t.game()
	var spawner = main.get_node("Enemies")
	var bat: Enemy = spawner.spawn_at(main.get_node("Player").global_position + Vector2(200, 0), 1, Enemy.Rank.NORMAL, "carrion_bat")
	await main.get_tree().physics_frame
	t.check(EnemyDB.ENEMIES["carrion_bat"].get("flying", false), "the bat flies")
	t.check(bat.collision_mask & TerrainTiles.WALL_COLLISION != 0, "a flying monster is stopped by walls")


func test_peoples_villages_and_goblins(t: TestContext) -> void:
	var main := await t.game()
	var world: World = main.get_node("World")
	var gen := world.generator
	var kinds := {}
	var castles := 0
	var total := 0
	for ry in range(-9, 10):
		for rx in range(-9, 10):
			var c: Variant = gen.village_center(Vector2i(rx, ry))
			if c == null:
				continue
			total += 1
			kinds[gen.village_culture(c)] = true
			castles += 1 if gen.has_castle(c) else 0
			t.check(gen.village_name(c) != "", "every village has a name")
	t.check(kinds.has("human") and kinds.has("elf") and kinds.has("dwarf"), "humans, elves and dwarves all build villages")
	t.check(castles > 0 and castles < total / 3, "a few villages have castles (%d of %d)" % [castles, total])
	t.equal(gen.village_culture(gen.first_village()), "human", "the first village is human")
	t.check(Prop.create_building(Prop.People.ELF, 3, Vector2.ZERO).is_house(), "a new house counts as a house")
	var keepers: Array = VillagerLife.KEEPERS["elf"]
	t.equal(VillagerLife.make(Vector2i(5, 5), 0, 1, "elf")["job"], keepers[0], "an elf village is kept by bladewardens")
	t.equal(VillagerLife.make(Vector2i(5, 5), 2, 1, "dwarf")["job"], "thane", "a dwarf village is led by its thane")
	# Camp goblins leave you be until one is struck; then the camp fights.
	var spawner = main.get_node("Enemies")
	var player: Player = main.get_node("Player")
	var a: Enemy = spawner.spawn_at(player.global_position + Vector2(80, 0), 1, Enemy.Rank.NORMAL, "goblin")
	var b: Enemy = spawner.spawn_at(player.global_position + Vector2(-80, 0), 1, Enemy.Rank.NORMAL, "goblin")
	a.camp = "camp:test"
	b.camp = "camp:test"
	await main.get_tree().physics_frame
	t.check(a.is_wild() and not a.angered, "a camp goblin starts at peace")
	a.take_damage(1.0, player.global_position)
	for i in 3:
		await main.get_tree().physics_frame
	t.check(a.angered and b.angered, "strike one goblin and the camp takes up arms")
	t.check(not EnemyDB.ENEMIES["goblin_raider"].has("wild"), "raiders attack on sight")
	t.check(main.get_node_or_null("GoblinCamps") != null, "goblin camps are built")


func test_the_telling(t: TestContext) -> void:
	var lore := preload("res://scripts/progression/lore.gd")
	var seen := {}
	for id: String in EnemyDB.ENEMIES:
		t.check(Codex.LORE.has(id), "%s has lore" % id)
		t.check(lore.family_of(id) != "", "%s belongs to a family" % id)
	for kind: String in Structures.SITE_NAMES:
		t.check(lore.PLACES.has(kind), "%s has a story" % kind)
	t.equal(lore.open_chapters({}).size(), 1, "the first chapter is open from the start")
	t.equal(lore.open_chapters({"villages": 1, "talks": 10, "kills": 50}).size(), 4, "chapters open with deeds")
