extends RefCounted
## World sites, props, fire and the running game.


func test_every_site_kind_is_built_and_mapped(t: TestContext) -> void:
	var kinds: Array = Structures.CHANCES.map(func(entry: Array) -> String: return entry[0])
	kinds.append_array(["altar", "shipwreck"])
	var structures := Structures.new()
	for kind: String in kinds:
		t.check(structures.has_method("_build_" + kind), "no builder for site %s" % kind)
		t.check(kind in MapIcons.KINDS, "no map icon for site %s" % kind)
	structures.free()
	var icons := MapIcons.SHEET
	t.check(icons.get_width() >= MapIcons.KINDS.size() * MapIcons.CELL, "map icon sheet is short of icons")


func test_flames_name_real_sheets(t: TestContext) -> void:
	for table: Dictionary in [Prop.DECOR_FLAMES, Prop.ART_FLAMES]:
		for frame: int in table:
			for entry: Array in table[frame]:
				t.equal(entry.size(), 4, "flame entry on frame %d" % frame)
				t.check(FlameFX.SHEETS.has(entry[3]), "flame on frame %d uses unknown sheet %s" % [frame, entry[3]])
	for kind: String in FlameFX.SHEETS:
		var sheet: Texture2D = FlameFX.SHEETS[kind][0]
		t.check(sheet.get_width() % int(FlameFX.SHEETS[kind][1]) == 0, "%s flame sheet does not split into its frames" % kind)


func test_decor_sheet_has_every_frame(t: TestContext) -> void:
	t.equal(Prop.Decor.size(), Prop.DECOR_FRAMES, "decor enum and frame count")
	t.equal(Prop.DECOR.get_width(), Prop.DECOR_FRAMES * 64, "decor sheet width")


func test_game_starts(t: TestContext) -> void:
	var main: Node = await t.game()
	var player: Player = main.get_node("Player")
	t.check(player != null, "no player")
	t.check(player.health.current > 0.0, "player starts dead")
	t.check(main.get_node("World").get_child_count() > 0, "the world built nothing")


func test_sites_are_the_same_every_time(t: TestContext) -> void:
	var main: Node = await t.game()
	var structures: Structures = main.get_node("Structures")
	var first := structures.site_for(Vector2i(3, -2))
	structures._sites.clear()
	t.equal(structures.site_for(Vector2i(3, -2)), first, "site in chunk 3,-2 after forgetting it")


func test_new_sites_build(t: TestContext) -> void:
	var main: Node = await t.game()
	var player: Player = main.get_node("Player")
	var world: World = main.get_node("World")
	var structures: Structures = main.get_node("Structures")
	var wanted := ["watchtower", "graveyard", "henge", "farmstead", "library"]
	var found := {}
	for r in range(1, 30):
		for cy in range(-r, r + 1):
			for cx in range(-r, r + 1):
				if maxi(absi(cx), absi(cy)) == r:
					var site := structures.site_for(Vector2i(cx, cy))
					if not site.is_empty() and site["kind"] in wanted and not found.has(site["kind"]):
						found[site["kind"]] = site["cell"]
		if found.size() == wanted.size():
			break
	for kind: String in wanted:
		t.check(found.has(kind), "no %s within 30 chunks of the start" % kind)
	for kind: String in found:
		var cell: Vector2i = found[kind]
		player.global_position = world.cell_to_world(cell + Vector2i(0, 6))
		world.load_around_now(player.global_position)
		await t.frames(3)
		var chunk := Vector2i((Vector2(cell) / World.CHUNK_SIZE).floor())
		var placed: Array = structures._by_chunk.get(chunk, [])
		t.check(placed.size() >= 3, "%s placed only %d things" % [kind, placed.size()])
	player.global_position = Vector2.ZERO
	world.load_around_now(Vector2.ZERO)
	await t.frames(3)


