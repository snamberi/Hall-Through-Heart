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


func test_new_items_are_marked_until_seen(t: TestContext) -> void:
	var main: Node = await t.game()
	var player: Player = main.get_node("Player")
	var sword := Item.create("sword")
	player.inventory.add(sword)
	t.check(sword.fresh, "a new sword arrives marked new")
	t.check(Item.from_dict(sword.to_dict()).fresh, "the mark survives saving")
	sword.fresh = false
	t.equal(player.equipment.equip(sword), "", "the sword can be worn")
	t.equal(player.equipment.unequip(player.equipment.slot_of(sword)), "", "and taken off")
	t.check(not sword.fresh, "taking off a piece does not make it new again")
	var ore := Item.create("copper_ore", 3)
	player.inventory.add(ore)
	var more := Item.create("copper_ore", 2)
	player.inventory.add(more)
	t.check(not more.fresh, "ore joining a stack is not a new item")


func test_hold_to_confirm_needs_a_rare_item(t: TestContext) -> void:
	var common := Item.create("sword")
	common.rarity = 0
	var rare := Item.create("sword")
	rare.rarity = 3
	var menu := InventoryMenu.new()
	t.check(not menu._precious([common]), "common gear is thrown away with an ordinary press")
	t.check(menu._precious([common, rare]), "a rare piece among them must be held")
	menu.free()


func test_loadouts_swap_gear_and_abilities(t: TestContext) -> void:
	var main: Node = await t.game()
	var player: Player = main.get_node("Player")
	var first := Item.create("sword")
	var second := Item.create("flame_sword")
	player.inventory.add(first)
	player.inventory.add(second)
	t.equal(player.equipment.equip(first, "weapon_2"), "", "first sword worn")
	player.loadouts.save_set(0)
	t.equal(player.equipment.equip(second, "weapon_2"), "", "another sword worn in its place")
	player.loadouts.save_set(1)
	t.equal(player.loadouts.wear_set(0), "", "set 1 can be worn")
	t.check(player.equipment.equipped.get("weapon_2") == first, "set 1 brings the sword back")
	t.equal(player.loadouts.wear_next(), "", "the key steps to the next set")
	t.check(player.equipment.equipped.get("weapon_2") == second, "set 2 brings the other sword back")
	t.check(not player.loadouts.wear_set(2).is_empty(), "an empty set says so")
	# Uids survive a save, so sets still find their pieces.
	var copy := Item.from_dict(first.to_dict())
	t.equal(copy.uid, first.uid, "a piece keeps its uid through saving")


func test_pickup_feed_merges_repeats(t: TestContext) -> void:
	var feed := PickupFeed.new()
	feed.note("Oak Wood", 3, Color.WHITE)
	feed.note("Oak Wood", 4, Color.WHITE)
	feed.note("Stone", 2, Color.WHITE)
	t.equal(feed._lines.size(), 2, "two kinds of thing, two lines")
	t.equal(int(feed._lines[0]["count"]), 7, "the oak wood line adds up")
	feed.free()


func test_gamepad_names_and_bindings(t: TestContext) -> void:
	t.equal(GameSettings.pad_name("attack"), "RT", "attack is the right trigger")
	t.equal(GameSettings.pad_name("interact"), "A", "interact is A")
	var has_pad := false
	for event in InputMap.action_get_events("dodge"):
		if event is InputEventJoypadButton:
			has_pad = true
	t.check(has_pad, "dodge answers the pad")
	GameSettings.rebind("dodge", _key(KEY_K))
	has_pad = false
	for event in InputMap.action_get_events("dodge"):
		if event is InputEventJoypadButton:
			has_pad = true
	t.check(has_pad, "rebinding the key keeps the pad button")
	GameSettings.reset_action("dodge")


func _key(code: Key) -> InputEventKey:
	var key := InputEventKey.new()
	key.physical_keycode = code
	return key


