class_name Equipment
extends Node
## What the player is wearing and wielding.

signal changed

## slot id -> Item, only for filled slots.
var equipped: Dictionary[String, Item] = {}

var _inventory: Inventory
var _leveling: Leveling
var _attributes: Attributes


func _ready() -> void:
	SaveGame.register("equipment", self)


func setup(inventory: Inventory, leveling: Leveling, attributes: Attributes) -> void:
	_inventory = inventory
	_leveling = leveling
	_attributes = attributes


func get_item(slot: String) -> Item:
	return equipped.get(slot)


## Why an item cannot be equipped, or "" if it can.
func cannot_equip_reason(item: Item) -> String:
	if not item.is_equipment():
		return "This cannot be equipped."
	if _leveling.level < item.level:
		return "Requires level %d." % item.level
	var requirements := item.attribute_requirements()
	for attribute: String in requirements:
		if _attributes.points[attribute] < requirements[attribute]:
			return "Requires %d %s." % [requirements[attribute], Attributes.NAMES[attribute]]
	return ""


## The slot an item would go into right now ("ring" picks a free ring slot).
func target_slot(item: Item) -> String:
	if item.slot() != "ring":
		return item.slot()
	return "ring_2" if equipped.has("ring_1") and not equipped.has("ring_2") else "ring_1"


## Moves an item from the bag into its slot; whatever it replaces goes back
## into the bag. Returns "" on success or the reason it failed.
func equip(item: Item) -> String:
	var reason := cannot_equip_reason(item)
	if reason != "":
		return reason
	var slot := target_slot(item)
	var displaced: Array[String] = []
	if equipped.has(slot):
		displaced.append(slot)
	# A two-handed weapon leaves no hand for a shield, and the reverse.
	if item.definition().get("two_handed", false) and equipped.has("off_hand"):
		displaced.append("off_hand")
	if slot == "off_hand" and equipped.has("main_hand") and equipped["main_hand"].definition().get("two_handed", false):
		displaced.append("main_hand")
	# The item leaving the bag frees one slot.
	if _inventory.free_slots() + 1 < displaced.size():
		return "Inventory is full."

	_inventory.items.erase(item)
	for old_slot in displaced:
		_inventory.items.append(equipped[old_slot])
		equipped.erase(old_slot)
	equipped[slot] = item
	_inventory.changed.emit()
	_emit_changed()
	return ""


## Moves an equipped item back to the bag. Returns "" or the failure reason.
func unequip(slot: String) -> String:
	if not equipped.has(slot):
		return ""
	if _inventory.free_slots() <= 0:
		return "Inventory is full."
	var item := equipped[slot]
	equipped.erase(slot)
	_inventory.add(item)
	_emit_changed()
	return ""


## Puts an item straight into its slot without touching the bag.
func equip_directly(item: Item) -> void:
	equipped[target_slot(item)] = item
	_emit_changed()


## Attack profile of the weapon in hand, or bare hands.
func weapon_profile() -> Dictionary:
	var weapon := get_item("main_hand")
	return weapon.definition()["weapon"] if weapon else ItemDB.UNARMED


## Everything equipped, summed as stat id -> {"flat", "percent"} for CharacterStats.
func modifiers() -> Dictionary:
	var totals := {}
	for item: Item in equipped.values():
		for modifier in item.all_modifiers():
			var stat: String = modifier["stat"]
			if not totals.has(stat):
				totals[stat] = {"flat": 0.0, "percent": 0.0}
			totals[stat][modifier["kind"]] += modifier["value"]
	var bonus: Dictionary = set_bonus()
	for stat: String in bonus:
		if not totals.has(stat):
			totals[stat] = {"flat": 0.0, "percent": 0.0}
		for kind: String in bonus[stat]:
			totals[stat][kind] += bonus[stat][kind]
	return totals


## The most armour pieces worn from one tier: {"tier": name, "count": n}.
func set_progress() -> Dictionary:
	var counts := {}
	for slot in ItemDB.SET_SLOTS:
		var item := get_item(slot)
		if item and item.definition().get("tiered", false):
			var tier := ItemDB.tier_name(item.level)
			counts[tier] = counts.get(tier, 0) + 1
	var best := {"tier": "", "count": 0}
	for tier: String in counts:
		if counts[tier] > best["count"]:
			best = {"tier": tier, "count": counts[tier]}
	return best


## Stat modifiers from the set bonus currently earned.
func set_bonus() -> Dictionary:
	var count: int = set_progress()["count"]
	var earned := {}
	for needed: int in ItemDB.SET_BONUSES:
		if count >= needed:
			earned = ItemDB.SET_BONUSES[needed]
	return earned


func save_data() -> Dictionary:
	var data := {}
	for slot in equipped:
		data[slot] = equipped[slot].to_dict()
	return data


func load_data(data: Dictionary) -> void:
	equipped.clear()
	for slot in ItemDB.SLOTS:
		var saved: Variant = data.get(slot)
		if saved is Dictionary:
			var item := Item.from_dict(saved)
			if item and item.is_equipment():
				equipped[slot] = item


func _emit_changed() -> void:
	changed.emit()
	SaveGame.request_save()
