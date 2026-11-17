class_name Gates
extends Node
## Gates: tears in the world that the Pact can see. Each has a rank, E to S,
## shown by its colour and the letter over it. A gate stays open a few days;
## left uncleared, it breaks, and what lived in it pours out into the world
## round it (and from an S-rank gate, a Monarch walks out). Inside: a line
## of chambers and, in the last, the gate's master. A red gate (rare) seals
## behind you: no way out, no recall, until its master dies.
##
## Gate keys (from rites and gate masters) open a private gate of their
## rank wherever you stand.
##
## Before the Pact, one gate only: the Drowned Chapel, crimson and gold, rank
## unknown. It opens near you once you are strong enough to survive it.

const RANKS := {
	"E": {"color": Color("a8a8b0"), "offset": -3, "days": 3, "rooms": 3, "leader": Enemy.Rank.ELITE, "floor": TerrainTiles.Type.CAVE_FLOOR, "walls": "rock", "from": 1},
	"D": {"color": Color("7ad07a"), "offset": -1, "days": 3, "rooms": 3, "leader": Enemy.Rank.CHAMPION, "floor": TerrainTiles.Type.CAVE_FLOOR, "walls": "rock", "from": 8},
	"C": {"color": Color("6aa8f0"), "offset": 1, "days": 4, "rooms": 4, "leader": Enemy.Rank.MINIBOSS, "floor": TerrainTiles.Type.CAVE_FLOOR, "walls": "stone", "from": 18},
	"B": {"color": Color("b07af0"), "offset": 3, "days": 4, "rooms": 4, "leader": Enemy.Rank.BOSS, "floor": TerrainTiles.Type.ASH, "walls": "stone", "from": 30},
	"A": {"color": Color("f0a050"), "offset": 6, "days": 5, "rooms": 5, "leader": Enemy.Rank.BOSS, "floor": TerrainTiles.Type.ASH, "walls": "void", "from": 50},
	"S": {"color": Color("f05a4a"), "offset": 10, "days": 6, "rooms": 5, "leader": Enemy.Rank.BOSS, "floor": TerrainTiles.Type.VOIDSCAR, "walls": "void", "from": 80},
}
const ORDER: Array[String] = ["E", "D", "C", "B", "A", "S"]
## The monsters a gate may hold (one theme of three, chosen by its seed).
const POOL: Array[String] = ["husk", "rot_hound", "bone_archer", "bog_slime", "carrion_bat", "thorn_stalker", "spore_shambler", "rot_cultist",
	"ember_wisp", "ash_wraith", "crag_golem", "giant_spider", "frost_wolf", "frost_troll", "dire_boar", "treant", "sand_scorpion", "dune_mummy",
	"void_stalker", "void_eye", "crimson_fiend", "veinheart", "heartsworn_knight", "rotten_corpse", "ghost", "magma_slime", "cinder_imp",
	"bog_lurker", "storm_harpy"]
const RED_POOL: Array[String] = ["frost_wolf", "frost_troll", "ghost", "ash_wraith"]
## The Monarchs: kings of what lies behind S-rank gates, each the strongest
## form of one of the world's great bosses. [boss id, name].
const MONARCHS: Array[Array] = [["cinderlord", "Vael, Monarch of Embers"], ["frostwarden", "Isarn, Monarch of the Long Winter"],
	["hollow_king", "Orrun, Monarch of the Hollow"], ["briar_queen", "Thessaly, Monarch of Thorns"], ["unblinking_eye", "The Monarch Who Watches"]]
const MAX_OPEN := 3
const OPEN_CHANCE := 0.6
const RED_CHANCE := 0.12
const SHOW_DISTANCE := 1400.0

## Whether a red gate holds the player (no recall, no leaving).
static var sealed := false

signal changed

## [{"id", "rank", "cell", "day", "red", "broken", "spawned"}]
var gates: Array = []
var cleared := 0
var monarchs_fallen: Array = []
var chapel_cell := Vector2i.MAX
var _next_id := 1

