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
## Blacksmith upgrade level; each adds ItemDB.UPGRADE_POWER to base power.
var upgrade := 0
## The enchantment on this item: one modifier {"stat", "kind", "value"}, or empty.
var enchant: Dictionary = {}
## Gem ids set into this item; "" is an empty socket.
var sockets: Array[String] = []
## The named set this piece belongs to (ItemDB.ITEM_SETS), or "".
var set_id := ""


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
	var saved_enchant: Variant = data.get("enchant", {})
	if saved_enchant is Dictionary and saved_enchant.has("stat") and saved_enchant.has("value"):
		item.enchant = {
			"stat": str(saved_enchant["stat"]),
			"kind": str(saved_enchant.get("kind", "flat")),
			"value": float(saved_enchant["value"]),
		}
	var saved_sockets: Variant = data.get("sockets", [])
	if saved_sockets is Array:
		for gem: Variant in saved_sockets:
			item.sockets.append(str(gem) if ItemDB.ITEMS.has(str(gem)) else "")
	item.set_id = str(data.get("set", "")) if ItemDB.ITEM_SETS.has(str(data.get("set", ""))) else ""
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
	var data := {"id": id, "rarity": rarity, "level": level, "upgrade": upgrade, "mods": mods.duplicate(true), "enchant": enchant.duplicate()}
	if not sockets.is_empty():
		data["sockets"] = sockets.duplicate()
	if set_id != "":
		data["set"] = set_id
	return data


func definition() -> Dictionary:
	return ItemDB.ITEMS[id]


func is_equipment() -> bool:
	return definition().has("slot")


func is_tool() -> bool:
	return definition().has("tool")


func is_consumable() -> bool:
	return definition().has("use") or definition().has("boat") or definition().has("treasure_map") or Crops.by_seed(id) != ""


## Things that are set down in the world rather than used up.
func is_placeable() -> bool:
	return definition().has("place")


func is_stackable() -> bool:
	return not is_equipment() and not is_tool()


## Colour to tint the icon with (white for icons drawn in their own colours).
func tint() -> Color:
	return definition().get("tint", Color.WHITE)


## What a merchant charges for one of this item, in gold.
func value() -> int:
	var def := definition()
	if def.has("value"):
		return def["value"]
	if is_equipment():
		var worth := (10.0 + level * 6.0) * pow(1.0 + rarity * 0.8, 1.5) * (1.0 + 0.15 * upgrade)
		return roundi(worth * (1.6 if def.get("two_handed", false) or slot() == "chest" else 1.0))
	if is_tool():
		return 60 * int(def["tool"]["tier"]) * int(def["tool"]["tier"])
	var by_rarity: Array[int] = [4, 12, 40, 120, 400, 1200]
	return by_rarity[rarity] * (5 if is_consumable() else 1)


## Whether a blacksmith can upgrade this: it must have damage or armour.
func is_upgradable() -> bool:
	return definition().has("damage") or definition().has("armor")


## "main_hand", "ring", "chest"... or "" for materials.
func slot() -> String:
	return definition().get("slot", "")


func display_name() -> String:
	var def := definition()
	var text: String = def["name"]
	if set_id != "":
		text = "%s %s" % [ItemDB.ITEM_SETS[set_id]["name"], text]
	elif def.get("tiered", false):
		text = "%s %s" % [ItemDB.tier_name(level), text]
	return "%s +%d" % [text, upgrade] if upgrade > 0 else text


func color() -> Color:
	return ItemDB.SET_COLOR if set_id != "" else ItemDB.RARITIES[rarity]["color"]


func is_unique() -> bool:
	return definition().has("unique")


func icon() -> Texture2D:
	if definition().has("flora"):
		return Flora.small_texture(definition()["flora"])
	if definition().has("decor"):
		return Prop.decor_icon(definition()["decor"])
	return ItemDB.icon(definition()["icon"])


## Base damage or armor at this item's level and rarity.
func base_power(key: String) -> float:
	var base: float = definition().get(key, 0.0)
	var power: float = base * (1.0 + ItemDB.POWER_PER_LEVEL * (level - 1)) * ItemDB.RARITIES[rarity]["power"]
	# Each upgrade is worth at least one point, so it shows on weak items too.
	return roundf(maxf(power * (1.0 + ItemDB.UPGRADE_POWER * upgrade), roundf(power) + upgrade))


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
	if not enchant.is_empty():
		result.append(enchant)
	for gem in sockets:
		if gem != "":
			result.append(Gems.modifier(gem, slot()))
	return result


## Attribute points needed to equip: {"strength": 14, ...}.
func attribute_requirements() -> Dictionary:
	var result := {}
	var requires: Dictionary = definition().get("requires", {})
	for attribute: String in requires:
		result[attribute] = roundi(requires[attribute][0] + requires[attribute][1] * level)
	return result
