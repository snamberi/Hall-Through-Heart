class_name SaintLull
extends Node2D
## Saint Lull's House for Foundlings: a white house in a field of wheat
## behind a white wall, far out in the world, where children in white are
## happy, well fed and clever, and are "sent to new families" when they come
## of age. They are not. They are raised for the Lull Court: tall nobles in
## porcelain masks who collect them at the back gate at night, as the old
## Promise between the courts and the kingdoms allows.
##
## The arc, as it is played:
##   1 Arrival: the Matron welcomes you and sets a warm seal on your wrist
##     (a brand: while you carry it she always knows where you are). The
##     children (Wren the planner, Pip the runner, Ash the lookout) talk.
##   2 The doll: Wren asks you to take Number 31's forgotten doll to the
##     back gate after dark. A black carriage waits; a masked noble lifts a
##     crate marked 31. You have seen the truth.
##   3 The plan, against a shipping-day countdown (Pip is to be sent away in
##     four days): find three lengths of rope (laundry, attic, woodshed),
##     find the wall's loose stones by night with Ash while the Matron walks
##     the yard with her lantern, and burn the brand out at the cellar forge.
##   4 Escape night: across the wheat with the children behind you, the
##     Matron's lantern sweeping the field (a child caught in its light is
##     taken), a masked noble at the wall, a rope over it, a rope bridge over
##     the chasm, and the woods.
##   5 The children are free (they live at the Sanctuary after, and are
##     grateful). The Matron waits at the house, and can be fought.
## Missing a shipping day costs a child. The arc goes on with who is left.
##
## Around it: the Reserve (a noble's hunting ground where you are the prey:
## hide in the tall grass, last three minutes), the Benefactor's Bunker (a
## hatch, and a journal in cipher to read), seven Promise Stones out in the
## world telling the history of the old Promise, informers among villagers
## (they wear a porcelain charm and ask where you are going), and games with
## the children by day: tag (quicker feet) and the Matron's tests (sharper
## wits). Music-box lullabies play round the house after dark.

const BUNKER_OFFSET := Vector2(70, 46)
const STONE_DISTANCES: Array[float] = [140.0, 220.0, 300.0, 380.0, 460.0, 540.0, 620.0]
const SHIP_DAYS := 4
const YARD := 7

const CHILDREN := {
	"wren": {"name": "Wren", "role": "the planner", "hair_style": 6, "hair": 5, "outfit": 5, "skin": 1,
		"lines": ["Matron says we're the cleverest children in the kingdom. Clever children get sent to the best families.",
			"Number 31 left last night. She didn't take her doll. She never went anywhere without it.",
			"Have you ever seen anyone come BACK to visit? I haven't. Not once."]},
	"pip": {"name": "Pip", "role": "the runner", "hair_style": 2, "hair": 2, "outfit": 0, "skin": 2,
		"lines": ["Bet you can't catch me! Nobody can catch me. Not even Matron.", "I'm going to a new family soon! Matron says I'm nearly ready.",
			"The field goes all the way to the wall. Past the wall there's the woods. We're not allowed past the wall."]},
	"ash": {"name": "Ash", "role": "the lookout", "hair_style": 9, "hair": 7, "outfit": 5, "skin": 4,
		"lines": ["I watch the lantern at night. Matron walks the yard when she thinks we're asleep.", "She hums when she's happy. She's always happy.",
			"I can hear the carriage wheels. Can you? Nobody else hears them."]},
}
## The Promise, in seven stones.
const STONES := [
	"THE FIRST STONE: Here the kings of men and the Lull Court made an end of the long war. The courts would hunt no more in the kingdoms.",
	"THE SECOND STONE: In return the kingdoms gave the courts the unclaimed: children with no name and no one to miss them.",
	"THE THIRD STONE: Houses were built for the unclaimed, white and warm, so that they would grow strong and clever. Clever children taste of more.",
	"THE FOURTH STONE: A keeper was set over each house, bound by a seal. She may never leave, and she may never let one go.",
	"THE FIFTH STONE: The courts wear porcelain, so that the faces of the unclaimed are never seen to be reflected in theirs.",
	"THE SIXTH STONE: Should a child of the houses go free, the Promise is broken in that place, and the courts may hunt there again.",
	"THE SEVENTH STONE (scratched in, later): We were the unclaimed. We got out. The Promise can break. -- the Benefactor",
]
## The Matron's tests: [question, [choices], index of the right one].
const TESTS := [
	["A lantern costs a silver more than its wick. Together they cost eleven. What does the wick cost?", ["One silver", "Half a silver", "Five silver"], 0],
	["Which comes next: 2, 3, 5, 8, 12, ...?", ["15", "17", "16"], 1],
	["Three children share nine apples, each one more than the one before. How many has the youngest?", ["Two", "Three", "Four"], 0],
	["If every Saint Lull child is clever, and Pip is a Saint Lull child, then...", ["Pip is clever", "Pip is not clever", "Nothing can be said"], 0],
	["A clock strikes six in five seconds. How long to strike twelve?", ["Ten seconds", "Eleven seconds", "Twelve seconds"], 1],
	["What has keys but opens no lock, and is played every night in this house?", ["A music box", "A piano", "A door"], 1],
	["Which word does not belong: gate, wall, field, fence?", ["Gate", "Field", "Fence"], 1],
	["A carriage leaves at dusk. The road is ten miles; it goes at four an hour. When does it reach the end?", ["After two and a half hours", "After three", "After two"], 0],
	["I am taken from a house, and given to a court. The more of me you know, the less you sleep. What am I?", ["A secret", "A child", "A name"], 0],
	["Half of the children are asleep. Half of the rest pretend. Four are awake. How many children?", ["Sixteen", "Eight", "Twelve"], 0],
]
## The Benefactor's journal, before it is read: a shift of the alphabet.
const JOURNAL := "The houses are farms. The keepers are bound. The stones in the wild tell how it began. Burn the seal at the forge and go by the wall where the stones are loose. There is a way over the chasm. Do not trust the ones with the white charm."
const RESERVE_SECONDS := 150.0
## What an informer asks, idly, while the plan is under way.
const INFORMER_LINES: Array[String] = ["Out walking late again, are we? Toward the wheat?", "Lovely children at the White House. You've been to see them, haven't you?",
	"Where are you headed, friend? I like to know where folk are going.", "They say someone's been asking questions about Saint Lull's. Not you, surely?"]

# --- the story, kept in the save
var stage := 0
var rope := 0
var wall_found := false
var branded := false
var brand_burned := false
var suspicion := 0.0
var ship_day := 0
var children := {"wren": "home", "pip": "home", "ash": "home"}
var wits := 0
var tag_wins := 0
var last_test_day := -1
var stones_read: Array = []
var journal_solved := false
var journal_shift := 0
var informers_caught: Array = []
var informers_heard: Dictionary = {}
var reserve_clears := 0
var matron_fallen := false
var found_rope: Array = []
var stash_taken := false

var _player: Player
var _world: World
var _instances: Instances
var _spawner: EnemySpawner
var _day_night: DayNight
var _music: MusicBox
## What is running inside a room of ours, if anything: "house", "escape", "reserve", "bunker".
var _scene := ""
var _hunter: Variant = null
var _followers: Array = []
var _scene_left := 0.0
var _hidden_spots: Array[Rect2] = []


func _ready() -> void:
	add_to_group("saint_lull")
	SaveGame.register("saint_lull", self)


func setup(player: Player, world: World, instances: Instances, spawner: EnemySpawner, day_night: DayNight) -> void:
	_player = player
	_world = world
	_instances = instances
	_spawner = spawner
	_day_night = day_night
	_music = MusicBox.new()
	add_child(_music)
	instances.left.connect(_on_left)
	_apply_gifts()


# ------------------------------------------------------------------ places

## How far the House's grounds reach from its middle, in tiles: wall,
## wheat and all. Nothing else is built or grows inside.
const GROUNDS := 15
const MANOR_ART: Texture2D = preload("res://assets/sprites/manor.png")


## Where the House stands: a cell out in the open, the same for a world.
static func house_cell(generator: WorldGenerator) -> Vector2i:
	return generator.lull_house_cell()


static func hatch_cell(generator: WorldGenerator) -> Vector2i:
	return generator.landmark_near(house_cell(generator) + Vector2i(BUNKER_OFFSET), 8121)


static func promise_cell(generator: WorldGenerator, index: int) -> Vector2i:
	return generator.landmark_cell(6100 + index * 37, STONE_DISTANCES[index], 3)


