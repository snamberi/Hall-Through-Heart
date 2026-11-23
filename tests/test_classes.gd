extends RefCounted
## Classes chosen at the start, their kits, class levels and the Class set,
## summons, the off-class weapon penalty, and what each race does.


func test_every_class_has_a_tree_a_kit_and_no_decide_later(t: TestContext) -> void:
	t.check(not "adventurer" in HeroClasses.CHOICES, "no 'decide later' among the choices")
	t.check("necromancer" in HeroClasses.CHOICES and "spellcaster" in HeroClasses.CHOICES, "Necromancer and Spellcaster can be chosen")
	for id: String in HeroClasses.CHOICES:
		var tree: Dictionary = HeroClasses.TREES[id]
		t.equal((tree["abilities"] as Array).size(), 6, "%s has six class abilities" % id)
		t.equal(int(tree["abilities"][0][1]), 1, "%s's first ability opens at class level 1" % id)
		for entry: Array in tree["abilities"]:
			t.check(AbilityDB.ABILITIES.has(entry[0]) and AbilityDB.is_class_ability(entry[0]), "%s is a class ability" % entry[0])
			t.equal(str(AbilityDB.ABILITIES[entry[0]].get("class", "")), id, "%s belongs to %s" % [entry[0], id])
		for entry: Array in HeroClasses.CLASSES[id]["kit"]:
			t.check(ItemDB.ITEMS.has(entry[0]), "%s's kit item %s exists" % [id, entry[0]])
		t.check(not (HeroClasses.CLASSES[id]["weapons"] as Array).is_empty(), "%s trains with some weapon" % id)


func test_a_new_necromancer_starts_with_its_kit_and_raises_the_dead(t: TestContext) -> void:
	var main := await t.game()
	var player: Player = main.get_node("Player")
	player.class_id = "necromancer"
	player.class_level = 1
	player.class_xp = 0
	player._apply_class()
	player.inventory.items.clear()
	player.give_starter_kit()
	var weapon := player.equipment.weapon()
	t.check(weapon != null and weapon.id == "staff", "the kit's staff is in hand (%s)" % (weapon.id if weapon else "nothing"))
	t.check(player.inventory.count_of("mana_potion") >= 3, "mana potions in the bag")
	t.check(player.inventory.count_of("bone") >= 6, "and bones")
	# The first class ability is open, on the Class set.
	t.check(player.abilities.rank("raise_dead") > 0, "Raise Dead is open at class level 1")
	t.equal(player.abilities.rank("bone_spear"), 0, "Bone Spear waits for class level 3")
	player.abilities._fill_empty_slots()
	t.check("raise_dead" in player.abilities.class_loadout, "it goes on the Class set by itself")
	player.abilities.active_set = 1
	player.abilities.switch_set()
	t.equal(player.abilities.active_set, 2, "Tab reaches the Class set")
	t.check("raise_dead" in player.abilities.slots(), "whose keys use the class abilities")
	player.abilities.switch_set()
	t.equal(player.abilities.active_set, 0, "and goes round to the weapon set")
	# Summoning: weak zombies, a limit, three minutes.
	var summons: Summons = player.get_node("Summons")
	summons.dismiss_all()
	await t.frames(1)
	var spec: Dictionary = AbilityDB.ABILITIES["raise_dead"]["summon"]
	summons.summon(spec, Color.WHITE)
	summons.summon(spec, Color.WHITE)
	await t.frames(2)
	t.equal(summons.count("zombie"), 3, "no more zombies than the limit (3)")
	var minion: Summons.Minion = summons.minions.filter(func(m: Variant) -> bool: return is_instance_valid(m))[0]
	t.check(minion.life > Summons.LIFETIME - 1.0 and Summons.LIFETIME == 180.0, "each lasts three minutes")
	minion.life = 0.01
	await t.frames(3)
	t.check(not is_instance_valid(minion), "and then crumbles")
	player.class_ranks["necro_horde"] = 2
	t.equal(summons.limit("zombie", 3), 5, "The Horde lets more stand")
	summons.dismiss_all()
	# Class experience: abilities and kills raise the class level and open more.
	for k in 40:
		player.gain_class_xp(10)
	t.check(player.class_level >= 3, "class level climbs (%d)" % player.class_level)
	t.check(player.abilities.rank("bone_spear") > 0, "Bone Spear opens")
	var level := player.class_level
	player._on_kill_class_xp({"rank": "boss"})
	t.check(player.class_level > level or player.class_xp > 0, "defeating a boss gives class experience")
	t.equal(player.class_points_total(), player.class_level, "a class point per class level")
	var data := player.save_data()
	t.equal(int(data["class_level"]), player.class_level, "class level is saved")
	t.close_game()


