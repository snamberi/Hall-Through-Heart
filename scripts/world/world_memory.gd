class_name WorldMemory
extends Node2D
## The world remembers what was done in it, and what it heard.
##
## Each patch of land (AREA tiles across) keeps count of trees felled,
## blood spilled, magic cast and travellers fallen; each tile, how often it
## is walked; and the places where great beasts died are marked. From that:
##   - woods felled again and again leave stumps, then open clearings;
##   - ground walked often wears to a pale track, then a dirt trail;
##   - where a boss fell, the ground stays scarred and strange flowers grow;
##   - where the player has died three times or more, a Sorrow Bloom grows,
##     pale flowers that weep light (kneel there once a day for a lesson);
##   - the land keeps the sound of what happened: blades ring faintly where
##     many fought, axes knock in felled woods, chimes hang where magic was
##     cast, and old ruins murmur scraps of talk;
##   - monsters gather where blood was spilled; peaceful beasts keep away;
##   - villagers speak of what happened near their village.

const AREA := 8
const CLEARING := 8
const STUMPS := 3
const WORN := 12
const TRAIL := 30
const SORROW := 3
const BLOODY := 40
const ECHOES := [
	"...bring the bread in before the rain...", "...he swore he saw lights on the hill...", "...hush, the little one's asleep...",
	"...three coins for the lot, and not a copper more...", "...when the bells stop, run...", "...did you bar the door?...",
	"...she isn't coming back, is she...", "...sing it again, the one about the river...",
]

## "x,y" of an area -> {"chops", "kills", "magic", "deaths"}
var areas: Dictionary = {}
## "x,y" of a tile -> times walked onto
var trails: Dictionary = {}
## [{"cell": [x, y], "boss": id, "color": html}]
var scars: Array = []
## structure key -> the day its camp was found emptied (it grows over after)
var abandoned: Dictionary = {}

var _player: Player
var _world: World
var _last_tile := Vector2i(1 << 30, 0)
var _echo_left := 6.0
## Nodes shown for scars and blooms, by "kind:x,y".
var _shown: Dictionary = {}


func _ready() -> void:
	SaveGame.register("memory", self)


func setup(player: Player, world: World) -> void:
	_player = player
	_world = world
	Events.enemy_killed.connect(func(info: Dictionary) -> void:
		note(_world.world_to_cell(info.get("position", _player.global_position)), "kills"))
	# Spells leave a ringing in the air that lingers where they were cast.
	Events.codex_event.connect(func(stat: String, _amount: int) -> void:
		if stat == "spells_cast" and not _player.indoors:
			note(_world.world_to_cell(_player.global_position), "magic"))
	Events.damage_dealt.connect(func(kind: String, _amount: float) -> void:
		if kind == "magic" and not _player.indoors and randf() < 0.25:
			note(_world.world_to_cell(_player.global_position), "magic"))
	Events.player_died.connect(func(_xp: int) -> void:
		if not _player.indoors:
			note(_world.world_to_cell(_player.global_position), "deaths")
			_show_near(_player.global_position))
	Events.boss_defeated.connect(boss_fell)
	_world.chunk_built.connect(func(chunk: Vector2i) -> void:
		_show_near(_world.cell_to_world(chunk * World.CHUNK_SIZE + Vector2i(World.CHUNK_SIZE / 2, World.CHUNK_SIZE / 2))))


## A boss has died where the player stands: the ground there stays scarred.
func boss_fell(boss_id: String) -> void:
	if _player.indoors:
		return
	var cell := _world.world_to_cell(_player.global_position)
	var color: Color = BossDB.BOSSES.get(boss_id, {}).get("color", Color(0.8, 0.3, 1.0))
	scars.append({"cell": [cell.x, cell.y], "boss": boss_id, "color": color.to_html(false)})
	_show_near(_player.global_position)
	SaveGame.request_save()


static func area_of(cell: Vector2i) -> Vector2i:
	return Vector2i((Vector2(cell) / AREA).floor())


static func _key(v: Vector2i) -> String:
	return "%d,%d" % [v.x, v.y]


## Counts one more of `what` in the area holding `cell`.
func note(cell: Vector2i, what: String) -> void:
	var key := _key(area_of(cell))
	var area: Dictionary = areas.get(key, {})
	area[what] = int(area.get(what, 0)) + 1
	areas[key] = area
	if what in ["chops", "deaths"]:
		SaveGame.request_save()


func count(cell: Vector2i, what: String) -> int:
	return int((areas.get(_key(area_of(cell)), {}) as Dictionary).get(what, 0))


