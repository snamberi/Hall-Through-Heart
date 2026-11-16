extends RefCounted
## Ego, relics and belts.


func _kill(rank: String, level: int) -> Dictionary:
	return {"id": "husk", "level": level, "rank": rank, "position": Vector2.ZERO, "fragment": false, "xp": 1, "xp_multiplier": 1.0,
		"weapon_type": "swords", "name": "Husk", "modifiers": 0, "named": ""}


func test_every_relic_is_an_item_with_a_power(t: TestContext) -> void:
	var powers := {}
	for id: String in RelicDB.RELICS:
		var item := RelicDB.make(id, 4)
		t.check(item.is_relic(), "%s is not a relic item" % id)
		t.equal(item.rarity, 4, "%s keeps its rarity" % id)
		t.check(not item.is_stackable(), "%s stacks" % id)
		t.equal(ItemText.type_name(item), "Relic", "%s type" % id)
		var ability: Dictionary = RelicDB.RELICS[id]["ability"]
		t.check(not powers.has(ability["id"]), "two relics share the power %s" % ability["id"])
		powers[ability["id"]] = true
		for stat: String in RelicDB.RELICS[id]["mods"]:
			t.check(CharacterStats.DISPLAY.any(func(entry: Dictionary) -> bool: return entry["id"] == stat), "%s boosts unknown stat %s" % [id, stat])
		var weak := RelicDB.mods_at(id, 0)
		var strong := RelicDB.mods_at(id, 5)
		for stat: String in weak:
			for kind: String in weak[stat]:
				t.check(strong[stat][kind] > weak[stat][kind], "%s: mythic is not stronger than common" % id)


func test_relic_rarity_survives_saving(t: TestContext) -> void:
	var relic := RelicDB.make("void_lens", 5)
	t.equal(Item.from_dict(relic.to_dict()).rarity, 5, "relic rarity after a save")
	var ore := Item.create("iron_ore")
	t.equal(Item.from_dict(ore.to_dict()).rarity, ore.rarity, "material rarity after a save")


func test_belts_open_relic_places_and_bag_room(t: TestContext) -> void:
	var main: Node = await t.game()
	var player: Player = main.get_node("Player")
	var before := player.inventory.bonus_slots
	t.equal(player.relics.slots(), 1, "relics worn without a belt")
	var belt := Item.create("reliquary_belt")
	player.inventory.add(belt)
	t.equal(player.equipment.equip(belt), "", "wearing the reliquary belt")
	t.equal(player.relics.slots(), 3, "relics worn with the reliquary belt")
	t.equal(player.inventory.bonus_slots, before + 10, "bag room from the belt")
	for id: String in ["hearthstone", "gale_feather", "ironroot", "void_lens"]:
		t.equal(player.relics.store(RelicDB.make(id, 2)), "", "storing %s" % id)
	var damage := player.stats.get_stat("physical_damage")
	for i in 3:
		player.relics.wear(player.relics.bag[0])
	t.equal(player.relics.worn.size(), 3, "three relics worn")
	t.check(player.stats.get_stat("physical_damage") > damage, "the hearthstone adds damage")
	t.equal(player.equipment.unequip("belt"), "", "taking the belt off")
	t.equal(player.relics.worn.size(), 1, "only one relic stays worn without the belt")
	t.equal(player.relics.bag.size(), 3, "the others go back to the bag")
	for item: Item in player.relics.worn + player.relics.bag:
		player.relics.discard(item)


func test_relic_powers_all_work(t: TestContext) -> void:
	var main: Node = await t.game()
	var player: Player = main.get_node("Player")
	for id: String in RelicDB.RELICS:
		var ability: String = RelicDB.RELICS[id]["ability"]["id"]
		var result := RelicPowers.use(ability, player, 2)
		t.check(result != "Nothing happens.", "relic power %s does nothing" % ability)
		await t.frames(2)
	player.global_position = Vector2.ZERO
	player.state = Player.State.MOVE


