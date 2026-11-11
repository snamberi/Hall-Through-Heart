class_name Instances
extends Node2D
## Takes the player into rooms off the world map (caves, void arenas, house
## interiors) and brings them back to where they were.

signal entered(room: Room)
signal left

const T := TerrainTiles.Type
const CAVE_SIZE := Vector2i(34, 24)
const CAVE_MONSTERS: Array[String] = ["carrion_bat", "bog_slime", "thorn_stalker", "rot_hound", "crag_golem", "bone_archer", "spore_shambler", "ash_wraith"]
## Each cave rolls a theme: who lives there, what the floor is, what lies
## about, how much ore, and who guards it when it is a lair.
const CAVE_THEMES := {
	"cavern": {"title": "Cavern", "floor": T.CAVE_FLOOR, "monsters": ["carrion_bat", "rot_hound", "crag_golem", "bone_archer", "husk"], "boss": "crag_golem",
		"decor": [Prop.Decor.RUBBLE, Prop.Decor.BONES, Prop.Decor.CRATE], "ore": 1.0, "light": Color(1.0, 0.8, 0.55)},
	"roost": {"title": "Bat Roost", "floor": T.CAVE_FLOOR, "monsters": ["carrion_bat", "carrion_bat", "carrion_bat", "rot_hound"], "boss": "carrion_bat",
		"decor": [Prop.Decor.BONES, Prop.Decor.BONES, Prop.Decor.RUBBLE], "ore": 0.6, "light": Color(0.75, 0.7, 1.0), "count": 1.4},
	"grotto": {"title": "Fungal Grotto", "floor": T.FUNGAL, "monsters": ["spore_shambler", "bog_slime", "bog_slime"], "boss": "spore_shambler",
		"decor": [Prop.Decor.RUBBLE, Prop.Decor.BONES], "ore": 0.6, "herbs": 10, "light": Color(0.55, 1.0, 0.75)},
	"mine": {"title": "Abandoned Mine", "floor": T.CAVE_FLOOR, "monsters": ["crag_golem", "husk", "bone_archer"], "boss": "crag_golem",
		"decor": [Prop.Decor.CRATE, Prop.Decor.BARREL, Prop.Decor.LANTERN, Prop.Decor.FENCE], "ore": 2.0, "light": Color(1.0, 0.85, 0.5)},
	"ossuary": {"title": "Ossuary", "floor": T.ASH, "monsters": ["bone_archer", "husk", "rot_cultist", "ash_wraith"], "boss": "rot_cultist",
		"decor": [Prop.Decor.BONES, Prop.Decor.CANDLES, Prop.Decor.STATUE, Prop.Decor.BONES], "ore": 0.5, "light": Color(0.9, 0.95, 1.0)},
	"ember": {"title": "Ember Depths", "floor": T.CINDER, "monsters": ["ember_wisp", "ash_wraith", "crag_golem"], "boss": "ember_wisp",
		"decor": [Prop.Decor.BRAZIER, Prop.Decor.RUBBLE, Prop.Decor.OBELISK], "ore": 1.3, "light": Color(1.0, 0.5, 0.25)},
	"flooded": {"title": "Flooded Cave", "floor": T.CAVE_FLOOR, "water": true, "monsters": ["bog_slime", "rot_hound", "thorn_stalker"], "boss": "bog_slime",
		"decor": [Prop.Decor.RUBBLE, Prop.Decor.BARREL], "ore": 0.8, "light": Color(0.6, 0.85, 1.0)},
}
const VOID_MONSTERS: Array[String] = ["ash_wraith", "rot_cultist", "ember_wisp", "husk", "bone_archer"]
const ARENA_RADIUS := 8

var room: Room

var _player: Player
var _world: World
var _spawner: EnemySpawner
var _loot: Node2D
var _return_position := Vector2.ZERO
## Void arena state.
var _waves_total := 0
var _wave := 0
var _next_wave_in := -1.0
var _arena_level := 1
var _on_cleared: Callable


