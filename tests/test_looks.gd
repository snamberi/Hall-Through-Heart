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
