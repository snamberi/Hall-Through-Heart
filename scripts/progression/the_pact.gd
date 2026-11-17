class_name ThePact
extends Node
## The Pact: a cold voice with a ledger, offered to whoever survives the
## Drowned Chapel (a deadly place that opens near you once, at level 6).
## Accept it and it keeps your tally from then on, in windows of navy and
## bronze:
##   - a Daily Rite (blows struck, ground walked, monsters slain, things
##     gathered): finish it for attribute points, gold, and now and then a
##     gate key; leave it unfinished and the next day it takes you to the
##     Pit of Atonement, to survive until it lets you go;
##   - your status, and attribute points to spend (the P key);
##   - at level 30, a hidden quest: the Vigil of Ashes, a job change. Hold
##     the grave-ring through the waves of the dead and the Warden of Ashes,
##     and you become a Shade Sovereign, who raises the fallen as shadows.

const CHAPEL_LEVEL := 6
const VIGIL_LEVEL := 30
const PIT_SECONDS := 150.0
const CHAPEL_TOLLS := 6
const TOLL_EVERY := 13.0
## The rite's goals grow with you: [base, per level, cap].
const RITE := {
	"blows": ["Strike blows", 150, 2.0, 500],
	"steps": ["Walk tiles of ground", 800, 4.0, 2000],
	"kills": ["Slay monsters", 25, 0.25, 80],
	"gathered": ["Gather materials", 20, 0.2, 60],
}
## The Chapel's commandments, one called before each toll of the bell.
const COMMANDMENTS := {
	"kneel": ["KNEEL", "Do not move when the bell tolls."],
	"silence": ["SILENCE", "Strike nothing when the bell tolls."],
	"light": ["LIGHT", "Stand in the candlelight when the bell tolls."],
}
const JOBS := {
	"shade_sovereign": {"name": "Shade Sovereign", "text": "Raises the fallen as shadow soldiers, and swaps places with them.",
		"mods": {"max_health": {"percent": 0.1}, "physical_damage": {"percent": 0.08}, "shadow_damage": {"flat": 4.0}, "shadow_resist": {"flat": 0.2}}},
}

signal changed

var awakened := false
var refused := 0
var job := ""
var rite_day := 0
var rite := {"blows": 0, "steps": 0.0, "kills": 0, "gathered": 0}
var rite_done := false
var penalty_due := false
var rites_finished := 0
var vigil_offered := false

var _player: Player
var _world: World
var _instances: Instances
var _spawner: EnemySpawner
var _day_night: DayNight
var _last_position := Vector2.INF
var _scene := ""
var _scene_left := 0.0
var _penalty_wait := 0.0
var _wave_wait := 0.0
var _wave := 0
# --- the Chapel
var _toll_wait := 0.0
var _tolls := 0
var _command := ""
var _commanded := false
var _bell: Node2D
var _candles: Array[Vector2] = []
var _altar: Prop
var _struck_in_toll := false
var _tolling := 0.0
var _vigil_boss: Variant = null


func _ready() -> void:
	add_to_group("pact")
	SaveGame.register("pact", self)


func setup(player: Player, world: World, instances: Instances, spawner: EnemySpawner, day_night: DayNight) -> void:
	_player = player
	_world = world
	_instances = instances
	_spawner = spawner
	_day_night = day_night
	Events.damage_dealt.connect(_on_blow)
	Events.enemy_killed.connect(_on_kill)
	Events.resource_gathered.connect(_on_gather)
	Events.level_up.connect(_on_level_up)
	day_night.day_changed.connect(_on_new_day)
	instances.left.connect(_on_left)
	_apply_job()
	if rite_day == 0:
		rite_day = day_night.day


# ------------------------------------------------------------------ the rite

func goal(key: String) -> int:
	var spec: Array = RITE[key]
	return mini(int(spec[1] + spec[2] * _player.leveling.level), int(spec[3]))


func progress(key: String) -> int:
	return mini(int(rite[key]), goal(key))


func _counts() -> bool:
	return awakened and not rite_done and GameSettings.system_window


func _on_blow(_kind: String, _amount: float) -> void:
	if _counts():
		rite["blows"] = int(rite["blows"]) + 1
		_check_rite()
	if _scene == "chapel" and _tolling > 0.0:
		_struck_in_toll = true