func test_ego_grows_on_stronger_foes_and_shrinks_with_honest_work(t: TestContext) -> void:
	var main: Node = await t.game()
	var player: Player = main.get_node("Player")
	player.ego.value = 0.0
	player.ego.add(0.0)
	Events.enemy_killed.emit(_kill("normal", 1))
	t.equal(player.ego.value, 0.0, "a foe at your level gives no ego")
	var damage := player.stats.get_stat("physical_damage")
	for i in 6:
		Events.enemy_killed.emit(_kill("elite", player.leveling.level + 8))
	t.check(player.ego.value > 50.0, "ego after six elites 8 levels up: %.1f" % player.ego.value)
	t.check(player.stats.get_stat("physical_damage") < damage, "high ego cuts damage")
	var high := player.ego.value
	Events.item_crafted.emit("bread")
	Events.codex_event.emit("sales", 3)
	t.check(player.ego.value < high, "crafting and trading bring ego down")
	player.ego.value = 0.0
	player.ego.add(0.0)


func test_every_talent_can_be_reached(t: TestContext) -> void:
	t.check(TalentDB.NODES.size() >= 200, "the tree has only %d talents" % TalentDB.NODES.size())
	var seen := {"awakened_heart": true}
	var queue: Array[String] = ["awakened_heart"]
	while not queue.is_empty():
		var id: String = queue.pop_back()
		for other: String in TalentDB.neighbours(id):
			if not seen.has(other):
				seen[other] = true
				queue.append(other)
	for id: String in TalentDB.NODES:
		t.check(seen.has(id), "talent %s cannot be reached from the Heart" % id)
		for stat: String in TalentDB.NODES[id]["mods"]:
			t.check(TalentDB.describe(id, 1).size() > 0, "talent %s describes nothing" % id)
	var spots := {}
	for id: String in TalentDB.NODES:
		var at := TalentDB.position(id)
		for other: String in spots:
			t.check(at.distance_to(spots[other]) > 30.0, "talents %s and %s overlap" % [id, other])
		spots[id] = at


func test_infusion_materials_are_real(t: TestContext) -> void:
	for material: String in Infusions.MATERIALS:
		t.check(ItemDB.ITEMS.has(material), "infusion material %s is not an item" % material)
		var stat: String = Infusions.MATERIALS[material]["stat"]
		t.check(Infusions.modifier(material, 10)["value"] > 0.0, "%s infuses nothing" % material)
		t.check(stat != "", "%s has no stat" % material)
	var item := LootGenerator.make_equipment(10, 4, "sword")
	t.equal(Infusions.room(item), 3, "legendary gear holds three infusions")
	item.infusions.append("fiend_horn")
	t.equal(Item.from_dict(item.to_dict()).infusions, item.infusions, "infusions after a save")


func test_heart_monsters_and_gear_are_whole(t: TestContext) -> void:
	for id: String in ["veinheart", "heartsworn_knight"]:
		t.check(EnemyDB.ENEMIES.has(id), "%s is not a monster" % id)
		t.check(ResourceLoader.exists(EnemyDB.SHEETS % id), "%s has no sprite sheet" % id)
		t.check(ItemDB.LOOT_TABLES.has(id), "%s drops nothing of its own" % id)
	for piece: String in ItemDB.ITEM_SETS["heartsworn"]["pieces"]:
		var item := LootGenerator.make_equipment(20, 0, piece)
		t.equal(item.set_id, "heartsworn", "%s joins its set" % piece)
		t.check(item.rarity >= 2, "%s comes at least Rare" % piece)
		t.check(not RecipeDB.find(piece).is_empty(), "%s cannot be forged" % piece)
	for weapon: String in ["pulsebrand", "heartpiercer", "heartstring"]:
		t.check(ResourceLoader.exists("res://assets/sprites/weapons/%s.png" % weapon), "%s has no sprite" % weapon)


