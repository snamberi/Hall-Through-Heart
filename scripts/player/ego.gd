class_name Ego
extends Node
## Ego: pride swelling from beating things stronger than you. Each kill of
## a monster above your level adds to it (more for Elites, Ancients and
## bosses, more the bigger the gap), and past a little pride it saps your
## damage, spell power and attack speed. Humbler work brings it down:
## building, crafting, cooking, fishing, trading, finishing quests and
## helping villagers.

signal changed

const MAX := 100.0
## Below this, ego costs nothing.
const FREE := 10.0
## At a full bar: damage and spell power lost, and attack speed lost.
const DAMAGE_LOSS := 0.4
const SPEED_LOSS := 0.3
const RANK_WEIGHT := {"normal": 1.0, "elite": 2.5, "champion": 4.0, "miniboss": 8.0, "boss": 15.0}
## [up to this much ego, name] from humble to insufferable.
const TIERS: Array[Array] = [[20.0, "Humble"], [45.0, "Proud"], [70.0, "Arrogant"], [90.0, "Vain"], [101.0, "Insufferable"]]
## How much each kind of humble work lowers it.
const HUMBLING := {"craft": 1.5, "cook": 3.0, "build": 2.0, "tile": 0.5, "fish": 3.0, "trade": 1.0, "quest": 6.0, "help": 5.0, "harvest": 1.0}

var value := 0.0
var _player: Player


func _ready() -> void:
	_player = get_parent()
	SaveGame.register("ego", self)
	Events.enemy_killed.connect(_on_kill)
	Events.item_crafted.connect(_on_crafted)
	Events.resource_gathered.connect(_on_gathered)
	Events.quest_completed.connect(func(_title: String, _rewards: String) -> void: humble("quest"))
	Events.codex_event.connect(_on_deed)
	_apply()


func _on_crafted(recipe_id: String) -> void:
	humble("cook" if RecipeDB.find(recipe_id).get("profession", "") == "cooking" else "craft")


func _on_gathered(info: Dictionary) -> void:
	if GatherDB.RESOURCES.get(info["resource"], {}).get("kind", "") == "fish":
		humble("fish")


func _on_deed(stat: String, amount: int) -> void:
	match stat:
		"sales", "purchases":
			humble("trade", amount)
		"quests":
			humble("quest", amount)
		"settlers":
			humble("help", amount)
		"built_tiles":
			humble("tile", amount)
		"built":
			humble("build", amount)
		"harvests":
			humble("harvest", amount)


func _on_kill(info: Dictionary) -> void:
	var gap := int(info.get("level", 1)) - _player.leveling.level
	if gap <= 0 or info.get("fragment", false):
		return
	var weight: float = RANK_WEIGHT.get(str(info.get("rank", "normal")), 1.0)
	add(minf((1.0 + gap * 0.6) * weight, 25.0))


## Adds pride (from a fight won above your station).
func add(amount: float) -> void:
	var before := tier()
	value = clampf(value + amount, 0.0, MAX)
	_apply()
	if tier() != before:
		Events.announcement.emit("EGO: %s" % tier().to_upper(), describe())


## Lowers ego for a piece of humble work, `times` over.
func humble(kind: String, times: int = 1) -> void:
	if value <= 0.0:
		return
	var before := tier()
	value = maxf(value - float(HUMBLING.get(kind, 1.0)) * times, 0.0)
	_apply()
	if tier() != before:
		Events.announcement.emit("EGO: %s" % tier().to_upper(), describe())


## How much of the penalty applies, 0 to 1.
func weight() -> float:
	return clampf((value - FREE) / (MAX - FREE), 0.0, 1.0)


func damage_loss() -> float:
	return DAMAGE_LOSS * weight()


func speed_loss() -> float:
	return SPEED_LOSS * weight()


func tier() -> String:
	for entry: Array in TIERS:
		if value < entry[0]:
			return entry[1]
	return TIERS[-1][1]


func describe() -> String:
	if weight() <= 0.0:
		return "No penalty. Win against the odds and it swells; humble work brings it down."
	return "-%d%% damage and spell power, -%d%% attack speed. Build, craft, cook, fish, trade, help villagers or finish quests to lower it." % [roundi(damage_loss() * 100.0), roundi(speed_loss() * 100.0)]


func _apply() -> void:
	if _player == null or _player.stats == null:
		return
	var mods := {}
	if weight() > 0.0:
		mods = {"physical_damage": {"percent": -damage_loss()}, "magic_power": {"percent": -damage_loss()}, "attack_speed": {"percent": -speed_loss()}}
	_player.stats.set_modifiers("ego", mods)
	changed.emit()


func save_data() -> Dictionary:
	return {"value": value}


func load_data(data: Dictionary) -> void:
	value = clampf(float(data.get("value", 0.0)), 0.0, MAX)
	_apply()