func _on_kill(_info: Dictionary) -> void:
	if _counts():
		rite["kills"] = int(rite["kills"]) + 1
		_check_rite()


func _on_gather(info: Dictionary) -> void:
	if _counts():
		rite["gathered"] = int(rite["gathered"]) + int(info.get("count", 1))
		_check_rite()


func _check_rite() -> void:
	for key: String in RITE:
		if progress(key) < goal(key):
			return
	rite_done = true
	rites_finished += 1
	_player.attributes.grant_points(3)
	var gold := 40 + _player.leveling.level * 6
	_player.inventory.add_gold(gold)
	var lines: Array = ["The Daily Rite is complete.", "+3 attribute points  ·  +%d gold" % gold]
	if randf() < 0.35:
		var key_item := Gates.key_for_level(_player.leveling.level)
		_player.inventory.add(Item.create(key_item))
		lines.append("+1 %s" % ItemDB.ITEMS[key_item]["name"])
	Voices.pact(get_tree(), "RITE COMPLETE", lines)
	Events.codex_event.emit("rites", 1)
	changed.emit()
	SaveGame.request_save()


## Each morning: an unfinished rite means the Pit; a fresh rite begins.
func _on_new_day(day: int) -> void:
	if awakened and GameSettings.system_window and not rite_done and day > rite_day:
		penalty_due = true
		_penalty_wait = 8.0
		Voices.pact(get_tree(), "PENALTY", ["The Daily Rite was not finished.", "You will be taken to the Pit of Atonement."])
	rite_day = day
	rite = {"blows": 0, "steps": 0.0, "kills": 0, "gathered": 0}
	rite_done = false
	if awakened and GameSettings.system_window:
		Voices.pact(get_tree(), "DAILY RITE", _rite_lines())
	changed.emit()
	SaveGame.request_save()


func _rite_lines() -> Array:
	var out: Array = []
	for key: String in RITE:
		out.append("%s  %d / %d" % [RITE[key][0], progress(key), goal(key)])
	return out


# ------------------------------------------------------------------ every frame

func _physics_process(delta: float) -> void:
	if _player == null:
		return
	# Ground walked counts toward the rite.
	if _counts() and not _player.indoors and _last_position != Vector2.INF:
		var moved := _player.global_position.distance_to(_last_position)
		if moved < 200.0:
			var before := int(rite["steps"])
			rite["steps"] = float(rite["steps"]) + moved / TerrainTiles.TILE_SIZE
			if before < goal("steps") and int(rite["steps"]) >= goal("steps"):
				_check_rite()
	_last_position = _player.global_position
	if penalty_due and _scene == "" and not _player.indoors and not _player.is_dead():
		_penalty_wait -= delta
		if _penalty_wait <= 0.0:
			_enter_pit()
	match _scene:
		"pit":
			_pit_tick(delta)
		"chapel":
			_chapel_tick(delta)
		"vigil":
			_vigil_tick(delta)


func _on_level_up(level: int) -> void:
	if awakened and job == "" and level >= VIGIL_LEVEL and not vigil_offered:
		vigil_offered = true
		Voices.pact(get_tree(), "HIDDEN QUEST", ["The Vigil of Ashes.", "Hold the grave-ring until the dead stop coming.", "(Begin it from the Pact window: P)"])
		SaveGame.request_save()


func _on_left() -> void:
	if _scene == "pit" and _scene_left > 0.0:
		# Died in the Pit: it counts as served, at a price.
		penalty_due = false
	_scene = ""
	_bell = null
	_vigil_boss = null


# ------------------------------------------------------------------ the Pit of Atonement

func _enter_pit() -> void:
	penalty_due = false
	_instances.prepare_room()
	var room := Room.new()
	room.title = "The Pit of Atonement"
	room.wall_style = "rock"
	room.gloom = 0.35
	for y in range(-15, 16):
		for x in range(-15, 16):
			var distance := Vector2(x, y).length()
			if distance <= 15.5:
				room.cells[Vector2i(x, y)] = TerrainTiles.Type.SAND if distance <= 14.0 else TerrainTiles.Type.WALL
	room.entry = Vector2i(0, 0)
	room.build(_world.tile_set())
	_instances.enter(room)
	for k in 8:
		var bone := Prop.create_decor(Prop.Decor.BONES, room.cell_position(Vector2i(Vector2.from_angle(TAU * k / 8.0) * 10.0)), 0.0)
		room.add_prop(bone)
	_scene = "pit"
	_scene_left = PIT_SECONDS
	_wave_wait = 3.0
	_wave = 0
	Voices.pact(get_tree(), "PENALTY: THE PIT OF ATONEMENT", ["Survive for %d minutes and a half." % int(PIT_SECONDS / 60.0), "There is no way out until then."])
	Events.codex_event.emit("penalties", 1)


