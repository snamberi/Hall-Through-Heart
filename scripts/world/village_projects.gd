class_name VillageProjects
extends Node
## What each village is building, with your help. Every village asks for
## one project at a time, in its own order, at its project board: a smithy,
## an inn, a chapel, a market hall, a herb garden. Bring what it needs (and
## some gold) and when it is all given the building goes up and the village
## grows (Hamlet, Village, Town, Market Town), each project with its own
## lasting good.

signal changed(village: String)

const PROJECTS := {
	"smithy": {"name": "Smithy", "needs": {"stone": 40, "oak_wood": 20, "iron_ingot": 6}, "gold": 300,
		"good": "A smith settles here, selling arms, armour and ingots."},
	"inn": {"name": "Inn", "needs": {"oak_wood": 40, "wool": 10, "stone": 20}, "gold": 400,
		"good": "Rest at the inn to wake Well Rested: +10% experience for 20 minutes."},
	"chapel": {"name": "Chapel", "needs": {"stone": 60, "healing_herb": 12, "silver_ingot": 3}, "gold": 500,
		"good": "Pray at the shrine for a Blessing: +6% maximum health for 20 minutes."},
	"market": {"name": "Market Hall", "needs": {"oak_wood": 30, "leather": 10, "gold_ingot": 2}, "gold": 600,
		"good": "The merchant here lays out one more ware and takes 5% off."},
	"garden": {"name": "Herb Garden", "needs": {"healing_herb": 10, "mana_flower": 6, "wheat_seeds": 6}, "gold": 200,
		"good": "Gather a few herbs from the garden once a day."},
}
const ORDER: Array[String] = ["smithy", "inn", "chapel", "market", "garden"]
const TIERS: Array[String] = ["Hamlet", "Village", "Village", "Town", "Town", "Market Town"]

## Village key ("x,y" of its centre) -> {"done": [ids], "given": {item: count}, "gold": int, "harvest_day": int}.
var villages: Dictionary = {}


func _ready() -> void:
	SaveGame.register("village_projects", self)


static func key_of(center: Vector2i) -> String:
	return "%d,%d" % [center.x, center.y]


func _state(center: Vector2i) -> Dictionary:
	var key := key_of(center)
	if not villages.has(key):
		villages[key] = {"done": [], "given": {}, "gold": 0}
	return villages[key]


## Projects finished in a village.
func done(center: Vector2i) -> Array:
	return villages.get(key_of(center), {}).get("done", [])


func has(center: Vector2i, project: String) -> bool:
	return project in done(center)


## This village's order of projects: the same list, turned to start at a
## place picked from where the village stands.
static func order_for(center: Vector2i) -> Array[String]:
	var start := absi(hash(center)) % ORDER.size()
	var result: Array[String] = []
	for index in ORDER.size():
		result.append(ORDER[(start + index) % ORDER.size()])
	return result


## The project the village is asking for now, or "" when all are built.
func current(center: Vector2i) -> String:
	for project in order_for(center):
		if not has(center, project):
			return project
	return ""


func tier_name(center: Vector2i) -> String:
	return TIERS[mini(done(center).size(), TIERS.size() - 1)]


## How much of an item has been given to the current project.
func given(center: Vector2i, item_id: String) -> int:
	return int(_state(center)["given"].get(item_id, 0))


func gold_given(center: Vector2i) -> int:
	return int(_state(center).get("gold", 0))


## Gives what the player has of one need (up to what is still wanted).
## Returns how many were given.
func give(center: Vector2i, player: Player, item_id: String) -> int:
	var project := current(center)
	if project == "":
		return 0
	var wanted: int = int(PROJECTS[project]["needs"].get(item_id, 0)) - given(center, item_id)
	var amount := mini(wanted, player.inventory.count_of(item_id))
	if amount <= 0:
		return 0
	player.inventory.take(item_id, amount)
	var state := _state(center)
	state["given"][item_id] = given(center, item_id) + amount
	Events.codex_event.emit("project_goods", amount)
	_check(center)
	return amount


## Gives gold toward the project. Returns how much was given.
func give_gold(center: Vector2i, player: Player) -> int:
	var project := current(center)
	if project == "":
		return 0
	var amount := mini(int(PROJECTS[project]["gold"]) - gold_given(center), player.inventory.gold)
	if amount <= 0:
		return 0
	player.inventory.add_gold(-amount)
	_state(center)["gold"] = gold_given(center) + amount
	_check(center)
	return amount


## Whether everything for the current project has been given.
func is_ready(center: Vector2i) -> bool:
	var project := current(center)
	if project == "":
		return false
	for item_id: String in PROJECTS[project]["needs"]:
		if given(center, item_id) < int(PROJECTS[project]["needs"][item_id]):
			return false
	return gold_given(center) >= int(PROJECTS[project]["gold"])


func _check(center: Vector2i) -> void:
	if is_ready(center):
		var project := current(center)
		var state := _state(center)
		state["done"].append(project)
		state["given"] = {}
		state["gold"] = 0
		Events.announcement.emit("%s BUILT" % String(PROJECTS[project]["name"]).to_upper(), "The %s grows: %s" % [tier_name(center).to_lower(), PROJECTS[project]["good"]])
		Events.codex_event.emit("projects", 1)
	changed.emit(key_of(center))
	SaveGame.request_save()


## The garden gives herbs once a day. Returns what was gathered, or [].
func harvest_garden(center: Vector2i, player: Player, day: int) -> Array:
	var state := _state(center)
	if int(state.get("harvest_day", -1)) == day:
		return []
	state["harvest_day"] = day
	var found: Array = []
	for herb: String in ["healing_herb", "mana_flower", "frost_lily", "bloodcap", "glowshroom"].slice(0, 3 + (randi() % 3)):
		var count := randi_range(1, 3)
		if player.inventory.add(Item.create(herb, count)):
			found.append([herb, count])
	SaveGame.request_save()
	return found


func save_data() -> Dictionary:
	return {"villages": villages.duplicate(true)}


func load_data(data: Dictionary) -> void:
	villages = data.get("villages", {}).duplicate(true)
