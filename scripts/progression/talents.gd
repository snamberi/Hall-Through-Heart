class_name Talents
extends Node
## The talents the player has learned.

signal changed

## node id -> ranks learned (only ids with at least one rank)
var ranks: Dictionary[String, int] = {}

var _leveling: Leveling
var _stats: CharacterStats


func _ready() -> void:
	SaveGame.register("talents", self)


func setup(leveling: Leveling, stats: CharacterStats) -> void:
	_leveling = leveling
	_stats = stats
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


## Why a rank cannot be learned right now, or "" if it can.
func blocked_reason(id: String) -> String:
	var node: Dictionary = TalentDB.NODES[id]
	if rank(id) >= node["max"]:
		return "Fully learned."
	for required: String in node.get("requires", []):
		if not has(required):
			return "Requires %s." % TalentDB.NODES[required]["name"]
	if _leveling.talent_points <= 0:
		return "No talent points."
	return ""


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
	var saved: Variant = data.get("ranks", {})
	if saved is Dictionary:
		for id: String in saved:
			if TalentDB.NODES.has(id):
				ranks[id] = clampi(int(saved[id]), 0, TalentDB.NODES[id]["max"])


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