## The places this story puts in the world, for Structures: each
## {"kind", "cell", "key", "grounds"}.
static func sites(generator: WorldGenerator) -> Array:
	var out: Array = []
	out.append({"kind": "orphanage", "cell": house_cell(generator), "key": "orphanage", "grounds": GROUNDS})
	out.append({"kind": "bunker", "cell": hatch_cell(generator), "key": "bunker", "grounds": 3})
	for index in STONE_DISTANCES.size():
		out.append({"kind": "promise_stone", "cell": promise_cell(generator, index), "key": "promise:%d" % index, "grounds": 3})
	return out


func orphanage_cell() -> Vector2i:
	return house_cell(_world.generator)


func bunker_cell() -> Vector2i:
	return hatch_cell(_world.generator)


func stone_cell(index: int) -> Vector2i:
	return promise_cell(_world.generator, index)


## The House, its wall and gates, the wheat, the woodshed, the children and
## the Matron outside by day.
func build_orphanage(structures: Structures, cell: Vector2i, placed: Array) -> void:
	var at := func(offset: Vector2i) -> Vector2: return _world.cell_to_world(cell + offset)
	# The wall: white stones all round, a gap at the front gate.
	var wall_cells: Array = []
	for d in range(-YARD, YARD + 1):
		for side: Vector2i in [Vector2i(d, -YARD), Vector2i(d, YARD), Vector2i(-YARD, d), Vector2i(YARD, d)]:
			if side.y == YARD and absi(side.x) <= 1:
				continue
			if side.y == -YARD and absi(side.x) <= 1:
				continue
			wall_cells.append(cell + side)
	for piece in StoneWall.build(wall_cells, func(c: Vector2i) -> Vector2: return _world.cell_to_world(c)):
		(piece as CanvasItem).modulate = Color(1.12, 1.1, 1.05)
		placed.append(piece)
	# The House itself, at its full size, with walls you cannot walk through.
	var manor := Prop.create_decor(Prop.Decor.MANOR, at.call(Vector2i(0, -2)), 0.0, "Enter Saint Lull's House", func(_p: Player) -> void: enter_house())
	manor.sprite().texture = MANOR_ART
	manor.sprite().hframes = 1
	manor.sprite().frame = 0
	manor.sprite().position.y = -48.0
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(112, 22)
	shape.shape = box
	shape.position = Vector2(0, -6)
	body.add_child(shape)
	manor.add_child(body)
	manor.add_light(0.6, 2.2, Color(1.0, 0.85, 0.6))
	placed.append(manor)
	# The back gate, where carriages come by night.
	var gate := Prop.create_decor(Prop.Decor.IRON_GATE, at.call(Vector2i(0, -YARD)), 0.0, "The back gate", func(_p: Player) -> void: _back_gate())
	placed.append(gate)
	# The woodshed, where a length of rope hangs.
	var shed := Prop.create_decor(Prop.Decor.STALL, at.call(Vector2i(5, 3)), 14.0, "Look in the woodshed", func(_p: Player) -> void: _take_rope("woodshed"))
	shed.sprite().modulate = Color(0.85, 0.8, 0.75)
	placed.append(shed)
	# Loose stones in the north wall, found only by night with Ash.
	var loose := Prop.create_decor(Prop.Decor.RUBBLE, at.call(Vector2i(-4, -YARD + 1)), 0.0, "Feel along the wall", func(_p: Player) -> void: _find_loose_stones())
	placed.append(loose)
	# Wheat on every side, and a scarecrow.
	for offset: Vector2i in [Vector2i(-11, 0), Vector2i(11, 0), Vector2i(0, 11), Vector2i(-10, 10), Vector2i(10, 10), Vector2i(0, -11)]:
		var field := WheatField.new()
		field.position = at.call(offset)
		field.size = Vector2(150, 110)
		placed.append(field)
	placed.append(Prop.create_decor(Prop.Decor.SCARECROW, at.call(Vector2i(-11, 1)), 6.0))
	# The yard: a washing line, a well, a bench, flower beds by the door and
	# lanterns on the gateposts.
	placed.append(Prop.create_decor(Prop.Decor.WELL, at.call(Vector2i(-4, 3)), 14.0))
	placed.append(Prop.create_decor(Prop.Decor.BENCH, at.call(Vector2i(4, 1)), 8.0))
	for x in [-3, 3]:
		placed.append(Prop.create_decor(Prop.Decor.FLOWER_BED, at.call(Vector2i(x, 1)), 0.0))
	for x in [-2, 2]:
		var lamp := Prop.create_decor(Prop.Decor.LANTERN, at.call(Vector2i(x, YARD)), 0.0)
		lamp.add_light(0.6, 1.2, Color(1.0, 0.85, 0.6))
		placed.append(lamp)
	placed.append(Prop.create_decor(Prop.Decor.FENCE, at.call(Vector2i(-5, 5)), 0.0))
	placed.append(Prop.create_decor(Prop.Decor.FENCE, at.call(Vector2i(-3, 5)), 0.0))
	# Out past the north-east corner, the Reserve's horn on its post.
	placed.append(Prop.create_decor(Prop.Decor.HORN_POST, at.call(Vector2i(12, -9)), 8.0, "Sound the hunting horn", func(_p: Player) -> void: _sound_horn()))


## The people in the yard. Who is there depends on the hour and on how far
## the story has gone, so they are placed afresh whenever either changes.
var _people: Array = []
var _people_key := ""


func _refresh_people() -> void:
	var home := _world.cell_to_world(orphanage_cell())
	var near := not _player.indoors and _player.global_position.distance_to(home) < 1100.0
	var night := _day_night.is_night_outside()
	var key := "" if not near else "%s:%d:%s:%s:%s" % [night, stage, str(children), matron_fallen, brand_burned]
	if key == _people_key:
		return
	_people_key = key
	for node: Variant in _people:
		if is_instance_valid(node):
			if node == _hunter:
				_hunter = null
			(node as Node).queue_free()
	_people.clear()
	if key == "":
		return
	var structures: Node = _world.get_parent().get_node("Structures")
	var at := func(offset: Vector2i) -> Vector2: return _world.cell_to_world(orphanage_cell() + offset)
	var add := func(node: Node2D) -> void:
		structures.add_child(node)
		_people.append(node)
	if stage < 5 and not night:
		# By day the children play in the yard, and the Matron watches from the door.
		var spots := [Vector2i(-3, 2), Vector2i(3, 3), Vector2i(-1, 4)]
		var index := 0
		for id: String in CHILDREN:
			if children[id] == "home":
				add.call(_child_npc(id, at.call(spots[index])))
			index += 1
		add.call(_matron_npc(at.call(Vector2i(2, 0))))
	elif stage >= 5 and not matron_fallen:
		# The Matron waits in the yard for the one who took her children.
		add.call(_matron_npc(at.call(Vector2i(0, 1))))
	if stage == 3 and night:
		# By night, while the plan is under way, she walks the yard with her lantern.
		var hunter := MatronHunter.new()
		hunter.setup(self, [at.call(Vector2i(-5, -5)), at.call(Vector2i(5, -5)), at.call(Vector2i(5, 5)), at.call(Vector2i(-5, 5))])
		add.call(hunter)
		_hunter = hunter


func _child_npc(id: String, at: Vector2) -> Npc:
	var npc := Npc.create("story", at)
	npc.look = child_look(id)
	npc.job = "child"
	npc.villager_name = CHILDREN[id]["name"]
	npc.title_text = "%s, %s" % [CHILDREN[id]["name"], CHILDREN[id]["role"]]
	npc.prompt_text = "Talk to %s" % CHILDREN[id]["name"]
	npc.offer = {"talk": func(_n: Npc) -> void: talk_child(id)}
	npc.lines.assign(CHILDREN[id]["lines"])
	return npc


func _matron_npc(at: Vector2) -> Npc:
	var npc := Npc.create("story", at)
	npc.look = matron_look()
	npc.villager_name = "The Matron"
	npc.title_text = "The Matron of Saint Lull's"
	npc.prompt_text = "Speak to the Matron"
	npc.offer = {"talk": func(_n: Npc) -> void: talk_matron(_n)}
	return npc


static func child_look(id: String) -> Dictionary:
	var look := Appearance.for_race("human")
	var data: Dictionary = CHILDREN[id]
	look["skin"] = data["skin"]
	look["hair_style"] = data["hair_style"]
	look["hair"] = data["hair"]
	look["outfit"] = data["outfit"]
	look["clothes"] = 6
	look["trousers"] = 7
	look["dye"] = 4
	return look


static func matron_look() -> Dictionary:
	var look := Appearance.for_race("human")
	look["skin"] = 1
	look["hair_style"] = 11
	look["hair"] = 8
	look["outfit"] = 5
	look["clothes"] = 4
	look["trousers"] = 2
	look["dye"] = 4
	return look


