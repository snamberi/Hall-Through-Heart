extends RefCounted
## Trinkets: charms on head, body, feet and hands that grow from level 1
## to 3 by doing what they are about, give a strength, then a greater one
## with a small gift, then a power; the Orb of Awakening raises one at once.

const DB := preload("res://scripts/items/trinket_db.gd")


func _wear(player: Player, id: String) -> Item:
	var item := LootGenerator.make_trinket(id)
	player.inventory.add(item)
	t_problem = player.equipment.equip(item)
	return item


var t_problem := ""


func test_trinkets_grow_by_doing(t: TestContext) -> void:
	var main := await t.game()
	var player: Player = main.get_node("Player")
	t.equal(DB.TRINKETS.size(), 12, "twelve trinkets")
	for slot: String in DB.SLOTS:
		t.check(slot in Equipment.ALL_SLOTS, "%s can be worn" % slot)
	var circlet := _wear(player, "hunters_circlet")
	t.equal(t_problem, "", "a circlet goes on the head")
	t.equal(player.equipment.get_item("trinket_head"), circlet, "and is worn there")
	var damage := player.stats.get_stat("physical_damage")
	t.check(damage > 0.0, "level 1 gives its strength")
	# Kills raise the Hunter's Circlet, nothing else does.
	player.trinkets.add("walked", 10000.0)
	t.equal(circlet.trinket_level, 1, "walking does not grow a hunter's charm")
	for k in DB.goal("hunters_circlet", 1):
		player.trinkets.add("kills", 1.0)
	t.equal(circlet.trinket_level, 2, "slaying monsters raises it to level 2")
	t.check(player.stats.get_stat("critical_chance") > 0.0 and player.stats.get_stat("physical_damage") > damage, "with a greater strength and its gift")
	t.check(not player.trinkets.has_power("night_eyes"), "no power yet")
	# The Orb: straight to the top.
	player.inventory.add(Item.create(DB.ORB))
	t.equal(player.trinkets.awaken(circlet), "", "an Orb of Awakening")
	t.equal(circlet.trinket_level, 3, "raises it to level 3")
	t.check(player.trinkets.has_power("night_eyes"), "and its power wakes")
	t.equal(player.inventory.count_of(DB.ORB), 0, "the orb is spent")
	t.check(player.trinkets.awaken(circlet) != "", "a full one cannot be awakened")
	# The level is kept with the item.
	var copy := Item.from_dict(circlet.to_dict())
	t.equal(copy.trinket_level, 3, "a trinket's level is saved")
	player.equipment.unequip("trinket_head")
	t.check(not player.trinkets.has_power("night_eyes"), "taken off, the power goes")


func test_trinket_powers_change_the_world(t: TestContext) -> void:
	var main := await t.game()
	var player: Player = main.get_node("Player")
	# Waterwalker: no more swimming.
	var charm := _wear(player, "tide_charm")
	charm.trinket_level = 3
	player.trinkets.apply()
	t.check(player.trinkets.has_power("waterwalker"), "the Tide Charm's Waterwalker")
	# Mountain Goat: the cliffs no longer stop the player.
	var anklet := _wear(player, "wayfarers_anklet")
	t.check(player.collision_mask & TerrainTiles.CLIFF_COLLISION != 0, "cliffs stop a walker")
	anklet.trinket_level = 3
	player.trinkets.apply()
	t.check(player.collision_mask & TerrainTiles.CLIFF_COLLISION == 0, "but not a Mountain Goat")
	# Thrift of Wood: a third less wood.
	var apron := _wear(player, "woodwrights_apron")
	var torch_recipe := RecipeDB.find("crafting_table")
	t.equal(int(Crafting.inputs_for(player, torch_recipe)["oak_wood"]), 6, "a crafting table takes six wood")
	apron.trinket_level = 3
	player.trinkets.apply()
	t.equal(int(Crafting.inputs_for(player, torch_recipe)["oak_wood"]), 4, "four with Thrift of Wood")
	# Deep Lore: recipes only a grown Scholar's Band teaches.
	var lore := RecipeDB.find("lore_might_elixir")
	t.check(not lore.is_empty() and Crafting.blocked_reason(player, lore).begins_with("Only a trinket"), "a Deep Lore recipe is closed to others")
	for slot: String in DB.SLOTS:
		player.equipment.unequip(slot)
	player.trinkets.apply()


func test_trinkets_and_the_orb_are_found(t: TestContext) -> void:
	var found := {}
	var orbs := 0
	for k in 3000:
		for entry: Dictionary in Structures.roll_chest(10, 1.0):
			if DB.is_trinket(str(entry["id"])):
				found[entry["id"]] = true
			elif entry["id"] == DB.ORB:
				orbs += 1
	t.check(found.size() >= 6, "chests hold trinkets now and then (%d kinds seen)" % found.size())
	t.check(orbs > 5 and orbs < 70, "and one in a hundred an Orb of Awakening (%d in 3000)" % orbs)
