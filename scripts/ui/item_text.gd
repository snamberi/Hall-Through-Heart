class_name ItemText
extends RefCounted
## Words about items, shared by every screen that shows them.

const FLAVOR := {
	"main_hand": "A weapon is only as good as the hand that holds it.",
	"off_hand": "Something solid between you and the rot.",
	"helmet": "Keeps your head where it belongs.",
	"chest": "Sturdy plate that balances protection and movement.",
	"legs": "Guards the legs without slowing the stride much.",
	"boots": "Good boots outlast most adventurers.",
	"necklace": "It hangs warm against the skin.",
	"ring": "A band with something of the old world in it.",
	"artifact": "It was not made by any living hand.",
}


## BBCode description of an item, as shown in the inventory's details panel
## and in the tooltip that follows the mouse everywhere items appear.
static func describe(item: Item, player: Player) -> String:
	var dim := UITheme.DIM.to_html(false)
	var text := UITheme.TEXT.to_html(false)
	var lines: PackedStringArray = []
	var def := item.definition()
	lines.append("[font_size=20][color=#%s]%s[/color][/font_size]" % [item.color().to_html(false), item.display_name()])
	var rarity: String = ItemDB.RARITIES[item.rarity]["name"]
	if not item.is_equipment():
		var kind := "Tool" if item.is_tool() else "Backpack" if item.is_backpack() else "Consumable" if item.is_consumable() else "Building" if item.is_placeable() else "Material"
		lines.append("[color=#%s]%s[/color]  [color=#%s]-  %s[/color]" % [item.color().to_html(false), rarity, dim, kind])
		lines.append("")
		lines.append("[i][color=#%s]%s[/color][/i]" % [dim, def["text"]])
		if item.is_backpack():
			lines.append("")
			lines.append("[color=#%s]+%d bag slots while worn[/color]" % [UITheme.GOOD.to_html(false), int(def["backpack"])])
		if item.is_tool():
			lines.append("")
			lines.append("[color=#%s]Kept on the belt. Works %d%% as fast as a worn tool.[/color]" % [dim, roundi(def["tool"]["speed"] * 100.0)])
		if item.is_stackable():
			lines.append("")
			lines.append("[color=#%s]You have %d.[/color]" % [dim, player.inventory.count_of(item.id)])
		return "\n".join(lines)

	var kind_name: String = "Two-handed" if def.get("two_handed", false) else ItemDB.SLOT_NAMES[item.slot()]
	if def.get("magic", false):
		kind_name += ", magic"
	lines.append("[color=#%s]%s[/color]  [color=#%s]-  %s  -  item level %d[/color]" % [item.color().to_html(false), rarity, dim, kind_name, item.level])
	lines.append("")
	if def.has("damage"):
		var weapon: Dictionary = def["weapon"]
		lines.append("[color=#%s]Damage[/color]  [font_size=20]%d[/font_size]%s%s" % [text, roundi(item.base_power("damage")), _delta(item, player, "damage"), "  [color=#%s](magic)[/color]" % dim if def.get("magic", false) else ""])
		var action := "shots, range" if weapon.has("projectile") else "swings, reach"
		lines.append("[color=#%s]%.2fs between %s %d[/color]" % [dim, weapon["cooldown"], action, roundi(weapon["range"])])
	if def.has("armor"):
		lines.append("[color=#%s]Armor[/color]  [font_size=20]%d[/font_size]%s" % [text, roundi(item.base_power("armor")), _delta(item, player, "armor")])
	var level_ok := player.leveling.level >= item.level
	lines.append("[i][color=#%s]Requires level %d[/color][/i]" % [UITheme.HEADING.to_html(false) if level_ok else UITheme.BAD.to_html(false), item.level])
	var requirements := item.attribute_requirements()
	for attribute: String in requirements:
		var met: bool = player.attributes.points[attribute] >= requirements[attribute]
		lines.append("[i][color=#%s]Requires %d %s[/color][/i]" % [dim if met else UITheme.BAD.to_html(false), requirements[attribute], Attributes.NAMES[attribute]])
	lines.append("")
	lines.append("[i][color=#%s]%s[/color][/i]" % [dim, FLAVOR.get(item.slot(), "")])
	lines.append("")
	if def.has("on_hit"):
		var effect: Dictionary = def["on_hit"]
		var status: Dictionary = ItemDB.STATUSES[effect["status"]]
		var detail := "slows by %d%%" % roundi(effect["power"] * 100.0) if effect["status"] == "chill" else "%d%% of the hit per second" % roundi(effect["power"] * 100.0)
		lines.append("[color=#%s]Inflicts %s: %s for %.1fs[/color]" % [status["color"].to_html(false), status["name"], detail, effect["duration"]])
	if def.has("life_steal"):
		lines.append("[color=#%s]Heals you for %d%% of damage dealt[/color]" % [UITheme.GOOD.to_html(false), roundi(def["life_steal"] * 100.0)])
	if def.has("unique"):
		lines.append("[color=#ff9a2e]Unique: %s[/color]" % Uniques.TEXT[def["unique"]])
	for modifier in item.rarity_gift():
		lines.append("[color=#%s]%s: %s[/color]" % [item.color().to_html(false), rarity, ItemDB.describe_modifier(modifier)])
	for modifier in item.implicit_modifiers():
		lines.append("[color=#%s]+[/color] %s" % [UITheme.HEADING.to_html(false), ItemDB.describe_modifier(modifier)])
	for modifier in item.mods:
		lines.append("[color=#%s]+[/color] [color=#%s]%s[/color]" % [UITheme.HEADING.to_html(false), UITheme.INFO.to_html(false), ItemDB.describe_modifier(modifier)])
	if not item.enchant.is_empty():
		lines.append("[color=#c08cff]+ %s  (enchanted)[/color]" % ItemDB.describe_modifier(item.enchant))
	for gem in item.sockets:
		if gem == "":
			lines.append("[color=#%s]<> Empty socket[/color]" % dim)
		else:
			lines.append("[color=#%s]<> %s: %s[/color]" % [(ItemDB.ITEMS[gem]["tint"] as Color).to_html(false), ItemDB.ITEMS[gem]["name"], ItemDB.describe_modifier(Gems.modifier(gem, item.slot()))])
	if item.set_id != "":
		var set_data: Dictionary = ItemDB.ITEM_SETS[item.set_id]
		var worn: int = player.equipment.named_set_counts().get(item.set_id, 0)
		lines.append("")
		lines.append("[color=#%s]%s set  (%d / %d worn)[/color]" % [ItemDB.SET_COLOR.to_html(false), set_data["name"], worn, set_data["pieces"].size()])
		for needed: int in set_data["bonuses"]:
			var parts: PackedStringArray = []
			for stat: String in set_data["bonuses"][needed]:
				for kind: String in set_data["bonuses"][needed][stat]:
					var value: float = set_data["bonuses"][needed][stat][kind]
					var text_part := ItemDB.describe_modifier({"stat": stat, "kind": kind, "value": absf(value)})
					parts.append(text_part if value >= 0.0 else "-" + text_part.substr(1))
			lines.append("[color=#%s](%d) %s[/color]" % [ItemDB.SET_COLOR.to_html(false) if worn >= needed else dim, needed, ", ".join(parts)])
	# What changes against what is worn in its place.
	var comparison := compare(item, player)
	if comparison != "":
		lines.append("")
		lines.append(comparison)
	return "\n".join(lines)