func _pit_tick(delta: float) -> void:
	_scene_left -= delta
	_wave_wait -= delta
	var room := _instances.room
	if room == null:
		return
	if _wave_wait <= 0.0 and _scene_left > 8.0:
		_wave += 1
		_wave_wait = 13.0
		for i in 2 + _wave:
			var spot := room.cell_position(Vector2i(Vector2.from_angle(randf() * TAU) * randf_range(8.0, 13.0)))
			var kind: String = ["sand_scorpion", "sand_scorpion", "dune_mummy"].pick_random()
			var enemy := _spawner.spawn_at(spot, _player.leveling.level, Enemy.Rank.ELITE if i == 0 and _wave % 3 == 0 else Enemy.Rank.NORMAL, kind)
			if enemy:
				enemy.target = _player
				room.enemies.append(enemy)
				RingBurst.spawn(room, spot, Color("d8c890"), 40.0)
	if _scene_left <= 0.0:
		_scene = ""
		room.clear_enemies()
		Voices.pact(get_tree(), "PENALTY SERVED", ["You may go."])
		_instances.leave()


# ------------------------------------------------------------------ the Drowned Chapel

## Into the Chapel: a long nave half under black water, candle-rings along
## it, a great bell over the far end where the altar waits. The bell tolls;
## before each toll a commandment is called; break it and the bell punishes.
func enter_chapel() -> void:
	_instances.prepare_room()
	var room := Room.new()
	room.title = "The Drowned Chapel"
	room.wall_style = "stone"
	room.gloom = 0.6
	for y in range(-26, 6):
		for x in range(-9, 10):
			var tile := TerrainTiles.Type.CAVE_FLOOR
			if absi(x) == 9 or y == -26 or y == 5:
				tile = TerrainTiles.Type.WALL
			elif absi(x) >= 6:
				tile = TerrainTiles.Type.SHALLOW_WATER
			room.cells[Vector2i(x, y)] = tile
	room.entry = Vector2i(0, 3)
	room.build(_world.tile_set())
	_instances.enter(room)
	_scene = "chapel"
	_tolls = 0
	_toll_wait = 8.0
	_command = ""
	_candles.clear()
	var at := func(cell: Vector2i) -> Vector2: return room.cell_position(cell)
	# Pews in rows, pillars, candle-rings, the altar and the bell.
	for y in range(-20, 2, 4):
		for x in [-4, -2, 2, 4]:
			room.add_prop(Prop.create_decor(Prop.Decor.BENCH, at.call(Vector2i(x, y)), 8.0))
		for x in [-6, 6]:
			room.add_prop(Prop.create_decor(Prop.Decor.CARVED_PILLAR, at.call(Vector2i(x, y - 1)), 10.0))
	for cell: Vector2i in [Vector2i(0, -4), Vector2i(-3, -12), Vector2i(3, -17), Vector2i(0, -9)]:
		_candles.append(at.call(cell))
		for k in 6:
			var candle := Prop.create_decor(Prop.Decor.CANDLES, at.call(cell) + Vector2.from_angle(TAU * k / 6.0) * 46.0, 0.0)
			room.add_prop(candle)
		var glow := Prop.create_decor(Prop.Decor.FLOOR, at.call(cell), 0.0)
		glow.sprite().modulate = Color(1.0, 0.85, 0.5, 0.5)
		glow.add_light(1.0, 1.6, Color(1.0, 0.82, 0.5))
		room.add_prop(glow)
	_altar = Prop.create(Prop.Art.ALTAR, at.call(Vector2i(0, -23)), 14.0, "The altar is dark", func(_p: Player) -> void: _touch_altar())
	room.add_prop(_altar)
	var bell := ChapelBell.new()
	bell.position = at.call(Vector2i(0, -24))
	room.add_prop(bell)
	_bell = bell
	room.add_prop(Prop.create(Prop.Art.LADDER, at.call(room.entry) + Vector2(0, 30), 0.0, "Flee the Chapel", func(_p: Player) -> void: _instances.leave()))
	for k in 3:
		var ghost := _spawner.spawn_at(at.call(Vector2i(-5 + k * 5, -15 + k * 3)), maxi(_player.leveling.level, 5), Enemy.Rank.NORMAL, "ghost")
		if ghost:
			room.enemies.append(ghost)
	Voices.pact(get_tree(), "THE DROWNED CHAPEL", ["The bell will toll %d times." % CHAPEL_TOLLS, "Obey what is called before each toll.", "Then the altar."])
	Voices.inner(get_tree(), "Listen for the commandment before each toll. KNEEL: stand still. SILENCE: strike nothing. LIGHT: stand in a candle-ring.", "chapel_rules")