## How worn a tile is: 0 untouched, 1 worn pale, 2 a dirt trail.
func wear(cell: Vector2i) -> int:
	var walked := int(trails.get(_key(cell), 0))
	return 2 if walked >= TRAIL else 1 if walked >= WORN else 0


## Days since a camp was found emptied (0 the first time it is seen so).
func days_abandoned(key: String, today: int) -> int:
	if not abandoned.has(key):
		abandoned[key] = today
		SaveGame.request_save()
	return today - int(abandoned[key])


## How much keener monsters' senses are here, for the magic that still
## hums in the air (1 .. 1.5).
func harmonics(cell: Vector2i) -> float:
	return 1.0 + minf(count(cell, "magic") / 60.0, 0.5)


## Whether a Sorrow Bloom grows on this tile or right beside it (nothing
## else grows there).
func is_sorrow_ground(cell: Vector2i) -> bool:
	if count(cell, "deaths") < SORROW:
		return false
	var center := area_of(cell) * AREA + Vector2i(AREA / 2, AREA / 2)
	return Vector2(cell - center).length() <= 2.0


## How many more monsters stir here for the blood spilled nearby (1 .. 1.4).
func violence(cell: Vector2i) -> float:
	var kills := 0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			kills += int((areas.get(_key(area_of(cell) + Vector2i(dx, dy)), {}) as Dictionary).get("kills", 0))
	return 1.0 + minf(kills / 150.0, 0.4)


func _physics_process(delta: float) -> void:
	if _player == null or _world == null or _player.indoors or _player.is_dead():
		return
	# Footsteps wear the ground (only on foot, on open land).
	var tile := _world.world_to_cell(_player.global_position)
	if tile != _last_tile:
		_last_tile = tile
		if not _player.flying and _player.mount_id == "" and _world.generator.is_dry_land(tile):
			var key := _key(tile)
			trails[key] = mini(int(trails.get(key, 0)) + 1, 99)
	_echo_left -= delta
	if _echo_left <= 0.0:
		_echo_left = randf_range(7.0, 14.0)
		_echo(tile)


## What the land remembers, as faint sound (and in ruins, faint words).
func _echo(tile: Vector2i) -> void:
	if count(tile, "kills") + count(tile + Vector2i(AREA, 0), "kills") >= BLOODY:
		Audio.play_note("swing" if randf() < 0.6 else "hit", randf_range(0.6, 0.85), -24.0)
	elif count(tile, "chops") >= CLEARING:
		Audio.play_note("chop", randf_range(0.7, 0.9), -24.0)
	elif count(tile, "magic") >= 30:
		Audio.play_note("pickup", [1.0, 1.26, 1.5][randi() % 3], -22.0)
	var structures: Node = get_parent().get_node_or_null("Structures")
	if structures and structures.has_method("site_for"):
		var site: Dictionary = structures.site_for(_world.cell_to_chunk(tile))
		if not site.is_empty() and site["kind"] in ["ruin", "graveyard", "watchtower", "library"] \
				and Vector2(tile).distance_to(Vector2(site["cell"] as Vector2i)) < 8.0 and randf() < 0.5:
			DamageNumber.spawn_text(get_parent(), _world.cell_to_world(site["cell"]) + Vector2(randf_range(-60, 60), -20), ECHOES.pick_random(), Color(0.75, 0.8, 0.95, 0.7), 12)


## Puts scars and Sorrow Blooms in the world near a place, once each.
func _show_near(at: Vector2) -> void:
	var here := _world.world_to_cell(at)
	for scar: Dictionary in scars:
		var cell := Vector2i(int(scar["cell"][0]), int(scar["cell"][1]))
		var key := "scar:" + _key(cell)
		if Vector2(cell).distance_to(Vector2(here)) < World.CHUNK_SIZE * 2 and not _valid(key):
			var node := BossScar.new()
			node.color = Color(str(scar["color"]))
			node.position = _world.cell_to_world(cell)
			node.add_to_group("scenery")
			_shown[key] = node
			add_child(node)
	for key: String in areas:
		if int((areas[key] as Dictionary).get("deaths", 0)) < SORROW:
			continue
		var parts := key.split(",")
		var cell := Vector2i(int(parts[0]), int(parts[1])) * AREA + Vector2i(AREA / 2, AREA / 2)
		var shown := "sorrow:" + key
		if Vector2(cell).distance_to(Vector2(here)) < World.CHUNK_SIZE * 2 and not _valid(shown):
			var bloom := SorrowBloom.create(_world.cell_to_world(cell), key)
			bloom.add_to_group("scenery")
			_shown[shown] = bloom
			add_child(bloom)