## The Benefactor's Bunker: a hatch in a grassy mound.
func build_bunker(cell: Vector2i, placed: Array) -> void:
	placed.append(Prop.create_decor(Prop.Decor.HATCH, _world.cell_to_world(cell), 0.0, "Open the hatch", func(_p: Player) -> void: enter_bunker()))


## A Promise Stone: one of seven, out in the wild.
func build_stone(cell: Vector2i, index: int, placed: Array) -> void:
	var read := index in stones_read
	var stone := Prop.create_decor(Prop.Decor.RUNE_STELE, _world.cell_to_world(cell), 10.0, "Read the Promise Stone" if not read else "The Promise Stone (read)",
		func(_p: Player) -> void: read_stone(index))
	stone.sprite().modulate = Color(1.0, 0.96, 0.92) if not read else Color(0.8, 0.8, 0.84)
	if not read:
		stone.add_light(0.5, 1.0, Color(1.0, 0.9, 0.8))
	placed.append(stone)
	placed.append(Prop.create_decor(Prop.Decor.CANDLES, _world.cell_to_world(cell + Vector2i(1, 1)), 0.0))


# ------------------------------------------------------------------ talking

func _talk(who: String, lines: Array, choices: Array = [], look: Dictionary = {}) -> void:
	DialogueMenu.talk(_player, who, lines, choices, look)


func talk_child(id: String) -> void:
	var data: Dictionary = CHILDREN[id]
	var who := str(data["name"])
	var look := child_look(id)
	var choices: Array = []
	match stage:
		0, 1:
			if stage == 0:
				_arrive()
			if id == "wren":
				_talk(who, ["Oh! A visitor. We don't get visitors.", data["lines"][1], "Will you do something for me? Take her doll to the back gate tonight. That's where the carriages wait. Maybe someone can give it to her.",
					"[Wren presses a rag doll with a stitched 31 on its apron into your hands.]"], [["I'll take it to the gate tonight.", func() -> void: _start_doll()]], look)
				return
			_talk(who, data["lines"], [], look)
		2:
			_talk(who, ["Did you take the doll? The gate is at the back of the yard. Carriages only come after dark."], [], look)
		3, 4:
			choices.append(["How goes the plan?", func() -> void: _talk(who, _plan_report(id), [], look)])
			if id == "pip" and not _day_night.is_night_outside():
				choices.append(["Play tag with the children", func() -> void: start_tag()])
			if id == "ash" and not wall_found:
				choices.append(["Show me where the wall is weak", func() -> void: _talk(who, ["North wall, left of the gate. Some of the stones are loose. Only go at night when she's at the far side of the yard, and stay out of her light."], [], look)])
			if id == "wren" and _plan_done():
				choices.append(["Everything's ready. We go tonight.", func() -> void: _escape_or_wait()])
			_talk(who, [_role_line(id)], choices, look)
		_:
			_talk(who, data["lines"], [], look)


func _role_line(id: String) -> String:
	match id:
		"wren":
			return "We need three ropes, the loose stones in the wall, and that seal off your wrist. Then we go, all of us, at night."
		"pip":
			return "I'll carry the rope. I'm the fastest. If anyone's going to make it over the wall first, it's me."
	return "I'll watch the lantern. When she's close I'll tell you. Don't let her light touch us."


func _plan_report(_id: String) -> Array:
	var lines: Array = []
	lines.append("Rope: %d of 3. %s" % [rope, "That's all of it!" if rope >= 3 else "Try the laundry, the attic and the woodshed."])
	lines.append("The wall: %s" % ("we know where the stones are loose." if wall_found else "we still need to find the loose stones. Night only."))
	lines.append("Your seal: %s" % ("burned out. She can't follow you any more." if brand_burned else "still on your wrist. She always knows where you are. The forge in the cellar can burn it out."))
	if ship_day > 0:
		lines.append("And Pip goes in %d day%s." % [maxi(ship_day - _day_night.day, 0), "" if ship_day - _day_night.day == 1 else "s"] if children["pip"] == "home" else "...They took Pip. We have to go before they take another.")
	return lines


func talk_matron(npc: Npc) -> void:
	var look := matron_look()
	if stage >= 5 and not matron_fallen:
		_talk("The Matron", ["You took my children.", "[She is still smiling. The lantern in her hand burns white.]", "Do you know what they will do to me, now that the Promise is broken here? No. You never think of the keepers."],
			[["Then face me.", func() -> void: _matron_fight(npc)], ["Leave", Callable()]], look)
		return
	if stage == 0:
		_arrive()
	match stage:
		1, 2:
			_talk("The Matron", ["Welcome to Saint Lull's, traveller. Our children are the happiest in the kingdom.", "Clever, healthy, loved. And when they are ready, they go to new families.",
				"Do stay as long as you like. We have nothing to hide here."], [], look)
		_:
			_talk("The Matron", ["Such a lovely evening. The children are very fond of you.", "Do be careful by the wall at night, dear. The field is so very dark."], [], look)


## First sight of the House: the Matron's welcome and her seal.
func _arrive() -> void:
	if stage > 0:
		return
	stage = 1
	branded = true
	Events.announcement.emit("SAINT LULL'S HOUSE FOR FOUNDLINGS", "The Matron takes your wrist and presses a warm seal to it. \"So we never lose you, dear.\"")
	Events.codex_event.emit("lull_found", 1)
	SaveGame.request_save()


func _start_doll() -> void:
	stage = 2
	_player.inventory.add(Item.create("lull_doll"))
	Events.announcement.emit("NUMBER 31'S DOLL", "Take it to the back gate after dark.")
	SaveGame.request_save()


func _back_gate() -> void:
	if stage != 2:
		Events.announcement.emit("", "\"Never go past the gate.\"" if stage < 2 else "The gate is locked. Beyond it, the wheat goes on to the dark.")
		return
	if not _day_night.is_night_outside():
		Events.announcement.emit("", "Nothing comes by day. Wren said the carriages wait after dark.")
		return
	_gate_scene()


## The night the truth is seen: a carriage at the gate, and a noble in a
## porcelain mask lifting a crate marked 31.
func _gate_scene() -> void:
	var gate_at := _world.cell_to_world(orphanage_cell() + Vector2i(0, -YARD - 3))
	var carriage := Prop.create_decor(Prop.Decor.CARRIAGE, gate_at + Vector2(-60, 0), 30.0)
	_world.get_parent().get_node("Structures").add_child(carriage)
	var noble := NobleFigure.new()
	noble.position = gate_at + Vector2(30, 6)
	_world.get_parent().get_node("Structures").add_child(noble)
	_music.play_once()
	stage = 3
	ship_day = _day_night.day + SHIP_DAYS
	_player.inventory.take("lull_doll", 1)
	SaveGame.request_save()
	_talk("Beyond the gate", ["[A black carriage waits in the wheat, its lamps hooded. Something very tall stands beside it.]",
		"[It wears a mask of white porcelain with one upright slit, and red tears painted beneath. Antlers rise through its hood.]",
		"[It bends to a crate stencilled 31, lifts the lid a little way, and breathes in, slowly.]",
		"[Then the slit turns toward you.]", "[You run.]"],
		[["Find Wren.", _after_gate.bind(carriage, noble)]])


## After the gate: the truth told, and the carriage gone into the dark.
func _after_gate(carriage: Node, noble: Node) -> void:
	Events.announcement.emit("THE TRUTH OF SAINT LULL'S", "The children are not adopted. They are harvested. Pip is to be sent away in %d days." % SHIP_DAYS)
	get_tree().create_timer(6.0).timeout.connect(_clear_gate.bind(carriage, noble))


func _clear_gate(carriage: Node, noble: Node) -> void:
	if is_instance_valid(carriage):
		carriage.queue_free()
	if is_instance_valid(noble):
		noble.queue_free()


# ------------------------------------------------------------------ the plan

func _plan_done() -> bool:
	return rope >= 3 and wall_found and brand_burned


func _take_rope(where: String) -> void:
	if stage != 3:
		Events.announcement.emit("", "Coils of old rope." if where == "woodshed" else "Nothing you need.")
		return
	if where in found_rope:
		Events.announcement.emit("", "You already took the rope from here.")
		return
	found_rope.append(where)
	rope = found_rope.size()
	Audio.play("pickup", -4.0)
	Events.announcement.emit("ROPE %d OF 3" % rope, "Pip will carry it for the night." if rope >= 3 else "Hidden away for the night.")
	SaveGame.request_save()


