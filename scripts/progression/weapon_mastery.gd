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
## The passive each weapon type grows at mastery 25, 150, 300, and 600:
## [stat, kind, amount at each of those four milestones].
const PASSIVE_LEVELS: Array[int] = [25, 150, 300, 600]
const PASSIVES := {
	"swords": ["attack_speed", "percent", [0.03, 0.05, 0.07, 0.10]],
	"greatswords": ["physical_damage", "percent", [0.03, 0.05, 0.07, 0.10]],
	"axes": ["critical_damage", "flat", [0.08, 0.12, 0.16, 0.25]],
	"daggers": ["critical_chance", "flat", [0.02, 0.03, 0.04, 0.06]],
	"spears": ["damage_taken", "percent", [-0.02, -0.03, -0.04, -0.06]],
	"bows": ["attack_speed", "percent", [0.03, 0.05, 0.07, 0.10]],
	"staves": ["magic_power", "percent", [0.04, 0.06, 0.08, 0.12]],
	"unarmed": ["dodge_efficiency", "percent", [0.05, 0.08, 0.10, 0.15]],
}
## From this mastery, every third basic attack in a row is a finisher.
const COMBO_LEVEL := 100
const COMBO_DAMAGE := 1.6

## Damage bonus with a weapon category at maximum mastery.
const MAX_DAMAGE_BONUS := 0.15
const XP_PER_DAMAGE := 0.05
const XP_PER_KILL := 15.0

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
	return roundf(12.0 * pow(from_level, 1.25))


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


## Stat modifiers earned so far with a weapon type, active while it is in hand.
func passive_modifiers(id: String) -> Dictionary:
	if not PASSIVES.has(id):
		return {}
	var passive: Array = PASSIVES[id]
	var total := 0.0
	for index in PASSIVE_LEVELS.size():
		if levels[id] >= PASSIVE_LEVELS[index]:
			total += passive[2][index]
	return {passive[0]: {passive[1]: total}} if total != 0.0 else {}


func has_combo(id: String) -> bool:
	return levels.get(id, 1) >= COMBO_LEVEL


## "Sword Master" and so on at the cap, otherwise "".
func title(id: String) -> String:
	return "%s Master" % NAMES[id].trim_suffix("s") if levels.get(id, 1) >= MAX_LEVEL else ""


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
