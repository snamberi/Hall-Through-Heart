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
