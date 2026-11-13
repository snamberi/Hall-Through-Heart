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