func test_rising_bosses_and_the_ninefold_blade(t: TestContext) -> void:
	for id: String in BossDB.REVIVES:
		t.check(BossDB.BOSSES.has(id), "%s rises again but is no boss" % id)
	t.equal(BossDB.PIECES.size(), 9, "nine bosses each hold a piece of the blade")
	var recipe := RecipeDB.find("ninefold_blade")
	t.check(not recipe.is_empty(), "the Ninefold Blade can be forged")
	for id: String in BossDB.PIECES:
		var piece: String = BossDB.PIECES[id]
		t.check(ItemDB.ITEMS.has(piece), "%s is not an item" % piece)
		t.check(recipe["inputs"].has(piece), "the blade does not need %s" % piece)
		t.check(BossDB.drops(id, 20).any(func(d: Dictionary) -> bool: return d["id"] == piece), "%s does not leave %s" % [id, piece])
	for monster: String in ["rotten_corpse", "ghost"]:
		t.check(EnemyDB.ENEMIES.has(monster), "%s is not a monster" % monster)
		t.check(ResourceLoader.exists(EnemyDB.SHEETS % monster), "%s has no sprite sheet" % monster)
		t.check(ItemDB.LOOT_TABLES.has(monster), "%s drops nothing of its own" % monster)
	for i in 200:
		t.check(LootGenerator.make_equipment(30, 5).id != "ninefold_blade", "the Ninefold Blade dropped as loot")
	t.equal(AbilityDB.moves_for("ninefold_blade").size(), 4, "the blade has its own four moves")


func test_a_boss_falls_twice(t: TestContext) -> void:
	var main := await t.game()
	var player: Player = main.get_node("Player")
	var spawner: EnemySpawner = main.get_node("Enemies")
	var boss: Enemy = spawner.enemy_scene.instantiate()
	boss.boss_id = "hollow_king"
	boss.position = player.global_position + Vector2(160, 0)
	boss.target = player
	boss.configure(5, Enemy.Rank.BOSS, "husk")
	spawner.add_child(boss)
	var deaths := [0]
	boss.died.connect(func(_e: Enemy) -> void: deaths[0] += 1)
	await t.frames(2)
	boss.take_damage(1e9, Vector2.ZERO)
	await t.frames(2)
	t.check(boss.state != Enemy.State.DEAD, "the Hollow King rises again")
	t.equal(deaths[0], 0, "its first fall is not its death")
	t.equal(boss.health.current, boss.health.max_health, "it rises whole")
	t.equal(boss.display_name, BossDB.REVIVES["hollow_king"]["name"], "it rises under a new name")
	t.equal(boss.take_damage(1e9, Vector2.ZERO), 0.0, "it cannot be struck as it rises")
	boss.revive_shield = 0.0
	boss.take_damage(1e9, Vector2.ZERO)
	await t.frames(2)
	t.check(boss.state == Enemy.State.DEAD, "the second fall is the last")
	t.equal(deaths[0], 1, "it dies once")


func test_every_quest_pays_in_goods(t: TestContext) -> void:
	for quest in QuestBookDB.all():
		var items: Array = quest["rewards"]["items"]
		t.check(not items.is_empty(), "%s pays no goods" % quest["id"])
		for entry: Array in items:
			t.check(entry[0] == QuestBookDB.GEAR or ItemDB.ITEMS.has(entry[0]), "%s pays an unknown item %s" % [quest["id"], entry[0]])
		for need: String in quest["requires"]:
			t.check(not QuestBookDB.find(need).is_empty(), "%s needs a quest that does not exist: %s" % [quest["id"], need])
	t.check(QuestBookDB.all().any(func(q: Dictionary) -> bool: return q["chapter"] == "legends"), "the Legends chapter has quests")
	t.check(QuestBookDB.all().any(func(q: Dictionary) -> bool: return q["chapter"] == "dead"), "the Restless Dead chapter has quests")