func setup(player: Player, world: World, spawner: EnemySpawner, loot: Node2D) -> void:
	_player = player
	_world = world
	_spawner = spawner
	_loot = loot


func is_inside() -> bool:
	return room != null


## Where the player will stand again after leaving.
func return_position() -> Vector2:
	return _return_position


## Moves the player into a built room.
func enter(new_room: Room) -> void:
	if room == null:
		_return_position = _player.global_position
	else:
		_discard_room()
	room = new_room
	add_child(room)
	_world.target = null
	_player.indoors = true
	(get_parent().get_node("DayNight") as DayNight).indoors = true
	_player.global_position = room.cell_position(room.entry)
	_player.velocity = Vector2.ZERO
	_player.camera.reset_smoothing()
	Events.announcement.emit(room.title, "")
	entered.emit(room)


## Returns the player to the world. Pass a position to come out somewhere
## other than where they went in (after dying, say).
func leave(at: Variant = null) -> void:
	if room == null:
		return
	_discard_room()
	_waves_total = 0
	_player.indoors = false
	(get_parent().get_node("DayNight") as DayNight).indoors = false
	_player.global_position = at if at != null else _return_position
	_player.velocity = Vector2.ZERO
	_world.target = _player
	_world.load_around_now(_player.global_position)
	_player.camera.reset_smoothing()
	left.emit()


# --- caves

