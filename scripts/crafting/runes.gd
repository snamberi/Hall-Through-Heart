class_name Runes
extends RefCounted
## Rune enchanting. Eight runes, each a small carved stone; two or three of
## them laid together in the right company bind into a named effect (a
## runeword) on a weapon or a piece of armour. A piece holds one runeword;
## binding a new one replaces it. Binding costs a Rift Shard for each rune
## and some gold, and needs Enchanting.
##
## A runeword's numbers grow with the level of the piece it is bound to.

const RUNES := {
	"rune_ember": {"name": "Ember", "tint": Color("ff8a40")},
	"rune_rime": {"name": "Rime", "tint": Color("8ad8ff")},
	"rune_venom": {"name": "Venom", "tint": Color("8ae060")},
	"rune_gloom": {"name": "Gloom", "tint": Color("a080e0")},
	"rune_dawn": {"name": "Dawn", "tint": Color("ffe08a")},
	"rune_gale": {"name": "Gale", "tint": Color("c8f0e8")},
	"rune_stone": {"name": "Stone", "tint": Color("b8b0a8")},
	"rune_blood": {"name": "Blood", "tint": Color("e04858")},
}
## Each runeword: the runes (any order), its name, and what it gives.
## "scaled" values grow by SCALE a level of the piece; others are fixed.
const WORDS := {
	"wildfire": {"runes": ["rune_ember", "rune_gale"], "name": "Wildfire",
		"mods": [["fire_damage", "flat", 4.0, true], ["attack_speed", "percent", 0.06, false]]},
	"glacier_ward": {"runes": ["rune_rime", "rune_stone"], "name": "Glacier Ward",
		"mods": [["armor", "percent", 0.08, false], ["frost_resist", "flat", 0.15, false]]},
	"night_hunger": {"runes": ["rune_blood", "rune_gloom"], "name": "Night Hunger",
		"mods": [["life_steal", "flat", 0.02, false], ["shadow_damage", "flat", 3.0, true]]},
	"bulwark_of_dawn": {"runes": ["rune_dawn", "rune_stone"], "name": "Bulwark of Dawn",
		"mods": [["max_health", "percent", 0.06, false], ["holy_resist", "flat", 0.15, false]]},
	"vipers_haste": {"runes": ["rune_gale", "rune_venom"], "name": "Viper's Haste",
		"mods": [["poison_damage", "flat", 3.0, true], ["move_speed", "percent", 0.04, false]]},
	"blood_pyre": {"runes": ["rune_blood", "rune_ember"], "name": "Blood Pyre",
		"mods": [["fire_damage", "flat", 3.0, true], ["life_steal", "flat", 0.01, false]]},
	"hoarfrost_step": {"runes": ["rune_gale", "rune_rime"], "name": "Hoarfrost Step",
		"mods": [["dodge_efficiency", "flat", 0.08, false], ["frost_damage", "flat", 3.0, true]]},
	"martyrs_vow": {"runes": ["rune_blood", "rune_dawn"], "name": "Martyr's Vow",
		"mods": [["health_regen", "flat", 1.0, true], ["max_health", "percent", 0.04, false]]},
	"tempest": {"runes": ["rune_ember", "rune_gale", "rune_rime"], "name": "Tempest",
		"mods": [["fire_damage", "flat", 3.0, true], ["frost_damage", "flat", 3.0, true], ["attack_speed", "percent", 0.08, false]]},
	"plague_heart": {"runes": ["rune_blood", "rune_gloom", "rune_venom"], "name": "Plague Heart",
		"mods": [["poison_damage", "flat", 3.0, true], ["shadow_damage", "flat", 3.0, true], ["life_steal", "flat", 0.02, false]]},
	"saints_bulwark": {"runes": ["rune_blood", "rune_dawn", "rune_stone"], "name": "Saint's Bulwark",
		"mods": [["armor", "percent", 0.1, false], ["max_health", "percent", 0.08, false], ["health_regen", "flat", 1.0, true]]},
	"pilgrims_road": {"runes": ["rune_dawn", "rune_gale", "rune_stone"], "name": "Pilgrim's Road",
		"mods": [["move_speed", "percent", 0.06, false], ["max_stamina", "percent", 0.1, false], ["dodge_efficiency", "flat", 0.06, false]]},
}
## How much a scaled number grows for each level of the piece.
const SCALE := 0.06
## Gold a binding costs, for each level of the piece.
const GOLD_PER_LEVEL := 25
## The Enchanting level needed to bind two runes, and three.
const LEVEL_TWO := 5
const LEVEL_THREE := 20


