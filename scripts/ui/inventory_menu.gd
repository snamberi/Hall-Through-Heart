class_name InventoryMenu
extends GameMenu
## Inventory: the bag on the left (searchable and filtered; it scrolls, and
## a backpack adds pockets), the character with what they wear in the
## middle and the weapons and tools the hotbar draws beneath, and the
## chosen item's inspector on the right: what it is, its numbers, what it
## needs, what it gives, then what can be done with it.
##
## Left-click selects an item; right-click equips, unequips, or uses it.
## Hover an item and press 1-9 to put it on the hotbar, or Q to make it
## the quick-use item. A tooltip follows the mouse.

const COLUMNS := 8
const SLOT_SIZE := 46.0
const DOLL_SLOT := 50.0
## From the top of one equipment slot to the top of the next (its name
## sits in the gap).
const DOLL_PITCH := 62.0
const DOLL_SIZE := Vector2(336.0, 376.0)
## Equipment slots down each side of the character.
const LEFT_SLOTS: Array[String] = ["necklace", "ring_1", "ring_2", "artifact", "backpack", "belt"]
const RIGHT_SLOTS: Array[String] = ["helmet", "chest", "legs", "boots", "off_hand"]
## Faint icon shown in an empty equipment slot.
const SLOT_ICONS := {"necklace": 10, "ring_1": 11, "ring_2": 11, "artifact": 12, "backpack": 93, "belt": 115,
	"helmet": 6, "chest": 7, "legs": 8, "boots": 9, "off_hand": 5,
	"combat": 38, "weapon_1": 33, "weapon_2": 0, "weapon_3": 0, "tool_pickaxe": 49, "tool_hatchet": 50, "tool_rod": 51}
const BELT_SLOT := 42.0
## Rows of the bag shown at once; the rest scroll.
const VISIBLE_ROWS := 8
## The same, while the hand-crafting strip is open beneath.
const ROWS_WITH_CRAFTING := 6
const FILTERS: Array[Array] = [["all", "All"], ["gear", "Gear"], ["materials", "Materials"], ["supplies", "Supplies"]]
const INSPECTOR := 340.0

var _count: Label
var _gold: Label
var _bag_buttons: Array[Button] = []
var _bag_counts: Array[Label] = []
var _bag_locks: Array[TextureRect] = []
var _slot_buttons: Dictionary[String, Button] = {}
var _set_label: Label
var _detail_icon: TextureRect
var _detail_frame: PanelContainer
var _detail_name: Label
var _detail_kind: Label
var _detail_badges: HBoxContainer
var _numbers: HBoxContainer
var _details: RichTextLabel
var _primary: Button
var _upgrade: Button
var _enchant: Button
var _infuse: Button
var _socket: Button
var _salvage: Button
var _discard: Button
var _lock: Button
var _secondary: Button
var _pick_toggle: Button
var _search: LineEdit
var _filter := "all"
var _filter_buttons: Dictionary = {}
var _scroll: ScrollContainer
var _craft_toggle: Button
var _craft_box: VBoxContainer
## What the bag grid shows now: the whole bag, or what the search and
## filter leave.
var _shown: Array = []
## Marking many items at once (to throw them away together).
var _picking := false
var _marked: Array[Item] = []
var _confirming := false
var _bag_marks: Array[MarkOverlay] = []
var _message: Label
var _hand_row: HBoxContainer
var _hand_buttons: Dictionary[String, Button] = {}
var _grid: GridContainer
var _tip: ItemTooltip
var _belt_marks: Dictionary[String, ColorRect] = {}

var _selected: Item
var _hovered: Item