var _player: Player
var _world: World
var _instances: Instances
var _spawner: EnemySpawner
var _day_night: DayNight
var _loot: Node
var _tears: Dictionary = {}
var _check_left := 0.0
var _inside: Dictionary = {}
var _master: Variant = null


func _ready() -> void:
	add_to_group("gates")
	SaveGame.register("gates", self)


func setup(player: Player, world: World, instances: Instances, spawner: EnemySpawner, day_night: DayNight, loot: Node) -> void:
	_player = player
	_world = world
	_instances = instances
	_spawner = spawner
	_day_night = day_night
	_loot = loot
	day_night.day_changed.connect(_on_new_day)
	instances.left.connect(_on_left)


func _pact() -> ThePact:
	return get_tree().get_first_node_in_group("pact") as ThePact


## The gate key for a level's rank.
static func key_for_level(level: int) -> String:
	return "gate_key_" + rank_for_level(level, 0.0).to_lower()


## A rank fitting a level (with a little luck upward).
static func rank_for_level(level: int, roll: float) -> String:
	var best := "E"
	for rank: String in ORDER:
		if level >= int(RANKS[rank]["from"]):
			best = rank
	var index := ORDER.find(best)
	if roll > 0.85 and index < ORDER.size() - 1:
		index += 1
	elif roll < 0.25 and index > 0:
		index -= 1
	return ORDER[index]


func gate_level(rank: String) -> int:
	return maxi(_player.leveling.level + int(RANKS[rank]["offset"]), 1)


# ------------------------------------------------------------------ opening, breaking

func _on_new_day(_day: int) -> void:
	var pact := _pact()
	# Gates left too long break.
	for gate: Dictionary in gates:
		if not gate["broken"] and _day_night.day - int(gate["day"]) >= int(RANKS[gate["rank"]]["days"]):
			gate["broken"] = true
			var where := Structures.compass(Vector2(Vector2i(gate["cell"][0], gate["cell"][1]) - _world.world_to_cell(_player.global_position)))
			Voices.pact(get_tree(), "GATE BREAK", ["The %s-rank gate to the %s has broken." % [gate["rank"], where], "What was inside walks free."])
			Events.codex_event.emit("gate_breaks", 1)
	gates = gates.filter(func(g: Dictionary) -> bool: return not (g["broken"] and g["spawned"]))
	if pact == null or not pact.awakened:
		return
	if gates.filter(func(g: Dictionary) -> bool: return not g["broken"]).size() < MAX_OPEN and randf() < OPEN_CHANCE:
		open_gate()
	changed.emit()
	SaveGame.request_save()


## Opens a gate somewhere out from the player. Returns the gate.
func open_gate(rank: String = "", red: Variant = null) -> Dictionary:
	if rank == "":
		rank = rank_for_level(_player.leveling.level, randf())
	var from := _world.world_to_cell(_player.global_position)
	var cell := _world.generator.find_walkable_near(from + Vector2i(Vector2.from_angle(randf() * TAU) * randf_range(40.0, 110.0)), 20)
	var is_red: bool = red if red != null else (rank != "E" and randf() < RED_CHANCE)
	var gate := {"id": _next_id, "rank": rank, "cell": [cell.x, cell.y], "day": _day_night.day, "red": is_red, "broken": false, "spawned": false}
	_next_id += 1
	gates.append(gate)
	var where := Structures.compass(Vector2(cell - from))
	Voices.pact(get_tree(), "%s-RANK GATE" % rank, ["A gate has opened %d tiles to the %s." % [roundi(Vector2(cell - from).length()), where],
		"It breaks in %d days." % int(RANKS[rank]["days"])])
	changed.emit()
	SaveGame.request_save()
	return gate


