class_name Leveling
extends Node
## Character level and experience.

signal xp_changed(xp: int, required: int)
signal leveled_up(level: int)

const MAX_LEVEL := 1200
const STAT_POINTS_PER_LEVEL := 3
const LEVELS_PER_TALENT_POINT := 2
const MILESTONE_INTERVAL := 10
## Share of progress toward the next level lost on death.
const DEATH_XP_LOSS := 0.25

var level := 1
var xp := 0
## Unspent talent points. The skill tree will spend these.
var talent_points := 0


func _ready() -> void:
	Events.enemy_killed.connect(func(info: Dictionary) -> void: add_xp(info["xp"], "combat"))
	SaveGame.register("leveling", self)


## Experience needed to go from `from_level` to the next: 29, 87, 167, 267, 388...
static func xp_required(from_level: int) -> int:
	return roundi((9 * from_level * from_level + 24 * from_level - 8) * 1.15)


func xp_to_next() -> int:
	return xp_required(level)


func is_max_level() -> bool:
	return level >= MAX_LEVEL


## Adds experience and processes every level it pays for.
func add_xp(amount: int, source: String = "") -> void:
	if amount <= 0 or is_max_level():
		return
	xp += amount
	Events.xp_gained.emit(amount, source)
	while not is_max_level() and xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		if level % LEVELS_PER_TALENT_POINT == 0:
			talent_points += 1
		leveled_up.emit(level)
		Events.level_up.emit(level)
		if level % MILESTONE_INTERVAL == 0:
			Events.milestone_reached.emit(level)
	if is_max_level():
		xp = 0
	xp_changed.emit(xp, xp_to_next())
	SaveGame.request_save()


## Removes part of the progress toward the next level. Returns the XP lost.
func apply_death_penalty() -> int:
	var lost := roundi(xp * float(Difficulty.value("death_loss")))
	xp -= lost
	xp_changed.emit(xp, xp_to_next())
	SaveGame.request_save()
	return lost


func save_data() -> Dictionary:
	return {"level": level, "xp": xp, "talent_points": talent_points}


func load_data(data: Dictionary) -> void:
	level = clampi(int(data.get("level", 1)), 1, MAX_LEVEL)
	xp = maxi(int(data.get("xp", 0)), 0)
	talent_points = maxi(int(data.get("talent_points", 0)), 0)