func test_villagers_and_their_errands(t: TestContext) -> void:
	var seen := {}
	for index in 7:
		var person := VillagerLife.make(Vector2i(40, -30), index, 12345)
		t.check(VillagerLife.JOBS.has(person["job"]), "a villager with an unknown trade")
		t.check(Appearance.RACES.has(person["look"]["race"]), "a villager of an unknown race")
		t.check(not seen.has(person["name"]), "two villagers named %s" % person["name"])
		seen[person["name"]] = true
	t.equal(VillagerLife.make(Vector2i(40, -30), 0, 12345)["job"], "guard", "every village has a guard")
	for job: String in VillagerLife.JOBS:
		var data: Dictionary = VillagerLife.JOBS[job]
		for entry: Array in data["fetch"] + data["pays"]:
			t.check(entry[0] == "@gear" or ItemDB.ITEMS.has(entry[0]), "%s deals in an unknown item %s" % [job, entry[0]])
		for day in 6:
			var errand := Errands.make("villager:1,1:%s" % job, job, "Test", 10, day, 0)
			t.check(errand["kind"] in ["fetch", "cull"], "%s asks for something odd" % job)
			t.check(int(errand["need"]) > 0 and int(errand["gold"]) > 0, "%s's errand asks or pays nothing" % job)
	var main := await t.game()
	var player: Player = main.get_node("Player")
	var errands: Errands = main.get_node("Errands")
	var npc := Npc.create("villager", player.global_position + Vector2(30, 0))
	var person := VillagerLife.make(Vector2i(3, 3), 2, 1)
	npc.villager_name = person["name"]
	npc.job = person["job"]
	npc.look = person["look"]
	npc.villager_key = person["key"]
	main.add_child(npc)
	await t.frames(2)
	var errand := errands.offer_for(npc)
	t.equal(errands.accept(npc), "", "an errand can be taken")
	var gold := player.inventory.gold
	if errand["kind"] == "fetch":
		t.check(not errands.can_hand_over(npc), "nothing to hand over yet")
		player.inventory.add(Item.create(errand["target"], int(errand["need"])))
		t.equal(errands.hand_over(npc), "", "the things asked for are handed over")
	else:
		for i in int(errand["need"]):
			Events.enemy_killed.emit({"id": errand["target"], "rank": "normal", "level": 1, "position": Vector2.ZERO})
	t.check(player.inventory.gold > gold, "the errand pays")
	t.equal(int(errands.helped.get(npc.villager_key, 0)), 1, "the villager remembers the help")
	t.check(errands.offer_for(npc).is_empty(), "one errand a day")
	npc.queue_free()


func test_each_weapon_has_its_own_mastery(t: TestContext) -> void:
	var main: Node = await t.game()
	var player: Player = main.get_node("Player")
	var mastery := player.mastery
	# Old saves kept one level per kind: every sword starts from it.
	mastery.load_data({"levels": {"swords": 30, "axes": 1}, "xp": {}})
	t.equal(mastery.level_of("sword"), 30, "a plain sword starts at the old sword level")
	t.equal(mastery.level_of("flame_sword"), 30, "so does every other sword")
	t.equal(mastery.level_of("axe"), 1, "axes had no old level")
	# Training one sword leaves the others where they were.
	mastery.add_xp("sword", WeaponMastery.xp_required(30) + 1.0)
	t.equal(mastery.level_of("sword"), 31, "the trained sword grew")
	t.equal(mastery.level_of("flame_sword"), 30, "another sword did not")
	t.equal(mastery.level_of("swords"), 31, "a kind reports its best weapon (for quests)")
	# Kills go to the weapon that last struck with that kind.
	Events.damage_dealt.emit("flame_sword", 1.0)
	var before := mastery.xp_of("flame_sword")
	Events.enemy_killed.emit(_kill("elite", 40))
	t.check(mastery.xp_of("flame_sword") > before, "the kill trained the weapon that made it")
	# A weapon's own moves rank with its own mastery.
	var move := "wm_flame_sword_2"
	if AbilityDB.ABILITIES.has(move):
		t.equal(player.abilities.rank(move), AbilityDB.rank(move, mastery.level_of("flame_sword")), "moves rank by their weapon's mastery")
	# Saving keeps every weapon apart.
	var copy := WeaponMastery.new()
	copy.load_data(mastery.save_data())
	t.equal(copy.level_of("sword"), 31, "saved level of the trained sword")
	t.equal(copy.level_of("flame_sword"), mastery.level_of("flame_sword"), "saved level of the sword that made the kill")
	t.equal(copy.level_of("frost_sword"), 30, "an untouched sword still starts at the old level")
	copy.free()
	# The old weapon abilities are templates, not abilities of their own.
	t.check(not AbilityDB.ABILITIES.has("heavy_slash"), "the old Heavy Slash is gone from the ability list")
	t.check(AbilityDB.BASE_ABILITIES.has("heavy_slash"), "but stays as a template for weapon moves")