## A cavern grown from a seed: winding floor, ore, monsters, and a chest at
## the far end. `lair` adds a mini-boss guarding the chest.
func enter_cave(cave_seed: int, level: int, lair: bool, on_chest: Callable) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = cave_seed
	var theme_ids: Array = CAVE_THEMES.keys()
	var theme: Dictionary = CAVE_THEMES[theme_ids[random.randi_range(0, theme_ids.size() - 1)]]
	var cave := Room.new()
	cave.title = theme["title"] + (" (Lair)" if lair else "")
	var size := Vector2i(random.randi_range(30, 44), random.randi_range(20, 30))
	var open := _grow_cave(random, size)
	var water := {}
	if theme.get("water", false):
		for cell: Vector2i in open:
			if (sin(cell.x * 0.45 + cave_seed % 7) + cos(cell.y * 0.5 + cave_seed % 5)) > 1.15:
				water[cell] = true
	for y in range(-1, size.y + 1):
		for x in range(-1, size.x + 1):
			var cell := Vector2i(x, y)
			if not open.has(cell):
				cave.cells[cell] = T.WALL
			elif water.has(cell):
				cave.cells[cell] = T.SHALLOW_WATER
			else:
				# Patches of plain stone break up the theme's floor.
				cave.cells[cell] = theme["floor"] if theme["floor"] == T.CAVE_FLOOR or random.randf() < 0.94 else T.CAVE_FLOOR
	# Come in at the lowest, leftmost open cell.
	var floor_cells: Array = open.keys()
	floor_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y - a.x > b.y - b.x)
	cave.entry = floor_cells[0]
	cave.cells[cave.entry] = T.CAVE_FLOOR
	cave.build(_world.tile_set())
	enter(cave)
	cave.add_prop(Prop.create(Prop.Art.LADDER, cave.cell_position(cave.entry) + Vector2(0, -30), 0.0, "Climb out", func(_p: Player) -> void: leave()))

	var far := cave.floor_by_distance().filter(func(cell: Vector2i) -> bool: return not water.has(cell))
	var used := {cave.entry: true}
	var free_cell := func() -> Vector2i:
		for attempt in 20:
			var cell: Vector2i = far[random.randi_range(0, far.size() - 1)]
			if not used.has(cell):
				used[cell] = true
				return cell
		return far[random.randi_range(0, far.size() - 1)]
	# Ore is richer underground than on the surface above.
	for i in roundi(random.randi_range(6, 9) * theme["ore"]):
		var cell: Vector2i = free_cell.call()
		var id := GatherDB.pick("ore", T.CAVE_FLOOR, level + 8, random)
		if id != "":
			cave.add_prop(ResourceNode.create(id, cell, cave.cell_position(cell)))
	for i in theme.get("herbs", 0):
		var cell: Vector2i = free_cell.call()
		var herb := "glowshroom" if level >= 18 else "poison_mushroom"
		if GatherDB.RESOURCES.has(herb):
			cave.add_prop(ResourceNode.create(herb, cell, cave.cell_position(cell)))
	# Scenery and glowing lights so each cave reads differently.
	var decor: Array = theme["decor"]
	for i in random.randi_range(10, 16):
		var cell: Vector2i = free_cell.call()
		var piece: int = decor[random.randi_range(0, decor.size() - 1)]
		var solid := 0.0 if piece in [Prop.Decor.BONES, Prop.Decor.RUBBLE, Prop.Decor.CANDLES] else 10.0
		var prop := Prop.create_decor(piece, cave.cell_position(cell) + Vector2(random.randf_range(-8, 8), random.randf_range(-8, 8)), solid)
		if piece in [Prop.Decor.LANTERN, Prop.Decor.CANDLES, Prop.Decor.BRAZIER]:
			prop.add_light(0.8, 1.3)
		cave.add_prop(prop)
	for i in random.randi_range(4, 7):
		var glow := PointLight2D.new()
		glow.texture = Prop.LIGHT
		glow.texture_scale = random.randf_range(1.4, 2.4)
		glow.energy = 0.55
		glow.color = theme["light"]
		glow.position = cave.cell_position(far[random.randi_range(0, far.size() - 1)]) - cave.position
		cave.add_child(glow)
	# Monsters: the theme's own, more in bigger caves, a few Elites.
	var roomy := far.slice(0, far.size() * 2 / 3)
	var options: Array = (theme["monsters"] as Array).filter(func(id: String) -> bool: return EnemyDB.ENEMIES[id]["min_level"] <= level + 3)
	if options.is_empty():
		options = CAVE_MONSTERS.filter(func(id: String) -> bool: return EnemyDB.ENEMIES[id]["min_level"] <= level + 2)
	var count := roundi(random.randi_range(6, 9) * theme.get("count", 1.0) * (size.x * size.y) / 960.0)
	for i in count:
		var cell: Vector2i = roomy[random.randi_range(0, roomy.size() - 1)]
		var rank := Enemy.Rank.ELITE if random.randf() < 0.12 else Enemy.Rank.NORMAL
		cave.enemies.append(_spawner.spawn_at(cave.cell_position(cell), level, rank, options[random.randi_range(0, options.size() - 1)]))
	var chest_cell: Vector2i = far[0]
	_add_chest(cave, chest_cell, level, 2.0 if lair else 1.0, on_chest)
	if lair:
		cave.enemies.append(_spawner.spawn_at(cave.cell_position(far[mini(3, far.size() - 1)]), level, Enemy.Rank.MINIBOSS, theme["boss"]))
	elif random.randf() < 0.3:
		# Some caves keep a Champion by their treasure instead.
		cave.enemies.append(_spawner.spawn_at(cave.cell_position(far[mini(2, far.size() - 1)]), level, Enemy.Rank.CHAMPION, options[random.randi_range(0, options.size() - 1)]))


func _grow_cave(random: RandomNumberGenerator, size: Vector2i = CAVE_SIZE) -> Dictionary:
	var open := {}
	for y in size.y:
		for x in size.x:
			if random.randf() > 0.44:
				open[Vector2i(x, y)] = true
	for pass_index in 4:
		var next := {}
		for y in size.y:
			for x in size.x:
				var walls := 0
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var near := Vector2i(x + dx, y + dy)
						if not open.has(near):
							walls += 1
				if walls < 5:
					next[Vector2i(x, y)] = true
		open = next
	# Keep only the largest connected cavern so nothing is walled off.
	var best := {}
	var seen := {}
	for start: Vector2i in open:
		if seen.has(start):
			continue
		var region := {}
		var queue: Array[Vector2i] = [start]
		seen[start] = true
		while not queue.is_empty():
			var cell: Vector2i = queue.pop_back()
			region[cell] = true
			for step: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				var near := cell + step
				if open.has(near) and not seen.has(near):
					seen[near] = true
					queue.append(near)
		if region.size() > best.size():
			best = region
	return best