func _chapel_tick(delta: float) -> void:
	if _tolls >= CHAPEL_TOLLS:
		return
	_toll_wait -= delta
	if _command == "" and _toll_wait <= 4.0:
		_command = COMMANDMENTS.keys().pick_random()
		var words: Array = COMMANDMENTS[_command]
		Voices.pact(get_tree(), words[0], [words[1]])
		Audio.play_note("heartbeat", 0.5, -2.0)
	if _toll_wait <= 0.0:
		_toll_wait = TOLL_EVERY
		_tolling = 1.4
		_struck_in_toll = false
		_tolls += 1
		if is_instance_valid(_bell):
			(_bell as ChapelBell).toll()
		Audio.play_note("thunder", 0.35, 2.0)
		_player.shake_camera(5.0)
	if _tolling > 0.0:
		_tolling -= delta
		var broken := false
		match _command:
			"kneel":
				broken = _player.velocity.length() > 20.0
			"silence":
				broken = _struck_in_toll
			"light":
				broken = not _candles.any(func(spot: Vector2) -> bool: return spot.distance_to(_player.global_position) < 60.0)
		if broken:
			_tolling = 0.0
			var hurt := _player.health.max_health * 0.3
			_player.take_damage(hurt, _player.global_position + Vector2(0, -10), _player.leveling.level + 5)
			DamageNumber.spawn_text(_player.get_parent(), _player.global_position + Vector2(0, -60), "THE BELL PUNISHES", Color(1.0, 0.4, 0.4), 15, true)
		if _tolling <= 0.0:
			_command = ""
			if _tolls >= CHAPEL_TOLLS:
				_altar.prompt_text = "Touch the altar"
				_altar.add_light(1.2, 2.0, Color(0.9, 0.8, 1.0))
				Voices.pact(get_tree(), "THE BELL IS STILL", ["You have endured.", "Go to the altar."])


func _touch_altar() -> void:
	if _tolls < CHAPEL_TOLLS:
		Events.announcement.emit("", "Dark and cold. Not yet.")
		return
	DialogueMenu.talk(_player, "The Pact", ["[A ledger opens in the air before you, its pages ruled in bronze.]",
		"You have survived the Drowned Chapel. Few do.",
		"A pact is offered. It will keep your tally. It will give, and it will take. It will make you more than you were.",
		"Will you accept?"], [["Accept the Pact", _accept], ["Refuse", _refuse]])


func _accept() -> void:
	awakened = true
	rite_day = _day_night.day
	rite_done = false
	Events.codex_event.emit("awakened", 1)
	Voices.heart(get_tree(), "The Pact is sealed.", "Press %s to open its window." % GameSettings.describe("open_system"))
	Voices.pact(get_tree(), "WELCOME, BEARER", ["Your tally begins.", "DAILY RITE: " + ", ".join(_rite_lines())])
	var gates: Gates = get_tree().get_first_node_in_group("gates")
	if gates:
		gates.chapel_done()
	_player.leveling.add_xp(800 + _player.leveling.level * 40, "quest")
	SaveGame.request_save()
	_instances.leave()


func _refuse() -> void:
	refused += 1
	Voices.pact(get_tree(), "THE PACT WAITS", ["It will be offered again."])
	_instances.leave()


