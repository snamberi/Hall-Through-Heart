class_name InventoryMenu
extends GameMenu
## Inventory: the bag on the left, the character with their equipment slots
## in the middle, and the selected item's details on the right.
##
## Left-click selects an item; right-click equips, unequips, or uses it.

const COLUMNS := 8
const SLOT_SIZE := 50.0
const DOLL_SLOT := 60.0
## Equipment slots down each side of the character.
const LEFT_SLOTS: Array[String] = ["necklace", "main_hand", "ring_1", "ring_2", "artifact"]
const RIGHT_SLOTS: Array[String] = ["helmet", "chest", "legs", "boots", "off_hand"]
## Faint icon shown in an empty equipment slot.
const SLOT_ICONS := {"necklace": 10, "main_hand": 0, "ring_1": 11, "ring_2": 11, "artifact": 12,
	"helmet": 6, "chest": 7, "legs": 8, "boots": 9, "off_hand": 5}
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

var _count: Label
var _gold: Label
var _bag_buttons: Array[Button] = []
var _bag_counts: Array[Label] = []
var _slot_buttons: Dictionary[String, Button] = {}
var _set_label: Label
var _detail_icon: TextureRect
var _detail_frame: PanelContainer
var _details: RichTextLabel
var _primary: Button
var _upgrade: Button
var _enchant: Button
var _salvage: Button
var _discard: Button
var _message: Label
var _hand_row: HBoxContainer
var _hand_buttons: Dictionary[String, Button] = {}

var _selected: Item
var _hovered: Item