func _build() -> void:
	content.add_theme_constant_override("separation", 10)
	# The title, with what the bag holds beside it.
	var title_row := HBoxContainer.new()
	content.add_child(title_row)
	var purse := HBoxContainer.new()
	purse.add_theme_constant_override("separation", 8)
	purse.custom_minimum_size.x = 330.0
	title_row.add_child(purse)
	purse.add_child(UITheme.icon(13, 26.0))
	_count = UITheme.strong("", 18)
	_count.custom_minimum_size.x = 84.0
	purse.add_child(_count)
	purse.add_child(UITheme.icon(ItemDB.GOLD_ICON, 26.0))
	_gold = UITheme.strong("", 18, UITheme.GOLD)
	purse.add_child(_gold)
	var title := UITheme.heading("INVENTORY", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	var balance := Control.new()
	balance.custom_minimum_size.x = 330.0
	title_row.add_child(balance)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	content.add_child(columns)

	# --- left: the bag
	var bag_panel := UITheme.inset_panel()
	columns.add_child(bag_panel)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	bag_panel.add_child(left)
	var grid_width := COLUMNS * (SLOT_SIZE + 3.0) + 12.0
	_search = UITheme.search_box("Search items...", grid_width, refresh)
	left.add_child(_search)
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 4)
	left.add_child(filters)
	for entry: Array in FILTERS:
		var id: String = entry[0]
		var button := UITheme.button(entry[1], func() -> void:
			_filter = id
			refresh()
		, (grid_width - 12.0) / FILTERS.size())
		button.toggle_mode = true
		button.custom_minimum_size.y = 30.0
		filters.add_child(button)
		_filter_buttons[id] = button
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.custom_minimum_size = Vector2(grid_width, VISIBLE_ROWS * (SLOT_SIZE + 3.0))
	left.add_child(_scroll)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 3)
	_grid.add_theme_constant_override("v_separation", 3)
	_scroll.add_child(_grid)
	_ensure_slots(Inventory.BASE)
	var bag_actions := HBoxContainer.new()
	bag_actions.add_theme_constant_override("separation", 4)
	left.add_child(bag_actions)
	bag_actions.add_child(UITheme.button("Sort", func() -> void: player.inventory.sort(), 62.0))
	_pick_toggle = UITheme.button("Select many", _toggle_picking, 112.0)
	_pick_toggle.tooltip_text = "Mark several items to throw away together. Locked items are left alone."
	bag_actions.add_child(_pick_toggle)
	var common := UITheme.button("Mark common", _mark_common, 112.0)
	common.tooltip_text = "Marks every common piece of gear that is not locked."
	bag_actions.add_child(common)
	_craft_toggle = UITheme.button("Crafting", _toggle_crafting, 106.0)
	_craft_toggle.toggle_mode = true
	_craft_toggle.tooltip_text = "Simple things made by hand, with no workbench."
	bag_actions.add_child(_craft_toggle)

	# Simple things that need no workbench: tucked away until asked for.
	_craft_box = VBoxContainer.new()
	_craft_box.add_theme_constant_override("separation", 4)
	_craft_box.visible = false
	left.add_child(_craft_box)
	_hand_row = HBoxContainer.new()
	_hand_row.add_theme_constant_override("separation", 4)
	_craft_box.add_child(_hand_row)
	for recipe_id in RecipeDB.NO_TABLE:
		var recipe := RecipeDB.find(recipe_id)
		var button := Button.new()
		# A picture each; pointing at one says what it is and what it takes.
		button.custom_minimum_size = Vector2((grid_width - 20.0) / maxf(RecipeDB.NO_TABLE.size(), 1.0), 52.0)
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 34)
		button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var made := Item.create(recipe["item"]) if recipe.has("item") else LootGenerator.make_equipment(1, 0, recipe.get("equipment", "club"))
		button.icon = made.icon()
		_tint_icon(button, made.icon_tint())
		button.pressed.connect(func() -> void: _report(Crafting.craft(player, recipe)))
		button.mouse_entered.connect(func() -> void: _tip.show_recipe(recipe, player))
		button.mouse_exited.connect(func() -> void: _tip.hide_tip())
		UITheme.sounds(button)
		_hand_row.add_child(button)
		_hand_buttons[recipe_id] = button

	# --- middle: the character and what they wear
	var doll_panel := UITheme.inset_panel()
	columns.add_child(doll_panel)
	var middle := VBoxContainer.new()
	middle.add_theme_constant_override("separation", 6)
	doll_panel.add_child(middle)
	var doll := CharacterPreview.new()
	doll.custom_minimum_size = DOLL_SIZE
	doll.setup(player)
	middle.add_child(doll)
	# Every slot down each side gets a whole place of its own: the area is
	# as tall as the longer column needs.
	for side: Array in [[LEFT_SLOTS, 0.0], [RIGHT_SLOTS, DOLL_SIZE.x - DOLL_SLOT]]:
		var slots: Array = side[0]
		for row in slots.size():
			var slot: String = slots[row]
			var button := _item_button(DOLL_SLOT)
			button.position = Vector2(side[1], row * DOLL_PITCH)
			button.size = Vector2(DOLL_SLOT, DOLL_SLOT)
			_wire(button, func() -> Item: return player.equipment.get_item(slot), Equipment.BELT_NAMES.get(slot, ItemDB.SLOT_NAMES.get(slot, slot)))
			# The slot's name, always shown, in the gap beneath it.
			var name_label := UITheme.label(Equipment.BELT_NAMES.get(slot, ItemDB.SLOT_NAMES.get(slot, slot)), 14, Color("a89a80"))
			name_label.position = Vector2(side[1] - 16.0, row * DOLL_PITCH + DOLL_SLOT - 5.0)
			name_label.size = Vector2(DOLL_SLOT + 32.0, 16.0)
			name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			doll.add_child(name_label)
			doll.add_child(button)
			_slot_buttons[slot] = button
	_set_label = UITheme.label("", 14, UITheme.GOOD)
	_set_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_set_label.custom_minimum_size.y = 18.0
	middle.add_child(_set_label)
	middle.add_child(UITheme.rule())
	# The weapons and tools the hotbar's first keys draw: not the belt that
	# is worn (that is an equipment slot above).
	var quick_title := UITheme.heading("Weapons & tools", 15)
	quick_title.tooltip_text = "What hotbar keys 1 to 7 draw. Hover an item in the bag and press a key to put it there."
	quick_title.mouse_filter = Control.MOUSE_FILTER_PASS
	middle.add_child(quick_title)
	var belt := HBoxContainer.new()
	belt.add_theme_constant_override("separation", 4)
	belt.alignment = BoxContainer.ALIGNMENT_CENTER
	middle.add_child(belt)
	for index in Equipment.BELT.size():
		var slot: String = Equipment.BELT[index]
		var button := _item_button(BELT_SLOT)
		button.tooltip_text = ""
		_wire(button, func() -> Item: return player.equipment.equipped.get(slot), "%s  (key %d)" % [Equipment.BELT_NAMES[slot], index + 1])
		var key := UITheme.label(str(index + 1), 14, UITheme.HEADING)
		key.position = Vector2(4, -2)
		key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		key.add_theme_color_override("font_outline_color", Color.BLACK)
		key.add_theme_constant_override("outline_size", 3)
		button.add_child(key)
		# In hand: a gold bar along the slot's foot, not small print inside it.
		var mark := ColorRect.new()
		mark.color = UITheme.GOLD
		mark.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		mark.offset_top = -4.0
		mark.offset_bottom = 0.0
		mark.offset_left = 3.0
		mark.offset_right = -3.0
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(mark)
		_belt_marks[slot] = mark
		belt.add_child(button)
		_slot_buttons[slot] = button
		if index == 3:
			var gap := Control.new()
			gap.custom_minimum_size.x = 6.0
			belt.add_child(gap)
	var hint := UITheme.label("Hover an item, press 1-9 for the hotbar or %s for quick use" % GameSettings.describe("quick_use").split(" / ")[0], 14, UITheme.DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(DOLL_SIZE.x, 0)
	middle.add_child(hint)

	# --- right: the inspector, then what can be done
	var detail_panel := UITheme.inset_panel()
	columns.add_child(detail_panel)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.custom_minimum_size = Vector2(INSPECTOR, 0.0)
	detail_panel.add_child(right)
	# Name, rarity and kind, and whether it is worn.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	right.add_child(top)
	_detail_frame = PanelContainer.new()
	_detail_frame.custom_minimum_size = Vector2(64.0, 64.0)
	_detail_frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(_detail_frame)
	_detail_icon = UITheme.icon(0, 50.0)
	_detail_frame.add_child(_detail_icon)
	var naming := VBoxContainer.new()
	naming.add_theme_constant_override("separation", 1)
	naming.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(naming)
	_detail_name = UITheme.heading("", 20)
	_detail_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_name.custom_minimum_size.x = INSPECTOR - 80.0
	naming.add_child(_detail_name)
	_detail_kind = UITheme.label("", 14, UITheme.DIM)
	naming.add_child(_detail_kind)
	_detail_badges = HBoxContainer.new()
	_detail_badges.add_theme_constant_override("separation", 6)
	naming.add_child(_detail_badges)
	# The headline numbers in a row of cells.
	_numbers = HBoxContainer.new()
	_numbers.add_theme_constant_override("separation", 0)
	right.add_child(_numbers)
	right.add_child(UITheme.rule())
	# Requirements, what it gives, and its story: this part scrolls while
	# the actions below stay put.
	_details = RichTextLabel.new()
	_details.bbcode_enabled = true
	_details.fit_content = false
	_details.scroll_active = true
	_details.custom_minimum_size = Vector2(INSPECTOR, 110.0)
	_details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UITheme.font_size(_details, 14, "normal_font_size")
	UITheme.font_size(_details, 14, "bold_font_size")
	UITheme.font_size(_details, 14, "italics_font_size")
	right.add_child(_details)
	_message = UITheme.reason("", INSPECTOR)
	_message.custom_minimum_size.y = 20.0
	right.add_child(_message)
	# The action that matters most for this item, then the routine ones,
	# then the ones that destroy, set apart.
	_primary = UITheme.primary_button("Equip", _use_selected, INSPECTOR)
	right.add_child(_primary)
	_secondary = UITheme.button("", _secondary_action, INSPECTOR)
	right.add_child(_secondary)
	var smith := HBoxContainer.new()
	smith.add_theme_constant_override("separation", 4)
	right.add_child(smith)
	_upgrade = UITheme.button("Upgrade", func() -> void: _act(Crafting.upgrade), 82.0)
	_enchant = UITheme.button("Enchant", func() -> void: _act(Crafting.enchant), 82.0)
	_infuse = UITheme.button("Infuse", _open_infusions, 82.0)
	_infuse.tooltip_text = "Work monster and animal parts into this piece for a lasting bonus."
	_socket = UITheme.button("Gems", _open_gems, 82.0)
	for button: Button in [_upgrade, _enchant, _infuse, _socket]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		smith.add_child(button)
	var risky := HBoxContainer.new()
	risky.add_theme_constant_override("separation", 4)
	right.add_child(risky)
	_lock = UITheme.button("Lock", _toggle_lock, 100.0)
	_lock.tooltip_text = "A locked piece cannot be salvaged, discarded or sold in bulk until unlocked."
	_lock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	risky.add_child(_lock)
	var gap := Control.new()
	gap.custom_minimum_size.x = 14.0
	risky.add_child(gap)
	_salvage = UITheme.danger_button("Salvage", func() -> void: _act(Crafting.salvage), 100.0)
	_salvage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	risky.add_child(_salvage)
	_discard = UITheme.danger_button("Discard", _discard_selected, 100.0)
	_discard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	risky.add_child(_discard)

	_tip = ItemTooltip.new()
	add_child(_tip)
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree():
			_tip.hide_tip()
	)
	player.inventory.changed.connect(refresh_if_open)
	player.equipment.changed.connect(refresh_if_open)


