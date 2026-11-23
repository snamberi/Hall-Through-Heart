class_name FlightTrial
extends Node
## Flight is won, not levelled or bought. The Sky Shrine, far out in the
## world, opens on Puzzlementson: ten chambers one after another, each
## barred by a stone gate until its puzzle is solved, wardens in some of
## them. Past the tenth is the Edge, and off the Edge the Trial of Panic: a
## long fall through a shaft of tumbling stone, steered only left and
## right. Survive it and wings break from the player's back: flight is
## theirs for good (T takes to the air and lands).
##
## Dying, or leaving, loses the way: the next attempt starts again at the
## first puzzle.

const T := TerrainTiles.Type
## The ten puzzles, one per chamber, in order.
const PUZZLES: Array[String] = ["plates", "order", "lamps", "bells", "statues", "sprint", "braziers", "riddle", "echo", "missing"]
const NAMES := {
	"plates": "Stand on every stone", "order": "Tread them in their order", "lamps": "Light all three lamps",
	"bells": "Strike from deepest to brightest", "statues": "Turn every watcher to the middle", "sprint": "Outrun the closing light",
	"braziers": "Light them by their marks, fewest first", "riddle": "Answer the inscription", "echo": "Repeat what the stones sing",
	"missing": "Name the colour that was not shown",
}
## Chambers with wardens in them (indices).
const WARDED: Array[int] = [2, 5, 8]
const WARDENS: Array[String] = ["ash_wraith", "void_wisp", "carrion_bat"]
const CHAMBER := 9
const SPACING := 13
const FALL_LENGTH := 150
const FALL_HALF := 5
const COLOURS: Array[Color] = [Color("e04848"), Color("4f9dff"), Color("5fd068"), Color("f2c14e"), Color("b565f0")]
const COLOUR_NAMES: Array[String] = ["red", "blue", "green", "gold", "violet"]
const RIDDLES: Array[Array] = [
	["The more of me you take, the more you leave behind.", ["Footsteps", "Time", "Breath"], 0],
	["I have cities but no houses, forests but no trees, rivers but no water.", ["A map", "A dream", "A grave"], 0],
	["I am always hungry and must be fed; the finger I lick soon turns red.", ["Fire", "A wolf", "A blade"], 0],
	["The one who makes me sells me; the one who buys me never uses me; the one who uses me never knows.", ["A coffin", "A crown", "A key"], 0],
]

## How many of the ten are solved in this attempt.
var solved := 0
var active := false

var _player: Player
var _instances: Instances
var _world: World
var _spawner: EnemySpawner
var _room: Room
var _gates: Array = []
var _chambers: Array = []
var _started: Array[bool] = []
var _falling := false
var _fall_end := 0.0
var _debris: Array = []
var _rng := RandomNumberGenerator.new()
var _sprint_left := -1.0


func setup(player: Player, instances: Instances, world: World, spawner: EnemySpawner) -> void:
	_player = player
	_instances = instances
	_world = world
	_spawner = spawner
	_instances.left.connect(_on_left)


## Steps through the Sky Shrine into Puzzlementson.
func enter(player: Player) -> void:
	_player = player
	if player.flight_unlocked:
		Events.announcement.emit("THE SHRINE IS QUIET", "You have already won your wings.")
		return
	player.land()
	_rng.randomize()
	solved = 0
	_falling = false
	_debris.clear()
	_gates.clear()
	_chambers.clear()
	_started.clear()
	_instances.prepare_room()
	var room := Room.new()
	room.title = "Puzzlementson"
	room.wall_style = "stone"
	room.gloom = 0.15
	var half := CHAMBER / 2
	for k in PUZZLES.size() + 1:
		var c := Vector2i(0, -k * SPACING)
		for y in range(-half - 1, half + 2):
			for x in range(-half - 1, half + 2):
				var cell := c + Vector2i(x, y)
				if not room.cells.has(cell) or room.cells[cell] == T.WALL:
					room.cells[cell] = T.SALT if absi(x) <= half and absi(y) <= half else T.WALL
		if k < PUZZLES.size():
			# A corridor north to the next chamber, three wide.
			for y in range(c.y - SPACING + half + 1, c.y - half):
				for x in range(-2, 3):
					room.cells[Vector2i(x, y)] = T.SALT if absi(x) <= 1 else T.WALL
	room.entry = Vector2i(0, half - 1)
	room.build(_world.tile_set())
	_instances.enter(room)
	_room = room
	active = true
	for k in PUZZLES.size():
		_gates.append(_gate(k))
		_chambers.append({})
		_started.append(false)
		_build(k)
	_build_edge()
	Events.announcement.emit("PUZZLEMENTSON", "Ten puzzles stand between you and the sky. Fall here, and you begin again.")