## What a recipe makes and needs, with how many of each the player has.
static func describe_recipe(recipe: Dictionary, player: Player) -> String:
	var dim := UITheme.DIM.to_html(false)
	var lines: PackedStringArray = []
	lines.append("[font_size=18][color=#%s]%s[/color][/font_size]" % [UITheme.HEADING.to_html(false), RecipeDB.display_name(recipe)])
	var made: String = recipe.get("item", "")
	if made != "" and ItemDB.ITEMS.has(made):
		lines.append("[i][color=#%s]%s[/color][/i]" % [dim, ItemDB.ITEMS[made].get("text", "")])
	lines.append("")
	lines.append("[color=#%s]Needs[/color]" % dim)
	for item_id: String in recipe["inputs"]:
		var need: int = recipe["inputs"][item_id]
		var have := player.inventory.count_of(item_id)
		lines.append("[color=#%s]%d / %d[/color]  %s" % [(UITheme.GOOD if have >= need else UITheme.BAD).to_html(false), have, need, ItemDB.ITEMS[item_id]["name"]])
	var problem := Crafting.blocked_reason(player, recipe)
	if problem != "":
		lines.append("")
		lines.append("[color=#%s]%s[/color]" % [UITheme.BAD.to_html(false), problem])
	else:
		lines.append("")
		lines.append("[color=#%s]Click to make it[/color]" % UITheme.GOOD.to_html(false))
	return "\n".join(lines)


## A small picture for each stat, from the item icon sheet.
const STAT_ICONS := {
	"physical_damage": 0, "magic_power": 33, "max_health": 35, "health_regen": 35, "max_mana": 36, "mana_regen": 36,
	"max_stamina": 37, "stamina_regen": 37, "critical_chance": 26, "critical_damage": 26, "attack_speed": 31,
	"move_speed": 9, "armor": 7, "damage_taken": 5, "dodge_efficiency": 29, "life_steal": 21, "magic_find": 12,
	"gold_find": 17, "mining_efficiency": 49, "fire_damage": 18, "frost_damage": 19, "shadow_damage": 20,
	"holy_damage": 63, "poison_damage": 24, "fire_resist": 18, "frost_resist": 19, "shadow_resist": 20,
	"holy_resist": 63, "poison_resist": 24, "elemental_resistance": 5, "knockback_resistance": 5,
}


static func stat_icon(stat: String) -> Texture2D:
	return ItemDB.icon(STAT_ICONS.get(stat, 12))


