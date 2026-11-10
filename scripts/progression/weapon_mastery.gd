class_name WeaponMastery
extends Node
## Persistent mastery level for each weapon category.
##
## Mastery is earned mostly from kills and a little from damage dealt, and is
## separate from character experience.

signal changed

const MAX_LEVEL := 600
const IDS: Array[String] = [
	"swords", "greatswords", "axes", "daggers", "spears", "bows", "staves", "unarmed",
]
const NAMES := {
	"swords": "Swords",
	"greatswords": "Greatswords",
	"axes": "Axes",
	"daggers": "Daggers",
	"spears": "Spears",
	"bows": "Bows",
	"staves": "Staves",
	"unarmed": "Unarmed Combat",
}
const MILESTONES: Array[Dictionary] = [
	{"level": 1, "reward": "Basic attack"},
	{"level": 10, "reward": "First special ability"},
	{"level": 25, "reward": "Minor passive bonus"},
	{"level": 50, "reward": "Second ability"},
	{"level": 100, "reward": "New combo"},
	{"level": 150, "reward": "Weapon technique"},
	{"level": 200, "reward": "Third ability"},
	{"level": 300, "reward": "Advanced technique"},
	{"level": 400, "reward": "Weapon awakening quest"},
	{"level": 500, "reward": "Ultimate technique"},
	{"level": 600, "reward": "Mastery title and final passive"},
]
## Damage bonus with a weapon category at maximum mastery.
const MAX_DAMAGE_BONUS := 0.15
const XP_PER_DAMAGE := 0.05
const XP_PER_KILL := 10.0

var levels: Dictionary[String, int] = {}
var xp: Dictionary[String, float] = {}


func _init() -> void:
	for id in IDS:
		levels[id] = 1
		xp[id] = 0.0


func _ready() -> void:
	Events.damage_dealt.connect(func(weapon_type: String, amount: float) -> void:
		add_xp(weapon_type, amount * XP_PER_DAMAGE)
	)
	Events.enemy_killed.connect(func(info: Dictionary) -> void:
		add_xp(info["weapon_type"], XP_PER_KILL * pow(info["level"], 1.1) * info["xp_multiplier"])
	)
	SaveGame.register("mastery", self)


static func xp_required(from_level: int) -> float:
	return roundf(30.0 * pow(from_level, 1.4))


func add_xp(id: String, amount: float) -> void:
	if not levels.has(id) or amount <= 0.0 or levels[id] >= MAX_LEVEL:
		return
	xp[id] += amount
	while levels[id] < MAX_LEVEL and xp[id] >= xp_required(levels[id]):
		xp[id] -= xp_required(levels[id])
		levels[id] += 1
		Events.mastery_level_up.emit(id, levels[id])
		SaveGame.request_save()
	if levels[id] >= MAX_LEVEL:
		xp[id] = 0.0
	changed.emit()


## Fraction of extra damage with this weapon category, 0 to MAX_DAMAGE_BONUS.
func damage_bonus(id: String) -> float:
	if not levels.has(id):
		return 0.0
	return MAX_DAMAGE_BONUS * (levels[id] - 1) / float(MAX_LEVEL - 1)


func save_data() -> Dictionary:
	return {"levels": levels.duplicate(), "xp": xp.duplicate()}


func load_data(data: Dictionary) -> void:
	var saved_levels: Variant = data.get("levels", {})
	var saved_xp: Variant = data.get("xp", {})
	for id in IDS:
		if saved_levels is Dictionary:
			levels[id] = clampi(int(saved_levels.get(id, 1)), 1, MAX_LEVEL)
		if saved_xp is Dictionary:
			xp[id] = maxf(float(saved_xp.get(id, 0.0)), 0.0)