func _center(k: int) -> Vector2:
	return _room.cell_position(Vector2i(0, -k * SPACING))


func _cell(k: int, offset: Vector2i) -> Vector2:
	return _room.cell_position(Vector2i(0, -k * SPACING) + offset)


## The stone gate across the way north out of a chamber.
func _gate(k: int) -> Array:
	var stones: Array = []
	var y := -k * SPACING - CHAMBER / 2 - 1
	for x in range(-1, 2):
		var stone := Prop.create(Prop.Art.WALL, _room.cell_position(Vector2i(x, y)) + Vector2(0, 10), 24.0)
		stone.sprite().modulate = Color(0.8, 0.85, 1.0)
		_room.add_prop(stone)
		stones.append(stone)
	return stones


func _plate(at: Vector2, label: String = "", colour: Color = Color(0.75, 0.8, 0.95)) -> TrialPlate:
	var plate := TrialPlate.new()
	plate.position = at
	plate.label = label
	plate.base = colour
	_room.add_prop(plate)
	return plate


func _stone(decor: Prop.Decor, at: Vector2, prompt: String, action: Callable) -> Prop:
	var prop := Prop.create_decor(decor, at, 10.0, prompt, func(_p: Player) -> void: action.call())
	_room.add_prop(prop)
	return prop


# --- the ten puzzles