## Makes sure the bag has a button for every slot (a backpack adds more).
func _ensure_slots(count: int) -> void:
	while _bag_buttons.size() < count:
		var index := _bag_buttons.size()
		var button := _item_button(SLOT_SIZE)
		_wire(button, func() -> Item: return _bag_item(index))
		var count_label := UITheme.label("", 14)
		count_label.add_theme_font_override("font", UITheme.body_bold())
		count_label.add_theme_color_override("font_outline_color", Color.BLACK)
		count_label.add_theme_constant_override("outline_size", 5)
		count_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		count_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		count_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
		count_label.position -= Vector2(4, 0)
		count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(count_label)
		# A small padlock on pieces the player has locked.
		var lock := TextureRect.new()
		lock.texture = UITheme.lock_texture()
		lock.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		lock.position = Vector2(1, 1)
		lock.size = Vector2(14, 14)
		lock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lock.visible = false
		button.add_child(lock)
		_bag_locks.append(lock)
		_bag_marks.append(MarkOverlay.attach(button))
		_grid.add_child(button)
		_bag_buttons.append(button)
		_bag_counts.append(count_label)
	for index in _bag_buttons.size():
		_bag_buttons[index].visible = index < count


## Which filter an item falls under.
static func category(item: Item) -> String:
	if item.is_equipment() or item.is_tool() or item.is_backpack() or item.is_belt() or item.is_relic():
		return "gear"
	if item.is_consumable() or item.is_placeable():
		return "supplies"
	return "materials"


