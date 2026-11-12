class_name Crafting
extends RefCounted
## Making things: recipes, and the three things done to existing equipment
## (upgrading, enchanting, salvaging). Every function returns "" on success
## or the reason it could not be done.

const ENCHANT_SLOTS: Array[String] = ["main_hand", "off_hand", "helmet", "chest", "legs", "boots", "necklace", "ring", "artifact"]


## Why a recipe cannot be made right now, or "".
static func blocked_reason(player: Player, recipe: Dictionary) -> String:
	if not recipe["id"] in RecipeDB.NO_TABLE and not player.near_crafting_table():
		return "Stand next to a crafting table."
	if player.professions.level(recipe["profession"]) < recipe["level"]:
		return "Requires %s %d." % [Professions.NAMES[recipe["profession"]], recipe["level"]]
	for item_id: String in recipe["inputs"]:
		if player.inventory.count_of(item_id) < recipe["inputs"][item_id]:
			return "Not enough %s." % ItemDB.ITEMS[item_id]["name"]
	if player.inventory.free_slots() <= 0:
		return "Inventory is full."
	return ""


## How likely a cook of this level makes a spare serving.
static func extra_serving_chance(cooking_level: int) -> float:
	return clampf(cooking_level * 0.006, 0.0, 0.6)


static func craft(player: Player, recipe: Dictionary) -> String:
	var reason := blocked_reason(player, recipe)
	if reason != "":
		return reason
	for item_id: String in recipe["inputs"]:
		player.inventory.take(item_id, recipe["inputs"][item_id])
	var skill := player.professions.level(recipe["profession"])
	var made: Item
	if recipe.has("equipment"):
		# A better smith is likelier to turn out something special.
		var rarity := LootGenerator.roll_rarity(player.stats.get_stat("magic_find"), skill / 20.0)
		made = LootGenerator.make_equipment(recipe["item_level"], rarity, recipe["equipment"], skill / 100.0)
	else:
		made = Item.create(recipe["item"], recipe["count"])
		# A practised cook stretches a pot further: a chance of a spare serving.
		if recipe["profession"] == "cooking" and randf() < extra_serving_chance(skill):
			made.count += recipe["count"]
			DamageNumber.spawn_text(player.get_parent(), player.global_position + Vector2(0, -56), "An extra serving!", UITheme.GOOD, 13)
	player.inventory.add(made)
	player.professions.add_xp(recipe["profession"], recipe["xp"])
	Events.item_crafted.emit(recipe["id"])
	return ""


# --- upgrading (blacksmithing)

## {"ingot": id, "ingots": n, "gold": n, "level": smithing level needed}.
static func upgrade_cost(item: Item) -> Dictionary:
	var tier := ItemDB.tier_start(item.level)
	return {
		"ingot": ItemDB.tier_ingot(item.level),
		"ingots": item.upgrade + 1,
		"gold": 20 * item.level * (item.upgrade + 1),
		"level": mini(tier, Professions.MAX_LEVEL),
	}


static func upgrade(player: Player, item: Item) -> String:
	if not item.is_equipment() or not item.is_upgradable():
		return "This cannot be upgraded."
	if item.upgrade >= ItemDB.MAX_UPGRADE:
		return "Already fully upgraded."
	var cost := upgrade_cost(item)
	if player.professions.level("blacksmithing") < cost["level"]:
		return "Requires Blacksmithing %d." % cost["level"]
	if player.inventory.gold < cost["gold"]:
		return "Costs %d gold." % cost["gold"]
	if not player.inventory.take(cost["ingot"], cost["ingots"]):
		return "Needs %d %s." % [cost["ingots"], ItemDB.ITEMS[cost["ingot"]]["name"]]
	player.inventory.add_gold(-cost["gold"])
	item.upgrade += 1
	player.professions.add_xp("blacksmithing", 15.0 + item.level * 2.0)
	_item_changed(player)
	return ""


# --- enchanting

## {"dust": n, "essence": n, "level": enchanting level needed}.
static func enchant_cost(item: Item) -> Dictionary:
	return {"dust": 2 + item.rarity, "essence": 1, "level": mini(ItemDB.tier_start(item.level), Professions.MAX_LEVEL)}


## Puts a random enchantment on an item, replacing any it already has.
static func enchant(player: Player, item: Item) -> String:
	if not item.is_equipment():
		return "This cannot be enchanted."
	var cost := enchant_cost(item)
	if player.professions.level("enchanting") < cost["level"]:
		return "Requires Enchanting %d." % cost["level"]
	if player.inventory.count_of("enchanted_dust") < cost["dust"] or player.inventory.count_of("essence") < cost["essence"]:
		return "Needs %d Enchanted Dust and %d Essence." % [cost["dust"], cost["essence"]]
	player.inventory.take("enchanted_dust", cost["dust"])
	player.inventory.take("essence", cost["essence"])
	var pool: Array[Dictionary] = []
	for affix in ItemDB.AFFIXES:
		if not affix.has("slots") or item.slot() in affix["slots"]:
			pool.append(affix)
	var affix: Dictionary = pool.pick_random()
	# Skill narrows the roll toward the top of the range.
	var skill := player.professions.level("enchanting") / float(Professions.MAX_LEVEL)
	var value: float = (affix["base"] + affix["per_level"] * item.level) * randf_range(0.7 + 0.3 * skill, 1.2)
	value = maxf(roundf(value), 1.0) if affix["kind"] == "flat" and affix["base"] >= 1.0 else snappedf(value, 0.001)
	item.enchant = {"stat": affix["stat"], "kind": affix["kind"], "value": value}
	player.professions.add_xp("enchanting", 20.0 + item.level * 2.0)
	_item_changed(player)
	Events.codex_event.emit("enchants", 1)
	return ""


# --- salvaging

## What breaking an item down gives: {item id: count}.
static func salvage_yield(player: Player, item: Item) -> Dictionary:
	var result := {}
	if item.definition().get("tiered", false):
		var ingots := 2 if item.definition().get("two_handed", false) or item.slot() == "chest" else 1
		# Skilled salvagers recover more metal.
		if player.professions.level("salvaging") >= 50:
			ingots += 1
		result[ItemDB.tier_ingot(item.level)] = ingots
	if item.rarity > 0 or not item.definition().get("tiered", false):
		result["enchanted_dust"] = maxi(item.rarity, 1)
	return result


static func salvage(player: Player, item: Item) -> String:
	if not item.is_equipment() or not item in player.inventory.items:
		return "Only equipment in your bag can be salvaged."
	var gains := salvage_yield(player, item)
	player.inventory.remove(item)
	for item_id: String in gains:
		player.inventory.add(Item.create(item_id, gains[item_id]))
	player.professions.add_xp("salvaging", 8.0 + item.level * 1.5 + item.rarity * 6.0)
	Events.codex_event.emit("salvages", 1)
	return ""


static func _item_changed(player: Player) -> void:
	player.inventory.changed.emit()
	player.equipment.changed.emit()
	SaveGame.request_save()