func _build(k: int) -> void:
	var state: Dictionary = _chambers[k]
	match PUZZLES[k]:
		"plates":
			state["plates"] = []
			for offset: Vector2i in [Vector2i(-2, -2), Vector2i(2, -2), Vector2i(-2, 2), Vector2i(2, 2)]:
				state["plates"].append(_plate(_cell(k, offset)))
		"order":
			var numerals := ["I", "II", "III", "IV"]
			var spots := [Vector2i(-3, 0), Vector2i(-1, -2), Vector2i(1, 2), Vector2i(3, 0)]
			spots.shuffle()
			state["plates"] = []
			for index in 4:
				var plate := _plate(_cell(k, spots[index]), numerals[index])
				plate.set_meta("rank", index)
				state["plates"].append(plate)
			state["next"] = 0
		"lamps":
			state["lit"] = [false, true, false]
			state["lamps"] = []
			for index in 3:
				var lamp := _plate(_cell(k, Vector2i(-2 + index * 2, -2)), "", Color(1.0, 0.8, 0.4))
				lamp.round = true
				state["lamps"].append(lamp)
				_stone(Prop.Decor.LEVER, _cell(k, Vector2i(-2 + index * 2, 1)), "Pull the lever", func() -> void: _pull(k, index))
			_show_lamps(k)
		"bells", "echo":
			var pitches := [0.62, 0.8, 1.0, 1.26]
			var order := [0, 1, 2, 3]
			order.shuffle()
			state["pitch"] = []
			state["orbs"] = []
			for index in 4:
				var pitch: float = pitches[order[index]]
				state["pitch"].append(pitch)
				var orb := _plate(_cell(k, Vector2i(-3 + index * 2, -2)), "", Color(0.7, 0.9, 1.0))
				orb.round = true
				state["orbs"].append(orb)
				_stone(Prop.Decor.CHIME_STONE, _cell(k, Vector2i(-3 + index * 2, 0)), "Strike the chime stone", func() -> void: _strike(k, index))
			state["heard"] = []
			if PUZZLES[k] == "echo":
				state["song"] = [randi() % 4, randi() % 4, randi() % 4, randi() % 4]
		"statues":
			state["facing"] = []
			state["arrows"] = []
			var spots := [Vector2i(-3, -2), Vector2i(3, -2), Vector2i(0, 3)]
			for index in 3:
				state["facing"].append(_rng.randi_range(0, 3))
				var arrow := TrialPlate.new()
				arrow.arrow = true
				arrow.position = _cell(k, spots[index]) + Vector2(0, -46)
				_room.add_prop(arrow)
				state["arrows"].append(arrow)
				_stone(Prop.Decor.STATUE, _cell(k, spots[index]), "Turn the watcher", func() -> void: _turn(k, index))
			state["spots"] = spots
			_show_arrows(k)
		"sprint":
			state["start"] = _plate(_cell(k, Vector2i(-3, 3)), "GO", Color(0.6, 0.95, 0.7))
			state["goal"] = _plate(_cell(k, Vector2i(3, -3)), "", Color(1.0, 0.85, 0.5))
		"braziers":
			var marks := [1, 2, 3, 4]
			marks.shuffle()
			state["marks"] = marks
			state["next"] = 1
			state["fires"] = []
			for index in 4:
				var fire := _plate(_cell(k, Vector2i(-3 + index * 2, -1)), "|".repeat(marks[index]), Color(0.95, 0.6, 0.35))
				fire.round = true
				state["fires"].append(fire)
				_stone(Prop.Decor.BRAZIER, _cell(k, Vector2i(-3 + index * 2, 1)), "Light the brazier (%d marks)" % marks[index], func() -> void: _kindle(k, index))
		"riddle":
			var riddle: Array = RIDDLES[_rng.randi_range(0, RIDDLES.size() - 1)]
			state["riddle"] = riddle
			_stone(Prop.Decor.RUNE_STELE, _cell(k, Vector2i(0, -3)), "Read the inscription", func() -> void:
				Events.announcement.emit("THE INSCRIPTION", riddle[0]))
			var answers: Array = riddle[1].duplicate()
			var right: String = answers[riddle[2]]
			answers.shuffle()
			for index in 3:
				var answer: String = answers[index]
				_stone(Prop.Decor.ANSWER_TABLET, _cell(k, Vector2i(-2 + index * 2, 1)), "Answer: %s" % answer, func() -> void: _answer(k, answer == right))
		"missing":
			var shown := [0, 1, 2, 3, 4]
			shown.shuffle()
			state["missing"] = shown.pop_back()
			state["shown"] = shown
			state["orbs"] = []
			for index in 4:
				var orb := _plate(_cell(k, Vector2i(-3 + index * 2, -3)), "", Color(0.3, 0.3, 0.35))
				orb.round = true
				state["orbs"].append(orb)
			for index in 5:
				var colour := index
				var tablet := _stone(Prop.Decor.ANSWER_TABLET, _cell(k, Vector2i(-4 + index * 2, 2)), "Name it %s" % COLOUR_NAMES[colour], func() -> void: _name_colour(k, colour))
				tablet.sprite().modulate = COLOURS[colour].lightened(0.3)


## Called the first time the player walks into a chamber.
func _start(k: int) -> void:
	_started[k] = true
	var state: Dictionary = _chambers[k]
	Events.announcement.emit("PUZZLE %d OF 10" % (k + 1), NAMES[PUZZLES[k]])
	if k in WARDED:
		for i in 2:
			var spot := _cell(k, Vector2i(-3 if i == 0 else 3, -3))
			var level := maxi(_player.leveling.level, 5)
			var enemy := _spawner.spawn_at(spot, level, Enemy.Rank.NORMAL, WARDENS[(k / 3) % WARDENS.size()] if EnemyDB.ENEMIES.has(WARDENS[(k / 3) % WARDENS.size()]) else "husk")
			_room.enemies.append(enemy)
			RingBurst.spawn(_room, spot, Color(0.75, 0.55, 1.0), 40.0)
	match PUZZLES[k]:
		"echo":
			_sing(k)
		"missing":
			_flash_colours(k)