func refresh() -> void:
	var inventory := player.inventory
	# Forget a selection that no longer exists (discarded, used up, salvaged).
	if _selected and not _selected in inventory.items and _equipped_slot(_selected) == "":
		_selected = null
	# The whole bag with its empty pockets, or just what is searched for.
	var words := _search.text.strip_edges().to_lower()
	var narrowed := words != "" or _filter != "all"
	if narrowed:
		_shown = inventory.items.filter(func(item: Item) -> bool:
			return item != null and (_filter == "all" or category(item) == _filter) \
				and (words == "" or item.display_name().to_lower().contains(words) or ItemText.type_name(item).to_lower().contains(words))
		)
	else:
		_shown = inventory.items
	for id: String in _filter_buttons:
		(_filter_buttons[id] as Button).set_pressed_no_signal(id == _filter)
	var slots := _shown.size() if narrowed else maxi(inventory.capacity(), inventory.items.size())
	_ensure_slots(maxi(slots, 1))
	_count.text = "%d / %d" % [inventory.items.size(), inventory.capacity()]
	_count.add_theme_color_override("font_color", UITheme.BAD if inventory.items.size() >= inventory.capacity() else UITheme.TEXT)
	for recipe_id in _hand_buttons:
		var blocked := Crafting.blocked_reason(player, RecipeDB.find(recipe_id))
		_hand_buttons[recipe_id].disabled = blocked != ""
	_gold.text = "%s gold" % _thousands(inventory.gold)
	_marked = _marked.filter(func(item: Item) -> bool: return item in inventory.items)
	for index in _bag_buttons.size():
		if not _bag_buttons[index].visible:
			continue
		var item := _bag_item(index)
		_style_button(_bag_buttons[index], item)
		_bag_counts[index].text = str(item.count) if item and item.count > 1 else ""
		_bag_marks[index].visible = item != null and item in _marked
		_bag_locks[index].visible = item != null and item.locked
	for slot in _belt_marks:
		_belt_marks[slot].visible = player.equipment.active_slot == slot and player.equipment.equipped.has(slot)
	for slot in _slot_buttons:
		var item: Item = player.equipment.equipped.get(slot)
		var button := _slot_buttons[slot]
		_style_button(button, item)
		if item == null:
			# A faint outline of what belongs here.
			button.icon = ItemDB.icon(SLOT_ICONS[slot])
			_tint_icon(button, Color(1, 1, 1, 0.3))
	var progress := player.equipment.set_progress()
	var notes: PackedStringArray = []
	if progress["count"] >= 2:
		notes.append("%s set  %d / %d" % [progress["tier"], progress["count"], ItemDB.SET_SLOTS.size()])
	var attuned := player.equipment.attunement()
	if not attuned.is_empty():
		notes.append(attuned["name"])
	_set_label.text = "   ·   ".join(notes)
	_pick_toggle.text = "Done" if _picking else "Select many"
	_refresh_details()


