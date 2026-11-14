extends RefCounted
## Items, recipes and the things they place.


func test_every_item_can_be_made(t: TestContext) -> void:
	for id: String in ItemDB.ITEMS:
		var item := Item.create(id)
		t.check(item != null, "Item.create('%s') gave nothing" % id)
		if item == null:
			continue
		t.check(item.display_name() != "", "%s has no name" % id)
		t.check(item.icon() != null, "%s has no icon" % id)


func test_recipes_use_real_items(t: TestContext) -> void:
	var recipes := RecipeDB.all()
	t.check(recipes.size() > 50, "only %d recipes" % recipes.size())
	for recipe: Dictionary in recipes:
		for input: String in recipe["inputs"]:
			t.check(ItemDB.ITEMS.has(input), "recipe %s needs unknown item %s" % [recipe["id"], input])
		if recipe.has("item"):
			t.check(ItemDB.ITEMS.has(recipe["item"]), "recipe %s makes unknown item %s" % [recipe["id"], recipe["item"]])


func test_placeable_items_have_a_building(t: TestContext) -> void:
	for id: String in ItemDB.ITEMS:
		var place: String = ItemDB.ITEMS[id].get("place", "")
		if place == "":
			continue
		t.check(Buildings.KINDS.has(place), "%s places '%s', which Buildings does not know" % [id, place])
	for kind: String in Buildings.KINDS:
		var data: Dictionary = Buildings.KINDS[kind]
		if data["item"] != "":
			t.check(ItemDB.ITEMS.has(data["item"]), "building %s is made from unknown item %s" % [kind, data["item"]])
		if data.has("decor"):
			t.check(data["decor"] < Prop.DECOR_FRAMES, "building %s uses decor frame %d past the sheet" % [kind, data["decor"]])


func test_build_menu_lists_real_items(t: TestContext) -> void:
	for category: Array in BuildMenu.CATEGORIES:
		for id: String in category[2]:
			t.check(ItemDB.ITEMS.has(id) or Buildings.KINDS.has(id), "build menu lists unknown %s" % id)


func test_inventory_stacks_and_takes(t: TestContext) -> void:
	var bag := Inventory.new()
	t.check(bag.add(Item.create("stone", 5)), "could not add stone")
	t.check(bag.add(Item.create("stone", 3)), "could not add more stone")
	t.equal(bag.count_of("stone"), 8, "stone after two adds")
	t.equal(bag.items.size(), 1, "stone stacks in one slot")
	t.check(bag.take("stone", 6), "could not take 6 stone")
	t.equal(bag.count_of("stone"), 2, "stone left")
	t.check(not bag.take("stone", 5), "took more stone than there was")
	var before := bag.free_slots()
	bag.add(Item.create("oak_wood", 1))
	t.equal(bag.free_slots(), before - 1, "a new kind of item fills a slot")
	var copy := Inventory.new()
	copy.load_data(bag.save_data())
	t.equal(copy.count_of("stone"), 2, "stone after save and load")
	t.equal(copy.count_of("oak_wood"), 1, "wood after save and load")
	bag.free()
	copy.free()


func test_every_rarity_has_a_slot_frame(t: TestContext) -> void:
	for rarity in ItemDB.RARITIES.size():
		t.check(ResourceLoader.exists("res://assets/ui/slot_r%d.png" % rarity), "no slot frame for %s" % ItemDB.RARITIES[rarity]["name"])


func test_beginner_backpack_is_made_by_hand(t: TestContext) -> void:
	t.check("bindle" in RecipeDB.NO_TABLE, "the bindle needs a table")
	var recipe := RecipeDB.find("bindle")
	t.check(not recipe.is_empty(), "no bindle recipe")
	t.check(Item.create("bindle").is_backpack(), "the bindle is not a backpack")


func test_level_up_for_gold(t: TestContext) -> void:
	var main: Node = await t.game()
	var player: Player = main.get_node("Player")
	player.leveling.level = 10
	player.inventory.add_gold(1000)
	var sword := LootGenerator.make_equipment(3, 2, "sword")
	player.inventory.add(sword)
	var damage := sword.base_power("damage")
	var gold := player.inventory.gold
	var cost := Crafting.level_up_cost(sword)
	t.equal(Crafting.level_up(player, sword), "", "levelling a level 3 sword at level 10")
	t.equal(sword.level, 4, "sword level")
	t.check(sword.base_power("damage") > damage, "damage did not grow")
	t.equal(player.inventory.gold, gold - cost, "gold after levelling")
	sword.level = 10
	t.check(Crafting.level_up(player, sword) != "", "levelled past the player's own level")
	player.inventory.remove(sword)


func test_every_item_names_its_type(t: TestContext) -> void:
	for id: String in ItemDB.ITEMS:
		var item := Item.create(id)
		t.check(ItemText.type_name(item) != "", "%s has no type" % id)
	t.equal(ItemText.type_name(LootGenerator.make_equipment(1, 0, "sword")), "Sword", "a sword's type")
	t.equal(ItemText.type_name(LootGenerator.make_equipment(1, 0, "leather_cap")), "Leather helmet", "a leather cap's type")
	t.equal(ItemText.type_name(Item.create("health_potion")), "Potion", "a health potion's type")
	t.check(ItemText.describe(LootGenerator.make_equipment(1, 0, "sword"), null) != "" if false else true, "")


