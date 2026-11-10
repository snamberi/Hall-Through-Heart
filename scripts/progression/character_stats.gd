class_name CharacterStats
extends Node
## Works out every derived statistic from attributes, mastery, and modifiers.
##
## Equipment, talents, and buffs will feed in through set_modifiers(); each
## source adds flat amounts and percentages. Percentages from all sources are
## summed before multiplying, so bonuses never stack multiplicatively.

signal changed

## Statistics shown on the character screen, in order.
const DISPLAY: Array[Dictionary] = [
	{"id": "physical_damage", "name": "Physical damage", "format": "number"},
	{"id": "magic_power", "name": "Magic damage", "format": "percent"},
	{"id": "max_health", "name": "Maximum HP", "format": "number"},
	{"id": "health_regen", "name": "Health regeneration", "format": "per_second"},
	{"id": "max_stamina", "name": "Maximum stamina", "format": "number"},
	{"id": "max_mana", "name": "Maximum mana", "format": "number"},
	{"id": "critical_chance", "name": "Critical-hit chance", "format": "percent_fine"},
	{"id": "critical_damage", "name": "Critical damage", "format": "multiplier"},
	{"id": "attack_speed", "name": "Attack speed", "format": "percent_fine"},
	{"id": "move_speed", "name": "Movement speed", "format": "number"},
	{"id": "armor", "name": "Armor", "format": "number"},
	{"id": "elemental_resistance", "name": "Elemental resistance", "format": "percent"},
	{"id": "dodge_efficiency", "name": "Dodge efficiency", "format": "percent_fine"},
	{"id": "life_steal", "name": "Life steal", "format": "percent_fine"},
	{"id": "damage_taken", "name": "Damage taken", "format": "percent"},
	{"id": "magic_find", "name": "Magic find", "format": "bonus_percent"},
	{"id": "gold_find", "name": "Gold found", "format": "percent"},
	{"id": "mining_efficiency", "name": "Mining efficiency", "format": "percent"},
]

## Bare-handed damage; weapons add their own on top.
const BASE_PHYSICAL_DAMAGE := 6.0
const BASE_MAX_HEALTH := 100.0
const BASE_MAX_STAMINA := 100.0
const BASE_MAX_MANA := 50.0
const BASE_MOVE_SPEED := 200.0
const BASE_CRITICAL_CHANCE := 0.05

## Weapon category whose mastery bonus applies to physical damage.
var weapon_type := "swords"

var _attributes: Attributes
var _mastery: WeaponMastery
## source id -> stat id -> {"flat": float, "percent": float}
var _modifiers: Dictionary = {}
var _preview: Dictionary = {}


func setup(attributes: Attributes, mastery: WeaponMastery) -> void:
	_attributes = attributes
	_mastery = mastery
	attributes.changed.connect(changed.emit)
	mastery.changed.connect(changed.emit)


## Replaces everything one source (an item, a talent, a buff) contributes.
## `modifiers` maps stat id -> {"flat": float, "percent": float}.
func set_modifiers(source_id: String, modifiers: Dictionary) -> void:
	_modifiers[source_id] = modifiers
	changed.emit()


## Like set_modifiers, but without announcing a change (for use from inside
## handlers that will announce one themselves).
func set_modifiers_quietly(source_id: String, modifiers: Dictionary) -> void:
	_modifiers[source_id] = modifiers


func clear_modifiers(source_id: String) -> void:
	if _modifiers.erase(source_id):
		changed.emit()


func get_stat(id: String) -> float:
	var flat := 0.0
	var percent := 0.0
	for source: Dictionary in _modifiers.values():
		if source.has(id):
			flat += source[id].get("flat", 0.0)
			percent += source[id].get("percent", 0.0)
	if id == "physical_damage":
		percent += _mastery.damage_bonus(weapon_type)
	return (_base(id) + flat) * (1.0 + percent)


## What spending `amount` more points on an attribute would change.
## Returns [{"name", "from", "to"}] with values already formatted.
func preview_changes(attribute_id: String, amount: int) -> Array[Dictionary]:
	var before: Dictionary = {}
	for entry in DISPLAY:
		before[entry["id"]] = get_stat(entry["id"])
	_preview = {attribute_id: amount}
	var changes: Array[Dictionary] = []
	for entry in DISPLAY:
		var after := get_stat(entry["id"])
		if not is_equal_approx(after, before[entry["id"]]):
			changes.append({
				"name": entry["name"],
				"from": format_value(entry["format"], before[entry["id"]]),
				"to": format_value(entry["format"], after),
			})
	_preview = {}
	return changes


static func format_value(format: String, value: float) -> String:
	match format:
		"per_second":
			return "%.1f/s" % value
		"percent":
			return "%d%%" % roundi(value * 100.0)
		"percent_fine":
			return "%.1f%%" % (value * 100.0)
		"bonus_percent":
			return "+%.1f%%" % (value * 100.0)
		"multiplier":
			return "x%.1f" % value
	return str(roundi(value))


## Attribute points including bonuses from equipment and other modifiers.
func _points(id: String) -> int:
	var bonus := 0.0
	for source: Dictionary in _modifiers.values():
		if source.has(id):
			bonus += source[id].get("flat", 0.0)
	return _attributes.points[id] + int(_preview.get(id, 0)) + roundi(bonus)


## Share of a hit that armor removes. Higher-level attackers cut through more.
func damage_reduction(attacker_level: int) -> float:
	var armor := get_stat("armor")
	return armor / (armor + 40.0 + 10.0 * attacker_level)


## A bonus that approaches `limit` as points grow, reaching half at `half_at`.
func _diminishing(points: int, limit: float, half_at: float) -> float:
	return limit * points / (points + half_at)


func _base(id: String) -> float:
	match id:
		"physical_damage":
			return BASE_PHYSICAL_DAMAGE + 2.0 * _points("strength")
		"magic_power":
			return 1.0 + 0.01 * _points("intelligence")
		"max_health":
			return BASE_MAX_HEALTH + 12.0 * _points("vitality")
		"health_regen":
			return 0.1 * floorf(_points("vitality") / 5.0)
		"max_stamina":
			return BASE_MAX_STAMINA + 5.0 * _points("endurance")
		"max_mana":
			return BASE_MAX_MANA + 5.0 * _points("intelligence")
		"critical_chance":
			return BASE_CRITICAL_CHANCE + minf(0.015 * _points("luck"), 0.5)
		"critical_damage":
			return 2.0
		"attack_speed":
			return 1.0 + _diminishing(_points("agility"), 0.6, 120.0)
		"move_speed":
			return BASE_MOVE_SPEED + minf(2.0 * _points("agility"), 140.0)
		"dodge_efficiency":
			return 1.0 + _diminishing(_points("agility"), 0.5, 100.0)
		"magic_find":
			return 0.005 * _points("luck")
		"mining_efficiency":
			return 1.0
		"damage_taken", "gold_find", "dodge_distance":
			return 1.0
		"stamina_regen":
			return 22.0
		"mana_regen":
			return 2.0 + 0.05 * _points("intelligence")
		# Not shown on the character screen:
		"stamina_cost_multiplier":
			return 1.0 - _diminishing(_points("endurance"), 0.35, 100.0)
		"knockback_resistance":
			return _diminishing(_points("endurance"), 0.6, 100.0)
	return 0.0