static func _thousands(number: int) -> String:
	var text := str(absi(number))
	var out := ""
	while text.length() > 3:
		out = "," + text.right(3) + out
		text = text.left(text.length() - 3)
	return ("-" if number < 0 else "") + text + out


func _toggle_crafting() -> void:
	_craft_box.visible = not _craft_box.visible
	_craft_toggle.set_pressed_no_signal(_craft_box.visible)
	_scroll.custom_minimum_size.y = (ROWS_WITH_CRAFTING if _craft_box.visible else VISIBLE_ROWS) * (SLOT_SIZE + 3.0)


func _toggle_lock() -> void:
	if _selected == null:
		return
	_selected.locked = not _selected.locked
	_marked.erase(_selected)
	SaveGame.request_save()
	refresh()


func _refresh_details() -> void:
	var shown := _hovered if _hovered else _selected
	_detail_frame.visible = shown != null
	_numbers.visible = shown != null
	for child in _detail_badges.get_children() + _numbers.get_children():
		child.queue_free()
	if shown == null:
		_detail_name.text = "Nothing chosen"
		_detail_name.add_theme_color_override("font_color", UITheme.DIM)
		_detail_kind.text = ""
		_details.text = "[color=#%s]Click an item to see what it does and what you can do with it.\n\nRight-click equips or uses it at once.[/color]" % UITheme.DIM.to_html(false)
	else:
		_detail_icon.texture = shown.icon()
		_detail_icon.modulate = shown.icon_tint()
		_detail_frame.add_theme_stylebox_override("panel", _frame_style(shown, false))
		_detail_name.text = shown.display_name()
		_detail_name.add_theme_color_override("font_color", shown.color())
		_detail_kind.text = ItemText.headline(shown)
		# Worn or in hand is said in words, not left to the frame's colour.
		var slot := _equipped_slot(shown)
		if slot != "":
			_detail_badges.add_child(UITheme.badge("In hand" if slot == player.equipment.active_slot else "Equipped", "gold"))
		if shown.locked:
			_detail_badges.add_child(UITheme.badge("Locked", "info"))
		if shown.is_equipment() and player.leveling.level < shown.level:
			_detail_badges.add_child(UITheme.badge("Needs level %d" % shown.level, "bad"))
		var cells := ItemText.numbers(shown, player)
		for index in cells.size():
			_numbers.add_child(_number_cell(cells[index], index > 0))
		_details.text = ItemText.describe(shown, player, true)

	var item := _selected
	var worn := item != null and _equipped_slot(item) != ""
	var in_bag := item != null and item in player.inventory.items
	var usable := item != null and (item.is_equipment() or item.is_consumable() or item.is_placeable() or item.is_tool() or item.is_backpack() or item.is_belt() or item.is_relic())
	_primary.disabled = not usable
	_primary.text = "Put in relic bag" if item and item.is_relic() else "Place" if item and item.is_placeable() else "Use" if item and item.is_consumable() else "Unequip" if worn else "Equip"
	_primary.tooltip_text = "" if usable else ("Choose an item first." if item == null else "This is a material: it is used in crafting, not worn or eaten.")
	var keeper := item != null and item.locked
	_discard.disabled = (not in_bag and _marked.is_empty()) or (keeper and _marked.is_empty())
	_discard.text = ("Really? (%d)" % _marked.size() if _confirming else "Discard %d" % _marked.size()) if not _marked.is_empty() else ("Really?" if _confirming else "Discard")
	_discard.tooltip_text = "Locked: unlock it first." if keeper else "Throws the item away for good. Asks twice."
	_secondary.visible = item != null and (item.is_consumable() or item.is_placeable() or (item.is_equipment() and item.is_upgradable()))
	if _secondary.visible:
		if item.is_equipment():
			var problem := Crafting.level_up_problem(player, item)
			_secondary.text = "Level up to %d  ·  %d gold" % [item.level + 1, Crafting.level_up_cost(item)]
			_secondary.disabled = problem != "" and not problem.begins_with("Costs")
			_secondary.tooltip_text = problem
		else:
			var spot := _hotbar_spot(item)
			var already := player.hotbar.id_in(spot) == item.id
			_secondary.text = ("On hotbar slot %d" if already else "Put on hotbar slot %d") % (spot + 1)
			_secondary.disabled = already
			_secondary.tooltip_text = ""
	var gear := item != null and item.is_equipment()
	_upgrade.disabled = not gear or not item.is_upgradable() or item.upgrade >= ItemDB.MAX_UPGRADE
	_upgrade.tooltip_text = "" if not _upgrade.disabled else ("Only weapons and armour can be upgraded." if not gear or not item.is_upgradable() else "Already at the highest upgrade.")
	_enchant.disabled = not gear
	_enchant.tooltip_text = "" if gear else "Only gear can be enchanted."
	_infuse.disabled = not Infusions.can_infuse(item)
	_socket.disabled = not gear or item.sockets.is_empty()
	_socket.tooltip_text = "" if not _socket.disabled else ("Only gear has sockets." if not gear else "This piece has no sockets.")
	_salvage.disabled = not in_bag or not gear or keeper
	_salvage.tooltip_text = "Locked: unlock it first." if keeper else ("Breaks the piece down into materials. It is gone for good." if gear and in_bag else "Only gear in the bag can be salvaged.")
	_lock.disabled = item == null or category(item) != "gear" or item.is_stackable()
	_lock.text = "Unlock" if keeper else "Lock"