func _solve(k: int) -> void:
	# Only the next puzzle, and only while the trial is laid out.
	if k != solved or k >= _gates.size():
		return
	solved += 1
	Audio.play("level_up", -6.0)
	for stone: Node in _gates[k]:
		if is_instance_valid(stone):
			RingBurst.spawn(_room, (stone as Node2D).global_position, Color(0.8, 0.9, 1.0), 30.0)
			stone.queue_free()
	Events.announcement.emit("SOLVED", "%d of 10. The way north opens." % solved if solved < 10 else "All ten. The Edge waits beyond.")


func _wrong(k: int, text: String) -> void:
	Audio.play("hit", -8.0)
	DamageNumber.spawn_text(_room, _center(k) + Vector2(0, -60), text, UITheme.BAD, 15)


func _physics_process(delta: float) -> void:
	if not active or _player == null or _room == null or not is_instance_valid(_room):
		return
	if _falling:
		_fall_step(delta)
		return
	var here := _player.global_position
	var k := clampi(roundi((_room.cell_position(Vector2i.ZERO).y - here.y) / (SPACING * TerrainTiles.TILE_SIZE)), 0, PUZZLES.size())
	if k >= PUZZLES.size() or k != solved:
		return
	if not _started[k] and here.distance_to(_center(k)) < (CHAMBER / 2) * TerrainTiles.TILE_SIZE:
		_start(k)
	if not _started[k]:
		return
	var state: Dictionary = _chambers[k]
	match PUZZLES[k]:
		"plates":
			var lit := 0
			for plate: TrialPlate in state["plates"]:
				if plate.under(here):
					plate.lit = true
				lit += 1 if plate.lit else 0
			if lit == 4:
				_solve(k)
		"order":
			for plate: TrialPlate in state["plates"]:
				if plate.under(here) and not plate.lit:
					if int(plate.get_meta("rank")) == state["next"]:
						plate.lit = true
						state["next"] += 1
						Audio.play_note("pickup", 0.8 + 0.15 * state["next"], -6.0)
						if state["next"] == 4:
							_solve(k)
					else:
						for other: TrialPlate in state["plates"]:
							other.lit = false
						state["next"] = 0
						_wrong(k, "Out of order")
		"sprint":
			if (state["start"] as TrialPlate).under(here) and _sprint_left < 0.0:
				_sprint_left = 3.4
				(state["start"] as TrialPlate).lit = true
				Audio.play_note("pickup", 1.2, -6.0)
			if _sprint_left >= 0.0:
				_sprint_left -= delta
				if (state["goal"] as TrialPlate).under(here):
					(state["goal"] as TrialPlate).lit = true
					_sprint_left = -1.0
					_solve(k)
				elif _sprint_left < 0.0:
					(state["start"] as TrialPlate).lit = false
					_wrong(k, "Too slow")


func _pull(k: int, index: int) -> void:
	if k != solved:
		return
	var lit: Array = _chambers[k]["lit"]
	for i in range(index - 1, index + 2):
		if i >= 0 and i < 3:
			lit[i] = not lit[i]
	Audio.play("ui_click", -6.0)
	_show_lamps(k)
	if lit.all(func(on: bool) -> bool: return on):
		_solve(k)


func _show_lamps(k: int) -> void:
	for index in 3:
		(_chambers[k]["lamps"][index] as TrialPlate).lit = _chambers[k]["lit"][index]


