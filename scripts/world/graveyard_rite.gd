class_name GraveyardRite
extends Node2D
## What wakes in a graveyard. Come close and the dead climb out of their
## graves, four to ten rotten corpses with dirt bursting round them. When
## the last is put down the ground splits and the Corpse of Roots rises
## (and, beaten once, rises again). Its fall leaves a hoard and the
## graveyard sleeps for a few days. At night a ghost or two drifts among
## the stones.

const WAKE_DISTANCE := 230.0

var structures: Structures
var cell := Vector2i.ZERO
var key := ""
var level := 1
var graves: Array[Vector2] = []
var _stage := "sleeping"
var _risen: Array[Enemy] = []
var _check := 0.0
var _ghosts_out := false
var _boss: Enemy


## Walking away mid-fight lets the dead sink back: the graveyard is built
## afresh, asleep, when the player returns.
func _exit_tree() -> void:
	for corpse in _risen:
		if is_instance_valid(corpse):
			corpse.queue_free()
	if is_instance_valid(_boss) and _boss.state != Enemy.State.DEAD:
		_boss.queue_free()


func _ready() -> void:
	add_to_group("graveyards")


func _process(delta: float) -> void:
	_check -= delta
	if _check > 0.0:
		return
	_check = 0.3
	var player := structures._player
	if player == null or player.is_dead():
		return
	var center := structures._at(cell)
	var near := player.global_position.distance_to(center) < WAKE_DISTANCE
	if near and not _ghosts_out and structures.get_parent().get_node("DayNight").is_night():
		_ghosts_out = true
		for i in randi_range(1, 2):
			structures._spawner.spawn_at(center + Vector2.from_angle(randf() * TAU) * 120.0, level, Enemy.Rank.NORMAL, "ghost")
	match _stage:
		"sleeping":
			if near and _awake():
				_raise_the_dead()
		"risen":
			_risen = _risen.filter(func(e: Enemy) -> bool: return is_instance_valid(e) and e.state != Enemy.State.DEAD)
			if _risen.is_empty():
				_stage = "rooting"
				_raise_the_corpse()


## Whether the graveyard has slept long enough since it was last put to rest.
func _awake() -> bool:
	var day: int = (structures.get_parent().get_node("DayNight") as DayNight).day
	return day - int(structures.boss_days.get(key, -999)) >= BossDB.RESPAWN_DAYS


func _raise_the_dead() -> void:
	_stage = "risen"
	var count := randi_range(4, 10)
	Events.announcement.emit("THE DEAD STIR", "%d corpses claw out of their graves" % count)
	Events.codex_event.emit("graveyards_woken", 1)
	structures._player.shake_camera(5.0)
	for i in count:
		var at: Vector2 = graves[i % graves.size()] + Vector2(randf_range(-14, 14), 22.0) if not graves.is_empty() else structures._at(cell) + Vector2.from_angle(randf() * TAU) * 90.0
		_dirt(at)
		var corpse := structures._spawner.spawn_at(at, level, Enemy.Rank.ELITE if randf() < 0.15 else Enemy.Rank.NORMAL, "rotten_corpse")
		_risen.append(corpse)


func _raise_the_corpse() -> void:
	var center := structures._at(cell)
	Events.announcement.emit("THE GROUND SPLITS", "Something old pushes up through the roots")
	for i in 6:
		_dirt(center + Vector2.from_angle(TAU * i / 6.0) * 50.0)
	structures._player.shake_camera(9.0)
	await get_tree().create_timer(1.6).timeout
	if not is_inside_tree():
		return
	var boss: Enemy = structures._spawner.enemy_scene.instantiate()
	boss.boss_id = "corpse_of_roots"
	boss.position = center
	boss.target = structures._player
	boss.configure(level + 3, Enemy.Rank.BOSS, "rotten_corpse")
	boss.lair_home = center
	boss.wants_minion.connect(func(from: Enemy) -> void:
		structures._spawner.spawn_at(from.global_position + Vector2.from_angle(randf() * TAU) * 70.0, from.level, Enemy.Rank.NORMAL, "rotten_corpse")
	)
	structures._spawner.add_child(boss)
	_boss = boss
	RingBurst.spawn(structures.get_parent(), center + Vector2(0, -20), BossDB.BOSSES["corpse_of_roots"]["color"], 180.0)
	boss.died.connect(_on_corpse_fallen)


func _on_corpse_fallen(_boss: Enemy) -> void:
	_stage = "sleeping"
	var day: int = (structures.get_parent().get_node("DayNight") as DayNight).day
	structures.boss_days[key] = day
	var chest_key := "%s:%d" % [key, day]
	var hoard: Array = BossDB.drops("corpse_of_roots", level + 3)
	# The graveyard's own extra: wood the roots grew from, and bone.
	hoard.append(Item.create("heartwood", randi_range(2, 4)).to_dict())
	hoard.append(Item.create("bone", randi_range(5, 10)).to_dict())
	hoard.append(LootGenerator.make_unique(level + 3, "wispkeeper").to_dict())
	# Kept in the save at once, so the chest is rebuilt if the player leaves
	# before opening it.
	structures.chests[chest_key] = hoard
	var chest := structures._chest(cell + Vector2i(0, 1), chest_key, level, 3.0, hoard)
	structures.add_child(chest)
	LightPillar.spawn(structures.get_parent(), structures._at(cell), Color(0.6, 0.9, 0.4))
	Events.announcement.emit("THE CORPSE OF ROOTS HAS FALLEN", "Its hoard lies among the graves")
	Events.boss_defeated.emit("corpse_of_roots")
	Events.codex_event.emit("graveyards_cleansed", 1)
	SaveGame.request_save()


## Earth bursting up where something climbs out.
func _dirt(at: Vector2) -> void:
	RingBurst.spawn(structures.get_parent(), at, Color(0.45, 0.36, 0.26), 36.0)
	Gore.spray(structures.get_parent(), at + Vector2(0, -4), "_stone", Vector2(0, -1), 8, false)