## One headline number: its name small above, the value large, and how it
## differs from what is worn beside it.
func _number_cell(cell: Array, divided: bool) -> Control:
	var box := HBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 0)
	if divided:
		var line := ColorRect.new()
		line.color = UITheme.LINE
		line.custom_minimum_size = Vector2(1, 0)
		box.add_child(line)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", -2)
	box.add_child(column)
	var title := UITheme.label(cell[0], 14, UITheme.DIM)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var value := UITheme.strong(cell[1], 22)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(value)
	var note := UITheme.label(("%s vs worn" % cell[2]) if cell[2] != "" else " ", 14, UITheme.GOOD if cell[3] else UITheme.BAD)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(note)
	return box


func _select(item: Item) -> void:
	_selected = item
	_confirming = false
	_message.text = _costs(item)
	_message.add_theme_color_override("font_color", UITheme.DIM)
	refresh()


## Typing in the search box must not also assign hotbar keys.
func _typing() -> bool:
	return get_viewport().gui_get_focus_owner() is LineEdit


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
	elif _selected.is_relic():
		result = player.relics.store(_selected)
	elif _selected.is_equipment() or _selected.is_tool() or _selected.is_backpack() or _selected.is_belt():
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


## A small window listing the gems in the bag that fit the selected item.
## Materials in the bag that can be worked into the chosen piece.
func _open_infusions() -> void:
	var item := _selected
	if not Infusions.can_infuse(item):
		return
	var popup := PopupPanel.new()
	popup.add_theme_stylebox_override("panel", UITheme.get_theme().get_stylebox("panel", "PanelContainer"))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	popup.add_child(box)
	box.add_child(UITheme.heading("Infuse %s" % item.display_name(), 18))
	var price := Infusions.cost(item)
	var room := Infusions.room(item)
	box.add_child(UITheme.label("%d of %d infusions used. The next takes %d of a material and %d gold." % [item.infusions.size(), room, price["count"], price["gold"]], 14, UITheme.DIM))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(420, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)
	var seen := {}
	for material in player.inventory.items:
		if material == null or seen.has(material.id) or not Infusions.MATERIALS.has(material.id):
			continue
		seen[material.id] = true
		var have := player.inventory.count_of(material.id)
		var button := UITheme.button("%s (%d)  ->  %s: %s" % [material.display_name(), have, Infusions.MATERIALS[material.id]["name"], Infusions.describe(material.id, item.level)], func() -> void:
			_report(Infusions.infuse(player, item, material.id))
			popup.hide()
		, 400.0)
		button.icon = material.icon()
		button.add_theme_color_override("icon_normal_color", material.tint())
		button.disabled = Infusions.problem(player, item, material.id) != ""
		button.tooltip_text = Infusions.problem(player, item, material.id)
		list.add_child(button)
	if seen.is_empty():
		list.add_child(UITheme.label("No parts to infuse. Hunt animals and monsters: hides, horns,\nfeathers, silk, cores and more all work.", 14, UITheme.DIM))
	box.add_child(UITheme.button("Close", popup.hide, 420.0))
	add_child(popup)
	popup.popup_centered()
	popup.popup_hide.connect(popup.queue_free)


