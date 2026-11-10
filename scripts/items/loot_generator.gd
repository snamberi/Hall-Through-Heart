class_name LootGenerator
extends RefCounted
## Rolls random equipment and enemy drops.


## Picks a rarity index. Magic find and `bonus` make better rarities likelier.
static func roll_rarity(magic_find: float = 0.0, bonus: float = 0.0) -> int:
	var weights: Array[float] = []
	var total := 0.0
	for index in ItemDB.RARITIES.size():
		var weight: float = ItemDB.RARITIES[index]["weight"]
		if index > 0:
			weight *= 1.0 + magic_find + bonus
		weights.append(weight)
		total += weight
	var roll := randf() * total
	for index in weights.size():
		roll -= weights[index]
		if roll <= 0.0:
			return index
	return 0


## Creates a piece of equipment. Leave `base_id` empty for a random type.
static func make_equipment(
	level: int, rarity: int, base_id: String = "", magic_find: float = 0.0
) -> Item:
	var item := Item.new()
	item.id = base_id if base_id != "" else _random_base(rarity)
	item.level = maxi(level, 1)
	item.rarity = rarity

	var slot := item.slot()
	var pool: Array[Dictionary] = []
	for affix in ItemDB.AFFIXES:
		if not affix.has("slots") or slot in affix["slots"]:
			pool.append(affix)
	pool.shuffle()
	# Luck lifts the worst possible roll, so bonuses come out stronger.
	var worst_roll := 0.6 + minf(magic_find, 1.0) * 0.2
	for index in mini(ItemDB.RARITIES[rarity]["mods"], pool.size()):
		var affix := pool[index]
		var value: float = (affix["base"] + affix["per_level"] * item.level) * randf_range(worst_roll, 1.0)
		if affix["kind"] == "flat" and affix["base"] >= 1.0:
			value = maxf(roundf(value), 1.0)
		else:
			value = snappedf(value, 0.001)
		item.mods.append({"stat": affix["stat"], "kind": affix["kind"], "value": value})
	return item


## Rolls what an enemy leaves behind. `info` is the Events.enemy_killed payload.
## Returns {"gold": int, "items": Array[Item]}.
static func roll_enemy_drops(info: Dictionary, magic_find: float = 0.0) -> Dictionary:
	var items: Array[Item] = []
	var result := {"gold": 0, "items": items}
	# Pieces of a split enemy drop nothing, so splitting is not a loot farm.
	if info.get("fragment", false):
		return result
	var table: Dictionary = ItemDB.LOOT_TABLES.get(info["id"], ItemDB.LOOT_TABLES["husk"])
	var rank: Dictionary = ItemDB.RANK_LOOT.get(info["rank"], ItemDB.RANK_LOOT["normal"])
	var level: int = info["level"]

	var gold: float = randf_range(table["gold"][0], table["gold"][1]) * pow(level, 0.9) * rank["gold"]
	result["gold"] = maxi(roundi(gold), 1)

	for entry: Dictionary in table["materials"]:
		var chance: float = entry["chance"] * rank["materials"] * (1.0 + magic_find)
		if randf() < chance:
			items.append(Item.create(entry["id"], randi_range(entry["count"][0], entry["count"][1])))

	if randf() < table["equipment_chance"] * rank["equipment_chance"]:
		var rarity := roll_rarity(magic_find, rank["rarity_bonus"])
		items.append(make_equipment(level, rarity, "", magic_find))
	return result


static func _random_base(rarity: int) -> String:
	var ids: Array[String] = []
	var total := 0.0
	for item_id: String in ItemDB.ITEMS:
		var def: Dictionary = ItemDB.ITEMS[item_id]
		if def.has("slot") and rarity >= def.get("min_rarity", 0):
			ids.append(item_id)
			total += def["drop_weight"]
	var roll := randf() * total
	for item_id in ids:
		roll -= ItemDB.ITEMS[item_id]["drop_weight"]
		if roll <= 0.0:
			return item_id
	return ids[0]