func _valid(key: String) -> bool:
	return _shown.has(key) and is_instance_valid(_shown[key])


## What villagers say about things that happened near them (up to three).
func rumours(center: Vector2i) -> Array[String]:
	var out: Array[String] = []
	for key: String in areas:
		var area: Dictionary = areas[key]
		var parts := key.split(",")
		var cell := Vector2i(int(parts[0]), int(parts[1])) * AREA
		if Vector2(cell - center).length() > 140.0:
			continue
		var where := _direction(cell - center)
		if int(area.get("chops", 0)) >= CLEARING:
			out.append("Someone has been felling the woods to the %s. There's open sky over a clearing there now." % where)
		if int(area.get("deaths", 0)) >= SORROW:
			out.append("They say a traveller fell to the %s, again and again. Pale flowers weep there now." % where)
		if int(area.get("kills", 0)) >= BLOODY:
			out.append("There's been killing to the %s. At night you can hear blades out there, and no one fighting." % where)
	for scar: Dictionary in scars:
		var cell := Vector2i(int(scar["cell"][0]), int(scar["cell"][1]))
		if Vector2(cell - center).length() < 160.0:
			var name: String = BossDB.BOSSES.get(scar["boss"], {}).get("name", "a great beast")
			out.append("%s fell to the %s. Nothing grows there but strange flowers." % [name, _direction(cell - center)])
	var worn := 0
	for key: String in trails:
		if int(trails[key]) >= TRAIL:
			worn += 1
	if worn > 40:
		out.append("You've walked so much round here the grass has worn to a track.")
	out.shuffle()
	return out.slice(0, 3)


static func _direction(offset: Vector2i) -> String:
	var angle := Vector2(offset).angle()
	var names := ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"]
	return names[posmod(roundi(angle / (PI / 4.0)), 8)]


func save_data() -> Dictionary:
	# Keep the trail map small: only tiles walked more than a few times.
	var kept := {}
	for key: String in trails:
		if int(trails[key]) >= 3:
			kept[key] = trails[key]
	return {"areas": areas, "trails": kept, "scars": scars, "abandoned": abandoned}


func load_data(data: Dictionary) -> void:
	var saved: Variant = data.get("areas", {})
	areas = saved if saved is Dictionary else {}
	saved = data.get("trails", {})
	trails = saved if saved is Dictionary else {}
	saved = data.get("scars", [])
	scars = saved if saved is Array else []
	saved = data.get("abandoned", {})
	abandoned = saved if saved is Dictionary else {}


## Where a boss died: scorched ground with glowing cracks in its colour, and
## a ring of flowers that grow nowhere else.
class BossScar:
	extends Node2D

	var color := Color(0.8, 0.3, 1.0)

	func _ready() -> void:
		z_index = -8

	func _process(_delta: float) -> void:
		queue_redraw()

	## A flat oval, row by row, so its edge stays on whole pixels.
	func _oval(rx: float, ry: float, tint: Color) -> void:
		for y in range(-int(ry), int(ry) + 1):
			var half := floorf(rx * sqrt(maxf(1.0 - float(y * y) / (ry * ry), 0.0)))
			draw_rect(Rect2(-half, y, half * 2.0, 1.0), tint)

	func _draw() -> void:
		var t := Time.get_ticks_msec() / 1000.0
		_oval(60.0, 36.0, Color(0.06, 0.04, 0.06, 0.55))
		_oval(40.0, 24.0, Color(0.02, 0.01, 0.02, 0.5))
		var glow := 0.55 + 0.25 * sin(t * 1.7)
		# Cracks run out from the middle in short straight steps.
		for i in 7:
			var a := TAU * i / 7.0 + 0.4
			var at := (Vector2.from_angle(a) * 8.0 * Vector2(1, 0.6)).round()
			for step in 9:
				var bend := a + (0.25 if step % 3 == 1 else -0.1)
				var next := (at + Vector2.from_angle(bend) * 5.0 * Vector2(1, 0.6)).round()
				var tint := Color(color, glow * (1.0 - step / 12.0))
				var from := at
				while from != next:
					draw_rect(Rect2(from, Vector2(2, 1)), tint)
					from += (next - from).sign()
				at = next
		# Flowers that grow nowhere else, in a ring round the scorch.
		for i in 12:
			var a := TAU * i / 12.0
			var at := (Vector2.from_angle(a) * 66.0 * Vector2(1, 0.62)).round()
			draw_rect(Rect2(at + Vector2(-1, -6), Vector2(2, 6)), Color("3a5a3a"))
			draw_rect(Rect2(at + Vector2(-3, -9), Vector2(6, 4)), color.lightened(0.35))
			draw_rect(Rect2(at + Vector2(-1, -8), Vector2(2, 2)), Color(1, 1, 1, 0.85))
			draw_rect(Rect2(at + Vector2(-4, -8), Vector2(1, 2)), color.darkened(0.2))
			draw_rect(Rect2(at + Vector2(3, -8), Vector2(1, 2)), color.darkened(0.2))