func _find_loose_stones() -> void:
	if stage != 3:
		return
	if not _day_night.is_night_outside():
		Events.announcement.emit("", "Not by day. She can see the whole yard from the windows.")
		return
	if wall_found:
		Events.announcement.emit("", "The stones here give a little. This is the place.")
		return
	wall_found = true
	Events.announcement.emit("THE LOOSE STONES", "Behind the stones, a gap. A rope could go over here.")
	SaveGame.request_save()


func _burn_brand() -> void:
	if not branded or brand_burned:
		Events.announcement.emit("", "The forge in the cellar burns low.")
		return
	_player.health.current = maxf(_player.health.current - _player.health.max_health * 0.3, 1.0)
	brand_burned = true
	branded = false
	Audio.play_note("hit", 0.6, -2.0)
	_player.shake_camera(6.0)
	Events.announcement.emit("THE SEAL IS BURNED OUT", "It hurts more than anything. But now she cannot find you.")
	SaveGame.request_save()


func _escape_or_wait() -> void:
	if not _day_night.is_night_outside():
		_talk("Wren", ["Not by day! Tonight, when the lantern's on the far side. Come back after dark and tell me."], [], child_look("wren"))
		return
	start_escape()


## Each day: a shipping day missed loses a child; the countdown moves on.
func _check_ships() -> void:
	if stage < 3 or stage >= 5 or ship_day <= 0 or _day_night.day <= ship_day:
		return
	for id: String in ["pip", "ash", "wren"]:
		if children[id] == "home":
			children[id] = "taken"
			Events.announcement.emit("A CARRIAGE CAME IN THE NIGHT", "%s was sent to a \"new family\"." % CHILDREN[id]["name"])
			break
	ship_day = _day_night.day + SHIP_DAYS
	if not "home" in children.values():
		stage = 5
		Events.announcement.emit("SAINT LULL'S IS QUIET", "There are no children left to save.")
	SaveGame.request_save()


# ------------------------------------------------------------------ inside the House

func enter_house() -> void:
	if stage == 0:
		_arrive()
	_instances.prepare_room()
	var room := Room.new()
	room.title = "Saint Lull's House"
	room.wall_style = "wood"
	room.gloom = 0.25 if _day_night.is_night_outside() else 0.05
	for y in range(-9, 10):
		for x in range(-13, 14):
			var edge := absi(x) == 13 or absi(y) == 9
			var inner := (absi(x) == 4 and absi(y) != 1 and absi(y) != 0) or (y == 0 and absi(x) > 4 and absi(x) != 8)
			room.cells[Vector2i(x, y)] = TerrainTiles.Type.WALL if edge or inner else TerrainTiles.Type.PLANK
	room.entry = Vector2i(0, 8)
	room.build(_world.tile_set())
	_instances.enter(room)
	_scene = "house"
	var at := func(cell: Vector2i) -> Vector2: return room.cell_position(cell)
	var add := func(node: Node2D) -> Node2D:
		room.add_prop(node)
		return node
	# The dormitory (top left): rows of white beds.
	for x in [-11, -9, -7]:
		for y in [-7, -4]:
			add.call(Prop.create(Prop.Art.BED, at.call(Vector2i(x, y)), 10.0))
	add.call(Prop.create_decor(Prop.Decor.CANDLES, at.call(Vector2i(-6, -2)), 0.0))
	# The laundry (bottom left): a rope among the sheets.
	add.call(Prop.create_decor(Prop.Decor.BARREL, at.call(Vector2i(-11, 3)), 10.0))
	add.call(Prop.create_decor(Prop.Decor.SHELF, at.call(Vector2i(-9, 2)), 10.0, "Search the laundry", func(_p: Player) -> void: _take_rope("laundry")))
	# The dining hall (middle): a long table, the entry below.
	for x in range(-2, 3):
		add.call(Prop.create(Prop.Art.TABLE, at.call(Vector2i(x, -2)), 0.0))
	add.call(Prop.create_decor(Prop.Decor.RUG, at.call(Vector2i(0, 4)), 0.0))
	add.call(Prop.create_decor(Prop.Decor.FIREPLACE, at.call(Vector2i(0, -8)), 12.0))
	# The schoolroom (top right): the day's test on the desk.
	add.call(Prop.create(Prop.Art.TABLE, at.call(Vector2i(8, -5)), 10.0, "Sit the Matron's test", func(_p: Player) -> void: sit_test()))
	for x in [6, 10]:
		add.call(Prop.create_decor(Prop.Decor.CHAIR, at.call(Vector2i(x, -5)), 0.0))
	add.call(Prop.create_decor(Prop.Decor.SHELF, at.call(Vector2i(11, -8)), 10.0))
	# The Matron's office (bottom right), the attic ladder and the cellar forge.
	add.call(Prop.create_decor(Prop.Decor.CUPBOARD, at.call(Vector2i(11, 3)), 10.0))
	add.call(Prop.create(Prop.Art.LADDER, at.call(Vector2i(6, 2)) + Vector2(0, -20), 0.0, "Climb to the attic", func(_p: Player) -> void: _take_rope("attic")))
	var forge := Prop.create_decor(Prop.Decor.FURNACE, at.call(Vector2i(10, 6)), 12.0, "Burn out the brand at the cellar forge", func(_p: Player) -> void: _burn_brand())
	forge.add_light(0.8, 1.2, Color(1.0, 0.55, 0.25))
	add.call(forge)
	add.call(Prop.create(Prop.Art.LADDER, at.call(room.entry) + Vector2(0, 26), 0.0, "Go outside", func(_p: Player) -> void: _instances.leave()))
	# The hall by the front door: a runner, potted plants, a bench of small
	# shoes in a row, and the children's drawings pinned along a shelf.
	add.call(Prop.create_decor(Prop.Decor.RUG, at.call(Vector2i(0, 6)), 0.0))
	for x in [-3, 3]:
		add.call(Prop.create_decor(Prop.Decor.PLANT_POT, at.call(Vector2i(x, 7)), 6.0))
	add.call(Prop.create_decor(Prop.Decor.BENCH, at.call(Vector2i(-6, 7)), 8.0, "Small shoes in a row", func(_p: Player) -> void:
		_talk("The hall", ["[Rows of small shoes, polished, each pair with a number painted inside. 32. 33. 34. There is a gap where 31 should be.]"])))
	add.call(Prop.create_decor(Prop.Decor.SHELF, at.call(Vector2i(6, 7)), 8.0, "Look at the drawings", func(_p: Player) -> void:
		_talk("The hall", ["[Children's drawings: the house, the wheat, the Matron smiling. In one, a tall white figure stands at the gate. Someone has scribbled it out.]"])))
	for cell: Vector2i in [Vector2i(-8, -1), Vector2i(8, -1), Vector2i(-2, 4), Vector2i(2, 4), Vector2i(-11, 7), Vector2i(11, -2)]:
		var lamp := Prop.create_decor(Prop.Decor.LANTERN, at.call(cell), 0.0)
		lamp.add_light(0.6, 1.0, Color(1.0, 0.85, 0.6))
		add.call(lamp)
	# By night the children are in bed, and once the plan is under way the
	# Matron walks the halls with her lantern.
	if _day_night.is_night_outside():
		_music.start()
		var beds := [Vector2i(-11, -6), Vector2i(-9, -6), Vector2i(-7, -6)]
		var index := 0
		for id: String in CHILDREN:
			if children[id] == "home":
				add.call(_child_npc(id, at.call(beds[index])))
			index += 1
		if stage == 3:
			var hunter := MatronHunter.new()
			hunter.setup(self, [at.call(Vector2i(0, -5)), at.call(Vector2i(-8, -5)), at.call(Vector2i(-8, 4)), at.call(Vector2i(0, 4)), at.call(Vector2i(8, 4)), at.call(Vector2i(8, -5))])
			add.call(hunter)
			_hunter = hunter
	else:
		var spots := [Vector2i(-2, 1), Vector2i(1, 2), Vector2i(3, -4)]
		var index := 0
		for id: String in CHILDREN:
			if children[id] == "home":
				add.call(_child_npc(id, at.call(spots[index])))
			index += 1
		add.call(_matron_npc(at.call(Vector2i(2, 6))))
	Events.announcement.emit("SAINT LULL'S HOUSE", "Warm, clean, and very quiet." if not _day_night.is_night_outside() else "Somewhere upstairs, a music box is playing.")


## The day's test in the schoolroom: one question; a right answer sharpens
## the wits for good (a little more experience from everything, up to ten).
func sit_test() -> void:
	if last_test_day == _day_night.day:
		_talk("The Matron's test", ["[Today's paper is already marked. Full marks are pinned to the wall in the Matron's neat hand.]"])
		return
	var test: Array = TESTS[posmod(_day_night.day * 7 + wits, TESTS.size())]
	var choices: Array = []
	for index in (test[1] as Array).size():
		choices.append([test[1][index], func() -> void: _answer(index == int(test[2]))])
	_talk("The Matron's test", ["[A paper waits on the desk, the ink still wet.]", test[0]], choices)