func _open_gems() -> void:
	var item := _selected
	if item == null:
		return
	var popup := PopupPanel.new()
	popup.add_theme_stylebox_override("panel", UITheme.get_theme().get_stylebox("panel", "PanelContainer"))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	popup.add_child(box)
	box.add_child(UITheme.heading("Gems for %s" % item.display_name(), 18))
	var free := item.sockets.count("")
	box.add_child(UITheme.label("%d of %d sockets empty" % [free, item.sockets.size()], 14, UITheme.DIM))
	var seen := {}
	for gem in player.inventory.items:
		if gem == null or not gem.definition().has("gem") or seen.has(gem.id):
			continue
		seen[gem.id] = true
		var button := UITheme.button("%s  ->  %s" % [gem.display_name(), ItemDB.describe_modifier(Gems.modifier(gem.id, item.slot()))], func() -> void:
			_report(Gems.insert(player, item, gem))
			popup.hide()
		, 360.0)
		button.icon = gem.icon()
		button.add_theme_color_override("icon_normal_color", gem.tint())
		button.disabled = free == 0
		box.add_child(button)
	if seen.is_empty():
		box.add_child(UITheme.label("You have no gems. Mine ore or beat strong foes.", 14, UITheme.DIM))
	box.add_child(UITheme.button("Remove all gems  (%d gold)" % (Gems.REMOVE_COST_PER_LEVEL * item.level), func() -> void:
		_report(Gems.remove_all(player, item))
		popup.hide()
	, 360.0))
	box.add_child(UITheme.button("Close", popup.hide, 360.0))
	add_child(popup)
	popup.popup_centered()
	popup.popup_hide.connect(popup.queue_free)


func _discard_selected() -> void:
	# Throwing things away asks twice.
	if not _confirming:
		_confirming = true
		refresh()
		return
	_confirming = false
	if not _marked.is_empty():
		var count := _marked.size()
		for item in _marked.duplicate():
			if item in player.inventory.items:
				player.inventory.remove(item)
		_marked.clear()
		_report("")
		_message.text = "Threw away %d item%s." % [count, "" if count == 1 else "s"]
		return
	if _selected and _selected in player.inventory.items and not _selected.locked:
		var item := _selected
		_selected = null
		player.inventory.remove(item)


## Marking mode: clicks mark items instead of selecting them.
func _toggle_picking() -> void:
	_picking = not _picking
	_confirming = false
	if not _picking:
		_marked.clear()
	refresh()


