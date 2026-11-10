class_name Item
extends RefCounted
## One item or stack of items: a base id from ItemDB plus what was rolled.

var id := ""
var count := 1
## Index into ItemDB.RARITIES.
var rarity := 0
## Item level: scales base power and sets the level requirement.
var level := 1
## Random modifiers: [{"stat", "kind", "value"}].
var mods: Array[Dictionary] = []
## Blacksmith upgrade level (not used yet).
var upgrade := 0


static func create(item_id: String, p_count: int = 1) -> Item:
	var item := Item.new()
	item.id = item_id
	item.count = p_count
	item.rarity = int(ItemDB.ITEMS[item_id].get("material_rarity", 0))
	return item


## Returns null for an id that no longer exists.
static func from_dict(data: Dictionary) -> Item:
	var item_id := str(data.get("id", ""))
	if not ItemDB.ITEMS.has(item_id):
		return null
	var item := Item.new()
	item.id = item_id
	item.count = maxi(int(data.get("count", 1)), 1)
	item.rarity = clampi(int(data.get("rarity", 0)), 0, ItemDB.RARITIES.size() - 1)
	item.level = maxi(int(data.get("level", 1)), 1)
	item.upgrade = maxi(int(data.get("upgrade", 0)), 0)
	var saved_mods: Variant = data.get("mods", [])
	if saved_mods is Array:
		for mod: Variant in saved_mods:
			if mod is Dictionary and mod.has("stat") and mod.has("value"):
				item.mods.append({
					"stat": str(mod["stat"]),
					"kind": str(mod.get("kind", "flat")),
					"value": float(mod["value"]),
				})
	return item


func to_dict() -> Dictionary:
	if not is_equipment():
		return {"id": id, "count": count}
	return {"id": id, "rarity": rarity, "level": level, "upgrade": upgrade, "mods": mods.duplicate(true)}


func definition() -> Dictionary:
	return ItemDB.ITEMS[id]


func is_equipment() -> bool:
	return definition().has("slot")


func is_stackable() -> bool:
	return not is_equipment()


## "main_hand", "ring", "chest"... or "" for materials.
func slot() -> String:
	return definition().get("slot", "")


func display_name() -> String:
	var def := definition()
	if def.get("tiered", false):
		return "%s %s" % [ItemDB.tier_name(level), def["name"]]
	return def["name"]


func color() -> Color:
	return ItemDB.RARITIES[rarity]["color"]


func icon() -> Texture2D:
	return ItemDB.icon(definition()["icon"])


## Base damage or armor at this item's level and rarity.
func base_power(key: String) -> float:
	var base: float = definition().get(key, 0.0)
	return roundf(base * (1.0 + ItemDB.POWER_PER_LEVEL * (level - 1)) * ItemDB.RARITIES[rarity]["power"])


## Modifiers every copy of this item has (not the random ones).
func implicit_modifiers() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for implicit: Dictionary in definition().get("implicit", []):
		var value: float = implicit["base"] + implicit["per_level"] * level
		# Whole numbers for things like health; fractions stay for percentages.
		if implicit["base"] >= 1.0:
			value = roundf(value)
		result.append({"stat": implicit["stat"], "kind": implicit["kind"], "value": value})
	return result


## Everything this item changes when equipped.
func all_modifiers() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if definition().has("damage"):
		result.append({"stat": "physical_damage", "kind": "flat", "value": base_power("damage")})
	if definition().has("armor"):
		result.append({"stat": "armor", "kind": "flat", "value": base_power("armor")})
	result.append_array(implicit_modifiers())
	result.append_array(mods)
	return result


## Attribute points needed to equip: {"strength": 14, ...}.
func attribute_requirements() -> Dictionary:
	var result := {}
	var requires: Dictionary = definition().get("requires", {})
	for attribute: String in requires:
		result[attribute] = roundi(requires[attribute][0] + requires[attribute][1] * level)
	return result