## The Drowned Chapel, once, before the Pact.
func _chapel_check() -> void:
	var pact := _pact()
	if pact == null or pact.awakened or _player.leveling.level < ThePact.CHAPEL_LEVEL or _player.indoors:
		return
	if chapel_cell == Vector2i.MAX:
		var from := _world.world_to_cell(_player.global_position)
		chapel_cell = _world.generator.find_walkable_near(from + Vector2i(Vector2.from_angle(randf() * TAU) * 18.0), 12)
		Voices.inner(get_tree(), "Something has opened nearby. Crimson and gold, and very old. It feels like a door that wants to be found.", "chapel_seen")
		SaveGame.request_save()


func chapel_done() -> void:
	chapel_cell = Vector2i.MAX
	var tear: Variant = _tears.get("chapel")
	if is_instance_valid(tear):
		(tear as Node).queue_free()
	_tears.erase("chapel")
	SaveGame.request_save()


func _physics_process(delta: float) -> void:
	if _player == null:
		return
	_check_left -= delta
	if _check_left > 0.0:
		return
	_check_left = 1.0
	_chapel_check()
	var outside := not _player.indoors
	# The tears near the player, shown; the rest, not.
	var wanted := {}
	for gate: Dictionary in gates:
		var at := _world.cell_to_world(Vector2i(gate["cell"][0], gate["cell"][1]))
		var near := outside and at.distance_to(_player.global_position) < SHOW_DISTANCE
		if gate["broken"]:
			if near and not gate["spawned"]:
				_break_out(gate, at)
			continue
		if near:
			wanted[str(gate["id"])] = [gate, at]
	if chapel_cell != Vector2i.MAX and outside:
		var at := _world.cell_to_world(chapel_cell)
		if at.distance_to(_player.global_position) < SHOW_DISTANCE:
			wanted["chapel"] = [{}, at]
	for key: String in _tears.keys():
		if not wanted.has(key):
			if is_instance_valid(_tears[key]):
				(_tears[key] as Node).queue_free()
			_tears.erase(key)
	for key: String in wanted:
		if not _tears.has(key) or not is_instance_valid(_tears[key]):
			var tear := GateTear.new()
			tear.position = wanted[key][1]
			tear.setup(self, wanted[key][0])
			_player.get_parent().add_child(tear)
			_tears[key] = tear


## A broken gate's horde, out in the world.
func _break_out(gate: Dictionary, at: Vector2) -> void:
	gate["spawned"] = true
	var rank: String = gate["rank"]
	var level := gate_level(rank)
	var kinds := _theme(int(gate["id"]), bool(gate["red"]))
	for i in 4 + ORDER.find(rank) * 2:
		var spot := at + Vector2.from_angle(TAU * i / 8.0 + randf()) * randf_range(60.0, 220.0)
		_spawner.spawn_at(spot, level, Enemy.Rank.ELITE if i % 4 == 0 else Enemy.Rank.NORMAL, kinds.pick_random())
	if rank == "S":
		_spawn_monarch(at + Vector2(0, -80), level + 4, null)
	else:
		var leader := _spawner.spawn_at(at, level + 1, RANKS[rank]["leader"] if int(RANKS[rank]["leader"]) < Enemy.Rank.BOSS else Enemy.Rank.MINIBOSS, kinds[0])
		if leader:
			leader.custom_name = "%s Breaker" % EnemyDB.ENEMIES[kinds[0]]["name"]
			leader.display_name = leader.custom_name
	RingBurst.spawn(_player.get_parent(), at, RANKS[rank]["color"], 160.0)
	SaveGame.request_save()


## The three kinds of monster a gate holds.
func _theme(seed: int, red: bool) -> Array:
	if red:
		return RED_POOL.duplicate()
	var random := RandomNumberGenerator.new()
	random.seed = seed * 7919 + 13
	var level := _player.leveling.level + 4
	var options := POOL.filter(func(id: String) -> bool: return int(EnemyDB.ENEMIES[id]["min_level"]) <= level)
	var out: Array = []
	for i in 3:
		out.append(options[random.randi_range(0, options.size() - 1)])
	return out


# ------------------------------------------------------------------ inside

