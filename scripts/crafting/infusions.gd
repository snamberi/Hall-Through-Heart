class_name Infusions
extends RefCounted
## Infusing gear with monster and animal parts: every part a creature
## leaves behind can be worked into a weapon or a piece of armour for a
## lasting bonus that grows with the item's level. Rarer gear holds more
## infusions (one, two from Rare, three from Legendary); each one after the
## first takes more of the material.

## material id -> {"name": the word for it, "stat", "kind", "base", "per_level"}.
const MATERIALS := {
	"husk_fragment": {"name": "Husk-bound", "stat": "max_health", "kind": "flat", "base": 3.0, "per_level": 0.6},
	"bone": {"name": "Bone-ribbed", "stat": "armor", "kind": "flat", "base": 1.0, "per_level": 0.25},
	"claw": {"name": "Keen", "stat": "critical_chance", "kind": "flat", "base": 0.008, "per_level": 0.0001},
	"essence": {"name": "Arcane", "stat": "magic_power", "kind": "percent", "base": 0.02, "per_level": 0.0002},
	"enchanted_dust": {"name": "Lucky", "stat": "magic_find", "kind": "flat", "base": 0.02, "per_level": 0.0002},
	"frost_pelt": {"name": "Frost-lined", "stat": "frost_resist", "kind": "flat", "base": 0.04, "per_level": 0.0},
	"troll_hide": {"name": "Troll-blooded", "stat": "health_regen", "kind": "flat", "base": 0.3, "per_level": 0.03},
	"boar_tusk": {"name": "Tusked", "stat": "physical_damage", "kind": "flat", "base": 0.6, "per_level": 0.12},
	"scorpion_stinger": {"name": "Stinging", "stat": "poison_damage", "kind": "flat", "base": 1.0, "per_level": 0.2},
	"mummy_wrap": {"name": "Wrapped", "stat": "shadow_resist", "kind": "flat", "base": 0.04, "per_level": 0.0},
	"void_shard": {"name": "Void-touched", "stat": "shadow_damage", "kind": "flat", "base": 1.2, "per_level": 0.25},
	"heartblood": {"name": "Heartfelt", "stat": "life_steal", "kind": "flat", "base": 0.006, "per_level": 0.00005},
	"crimson_plate": {"name": "Crimson", "stat": "armor", "kind": "percent", "base": 0.03, "per_level": 0.0002},
	"heart_shard": {"name": "Heart-bound", "stat": "max_health", "kind": "percent", "base": 0.04, "per_level": 0.0002},
	"fiend_horn": {"name": "Fiendish", "stat": "fire_damage", "kind": "flat", "base": 1.2, "per_level": 0.25},
	"magma_core": {"name": "Molten", "stat": "fire_damage", "kind": "flat", "base": 2.0, "per_level": 0.35},
	"ember_core": {"name": "Ember", "stat": "fire_damage", "kind": "flat", "base": 1.5, "per_level": 0.3},
	"harpy_feather": {"name": "Swift", "stat": "attack_speed", "kind": "percent", "base": 0.012, "per_level": 0.0001},
	"lurker_tongue": {"name": "Bog-proof", "stat": "poison_resist", "kind": "flat", "base": 0.04, "per_level": 0.0},
	"hound_pelt": {"name": "Fleet", "stat": "move_speed", "kind": "flat", "base": 2.0, "per_level": 0.03},
	"slime_gel": {"name": "Slippery", "stat": "dodge_efficiency", "kind": "flat", "base": 0.02, "per_level": 0.0002},
	"bat_wing": {"name": "Leeching", "stat": "life_steal", "kind": "flat", "base": 0.004, "per_level": 0.00003},
	"chitin": {"name": "Shelled", "stat": "armor", "kind": "flat", "base": 1.5, "per_level": 0.3},
	"spore_cap": {"name": "Sporous", "stat": "poison_damage", "kind": "flat", "base": 0.8, "per_level": 0.15},
	"cultist_sigil": {"name": "Profane", "stat": "magic_power", "kind": "percent", "base": 0.025, "per_level": 0.0002},
	"wraith_cloth": {"name": "Ghostly", "stat": "dodge_efficiency", "kind": "flat", "base": 0.03, "per_level": 0.0002},
	"venom_sac": {"name": "Toxic", "stat": "poison_damage", "kind": "flat", "base": 1.5, "per_level": 0.3},
	"stone_heart": {"name": "Stonehearted", "stat": "max_health", "kind": "percent", "base": 0.025, "per_level": 0.0002},
	"antler": {"name": "Antlered", "stat": "critical_damage", "kind": "flat", "base": 0.03, "per_level": 0.0003},
	"goat_horn": {"name": "Horned", "stat": "physical_damage", "kind": "percent", "base": 0.012, "per_level": 0.0001},
	"bear_pelt": {"name": "Bear-hide", "stat": "max_health", "kind": "flat", "base": 5.0, "per_level": 1.0},
	"spider_silk": {"name": "Silken", "stat": "attack_speed", "kind": "percent", "base": 0.01, "per_level": 0.0001},
	"fox_pelt": {"name": "Fox-lined", "stat": "frost_resist", "kind": "flat", "base": 0.05, "per_level": 0.0},
	"crab_shell": {"name": "Shell-plated", "stat": "armor", "kind": "flat", "base": 1.0, "per_level": 0.25},
	"lizard_scale": {"name": "Scaled", "stat": "fire_resist", "kind": "flat", "base": 0.04, "per_level": 0.0},
	"feather": {"name": "Light", "stat": "move_speed", "kind": "flat", "base": 1.5, "per_level": 0.02},
	"pheasant_feather": {"name": "Plumed", "stat": "move_speed", "kind": "flat", "base": 1.5, "per_level": 0.02},
	"wool": {"name": "Woollen", "stat": "frost_resist", "kind": "flat", "base": 0.03, "per_level": 0.0},
	"deer_hide": {"name": "Hardy", "stat": "max_stamina", "kind": "flat", "base": 4.0, "per_level": 0.2},
	"hare_pelt": {"name": "Quick", "stat": "max_stamina", "kind": "flat", "base": 3.0, "per_level": 0.15},
	"pig_hide": {"name": "Thick", "stat": "max_health", "kind": "flat", "base": 2.0, "per_level": 0.5},
	"cow_hide": {"name": "Tough", "stat": "armor", "kind": "flat", "base": 0.8, "per_level": 0.2},
	"toad_slime": {"name": "Slick", "stat": "poison_resist", "kind": "flat", "base": 0.03, "per_level": 0.0},
}