# --- void arenas

## One round room and a number of waves. `on_cleared` runs when the last
## wave falls, and the way out opens.
func enter_arena(arena_seed: int, level: int, on_cleared: Callable) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = arena_seed
	var arena := Room.new()
	arena.title = "The Void"
	for y in range(-ARENA_RADIUS - 1, ARENA_RADIUS + 2):
		for x in range(-ARENA_RADIUS - 1, ARENA_RADIUS + 2):
			var distance := Vector2(x, y).length()
			if distance <= ARENA_RADIUS + 1.5:
				arena.cells[Vector2i(x, y)] = T.VOIDSCAR if distance <= ARENA_RADIUS else T.WALL
	arena.entry = Vector2i(0, ARENA_RADIUS - 2)
	arena.build(_world.tile_set())
	enter(arena)
	_waves_total = random.randi_range(2, 6)
	_wave = 0
	_arena_level = level
	_next_wave_in = 2.0
	_on_cleared = on_cleared


func _physics_process(delta: float) -> void:
	if room == null or _waves_total == 0 or _player.is_dead():
		return
	if _next_wave_in >= 0.0:
		_next_wave_in -= delta
		if _next_wave_in < 0.0:
			_start_wave()
		return
	if room.living_enemies() > 0:
		return
	if _wave < _waves_total:
		_next_wave_in = 2.5
		return
	# Every wave is down: pay out and open the way back.
	_waves_total = 0
	Events.announcement.emit("THE VOID IS QUIET", "A way out has opened")
	_add_chest(room, Vector2i.ZERO, _arena_level, 2.5, Callable())
	room.add_prop(Prop.create(Prop.Art.PORTAL, room.cell_position(room.entry), 0.0, "Step back through", func(_p: Player) -> void: leave()))
	if _on_cleared.is_valid():
		_on_cleared.call()


func _start_wave() -> void:
	_wave += 1
	Events.announcement.emit("WAVE %d OF %d" % [_wave, _waves_total], "")
	var options := VOID_MONSTERS.filter(func(id: String) -> bool: return EnemyDB.ENEMIES[id]["min_level"] <= _arena_level + 3)
	var count := 3 + _wave
	for i in count:
		var spot := Vector2.from_angle(TAU * i / count + _wave) * (ARENA_RADIUS - 2) * TerrainTiles.TILE_SIZE
		# The last wave is led by an Elite.
		var rank := Enemy.Rank.ELITE if _wave == _waves_total and i == 0 else Enemy.Rank.NORMAL
		var enemy := _spawner.spawn_at(Room.ORIGIN + spot + Vector2(22, 22), _arena_level, rank, options.pick_random())
		RingBurst.spawn(room, enemy.global_position, Color(0.75, 0.55, 1.0), 50.0)
		room.enemies.append(enemy)


# --- shared

## A chest that scatters its loot when opened. `richness` scales it.
func _add_chest(in_room: Room, cell: Vector2i, level: int, richness: float, on_open: Callable) -> void:
	var contents: Array = []
	var chest: Prop
	chest = Prop.create(Prop.Art.CHEST, in_room.cell_position(cell), 12.0, "Open the chest", func(_p: Player) -> void:
		if contents.is_empty() and chest.get_meta("rolled", false) == false:
			contents.append_array(Structures.roll_chest(level, richness))
			chest.set_meta("rolled", true)
			if on_open.is_valid():
				on_open.call()
		chest.set_art(Prop.Art.CHEST_OPEN)
		Events.loot_opened.emit({"items": contents, "title": "Chest", "take_only": true})
	)
	in_room.add_prop(chest)


func _discard_room() -> void:
	room.clear_enemies()
	# Loose loot belongs to the room too.
	for pickup in get_tree().get_nodes_in_group("pickups"):
		if pickup.global_position.distance_to(Room.ORIGIN) < 20000.0:
			pickup.queue_free()
	room.queue_free()
	room = null
