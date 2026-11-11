class_name Gems
extends RefCounted
## Gems go into sockets on gear. What a gem gives depends on what it is set
## into: weapons, armour, or jewellery (rings, necklaces, artifacts). Each
## grade (1 Chipped to 5 Perfect) gives more.

const KINDS: Array[String] = ["ruby", "sapphire", "emerald", "topaz", "amethyst", "diamond", "garnet"]
## kind -> place -> [stat, modifier kind, amount per grade]
const EFFECTS := {
	"ruby": {"weapon": ["physical_damage", "flat", 2.0], "armor": ["max_health", "flat", 12.0], "jewel": ["critical_damage", "flat", 0.06]},
	"sapphire": {"weapon": ["frost_damage", "flat", 1.8], "armor": ["frost_resist", "flat", 0.04], "jewel": ["max_mana", "flat", 8.0]},
	"emerald": {"weapon": ["poison_damage", "flat", 1.8], "armor": ["poison_resist", "flat", 0.04], "jewel": ["health_regen", "flat", 0.35]},
	"topaz": {"weapon": ["critical_chance", "flat", 0.012], "armor": ["move_speed", "flat", 2.5], "jewel": ["magic_find", "flat", 0.03]},
	"amethyst": {"weapon": ["shadow_damage", "flat", 1.8], "armor": ["shadow_resist", "flat", 0.04], "jewel": ["life_steal", "flat", 0.006]},
	"diamond": {"weapon": ["holy_damage", "flat", 1.8], "armor": ["elemental_resistance", "flat", 0.02], "jewel": ["attack_speed", "percent", 0.012]},
	"garnet": {"weapon": ["fire_damage", "flat", 1.8], "armor": ["fire_resist", "flat", 0.04], "jewel": ["max_health", "flat", 10.0]},
}
## Sockets a new piece of gear can have, by rarity: [fewest, most].
const SOCKETS_BY_RARITY: Array = [[0, 0], [0, 1], [1, 1], [1, 2], [2, 2], [2, 3]]
## Gold per item level to pull the gems back out of an item.
const REMOVE_COST_PER_LEVEL := 8


static func place_of(slot: String) -> String:
	if slot == "main_hand":
		return "weapon"
	if slot in ["ring", "necklace", "artifact"]:
		return "jewel"
	return "armor"


## The modifier a gem gives in an item of a slot.
static func modifier(gem_id: String, slot: String) -> Dictionary:
	var def: Dictionary = ItemDB.ITEMS.get(gem_id, {})
	if not def.has("gem"):
		return {}
	var effect: Array = EFFECTS[def["gem"]][place_of(slot)]
	var value: float = effect[2] * def["grade"]
	if effect[2] >= 1.0:
		value = roundf(value)
	return {"stat": effect[0], "kind": effect[1], "value": value}


static func roll_sockets(rarity: int) -> int:
	var range_: Array = SOCKETS_BY_RARITY[clampi(rarity, 0, SOCKETS_BY_RARITY.size() - 1)]
	var count := randi_range(range_[0], range_[1])
	# Now and then a plain item has a socket anyway.
	if count == 0 and randf() < 0.1:
		count = 1
	return count


## A random gem of a grade suited to a level.
static func random_gem(level: int) -> String:
	var grade := 1
	var roll := randf()
	if level >= 15 and roll < 0.35:
		grade = 2
	if level >= 35 and roll < 0.12:
		grade = 3
	if level >= 60 and roll < 0.04:
		grade = 4
	return "%s_%d" % [KINDS[randi() % KINDS.size()], grade]


static func insert(player: Player, item: Item, gem: Item) -> String:
	var free := item.sockets.find("")
	if free == -1:
		return "No empty socket."
	if not gem in player.inventory.items or not gem.definition().has("gem"):
		return "No such gem."
	player.inventory.take(gem.id, 1)
	item.sockets[free] = gem.id
	Events.codex_event.emit("gems_socketed", 1)
	player.equipment.changed.emit()
	player.inventory.changed.emit()
	return ""


static func remove_all(player: Player, item: Item) -> String:
	var gems := item.sockets.filter(func(id: String) -> bool: return id != "")
	if gems.is_empty():
		return "No gems to remove."
	var cost := REMOVE_COST_PER_LEVEL * item.level
	if player.inventory.gold < cost:
		return "Removing the gems costs %d gold." % cost
	player.inventory.gold -= cost
	for id: String in gems:
		player.inventory.add(Item.create(id))
	for index in item.sockets.size():
		item.sockets[index] = ""
	player.equipment.changed.emit()
	player.inventory.changed.emit()
	return ""