func _answer(right: bool) -> void:
	last_test_day = _day_night.day
	if right:
		wits = mini(wits + 1, 10)
		_apply_gifts()
		Events.announcement.emit("FULL MARKS", "Your wits are sharper: %d%% more experience from everything." % wits)
	else:
		Events.announcement.emit("", "The Matron marks your paper with a small red cross, and smiles.")
	SaveGame.request_save()


# ------------------------------------------------------------------ escape night

## The field at night: the children follow you through the wheat to the
## wall; the Matron's lantern sweeps the field; a noble waits at the wall.
func start_escape() -> void:
	DialogueMenu.talk(_player, "Wren", ["Now. Stay low. Stay out of the light. Don't look back."], [["Go.", func() -> void: _enter_escape()]], child_look("wren"))


func _enter_escape() -> void:
	_instances.prepare_room()
	var room := Room.new()
	room.title = "The Field at Night"
	room.wall_style = "stone"
	room.gloom = 0.55
	for y in range(-48, 4):
		for x in range(-12, 13):
			var tile := TerrainTiles.Type.DEAD_GRASS
			if absi(x) == 12 or y == 3 or y == -48:
				tile = TerrainTiles.Type.WALL
			elif y == -36:
				tile = TerrainTiles.Type.WALL
			elif y >= -41 and y <= -39:
				tile = TerrainTiles.Type.WALL
			room.cells[Vector2i(x, y)] = tile
	room.entry = Vector2i(0, 1)
	room.build(_world.tile_set())
	_instances.enter(room)
	_scene = "escape"
	stage = 4
	var at := func(cell: Vector2i) -> Vector2: return room.cell_position(cell)
	for row in range(-34, 2, 6):
		for col in [-8, 0, 8]:
			var field := WheatField.new()
			field.position = at.call(Vector2i(col, row))
			field.size = Vector2(300, 200)
			room.add_prop(field)
	# The rope over the wall, the bridge over the chasm, the woods.
	room.add_prop(Prop.create_decor(Prop.Decor.FENCE, at.call(Vector2i(-4, -35)), 0.0, "Climb the rope over the wall", func(_p: Player) -> void: _cross(room, Vector2i(-4, -37))))
	room.add_prop(Prop.create_decor(Prop.Decor.FENCE, at.call(Vector2i(-4, -38)), 0.0, "Cross the rope bridge", func(_p: Player) -> void: _cross(room, Vector2i(-4, -43))))
	room.add_prop(Prop.create(Prop.Art.LADDER, at.call(Vector2i(0, -46)), 0.0, "Into the woods", func(_p: Player) -> void: _escaped()))
	# The children, close behind.
	_followers.clear()
	var index := 0
	for id: String in CHILDREN:
		if children[id] == "home":
			var child := ChildFollower.new()
			child.id = id
			child.position = at.call(Vector2i(-1 + index, 2))
			child.setup(self, _player, index)
			room.add_prop(child)
			_followers.append(child)
			index += 1
	# The Matron's lantern sweeping the field, and a noble at the wall.
	var hunter := MatronHunter.new()
	hunter.speed = 70.0
	hunter.setup(self, [at.call(Vector2i(-9, -10)), at.call(Vector2i(9, -10)), at.call(Vector2i(9, -24)), at.call(Vector2i(-9, -24))])
	room.add_prop(hunter)
	_hunter = hunter
	var guard := _spawner.spawn_at(at.call(Vector2i(3, -33)), maxi(_player.leveling.level, 8), Enemy.Rank.NORMAL, "masked_noble")
	room.enemies.append(guard)
	_music.start()
	Events.announcement.emit("ESCAPE", "Through the wheat to the north wall. Keep the children out of the lantern's light.")


func _cross(room: Room, to: Vector2i) -> void:
	_player.global_position = room.cell_position(to)
	for child: ChildFollower in _followers:
		if is_instance_valid(child) and not child.taken:
			child.global_position = room.cell_position(to) + Vector2(randf_range(-30, 30), 24)
	_player.camera.reset_smoothing()


## A child caught in the lantern's light is taken.
func child_caught(child: ChildFollower) -> void:
	children[child.id] = "taken"
	child.taken = true
	DamageNumber.spawn_text(_world.get_parent(), child.global_position + Vector2(0, -40), "%s is taken!" % CHILDREN[child.id]["name"], UITheme.BAD, 14)
	child.queue_free()
	SaveGame.request_save()


func _escaped() -> void:
	var saved: Array = []
	for child: ChildFollower in _followers:
		if is_instance_valid(child) and not child.taken:
			children[child.id] = "saved"
			saved.append(CHILDREN[child.id]["name"])
	stage = 5
	_followers.clear()
	_instances.leave()
	_apply_gifts()
	_player.leveling.add_xp(600 * maxi(saved.size(), 1), "quest")
	Events.codex_event.emit("foundlings_saved", saved.size())
	if saved.is_empty():
		Events.announcement.emit("ALONE IN THE WOODS", "None of the children made it out with you.")
	else:
		Events.announcement.emit("FREE", "%s made it out. They will be safe at the Sanctuary. Each of them is grateful (more health for every child saved)." % ", ".join(saved))
	SaveGame.request_save()


func _matron_fight(npc: Npc) -> void:
	var at := npc.global_position
	npc.queue_free()
	var boss := _spawner.spawn_at(at, maxi(_player.leveling.level + 2, 10), Enemy.Rank.MINIBOSS, "matron")
	boss.custom_name = "The Matron of Saint Lull's"
	boss.display_name = boss.custom_name
	boss.died.connect(func(_e: Enemy) -> void:
		matron_fallen = true
		var lantern := LootGenerator.make_equipment(_player.leveling.level, 4, "matron_lantern")
		_player.inventory.add(lantern)
		Events.announcement.emit("THE KEEPER IS RELEASED", "The seal that bound her breaks. She is still smiling. Her lantern is yours.")
		Events.codex_event.emit("matron_fallen", 1)
		SaveGame.request_save())
	_music.play_once()


# ------------------------------------------------------------------ games by day

## Tag in the yard: catch every child before the time runs out.
func start_tag() -> void:
	var tag := TagGame.new()
	tag.setup(self, _player)
	_world.get_parent().get_node("Structures").add_child(tag)
	Events.announcement.emit("TAG!", "Catch all three before the bell. They're quick.")


func tag_won() -> void:
	tag_wins = mini(tag_wins + 1, 5)
	_apply_gifts()
	Events.announcement.emit("CAUGHT THEM ALL", "Quicker feet: %d%% faster for good." % tag_wins)
	SaveGame.request_save()


## The lasting gifts: quicker feet from tag, sharper wits from the tests,
## health from every child saved, and the Promise known (the courts' masks
## crack more easily).
func _apply_gifts() -> void:
	if _player == null:
		return
	var saved := children.values().count("saved")
	_player.stats.set_modifiers("saint_lull", {
		"move_speed": {"percent": 0.01 * tag_wins},
		"xp_gain": {"flat": 0.01 * wits},
		"max_health": {"percent": 0.02 * saved},
	})


# ------------------------------------------------------------------ the Reserve

## A noble's hunting reserve, entered by the horn at its gate: three nobles
## hunt you through the woods; hide in the tall grass, last the time out.
func enter_reserve() -> void:
	_instances.prepare_room()
	var room := Room.new()
	room.title = "The Reserve"
	room.wall_style = "stone"
	room.gloom = 0.4
	for y in range(-20, 21):
		for x in range(-20, 21):
			room.cells[Vector2i(x, y)] = TerrainTiles.Type.WALL if absi(x) == 20 or absi(y) == 20 else TerrainTiles.Type.DARK_GRASS
	room.entry = Vector2i(0, 18)
	room.build(_world.tile_set())
	_instances.enter(room)
	_scene = "reserve"
	_scene_left = RESERVE_SECONDS
	_hidden_spots.clear()
	var random := RandomNumberGenerator.new()
	random.seed = reserve_clears * 31 + 7
	for i in 14:
		var cell := Vector2i(random.randi_range(-16, 16), random.randi_range(-16, 14))
		var spot := Rect2(room.cell_position(cell) - Vector2(66, 44), Vector2(132, 88))
		_hidden_spots.append(spot)
		var grass := TallGrass.new()
		grass.position = spot.position
		grass.size = spot.size
		room.add_prop(grass)
	for i in 3:
		var noble := _spawner.spawn_at(room.cell_position(Vector2i(-12 + i * 12, -14)), maxi(_player.leveling.level + i, 8), Enemy.Rank.NORMAL, "masked_noble")
		room.enemies.append(noble)
	Audio.play_note("thunder", 0.5, -8.0)
	Events.announcement.emit("THE RESERVE", "A horn sounds. You are the quarry. Hide in the tall grass and last %d minutes and a half." % int(RESERVE_SECONDS / 60.0))


