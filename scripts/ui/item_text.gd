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
		lines.append("[color=#%s]Damage[/color]  [font_size=20]%d[/font_size]%s" % [text, roundi(item.base_power("damage")), "  [color=#%s](magic)[/color]" % dim if def.get("magic", false) else ""])
		var action := "shots, range" if weapon.has("projectile") else "swings, reach"
		lines.append("[color=#%s]%.2fs between %s %d[/color]" % [dim, weapon["cooldown"], action, roundi(weapon["range"])])
	if def.has("armor"):
		lines.append("[color=#%s]Armor[/color]  [font_size=20]%d[/font_size]" % [text, roundi(item.base_power("armor"))])
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
	if player.equipment.slot_of(item) == "":
		var current := player.equipment.get_item(player.equipment.target_slot(item))
		if current:
			lines.append("")
			lines.append("[color=#%s]Wearing: %s[/color]" % [dim, current.display_name()])
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