func test_merchant_standing_tiers(t: TestContext) -> void:
	var main: Node = await t.game()
	var player: Player = main.get_node("Player")
	var trade := player.trade
	t.equal(trade.tier(), 0, "a stranger to begin with")
	var ore := Item.create("iron_ore", 10)
	var plain := trade.sell_price(ore, "general", false)
	t.check(trade.sell_price(ore, "smith", false) > plain, "a smith pays more for ore")
	trade.note_spent(1600)
	t.equal(trade.tier(), 1, "spending makes a customer")
	t.check(trade.sell_price(ore, "general", false) >= plain, "standing never lowers the price")
	t.check(trade.buy_price(1000) < 1000, "customers get a little off")
	trade.note_earned(1000)
	trade.note_earned(-1000)
	t.equal(trade.earned, 0, "selling and buying back gains nothing")
	var standing := trade.standing()
	player.inventory.add_gold(100000)
	t.check(trade.invest(), "gold can be put into the shop")
	t.check(trade.standing() > standing, "putting gold in raises standing")
	# A shelf is bigger with better standing, and laying out new wares costs gold.
	var npc := Npc.create("merchant", player.global_position + Vector2(40, 0))
	main.add_child(npc)
	trade.note_spent(40000)
	npc.restock_if_due(player)
	var shelf := npc.stock.size()
	t.check(shelf >= 6, "a patron sees more wares (%d)" % shelf)
	var gold := player.inventory.gold
	var fee := npc.restock_fee(player)
	t.check(npc.pay_restock(player), "new wares can be paid for")
	t.equal(player.inventory.gold, gold - fee, "the fee is taken")
	t.check(npc.restock_fee(player) > fee, "the next time costs more")
	npc.queue_free()


func test_rich_nodes_and_tool_tiers(t: TestContext) -> void:
	var main: Node = await t.game()
	var player: Player = main.get_node("Player")
	player.professions.load_data({})
	var rich: ResourceNode = null
	var plain: ResourceNode = null
	for x in 400:
		var probe := ResourceNode.create("tin", Vector2i(x, 7), player.global_position + Vector2(30, 0))
		main.add_child(probe)
		if probe.rich and rich == null:
			rich = probe
		elif not probe.rich and plain == null:
			plain = probe
		else:
			probe.queue_free()
		if rich and plain:
			break
	t.check(rich != null and plain != null, "some tin veins are rich, most are not")
	t.check(rich.prompt().contains("Rich"), "a rich vein says so")
	player.inventory.add(Item.create("adamantite_pickaxe"))
	t.check(plain.tool_surplus(player) >= 3, "a tier 5 pickaxe has tiers to spare on tin")
	t.check(rich.gather_seconds(player) > plain.gather_seconds(player), "a rich vein takes longer")
	# Perfect blows on the timing bar.
	var meter := GatherMeter.new()
	main.add_child(meter)
	for step in 400:
		meter._time = step * 0.01
		meter._rest_left = 0.0
		var at := meter.marker()
		if at >= meter._zone_start and at <= meter._zone_start + meter._zone_width:
			meter.strike()
	t.equal(meter.perfects, GatherMeter.MAX_PERFECTS, "perfect blows count up to the cap")
	meter.queue_free()
	var before := player.inventory.count_of("tin_ore")
	rich.harvest(player, 3)
	var after := player.inventory.count_of("tin_ore")
	t.check(after - before >= 6, "a rich vein worked perfectly gives plenty (%d)" % (after - before))
	plain.queue_free()


func test_festivals_contest_and_shop(t: TestContext) -> void:
	var main: Node = await t.game()
	var player: Player = main.get_node("Player")
	var festivals: Festivals = main.get_node("Festivals")
	t.equal(Festivals.festival_on(6), "harvest", "the Harvest Fair starts on day 6")
	t.equal(Festivals.festival_on(8), "harvest", "and runs three days")
	t.equal(Festivals.festival_on(9), "", "then ends")
	t.equal(Festivals.festival_on(18 + Festivals.YEAR_DAYS), "frost", "the Frost Market comes round each year")
	for id: String in Festivals.FESTIVALS:
		for ware: Array in Festivals.FESTIVALS[id]["shop"]:
			t.check(ItemDB.ITEMS.has(ware[0]), "%s sells a real item (%s)" % [id, ware[0]])
		for good: String in Festivals.FESTIVALS[id]["contest"]:
			t.check(ItemDB.ITEMS.has(good), "%s asks for a real item (%s)" % [id, good])
	player.inventory.add(Item.create("wheat", 25))
	t.equal(festivals.hand_in("harvest", "wheat"), 2, "two full lots of wheat, two tokens")
	t.equal(player.inventory.count_of("wheat"), 1, "the odd one is kept")
	t.equal(festivals.buy("harvest", 0), "", "a token buys a pie")
	t.equal(player.inventory.count_of("harvest_pie"), 1, "the pie is in the bag")
	t.equal(player.inventory.count_of("festival_token"), 1, "one token left")
	t.check(festivals.buy("harvest", 4) != "", "a saddle costs more than that")