func _reserve_tick(delta: float) -> void:
	var hidden := _hidden_spots.any(func(spot: Rect2) -> bool: return spot.has_point(_player.global_position))
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy and enemy.enemy_id == "masked_noble":
			enemy.senses = 0.3 if hidden else 1.2
			if hidden and enemy.state == Enemy.State.CHASE and enemy.global_position.distance_to(_player.global_position) > 150.0:
				enemy._pick_wander()
	_scene_left -= delta
	if _scene_left <= 0.0:
		reserve_clears += 1
		_scene = ""
		_player.inventory.add(Item.create("noble_mask"))
		_player.inventory.add_gold(120 + 40 * reserve_clears)
		Events.announcement.emit("THE HUNT IS OVER", "The horn sounds again, three times. You lived. A porcelain mask lies in the grass.")
		Events.codex_event.emit("reserve_survived", 1)
		_instances.leave()
		SaveGame.request_save()


# ------------------------------------------------------------------ the Bunker

func enter_bunker() -> void:
	_instances.prepare_room()
	var room := Room.new()
	room.title = "The Benefactor's Bunker"
	room.wall_style = "wood"
	room.gloom = 0.3
	for y in range(-5, 6):
		for x in range(-7, 8):
			room.cells[Vector2i(x, y)] = TerrainTiles.Type.WALL if absi(x) == 7 or absi(y) == 5 else TerrainTiles.Type.PLANK
	room.entry = Vector2i(0, 4)
	room.build(_world.tile_set())
	_instances.enter(room)
	_scene = "bunker"
	var at := func(cell: Vector2i) -> Vector2: return room.cell_position(cell)
	for x in [-5, -3, 3, 5]:
		room.add_prop(Prop.create_decor(Prop.Decor.SHELF, at.call(Vector2i(x, -4)), 10.0))
	room.add_prop(Prop.create(Prop.Art.TABLE, at.call(Vector2i(0, -2)), 10.0, "Read the Benefactor's journal", func(_p: Player) -> void: open_journal()))
	room.add_prop(Prop.create_decor(Prop.Decor.CANDLES, at.call(Vector2i(1, -2)), 0.0))
	room.add_prop(Prop.create(Prop.Art.BED, at.call(Vector2i(-5, 2)), 10.0))
	var stash := Prop.create(Prop.Art.CHEST if not journal_solved else Prop.Art.CHEST_OPEN, at.call(Vector2i(5, 2)), 10.0, "Open the Benefactor's stash", func(_p: Player) -> void: _open_stash())
	room.add_prop(stash)
	room.add_prop(Prop.create(Prop.Art.LADDER, at.call(room.entry) + Vector2(0, 20), 0.0, "Climb out", func(_p: Player) -> void: _instances.leave()))
	var lamp := Prop.create_decor(Prop.Decor.LANTERN, at.call(Vector2i(-2, -2)), 0.0)
	lamp.add_light(0.7, 1.2, Color(1.0, 0.85, 0.6))
	room.add_prop(lamp)


## The journal is written in a shifted alphabet: turn the dial until it reads.
func open_journal() -> void:
	var menus: Node = _player.get_parent().get_node("Menus")
	var cipher: CipherMenu = menus.get_menu("cipher")
	cipher.lull = self
	menus.open("cipher")


## The shift the Benefactor used (the same in a world).
func journal_key() -> int:
	return 1 + posmod(_world.generator.world_seed, 25)


static func shift_text(text: String, by: int) -> String:
	var out := ""
	for ch in text:
		var code := ch.unicode_at(0)
		if code >= 65 and code <= 90:
			out += String.chr(65 + posmod(code - 65 + by, 26))
		elif code >= 97 and code <= 122:
			out += String.chr(97 + posmod(code - 97 + by, 26))
		else:
			out += ch
	return out


func journal_read() -> void:
	if journal_solved:
		return
	journal_solved = true
	_player.inventory.add(LootGenerator.make_equipment(_player.leveling.level, 3, "benefactor_pen"))
	# The Promise Stones are marked on the map as pins.
	for index in STONE_DISTANCES.size():
		var cell := stone_cell(index)
		if MapMenu.pin_at(cell) < 0 and not index in stones_read:
			MapMenu.pins.append({"tile": [cell.x, cell.y], "name": "Promise Stone %d" % (index + 1), "style": 4, "tracked": false})
	Events.announcement.emit("THE JOURNAL READS TRUE", "The seven Promise Stones are marked on your map. In the stash: the Benefactor's pen.")
	SaveGame.request_save()


func _open_stash() -> void:
	if not journal_solved:
		Events.announcement.emit("", "Locked, with a dial of letters. The journal on the desk must tell the way.")
		return
	if stash_taken:
		Events.announcement.emit("", "Empty now.")
		return
	stash_taken = true
	_player.inventory.add_gold(400)
	_player.inventory.add(Item.create("bedroll"))
	Events.announcement.emit("THE BENEFACTOR'S STASH", "400 gold and a bedroll, left for whoever came next.")
	SaveGame.request_save()


# ------------------------------------------------------------------ the Promise Stones

func read_stone(index: int) -> void:
	var first := not index in stones_read
	if first:
		stones_read.append(index)
		SaveGame.request_save()
	var lines: Array = [STONES[index]]
	if first and stones_read.size() == STONES.size():
		lines.append("[All seven stones are read. You know the Promise now, and how it was broken once. The courts' porcelain will crack more easily under your hand.]")
		Events.codex_event.emit("promise_known", 1)
	_talk("A Promise Stone", lines)
	if first:
		var pin := MapMenu.pin_at(stone_cell(index))
		if pin >= 0:
			MapMenu.pins.remove_at(pin)


## Whether all the stones are read (the masks crack more easily).
func promise_known() -> bool:
	return stones_read.size() >= STONES.size()


# ------------------------------------------------------------------ informers

## Whether a villager informs for the Lull Court (one in seven, by their name).
static func is_informer(villager_key: String) -> bool:
	return villager_key != "" and absi(hash(villager_key + ":lull")) % 7 == 0


## Talking to an informer while the plan is under way: they pass it on.
func heard_by(villager_key: String) -> void:
	if not is_informer(villager_key) or villager_key in informers_caught or stage < 2 or stage >= 5:
		return
	var today := "%s:%d" % [villager_key, _day_night.day]
	if informers_heard.has(today):
		return
	informers_heard[today] = true
	suspicion = minf(suspicion + 15.0, 100.0)
	var factions: Factions = get_tree().get_first_node_in_group("factions")
	if factions:
		factions.report("lull", {"styles": {"melee": 1}})
	SaveGame.request_save()


## Accusing a villager of informing: right, they flee; wrong, it costs.
func accuse(villager_key: String) -> String:
	if is_informer(villager_key) and not villager_key in informers_caught:
		informers_caught.append(villager_key)
		suspicion = maxf(suspicion - 25.0, 0.0)
		SaveGame.request_save()
		return "Their face goes white. The porcelain charm at their throat swings as they run. They will not inform again."
	suspicion = minf(suspicion + 10.0, 100.0)
	SaveGame.request_save()
	return "They stare at you, hurt. The village will remember this. (Suspicion grows.)"


# ------------------------------------------------------------------ every frame

func _physics_process(delta: float) -> void:
	if _player == null:
		return
	_check_ships()
	_refresh_people()
	_new_day()
	_stalk(delta)
	match _scene:
		"reserve":
			_reserve_tick(delta)
	# Music-box lullabies near the House after dark.
	if not _player.indoors and _day_night.is_night_outside():
		var near := _player.global_position.distance_to(_world.cell_to_world(orphanage_cell())) < 520.0
		if near and not _music.playing:
			_music.start()
		elif not near and _music.playing and _scene == "":
			_music.stop()
	# With the seal on your wrist, the Matron always knows where you are.
	if _hunter != null and is_instance_valid(_hunter) and branded:
		(_hunter as MatronHunter).homing_on = _player.global_position


var _last_day := -1
var _stalk_wait := 30.0


## Each morning the Court's suspicion cools a little.
func _new_day() -> void:
	if _day_night.day == _last_day:
		return
	if _last_day >= 0:
		suspicion = maxf(suspicion - 8.0, 0.0)
	_last_day = _day_night.day