func test_build_mode_hides_the_hud(t: TestContext) -> void:
	var main: Node = await t.game()
	var player: Player = main.get_node("Player")
	var hud: Node = main.get_node("HUD")
	player.inventory.add(Item.create("torch", 3))
	var palette: BuildPalette = hud._palette
	palette.set_active(true)
	await t.frames(3)
	t.check(BuildPalette.on, "build mode did not turn on")
	t.check(not hud._ability_bar.visible, "ability bar still shows in build mode")
	t.check(player.view_zoom < 1.0, "camera did not pull back")
	palette.set_active(false)
	await t.frames(3)
	t.check(not BuildPalette.on, "build mode did not turn off")
	t.check(hud._ability_bar.visible, "ability bar did not come back")
	t.equal(player.view_zoom, 1.0, "camera zoom after build mode")


func test_crates_and_barrels_break_open(t: TestContext) -> void:
	for i in 30:
		var spill := Prop.roll_breakable(5, i % 2 == 0)
		t.check(spill.size() >= 1 and spill.size() <= 3, "a broken crate spilled %d things" % spill.size())
	var crate := Prop.create_decor(Prop.Decor.CRATE, Vector2.ZERO)
	t.check(crate.is_in_group("breakables") and crate.hits_left == 1, "a found crate can't be broken")
	var barrel := Prop.create_decor(Prop.Decor.BARREL, Vector2.ZERO)
	t.equal(barrel.hits_left, 2, "hits to break a barrel")
	var chair := Prop.create_decor(Prop.Decor.CHAIR, Vector2.ZERO)
	t.check(not chair.is_in_group("breakables"), "a chair can be smashed")
	for prop: Prop in [crate, barrel, chair]:
		prop.free()


func test_every_enemy_attack_is_handled(t: TestContext) -> void:
	var kinds := ["lunge", "charge", "swoop", "swipe", "thrust", "combo", "pounce", "spit", "spin", "burrow", "shoot", "slam", "cloud", "explode"]
	var used := {}
	for id: String in EnemyDB.ENEMIES:
		var attack: Dictionary = EnemyDB.ENEMIES[id]["attack"]
		t.check(attack["kind"] in kinds, "%s attacks with unknown kind %s" % [id, attack["kind"]])
		t.check(attack.has("range") and attack.has("windup") and attack.has("recover"), "%s's attack lacks range, windup or recover" % id)
		if attack["kind"] in ["slam", "cloud", "explode", "spin", "burrow"]:
			t.check(attack.has("radius"), "%s's area attack has no radius" % id)
		if attack["kind"] in ["shoot", "spit"]:
			t.check(attack.has("sprite") and attack.has("speed"), "%s's shot has no sprite or speed" % id)
		if float(attack["range"]) > 0.0:
			used[attack["kind"]] = true
	t.check(used.size() >= 10, "only %d kinds of attack among the monsters" % used.size())


func test_every_monster_has_a_sheet_and_loot(t: TestContext) -> void:
	for id: String in EnemyDB.ENEMIES:
		var data: Dictionary = EnemyDB.ENEMIES[id]
		var sheet: String = data.get("sheet", EnemyDB.SHEETS % id)
		t.check(ResourceLoader.exists(sheet), "%s has no sprite sheet" % id)
		t.check(ItemDB.LOOT_TABLES.has(id), "%s has no loot table" % id)
		for drop: Dictionary in ItemDB.LOOT_TABLES.get(id, {}).get("materials", []):
			t.check(ItemDB.ITEMS.has(drop["id"]), "%s drops unknown %s" % [id, drop["id"]])
	for id: String in ["sheep", "cow", "chicken", "bear", "grey_wolf", "giant_spider", "web_spider"]:
		t.check(EnemyDB.ENEMIES.has(id), "no %s" % id)


