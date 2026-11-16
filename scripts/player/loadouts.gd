class_name Loadouts
extends Node
## Three saved sets of what you wear and use: every equipped piece, both
## ability sets (and which is live) and the worn relics. Save the current
## set into a slot, then wear any slot at once, from the inventory screen
## or with the loadout key, which steps to the next saved set. Pieces are
## remembered by their uid; one sold or lost is simply skipped.

signal changed

const SLOTS := 3

## Each set: {} when empty, else {"gear": {slot: uid}, "abilities": [...],
## "active_set": int, "relics": [uid, ...]}.
var sets: Array[Dictionary] = [{}, {}, {}]
## The set last worn, or -1.
var current := -1
var _player: Player


func _ready() -> void:
	_player = get_parent()
	SaveGame.register("loadouts", self)


func is_empty(index: int) -> bool:
	return sets[index].is_empty()


## Keeps what is worn now in a slot.
func save_set(index: int) -> void:
	var gear := {}
	for slot: String in _player.equipment.equipped:
		var item: Item = _player.equipment.equipped[slot]
		if item:
			gear[slot] = item.ensure_uid()
	var relics: Array = []
	for relic in _player.relics.worn:
		relics.append(relic.ensure_uid())
	sets[index] = {"gear": gear, "abilities": _player.abilities.loadout.duplicate(), "active_set": _player.abilities.active_set, "relics": relics}
	current = index
	SaveGame.request_save()
	changed.emit()


## Puts on a saved set. Returns "" or what could not be done.
func wear_set(index: int) -> String:
	if is_empty(index):
		return "Set %d is empty: save one first." % (index + 1)
	var data: Dictionary = sets[index]
	var missing := 0
	var gear: Dictionary = data.get("gear", {})
	for slot: String in gear:
		var item := _find(int(gear[slot]))
		if item == null:
			missing += 1
			continue
		if _player.equipment.equipped.get(slot) == item:
			continue
		var worn_in := _player.equipment.slot_of(item)
		if worn_in != "":
			_player.equipment.unequip(worn_in)
		if _player.equipment.equip(item, slot) != "":
			missing += 1
	# Abilities: only ones still known.
	var saved: Array = data.get("abilities", [])
	for slot in mini(saved.size(), _player.abilities.loadout.size()):
		var id := str(saved[slot])
		_player.abilities.loadout[slot] = id if id == "" or AbilityDB.ABILITIES.has(id) else ""
	_player.abilities.active_set = clampi(int(data.get("active_set", 0)), 0, AbilityDB.SETS - 1)
	_player.abilities.changed.emit()
	# Relics: take off what is not in the set, then wear what is.
	var wanted: Array = data.get("relics", [])
	for relic in _player.relics.worn.duplicate():
		if not relic.uid in wanted:
			_player.relics.take_off(relic)
	for uid: Variant in wanted:
		for relic in _player.relics.bag.duplicate():
			if relic.uid == int(uid):
				_player.relics.wear(relic)
	current = index
	SaveGame.request_save()
	changed.emit()
	Events.announcement.emit("SET %d" % (index + 1), "%d piece%s not found" % [missing, "" if missing == 1 else "s"] if missing > 0 else "Gear, abilities and relics changed")
	return ""


## The next saved set after the one worn last (for the loadout key).
func wear_next() -> String:
	for step in range(1, SLOTS + 1):
		var index := posmod(current + step, SLOTS)
		if not is_empty(index):
			return wear_set(index)
	return "No sets saved yet. Save one in the inventory."


func _find(uid: int) -> Item:
	if uid == 0:
		return null
	for item in _player.inventory.items:
		if item and item.uid == uid:
			return item
	for item: Item in _player.equipment.equipped.values():
		if item and item.uid == uid:
			return item
	return null


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("loadout_next") and not _player.is_dead() and not get_tree().paused:
		var problem := wear_next()
		if problem != "":
			DamageNumber.spawn_text(_player.get_parent(), _player.global_position + Vector2(0, -50), problem, UITheme.BAD, 13)
		get_viewport().set_input_as_handled()


func save_data() -> Dictionary:
	return {"sets": sets.duplicate(true), "current": current}


func load_data(data: Dictionary) -> void:
	sets = [{}, {}, {}]
	var saved: Variant = data.get("sets", [])
	if saved is Array:
		for index in mini((saved as Array).size(), SLOTS):
			if saved[index] is Dictionary:
				sets[index] = (saved[index] as Dictionary).duplicate(true)
	current = clampi(int(data.get("current", -1)), -1, SLOTS - 1)
	changed.emit()
