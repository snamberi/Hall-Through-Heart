extends RefCounted
## The long stories out in the world: Saint Lull's House for Foundlings.


func test_saint_lull_stands_out_in_the_wheat(t: TestContext) -> void:
	var main := await t.game()
	var world: World = main.get_node("World")
	var structures: Structures = main.get_node("Structures")
	var house := SaintLull.house_cell(world.generator)
	t.check(Vector2(house).length() > 220.0, "the House stands far out (%s)" % house)
	t.check(world.generator.is_dry_land(house) and world.generator.is_dry_land(house + Vector2i(10, 10)), "on open dry ground")
	var chunk := Vector2i((Vector2(house) / World.CHUNK_SIZE).floor())
	t.equal(str(structures.site_for(chunk).get("kind", "")), "orphanage", "Structures places the House")
	t.check(structures.is_reserved(house + Vector2i(9, 9)), "nothing grows or is built in its wheat")
	var kinds := {}
	for site: Dictionary in SaintLull.sites(world.generator):
		kinds[site["kind"]] = int(kinds.get(site["kind"], 0)) + 1
	t.equal(kinds, {"orphanage": 1, "bunker": 1, "promise_stone": 7}, "the House, the hatch and seven Promise Stones")
	var placed: Array = []
	var lull: SaintLull = main.get_node("SaintLull")
	lull.build_orphanage(structures, house, placed)
	var props: Array = placed.filter(func(n: Object) -> bool: return n is Prop)
	var decor: Array = props.filter(func(p: Prop) -> bool: return p.sprite().texture == Prop.DECOR).map(func(p: Prop) -> int: return p.sprite().frame)
	t.check(props.any(func(p: Prop) -> bool: return p.sprite().texture == SaintLull.MANOR_ART), "the House at its full size")
	t.check(Prop.Decor.IRON_GATE in decor and Prop.Decor.HORN_POST in decor, "its back gate and the Reserve's horn")
	t.equal(world.generator.tile_type_at(house + Vector2i(0, 4)), TerrainTiles.Type.PATH, "a path from the gate to the door")
	t.equal(world.generator.tile_type_at(house + Vector2i(4, -4)), TerrainTiles.Type.DARK_GRASS, "a lawn inside the wall")
	t.check(placed.any(func(n: Object) -> bool: return n is StoneWall), "a white wall all round")
	for node: Node in placed:
		node.free()