func test_a_new_pet_does_not_push_out_the_follower(t: TestContext) -> void:
	var main: Node = await t.game()
	var player: Player = main.get_node("Player")
	var pets := player.pets
	pets.pets.clear()
	pets.active = -1
	pets._adopt("rabbit", "critter", "First")
	t.equal(pets.active, 0, "the first pet follows at once")
	pets._adopt("rabbit", "critter", "Second")
	t.equal(pets.active, 0, "the first pet keeps following when a second is tamed")
	pets.set_active(1)
	t.equal(pets.current()["name"], "Second", "the choice can still be made")


func test_map_waypoint_and_filters_are_saved(t: TestContext) -> void:
	var main: Node = await t.game()
	var menu := MapMenu.new()
	MapMenu.waypoint = Vector2(320, -96)
	MapMenu.hidden_groups = {"life": true}
	var data := menu.save_data()
	MapMenu.waypoint = null
	MapMenu.hidden_groups = {}
	menu.load_data(data)
	t.equal(MapMenu.waypoint, Vector2(320, -96), "waypoint after a save")
	t.check(MapMenu.hidden_groups.has("life"), "hidden legend group after a save")
	menu.free()
	MapMenu.waypoint = null
	MapMenu.hidden_groups = {}


func test_trophy_hall_gives_bonuses(t: TestContext) -> void:
	var main: Node = await t.game()
	var player: Player = main.get_node("Player")
	var buildings: Buildings = main.get_node("Buildings")
	var codex: Codex = main.get_node("Codex")
	codex.boss_kills["hollow_king"] = 1
	t.check("hollow_king" in Trophies.earned(codex), "a beaten boss's trophy is earned")
	t.check(not "frostwarden" in Trophies.earned(codex), "an unbeaten one is not")
	for boss: String in Trophies.TROPHIES:
		t.check(BossDB.BOSSES.has(boss), "%s is a real boss" % boss)
		var rows: Array = Trophies.SHAPES[Trophies.TROPHIES[boss]["shape"]]
		for row: String in rows:
			t.equal(row.length(), String(rows[0]).length(), "%s's trophy rows are even" % boss)
	var before := player.stats.get_stat("physical_damage")
	var first := {"id": 9001, "kind": "trophy_stand", "where": "house:1", "x": 2, "y": 2, "items": []}
	var second := {"id": 9002, "kind": "trophy_stand", "where": "house:1", "x": 4, "y": 2, "items": []}
	buildings.records.append(first)
	buildings.records.append(second)
	buildings.set_trophy(first, "hollow_king")
	t.check(player.stats.get_stat("physical_damage") > before, "a trophy on show gives its bonus")
	buildings.set_trophy(second, "hollow_king")
	t.equal(first.get("trophy", ""), "", "a trophy moves rather than showing twice")
	t.equal(buildings.shown_trophies().size(), 1, "one trophy on show")
	buildings.take_down(second)
	t.equal(buildings.shown_trophies().size(), 0, "taking the stand down takes the trophy off show")
	t.check(is_equal_approx(player.stats.get_stat("physical_damage"), before), "and its bonus goes")
	buildings.records.erase(first)


