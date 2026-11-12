class_name Equipment
extends Node
## What the player is wearing, and what hangs on their belt.
##
## Armour and trinkets are worn in ItemDB.SLOTS, plus a backpack. Weapons
## and tools live on the belt (the first six hotbar slots): one magic
## weapon, two other weapons, a pickaxe, a hatchet and a fishing rod. Only
## the belt item in hand counts; "main_hand" is another name for whichever
## weapon that is.

signal changed

const WEAPON_SLOTS: Array[String] = ["weapon_1", "weapon_2", "weapon_3"]
const TOOL_SLOTS := {"pickaxe": "tool_pickaxe", "hatchet": "tool_hatchet", "rod": "tool_rod"}
## Belt slots in hotbar order.
const BELT: Array[String] = ["weapon_1", "weapon_2", "weapon_3", "tool_pickaxe", "tool_hatchet", "tool_rod"]
const BELT_NAMES := {"weapon_1": "Magic", "weapon_2": "Weapon", "weapon_3": "Weapon", "tool_pickaxe": "Pickaxe",
	"tool_hatchet": "Hatchet", "tool_rod": "Fishing rod", "backpack": "Backpack"}
## Worn slots, the belt, and the backpack: everything that can hold an item.
const ALL_SLOTS: Array[String] = ["off_hand", "helmet", "chest", "legs", "boots", "necklace", "ring_1", "ring_2", "artifact",
	"weapon_1", "weapon_2", "weapon_3", "tool_pickaxe", "tool_hatchet", "tool_rod", "backpack"]

## slot id -> Item, only for filled slots.
var equipped: Dictionary[String, Item] = {}
## The belt slot in hand.
var active_slot := "weapon_2"
## A tool taken in hand for a job (mining, chopping), shown instead of the
## belt item until the job is done.
var working_tool: Item

var _inventory: Inventory
var _leveling: Leveling
var _attributes: Attributes


func _ready() -> void:
	SaveGame.register("equipment", self)


func setup(inventory: Inventory, leveling: Leveling, attributes: Attributes) -> void:
	_inventory = inventory
	_leveling = leveling
	_attributes = attributes
	_inventory.bonus_slots = bag_slots()
	stow_loose_tools()


## Tools carried loose in the bag go onto empty belt slots (new characters,
## and saves from before the belt).
func stow_loose_tools() -> void:
	var moved := false
	for kind: String in TOOL_SLOTS:
		var spare := _inventory.best_tool(kind)
		if spare and not equipped.has(TOOL_SLOTS[kind]):
			_inventory.items.erase(spare)
			equipped[TOOL_SLOTS[kind]] = spare
			moved = true
	if moved:
		_inventory.changed.emit()
		changed.emit()


func get_item(slot: String) -> Item:
	if slot == "main_hand":
		return weapon()
	return equipped.get(slot)


## The weapon in hand, or null when the hand holds a tool or nothing.
func weapon() -> Item:
	return equipped.get(active_slot) if active_slot in WEAPON_SLOTS else null


## Whatever is in hand to look at: a tool at work, or the belt item.
func in_hand() -> Item:
	return working_tool if working_tool else equipped.get(active_slot)


## The best tool of a kind the player owns, on the belt or in the bag.
func tool(kind: String) -> Item:
	var best: Item = equipped.get(TOOL_SLOTS.get(kind, ""))
	var spare := _inventory.best_tool(kind)
	if spare and (best == null or spare.definition()["tool"]["tier"] > best.definition()["tool"]["tier"]):
		best = spare
	return best


## Extra bag slots from the backpack worn.
func bag_slots() -> int:
	var pack: Item = equipped.get("backpack")
	return int(pack.definition()["backpack"]) if pack else 0


## Takes a belt slot's item in hand. False if the slot is empty.
func select(slot: String) -> bool:
	if not slot in BELT or not equipped.has(slot):
		return false
	working_tool = null
	if active_slot != slot:
		active_slot = slot
		_emit_changed()
	return true