func _strike(k: int, index: int) -> void:
	if k != solved:
		return
	var state: Dictionary = _chambers[k]
	var pitch: float = state["pitch"][index]
	Audio.play_note("pickup", pitch, -3.0)
	(state["orbs"][index] as TrialPlate).pulse()
	var heard: Array = state["heard"]
	heard.append(index)
	if PUZZLES[k] == "bells":
		# Each strike must ring higher than the one before.
		if heard.size() > 1 and pitch < float(state["pitch"][heard[heard.size() - 2]]):
			heard.clear()
			_wrong(k, "Lower than the last")
		elif heard.size() == 4:
			_solve(k)
	else:
		var song: Array = state["song"]
		if heard[heard.size() - 1] != song[heard.size() - 1]:
			heard.clear()
			_wrong(k, "Not their song. Listen again.")
			_sing(k)
		elif heard.size() == song.size():
			_solve(k)


## The stones sing their tune, one after another.
func _sing(k: int) -> void:
	var state: Dictionary = _chambers[k]
	for step in (state["song"] as Array).size():
		var index: int = state["song"][step]
		get_tree().create_timer(0.9 + step * 0.7).timeout.connect(func() -> void:
			var orb: Variant = state["orbs"][index]
			if active and not _falling and is_instance_valid(orb):
				Audio.play_note("pickup", float(state["pitch"][index]), -3.0)
				(orb as TrialPlate).pulse()
		)


func _turn(k: int, index: int) -> void:
	if k != solved:
		return
	var facing: Array = _chambers[k]["facing"]
	facing[index] = (int(facing[index]) + 1) % 4
	Audio.play("ui_click", -6.0)
	_show_arrows(k)
	for i in 3:
		if facing[i] != _toward_middle(_chambers[k]["spots"][i]):
			return
	_solve(k)


## Which way (0 east, 1 south, 2 west, 3 north) points from a spot toward
## the chamber's middle.
static func _toward_middle(spot: Vector2i) -> int:
	var to := -Vector2(spot)
	if absf(to.x) >= absf(to.y):
		return 0 if to.x > 0.0 else 2
	return 1 if to.y > 0.0 else 3


func _show_arrows(k: int) -> void:
	for index in 3:
		(_chambers[k]["arrows"][index] as TrialPlate).direction = int(_chambers[k]["facing"][index])


func _kindle(k: int, index: int) -> void:
	if k != solved:
		return
	var state: Dictionary = _chambers[k]
	var fire: TrialPlate = state["fires"][index]
	if fire.lit:
		return
	if int(state["marks"][index]) == int(state["next"]):
		fire.lit = true
		state["next"] += 1
		Audio.play("ui_click", -4.0)
		if state["next"] == 5:
			_solve(k)
	else:
		for other: TrialPlate in state["fires"]:
			other.lit = false
		state["next"] = 1
		_wrong(k, "The fires gutter out")


func _answer(k: int, right: bool) -> void:
	if k != solved:
		return
	if right:
		_solve(k)
	else:
		_wrong(k, "The stone does not agree")
		var enemy := _spawner.spawn_at(_center(k) + Vector2(0, -80), maxi(_player.leveling.level, 5), Enemy.Rank.NORMAL, "husk")
		_room.enemies.append(enemy)


func _flash_colours(k: int) -> void:
	var state: Dictionary = _chambers[k]
	for index in 4:
		(state["orbs"][index] as TrialPlate).base = COLOURS[state["shown"][index]]
		(state["orbs"][index] as TrialPlate).lit = true
	get_tree().create_timer(2.6).timeout.connect(func() -> void:
		if active and not _falling:
			for orb: Variant in state["orbs"]:
				if is_instance_valid(orb):
					(orb as TrialPlate).lit = false
					(orb as TrialPlate).base = Color(0.3, 0.3, 0.35)
	)


func _name_colour(k: int, colour: int) -> void:
	if k != solved:
		return
	if colour == int(_chambers[k]["missing"]):
		_solve(k)
	else:
		_wrong(k, "That one was shown")
		_flash_colours(k)


# --- the Edge and the Trial of Panic