## Marks every common piece of gear in the bag (the usual junk).
func _mark_common() -> void:
	_picking = true
	_confirming = false
	for item in player.inventory.items:
		if item.is_equipment() and item.rarity == 0 and not item.is_unique() and item.set_id == "" and not item.locked and not item in _marked:
			_marked.append(item)
	refresh()


## Which hotbar slot a usable item goes in: food in 9, potions and other
## usable things in 7 or 8 (whichever is free, or already holds it).
func _hotbar_spot(item: Item) -> int:
	if ItemDB.course_of(item.id) != "":
		return 9
	for spot: int in [7, 8]:
		if player.hotbar.id_in(spot) == item.id:
			return spot
	for spot: int in [7, 8]:
		if player.hotbar.id_in(spot) == "":
			return spot
	return 7


## The second button: puts a potion or food on the hotbar, or raises a
## weapon or piece of armour a level for gold.
func _secondary_action() -> void:
	var item := _selected
	if item == null:
		return
	if item.is_equipment():
		var result := Crafting.level_up(player, item)
		_report(result)
		if result == "":
			_message.text = "%s is now level %d." % [item.display_name(), item.level]
			_message.add_theme_color_override("font_color", UITheme.GOOD)
		return
	var spot := _hotbar_spot(item)
	var problem := player.hotbar.assign(spot, item)
	_report(problem)
	if problem == "":
		_message.text = "%s is on hotbar slot %d." % [item.display_name(), spot + 1]
		_message.add_theme_color_override("font_color", UITheme.GOOD)


func _bag_item(index: int) -> Item:
	return _shown[index] if index < _shown.size() else null


func _equipped_slot(item: Item) -> String:
	return player.equipment.slot_of(item)


## Connects a slot button to whatever item it currently shows.
## `empty_text` names the slot in the tooltip when nothing is in it.
func _wire(button: Button, item_of: Callable, empty_text: String = "") -> void:
	button.pressed.connect(func() -> void:
		var item: Item = item_of.call()
		if _picking and item != null and item in player.inventory.items and not item.locked:
			if item in _marked:
				_marked.erase(item)
			else:
				_marked.append(item)
			_confirming = false
			refresh()
			return
		_select(item)
	)
	button.mouse_entered.connect(func() -> void:
		var item: Item = item_of.call()
		_hover(item)
		if item:
			_tip.show_item(item, player)
			Audio.play("ui_hover", -18.0, 0.03)
		elif empty_text != "":
			_tip.show_text(empty_text, "Empty.")
	)
	button.mouse_exited.connect(func() -> void:
		_hover(null)
		_tip.hide_tip()
	)
	button.gui_input.connect(func(event: InputEvent) -> void:
		var click := event as InputEventMouseButton
		if click and click.pressed and click.button_index == MOUSE_BUTTON_RIGHT and item_of.call():
			_select(item_of.call())
			_use_selected()
	)


func _item_button(side: float) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(side, side)
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return button


func _tint_icon(button: Button, tint: Color) -> void:
	for state: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "icon_disabled_color"]:
		button.add_theme_color_override(state, tint)


## A slot frame in the item's rarity colour; the selected item's is bright.
func _frame_style(item: Item, selected: bool) -> StyleBoxTexture:
	return ItemGrid.frame_style(item, selected)


func _style_button(button: Button, item: Item) -> void:
	ItemGrid.style_slot(button, item, item != null and item == _selected)


## Hotbar keys put the hovered (or selected) item in that slot; the
## quick-use key makes it the quick item.
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or _typing():
		return
	var item := _hovered if _hovered else _selected
	if item == null:
		return
	if event.is_action_pressed("quick_use"):
		var refused := player.hotbar.set_quick(item)
		_message.add_theme_color_override("font_color", UITheme.GOOD if refused == "" else UITheme.BAD)
		_message.text = "%s is now your quick-use item." % item.display_name() if refused == "" else refused
		get_viewport().set_input_as_handled()
		return
	for index in Hotbar.SIZE:
		if event.is_action_pressed("hotbar_%d" % (index + 1)):
			var problem := player.hotbar.assign(index, item)
			_tip.hide_tip()
			refresh()
			_message.add_theme_color_override("font_color", UITheme.GOOD if problem == "" else UITheme.BAD)
			_message.text = "%s is on hotbar slot %d." % [item.display_name(), index + 1] if problem == "" else problem
			get_viewport().set_input_as_handled()
			return
