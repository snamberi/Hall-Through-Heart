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
	t.check(TalentDB.NODES.size() >= 100, "the tree has only %d talents" % TalentDB.NODES.size())
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