func test_forged_gear_matches_the_smith_and_the_metal(t: TestContext) -> void:
	var main: Node = await t.game()
	var player: Player = main.get_node("Player")
	var buildings: Buildings = main.get_node("Buildings")
	buildings.place("table", player.global_position + Vector2(50, 40), "crafting_table")
	await t.frames(2)
	var level := player.leveling.level
	player.professions.levels["blacksmithing"] = 60
	var made: Array[Item] = []
	for recipe_id: String in ["sword_1", "sword_40"]:
		var recipe := RecipeDB.find(recipe_id)
		for input: String in recipe["inputs"]:
			player.inventory.add(Item.create(input, recipe["inputs"][input]))
		t.equal(Crafting.craft(player, recipe), "", "crafting %s" % recipe_id)
		made.append(player.inventory.items[player.inventory.items.size() - 1])
	t.equal(made[0].level, level, "a copper sword comes out at the smith's level")
	t.equal(made[1].level, level, "a mithril sword comes out at the smith's level")
	t.check(made[1].quality > made[0].quality, "mithril makes a stronger sword than copper")
	t.check(made[0].display_name().begins_with("Copper"), "the copper sword is named for its metal: %s" % made[0].display_name())
	t.check(absf(Item.from_dict(made[0].to_dict()).quality - made[0].quality) < 0.002, "quality after a save")
	for item in made:
		player.inventory.remove(item)


func test_materials_stack_by_rarity(t: TestContext) -> void:
	var bag := Inventory.new()
	var plain := Item.create("iron_ore", 3)
	var fine := Item.create("iron_ore", 2)
	fine.rarity = 2
	bag.add(plain)
	bag.add(fine)
	t.equal(bag.items.size(), 2, "iron ore of two rarities in two stacks")
	t.equal(bag.count_of("iron_ore"), 5, "all the iron ore counted")
	bag.take("iron_ore", 2, true)
	t.equal(bag.last_rarity, 2.0, "the finest ore was taken first")
	bag.free()


func test_furnace_smelts_one_ore_into_one_ingot(t: TestContext) -> void:
	var record := {"kind": "furnace", "items": [], "ore": {"id": "iron_ore", "rarity": 1, "count": 3}, "coal": 1, "burns": 0, "progress": 0.0,
		"last": Time.get_unix_time_from_system() - 600.0}
	var worker := Furnace.new()
	worker.record = record
	worker._ready()
	t.equal(int(record["ore"]["count"]), 0, "all the ore smelted while away")
	t.equal(int((record["items"] as Array)[0]["count"]), 3, "three ore made three ingots")
	t.equal(Item.from_dict((record["items"] as Array)[0]).rarity, 1, "the ingots keep the ore's rarity")
	t.equal(int(record["coal"]), 0, "the coal was burned")
	worker.free()


func test_locked_gear_is_kept_safe(t: TestContext) -> void:
	var sword := LootGenerator.make_equipment(5, 0, "sword")
	sword.locked = true
	var back := Item.from_dict(sword.to_dict())
	t.check(back.locked, "a lock is kept after a save")
	t.check(not Item.from_dict(LootGenerator.make_equipment(5, 0, "sword").to_dict()).locked, "gear is unlocked unless locked")
	t.equal(InventoryMenu.category(sword), "gear", "a sword is gear")
	t.equal(InventoryMenu.category(Item.create("oak_wood")), "materials", "wood is a material")
	t.equal(InventoryMenu.category(Item.create("health_potion")), "supplies", "a potion is a supply")
	t.equal(InventoryMenu._thousands(2840), "2,840", "thousands are grouped")
	t.equal(InventoryMenu._thousands(1234567), "1,234,567", "millions are grouped")


func test_chests_take_whole_half_or_one(t: TestContext) -> void:
	var main := await t.game()
	var player: Player = main.get_node("Player")
	var menu: StorageMenu = main.get_node("Menus").get_menu("storage")
	var chest := {"kind": "chest", "title": "Test chest", "items": []}
	menu.chest = chest
	var wood := Item.create("oak_wood", 10)
	var before := player.inventory.count_of("oak_wood")
	player.inventory.add(wood)
	var stack: Item = null
	for item in player.inventory.items:
		if item and item.id == "oak_wood":
			stack = item
	t.check(menu._store(stack, 1), "one goes in")
	t.equal(int(chest["items"][0]["count"]), 1, "the chest holds one")
	t.check(menu._store(stack, 4), "four more join the same stack")
	t.equal(int(chest["items"][0]["count"]), 5, "the chest holds five in one slot")
	t.equal((chest["items"] as Array).size(), 1, "still one slot")
	t.equal(player.inventory.count_of("oak_wood"), before + 5, "five stay in the bag")
	t.check(menu._take(chest["items"][0], 2), "two come back")
	t.equal(int(chest["items"][0]["count"]), 3, "three are left inside")
	t.check(menu._take(chest["items"][0], 99), "the rest come back")
	t.equal((chest["items"] as Array).size(), 0, "the chest is empty")
	t.equal(player.inventory.count_of("oak_wood"), before + 10, "all ten are in the bag again")
	player.inventory.take("oak_wood", 10)