func test_the_orphanage_arc_from_arrival_to_escape(t: TestContext) -> void:
	var main := await t.game()
	var player: Player = main.get_node("Player")
	var lull: SaintLull = main.get_node("SaintLull")
	var day_night: DayNight = main.get_node("DayNight")
	var menus: Node = main.get_node("Menus")
	var instances: Instances = main.get_node("Instances")
	day_night.time = 0.5
	# Arrival: Wren talks, the Matron's seal goes on.
	lull.talk_child("wren")
	await t.frames(2)
	t.equal(menus.open_id(), "dialogue", "talking to a child opens a conversation")
	t.equal(lull.stage, 1, "arrived at Saint Lull's")
	t.check(lull.branded, "the Matron's seal is on the wrist")
	menus.close()
	lull._start_doll()
	t.equal(player.inventory.count_of("lull_doll"), 1, "Number 31's doll to take to the gate")
	# By day the gate holds nothing; after dark the truth is there.
	lull._back_gate()
	t.equal(lull.stage, 2, "nothing comes by day")
	day_night.time = 0.92
	lull._back_gate()
	await t.frames(2)
	t.equal(lull.stage, 3, "the carriage at the back gate: the truth is seen")
	t.equal(player.inventory.count_of("lull_doll"), 0, "the doll is gone")
	t.equal(lull.ship_day, day_night.day + SaintLull.SHIP_DAYS, "Pip is to go in four days")
	menus.close()
	t.check(not lull.tracker_lines().is_empty(), "the plan shows on the tracker")
	# The plan: three ropes, the loose stones by night, the brand burned out.
	for where: String in ["laundry", "attic", "woodshed", "attic"]:
		lull._take_rope(where)
	t.equal(lull.rope, 3, "three lengths of rope, each found once")
	lull._find_loose_stones()
	t.check(lull.wall_found, "the loose stones, found by night")
	var health_before := player.health.current
	lull._burn_brand()
	t.check(lull.brand_burned and not lull.branded and player.health.current < health_before, "the brand burns out, and it hurts")
	t.check(lull._plan_done(), "the plan is ready")
	# A missed shipping day costs a child.
	var saved_ship := lull.ship_day
	day_night.day = saved_ship + 1
	lull._check_ships()
	t.equal(lull.children["pip"], "taken", "Pip was sent away in the night")
	day_night.day = saved_ship - 1
	lull.children["pip"] = "home"
	lull.ship_day = saved_ship
	# Escape night: the field, the children behind, a noble at the wall.
	lull._enter_escape()
	await t.frames(3)
	t.check(instances.is_inside() and instances.room.title == "The Field at Night", "into the field at night")
	t.equal(lull._followers.size(), 3, "all three children follow")
	t.check(instances.room.enemies.any(func(e: Variant) -> bool: return is_instance_valid(e) and e.enemy_id == "masked_noble"), "a masked noble waits at the wall")
	lull.child_caught(lull._followers[0])
	t.equal(lull.children.values().count("taken"), 1, "a child caught in the lantern is taken")
	var health_max := player.health.max_health
	lull._escaped()
	await t.frames(2)
	t.equal(lull.stage, 5, "out over the wall and into the woods")
	t.check(not instances.is_inside(), "back in the world")
	t.equal(lull.children.values().count("saved"), 2, "two children saved")
	t.check(player.health.max_health > health_max, "the saved children's gratitude: more health")
	# The Matron waits, and can be faced.
	var npc := Npc.create("story", player.global_position + Vector2(140, 0))
	main.get_node("Structures").add_child(npc)
	lull._matron_fight(npc)
	await t.frames(2)
	var matron: Enemy = null
	for node in main.get_tree().get_nodes_in_group("enemies"):
		if (node as Enemy).enemy_id == "matron":
			matron = node
	t.check(matron != null and matron.rank == Enemy.Rank.MINIBOSS, "the Matron fights")
	if matron:
		matron.health.take_damage(matron.health.max_health * 10.0)
		await t.frames(2)
	t.check(lull.matron_fallen, "the Keeper is released")
	t.check(player.inventory.items.any(func(i: Item) -> bool: return i.id == "matron_lantern"), "her lantern is yours")
	# It is all kept in the save.
	var data := lull.save_data()
	lull.load_data({})
	t.equal(lull.stage, 0, "a fresh story")
	lull.load_data(data)
	t.equal(lull.stage, 5, "and back again from the save")
	t.check(lull.matron_fallen and lull.brand_burned, "with what was done")
	t.close_game()


func test_court_masks_glance_crack_and_shatter(t: TestContext) -> void:
	var main := await t.game()
	var player: Player = main.get_node("Player")
	var spawner: EnemySpawner = main.get_node("Enemies")
	var noble := spawner.spawn_at(player.global_position + Vector2(200, 0), 10, Enemy.Rank.NORMAL, "masked_noble")
	await t.frames(2)
	t.equal(noble.mask_left, Enemy.MASK_CRACKS, "three cracks to break a mask")
	t.equal(noble.faction, "lull", "of the Lull Court")
	noble.target = null
	noble._mask_facing = Vector2.RIGHT
	noble.health.max_health = 100000.0
	noble.health.current = 100000.0
	# Struck in the face (the blow pushes it back the way it looks from).
	var dealt := noble.take_damage(100.0, Vector2(-300, 0))
	t.check(absf(dealt - 100.0 * Enemy.MASK_GLANCE) < 0.5, "a blow to the mask glances off (%s)" % dealt)
	dealt = noble.take_damage(100.0, Vector2(300, 0))
	t.check(absf(dealt - 200.0) < 0.5, "from behind it lands double (%s)" % dealt)
	noble.take_damage(100.0, Vector2(-300, 0), true)
	t.equal(noble.mask_left, 2, "a critical blow cracks the mask")
	noble.break_mask()
	t.equal(noble.mask_left, 0, "a finisher shatters it")
	dealt = noble.take_damage(100.0, Vector2(-300, 0))
	t.check(absf(dealt - 125.0) < 0.5, "the bare face takes more (%s)" % dealt)
	# It feeds on deaths near it.
	var traits := noble._traits.size()
	noble.health.current = 50000.0
	noble._on_death_nearby({"position": noble.global_position + Vector2(60, 0)})
	t.check(noble.health.current > 50000.0 and noble._traits.size() == traits + 1, "a death nearby feeds it and it grows worse")
	noble.queue_free()
	t.close_game()