# ------------------------------------------------------------------ the Vigil of Ashes

func vigil_problem() -> String:
	if not awakened:
		return "The Pact is not yours."
	if job != "":
		return "You have already changed your job."
	if _player.leveling.level < VIGIL_LEVEL:
		return "The Vigil opens at level %d." % VIGIL_LEVEL
	if _player.indoors:
		return "Go outside first."
	return ""


## A ring of graves in the dark, braziers at the quarters. Five waves of the
## dead come over the graves, then the Warden of Ashes.
func begin_vigil() -> String:
	var problem := vigil_problem()
	if problem != "":
		return problem
	_instances.prepare_room()
	var room := Room.new()
	room.title = "The Vigil of Ashes"
	room.wall_style = "stone"
	room.gloom = 0.75
	for y in range(-14, 15):
		for x in range(-14, 15):
			var distance := Vector2(x, y).length()
			if distance <= 14.5:
				room.cells[Vector2i(x, y)] = TerrainTiles.Type.ASH if distance <= 13.0 else TerrainTiles.Type.WALL
	room.entry = Vector2i(0, 0)
	room.build(_world.tile_set())
	_instances.enter(room)
	for k in 12:
		room.add_prop(Prop.create_decor(Prop.Decor.GRAVESTONE, room.cell_position(Vector2i(Vector2.from_angle(TAU * k / 12.0) * 10.0)), 8.0))
	for k in 4:
		var brazier := Prop.create_decor(Prop.Decor.BRAZIER, room.cell_position(Vector2i(Vector2.from_angle(TAU * k / 4.0 + PI / 4.0) * 6.0)), 10.0)
		brazier.add_light(1.0, 2.0, Color(1.0, 0.6, 0.4))
		room.add_prop(brazier)
	_scene = "vigil"
	_wave = 0
	_wave_wait = 4.0
	_vigil_boss = null
	Voices.pact(get_tree(), "JOB CHANGE: THE VIGIL OF ASHES", ["Hold the grave-ring.", "The dead come in five waves, and then their Warden."])
	return ""


func _vigil_tick(delta: float) -> void:
	var room := _instances.room
	if room == null:
		return
	if _vigil_boss != null:
		return
	if room.living_enemies() > 0:
		return
	_wave_wait -= delta
	if _wave_wait > 0.0:
		return
	_wave += 1
	_wave_wait = 3.0
	var level := _player.leveling.level + 2
	if _wave <= 5:
		var waves: Array = [["husk"], ["husk", "bone_archer"], ["rotten_corpse", "bone_archer"], ["ghost", "rotten_corpse"], ["heartsworn_knight", "ghost", "bone_archer"]]
		var kinds: Array = waves[_wave - 1]
		for i in 4 + _wave:
			var spot := room.cell_position(Vector2i(Vector2.from_angle(TAU * i / (4.0 + _wave) + _wave) * 10.0))
			var enemy := _spawner.spawn_at(spot, level, Enemy.Rank.ELITE if i == 0 and _wave >= 3 else Enemy.Rank.NORMAL, kinds.pick_random())
			if enemy:
				enemy.target = _player
				room.enemies.append(enemy)
				RingBurst.spawn(room, spot, Color(0.6, 0.5, 0.7), 40.0)
		Voices.pact(get_tree(), "WAVE %d OF 5" % _wave, [])
		return
	var warden := _spawner.spawn_at(room.cell_position(Vector2i(0, -8)), level + 3, Enemy.Rank.MINIBOSS, "heartsworn_knight")
	if warden == null:
		return
	warden.custom_name = "The Warden of Ashes"
	warden.display_name = warden.custom_name
	warden.target = _player
	room.enemies.append(warden)
	_vigil_boss = warden
	LightPillar.spawn(room, warden.global_position, Color(0.7, 0.6, 0.9))
	Voices.pact(get_tree(), "THE WARDEN OF ASHES", ["Defeat it."])
	warden.died.connect(_on_warden_fallen)


