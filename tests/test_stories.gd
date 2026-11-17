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


func test_devouring_copies_echoes_that_can_be_worn_and_fused(t: TestContext) -> void:
	var main := await t.game()
	var player: Player = main.get_node("Player")
	var echoes: Echoes = main.get_node("Echoes")
	echoes.awake = true
	echoes.learned.clear()
	echoes.worn.clear()
	echoes.hunger.clear()
	t.check(Echoes.of_monster("crag_golem").has("stone_skin"), "a golem carries Stoneskin")
	for id: String in Echoes.LIST:
		for monster: String in Echoes.LIST[id].get("from", []):
			t.check(EnemyDB.ENEMIES.has(monster), "%s comes from a real monster (%s)" % [id, monster])
	for fusion: Array in Echoes.FUSIONS:
		t.check(Echoes.LIST.has(fusion[0]) and Echoes.LIST.has(fusion[1]) and int(Echoes.LIST[fusion[2]]["tier"]) == 2, "fusion %s is whole" % fusion[2])
	# A kill leaves a remnant; devouring it surely gives the Echo in the end.
	echoes._on_kill({"id": "crag_golem", "name": "Crag Golem", "rank": "normal", "position": player.global_position + Vector2(30, 0)})
	await t.frames(1)
	var remnants := main.get_tree().get_nodes_in_group("props").filter(func(n: Node) -> bool: return n is Echoes.Remnant)
	t.equal(remnants.size(), 1, "a fallen golem leaves its remnant")
	for k in Echoes.SURE_AFTER:
		var remnant := Echoes.Remnant.new()
		remnant.setup(echoes, "crag_golem", 0, "Crag Golem", 9.0)
		main.add_child(remnant)
		echoes.devour(remnant)
		if "stone_skin" in echoes.learned:
			break
	t.check("stone_skin" in echoes.learned, "devouring golems gives Stoneskin, sooner or later")
	t.check("stone_skin" in echoes.worn, "worn at once while a slot is free")
	var speed_worn := player.stats.get_stat("move_speed")
	echoes.toggle("stone_skin")
	t.check(player.stats.get_stat("move_speed") > speed_worn, "its gifts come off with it (Stoneskin slows)")
	echoes.toggle("stone_skin")
	(remnants[0] as Node).queue_free()
	echoes.learn("gel_body")
	t.check(not echoes.fusions_ready().is_empty(), "Gel Body and Stoneskin can fuse")
	t.equal(echoes.fuse("gel_body", "stone_skin"), "", "they fuse")
	t.check("living_bulwark" in echoes.learned and not "gel_body" in echoes.learned and not "stone_skin" in echoes.learned, "into Living Bulwark, using both")
	for id: String in ["pack_howl", "bone_aim", "night_wings", "thorn_hide", "ash_veil", "void_sight"]:
		echoes.learn(id)
	t.check(echoes.worn.size() <= echoes.slots(), "never more worn than slots (%d)" % echoes.slots())
	t.check(echoes.toggle("void_sight") != "" or "void_sight" in echoes.worn, "a full set of slots refuses another")
	var data := echoes.save_data()
	echoes.load_data({})
	t.check(echoes.learned.is_empty(), "a fresh start")
	echoes.load_data(data)
	t.check("living_bulwark" in echoes.learned, "and the save keeps them")
	t.close_game()


