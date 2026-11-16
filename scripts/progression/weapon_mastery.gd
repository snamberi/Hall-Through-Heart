class_name WeaponMastery
extends Node
## Mastery of each weapon on its own. Every weapon (each kind of sword, axe,
## bow and staff by item), the bare hands and the magic hand has its own
## level from 1 to 600, earned mostly from kills and a little from damage
## dealt with it, apart from character experience. A weapon's mastery opens
## its own moves (WeaponMoves.UNLOCK), adds damage with it, and at
## milestones gives the passive of its kind (PASSIVES), a combo and a title.
##
## Saves from before kept one level per kind of weapon: each weapon of a
## kind starts from that old level the first time it is used.

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

## Weapon key -> level and progress. A key is an item id, "unarmed" (the
## bare hands and combat styles) or "magic" (the magic hand).
var levels: Dictionary[String, int] = {}
var xp: Dictionary[String, float] = {}
## Kind -> level, from saves made before mastery was per weapon.
var _legacy: Dictionary = {}
## Kind -> the key of the weapon of that kind that last dealt damage, so a
## kill is credited to the weapon that made it.
var _recent: Dictionary = {}


func _ready() -> void:
	Events.damage_dealt.connect(func(key: String, amount: float) -> void:
		_recent[kind_of(key)] = key
		add_xp(key, amount * XP_PER_DAMAGE)
	)
	Events.enemy_killed.connect(func(info: Dictionary) -> void:
		var kind: String = info.get("weapon_type", "")
		var key: String = _recent.get(kind, "unarmed" if kind == "unarmed" else "")
		if key != "":
			add_xp(key, XP_PER_KILL * pow(info["level"], 1.1) * info["xp_multiplier"])
	)
	SaveGame.register("mastery", self)


static func xp_required(from_level: int) -> float:
	return roundf(12.0 * pow(from_level, 1.25))


## The kind of weapon a key is (one of IDS).
static func kind_of(key: String) -> String:
	if key == "magic":
		return "staves"
	if ItemDB.ITEMS.has(key) and ItemDB.ITEMS[key].has("weapon"):
		var kind: String = ItemDB.ITEMS[key]["weapon"].get("type", "unarmed")
		return kind if kind in IDS else "unarmed"
	return key if key in IDS else "unarmed"


## Whether a key names a kind rather than one weapon.
static func is_kind(key: String) -> bool:
	return key in IDS and key != "unarmed" and not ItemDB.ITEMS.has(key)


## A weapon's name as the mastery screen shows it.
static func display_name(key: String) -> String:
	match key:
		"unarmed":
			return "Bare hands"
		"magic":
			return "Magic hand"
	if ItemDB.ITEMS.has(key):
		return ItemDB.ITEMS[key]["name"]
	return NAMES.get(key, key.capitalize())


## Every weapon with a mastery of its own, of one kind (items in data order).
static func keys_of_kind(kind: String) -> Array[String]:
	var keys: Array[String] = []
	if kind == "unarmed":
		keys.append("unarmed")
	if kind == "staves":
		keys.append("magic")
	for id: String in ItemDB.ITEMS:
		var data: Dictionary = ItemDB.ITEMS[id]
		if data.has("weapon") and not data.has("tool") and data["weapon"].get("type", "") == kind:
			keys.append(id)
	return keys


## A weapon's level. Given a kind, the best weapon of that kind.
func level_of(key: String) -> int:
	if is_kind(key):
		return best_of_kind(key)
	return levels.get(key, maxi(1, int(_legacy.get(kind_of(key), 1))))


func xp_of(key: String) -> float:
	return xp.get(key, 0.0)


func best_of_kind(kind: String) -> int:
	var best := maxi(1, int(_legacy.get(kind, 1)))
	for key: String in levels:
		if kind_of(key) == kind:
			best = maxi(best, levels[key])
	return best


func add_xp(key: String, amount: float) -> void:
	if is_kind(key) or amount <= 0.0:
		return
	if not levels.has(key):
		levels[key] = level_of(key)
		xp[key] = 0.0
	if levels[key] >= MAX_LEVEL:
		return
	xp[key] += amount
	while levels[key] < MAX_LEVEL and xp[key] >= xp_required(levels[key]):
		xp[key] -= xp_required(levels[key])
		levels[key] += 1
		Events.mastery_level_up.emit(key, levels[key])
		SaveGame.request_save()
	if levels[key] >= MAX_LEVEL:
		xp[key] = 0.0
	changed.emit()


## Fraction of extra damage with this weapon, 0 to MAX_DAMAGE_BONUS.
func damage_bonus(key: String) -> float:
	return MAX_DAMAGE_BONUS * (level_of(key) - 1) / float(MAX_LEVEL - 1)


## Stat modifiers earned so far with a weapon, active while it is in hand:
## its kind's passive, grown at each milestone it has passed.
func passive_modifiers(key: String) -> Dictionary:
	var kind := kind_of(key)
	if not PASSIVES.has(kind):
		return {}
	var passive: Array = PASSIVES[kind]
	var level := level_of(key)
	var total := 0.0
	for index in PASSIVE_LEVELS.size():
		if level >= PASSIVE_LEVELS[index]:
			total += passive[2][index]
	return {passive[0]: {passive[1]: total}} if total != 0.0 else {}


func has_combo(key: String) -> bool:
	return level_of(key) >= COMBO_LEVEL


## "Emberbrand Master" and so on at the cap, otherwise "".
func title(key: String) -> String:
	return "%s Master" % display_name(key) if level_of(key) >= MAX_LEVEL else ""


func save_data() -> Dictionary:
	return {"version": 2, "levels": levels.duplicate(), "xp": xp.duplicate(), "legacy": _legacy.duplicate()}


func load_data(data: Dictionary) -> void:
	levels.clear()
	xp.clear()
	_legacy.clear()
	var saved_levels: Variant = data.get("levels", {})
	var saved_xp: Variant = data.get("xp", {})
	if int(data.get("version", 1)) < 2:
		# One level per kind: kept as where each weapon of that kind starts.
		if saved_levels is Dictionary:
			for kind: String in IDS:
				var old := clampi(int(saved_levels.get(kind, 1)), 1, MAX_LEVEL)
				if old > 1:
					_legacy[kind] = old
		changed.emit()
		return
	if data.get("legacy", {}) is Dictionary:
		_legacy = (data["legacy"] as Dictionary).duplicate()
	if saved_levels is Dictionary:
		for key: String in saved_levels:
			levels[key] = clampi(int(saved_levels[key]), 1, MAX_LEVEL)
	if saved_xp is Dictionary:
		for key: String in saved_xp:
			if levels.has(key):
				xp[key] = maxf(float(saved_xp[key]), 0.0)
	changed.emit()
