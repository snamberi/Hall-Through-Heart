extends RefCounted
## Abilities, spells and their icons.

const SHAPES := ["shot", "buff", "chain", "arc", "spin", "slam", "dash", "leap", "flurry"]


func test_abilities_are_complete(t: TestContext) -> void:
	for id: String in AbilityDB.ABILITIES:
		var ability: Dictionary = AbilityDB.ABILITIES[id]
		t.check(ability.get("name", "") != "", "%s has no name" % id)
		t.check(ability.get("text", "") != "", "%s has no description" % id)
		t.check(ability.has("cooldown"), "%s has no cooldown" % id)
		t.check(ability.get("shape", "") in SHAPES, "%s has unknown shape %s" % [id, ability.get("shape", "")])
		t.check(ability.has("weapon") or ability.has("class") or ability.has("school"), "%s belongs to no weapon, class or school" % id)


func test_every_ability_has_its_own_icon(t: TestContext) -> void:
	var sheet := AbilityDB.ICON_SHEET
	var seen := {}
	for id: String in AbilityDB.ABILITIES:
		var icon := AbilityDB.icon(id) as AtlasTexture
		t.check(icon != null, "%s has no icon" % id)
		if icon == null:
			continue
		var region := icon.region
		t.check(region.end.x <= sheet.get_width() and region.end.y <= sheet.get_height(), "%s icon lies outside the sheet" % id)
		t.check(not seen.has(region), "%s shares an icon with %s" % [id, seen.get(region, "")])
		seen[region] = id
		var image := sheet.get_image().get_region(Rect2i(region))
		t.check(not image.is_invisible(), "%s icon is blank" % id)


func test_magic_schools_have_four_spells(t: TestContext) -> void:
	for school: String in MagicDB.SCHOOLS:
		var spells: Array = MagicDB.spells(school)
		t.equal(spells.size(), 4, "spells in %s" % school)
		for spell: String in spells:
			t.check(AbilityDB.ABILITIES.has(spell), "%s lists unknown spell %s" % [school, spell])
			t.equal(MagicDB.school_of(spell), school, "school of %s" % spell)


func test_every_effect_has_an_icon(t: TestContext) -> void:
	t.equal(Buffs.EFFECT_SHEET.get_width(), Buffs.EFFECT_ICONS.size() * 24, "effect sheet width")
	for id: String in ["torchlight", "heart", "bloodthirst", "blessing", "henge", "perfect_dodge", "chill", "burn", "poison", "bleed"]:
		t.check(Buffs.icon_for(id) != null, "%s has no icon" % id)
	for id: String in AbilityDB.ABILITIES:
		t.equal(Buffs.icon_for(id), AbilityDB.icon(id), "%s buff icon" % id)
	t.check(Buffs.icon_for("something_new", "", {"armor": {"flat": -5.0}}) == Buffs.icon_for("debuff"), "a buff that only hurts shows the down arrow")