func test_names_evolve_towns_grow_and_treaties_hold(t: TestContext) -> void:
	var main := await t.game()
	var player: Player = main.get_node("Player")
	var pets: Pets = player.pets
	var town: MonsterTown = main.get_node("MonsterTown")
	var factions: Factions = main.get_node("Factions")
	var buildings: Buildings = main.get_node("Buildings")
	pets.pets.clear()
	pets._adopt("rot_hound", "monster", "Gruk")
	player.mana.current = 0.0
	t.check(pets.give_name(0, "Gruk") != "", "with no mana there is no Name")
	player.mana.current = player.mana.max_value
	var weak := pets.damage(pets.pets[0])
	t.equal(pets.give_name(0, "Gruk"), "", "a Name is given")
	t.check(pets.pets[0]["named"] and player.mana.current == 0.0 and player.buffs.has("name_weary"), "it takes all your mana and leaves you weary")
	t.check(pets.damage(pets.pets[0]) > weak, "a Named monster hits harder")
	pets._gain(pets.pets[0], 200000)
	t.equal(pets.stage(pets.pets[0]), 3, "growing, it evolves to Ascendant")
	# A home, then the town.
	buildings.home = {"position": [player.global_position.x + 200.0, player.global_position.y]}
	t.equal(town.settle(0), "", "a Named monster settles in town")
	t.equal(town.citizens.size(), 1, "one citizen")
	t.check(pets.pets.is_empty(), "no longer a pet")
	t.check(town.has_speaker("feral"), "it speaks for the Feral Packs")
	town.set_job(0, "forager")
	town._on_morning(2)
	t.check(not town.store.is_empty(), "work brings things to the store")
	# A treaty through it.
	player.inventory.add_gold(5000)
	t.equal(factions.treaty_problem("feral", town, player), "", "a treaty can be offered")
	t.check(factions.treaty_problem("lull", town, player) != "", "never with the Court")
	factions.sign_treaty("feral", player)
	t.check(factions.at_peace("feral"), "at peace with the Feral Packs")
	var spawner: EnemySpawner = main.get_node("Enemies")
	var hound := spawner.spawn_at(player.global_position + Vector2(120, 0), 3, Enemy.Rank.NORMAL, "rot_hound")
	await t.frames(2)
	hound._since_hurt = 99.0
	t.check(hound._at_peace(), "a hound leaves you be")
	hound.take_damage(1.0, Vector2(10, 0))
	t.check(not factions.at_peace("feral"), "strike one, and the treaty is broken")
	hound.queue_free()
	# The festival.
	town.citizens.append({"id": 999, "species": "crag_golem", "kind": "monster", "name": "Tor", "level": 3, "xp": 0, "named": true, "stage": 0, "job": "miner"})
	var level_before := int(town.citizens[1]["level"])
	t.equal(town.hold_festival(), "", "the Festival of Rising")
	t.equal(int(town.citizens[1]["level"]), level_before + MonsterTown.FESTIVAL_LEVELS, "everyone grows")
	t.check(player.buffs.has("risen"), "and you are Risen")
	t.check(town.hold_festival() != "", "once a week")
	t.close_game()


func test_the_aura_cows_the_weak_and_not_the_great(t: TestContext) -> void:
	var main := await t.game()
	var player: Player = main.get_node("Player")
	var aura: DreadAura = player.get_node("DreadAura")
	var spawner: EnemySpawner = main.get_node("Enemies")
	var weakling := spawner.spawn_at(player.global_position + Vector2(100, 0), 1, Enemy.Rank.NORMAL, "husk")
	var boss := spawner.spawn_at(player.global_position + Vector2(-100, 0), 1, Enemy.Rank.MINIBOSS, "husk")
	await t.frames(2)
	aura.toggle()
	t.check(not aura.active, "asleep until the gift wakes")
	aura._on_level_up(DreadAura.WAKE_LEVEL)
	player.mana.current = player.mana.max_value
	aura.toggle()
	t.check(aura.active, "released")
	aura._physics_process(0.1)
	t.check(weakling.cowed > 0.0, "the weak cower")
	t.equal(boss.cowed, 0.0, "the great do not")
	player.mana.current = 0.0
	aura._physics_process(0.1)
	t.check(not aura.active, "no mana, no aura")
	weakling.queue_free()
	boss.queue_free()
	t.close_game()