## Why an item cannot be equipped, or "" if it can.
func cannot_equip_reason(item: Item) -> String:
	if item.is_tool() or item.is_backpack():
		return ""
	if not item.is_equipment():
		return "This cannot be equipped."
	if _leveling.level < item.level:
		return "Requires level %d." % item.level
	var requirements := item.attribute_requirements()
	for attribute: String in requirements:
		if _attributes.points[attribute] < requirements[attribute]:
			return "Requires %d %s." % [requirements[attribute], Attributes.NAMES[attribute]]
	return ""


## Whether an item belongs in a slot.
func fits(item: Item, slot: String) -> bool:
	if item.is_tool():
		return slot == TOOL_SLOTS.get(item.definition()["tool"]["kind"], "")
	if item.is_backpack():
		return slot == "backpack"
	if item.slot() == "main_hand":
		return slot in WEAPON_SLOTS and (slot == "weapon_1") == bool(item.definition().get("magic", false))
	if item.slot() == "ring":
		return slot in ["ring_1", "ring_2"]
	return slot == item.slot()


## The slot an item would go into right now: a free ring finger, a free
## place on the belt, the magic slot for a staff.
func target_slot(item: Item) -> String:
	if item.is_tool():
		return TOOL_SLOTS.get(item.definition()["tool"]["kind"], "tool_pickaxe")
	if item.is_backpack():
		return "backpack"
	if item.slot() == "main_hand":
		if item.definition().get("magic", false):
			return "weapon_1"
		for candidate: String in ["weapon_2", "weapon_3"]:
			if not equipped.has(candidate):
				return candidate
		return active_slot if active_slot in ["weapon_2", "weapon_3"] else "weapon_2"
	if item.slot() != "ring":
		return item.slot()
	return "ring_2" if equipped.has("ring_1") and not equipped.has("ring_2") else "ring_1"


## Which slot holds an item, or "".
func slot_of(item: Item) -> String:
	for slot in equipped:
		if equipped[slot] == item:
			return slot
	return ""


## Moves an item from the bag into a slot (its usual one unless `into` is
## given); whatever it replaces goes back into the bag. Returns "" on
## success or the reason it failed.
func equip(item: Item, into: String = "") -> String:
	var reason := cannot_equip_reason(item)
	if reason != "":
		return reason
	var slot := into if into != "" else target_slot(item)
	if not fits(item, slot):
		return "Slot 1 is for staves and other magic." if slot == "weapon_1" else "That does not go there."
	if slot == "backpack" and equipped.has(slot) and _inventory.items.size() > Inventory.BASE + int(item.definition()["backpack"]):
		return "Too much in the bag for a smaller pack."
	# One out of the bag, at most one back in: there is always room.
	_inventory.items.erase(item)
	if equipped.has(slot):
		_inventory.items.append(equipped[slot])
	equipped[slot] = item
	if slot in WEAPON_SLOTS:
		active_slot = slot
		working_tool = null
	_inventory.bonus_slots = bag_slots()
	_inventory.changed.emit()
	_emit_changed()
	return ""


## Moves an equipped item back to the bag. Returns "" or the failure reason.
func unequip(slot: String) -> String:
	if slot == "main_hand":
		slot = active_slot
	if not equipped.has(slot):
		return ""
	if slot == "backpack":
		if _inventory.items.size() + 1 > Inventory.BASE:
			return "Empty the pack's pockets first."
	elif _inventory.free_slots() <= 0:
		return "Inventory is full."
	var item := equipped[slot]
	equipped.erase(slot)
	_inventory.bonus_slots = bag_slots()
	_inventory.add(item)
	_emit_changed()
	return ""


## Puts an item straight into its slot without touching the bag.
func equip_directly(item: Item) -> void:
	var slot := target_slot(item)
	equipped[slot] = item
	if slot in WEAPON_SLOTS:
		active_slot = slot
	_inventory.bonus_slots = bag_slots()
	_emit_changed()