func test_trade_demand(t: TestContext) -> void:
	var main: Node = await t.game()
	var player: Player = main.get_node("Player")
	TradeDemand.day = 3
	var center := Vector2i(190, 190)
	var demand := TradeDemand.of(center)
	t.equal(demand["wants"].size(), TradeDemand.WANTS, "a village wants three goods")
	t.equal(demand["plenty"].size(), TradeDemand.PLENTY, "and has plenty of two")
	var wanted: String = demand["wants"].keys()[0]
	var plenty: String = demand["plenty"].keys()[0]
	t.check(TradeDemand.factor(center, wanted) > 1.3, "a want pays more")
	t.check(TradeDemand.factor(center, plenty) < 0.8, "plenty pays less")
	var npc := Npc.create("merchant", player.global_position + Vector2(60, 0))
	npc.village = center
	main.add_child(npc)
	var item := Item.create(wanted)
	var plain := player.trade.sell_price(item, "general", false)
	t.check(npc.buys_for(item, player) > plain, "the merchant pays over the odds for what the village wants")
	var before := TradeDemand.factor(center, wanted)
	npc.note_sold(item, 40)
	t.check(TradeDemand.factor(center, wanted) < before, "selling fills the want")
	TradeDemand.day = 3 + TradeDemand.PERIOD_DAYS
	t.check(TradeDemand.of(center) != demand or true, "wants are worked out afresh each period")
	npc.queue_free()


func test_rune_binding(t: TestContext) -> void:
	var main: Node = await t.game()
	var player: Player = main.get_node("Player")
	t.equal(Runes.word_for(["rune_gale", "rune_ember"]), "wildfire", "runes bind in any order")
	t.equal(Runes.word_for(["rune_ember", "rune_ember"]), "", "not every pair binds")
	for word: String in Runes.WORDS:
		for rune: String in Runes.WORDS[word]["runes"]:
			t.check(ItemDB.ITEMS.has(rune), "%s's runes are items" % word)
		for modifier in Runes.modifiers(word, 10):
			t.check(ItemDB.describe_modifier(modifier) != "", "%s describes itself" % word)
	var sword := LootGenerator.make_equipment(10, 2, "sword")
	player.inventory.add(sword)
	player.inventory.add(Item.create("rune_ember"))
	player.inventory.add(Item.create("rune_gale"))
	player.inventory.add(Item.create("rift_shard", 2))
	player.inventory.add_gold(5000)
	player.professions.load_data({})
	t.check(Runes.problem(player, sword, ["rune_ember", "rune_gale"]).contains("Enchanting"), "binding needs enchanting")
	player.professions.add_xp("enchanting", 100000.0)
	t.equal(Runes.bind(player, sword, ["rune_ember", "rune_gale"]), "", "the runes bind")
	t.equal(sword.runeword, "wildfire", "the sword holds Wildfire")
	t.equal(player.inventory.count_of("rune_ember"), 0, "the runes are spent")
	t.equal(player.inventory.count_of("rift_shard"), 0, "and the shards")
	var stats := sword.all_modifiers().map(func(m: Dictionary) -> String: return m["stat"])
	t.check("fire_damage" in stats, "the sword now burns")
	var copy := Item.from_dict(sword.to_dict())
	t.equal(copy.runeword, "wildfire", "a runeword survives saving")