## The Court hunts by night: near the House once the truth is seen, and
## anywhere in the wild once suspicion runs high. One or two nobles at most.
func _stalk(delta: float) -> void:
	_stalk_wait -= delta
	if _stalk_wait > 0.0:
		return
	_stalk_wait = 40.0
	if _player.indoors or not _day_night.is_night_outside() or _player.is_dead() or stage < 3:
		return
	var near_house := _player.global_position.distance_to(_world.cell_to_world(orphanage_cell())) < 900.0
	if not near_house and suspicion < 60.0:
		return
	var out := 0
	for node in get_tree().get_nodes_in_group("enemies"):
		if (node as Enemy).enemy_id == "masked_noble":
			out += 1
	if out >= (2 if suspicion >= 80.0 else 1):
		return
	if randf() > (0.35 + suspicion / 200.0):
		return
	var at := _player.global_position + Vector2.from_angle(randf() * TAU) * 520.0
	var cell := _world.generator.find_walkable_near(_world.world_to_cell(at), 8)
	var noble := _spawner.spawn_at(_world.cell_to_world(cell), maxi(_player.leveling.level, 6), Enemy.Rank.ELITE if suspicion >= 80.0 else Enemy.Rank.NORMAL, "masked_noble")
	if noble:
		DamageNumber.spawn_text(_world.get_parent(), _player.global_position + Vector2(0, -60), "Something tall is walking in the dark...", Color(0.96, 0.94, 0.9), 13)
		Audio.play_creature("masked_noble", "idle", noble.global_position, 2.0, 0.8)


## Caught in the Matron's lantern: out of the House, suspicion high, and the
## next shipping comes a day sooner.
func caught() -> void:
	suspicion = minf(suspicion + 30.0, 100.0)
	if ship_day > 0:
		ship_day = maxi(ship_day - 1, _day_night.day + 1)
	var lines: Array = ["There you are, dear. Out of bed, at this hour?", "[Her hand is very cold on your shoulder.]", "Off you go. And do sleep well."]
	if branded:
		lines.append("[The seal on your wrist is warm. She will always find you while it is there. The forge in the cellar could burn it out.]")
	_talk("The Matron", lines,
		[["...", func() -> void:
			if _instances.is_inside():
				_instances.leave()]], matron_look())
	SaveGame.request_save()


## The horn at the Reserve's gate: once you know what the Court is, a
## blast on it calls a hunt in which you are the quarry.
func _sound_horn() -> void:
	if stage < 3:
		Events.announcement.emit("", "A hunting horn on a post, and a porcelain plaque with one slit. Something tells you to leave it be.")
		return
	if not _day_night.is_night_outside():
		_talk("The hunting horn", ["[The plaque on the post reads, in thin gilt letters: THE RESERVE OF THE LULL COURT. HUNTS AT NIGHTFALL.]"])
		return
	_talk("The hunting horn", ["[If you blow it, the Court will come to hunt. In their Reserve there is only tall grass to hide in.]"],
		[["Blow the horn", func() -> void: enter_reserve()], ["Leave it", Callable()]])


func _on_left() -> void:
	if _scene == "escape" and stage == 4:
		# Left the field before reaching the woods: the escape failed.
		stage = 3
		for child: ChildFollower in _followers:
			if is_instance_valid(child) and not child.taken:
				children[child.id] = "home"
		Events.announcement.emit("BACK TO THE HOUSE", "The escape failed. Try again another night.")
	_scene = ""
	_followers.clear()
	_hunter = null
	_people_key = "-"
	_music.stop()


## What the tracker shows while the arc is on.
func tracker_lines() -> Array:
	var steps: Array = []
	match stage:
		1:
			steps.append(["Talk to the children of Saint Lull's", 0, 1])
		2:
			steps.append(["Take the doll to the back gate after dark", 0, 1])
		3:
			steps.append(["Rope (laundry, attic, woodshed)", rope, 3])
			steps.append(["Find the loose stones in the wall by night", 1 if wall_found else 0, 1])
			steps.append(["Burn out the brand at the cellar forge", 1 if brand_burned else 0, 1])
			if ship_day > 0:
				steps.append(["Days until the next carriage", maxi(ship_day - _day_night.day, 0), SHIP_DAYS])
		5:
			if not matron_fallen:
				steps.append(["The Matron waits at the House", 0, 1])
	if steps.is_empty():
		return []
	return ["Saint Lull's House", steps, true]


func save_data() -> Dictionary:
	return {"stage": stage, "rope": rope, "found_rope": found_rope, "wall_found": wall_found, "branded": branded, "brand_burned": brand_burned,
		"suspicion": suspicion, "ship_day": ship_day, "children": children, "wits": wits, "tag_wins": tag_wins, "last_test_day": last_test_day,
		"stones_read": stones_read, "journal_solved": journal_solved, "informers_caught": informers_caught, "informers_heard": informers_heard,
		"reserve_clears": reserve_clears, "matron_fallen": matron_fallen, "stash_taken": stash_taken}


func load_data(data: Dictionary) -> void:
	stage = int(data.get("stage", 0))
	rope = int(data.get("rope", 0))
	found_rope = data.get("found_rope", []) if data.get("found_rope") is Array else []
	wall_found = bool(data.get("wall_found", false))
	branded = bool(data.get("branded", false))
	brand_burned = bool(data.get("brand_burned", false))
	suspicion = float(data.get("suspicion", 0.0))
	ship_day = int(data.get("ship_day", 0))
	var saved_children: Variant = data.get("children", {})
	if saved_children is Dictionary:
		for id: String in children:
			children[id] = str((saved_children as Dictionary).get(id, "home"))
	wits = int(data.get("wits", 0))
	tag_wins = int(data.get("tag_wins", 0))
	last_test_day = int(data.get("last_test_day", -1))
	stones_read = data.get("stones_read", []) if data.get("stones_read") is Array else []
	journal_solved = bool(data.get("journal_solved", false))
	informers_caught = data.get("informers_caught", []) if data.get("informers_caught") is Array else []
	informers_heard = data.get("informers_heard", {}) if data.get("informers_heard") is Dictionary else {}
	reserve_clears = int(data.get("reserve_clears", 0))
	matron_fallen = bool(data.get("matron_fallen", false))
	stash_taken = bool(data.get("stash_taken", false))
	_people_key = "-"
	_apply_gifts()


# ================================================================== pieces

## The Matron with her lantern, walking a round. Her light is a cone ahead
## of her: anyone in it (the player, a child) is seen. With the seal on the
## player's wrist she walks straight to them instead.
class MatronHunter:
	extends Node2D

	var speed := 55.0
	var homing_on: Variant = null
	## Seconds after catching someone in which she goes back to her round.
	var grace := 0.0
	var _lull: SaintLull
	var _points: Array = []
	var _next := 0
	var _facing := Vector2.RIGHT
	var _seeing := 0.0
	var _sprite: AnimatedSprite2D
	var _light: PointLight2D

	func setup(lull: SaintLull, points: Array) -> void:
		_lull = lull
		_points = points
		position = points[0]

	func _ready() -> void:
		_sprite = AnimatedSprite2D.new()
		_sprite.sprite_frames = SheetAnimations.build(EnemyDB.sheet("matron"), EnemyDB.frame_size(EnemyDB.sheet("matron")), [{"name": "idle", "frames": 4, "fps": 4.0, "loop": true}, {"name": "walk", "frames": 6, "fps": 8.0, "loop": true}])
		_sprite.position = Vector2(0, -23)
		_sprite.play("walk")
		add_child(_sprite)
		_light = PointLight2D.new()
		_light.texture = Prop.LIGHT
		_light.texture_scale = 1.6
		_light.energy = 1.1
		_light.color = Color(1.0, 0.85, 0.55)
		_light.position = Vector2(10, -20)
		add_child(_light)

	func _physics_process(delta: float) -> void:
		grace = maxf(grace - delta, 0.0)
		if grace > 0.0:
			homing_on = null
		var goal: Vector2 = homing_on if homing_on != null else _points[_next]
		var way := goal - global_position
		if way.length() < 8.0:
			_next = (_next + 1) % _points.size()
		else:
			_facing = way.normalized()
			global_position += _facing * speed * delta
			_sprite.flip_h = _facing.x < 0.0
		homing_on = null
		# Anyone in the lantern's light is seen.
		var player := _lull._player
		if grace <= 0.0 and _sees(player.global_position) and not player.is_dead():
			_seeing += delta
			if _seeing > 0.6:
				_seeing = 0.0
				grace = 10.0
				_lull.caught()
		else:
			_seeing = maxf(_seeing - delta, 0.0)
		for child in _lull._followers:
			if is_instance_valid(child) and not child.taken and _sees(child.global_position):
				_lull.child_caught(child)
		queue_redraw()

	func _sees(spot: Vector2) -> bool:
		var to := spot - global_position
		return to.length() < 170.0 and to.normalized().dot(_facing) > 0.78

	## The lantern's cone, row by row, warm and faint, brighter near her.
	func _draw() -> void:
		var tip := Vector2(0, -18)
		var steps := 18
		for k in steps:
			var t := float(k) / steps
			var reach := 170.0 * t
			var half := reach * 0.62
			var middle := tip + _facing * reach
			var side := _facing.orthogonal() * half
			draw_line(middle - side, middle + side, Color(1.0, 0.86, 0.5, 0.16 * (1.0 - t) + 0.04), 8.0)