static func is_rune(item_id: String) -> bool:
	return RUNES.has(item_id)


## The runeword a set of runes binds into, or "".
static func word_for(runes: Array) -> String:
	var wanted := runes.duplicate()
	wanted.sort()
	for word: String in WORDS:
		var needs: Array = (WORDS[word]["runes"] as Array).duplicate()
		needs.sort()
		if needs == wanted:
			return word
	return ""


## A runeword's modifiers on a piece of this level.
static func modifiers(word: String, at_level: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not WORDS.has(word):
		return result
	for entry: Array in WORDS[word]["mods"]:
		var value: float = entry[2]
		if entry[3]:
			value = roundf(value * (1.0 + SCALE * at_level))
		result.append({"stat": entry[0], "kind": entry[1], "value": value})
	return result


static func describe(word: String, at_level: int) -> String:
	var parts: PackedStringArray = []
	for modifier in modifiers(word, at_level):
		parts.append(ItemDB.describe_modifier(modifier))
	return ", ".join(parts)


## What binding these runes to a piece costs: {"gold", "shards"}.
static func cost(item: Item, runes: Array) -> Dictionary:
	return {"gold": GOLD_PER_LEVEL * maxi(item.level, 1), "shards": runes.size()}


## Why these runes cannot be bound to the piece now, or "".
static func problem(player: Player, item: Item, runes: Array) -> String:
	if item == null or not item.is_equipment():
		return "Choose a weapon or a piece of armour."
	if runes.size() < 2:
		return "Lay at least two runes."
	var word := word_for(runes)
	if word == "":
		return "These runes do not bind together."
	var skill := player.professions.level("enchanting")
	var needed := LEVEL_THREE if runes.size() >= 3 else LEVEL_TWO
	if skill < needed:
		return "Binding %d runes needs Enchanting %d." % [runes.size(), needed]
	var counts := {}
	for rune: String in runes:
		counts[rune] = int(counts.get(rune, 0)) + 1
	for rune: String in counts:
		if player.inventory.count_of(rune) < int(counts[rune]):
			return "You do not hold the %s rune." % RUNES[rune]["name"]
	var price := cost(item, runes)
	if player.inventory.count_of("rift_shard") < int(price["shards"]):
		return "Needs %d Rift Shards (from Heart Rifts)." % price["shards"]
	if player.inventory.gold < int(price["gold"]):
		return "Needs %d gold." % price["gold"]
	return ""


## Binds the runes into the piece. Returns "" or why not.
static func bind(player: Player, item: Item, runes: Array) -> String:
	var reason := problem(player, item, runes)
	if reason != "":
		return reason
	var price := cost(item, runes)
	for rune: String in runes:
		player.inventory.take(rune, 1)
	player.inventory.take("rift_shard", int(price["shards"]))
	player.inventory.add_gold(-int(price["gold"]))
	item.runeword = word_for(runes)
	player.professions.add_xp("enchanting", 40.0 * runes.size())
	Events.codex_event.emit("runewords", 1)
	# Worn gear's numbers are gathered again when the equipment changes.
	player.equipment.changed.emit()
	player.inventory.changed.emit()
	SaveGame.request_save()
	return ""