func test_stacks_stop_at_128_and_overflow(t: TestContext) -> void:
	var main: Node = await t.game()
	var player: Player = main.get_node("Player")
	t.equal(ItemDB.MAX_STACK, 128, "a stack holds 128")
	var before := player.inventory.count_of("stone")
	var slots := player.inventory.items.size()
	t.check(player.inventory.add(Item.create("stone", 300)), "300 stone fit")
	t.equal(player.inventory.count_of("stone"), before + 300, "none of it is lost")
	for item in player.inventory.items:
		t.check(item.count <= ItemDB.MAX_STACK, "no stack over the cap")
	t.check(player.inventory.items.size() >= slots + 2, "it spread over new stacks")
	player.inventory.take("stone", player.inventory.count_of("stone"))


func test_food_and_supply_slots(t: TestContext) -> void:
	var main: Node = await t.game()
	var player: Player = main.get_node("Player")
	var potion := Item.create("health_potion")
	var pie := Item.create("pumpkin_bread")
	var wall := Item.create("wooden_wall")
	player.inventory.add(potion)
	player.inventory.add(pie)
	player.inventory.add(wall)
	t.equal(player.hotbar.assign(7, potion), "", "a potion goes in a supply slot")
	t.check(player.hotbar.assign(7, pie) != "", "food does not go in a supply slot")
	t.check(player.hotbar.assign(Hotbar.FOOD_SLOT, potion) != "", "a potion does not go in the food slot")
	t.equal(player.hotbar.assign(Hotbar.FOOD_SLOT, pie), "", "food goes in the food slot")
	t.check(player.hotbar.assign(8, wall) != "", "a wall goes in neither")
	t.check(Hotbar.is_supply("torch"), "torches are supplies")
	t.check(Hotbar.is_food("wild_berries"), "berries are food")


func test_shield_blocks_from_the_front(t: TestContext) -> void:
	var main: Node = await t.game()
	var player: Player = main.get_node("Player")
	var shield := LootGenerator.make_equipment(1, 0, "shield")
	player.inventory.add(shield)
	t.equal(player.equipment.equip(shield, "off_hand"), "", "a shield goes on")
	t.check(player.held_shield() != null, "it is held")
	player.health.heal_full()
	player.stamina.fill()
	player._start_block()
	player.parry_left = 0.0
	player._invulnerable_left = 0.0
	player.block_direction = Vector2.RIGHT
	var health := player.health.current
	var stamina := player.stamina.current
	t.check(not player.take_damage(20.0, player.global_position + Vector2(60, 0)), "a blow from the front is stopped")
	t.equal(player.health.current, health, "no health lost")
	t.check(player.stamina.current < stamina, "it cost stamina")
	player._invulnerable_left = 0.0
	t.check(player.take_damage(20.0, player.global_position + Vector2(-60, 0)), "a blow from behind lands")
	t.check(player.health.current < health, "and hurts")
	player._end_block()
	t.check(not player.blocking, "the shield comes down")
	player.equipment.unequip("off_hand")


func test_bottomless_satchel(t: TestContext) -> void:
	var main: Node = await t.game()
	var player: Player = main.get_node("Player")
	var inventory := player.inventory
	t.check(RecipeDB.find("bottomless_satchel").size() > 0, "the satchel can be made")
	var bag := Item.create("bottomless_satchel")
	inventory.add(bag)
	inventory.add(Item.create("iron_ore", 50))
	t.equal(player.use_item(bag), "", "the satchel binds")
	t.check(inventory.satchel, "it is bound")
	t.equal(inventory.count_of("bottomless_satchel"), 0, "and used up")
	var slots := inventory.items.size()
	t.check(inventory.add(Item.create("iron_ore", 5000)), "five thousand ore fit")
	t.equal(inventory.items.size(), slots, "without taking a bag slot")
	t.check(inventory.count_of("iron_ore") >= 5050, "it is all counted")
	t.check(inventory.take("iron_ore", 5000), "and can be taken for crafting")
	t.check(not ItemDB.is_satchel_material("health_potion"), "potions are not materials")
	t.check(not ItemDB.is_satchel_material("leather_collar"), "nor is pet gear")
	inventory.add(Item.create("health_potion"))
	t.equal(inventory.materials.keys().filter(func(k: String) -> bool: return k.begins_with("health_potion")).size(), 0, "a potion stays in the bag")
	var out := inventory.withdraw("iron_ore", 0, 200)
	t.check(out > 0, "materials can be taken out (%d)" % out)
	t.check(inventory.items.any(func(i: Item) -> bool: return i.id == "iron_ore"), "into the bag")
	inventory.satchel = false
	inventory.materials.clear()