## Attack profile of the weapon in hand, or bare hands.
func weapon_profile() -> Dictionary:
	var held := weapon()
	return held.definition()["weapon"] if held else ItemDB.UNARMED


## Everything whose stats count now: what is worn, and the weapon in hand.
## Sheathed weapons, tools and the backpack give nothing; nor does a shield
## while both hands are on the weapon.
func counted() -> Array[Item]:
	var result: Array[Item] = []
	var held := weapon()
	var two_handed: bool = held != null and held.definition().get("two_handed", false)
	for slot in equipped:
		if slot == "backpack" or (slot in BELT and (slot != active_slot or not slot in WEAPON_SLOTS)):
			continue
		if slot == "off_hand" and two_handed:
			continue
		result.append(equipped[slot])
	return result


## Everything equipped, summed as stat id -> {"flat", "percent"} for CharacterStats.
func modifiers() -> Dictionary:
	var totals := {}
	for item: Item in counted():
		for modifier in item.all_modifiers():
			var stat: String = modifier["stat"]
			if not totals.has(stat):
				totals[stat] = {"flat": 0.0, "percent": 0.0}
			totals[stat][modifier["kind"]] += modifier["value"]
	var bonuses: Array = [set_bonus(), attunement().get("mods", {})]
	var named := named_set_counts()
	for set_id: String in named:
		for needed: int in ItemDB.ITEM_SETS[set_id]["bonuses"]:
			if named[set_id] >= needed:
				bonuses.append(ItemDB.ITEM_SETS[set_id]["bonuses"][needed])
	for bonus: Dictionary in bonuses:
		for stat: String in bonus:
			if not totals.has(stat):
				totals[stat] = {"flat": 0.0, "percent": 0.0}
			for kind: String in bonus[stat]:
				totals[stat][kind] += bonus[stat][kind]
	return totals


## The rarity attunement earned: {"rarity", "name", "mods", "count"} for the
## best rarity with enough pieces worn at that rarity or better, or {}.
func attunement() -> Dictionary:
	var worn := counted()
	for rarity: int in [5, 4, 3, 2]:
		var count := 0
		for item in worn:
			if item.rarity >= rarity:
				count += 1
		if count >= ItemDB.ATTUNE_PIECES:
			var found: Dictionary = (ItemDB.ATTUNEMENTS[rarity] as Dictionary).duplicate()
			found["rarity"] = rarity
			found["count"] = count
			return found
	return {}


## How many pieces of each named set are worn: {"gravewarden": 3}.
func named_set_counts() -> Dictionary:
	var counts := {}
	for item: Item in counted():
		if item.set_id != "":
			counts[item.set_id] = counts.get(item.set_id, 0) + 1
	return counts


## The unique effect ids of everything worn.
func unique_effects() -> Array[String]:
	var effects: Array[String] = []
	for item: Item in counted():
		if item.is_unique():
			effects.append(item.definition()["unique"])
	return effects


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
	var data := {"active_slot": active_slot}
	for slot in equipped:
		data[slot] = equipped[slot].to_dict()
	return data


func load_data(data: Dictionary) -> void:
	equipped.clear()
	working_tool = null
	for slot in ALL_SLOTS:
		var saved: Variant = data.get(slot)
		if saved is Dictionary:
			var item := Item.from_dict(saved)
			if item and (item.is_equipment() or item.is_tool() or item.is_backpack()):
				equipped[slot] = item
	# Saves from before the belt kept one weapon in "main_hand".
	var old: Variant = data.get("main_hand")
	if old is Dictionary:
		var item := Item.from_dict(old)
		if item and item.is_equipment():
			equipped["weapon_1" if item.definition().get("magic", false) else "weapon_2"] = item
	active_slot = str(data.get("active_slot", "weapon_2"))
	if not equipped.has(active_slot):
		for slot in WEAPON_SLOTS:
			if equipped.has(slot):
				active_slot = slot
	if _inventory:
		_inventory.bonus_slots = bag_slots()


func _emit_changed() -> void:
	changed.emit()
	SaveGame.request_save()