## Into a gate: a line of chambers going north, the gate's master in the
## last. `gate` is a world gate, or a private one from a key.
func enter(gate: Dictionary) -> void:
	if gate.is_empty():
		var pact := _pact()
		if pact:
			pact.enter_chapel()
		return
	var rank: String = gate["rank"]
	var red: bool = gate.get("red", false)
	var data: Dictionary = RANKS[rank]
	var level := gate_level(rank)
	var random := RandomNumberGenerator.new()
	random.seed = int(gate["id"]) * 31 + 5
	_instances.prepare_room()
	var room := Room.new()
	room.title = ("Red Gate (%s)" if red else "%s-Rank Gate") % rank
	room.wall_style = "rock" if red else data["walls"]
	room.gloom = 0.55 if red else 0.4 + ORDER.find(rank) * 0.06
	var count: int = data["rooms"]
	var floor_type: int = TerrainTiles.Type.SNOW if red else data["floor"]
	var rects: Array[Rect2i] = []
	for index in count:
		var center := Vector2i(random.randi_range(-3, 3), -index * 16)
		rects.append(Rect2i(center - Vector2i(7, 5), Vector2i(15, 11)))
	var floor_cells := {}
	for rect in rects:
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				floor_cells[Vector2i(x, y)] = floor_type
	for index in count - 1:
		var a := rects[index].get_center()
		var b := rects[index + 1].get_center()
		var at := a
		while at != b:
			at += Vector2i(0, signi(b.y - at.y)) if at.y != b.y else Vector2i(signi(b.x - at.x), 0)
			for k in range(-1, 2):
				floor_cells[at + Vector2i(k, 0)] = TerrainTiles.Type.PATH if not red else floor_type
	for cell: Vector2i in floor_cells.keys():
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if not floor_cells.has(cell + Vector2i(dx, dy)):
					room.cells[cell + Vector2i(dx, dy)] = TerrainTiles.Type.WALL
	for cell: Vector2i in floor_cells:
		room.cells[cell] = floor_cells[cell]
	room.entry = rects[0].get_center() + Vector2i(0, 3)
	room.build(_world.tile_set())
	_instances.enter(room)
	_inside = gate
	sealed = red
	var kinds := _theme(int(gate["id"]), red)
	# Monsters in every chamber but the first, the master in the last.
	for index in range(1, count):
		var rect := rects[index]
		var last := index == count - 1
		for i in random.randi_range(4, 6) + ORDER.find(rank):
			var spot := room.cell_position(rect.position + Vector2i(random.randi_range(2, rect.size.x - 3), random.randi_range(2, rect.size.y - 3)))
			var enemy := _spawner.spawn_at(spot, level, Enemy.Rank.ELITE if random.randf() < 0.12 + 0.03 * ORDER.find(rank) else Enemy.Rank.NORMAL, kinds[random.randi_range(0, kinds.size() - 1)])
			if enemy:
				room.enemies.append(enemy)
		for k in 2:
			var brazier := Prop.create_decor(Prop.Decor.BRAZIER if not red else Prop.Decor.LANTERN, room.cell_position(rect.position + Vector2i(1 + k * (rect.size.x - 3), 1)), 10.0)
			brazier.add_light(0.9, 1.6, (data["color"] as Color).lightened(0.3) if not red else Color(1.0, 0.4, 0.35))
			room.add_prop(brazier)
		if last:
			_spawn_master(room, rank, room.cell_position(rect.get_center() + Vector2i(0, -2)), level, kinds, red)
	for k in random.randi_range(4, 8):
		var rect := rects[random.randi_range(0, count - 1)]
		var piece: int = [Prop.Decor.BONES, Prop.Decor.RUBBLE, Prop.Decor.STONE_SHARD, Prop.Decor.CANDLES][random.randi_range(0, 3)]
		room.add_prop(Prop.create_decor(piece, room.cell_position(rect.position + Vector2i(random.randi_range(1, rect.size.x - 2), random.randi_range(1, rect.size.y - 2))), 0.0))
	if not red:
		room.add_prop(Prop.create(Prop.Art.PORTAL, room.cell_position(room.entry) + Vector2(0, 30), 0.0, "Leave the gate", func(_p: Player) -> void: _instances.leave()))
	if red:
		var haze := RedHaze.new()
		haze.player = _player
		haze.bounds = Rect2(room.cell_position(Vector2i(-12, -count * 16)) - room.position, Vector2(26, count * 16 + 12) * TerrainTiles.TILE_SIZE)
		room.add_child(haze)
		Voices.pact(get_tree(), "RED GATE", ["The way out has closed.", "Defeat the gate's master to leave."])
	else:
		Voices.pact(get_tree(), "%s-RANK GATE" % rank, ["Defeat the gate's master to close it."])