func test_a_mage_with_a_sword_is_clumsy_and_it_depends_on_difficulty(t: TestContext) -> void:
	var main := await t.game()
	var player: Player = main.get_node("Player")
	player.class_id = "mage"
	player.class_level = 1
	player._apply_class()
	var was := Difficulty.current
	Difficulty.current = "normal"
	var sword := LootGenerator.make_equipment(1, 0, "sword")
	player.equipment.equip_directly(sword)
	player._on_equipment_changed()
	var mods := player.class_weapon_mods()
	t.check(absf(float(mods["physical_damage"]["percent"]) + 0.3) < 0.001, "a sword in a mage's hand keeps 70% of its damage on Normal")
	t.check(absf(float(mods["attack_speed"]["percent"]) + 0.1) < 0.001, "and strikes 10% slower")
	t.check(player.off_class_weapon(), "it is off-class")
	Difficulty.current = "insane"
	mods = player.class_weapon_mods()
	t.check(float(mods["physical_damage"]["percent"]) < -0.3 and float(mods["attack_speed"]["percent"]) < -0.1, "worse on Insane")
	Difficulty.current = "easy"
	mods = player.class_weapon_mods()
	t.check(float(mods["physical_damage"]["percent"]) > -0.3, "milder on Easy")
	Difficulty.current = "normal"
	var staff := LootGenerator.make_equipment(1, 0, "staff")
	player.equipment.equip_directly(staff)
	player._on_equipment_changed()
	t.check(not player.off_class_weapon(), "a staff is a mage's own")
	t.check(float(player.class_weapon_mods().get("physical_damage", {}).get("percent", 0.0)) > 0.0, "and gets the class bonus")
	Difficulty.current = was
	t.close_game()


func test_races_play_differently(t: TestContext) -> void:
	var main := await t.game()
	var player: Player = main.get_node("Player")
	var traits: RaceTraits = main.get_node("RaceTraits")
	var base := Inventory.BASE + player.inventory.bonus_slots
	player.appearance["race"] = "orc"
	traits.apply()
	t.equal(player.inventory.capacity(), base + 15, "an orc carries 15 more")
	player.appearance["race"] = "fairy"
	traits.apply()
	t.equal(player.inventory.capacity(), base - 10, "a fairy 10 fewer")
	t.check(float(RaceTraits.value("slime", "water", 1.0)) > 1.5, "slimes are quick in water")
	t.check(float(RaceTraits.value("dwarf", "mining", 1.0)) > 1.4 and float(RaceTraits.value("dwarf", "yield", 0.0)) > 0.0, "dwarves mine faster and get more")
	t.check(float(RaceTraits.value("elf", "aim", 1.0)) > 1.2, "elves aim further")
	t.check(float(RaceTraits.value("stoneborn", "water", 1.0)) < 1.0, "stoneborn sink")
	# Big swings in both directions.
	for race: String in Appearance.RACES:
		var mods: Dictionary = Appearance.RACES[race]["mods"]
		var biggest := 0.0
		for stat: String in mods:
			for kind: String in mods[stat]:
				biggest = maxf(biggest, absf(float(mods[stat][kind])))
		t.check(biggest >= 0.15, "%s has a gift worth feeling (%.2f)" % [race, biggest])
		t.check(not RaceTraits.of(race).get("lines", []).is_empty(), "%s has something only it does" % race)
	# An elf's arrows fly faster.
	player.appearance["race"] = "elf"
	var shot := Projectile.fire(player, Vector2.RIGHT, {"sprite": 0, "speed": 600.0, "range": 500.0}, 1.0)
	t.check(float(shot._config["speed"]) > 600.0 and float(shot._config["range"]) > 500.0, "elf shots go faster and further")
	shot.queue_free()
	player.appearance["race"] = "human"
	traits.apply()
	t.close_game()


func test_a_second_class_at_level_75(t: TestContext) -> void:
	var main := await t.game()
	var player: Player = main.get_node("Player")
	var before_class := player.class_id
	var before_second := player.second_class
	player.class_id = "warrior"
	player.class_level = maxi(player.class_level, 1)
	player.second_class = ""
	var level := player.leveling.level
	player.leveling.level = 74
	t.check(player.choose_second_class("mage") != "", "not before level 75")
	player.leveling.level = 75
	t.check(player.choose_second_class("warrior") != "", "not your own class again")
	var power := player.stats.get_stat("magic_power")
	t.equal(player.choose_second_class("mage"), "", "at 75 a Warrior can take up the Mage's path")
	t.check(player.stats.get_stat("magic_power") > power, "and gains part of its strengths")
	var lent := HeroClasses.second_abilities("mage")
	t.check(lent.size() == HeroClasses.SECOND_ABILITIES and player.abilities.rank(lent[0]) > 0, "its first abilities are usable")
	t.check(lent[0] in player.abilities.known_class(), "and sit on the Class set")
	t.check(player.choose_second_class("ranger") != "", "a second class is for life")
	t.equal(str(player.save_data().get("second_class", "")), "mage", "and is saved")
	player.leveling.level = level
	player.second_class = before_second
	player.class_id = before_class
	player._apply_class()