func _build_edge() -> void:
	var k := PUZZLES.size()
	var edge := Prop.create(Prop.Art.PORTAL, _center(k), 0.0, "Step off the Edge", func(_p: Player) -> void:
		if solved >= PUZZLES.size():
			_start_fall()
		else:
			Events.announcement.emit("", "The Edge will not have you yet.")
	)
	edge.sprite().modulate = Color(0.8, 0.9, 1.0)
	_room.add_prop(edge)


func _start_fall() -> void:
	# Only from the Edge, with all ten solved.
	if solved < PUZZLES.size() or _player == null or _player.flight_unlocked:
		return
	var room := Room.new()
	room.title = "The Trial of Panic"
	room.wall_style = "void"
	room.gloom = 0.35
	for y in range(-1, FALL_LENGTH + 2):
		for x in range(-FALL_HALF - 1, FALL_HALF + 2):
			room.cells[Vector2i(x, y)] = T.VOIDSCAR if absi(x) <= FALL_HALF and y >= 0 and y <= FALL_LENGTH else T.WALL
	room.entry = Vector2i(0, 1)
	room.build(_world.tile_set())
	_instances.enter(room)
	_room = room
	_falling = true
	_fall_end = room.cell_position(Vector2i(0, FALL_LENGTH - 2)).y
	_debris.clear()
	# Tumbling stone, thicker the further down.
	for y in range(8, FALL_LENGTH - 6, 3):
		var count := 1 if y < 50 else 2
		for i in count:
			var rock := FallingStone.new()
			rock.position = room.cell_position(Vector2i(_rng.randi_range(-FALL_HALF, FALL_HALF), y)) + Vector2(_rng.randf_range(-14, 14), 0)
			rock.size = _rng.randf_range(9.0, 15.0)
			room.add_prop(rock)
			_debris.append(rock)
	var streaks := FallStreaks.new()
	streaks.follow = _player
	room.add_child(streaks)
	_player.falling = true
	Events.announcement.emit("THE TRIAL OF PANIC", "You fall. Lean left and right; do not hit the stone.")


func _fall_step(_delta: float) -> void:
	var here := _player.global_position
	for entry: Variant in _debris.duplicate():
		if not is_instance_valid(entry):
			_debris.erase(entry)
			continue
		var rock := entry as FallingStone
		if rock.global_position.distance_to(here + Vector2(0, -18)) < rock.size + 10.0:
			_debris.erase(rock)
			rock.shatter()
			var shove := Vector2(signf(here.x - rock.global_position.x) * 260.0, 0.0)
			_player.take_damage(_player.health.max_health * 0.16, shove)
			if _player.is_dead():
				return
	if here.y >= _fall_end:
		_falling = false
		_player.falling = false
		_awaken()


func _awaken() -> void:
	active = false
	_player.flight_unlocked = true
	_instances.leave()
	_player.toggle_flight()
	LightPillar.spawn(_player.get_parent(), _player.global_position, Color(0.85, 0.92, 1.0))
	RingBurst.spawn(_player.get_parent(), _player.global_position, Color(1.0, 0.95, 0.8), 90.0)
	Events.announcement.emit("FLIGHT AWAKENED", "Wings break from your back. T takes to the air and lands.")
	Events.codex_event.emit("flight", 1)
	SaveGame.request_save()


func _on_left() -> void:
	if not active:
		return
	if _falling or solved < PUZZLES.size() or _instances.room == null:
		# Died or walked out: the way is lost.
		active = false
		_falling = false
		_player.falling = false
		solved = 0