func test_the_benefactors_cipher_and_the_promise_stones(t: TestContext) -> void:
	var main := await t.game()
	var lull: SaintLull = main.get_node("SaintLull")
	var menus: Node = main.get_node("Menus")
	var pins := MapMenu.pins.duplicate(true)
	var key := lull.journal_key()
	t.check(key >= 1 and key <= 25, "the journal is shifted (%d)" % key)
	var written := SaintLull.shift_text(SaintLull.JOURNAL, key)
	t.check(written != SaintLull.JOURNAL, "the page is unreadable as it stands")
	t.equal(SaintLull.shift_text(written, -key), SaintLull.JOURNAL, "walked back, it reads")
	lull.open_journal()
	await t.frames(2)
	t.equal(menus.open_id(), "cipher", "the journal opens on the cipher dial")
	var cipher: CipherMenu = menus.get_menu("cipher")
	cipher._shift = posmod(key + 1, 26)
	cipher._check()
	t.check(not lull.journal_solved, "the wrong turn of the dial reads nothing")
	cipher._shift = key
	cipher._check()
	t.check(lull.journal_solved, "the right one reads true")
	t.check((main.get_node("Player") as Player).inventory.items.any(func(i: Item) -> bool: return i.id == "benefactor_pen"), "and the Benefactor's pen is found")
	var marked := MapMenu.pins.filter(func(p: Dictionary) -> bool: return str(p["name"]).begins_with("Promise Stone"))
	t.equal(marked.size(), 7, "the seven stones are marked on the map")
	menus.close()
	for index in SaintLull.STONES.size():
		t.check(not lull.promise_known(), "not all read yet")
		lull.read_stone(index)
		menus.close()
	t.check(lull.promise_known(), "all seven read: the Promise is known")
	t.equal(MapMenu.pins.filter(func(p: Dictionary) -> bool: return str(p["name"]).begins_with("Promise Stone")).size(), 0, "read stones come off the map")
	var noble := (main.get_node("Enemies") as EnemySpawner).spawn_at(Vector2(300, 300), 5, Enemy.Rank.NORMAL, "masked_noble")
	await t.frames(1)
	t.equal(noble.mask_left, 2, "knowing the Promise, masks crack sooner")
	noble.queue_free()
	MapMenu.pins = pins
	t.close_game()


func test_informers_wear_the_charm_and_can_be_named(t: TestContext) -> void:
	var main := await t.game()
	var lull: SaintLull = main.get_node("SaintLull")
	var informer := ""
	var honest := ""
	for i in 200:
		var key := "villager_%d" % i
		if SaintLull.is_informer(key) and informer == "":
			informer = key
		elif not SaintLull.is_informer(key) and honest == "":
			honest = key
	t.check(informer != "" and honest != "", "some villagers inform, most do not")
	lull.stage = 3
	lull.heard_by(informer)
	t.equal(lull.suspicion, 15.0, "an informer passes on what they hear")
	lull.heard_by(informer)
	t.equal(lull.suspicion, 15.0, "once a day")
	lull.accuse(honest)
	t.equal(lull.suspicion, 25.0, "a wrong accusation costs")
	lull.accuse(informer)
	t.check(informer in lull.informers_caught and lull.suspicion < 25.0, "a right one stops them")
	lull.stage = 0
	lull.suspicion = 0.0
	t.close_game()