## Gold per item level for each infusion.
const GOLD_PER_LEVEL := 8


## How many infusions an item can hold.
static func room(item: Item) -> int:
	return 1 + item.rarity / 2


static func can_infuse(item: Item) -> bool:
	return item != null and item.is_equipment()


## The bonus a material gives on an item of this level.
static func modifier(material: String, item_level: int) -> Dictionary:
	var data: Dictionary = MATERIALS[material]
	var value: float = data["base"] + data["per_level"] * item_level
	if data["kind"] == "flat" and data["base"] >= 1.0:
		value = snappedf(value, 0.1)
	return {"stat": data["stat"], "kind": data["kind"], "value": value}


## {"count": how many of the material, "gold": n} for the next infusion.
static func cost(item: Item) -> Dictionary:
	return {"count": 2 + 2 * item.infusions.size(), "gold": GOLD_PER_LEVEL * item.level * (1 + item.infusions.size())}


## Why `material` can't be worked into `item` now, or "".
static func problem(player: Player, item: Item, material: String) -> String:
	if not can_infuse(item):
		return "Only weapons and armour take infusions."
	if not MATERIALS.has(material):
		return "%s cannot be infused." % ItemDB.ITEMS[material]["name"]
	if item.infusions.size() >= room(item):
		return "No room for more infusions (%d). Rarer gear holds more." % room(item)
	var price := cost(item)
	if player.inventory.count_of(material) < price["count"]:
		return "Needs %d %s." % [price["count"], ItemDB.ITEMS[material]["name"]]
	if player.inventory.gold < price["gold"]:
		return "Costs %d gold." % price["gold"]
	return ""


static func infuse(player: Player, item: Item, material: String) -> String:
	var reason := problem(player, item, material)
	if reason != "":
		return reason
	var price := cost(item)
	player.inventory.take(material, price["count"])
	player.inventory.add_gold(-price["gold"])
	item.infusions.append(material)
	player.professions.add_xp("blacksmithing", 10.0 + item.level * 1.5)
	Events.item_crafted.emit("infusion")
	Events.codex_event.emit("infusions", 1)
	Audio.play("level_up", -10.0, 0.25)
	player.equipment.changed.emit()
	player.inventory.changed.emit()
	return ""


## "+3 Fire damage", for a material on an item of this level.
static func describe(material: String, item_level: int) -> String:
	return ItemDB.describe_modifier(modifier(material, item_level))