func _on_warden_fallen(_enemy: Enemy) -> void:
	job = "shade_sovereign"
	_apply_job()
	Events.codex_event.emit("job_changed", 1)
	Voices.heart(get_tree(), "Job changed: Shade Sovereign.", "The fallen may rise for you now (press %s near one). Swap places with a shadow: %s." % [GameSettings.describe("raise_shadow"), GameSettings.describe("shadow_swap")])
	Voices.pact(get_tree(), "JOB CHANGE COMPLETE", ["Shade Sovereign", JOBS["shade_sovereign"]["text"]])
	var room := _instances.room
	if room:
		room.add_prop(Prop.create(Prop.Art.PORTAL, room.cell_position(Vector2i.ZERO), 0.0, "Leave the Vigil", func(_p: Player) -> void: _instances.leave()))
	SaveGame.request_save()


func _apply_job() -> void:
	if _player == null:
		return
	_player.stats.set_modifiers("pact_job", JOBS[job]["mods"] if JOBS.has(job) else {})


func job_name() -> String:
	return str(JOBS[job]["name"]) if JOBS.has(job) else ("Awakened" if awakened else "None")


func save_data() -> Dictionary:
	return {"awakened": awakened, "refused": refused, "job": job, "rite_day": rite_day, "rite": rite, "rite_done": rite_done,
		"penalty_due": penalty_due, "rites_finished": rites_finished, "vigil_offered": vigil_offered}


func load_data(data: Dictionary) -> void:
	awakened = bool(data.get("awakened", false))
	refused = int(data.get("refused", 0))
	job = str(data.get("job", ""))
	rite_day = int(data.get("rite_day", 0))
	var saved: Variant = data.get("rite", {})
	rite = {"blows": 0, "steps": 0.0, "kills": 0, "gathered": 0}
	if saved is Dictionary:
		for key: String in rite:
			rite[key] = (saved as Dictionary).get(key, rite[key])
	rite_done = bool(data.get("rite_done", false))
	penalty_due = bool(data.get("penalty_due", false))
	rites_finished = int(data.get("rites_finished", 0))
	vigil_offered = bool(data.get("vigil_offered", false))
	_penalty_wait = 8.0
	_apply_job()


## The Chapel's great bell: bronze, hung from a black beam on two chains,
## swinging when it tolls, with rings of sound going out from it.
class ChapelBell:
	extends Node2D

	var _swing := 0.0
	var _rings: Array = []

	func toll() -> void:
		_swing = 1.0
		_rings.append(0.0)

	func _ready() -> void:
		z_index = 2

	func _process(delta: float) -> void:
		_swing = maxf(_swing - delta * 0.4, 0.0)
		for k in _rings.size():
			_rings[k] = float(_rings[k]) + delta
		_rings = _rings.filter(func(r: float) -> bool: return r < 1.6)
		queue_redraw()

	func _draw() -> void:
		var t := Time.get_ticks_msec() / 1000.0
		# The beam and chains.
		draw_rect(Rect2(-40, -96, 80, 6), Color("1a1820"))
		draw_rect(Rect2(-40, -96, 80, 1), Color("3a3644"))
		var angle := sin(t * 5.0) * 0.25 * _swing
		draw_set_transform(Vector2(0, -90), angle, Vector2.ONE)
		for x in [-10, 9]:
			for y in range(0, 22, 3):
				draw_rect(Rect2(x, y, 2, 2), Color("5a5664"))
		# The bell, row by row: a flared bronze shape, lit at the left.
		for row in 34:
			var y := 22.0 + row
			var half := floorf(9.0 + row * 0.35 + (pow(maxf(row - 24.0, 0.0), 1.6) * 0.5))
			for x in range(-int(half), int(half) + 1):
				var share := (x + half) / maxf(half * 2.0, 1.0)
				var colour := Color("e8bc4a") if share < 0.22 else Color("c8904a") if share < 0.65 else Color("8a5a2a")
				if row == 0 or row == 33 or absi(x) == int(half):
					colour = Color("4a2e14")
				draw_rect(Rect2(x, y, 1, 1), colour)
		draw_rect(Rect2(-2, 56, 4, 4), Color("6a4a20"))
		draw_set_transform(Vector2.ZERO)
		# Rings of sound.
		for r: float in _rings:
			var radius := 30.0 + r * 160.0
			draw_arc(Vector2(0, -50), radius, 0.0, TAU, 48, Color(0.95, 0.85, 0.55, 0.5 * (1.0 - r / 1.6)), 2.0)
