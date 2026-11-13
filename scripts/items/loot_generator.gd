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
	item.rarity = maxi(rarity, int(ItemDB.ITEMS[item.id].get("min_rarity", 0)))
	rarity = item.rarity
	item.set_id = str(ItemDB.ITEMS[item.id].get("set", ""))
	if ItemDB.ITEMS[item.id].has("unique"):
		item.rarity = 4
		rarity = 4
	for index in Gems.roll_sockets(rarity):
		item.sockets.append("")

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
		# Rarer gear rolls bigger bonuses, not just more of them.
		var value: float = (affix["base"] + affix["per_level"] * item.level) * randf_range(worst_roll, 1.0) * ItemDB.RARITIES[rarity]["affix"]
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

	# Each modifier on an Elite or Champion sweetens what it drops.
	var bonus: float = (1.0 + Enemy.REWARD_PER_MODIFIER * info.get("modifiers", 0)) * float(Difficulty.value("loot")) * (2.0 if DayNight.blood_moon else 1.0)
	var gold: float = randf_range(table["gold"][0], table["gold"][1]) * pow(level, 0.9) * rank["gold"] * bonus
	result["gold"] = maxi(roundi(gold), 1)

	for entry: Dictionary in table["materials"]:
		var chance: float = entry["chance"] * rank["materials"] * (1.0 + magic_find)
		if randf() < chance:
			items.append(Item.create_rolled(entry["id"], randi_range(entry["count"][0], entry["count"][1])))

	if info["rank"] == "miniboss":
		items.append(Item.create("heart_shard"))
	var extra := roll_special(level, info["rank"], magic_find, bonus)
	if extra:
		items.append(extra)
	# Gems from the tougher monsters.
	if randf() < {"normal": 0.004, "elite": 0.06, "champion": 0.2, "miniboss": 0.6}.get(info["rank"], 0.0) * (1.0 + magic_find):
		items.append(Item.create(Gems.random_gem(level)))
	# Gear is what that kind of monster would carry, and rare from the
	# rank and file; Elites and above drop it far more readily.
	for entry: Array in table.get("gear", []):
		if randf() < minf(entry[1] * rank["equipment_chance"], 1.0):
			var base: String = entry[0]
			var rarity := maxi(roll_rarity(magic_find, rank["rarity_bonus"] * bonus), ItemDB.ITEMS[base].get("min_rarity", 0))
			items.append(make_equipment(level, rarity, base, magic_find))
			break
	return result


## Chance of a set piece and of a unique, by rank.
const SET_CHANCE := {"normal": 0.0, "elite": 0.006, "champion": 0.05, "miniboss": 0.25, "boss": 0.6}
const UNIQUE_CHANCE := {"normal": 0.0, "elite": 0.002, "champion": 0.015, "miniboss": 0.06, "boss": 0.25}


## A set piece or a unique, now and then. Returns null most of the time.
static func roll_special(level: int, rank: String, magic_find: float = 0.0, bonus: float = 1.0) -> Item:
	var luck := (1.0 + magic_find) * bonus
	if randf() < UNIQUE_CHANCE.get(rank, 0.0) * luck:
		return make_unique(level)
	if randf() < SET_CHANCE.get(rank, 0.0) * luck:
		return make_set_piece(level)
	return null


static func unique_ids() -> Array[String]:
	var ids: Array[String] = []
	for item_id: String in ItemDB.ITEMS:
		if ItemDB.ITEMS[item_id].has("unique"):
			ids.append(item_id)
	return ids


static func make_unique(level: int, item_id: String = "") -> Item:
	var ids := unique_ids()
	return make_equipment(level, 4, item_id if item_id != "" else ids[randi() % ids.size()])


## A piece of a named set at Epic power. Leave set_id empty for any set.
static func make_set_piece(level: int, set_id: String = "") -> Item:
	var sets: Array = ItemDB.ITEM_SETS.keys()
	var chosen: String = set_id if set_id != "" else sets[randi() % sets.size()]
	var pieces: Array = ItemDB.ITEM_SETS[chosen]["pieces"]
	var item := make_equipment(level, 3, pieces[randi() % pieces.size()])
	item.set_id = chosen
	return item


static func _random_base(rarity: int) -> String:
	var ids: Array[String] = []
	var total := 0.0
	for item_id: String in ItemDB.ITEMS:
		var def: Dictionary = ItemDB.ITEMS[item_id]
		if def.has("slot") and rarity >= def.get("min_rarity", 0) and def.get("drop_weight", 1.0) > 0.0:
			ids.append(item_id)
			total += def["drop_weight"]
	var roll := randf() * total
	for item_id in ids:
		roll -= ItemDB.ITEMS[item_id]["drop_weight"]
		if roll <= 0.0:
			return item_id
	return ids[0]