func test_the_pact_is_won_in_the_chapel_and_keeps_a_daily_rite(t: TestContext) -> void:
	var main := await t.game()
	var player: Player = main.get_node("Player")
	var pact: ThePact = main.get_node("ThePact")
	var gates: Gates = main.get_node("Gates")
	var instances: Instances = main.get_node("Instances")
	var day_night: DayNight = main.get_node("DayNight")
	t.check(not pact.awakened, "no Pact at first")
	player.leveling.add_xp(3000)
	gates._chapel_check()
	t.check(gates.chapel_cell != Vector2i.MAX, "the crimson gate opens near you at level %d" % ThePact.CHAPEL_LEVEL)
	gates.enter({})
	await t.frames(3)
	t.check(instances.is_inside() and instances.room.title == "The Drowned Chapel", "into the Drowned Chapel")
	# A broken commandment hurts.
	pact._command = "kneel"
	pact._toll_wait = 0.0
	player.velocity = Vector2(200, 0)
	var health := player.health.current
	pact._chapel_tick(0.01)
	pact._chapel_tick(0.01)
	t.check(player.health.current < health, "moving while the bell tolls for KNEEL is punished")
	pact._tolls = ThePact.CHAPEL_TOLLS
	pact._accept()
	await t.frames(2)
	t.check(pact.awakened and not instances.is_inside(), "the Pact is accepted, and you are out")
	t.equal(gates.chapel_cell, Vector2i.MAX, "the crimson gate is gone")
	# The rite.
	var points := player.attributes.unspent
	for key: String in ThePact.RITE:
		pact.rite[key] = pact.goal(key) - 1
	pact._on_kill({})
	t.check(not pact.rite_done, "not done until every part is")
	pact.rite["blows"] = pact.goal("blows")
	pact.rite["steps"] = float(pact.goal("steps"))
	pact.rite["gathered"] = pact.goal("gathered")
	pact._check_rite()
	t.check(pact.rite_done and player.attributes.unspent == points + 3, "a finished rite gives three points")
	# An unfinished one means the Pit.
	pact.rite_done = false
	day_night.day += 1
	pact._on_new_day(day_night.day)
	t.check(pact.penalty_due, "an unfinished rite brings a penalty")
	pact._penalty_wait = 0.0
	pact._physics_process(0.1)
	await t.frames(3)
	t.check(instances.is_inside() and instances.room.title == "The Pit of Atonement", "taken to the Pit of Atonement")
	pact._scene_left = 0.0
	pact._pit_tick(0.1)
	await t.frames(2)
	t.check(not instances.is_inside(), "let go when the time is served")
	var data := pact.save_data()
	pact.load_data({})
	t.check(not pact.awakened, "fresh")
	pact.load_data(data)
	t.check(pact.awakened, "the save keeps the Pact")
	t.close_game()