## A child following the player through the field.
class ChildFollower:
	extends Node2D

	var id := ""
	var taken := false
	var _lull: SaintLull
	var _player: Player
	var _place := 0
	var _figure: PersonFigure
	var _warned := 0.0

	func setup(lull: SaintLull, player: Player, place: int) -> void:
		_lull = lull
		_player = player
		_place = place

	func _ready() -> void:
		_figure = PersonFigure.new()
		_figure.dress(SaintLull.child_look(id), 0.72)
		add_child(_figure)

	func _physics_process(delta: float) -> void:
		var goal := _player.global_position + Vector2(-20 + _place * 20, 34 + _place * 10)
		var way := goal - global_position
		if way.length() > 6.0:
			global_position += way.normalized() * minf(way.length() * 4.0, 230.0) * delta
			_figure.pose("walk")
			_figure.face(way.x)
		else:
			_figure.pose("idle")
		# Ash the lookout warns when the lantern comes close.
		_warned -= delta
		if id == "ash" and _warned <= 0.0 and _lull._hunter != null and is_instance_valid(_lull._hunter):
			if (_lull._hunter as Node2D).global_position.distance_to(global_position) < 260.0:
				_warned = 4.0
				DamageNumber.spawn_text(_lull._world.get_parent(), global_position + Vector2(0, -30), "Lantern! Get down!", Color(1.0, 0.85, 0.5), 12)


## A masked noble standing still, seen at the back gate.
class NobleFigure:
	extends Node2D

	func _ready() -> void:
		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = SheetAnimations.build(EnemyDB.sheet("masked_noble"), EnemyDB.frame_size(EnemyDB.sheet("masked_noble")), [{"name": "idle", "frames": 4, "fps": 3.0, "loop": true}])
		sprite.position = Vector2(0, -23)
		sprite.flip_h = true
		sprite.play("idle")
		add_child(sprite)


## A field of wheat: rows of golden stalks drawn pixel by pixel, nodding.
class WheatField:
	extends Node2D

	var size := Vector2(150, 110)

	func _ready() -> void:
		z_index = 0
		y_sort_enabled = false

	func _process(_delta: float) -> void:
		if Engine.get_process_frames() % 3 == 0:
			queue_redraw()

	func _draw() -> void:
		var t := Time.get_ticks_msec() / 1000.0
		var random := RandomNumberGenerator.new()
		random.seed = hash(position)
		var stalks := int(size.x * size.y / 70.0)
		for i in stalks:
			var x := roundf(random.randf_range(-size.x / 2.0, size.x / 2.0))
			var y := roundf(random.randf_range(-size.y / 2.0, size.y / 2.0))
			var tall := 10.0 + random.randi_range(0, 5)
			var sway := roundf(sin(t * 1.6 + x * 0.05 + y * 0.03) * 1.5)
			var stem := Color("b89a42") if i % 3 else Color("9a7e32")
			draw_rect(Rect2(x, y - tall, 1, tall), stem)
			draw_rect(Rect2(x + sway - 1, y - tall - 5, 3, 5), Color("e8c860"))
			draw_rect(Rect2(x + sway, y - tall - 6, 1, 1), Color("f4dc80"))


## Tall grass in the Reserve: somewhere to hide.
class TallGrass:
	extends Node2D

	var size := Vector2(132, 88)

	func _ready() -> void:
		# Drawn over whoever stands in it: that is what hiding means.
		z_index = 1

	func _process(_delta: float) -> void:
		if Engine.get_process_frames() % 3 == 0:
			queue_redraw()

	## Clumps of tall grass, each a fan of blades two pixels wide at the
	## root, dark at the foot and pale at the tips, leaning in the wind.
	func _draw() -> void:
		var t := Time.get_ticks_msec() / 1000.0
		var random := RandomNumberGenerator.new()
		random.seed = hash(position)
		# A darker bed under it all, ragged at the edge.
		for k in int(size.x * size.y / 260.0):
			var at := Vector2(roundf(random.randf_range(4, size.x - 4)), roundf(random.randf_range(4, size.y - 4)))
			draw_rect(Rect2(at - Vector2(6, 2), Vector2(12, 4)), Color(0.1, 0.16, 0.08, 0.55))
		for i in int(size.x * size.y / 70.0):
			var x := roundf(random.randf_range(2, size.x - 2))
			var y := roundf(random.randf_range(6, size.y))
			var tall := 14.0 + random.randi_range(0, 8)
			var lean := roundf(sin(t * 1.3 + x * 0.07 + y * 0.03) * 2.0)
			for blade in 3:
				var spread := float(blade - 1) * 3.0
				var tip := Vector2(x + spread + lean + spread * 0.6, y - tall + absf(spread))
				draw_line(Vector2(x + spread * 0.3, y), tip, Color("2e4a22") if blade != 1 else Color("3c5e2a"), 2.0 if blade == 1 else 1.0)
				draw_line(tip.lerp(Vector2(x, y), 0.5), tip, Color("5a8a38"), 1.0)
				draw_rect(Rect2(tip, Vector2(1, 2)), Color("8ab45a"))


## Tag in the yard: three children run; touch each before the bell.
class TagGame:
	extends Node2D

	var _lull: SaintLull
	var _player: Player
	var _runners: Array = []
	var _left := 45.0

	func setup(lull: SaintLull, player: Player) -> void:
		_lull = lull
		_player = player

	func _ready() -> void:
		var middle := _lull._world.cell_to_world(_lull.orphanage_cell() + Vector2i(0, 2))
		var index := 0
		for id: String in SaintLull.CHILDREN:
			var runner := PersonFigure.new()
			runner.dress(SaintLull.child_look(id), 0.72)
			runner.position = middle + Vector2(-60 + index * 60, 30)
			runner.set_meta("caught", false)
			add_child(runner)
			_runners.append(runner)
			index += 1

	func _physics_process(delta: float) -> void:
		_left -= delta
		var middle := _lull._world.cell_to_world(_lull.orphanage_cell() + Vector2i(0, 2))
		var free := 0
		for runner: PersonFigure in _runners:
			if runner.get_meta("caught"):
				continue
			free += 1
			var away := runner.position - _player.global_position
			if away.length() < 26.0:
				runner.set_meta("caught", true)
				runner.modulate = Color(0.7, 0.7, 0.75)
				DamageNumber.spawn_text(get_parent(), runner.position + Vector2(0, -30), "Caught!", UITheme.GOOD, 12)
				continue
			# Run from the player, but keep within the yard.
			var heading := away.normalized() if away.length() < 160.0 else Vector2.from_angle(Time.get_ticks_msec() / 700.0 + runner.position.x)
			heading = (heading + (middle - runner.position) / 220.0).normalized()
			runner.position += heading * 150.0 * delta
			runner.pose("run")
			runner.face(heading.x)
		if free == 0:
			_lull.tag_won()
			queue_free()
		elif _left <= 0.0:
			Events.announcement.emit("THE BELL RINGS", "Supper! They got away this time.")
			queue_free()


## A music box playing a slow lullaby, one note at a time.
class MusicBox:
	extends Node

	const TUNE: Array[float] = [1.0, 1.26, 1.5, 1.26, 1.0, 0.94, 0.84, 0.94, 1.0, 1.26, 1.5, 1.68, 1.5, 1.26, 1.0, 0.0]
	var playing := false
	var _note := 0
	var _wait := 0.0
	var _once := false

	func start() -> void:
		playing = true
		_once = false

	func stop() -> void:
		playing = false

	func play_once() -> void:
		playing = true
		_once = true
		_note = 0

	func _process(delta: float) -> void:
		if not playing:
			return
		_wait -= delta
		if _wait > 0.0:
			return
		_wait = 0.55
		var pitch := TUNE[_note]
		if pitch > 0.0:
			Audio.play_note("pickup", pitch * 1.5, -16.0)
		_note = (_note + 1) % TUNE.size()
		if _note == 0:
			_wait = 6.0
			if _once:
				playing = false