## A floor stone, lamp or marker in Puzzlementson, drawn as a disc that
## lights up; as `arrow`, a pointer showing which way a statue watches.
class TrialPlate:
	extends Node2D

	var label := ""
	var base := Color(0.75, 0.8, 0.95)
	var round := false
	var arrow := false
	var direction := 0
	var lit := false:
		set(value):
			lit = value
			queue_redraw()
	var _pulse := 0.0

	func _ready() -> void:
		z_index = -2 if not arrow else 2

	func under(at: Vector2) -> bool:
		return at.distance_to(global_position) < 18.0

	func pulse() -> void:
		_pulse = 0.5

	func _process(delta: float) -> void:
		if _pulse > 0.0:
			_pulse = maxf(_pulse - delta, 0.0)
		queue_redraw()

	func _draw() -> void:
		if arrow:
			var dir: Vector2 = [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP][direction]
			draw_line(-dir * 8.0, dir * 8.0, Color(1.0, 0.9, 0.6), 3.0)
			draw_line(dir * 8.0, dir * 3.0 + dir.orthogonal() * 5.0, Color(1.0, 0.9, 0.6), 3.0)
			draw_line(dir * 8.0, dir * 3.0 - dir.orthogonal() * 5.0, Color(1.0, 0.9, 0.6), 3.0)
			return
		var glow := 1.0 if lit else _pulse * 2.0
		var colour := base.darkened(0.55).lerp(base.lightened(0.25), clampf(glow, 0.0, 1.0))
		if round:
			draw_circle(Vector2(0, -10), 9.0, Color(0.08, 0.08, 0.12))
			draw_circle(Vector2(0, -10), 7.0, colour)
			if glow > 0.0:
				draw_circle(Vector2(0, -10), 13.0, Color(base, 0.25 * glow))
		else:
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.6))
			draw_circle(Vector2.ZERO, 17.0, Color(0.1, 0.1, 0.14))
			draw_circle(Vector2.ZERO, 14.0, colour)
			draw_arc(Vector2.ZERO, 14.0, 0.0, TAU, 24, Color(1, 1, 1, 0.3), 1.0)
			draw_set_transform(Vector2.ZERO)
		if label != "":
			var font := UITheme.body_bold()
			draw_string_outline(font, Vector2(-30, -16 if round else 5), label, HORIZONTAL_ALIGNMENT_CENTER, 60, 13, 3, Color(0, 0, 0, 0.8))
			draw_string(font, Vector2(-30, -16 if round else 5), label, HORIZONTAL_ALIGNMENT_CENTER, 60, 13, Color(1.0, 0.95, 0.8))


## A stone tumbling in the shaft of the Trial of Panic.
class FallingStone:
	extends Node2D

	var size := 12.0
	var _spin := 0.0

	func _process(delta: float) -> void:
		_spin += delta
		position.x += sin(_spin * 1.3 + position.y) * 10.0 * delta
		queue_redraw()

	func shatter() -> void:
		RingBurst.spawn(get_parent(), global_position, Color(0.75, 0.7, 0.8), 30.0)
		queue_free()

	func _draw() -> void:
		var points := PackedVector2Array()
		for i in 7:
			var a := TAU * i / 7.0 + _spin * 0.8
			points.append((Vector2.from_angle(a) * size * (0.8 + 0.2 * sin(i * 2.3))).round())
		draw_colored_polygon(points, Color("6a6474"))
		points.append(points[0])
		draw_polyline(points, Color("1a1620"), 2.0)
		draw_circle(Vector2(-size * 0.3, -size * 0.3).round(), size * 0.25, Color("9a94a4"))


## Streaks of wind rushing up past the falling player.
class FallStreaks:
	extends Node2D

	var follow: Node2D
	var _lines: Array = []

	func _ready() -> void:
		z_index = 5
		for i in 26:
			_lines.append(Vector3(randf_range(-260, 260), randf_range(-200, 200), randf_range(14, 34)))

	func _process(delta: float) -> void:
		if follow == null or not is_instance_valid(follow):
			return
		global_position = follow.global_position
		for i in _lines.size():
			var line: Vector3 = _lines[i]
			line.y -= 900.0 * delta
			if line.y < -220.0:
				line = Vector3(randf_range(-260, 260), 220.0, randf_range(14, 34))
			_lines[i] = line
		queue_redraw()

	func _draw() -> void:
		for line: Vector3 in _lines:
			draw_line(Vector2(line.x, line.y), Vector2(line.x, line.y + line.z), Color(0.85, 0.9, 1.0, 0.35), 2.0)
