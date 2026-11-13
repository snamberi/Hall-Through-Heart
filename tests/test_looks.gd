extends RefCounted
## Races and character looks.


func test_every_race_resolves(t: TestContext) -> void:
	for race: String in Appearance.RACES:
		var look := Appearance.for_race(race)
		var worn := Appearance.resolved(look)
		t.equal(worn["race"], race, "race survives resolving")
		for row: Array in Appearance.OPTIONS:
			var size := Appearance.list(row[2]).size()
			t.check(int(worn[row[0]]) >= 0 and int(worn[row[0]]) < size, "%s: %s out of range" % [race, row[0]])
		t.check(Appearance.make_material(look) != null, "%s: no body material" % race)
		t.check(Appearance.RACES[race].has("mods"), "%s has no gifts" % race)


func test_every_layer_has_its_sheet(t: TestContext) -> void:
	var looks: Array = Appearance.RACES.keys().map(func(race: String) -> Dictionary: return Appearance.for_race(race))
	for i in 20:
		looks.append(Appearance.random())
	for look: Dictionary in looks:
		var layers := Appearance.layers(look)
		for slot: String in layers:
			var path := "res://assets/sprites/looks/%s.png" % layers[slot]["sheet"]
			t.check(ResourceLoader.exists(path), "%s needs missing %s" % [look["race"], path])


func test_recolour_shader_uses_modulate_only(t: TestContext) -> void:
	# The texture colour is already in COLOR in fragment(); multiplying the
	# recoloured pixel by it again squared every body colour.
	t.check(not Appearance.SHADER.contains("* COLOR;"), "body shader multiplies by COLOR (the texture) again")


func test_every_armour_has_its_worn_look(t: TestContext) -> void:
	var parts := {"helmet": "helmet", "chest": "chest", "legs": "legs", "boots": "boots"}
	for id: String in ItemDB.ITEMS:
		var def: Dictionary = ItemDB.ITEMS[id]
		var slot: String = def.get("slot", "")
		if not parts.has(slot):
			continue
		for level: int in [1, 30, 60]:
			var item := LootGenerator.make_equipment(level, 1, id)
			var sheet := PlayerAnimator.armour_sheet(parts[slot], item)
			t.check(ResourceLoader.exists("res://assets/sprites/%s.png" % sheet), "%s at level %d needs missing %s" % [id, level, sheet])
	t.check(PlayerAnimator.armour_sheet("helmet", LootGenerator.make_equipment(1, 0, "helmet")) != PlayerAnimator.armour_sheet("helmet", LootGenerator.make_equipment(60, 0, "helmet")),
		"plate helmets look the same at every level")
	t.check(PlayerAnimator.armour_sheet("chest", LootGenerator.make_equipment(5, 0, "leather_vest")) != PlayerAnimator.armour_sheet("chest", LootGenerator.make_equipment(5, 0, "chestplate")),
		"a leather vest looks like a chestplate")


func test_every_choice_has_its_art_and_name(t: TestContext) -> void:
	for row: Array in Appearance.OPTIONS:
		var entries := Appearance.list(row[2])
		t.check(entries.size() > 1, "%s offers no choice" % row[1])
		for index in entries.size():
			t.check(Appearance.option_name(row[2], index) != "", "%s %d has no name" % [row[1], index])
			if row[3] == "shape" and entries[index] is Dictionary and entries[index].get("sheet", "") != "":
				t.check(ResourceLoader.exists("res://assets/sprites/looks/%s.png" % entries[index]["sheet"]), "%s %d has no art" % [row[1], index])
	t.equal(Appearance.SKIN_NAMES.size(), Appearance.SKIN_TONES.size(), "every skin has a name")
	t.equal(Appearance.HAIR_NAMES.size(), Appearance.HAIR.size(), "every hair colour has a name")
	t.equal(Appearance.EYE_NAMES.size(), Appearance.EYES.size(), "every eye colour has a name")
	t.equal(Appearance.CLOTHES_NAMES.size(), Appearance.CLOTHES.size(), "every clothes colour has a name")
	t.equal(Appearance.TROUSER_NAMES.size(), Appearance.TROUSERS.size(), "every trouser colour has a name")
	t.equal(Appearance.DYE_NAMES.size(), Appearance.DYES.size(), "every dye has a name")
	var dressed := Appearance.for_race("human")
	dressed.merge({"hat": 4, "accessory": 1, "neck": 1, "cape": 2, "dye": 5}, true)
	var layers := Appearance.layers(dressed)
	for slot: String in ["hat", "face", "neck", "cape"]:
		t.check(layers.has(slot), "a worn %s shows" % slot)
	t.equal(layers["hat"]["tint"], Color(Appearance.DYES[5][0]), "a dyed hat takes the dye")
	t.check(Appearance.option_count() >= 200, "plenty of choices (%d)" % Appearance.option_count())
