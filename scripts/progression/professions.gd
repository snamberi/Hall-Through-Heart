class_name Professions
extends Node
## Gathering and crafting skill levels, separate from character level.

signal changed

const MAX_LEVEL := 100
const GATHERING: Array[String] = ["mining", "woodcutting", "herbalism", "fishing"]
const CRAFTING: Array[String] = ["building", "blacksmithing", "alchemy", "cooking", "enchanting", "salvaging"]
const NAMES := {
	"mining": "Mining", "woodcutting": "Woodcutting", "herbalism": "Herbalism", "fishing": "Fishing",
	"building": "Building", "blacksmithing": "Blacksmithing", "alchemy": "Alchemy", "cooking": "Cooking",
	"enchanting": "Enchanting", "salvaging": "Salvaging",
}
const ICONS := {
	"mining": 49, "woodcutting": 50, "herbalism": 44, "fishing": 51,
	"building": 54, "blacksmithing": 46, "alchemy": 47, "cooking": 48, "enchanting": 52, "salvaging": 2,
}
const TITLES := {
	"mining": "Master Miner", "woodcutting": "Master Woodcutter", "herbalism": "Master Herbalist",
	"fishing": "Master Angler", "blacksmithing": "Master Smith", "alchemy": "Master Alchemist",
	"cooking": "Master Cook", "building": "Master Builder", "enchanting": "Master Enchanter", "salvaging": "Master Salvager",
}
## Gathering is this much faster per level, and this likely per level to yield double.
const SPEED_PER_LEVEL := 0.01
const DOUBLE_PER_LEVEL := 0.005

var levels: Dictionary[String, int] = {}
var xp: Dictionary[String, float] = {}


func _init() -> void:
	for id: String in NAMES:
		levels[id] = 1
		xp[id] = 0.0


func _ready() -> void:
	SaveGame.register("professions", self)


static func all_ids() -> Array[String]:
	return GATHERING + CRAFTING


static func xp_required(from_level: int) -> float:
	return roundf(40.0 * pow(from_level, 1.4))


func level(id: String) -> int:
	return levels.get(id, 1)


func add_xp(id: String, amount: float) -> void:
	if not levels.has(id) or amount <= 0.0 or levels[id] >= MAX_LEVEL:
		return
	xp[id] += amount
	while levels[id] < MAX_LEVEL and xp[id] >= xp_required(levels[id]):
		xp[id] -= xp_required(levels[id])
		levels[id] += 1
		Events.profession_level_up.emit(id, levels[id])
	if levels[id] >= MAX_LEVEL:
		xp[id] = 0.0
	changed.emit()
	SaveGame.request_save()


func speed_multiplier(id: String) -> float:
	return 1.0 + SPEED_PER_LEVEL * (level(id) - 1)


func double_chance(id: String) -> float:
	return DOUBLE_PER_LEVEL * (level(id) - 1)


## "Master Miner" and so on at the level cap, otherwise "".
func title(id: String) -> String:
	return TITLES[id] if level(id) >= MAX_LEVEL else ""


func save_data() -> Dictionary:
	return {"levels": levels.duplicate(), "xp": xp.duplicate()}


func load_data(data: Dictionary) -> void:
	var saved_levels: Variant = data.get("levels", {})
	var saved_xp: Variant = data.get("xp", {})
	for id: String in NAMES:
		if saved_levels is Dictionary:
			levels[id] = clampi(int(saved_levels.get(id, 1)), 1, MAX_LEVEL)
		if saved_xp is Dictionary:
			xp[id] = maxf(float(saved_xp.get(id, 0.0)), 0.0)