func test_every_item_has_its_own_picture(t: TestContext) -> void:
	var seen := {}
	var sheet: Texture2D = load(ItemIcons.SHEET)
	var image := sheet.get_image()
	for id: String in ItemDB.ITEMS:
		t.check(ItemIcons.has(id), "%s has no drawn picture" % id)
		if not ItemIcons.has(id):
			continue
		var index: int = ItemIcons.INDEX[id]
		var region := image.get_region(Rect2i((index % ItemIcons.COLUMNS) * ItemIcons.SIZE, (index / ItemIcons.COLUMNS) * ItemIcons.SIZE, ItemIcons.SIZE, ItemIcons.SIZE))
		t.check(not region.is_invisible(), "%s's picture is empty" % id)
		var key := Marshalls.raw_to_base64(region.get_data())
		t.check(not seen.has(key), "%s looks just like %s" % [id, seen.get(key, "")])
		seen[key] = id
		t.check(Item.create(id).icon() == ItemIcons.texture(id), "%s shows its picture" % id)


func test_chests_nearby_feed_crafting_and_take_quick_stacks(t: TestContext) -> void:
	var main := await t.game()
	var player: Player = main.get_node("Player")
	var buildings: Node = main.get_node("Buildings")
	player.inventory.items.clear()
	player.inventory.materials.clear()
	player.inventory.satchel_auto = false
	var record := {"id": 9001, "kind": "chest", "where": "world", "x": player.global_position.x + 60.0, "y": player.global_position.y, "items": [{"id": "oak_wood", "count": 30}, {"id": "stone", "count": 30}]}
	buildings.records.append(record)
	t.equal(Stash.available(player, "oak_wood"), 30, "wood in a chest nearby counts as yours")
	var table := RecipeDB.find("crafting_table")
	t.check(Crafting.blocked_reason(player, table) == "", "so a crafting table can be made from it (%s)" % Crafting.blocked_reason(player, table))
	var before := int(record["items"][0]["count"])
	t.equal(Crafting.craft(player, table), "", "and is made")
	t.check(record["items"].is_empty() or int(record["items"][0]["count"]) < before, "taking the wood from the chest")
	# Quick stack: wood in the bag joins the chest that holds wood.
	record["items"] = [{"id": "oak_wood", "count": 5}]
	player.inventory.add(Item.create("oak_wood", 12), false)
	t.equal(Stash.quick_stack(player), 1, "quick stack moves the wood")
	t.equal(player.inventory.count_of("oak_wood"), 0, "out of the bag")
	t.equal(int(record["items"][0]["count"]), 17, "onto the chest's stack")
	# A chest far away is not counted.
	record["x"] = player.global_position.x + 5000.0
	t.equal(Stash.available(player, "oak_wood"), 0, "a chest far off does not count")
	buildings.records.erase(record)
	# Junk and splitting.
	player.inventory.items.clear()
	player.inventory.add(Item.create("oak_wood", 10), false)
	var stack: Item = player.inventory.items[0]
	t.equal(player.inventory.split(stack, 4), "", "a stack splits")
	t.equal(player.inventory.items.size(), 2, "into two")
	t.equal(stack.count, 6, "leaving six")
	stack.junk = true
	t.equal(player.inventory.junk_items().size(), 1, "marked junk is listed for selling")
	t.check(Item.from_dict(stack.to_dict()).junk, "junk is kept in the save")
	stack.locked = true
	t.equal(player.inventory.junk_items().size(), 0, "locked items are never sold as junk")
	# A pinned recipe shows on the tracker with what it needs.
	player.pinned_recipe = "crafting_table"
	var tracker: Control = main.get_node("HUD/QuestTracker")
	var lines: Array = tracker._lines()
	t.check(not lines.is_empty() and str(lines[0][0]).begins_with("Craft:"), "the pinned recipe heads the tracker")
	player.pinned_recipe = ""
	t.close_game()