## Pale flowers where the player has fallen again and again, weeping light.
## Kneeling there once a day teaches: a while of keener blows.
class SorrowBloom:
	extends Node2D

	var key := ""

	static func create(at: Vector2, area_key: String) -> SorrowBloom:
		var bloom := SorrowBloom.new()
		bloom.position = at
		bloom.key = area_key
		var prop := Prop.create(Prop.Art.PILLAR, Vector2.ZERO, 0.0, "Kneel at the Sorrow Bloom", func(player: Player) -> void: bloom._kneel(player))
		prop.sprite().visible = false
		bloom.add_child(prop)
		var light := FlickerLight.new()
		light.texture = Prop.LIGHT
		light.texture_scale = 1.4
		light.energy = 0.55
		light.base_energy = 0.55
		light.base_scale = 1.4
		light.color = Color(0.7, 0.85, 1.0)
		light.position.y = -10.0
		bloom.add_child(light)
		return bloom

	func _kneel(player: Player) -> void:
		var day: int = get_tree().get_first_node_in_group("world").get_parent().get_node("DayNight").day
		if player.has_meta("sorrow_day") and int(player.get_meta("sorrow_day")) == day:
			Events.announcement.emit("", "The flowers have nothing more to say today.")
			return
		player.set_meta("sorrow_day", day)
		Events.codex_event.emit("sorrow", 1)
		player.buffs.add("sorrows_lesson", "Sorrow's Lesson", 600.0, {"physical_damage": {"percent": 0.12}, "critical_chance": {"flat": 0.04}})
		Events.announcement.emit("SORROW'S LESSON", "You remember how you fell here. You will not fall the same way again.")

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var t := Time.get_ticks_msec() / 1000.0
		# A faint pool of pale light on the ground, row by row.
		var pulse := 0.18 + 0.06 * sin(t * 1.3)
		for y in range(-16, 17):
			var half := floorf(48.0 * sqrt(1.0 - y * y / 272.0))
			draw_rect(Rect2(-half, y - 4, half * 2.0, 1.0), Color(0.6, 0.75, 1.0, pulse * (1.0 - absf(y) / 18.0)))
		for i in 15:
			var a := TAU * i / 15.0 + 0.3
			var at := (Vector2.from_angle(a) * (6.0 + (i % 3) * 13.0) * Vector2(1, 0.55)).round()
			var tall := 12.0 + (i % 4) * 2.0
			# A stem that arches over, and a bell of a flower hanging from it.
			var flip := 1.0 if i % 2 == 0 else -1.0
			draw_rect(Rect2(at + Vector2(0, -tall), Vector2(1, tall)), Color("5a7a8a"))
			draw_rect(Rect2(at + Vector2(minf(flip, 0.0) * 3.0 + (1.0 if flip > 0 else 0.0), -tall - 1), Vector2(3, 1)), Color("5a7a8a"))
			draw_rect(Rect2(at + Vector2(flip * 4.0, -tall), Vector2(1, 1)), Color("5a7a8a"))
			var bell := at + Vector2(flip * 4.0, -tall + 1)
			draw_rect(Rect2(bell + Vector2(-1, 0), Vector2(3, 1)), Color("e6efff"))
			draw_rect(Rect2(bell + Vector2(-2, 1), Vector2(5, 2)), Color("cfe0ff"))
			draw_rect(Rect2(bell + Vector2(-2, 3), Vector2(5, 1)), Color("a9c2f0"))
			draw_rect(Rect2(bell + Vector2(-3, 4), Vector2(1, 1)), Color("8aa6dc"))
			draw_rect(Rect2(bell + Vector2(3, 4), Vector2(1, 1)), Color("8aa6dc"))
			draw_rect(Rect2(bell + Vector2(-1, 1), Vector2(1, 1)), Color(1, 1, 1, 0.9))
			bell += Vector2(0, -1)
			# A tear of light falls from the bell now and then.
			var drop := fmod(t * 0.6 + i * 0.37, 1.0)
			draw_rect(Rect2(bell + Vector2(1, 5 + roundf(drop * 9.0)), Vector2(1, 2)), Color(0.85, 0.93, 1.0, 1.0 - drop))
