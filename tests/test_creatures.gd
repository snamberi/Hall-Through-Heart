extends RefCounted
## Characters and creatures, drawn and shown: people seen from every side
## and each class at rest, tools in villagers' hands and gear on others,
## monsters' hit frames, rank outlines and deaths, summoned allies drawn for
## themselves, pets at their ease, and riders' legs on their mounts.


func test_people_are_drawn_from_every_side(t: TestContext) -> void:
	var rows := PlayerAnimator.ROWS.map(func(row: Dictionary) -> String: return row["name"])
	for name: String in ["idle_back", "walk_back", "run_back", "idle_side", "walk_side", "run_side"]:
		t.check(name in rows, "the sheets have %s" % name)
	var deepest := 0
	for row: Dictionary in PlayerAnimator.ROWS:
		deepest = maxi(deepest, int(row.get("row", PlayerAnimator.ROWS.find(row))))
	for path: String in ["res://assets/sprites/player_sheet.png", "res://assets/sprites/looks/hair_0.png", "res://assets/sprites/layers/chest_plate_1.png"]:
		var sheet: Texture2D = load(path)
		t.check(sheet.get_height() >= (deepest + 1) * PlayerAnimator.FRAME_SIZE, "%s holds every row" % path.get_file())
	t.equal(PlayerAnimator.view_of(Vector2(0, -100)), "back", "going up, seen from behind")
	t.equal(PlayerAnimator.view_of(Vector2(100, 10)), "side", "going sideways, in profile")
	t.equal(PlayerAnimator.view_of(Vector2(0, 100)), "front", "coming down, from the front")
	var frames := BodyFit.frames("people/body_h2_b1")
	t.check(frames.has_animation("walk_side") and frames.get_frame_count("walk_side") == 8, "the profile walk has its eight frames")


func test_each_class_has_its_own_stance(t: TestContext) -> void:
	var frames := BodyFit.frames("people/body_h2_b1")
	for id: String in ["warrior", "guardian", "ranger", "assassin", "mage", "spellblade", "necromancer", "spellcaster"]:
		t.check(frames.has_animation("idle_" + id), "%s stands its own way" % id)
	# Two stances share a row: the second starts four frames in.
	var guardian := frames.get_frame_texture("idle_guardian", 0) as AtlasTexture
	t.equal(int(guardian.region.position.x), 4 * PlayerAnimator.FRAME_SIZE, "packed two to a row")


func test_villagers_hold_tools_at_their_own_size(t: TestContext) -> void:
	var figure := PersonFigure.new()
	figure.dress(Appearance.DEFAULT)
	t.check(figure.hold_tool("worn_hatchet"), "a woodcutter's hatchet is drawn to be held")
	var held: Sprite2D = figure._held
	t.equal(held.scale, Vector2.ONE, "at its own size, not a shrunken icon")
	t.check(not figure.hold_tool("no_such_tool"), "anything else falls back to its icon")
	figure.wear([{"l": "helmet", "s": "layers/helmet_plate_1", "t": Color.WHITE}, {"l": "chest", "s": "layers/chest_plate_1", "t": Color.WHITE}])
	t.check(figure._gear.has("helmet") and (figure._gear["helmet"] as CanvasItem).visible, "and wears armour over the body")
	figure.free()
	t.check(not (VillagerLife.JOBS["guard"].get("wears", []) as Array).is_empty(), "guards are armoured")


func test_monsters_show_their_rank_and_die_their_own_way(t: TestContext) -> void:
	t.equal(MonsterLook.death_of("husk"), "crumble", "husks crumble")
	t.equal(MonsterLook.death_of("bog_slime"), "splat", "slimes splat")
	t.equal(MonsterLook.death_of("ember_wisp"), "fade", "wisps fade")
	t.equal(MonsterLook.death_of("grey_wolf"), "fall", "beasts fall")
	var main := await t.game()
	var spawner: EnemySpawner = main.get_node("Enemies")
	var elite := spawner.spawn_at(Vector2(2000, 2000), 3, Enemy.Rank.ELITE, "husk")
	await t.frames(2)
	var look := elite._animator.material as ShaderMaterial
	t.check(look != null and int(look.get_shader_parameter("pattern")) == 0, "an Elite wears its gold outline")
	elite.take_damage(1.0, Vector2(60, 0))
	t.check(elite._animator._flinch_left > 0.0, "a blow shows the drawn hurt frames")
	t.equal(elite._animator.scale, Vector2.ONE, "and nothing is stretched")
	elite.queue_free()


func test_allies_and_pets_are_drawn_for_themselves(t: TestContext) -> void:
	for kind: String in Summons.KINDS:
		var species: String = Summons.KINDS[kind]["species"]
		t.check(ResourceLoader.exists("res://assets/sprites/enemies/%s.png" % species), "%s has its own sheet" % kind)
		t.equal(Summons.KINDS[kind]["tint"], Color.WHITE, "%s is not a tinted monster" % kind)
	var wolf: Texture2D = load("res://assets/sprites/enemies/grey_wolf.png")
	t.check(wolf.get_height() >= 96 * 9, "monster sheets carry a pet's resting rows")
	var critters: Texture2D = Critter.SHEET
	t.equal(critters.get_width(), Critter.KINDS.size() * Critter.FRAMES * 24, "critters have their fidget frames")


func test_riders_legs_are_drawn_on_their_mounts(t: TestContext) -> void:
	for id: String in Mount.MOUNTS:
		var near: Texture2D = load("res://assets/sprites/mounts/%s_front.png" % Mount.MOUNTS[id]["sheet"])
		var image := near.get_image()
		if image.is_compressed():
			image.decompress()
		# The trouser colours the rider's palette turns into their own.
		var found := false
		for y in range(20, 80):
			for x in range(20, 76):
				if image.get_pixel(x, y).to_html(false) in ["4c4a5e", "383648", "272633"]:
					found = true
					break
			if found:
				break
		t.check(found, "%s carries the rider's leg" % id)