func test_gates_open_break_seal_and_yield_to_keys(t: TestContext) -> void:
	var main := await t.game()
	var player: Player = main.get_node("Player")
	var pact: ThePact = main.get_node("ThePact")
	var gates: Gates = main.get_node("Gates")
	var instances: Instances = main.get_node("Instances")
	var day_night: DayNight = main.get_node("DayNight")
	var buildings: Buildings = main.get_node("Buildings")
	pact.awakened = true
	t.equal(Gates.rank_for_level(1, 0.5), "E", "a beginner meets E-rank gates")
	t.equal(Gates.rank_for_level(90, 0.5), "S", "the strong meet S-rank gates")
	var gate := gates.open_gate("D", false)
	t.equal(gates.gates.size(), 1, "a gate opens")
	gates._physics_process(1.1)
	await t.frames(1)
	# Inside, the master; its fall clears the gate.
	gates.enter(gate)
	await t.frames(3)
	t.check(instances.is_inside() and instances.room.title == "D-Rank Gate", "into a D-rank gate")
	t.check(gates._master != null and is_instance_valid(gates._master), "its master waits")
	(gates._master as Enemy).health.take_damage(1e9)
	await t.frames(3)
	t.equal(gates.gates.size(), 0, "cleared, the gate closes")
	t.equal(gates.cleared, 1, "one gate cleared")
	instances.leave()
	await t.frames(2)
	# A red gate seals.
	var red := gates.open_gate("C", true)
	gates.enter(red)
	await t.frames(3)
	t.check(Gates.sealed, "a red gate seals")
	buildings.home = {"position": [0.0, 0.0]}
	t.check(buildings.recall_problem().contains("red gate"), "no recall out of a red gate")
	t.check(not instances.room.get_children().any(func(n: Node) -> bool: return n is Prop and (n as Prop).prompt_text == "Leave the gate"), "and no way out")
	(gates._master as Enemy).health.take_damage(1e9)
	await t.frames(3)
	t.check(not Gates.sealed, "its master's fall opens it")
	instances.leave()
	await t.frames(2)
	# Left too long, a gate breaks and its horde walks out.
	var old := gates.open_gate("E", false)
	old["day"] = day_night.day - 10
	gates._on_new_day(day_night.day)
	t.check(old["broken"], "an old gate breaks")
	var before := main.get_tree().get_nodes_in_group("enemies").size()
	gates._break_out(old, player.global_position + Vector2(300, 0))
	await t.frames(2)
	t.check(main.get_tree().get_nodes_in_group("enemies").size() > before, "and monsters pour out")
	# A key opens a private gate.
	player.inventory.add(Item.create("gate_key_e"))
	var key: Item = null
	for item in player.inventory.items:
		if item.id == "gate_key_e":
			key = item
	t.equal(player.use_item(key), "", "a gate key opens a gate")
	await t.frames(3)
	t.check(instances.is_inside() and instances.room.title == "E-Rank Gate", "a private E-rank gate")
	t.equal(player.inventory.count_of("gate_key_e"), 0, "the key is used up")
	instances.leave()
	t.close_game()


func test_the_vigil_makes_a_shade_sovereign_who_raises_shadows(t: TestContext) -> void:
	var main := await t.game()
	var player: Player = main.get_node("Player")
	var pact: ThePact = main.get_node("ThePact")
	var shadows: Shadows = main.get_node("Shadows")
	var instances: Instances = main.get_node("Instances")
	pact.awakened = true
	t.check(pact.vigil_problem() != "", "the Vigil waits for level %d" % ThePact.VIGIL_LEVEL)
	player.leveling.add_xp(4000000)
	t.check(player.leveling.level >= ThePact.VIGIL_LEVEL, "grown enough")
	t.equal(pact.begin_vigil(), "", "the Vigil begins")
	await t.frames(3)
	t.check(instances.is_inside() and instances.room.title == "The Vigil of Ashes", "in the grave-ring")
	pact._wave = 5
	pact._wave_wait = 0.0
	instances.room.clear_enemies()
	pact._vigil_tick(0.1)
	await t.frames(2)
	t.check(pact._vigil_boss != null, "the Warden of Ashes comes")
	(pact._vigil_boss as Enemy).health.take_damage(1e9)
	await t.frames(3)
	t.equal(pact.job, "shade_sovereign", "the job changes")
	instances.leave()
	await t.frames(2)
	t.check(shadows.can_raise(), "a Shade Sovereign raises the fallen")
	# Raise one (several tries at most; a normal monster is easy).
	var raised := false
	for k in 8:
		shadows._on_kill({"id": "husk", "name": "Husk", "rank": "normal", "position": player.global_position + Vector2(40, 0)})
		if shadows.raise_nearest() == "":
			raised = true
			break
	t.check(raised and shadows.soldiers.size() == 1, "a husk rises as a shadow")
	shadows._physics_process(0.1)
	await t.frames(2)
	t.equal(shadows._nodes.size(), 1, "and walks with you")
	var node: Node2D = shadows._nodes.values()[0]
	node.global_position = player.global_position + Vector2(200, 0)
	player.camera.global_position = player.global_position
	var at := player.global_position
	main.get_viewport().warp_mouse(main.get_viewport().get_visible_rect().size / 2.0)
	t.equal(shadows.swap(), "", "swap places with it")
	t.check(player.global_position.distance_to(at) > 100.0, "you stand where it stood")
	t.check(shadows.swap() != "", "not again so soon")
	t.close_game()