func _spawn_master(room: Room, rank: String, at: Vector2, level: int, kinds: Array, red: bool) -> void:
	var data: Dictionary = RANKS[rank]
	var master: Enemy = null
	if rank == "S":
		master = _spawn_monarch(at, level + 4, room)
	elif int(data["leader"]) >= Enemy.Rank.BOSS:
		var ids: Array = BossDB.BOSSES.keys()
		var boss_id: String = ids[randi() % ids.size()]
		master = _spawner.enemy_scene.instantiate()
		master.boss_id = boss_id
		master.position = at
		master.target = _player
		master.configure(level + 2, Enemy.Rank.BOSS, BossDB.BOSSES[boss_id]["monster"])
		_spawner.add_child(master)
		if rank == "A":
			master.health.max_health *= 1.5
			master.health.current = master.health.max_health
	else:
		master = _spawner.spawn_at(at, level + 2, data["leader"], kinds[0])
		if master:
			master.custom_name = ("Warden of the Red Gate" if red else "%s Gatekeeper" % EnemyDB.ENEMIES[kinds[0]]["name"])
			master.display_name = master.custom_name
	if master == null:
		return
	room.enemies.append(master)
	_master = master
	LightPillar.spawn(room, at, data["color"])
	master.died.connect(_on_master_fallen.bind(rank, red))


## A Monarch: the strongest form of a great boss, crowned and three times
## as hard to kill.
func _spawn_monarch(at: Vector2, level: int, room: Variant) -> Enemy:
	var choice: Array = MONARCHS[randi() % MONARCHS.size()]
	if not BossDB.BOSSES.has(choice[0]):
		choice = [BossDB.BOSSES.keys()[0], "The Nameless Monarch"]
	var monarch: Enemy = _spawner.enemy_scene.instantiate()
	monarch.boss_id = choice[0]
	monarch.custom_name = choice[1]
	monarch.position = at
	monarch.target = _player
	monarch.configure(level, Enemy.Rank.BOSS, BossDB.BOSSES[choice[0]]["monster"])
	_spawner.add_child(monarch)
	monarch.health.max_health *= 3.0
	monarch.health.current = monarch.health.max_health
	monarch.set_meta("monarch", choice[1])
	if room == null:
		monarch.died.connect(_on_monarch_fallen.bind(choice[1]))
	Voices.heart(get_tree(), "%s has come." % choice[1], "A Monarch walks.")
	Events.codex_event.emit("monarchs_seen", 1)
	return monarch


func _on_monarch_fallen(_enemy: Enemy, title: String) -> void:
	monarchs_fallen.append(title)
	Events.codex_event.emit("monarchs", 1)
	Voices.heart(get_tree(), "%s has fallen." % title, "The world is quieter for it.")
	_player.inventory.add(Item.create("gate_key_s"))
	SaveGame.request_save()


