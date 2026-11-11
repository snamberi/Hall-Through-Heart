class_name Raids
extends Node
## Now and then, as night falls, monsters come for the player's home -
## always under a blood moon. Three waves come at it from the dark; walls,
## spike traps, ballistas and a guard help hold them off. Beat them all for
## a reward; at dawn any still alive slink away.

const WAVES := 3
const CHANCE := 0.35
const MIN_DAY := 4
const MIN_GAP_DAYS := 2
const NEAR_HOME := 1500.0

var last_raid_day := -99
var active := false
var wave := 0

var _player: Player
var _settlers: Settlers
var _spawner: EnemySpawner
var _world: World
var _day_night: DayNight
var _raiders: Array = []
var _next_wave_in := 0.0
var _was_night := false


func _ready() -> void:
	SaveGame.register("raids", self)


func setup(player: Player, settlers: Settlers, spawner: EnemySpawner, world: World, day_night: DayNight) -> void:
	_player = player
	_settlers = settlers
	_spawner = spawner
	_world = world
	_day_night = day_night


func _physics_process(delta: float) -> void:
	if _player == null:
		return
	var night := _day_night.is_night()
	if night and not _was_night:
		_dusk()
	elif not night and _was_night and active:
		_end(false)
	_was_night = night
	if not active:
		return
	_raiders = _raiders.filter(func(e: Variant) -> bool: return is_instance_valid(e) and not e.health.is_dead())
	if _raiders.is_empty():
		_next_wave_in -= delta
		if _next_wave_in <= 0.0:
			if wave >= WAVES:
				_end(true)
			else:
				_start_wave()


func _dusk() -> void:
	var home: Variant = _settlers.home_point()
	if home == null or _player.indoors or _player.is_dead():
		return
	if _day_night.day < MIN_DAY or _day_night.day - last_raid_day < MIN_GAP_DAYS:
		return
	if (home as Vector2).distance_to(_player.global_position) > NEAR_HOME:
		return
	if not DayNight.blood_moon and randf() > CHANCE:
		return
	begin()


func begin() -> void:
	active = true
	wave = 0
	last_raid_day = _day_night.day
	_next_wave_in = 4.0
	Events.announcement.emit("YOUR HOME IS UNDER ATTACK", "Hold out through %d waves" % WAVES)
	Audio.play("level_up", -2.0, 0.0)
	SaveGame.request_save()


func _start_wave() -> void:
	wave += 1
	_next_wave_in = 6.0
	var home: Vector2 = _settlers.home_point()
	var cell := _world.world_to_cell(home)
	var level := _world.generator.enemy_level_at(cell) + 1
	var count := 4 + wave * 2 + (2 if DayNight.blood_moon else 0)
	for i in count:
		var angle := randf() * TAU
		var spot := _world.world_to_cell(home + Vector2.from_angle(angle) * randf_range(560.0, 700.0))
		spot = _world.generator.find_walkable_near(spot, 6)
		var id := EnemyDB.pick(_world.generator.tile_type_at(spot), level, true, false)
		if id == "":
			id = "husk"
		var rank := Enemy.Rank.ELITE if randf() < 0.1 * wave else Enemy.Rank.NORMAL
		if wave == WAVES and i == 0:
			rank = Enemy.Rank.CHAMPION
		var enemy := _spawner.spawn_at(_world.cell_to_world(spot), level, rank, id)
		enemy.lair_home = home
		enemy.state = Enemy.State.CHASE
		_raiders.append(enemy)
	Events.announcement.emit("WAVE %d OF %d" % [wave, WAVES], "%d raiders approach" % count)


func raiders_left() -> int:
	return _raiders.size()


func _end(won: bool) -> void:
	active = false
	if not won:
		for enemy: Variant in _raiders:
			if is_instance_valid(enemy) and not enemy.health.is_dead():
				enemy.queue_free()
		_raiders.clear()
		Events.announcement.emit("THE RAIDERS FLEE", "Dawn breaks over your home")
		return
	var level := _player.leveling.level
	var gold := roundi(60.0 * pow(level, 0.9))
	_player.inventory.add_gold(gold)
	_player.leveling.add_xp(roundi(80.0 * pow(level, 1.2)), "raid")
	var prize := LootGenerator.roll_special(level, "champion", 0.0, 2.0)
	if prize == null:
		prize = LootGenerator.make_equipment(level, maxi(LootGenerator.roll_rarity(0.0, 4.0), 2))
	_player.inventory.add(prize)
	Events.codex_event.emit("raids", 1)
	Events.announcement.emit("RAID REPELLED", "%d gold and %s" % [gold, prize.display_name()])
	SaveGame.request_save()


func save_data() -> Dictionary:
	return {"last": last_raid_day}


func load_data(data: Dictionary) -> void:
	last_raid_day = int(data.get("last", -99))
