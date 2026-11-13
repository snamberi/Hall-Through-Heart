class_name Buffs
extends Node
## Temporary effects on the player. Each buff feeds stat modifiers into
## CharacterStats for as long as it lasts.

signal changed

## buff id -> {"name": String, "time": seconds left, "total": seconds,
## "icon": Texture2D or null, "kind": "meal", "drink", "treat", "potion"...}
var active: Dictionary = {}

var _stats: CharacterStats


func setup(stats: CharacterStats) -> void:
	_stats = stats


## Round effect icons (tools/generate_ability_icons.py), in sheet order.
const EFFECT_SHEET: Texture2D = preload("res://assets/icons/effects.png")
const EFFECT_ICONS: Array[String] = ["buff", "torchlight", "heart_racing", "heart_steady", "bloodthirst", "blessing", "henge",
	"perfect_dodge", "chill", "burn", "poison", "bleed", "well_fed", "debuff"]
static var _effect_textures: Dictionary = {}


## The picture for a buff: its own effect icon, the ability's icon for an
## ability's buff, or a plain up (or down, if it only hurts) arrow.
static func icon_for(id: String, display_name: String = "", modifiers: Dictionary = {}) -> Texture2D:
	var key := id
	if id == "heart":
		key = "heart_racing" if display_name.contains("Racing") else "heart_steady"
	if not key in EFFECT_ICONS:
		if AbilityDB.ABILITIES.has(id):
			return AbilityDB.icon(id)
		key = "debuff" if _only_hurts(modifiers) else "buff"
	if not _effect_textures.has(key):
		var atlas := AtlasTexture.new()
		atlas.atlas = EFFECT_SHEET
		atlas.region = Rect2(EFFECT_ICONS.find(key) * 24, 0, 24, 24)
		_effect_textures[key] = atlas
	return _effect_textures[key]


static func _only_hurts(modifiers: Dictionary) -> bool:
	if modifiers.is_empty():
		return false
	for stat: String in modifiers:
		for kind: String in modifiers[stat]:
			if float(modifiers[stat][kind]) > 0.0:
				return false
	return true


## Starts a buff, or restarts its timer if it is already running.
## `modifiers` maps stat id -> {"flat": float, "percent": float}. With no
## icon given, one is found for it (see icon_for).
func add(id: String, display_name: String, duration: float, modifiers: Dictionary, icon: Texture2D = null, kind: String = "") -> void:
	if icon == null:
		icon = icon_for(id, display_name, modifiers)
	active[id] = {"name": display_name, "time": duration, "total": duration, "icon": icon, "kind": kind, "mods": modifiers}
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