func _on_master_fallen(enemy: Enemy, rank: String, red: bool) -> void:
	sealed = false
	var room := _instances.room
	cleared += 1
	Events.codex_event.emit("gates", 1)
	if red:
		Events.codex_event.emit("red_gates", 1)
	if rank == "S" and enemy.has_meta("monarch"):
		_on_monarch_fallen(enemy, str(enemy.get_meta("monarch")))
	var at := enemy.global_position
	var level := gate_level(rank)
	var rank_index := ORDER.find(rank)
	if _loot:
		_loot.drop_gold(roundi((60 + level * 8) * (1.0 + rank_index * 0.6) * (1.6 if red else 1.0)), at)
		for i in 1 + rank_index / 2 + (1 if red else 0):
			_loot.drop_item(LootGenerator.make_equipment(level, clampi(1 + rank_index, 1, 5)), at + Vector2(randf_range(-50, 50), randf_range(-30, 30)))
		if randf() < 0.3 + 0.1 * rank_index:
			_loot.drop_item(Item.create("gate_key_" + rank.to_lower()), at + Vector2(0, 20))
	gates = gates.filter(func(g: Dictionary) -> bool: return g["id"] != _inside.get("id", -1))
	_inside = {}
	_master = null
	Voices.pact(get_tree(), "GATE CLEARED", ["The %s-rank gate closes behind you." % rank, "Gates cleared: %d" % cleared])
	if room:
		room.add_prop(Prop.create(Prop.Art.PORTAL, at + Vector2(0, 40), 0.0, "Step out of the gate", func(_p: Player) -> void: _instances.leave()))
	changed.emit()
	SaveGame.request_save()


func _on_left() -> void:
	sealed = false
	_inside = {}
	_master = null


## A gate key: a private gate of its rank, here and now.
func use_key(rank: String) -> String:
	if _player.indoors:
		return "A key opens a gate only under the open sky."
	var pact := _pact()
	if pact == null or not pact.awakened:
		return "The key is cold and does nothing. The Pact is not yours."
	var gate := {"id": 100000 + _next_id, "rank": rank, "cell": [0, 0], "day": _day_night.day, "red": false, "broken": false, "spawned": false}
	_next_id += 1
	Events.codex_event.emit("keys_used", 1)
	enter(gate)
	return ""


func save_data() -> Dictionary:
	return {"gates": gates.duplicate(true), "cleared": cleared, "monarchs_fallen": monarchs_fallen, "chapel": [chapel_cell.x, chapel_cell.y], "next_id": _next_id}


func load_data(data: Dictionary) -> void:
	gates = data.get("gates", []) if data.get("gates") is Array else []
	cleared = int(data.get("cleared", 0))
	monarchs_fallen = data.get("monarchs_fallen", []) if data.get("monarchs_fallen") is Array else []
	var chapel: Variant = data.get("chapel", [])
	chapel_cell = Vector2i(int(chapel[0]), int(chapel[1])) if chapel is Array and (chapel as Array).size() == 2 else Vector2i.MAX
	_next_id = int(data.get("next_id", 1))
	for tear: Variant in _tears.values():
		if is_instance_valid(tear):
			(tear as Node).queue_free()
	_tears.clear()