func test_tents_and_houses_can_be_entered(t: TestContext) -> void:
	var main: Node = await t.game()
	var instances: Instances = main.get_node("Instances")
	for kind: String in ["tent", "cottage"]:
		var looted := [false]
		instances.enter_dwelling(kind, "Test " + kind, 5, 42, false, func() -> void: looted[0] = true)
		await t.frames(3)
		t.check(instances.is_inside(), "could not enter a %s" % kind)
		var chest: Prop = null
		for node in t.tree.get_nodes_in_group("props"):
			if node is Prop and (node.prompt_text == "Open the chest" or node.prompt_text == "Open the cupboard"):
				chest = node
		t.check(chest != null, "no chest or cupboard in the %s" % kind)
		if chest:
			chest.interact(main.get_node("Player"))
			await t.frames(2)
			t.check(looted[0], "opening the %s's chest did not count as looting it" % kind)
			main.get_node("Menus").close()
		instances.leave()
		await t.frames(3)
		t.check(not instances.is_inside(), "could not leave the %s" % kind)


func test_ego_rises_and_falls(t: TestContext) -> void:
	var main: Node = await t.game()
	var player: Player = main.get_node("Player")
	player.ego.value = 0.0
	player.ego.add(0.0)
	var damage := player.stats.get_stat("physical_damage")
	player.ego.add(80.0)
	t.check(player.stats.get_stat("physical_damage") < damage, "a swollen ego did not cut damage")
	t.check(player.ego.speed_loss() > 0.0, "a swollen ego did not slow attacks")
	var before := player.ego.value
	player.ego.humble("cook")
	player.ego.humble("trade", 2)
	t.check(player.ego.value < before, "humble work did not lower ego")
	player.ego.value = 0.0
	player.ego.add(0.0)
	t.equal(player.stats.get_stat("physical_damage"), damage, "damage with no ego")


func test_root_tech_farms_and_walls_are_whole(t: TestContext) -> void:
	for kind: String in RootMachine.KINDS:
		t.check(Buildings.KINDS.values().any(func(data: Dictionary) -> bool: return data.get("machine", "") == kind), "root machine %s cannot be built" % kind)
	for species: String in Livestock.SPECIES:
		var data: Dictionary = Livestock.SPECIES[species]
		for sheet: String in [species, data["baby"]]:
			t.check(ResourceLoader.exists(EnemyDB.SHEETS % sheet), "%s has no sprite sheet" % sheet)
		t.check(ItemDB.ITEMS.has(data["produce"]), "%s produces unknown %s" % [species, data["produce"]])
		for food: String in data["food"]:
			t.check(ItemDB.ITEMS.has(food), "%s eats unknown %s" % [species, food])
	for id: String in ItemDB.ITEMS:
		var style: String = ItemDB.ITEMS[id].get("wall", "")
		if style != "":
			t.check(StoneWall.STYLES.has(style), "%s builds unknown wall style %s" % [id, style])


func test_root_machines_and_farms_work(t: TestContext) -> void:
	var main: Node = await t.game()
	var player: Player = main.get_node("Player")
	var buildings: Buildings = main.get_node("Buildings")
	var at := player.global_position + Vector2(400, 300)
	buildings.place("farmhouse", at)
	await t.frames(3)
	var farm: Dictionary = buildings.records[buildings.records.size() - 1]
	t.equal(farm["kind"], "farmhouse", "the farmhouse was placed")
	var sheep := Livestock.new().setup("sheep", {"baby": false, "age": 0.0}, farm)
	(farm["animals"] as Array).append(sheep.state)
	sheep.position = at + Vector2(0, 80)
	buildings.add_child(sheep)
	sheep.state["next"] = 0.0
	await t.frames(3)
	t.check((farm["items"] as Array).any(func(saved: Dictionary) -> bool: return saved["id"] == "wool"), "the sheep left no wool")
	t.check(buildings.take_down_problem(farm) != "", "a farmhouse with animals can be packed up")
	farm["last"] = Time.get_unix_time_from_system() - 7200.0
	var before: int = (farm["items"] as Array)[0]["count"]
	Livestock.catch_up(farm)
	t.check(int((farm["items"] as Array)[0]["count"]) > before, "nothing was made while away")
	sheep.queue_free()
	(farm["animals"] as Array).clear()
	(farm["items"] as Array).clear()
	t.equal(buildings.take_down(farm), "", "packing up the empty farmhouse")
