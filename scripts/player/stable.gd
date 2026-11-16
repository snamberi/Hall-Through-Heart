class_name Stable
extends Node
## Tack for whatever you ride, and your race records. A saddle makes any
## mount faster; barding is armour for the ride (and the heavier kinds keep
## you in the saddle when struck). Tack is put on from the bag and fits
## every mount you own. Race records keep the best time and medal for each
## village course (see RaceCourse).

signal changed

const SLOTS := ["saddle", "barding"]
const MEDALS := ["", "Bronze", "Silver", "Gold"]
const MEDAL_COLORS := [Color(0.6, 0.6, 0.65), Color(0.85, 0.55, 0.3), Color(0.8, 0.85, 0.92), Color(1.0, 0.82, 0.3)]

## slot -> Item or null.
var tack: Dictionary = {"saddle": null, "barding": null}
## Course key -> best time in seconds.
var best_times: Dictionary = {}
## Course key -> best medal won (1 bronze, 2 silver, 3 gold).
var medals: Dictionary = {}
var _player: Player


func _ready() -> void:
	_player = get_parent()
	SaveGame.register("stable", self)


static func slot_of(item: Item) -> String:
	return str(item.definition().get("tack", "")) if item else ""


## Extra speed for any mount, as a share (0.12 is 12% faster).
func speed_bonus() -> float:
	var total := 0.0
	for slot: String in SLOTS:
		var item: Item = tack[slot]
		if item:
			total += float(item.definition().get("tack_speed", 0.0))
	return total


## Extra armour while riding, as a share.
func armour_bonus() -> float:
	var item: Item = tack["barding"]
	return float(item.definition().get("tack_armour", 0.0)) if item else 0.0


## Whether blows cannot knock you from the saddle.
func steady() -> bool:
	var item: Item = tack["barding"]
	return item != null and item.definition().get("steady", false)


## Puts tack on from the bag; what was there goes back in the bag.
## Returns "" or why not.
func put_on(item: Item) -> String:
	var slot := slot_of(item)
	if slot == "":
		return "That is not tack."
	if not item in _player.inventory.items:
		return "It is not in your bag."
	var old: Item = tack[slot]
	tack[slot] = take_one(_player.inventory, item)
	if old:
		_player.inventory.add(old, false)
	_changed()
	return ""


## Takes one of a stack out of the bag, as its own item.
static func take_one(inventory: Inventory, item: Item) -> Item:
	if item.count > 1:
		item.count -= 1
		inventory.changed.emit()
		var single := Item.from_dict(item.to_dict())
		single.count = 1
		return single
	inventory.remove(item)
	return item


func take_off(slot: String) -> String:
	var item: Item = tack.get(slot)
	if item == null:
		return ""
	if not _player.inventory.has_room_for(item):
		return "Your bag is full."
	tack[slot] = null
	_player.inventory.add(item, false)
	_changed()
	return ""


## Notes a finished race. Returns the medal won (0 for none) and whether
## the time and medal are new bests: {"medal", "new_best", "new_medal"}.
func record_race(course: String, seconds: float, medal: int) -> Dictionary:
	var result := {"medal": medal, "new_best": false, "new_medal": false}
	if not best_times.has(course) or seconds < float(best_times[course]):
		best_times[course] = seconds
		result["new_best"] = true
	if medal > int(medals.get(course, 0)):
		medals[course] = medal
		result["new_medal"] = true
	_changed()
	return result


## How many courses have at least this medal.
func medal_count(at_least: int) -> int:
	var count := 0
	for course: String in medals:
		if int(medals[course]) >= at_least:
			count += 1
	return count


## Armour while riding comes and goes with the saddle.
func apply_riding(riding: bool) -> void:
	if riding and armour_bonus() > 0.0:
		_player.stats.set_modifiers("barding", {"armor": {"percent": armour_bonus()}})
	else:
		_player.stats.clear_modifiers("barding")


func _changed() -> void:
	apply_riding(_player.mount_id != "")
	changed.emit()
	SaveGame.request_save()


func save_data() -> Dictionary:
	var gear := {}
	for slot: String in SLOTS:
		if tack[slot]:
			gear[slot] = (tack[slot] as Item).to_dict()
	return {"tack": gear, "best": best_times.duplicate(), "medals": medals.duplicate()}


func load_data(data: Dictionary) -> void:
	tack = {"saddle": null, "barding": null}
	var gear: Dictionary = data.get("tack", {})
	for slot: String in SLOTS:
		if gear.get(slot) is Dictionary:
			tack[slot] = Item.from_dict(gear[slot])
	best_times = data.get("best", {}).duplicate()
	medals = data.get("medals", {}).duplicate()
	changed.emit()