func test_pet_talents_and_gear(t: TestContext) -> void:
	var main: Node = await t.game()
	var player: Player = main.get_node("Player")
	var pets := player.pets
	pets._adopt("husk", "monster", "Gristle")
	var index := pets.pets.size() - 1
	var pet: Dictionary = pets.pets[index]
	pet["level"] = 10
	t.equal(pets.points_left(pet), 2, "a talent point every five levels")
	var plain := pets.damage(pet)
	t.equal(pets.learn(index, "ferocity"), "", "ferocity can be learned")
	t.check(pets.damage(pet) > plain, "ferocity makes it hit harder")
	t.check(pets.learn(index, "nonsense") == "", "an unknown talent is ignored")
	pets._adopt("rabbit", "critter", "Bun")
	var bunny: Dictionary = pets.pets[pets.pets.size() - 1]
	t.check(not "ferocity" in pets.talents_for(bunny), "a critter cannot learn to fight")
	var collar := Item.create("spiked_collar")
	player.inventory.add(collar)
	var harder := pets.damage(pet)
	t.equal(pets.put_on(index, collar), "", "a collar goes on")
	t.check(pets.damage(pet) > harder, "the collar makes it hit harder")
	t.equal(player.inventory.count_of("spiked_collar"), 0, "the collar left the bag")
	var charm := Item.create("lucky_charm")
	player.inventory.add(charm)
	pets.put_on(index, charm)
	pets.set_active(index)
	t.check(pets.owner_mods(pet).has("magic_find"), "a lucky charm helps its owner")
	t.equal(pets.take_off(index, "collar"), "", "the collar comes off")
	t.equal(player.inventory.count_of("spiked_collar"), 1, "back in the bag")
	pets.unlearn(index)
	t.equal(pets.points_left(pet), 2, "talents can be forgotten")


func test_mount_tack_and_races(t: TestContext) -> void:
	var main: Node = await t.game()
	var player: Player = main.get_node("Player")
	var stable := player.stable
	player.inventory.add(Item.create("racing_saddle"))
	player.inventory.add(Item.create("iron_barding"))
	for item: Item in player.inventory.items.duplicate():
		if Stable.slot_of(item) != "":
			t.equal(stable.put_on(item), "", "%s goes on" % item.display_name())
	t.check(is_equal_approx(stable.speed_bonus(), 0.12), "a racing saddle is 12% faster")
	t.check(stable.steady(), "iron barding keeps you in the saddle")
	var times := RaceCourse.par_times(Vector2.ZERO, [Vector2(1000, 0), Vector2(1000, 1000), Vector2.ZERO] as Array[Vector2])
	t.check(times[0] > times[1] and times[1] > times[2], "bronze is slower than silver, silver than gold")
	var first := stable.record_race("race:test", 40.0, 1)
	t.check(first["new_medal"] and first["new_best"], "a first finish is a new best and a medal")
	var again := stable.record_race("race:test", 45.0, 1)
	t.check(not again["new_medal"] and not again["new_best"], "a slower run changes nothing")
	stable.record_race("race:test", 30.0, 3)
	t.equal(stable.medal_count(3), 1, "a gold is kept")
	t.equal(stable.take_off("saddle"), "", "the saddle comes off")
	t.equal(stable.speed_bonus(), 0.0, "and the speed with it")
	# A village course is laid on dry ground and ends at the post.
	var world: World = main.get_node("World")
	var post := world.cell_to_world(Vector2i(4, 4))
	var gates := RaceCourse.plan(world, Vector2i.ZERO, post)
	t.check(gates.size() >= 4, "a course has gates (%d)" % gates.size())
	t.equal(gates[-1], post, "the course ends at the post")
