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
