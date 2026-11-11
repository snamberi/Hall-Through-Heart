class_name Talents
extends Node
## The talents the player has learned.

signal changed

## node id -> ranks learned (only ids with at least one rank)
var ranks: Dictionary[String, int] = {}

var _leveling: Leveling
var _stats: CharacterStats
var _refund := 0


func _ready() -> void:
	SaveGame.register("talents", self)


func setup(leveling: Leveling, stats: CharacterStats) -> void:
	_leveling = leveling
	_stats = stats
	if _refund > 0:
		leveling.talent_points += _refund
		_refund = 0
	_apply()


func rank(id: String) -> int:
	return ranks.get(id, 0)


func has(id: String) -> bool:
	return rank(id) > 0


func spent_points() -> int:
	var total := 0
	for id in ranks:
		total += ranks[id]
	return total


## Why a rank cannot be learned right now, or "".
func blocked_reason(id: String) -> String:
	var node: Dictionary = TalentDB.NODES[id]
	if rank(id) >= node["max"]:
		return "Fully learned."
	if id != "awakened_heart" and not TalentDB.neighbours(id).any(func(other: String) -> bool: return has(other)):
		return "Learn a talent next to it first."
	if spent_points() < node.get("milestone", 0):
		return "Needs %d points spent in the tree (you have %d)." % [node["milestone"], spent_points()]
	if _leveling.talent_points <= 0:
		return "No talent points."
	return ""


## Whether a node could be learned at all from where the player is now
## (ignoring whether they have a point to spend).
func reachable(id: String) -> bool:
	return id == "awakened_heart" or TalentDB.neighbours(id).any(func(other: String) -> bool: return has(other))


func learn(id: String) -> bool:
	if not TalentDB.NODES.has(id) or blocked_reason(id) != "":
		return false
	_leveling.talent_points -= 1
	ranks[id] = rank(id) + 1
	_apply()
	changed.emit()
	SaveGame.request_save()
	return true


func save_data() -> Dictionary:
	return {"ranks": ranks.duplicate()}


func load_data(data: Dictionary) -> void:
	ranks.clear()
	_refund = 0
	var saved: Variant = data.get("ranks", {})
	if saved is Dictionary:
		for id: String in saved:
			if TalentDB.NODES.has(id):
				ranks[id] = clampi(int(saved[id]), 0, TalentDB.NODES[id]["max"])
				_refund += int(saved[id]) - ranks[id]
			else:
				# A talent from an older tree: give the point back.
				_refund += int(saved[id])
	# Talents that no longer connect to the Heart are given back too.
	if not ranks.is_empty() and not ranks.has("awakened_heart"):
		for id: String in ranks:
			_refund += ranks[id]
		ranks.clear()


## Sums every learned rank into one set of stat modifiers.
func _apply() -> void:
	var totals := {}
	for id in ranks:
		var mods: Dictionary = TalentDB.NODES[id]["mods"]
		for stat: String in mods:
			if not totals.has(stat):
				totals[stat] = {"flat": 0.0, "percent": 0.0}
			for kind: String in mods[stat]:
				totals[stat][kind] += mods[stat][kind] * ranks[id]
	_stats.set_modifiers("talents", totals)