## What using an item does, as [icon, words, colour] lines: what it
## restores, and the buff it gives with its time.
static func effects(item: Item) -> Array:
	var lines: Array = []
	var use: Dictionary = item.definition().get("use", {})
	for pair: Array in [["heal", 35, "health", Color("ff7a7a")], ["mana", 36, "mana", Color("7aa8ff")], ["stamina", 37, "stamina", Color("ffd25a")]]:
		if use.has(pair[0]):
			lines.append([ItemDB.icon(pair[1]), "Restores %d%% %s" % [roundi(float(use[pair[0]]) * 100.0), pair[2]], pair[3]])
	if use.has("buff"):
		var minutes := float(use["duration"]) / 60.0
		var time := "%d min" % roundi(minutes) if minutes >= 1.0 else "%d s" % roundi(use["duration"])
		var parts: PackedStringArray = []
		for stat: String in use["mods"]:
			for kind: String in use["mods"][stat]:
				parts.append(ItemDB.describe_modifier({"stat": stat, "kind": kind, "value": use["mods"][stat][kind]}))
		lines.append([ItemDB.icon(55), "%s (%s): %s" % [use.get("name", "Buff"), time, ", ".join(parts)], UITheme.GOOD])
		var course := ItemDB.course_of(item.id)
		if course != "":
			lines.append([ItemDB.icon(48), "%s: one at a time, works alongside a %s" % [ItemDB.COURSE_NAMES[course], " and a ".join(["meal", "drink", "treat"].filter(func(c: String) -> bool: return c != course))], UITheme.DIM])
	return lines


## How an item compares with what is worn in its place, as BBCode lines:
## each stat that would change, green for better and red for worse.
## What a piece of gear would be measured against: the worn piece in its
## slot, or for a weapon the one in hand (a free second weapon slot is no
## rival worth comparing with).
static func rival(item: Item, player: Player) -> Item:
	var equipment := player.equipment
	if item.slot() == "main_hand" and not item.definition().get("magic", false):
		for slot: String in [equipment.active_slot, "weapon_2", "weapon_3"]:
			if slot in ["weapon_2", "weapon_3"] and equipment.equipped.has(slot):
				return equipment.equipped[slot]
		return null
	return equipment.equipped.get(equipment.target_slot(item))


## Beside a weapon's damage or armour's armor: how far it is above or below
## what is worn in its place, in green or red, so a glance is enough.
static func _delta(item: Item, player: Player, key: String) -> String:
	var worn := rival(item, player)
	if worn == item or player.equipment.slot_of(item) != "":
		return ""
	var change := item.base_power(key) - (worn.base_power(key) if worn and worn.definition().has(key) else 0.0)
	if absf(change) < 0.5:
		return "  [color=#%s](same as worn)[/color]" % UITheme.DIM.to_html(false)
	return "  [color=#%s]%s%d %s[/color]" % [(UITheme.GOOD if change > 0.0 else UITheme.BAD).to_html(false), "+" if change > 0.0 else "-", roundi(absf(change)), "vs worn" if worn else "(slot empty)"]


static func compare(item: Item, player: Player) -> String:
	if not item.is_equipment():
		return ""
	var slot := player.equipment.target_slot(item)
	var worn := rival(item, player)
	if worn == item or player.equipment.slot_of(item) != "":
		return ""
	var totals := func(source: Item) -> Dictionary:
		var result := {}
		if source == null:
			return result
		for modifier in source.all_modifiers():
			var key: String = modifier["stat"] + ":" + modifier["kind"]
			result[key] = result.get(key, 0.0) + float(modifier["value"])
		return result
	var mine: Dictionary = totals.call(item)
	var theirs: Dictionary = totals.call(worn)
	var keys: Array = mine.keys()
	for key: String in theirs:
		if not key in keys:
			keys.append(key)
	var lines: PackedStringArray = []
	lines.append("[color=#%s]Compared with %s:[/color]" % [UITheme.DIM.to_html(false), worn.display_name() if worn else "an empty %s slot" % str(Equipment.BELT_NAMES.get(slot, ItemDB.SLOT_NAMES.get(slot, slot))).to_lower()])
	var any := false
	for key: String in keys:
		var change: float = mine.get(key, 0.0) - theirs.get(key, 0.0)
		if absf(change) < 0.0005:
			continue
		any = true
		var parts := key.split(":")
		var words := ItemDB.describe_modifier({"stat": parts[0], "kind": parts[1], "value": absf(change)})
		var better := change > 0.0 if parts[0] != "damage_taken" else change < 0.0
		lines.append("[color=#%s]%s %s[/color]" % [(UITheme.GOOD if better else UITheme.BAD).to_html(false), "+" if change > 0.0 else "-", words.substr(1)])
	if not any:
		lines.append("[color=#%s]No difference.[/color]" % UITheme.DIM.to_html(false))
	return "\n".join(lines)