func _build() -> void:
	var title := UITheme.heading("INVENTORY", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	content.add_child(columns)

	# --- left: the bag
	var bag_panel := UITheme.inset_panel()
	columns.add_child(bag_panel)
	bag_panel.custom_minimum_size.y = 520.0
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	bag_panel.add_child(left)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	left.add_child(header)
	header.add_child(UITheme.icon(13, 26.0))
	_count = UITheme.label("", 20)
	_count.custom_minimum_size.x = 130.0
	header.add_child(_count)
	header.add_child(UITheme.icon(ItemDB.GOLD_ICON, 26.0))
	_gold = UITheme.label("", 20, UITheme.GOLD)
	header.add_child(_gold)
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	left.add_child(grid)
	for index in Inventory.CAPACITY:
		var button := _item_button(SLOT_SIZE)
		_wire(button, func() -> Item: return _bag_item(index))
		var count := UITheme.label("", 13)
		count.add_theme_color_override("font_outline_color", Color.BLACK)
		count.add_theme_constant_override("outline_size", 4)
		count.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		count.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		count.grow_vertical = Control.GROW_DIRECTION_BEGIN
		count.position -= Vector2(4, 1)
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(count)
		grid.add_child(button)
		_bag_buttons.append(button)
		_bag_counts.append(count)
	var bag_actions := HBoxContainer.new()
	bag_actions.add_theme_constant_override("separation", 10)
	left.add_child(bag_actions)
	_discard = UITheme.button("Discard", _discard_selected, 130.0)
	bag_actions.add_child(_discard)
	bag_actions.add_child(UITheme.button("Sort", func() -> void: player.inventory.sort(), 130.0))

	# Simple things that need no workbench.
	left.add_child(UITheme.heading("Craft by hand", 16))
	_hand_row = HBoxContainer.new()
	_hand_row.add_theme_constant_override("separation", 6)
	left.add_child(_hand_row)
	for recipe_id in RecipeDB.NO_TABLE:
		var recipe := RecipeDB.find(recipe_id)
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(98.0, 44.0)
		button.add_theme_font_size_override("font_size", 12)
		button.text = RecipeDB.display_name(recipe)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD
		button.pressed.connect(func() -> void: _report(Crafting.craft(player, recipe)))
		button.mouse_entered.connect(func() -> void:
			var needs: PackedStringArray = []
			for item_id: String in recipe["inputs"]:
				needs.append("%d %s" % [recipe["inputs"][item_id], ItemDB.ITEMS[item_id]["name"]])
			_message.add_theme_color_override("font_color", UITheme.DIM)
			_message.text = "%s needs %s" % [RecipeDB.display_name(recipe), ", ".join(needs)]
		)
		_hand_row.add_child(button)
		_hand_buttons[recipe_id] = button

	# --- middle: the character and what they wear
	var doll_panel := UITheme.inset_panel()
	columns.add_child(doll_panel)
	doll_panel.custom_minimum_size.y = 520.0
	var doll := CharacterPreview.new()
	doll.custom_minimum_size = Vector2(330.0, 400.0)
	doll.setup(player)
	doll_panel.add_child(doll)
	for side: Array in [[LEFT_SLOTS, 4.0], [RIGHT_SLOTS, 330.0 - DOLL_SLOT - 4.0]]:
		var slots: Array = side[0]
		for row in slots.size():
			var slot: String = slots[row]
			var button := _item_button(DOLL_SLOT)
			button.position = Vector2(side[1], 6.0 + row * (DOLL_SLOT + 16.0))
			button.size = Vector2(DOLL_SLOT, DOLL_SLOT)
			button.tooltip_text = ItemDB.SLOT_NAMES[slot]
			_wire(button, func() -> Item: return player.equipment.get_item(slot))
			doll.add_child(button)
			_slot_buttons[slot] = button
	_set_label = UITheme.label("", 13, UITheme.GOOD)
	_set_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_set_label.offset_top = -22.0
	_set_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_set_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	doll.add_child(_set_label)

	# --- right: details and actions
	var detail_panel := UITheme.inset_panel()
	columns.add_child(detail_panel)
	detail_panel.custom_minimum_size.y = 520.0
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.custom_minimum_size = Vector2(310.0, 0.0)
	detail_panel.add_child(right)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	right.add_child(top)
	_detail_frame = PanelContainer.new()
	_detail_frame.custom_minimum_size = Vector2(72.0, 72.0)
	_detail_frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(_detail_frame)
	_detail_icon = UITheme.icon(0, 56.0)
	_detail_frame.add_child(_detail_icon)
	_details = RichTextLabel.new()
	_details.bbcode_enabled = true
	# A fixed box so the screen keeps its size whatever is shown.
	_details.fit_content = false
	_details.scroll_active = true
	_details.custom_minimum_size = Vector2(310.0, 270.0)
	_details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_details.add_theme_font_size_override("normal_font_size", 14)
	_details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(_details)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(spacer)
	_message = UITheme.label("", 13, UITheme.BAD)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD
	_message.custom_minimum_size = Vector2(310.0, 20.0)
	right.add_child(_message)
	_primary = UITheme.button("Equip", _use_selected, 310.0)
	right.add_child(_primary)
	var smith := HBoxContainer.new()
	smith.add_theme_constant_override("separation", 6)
	right.add_child(smith)
	_upgrade = UITheme.button("Upgrade", func() -> void: _act(Crafting.upgrade), 99.0)
	_enchant = UITheme.button("Enchant", func() -> void: _act(Crafting.enchant), 99.0)
	_salvage = UITheme.button("Salvage", func() -> void: _act(Crafting.salvage), 99.0)
	for button: Button in [_upgrade, _enchant, _salvage]:
		smith.add_child(button)

	player.inventory.changed.connect(refresh_if_open)
	player.equipment.changed.connect(refresh_if_open)


func refresh() -> void:
	var inventory := player.inventory
	# Forget a selection that no longer exists (discarded, used up, salvaged).
	if _selected and not _selected in inventory.items and _equipped_slot(_selected) == "":
		_selected = null
	_count.text = "%d / %d" % [inventory.items.size(), Inventory.CAPACITY]
	for recipe_id in _hand_buttons:
		_hand_buttons[recipe_id].disabled = Crafting.blocked_reason(player, RecipeDB.find(recipe_id)) != ""
	_gold.text = "%d gold" % inventory.gold
	for index in Inventory.CAPACITY:
		var item := _bag_item(index)
		_style_button(_bag_buttons[index], item)
		_bag_counts[index].text = str(item.count) if item and item.count > 1 else ""
	for slot in _slot_buttons:
		var item := player.equipment.get_item(slot)
		var button := _slot_buttons[slot]
		_style_button(button, item)
		if item == null:
			# A faint outline of what belongs here.
			button.icon = ItemDB.icon(SLOT_ICONS[slot])
			_tint_icon(button, Color(1, 1, 1, 0.16))
	var progress := player.equipment.set_progress()
	_set_label.text = "%s set  %d / %d" % [progress["tier"], progress["count"], ItemDB.SET_SLOTS.size()] if progress["count"] >= 2 else ""
	_refresh_details()


func _refresh_details() -> void:
	var shown := _hovered if _hovered else _selected
	_detail_frame.visible = shown != null
	if shown == null:
		_details.text = "[color=#%s]Select an item to see what it does.\n\nRight-click an item to equip or use it at once.[/color]" % UITheme.DIM.to_html(false)
	else:
		_detail_icon.texture = shown.icon()
		_detail_icon.modulate = shown.tint()
		_detail_frame.add_theme_stylebox_override("panel", _frame_style(shown, false))
		_details.text = _describe(shown)

	var item := _selected
	var worn := item != null and _equipped_slot(item) != ""
	var in_bag := item != null and item in player.inventory.items
	_primary.disabled = item == null or not (item.is_equipment() or item.is_consumable() or item.is_placeable())
	_primary.text = "Place" if item and item.is_placeable() else "Use" if item and item.is_consumable() else "Equipped  -  click to unequip" if worn else "Equip"
	_discard.disabled = not in_bag
	_upgrade.disabled = item == null or not item.is_equipment() or not item.is_upgradable() or item.upgrade >= ItemDB.MAX_UPGRADE
	_enchant.disabled = item == null or not item.is_equipment()
	_salvage.disabled = not in_bag or not item.is_equipment()


## BBCode description of an item.
func _describe(item: Item) -> String:
	var dim := UITheme.DIM.to_html(false)
	var text := UITheme.TEXT.to_html(false)
	var lines: PackedStringArray = []
	var def := item.definition()
	lines.append("[font_size=20][color=#%s]%s[/color][/font_size]" % [item.color().to_html(false), item.display_name()])
	var rarity: String = ItemDB.RARITIES[item.rarity]["name"]
	if not item.is_equipment():
		var kind := "Tool" if item.is_tool() else "Consumable" if item.is_consumable() else "Building" if item.is_placeable() else "Material"
		lines.append("[color=#%s]%s[/color]  [color=#%s]-  %s[/color]" % [item.color().to_html(false), rarity, dim, kind])
		lines.append("")
		lines.append("[i][color=#%s]%s[/color][/i]" % [dim, def["text"]])
		if item.is_stackable():
			lines.append("")
			lines.append("[color=#%s]You have %d.[/color]" % [dim, player.inventory.count_of(item.id)])
		return "\n".join(lines)

	var kind_name: String = "Two-handed" if def.get("two_handed", false) else ItemDB.SLOT_NAMES[item.slot()]
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
	for modifier in item.implicit_modifiers():
		lines.append("[color=#%s]+[/color] %s" % [UITheme.HEADING.to_html(false), ItemDB.describe_modifier(modifier)])
	for modifier in item.mods:
		lines.append("[color=#%s]+[/color] [color=#%s]%s[/color]" % [UITheme.HEADING.to_html(false), UITheme.INFO.to_html(false), ItemDB.describe_modifier(modifier)])
	if not item.enchant.is_empty():
		lines.append("[color=#c08cff]+ %s  (enchanted)[/color]" % ItemDB.describe_modifier(item.enchant))
	if _equipped_slot(item) == "":
		var current := player.equipment.get_item(player.equipment.target_slot(item))
		if current:
			lines.append("")
			lines.append("[color=#%s]Wearing: %s[/color]" % [dim, current.display_name()])
	return "\n".join(lines)


func _select(item: Item) -> void:
	_selected = item
	_message.text = _costs(item)
	_message.add_theme_color_override("font_color", UITheme.DIM)
	refresh()


func _hover(item: Item) -> void:
	_hovered = item
	_refresh_details()


## What upgrading and enchanting the item would cost, as one line.
func _costs(item: Item) -> String:
	if item == null or not item.is_equipment():
		return ""
	var parts: PackedStringArray = []
	if item.is_upgradable() and item.upgrade < ItemDB.MAX_UPGRADE:
		var cost := Crafting.upgrade_cost(item)
		parts.append("Upgrade: %d %s, %d gold" % [cost["ingots"], ItemDB.ITEMS[cost["ingot"]]["name"], cost["gold"]])
	var enchant := Crafting.enchant_cost(item)
	parts.append("Enchant: %d dust, %d essence" % [enchant["dust"], enchant["essence"]])
	return "\n".join(parts)


## Equips, unequips, or uses the selected item.
func _use_selected() -> void:
	if _selected == null:
		return
	var result := ""
	if _selected.is_placeable():
		result = player.use_item(_selected)
		if result == "":
			# Step out of the menu so the player can choose the spot.
			PauseMenu.close_menus(self)
			return
	elif _selected.is_consumable():
		result = player.use_item(_selected)
	elif _selected.is_equipment():
		var slot := _equipped_slot(_selected)
		result = player.equipment.unequip(slot) if slot != "" else player.equipment.equip(_selected)
	_report(result)


## Runs a crafting action (upgrade, enchant, salvage) on the selected item.
func _act(action: Callable) -> void:
	if _selected:
		_report(action.call(player, _selected))


func _report(result: String) -> void:
	refresh()
	if result != "":
		_message.text = result
		_message.add_theme_color_override("font_color", UITheme.BAD)
	else:
		_message.text = _costs(_selected)
		_message.add_theme_color_override("font_color", UITheme.DIM)


func _discard_selected() -> void:
	if _selected and _selected in player.inventory.items:
		var item := _selected
		_selected = null
		player.inventory.remove(item)


func _bag_item(index: int) -> Item:
	return player.inventory.items[index] if index < player.inventory.items.size() else null


func _equipped_slot(item: Item) -> String:
	for slot in player.equipment.equipped:
		if player.equipment.equipped[slot] == item:
			return slot
	return ""


## Connects a slot button to whatever item it currently shows.
func _wire(button: Button, item_of: Callable) -> void:
	button.pressed.connect(func() -> void: _select(item_of.call()))
	button.mouse_entered.connect(func() -> void: _hover(item_of.call()))
	button.mouse_exited.connect(func() -> void: _hover(null))
	button.gui_input.connect(func(event: InputEvent) -> void:
		var click := event as InputEventMouseButton
		if click and click.pressed and click.button_index == MOUSE_BUTTON_RIGHT and item_of.call():
			_select(item_of.call())
			_use_selected()
	)


func _item_button(side: float) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(side, side)
	button.focus_mode = Control.FOCUS_NONE
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return button


func _tint_icon(button: Button, tint: Color) -> void:
	for state: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "icon_disabled_color"]:
		button.add_theme_color_override(state, tint)


## A slot frame in the item's rarity colour; the selected item's is bright.
func _frame_style(item: Item, selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("151823")
	style.border_color = Color("3a3e50")
	style.set_border_width_all(2)
	style.set_content_margin_all(5)
	if item:
		style.border_color = item.color().darkened(0.2)
		style.bg_color = item.color().darkened(0.84)
		if selected:
			style.border_color = Color.WHITE
			style.set_border_width_all(3)
	return style


func _style_button(button: Button, item: Item) -> void:
	var style := _frame_style(item, item != null and item == _selected)
	var hover := style.duplicate()
	hover.bg_color = style.bg_color.lightened(0.08)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_stylebox_override("hover", hover)
	button.icon = item.icon() if item else null
	_tint_icon(button, item.tint() if item else Color.WHITE)