## A gate in the world: a tall tear of light standing on the ground, its
## rim rippling in the rank's colour, its heart dark and turning, sparks
## drifting off it, the rank's letter floating over it. A red gate has a
## crimson rim and a heart of drifting snow. The Drowned Chapel's tear is
## crimson and gold, with a question mark for a rank.
class GateTear:
	extends Prop

	var gate: Dictionary
	var _gates: Gates
	var _color := Color.WHITE
	var _rim := Color.WHITE
	var _letter := "?"

	func setup(gates_node: Gates, gate_data: Dictionary) -> void:
		_gates = gates_node
		gate = gate_data
		reach = 80.0
		if gate.is_empty():
			_color = Color("e8bc4a")
			_rim = Color("c83a48")
			_letter = "?"
			prompt_text = "Step into the crimson gate"
		else:
			_color = Gates.RANKS[gate["rank"]]["color"]
			_rim = Color("e0303a") if gate["red"] else _color
			_letter = gate["rank"]
			prompt_text = "Enter the %s-rank gate" % _letter
		on_interact = func(_p: Player) -> void: _gates.enter(gate)

	func _ready() -> void:
		var light := PointLight2D.new()
		light.texture = Prop.LIGHT
		light.color = _rim
		light.energy = 0.9
		light.texture_scale = 2.2
		light.position = Vector2(0, -50)
		add_child(light)

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var t := Time.get_ticks_msec() / 1000.0
		# A scorch on the ground under it.
		draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.4))
		draw_circle(Vector2.ZERO, 34.0, Color(0, 0, 0, 0.35))
		draw_set_transform(Vector2.ZERO)
		# The tear: rows of an upright oval, a ragged rim that ripples.
		var top := -104.0
		var height := 100.0
		for row in int(height):
			var y := top + row
			var share := float(row) / height
			var half := 22.0 * sqrt(maxf(1.0 - pow((share - 0.5) * 2.0, 2.0), 0.0))
			var wobble := roundf(sin(t * 4.0 + row * 0.35) * 1.5)
			var left := roundf(-half + wobble)
			var right := roundf(half + wobble)
			if right - left < 2.0:
				continue
			draw_rect(Rect2(left, y, right - left, 1), Color(0.03, 0.02, 0.06, 0.95))
			# Swirling bands inside.
			var band := fmod(row * 0.13 + t * 1.2, 1.0)
			if band < 0.18:
				draw_rect(Rect2(left + 3.0, y, maxf(right - left - 6.0, 0.0), 1), Color(_color, 0.22))
			draw_rect(Rect2(left - 2.0, y, 3, 1), _rim)
			draw_rect(Rect2(right - 1.0, y, 3, 1), _rim)
			draw_rect(Rect2(left - 3.0, y, 1, 1), Color(_rim.lightened(0.4), 0.6))
		# Snow in a red gate; sparks off any gate.
		for k in 12:
			var phase := fmod(t * 0.35 + k / 12.0, 1.0)
			var spot := Vector2(roundf(sin(k * 3.1 + t * 0.7) * 30.0), roundf(top + height - phase * (height + 30.0)))
			var colour := Color(0.95, 0.97, 1.0) if not gate.is_empty() and gate.get("red", false) else _color.lightened(0.3)
			draw_rect(Rect2(spot, Vector2(2, 2) if k % 3 == 0 else Vector2(1, 1)), Color(colour, 0.85 * (1.0 - phase)))
		# The rank's letter over it.
		var font := UITheme.bold()
		var bob := roundf(sin(t * 2.0) * 2.0)
		draw_string_outline(font, Vector2(-20, top - 10.0 + bob), _letter, HORIZONTAL_ALIGNMENT_CENTER, 40.0, 24, 5, Color(0, 0, 0, 0.85))
		draw_string(font, Vector2(-20, top - 10.0 + bob), _letter, HORIZONTAL_ALIGNMENT_CENTER, 40.0, 24, _rim.lightened(0.2))


## Inside a red gate: a crimson cast over the snow, and snow coming down
## out of a sky that is not there, flake by flake round the player.
class RedHaze:
	extends Node2D

	var bounds := Rect2()
	var player: Node2D
	var _flakes: Array = []

	func _ready() -> void:
		z_index = 5
		for k in 140:
			_flakes.append([Vector2(randf_range(-700, 700), randf_range(-420, 420)), randf_range(18.0, 46.0), randf_range(0.0, TAU), 1 + int(randf() < 0.25)])

	func _process(delta: float) -> void:
		for flake: Array in _flakes:
			var at: Vector2 = flake[0]
			at.y += float(flake[1]) * delta
			at.x += sin(float(flake[2]) + at.y * 0.02) * 8.0 * delta
			if at.y > 420.0:
				at.y = -420.0
			flake[0] = at
		queue_redraw()

	func _draw() -> void:
		draw_rect(bounds, Color(0.55, 0.04, 0.08, 0.2))
		var middle := player.global_position - global_position if is_instance_valid(player) else Vector2.ZERO
		for flake: Array in _flakes:
			var size: int = flake[3]
			draw_rect(Rect2((middle + (flake[0] as Vector2)).round(), Vector2(size, size)), Color(1.0, 0.92, 0.92, 0.8))
