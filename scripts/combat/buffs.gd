class_name Buffs
extends Node
## Temporary effects on the player. Each buff feeds stat modifiers into
## CharacterStats for as long as it lasts.

signal changed

## buff id -> {"name": String, "time": seconds left}
var active: Dictionary = {}

var _stats: CharacterStats


func setup(stats: CharacterStats) -> void:
	_stats = stats


## Starts a buff, or restarts its timer if it is already running.
## `modifiers` maps stat id -> {"flat": float, "percent": float}.
func add(id: String, display_name: String, duration: float, modifiers: Dictionary) -> void:
	active[id] = {"name": display_name, "time": duration}
	_stats.set_modifiers("buff:" + id, modifiers)
	changed.emit()


func has(id: String) -> bool:
	return active.has(id)


func clear_all() -> void:
	for id: String in active.keys():
		_stats.clear_modifiers("buff:" + id)
	active.clear()
	changed.emit()


func _physics_process(delta: float) -> void:
	for id: String in active.keys():
		active[id]["time"] -= delta
		if active[id]["time"] <= 0.0:
			active.erase(id)
			_stats.clear_modifiers("buff:" + id)
			changed.emit()
