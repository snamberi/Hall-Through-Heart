class_name RelicsMenu
extends GameMenu
## The relic bag. Three things are kept apart here: what is worn (one
## relic, or up to three with a good belt), what is stored (up to 15), and
## which worn relic the relic key calls on (its active power).
##
## Left: the worn slots as cards, each marked Equipped, the active one
## marked with the key; locked slots name the belt that opens them.
## Middle: the collection, which can be narrowed and sorted. Right: the
## chosen relic's boon and power in their own blocks, and what to do.

const BELT_FOR_SLOT := ["", "Leather Belt", "Reliquary Belt"]
const FILTERS: Array[Array] = [["all", "All"], ["damage", "Damage"], ["utility", "Utility"]]
const DAMAGE_STATS: Array[String] = ["physical_damage", "fire_damage", "frost_damage", "shadow_damage", "poison_damage", "storm_damage", "holy_damage",
	"critical_chance", "critical_damage", "attack_speed", "magic_power"]
const WIDTH := 330.0

var _tip: ItemTooltip
var _summary: Label
var _bag: ItemGrid
var _worn_cards: Array[Button] = []
var _belt_line: Label
var _filter := "all"
var _filter_buttons: Dictionary = {}
var _sort: OptionButton
var _icon_frame: PanelContainer
var _icon: TextureRect
var _name: Label
var _kind: Label
var _lore: Label
var _badges: HBoxContainer
var _boon: VBoxContainer
var _power_title: Label
var _power_state: HBoxContainer
var _power_text: Label
var _wear_button: Button
var _focus_button: Button
var _discard_button: Button
var _message: Label
var _selected: Item
var _confirm_discard := false


func _build() -> void:
	content.add_theme_constant_override("separation", 8)
	var title := UITheme.heading("RELIC BAG", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	_summary = UITheme.strong("", 16)
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary.tooltip_text = "Relics are won from bosses, and now and then from Ancients. They have no level: a rarer relic gives stronger boons."
	_summary.mouse_filter = Control.MOUSE_FILTER_PASS
	content.add_child(_summary)
	_tip = ItemTooltip.new()
	add_child(_tip)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	columns.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(columns)

	# --- worn
	var worn_panel := UITheme.inset_panel()
	columns.add_child(worn_panel)
	var worn_box := VBoxContainer.new()
	worn_box.add_theme_constant_override("separation", 8)
	worn_panel.add_child(worn_box)
	worn_box.add_child(UITheme.heading("Worn relics", 18))
	for index in 3:
		var card := Button.new()
		card.custom_minimum_size = Vector2(280, 92)
		card.pressed.connect(_on_worn_pressed.bind(index))
		card.gui_input.connect(_on_worn_input.bind(index))
		card.mouse_entered.connect(_on_worn_hover.bind(index))
		card.mouse_exited.connect(func() -> void: _tip.hide_tip())
		UITheme.sounds(card)
		worn_box.add_child(card)
		_worn_cards.append(card)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	worn_box.add_child(spacer)
	worn_box.add_child(UITheme.rule())
	_belt_line = UITheme.paragraph("", 280.0, 14, UITheme.DIM)
	worn_box.add_child(_belt_line)
	worn_box.add_child(UITheme.button("View belt slot", func() -> void: Events.screen_requested.emit("inventory"), 280.0))

	# --- the collection
	var bag_panel := UITheme.inset_panel()
	columns.add_child(bag_panel)
	var bag_box := VBoxContainer.new()
	bag_box.add_theme_constant_override("separation", 8)
	bag_panel.add_child(bag_box)
	bag_box.add_child(UITheme.heading("Relic collection", 18))
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 4)
	bag_box.add_child(tools)
	for entry: Array in FILTERS:
		var id: String = entry[0]
		var button := UITheme.button(entry[1], func() -> void:
			_filter = id
			refresh()
		, 70.0)
		button.toggle_mode = true
		button.custom_minimum_size.y = 32.0
		tools.add_child(button)
		_filter_buttons[id] = button
	_sort = OptionButton.new()
	_sort.add_item("Sort: Rarity")
	_sort.add_item("Sort: Name")
	_sort.custom_minimum_size = Vector2(124, 32)
	_sort.item_selected.connect(func(_index: int) -> void: refresh())
	tools.add_child(_sort)
	_bag = ItemGrid.new()
	_bag.setup(player, _tip, 5, 3)
	_bag.custom_minimum_size = Vector2(5 * (ItemGrid.SLOT + ItemGrid.GAP) + 12.0, 3 * (ItemGrid.SLOT + ItemGrid.GAP) + 6.0)
	_bag.note_for = func(_item: Item) -> String: return "[color=#%s]Click to choose, right-click to wear[/color]" % UITheme.GOOD.to_html(false)
	_bag.picked.connect(func(item: Item, _index: int) -> void: _select(item))
	_bag.alt_picked.connect(func(item: Item, _index: int) -> void:
		_select(item)
		_wear_or_remove()
	)
	bag_box.add_child(_bag)
	bag_box.add_child(UITheme.paragraph("Found relics come here, not into your bag. If this is full, a new one waits in your bag until there is room.", 280.0, 14, UITheme.DIM))

	# --- the chosen relic
	var detail_panel := UITheme.inset_panel()
	columns.add_child(detail_panel)
	var detail := VBoxContainer.new()
	detail.add_theme_constant_override("separation", 8)
	detail.custom_minimum_size.x = WIDTH
	detail_panel.add_child(detail)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	detail.add_child(top)
	_icon_frame = PanelContainer.new()
	_icon_frame.custom_minimum_size = Vector2(72, 72)
	_icon_frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(_icon_frame)
	_icon = UITheme.icon(0, 58.0)
	_icon_frame.add_child(_icon)
	var naming := VBoxContainer.new()
	naming.add_theme_constant_override("separation", 2)
	naming.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(naming)
	_name = UITheme.heading("", 20)
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name.custom_minimum_size.x = WIDTH - 90.0
	naming.add_child(_name)
	_kind = UITheme.label("", 14, UITheme.DIM)
	naming.add_child(_kind)
	_badges = HBoxContainer.new()
	_badges.add_theme_constant_override("separation", 6)
	naming.add_child(_badges)
	# What it gives all the time.
	var boon_panel := PanelContainer.new()
	boon_panel.add_theme_stylebox_override("panel", UITheme.card("card", 10))
	detail.add_child(boon_panel)
	_boon = VBoxContainer.new()
	_boon.add_theme_constant_override("separation", 2)
	boon_panel.add_child(_boon)
	# What its power does when called on.
	var power_panel := PanelContainer.new()
	power_panel.add_theme_stylebox_override("panel", UITheme.card("card", 10))
	detail.add_child(power_panel)
	var power_box := VBoxContainer.new()
	power_box.add_theme_constant_override("separation", 4)
	power_panel.add_child(power_box)
	var power_head := HBoxContainer.new()
	power_head.add_theme_constant_override("separation", 8)
	power_box.add_child(power_head)
	_power_title = UITheme.strong("", 16, UITheme.HEADING)
	_power_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	power_head.add_child(_power_title)
	_power_state = HBoxContainer.new()
	_power_state.add_theme_constant_override("separation", 6)
	power_head.add_child(_power_state)
	_power_text = UITheme.paragraph("", WIDTH - 24.0, 15)
	power_box.add_child(_power_text)
	_lore = UITheme.paragraph("", WIDTH, 14, UITheme.DIM)
	detail.add_child(_lore)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_child(fill)
	_message = UITheme.reason("", WIDTH)
	detail.add_child(_message)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	detail.add_child(buttons)
	_focus_button = UITheme.primary_button("Make active", _focus_selected, 190.0)
	_focus_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(_focus_button)
	_wear_button = UITheme.button("Wear", _wear_or_remove, 120.0)
	_wear_button.custom_minimum_size.y = 40.0
	buttons.add_child(_wear_button)
	detail.add_child(UITheme.rule())
	_discard_button = UITheme.danger_button("Discard", _discard_selected, 150.0)
	_discard_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	detail.add_child(_discard_button)

	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree():
			_tip.hide_tip()
			_confirm_discard = false
	)
	player.relics.changed.connect(refresh_if_open)
	player.equipment.changed.connect(refresh_if_open)


func _key() -> String:
	return GameSettings.describe("relic_ability").split(" / ")[0]


func refresh_if_open() -> void:
	if is_visible_in_tree():
		refresh()


func _process(_delta: float) -> void:
	# Cooldowns tick while the bag is open.
	if is_visible_in_tree() and _selected and player.relics.cooldown_left(_selected) > 0.0 and Engine.get_process_frames() % 20 == 0:
		_show_details()


## Whether a relic's boons are about hitting harder.
static func is_damage_relic(item: Item) -> bool:
	var mods: Dictionary = RelicDB.RELICS[item.definition()["relic"]]["mods"]
	for stat: String in mods:
		if stat in DAMAGE_STATS:
			return true
	return false


func refresh() -> void:
	var relics := player.relics
	if _selected and not (_selected in relics.bag or _selected in relics.worn):
		_selected = null
	# Open on something: the active relic, or the first stored.
	if _selected == null:
		_selected = relics.focused()
		if _selected == null and not relics.bag.is_empty():
			_selected = relics.bag[0]
	var slots := relics.slots()
	_summary.text = "Worn %d / %d    ·    Stored %d / %d" % [relics.worn.size(), slots, relics.bag.size(), RelicDB.BAG_SIZE]
	for index in 3:
		_fill_worn_card(index, slots)
	var belt := player.equipment.get_item("belt")
	_belt_line.text = ("Belt worn: %s." % belt.display_name()) if belt else "No belt worn. A belt gives more places for relics."
	for id: String in _filter_buttons:
		(_filter_buttons[id] as Button).set_pressed_no_signal(id == _filter)
	var shown: Array = relics.bag.filter(func(item: Item) -> bool:
		return _filter == "all" or is_damage_relic(item) == (_filter == "damage"))
	if _sort.selected == 1:
		shown.sort_custom(func(a: Item, b: Item) -> bool: return a.display_name() < b.display_name())
	else:
		shown.sort_custom(func(a: Item, b: Item) -> bool: return a.rarity > b.rarity if a.rarity != b.rarity else a.display_name() < b.display_name())
	_bag.selected = _selected
	_bag.set_items(shown, RelicDB.BAG_SIZE if _filter == "all" else maxi(shown.size(), 5))
	_show_details()


## One worn slot as a card: the relic with "Equipped" and, on the one the
## key calls, the key and "Active power"; or what would open the slot.
func _fill_worn_card(index: int, slots: int) -> void:
	var relics := player.relics
	var card := _worn_cards[index]
	for child in card.get_children():
		child.queue_free()
	var item: Item = relics.worn[index] if index < relics.worn.size() else null
	var locked := index >= slots
	var chosen := item != null and item == _selected
	var kind := "card_selected" if chosen else ("card_dim" if locked else "card")
	for state: String in ["normal", "pressed", "disabled"]:
		card.add_theme_stylebox_override(state, UITheme.card(kind, 8))
	card.add_theme_stylebox_override("hover", UITheme.card("card_selected" if chosen else ("card_dim" if locked else "card_hover"), 8))
	card.disabled = locked
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	var picture := PanelContainer.new()
	picture.custom_minimum_size = Vector2(62, 62)
	picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.add_theme_stylebox_override("panel", ItemGrid.frame_style(item, false) if item else UITheme.slot("slot"))
	row.add_child(picture)
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.add_child(icon)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 3)
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(words)
	if locked:
		icon.texture = UITheme.lock_texture()
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		words.add_child(UITheme.strong(BELT_FOR_SLOT[index], 16, UITheme.DIM))
		words.add_child(UITheme.label("→ %d slots" % (index + 1), 14, UITheme.DIM))
	elif item == null:
		words.add_child(UITheme.strong("Empty slot", 16, UITheme.DIM))
		words.add_child(UITheme.label("Choose a relic and wear it.", 14, UITheme.DIM))
	else:
		icon.texture = item.icon()
		icon.modulate = item.icon_tint()
		var name_label := UITheme.strong(item.display_name(), 16, item.color())
		name_label.clip_text = true
		words.add_child(name_label)
		var marks := HBoxContainer.new()
		marks.add_theme_constant_override("separation", 6)
		marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
		words.add_child(marks)
		marks.add_child(UITheme.badge("Equipped", "good"))
		if index == relics.focus:
			var active := HBoxContainer.new()
			active.add_theme_constant_override("separation", 6)
			active.mouse_filter = Control.MOUSE_FILTER_IGNORE
			words.add_child(active)
			active.add_child(UITheme.key_cap(_key()))
			active.add_child(UITheme.badge("Active power", "gold"))


func _show_details() -> void:
	var item := _selected
	var relics := player.relics
	for child in _badges.get_children() + _boon.get_children() + _power_state.get_children():
		child.queue_free()
	_icon_frame.visible = item != null
	_discard_button.disabled = item == null
	_discard_button.text = "Really discard?" if _confirm_discard else "Discard"
	if item == null:
		_name.text = "Nothing chosen"
		_name.add_theme_color_override("font_color", UITheme.DIM)
		_kind.text = ""
		_lore.text = "Choose a relic to see its boon and its power."
		_boon.add_child(UITheme.label("Boon", 14, UITheme.DIM))
		_power_title.text = "Power"
		_power_text.text = ""
		_wear_button.text = "Wear"
		_wear_button.disabled = true
		_focus_button.text = "Make active"
		_focus_button.disabled = true
		return
	var worn := item in relics.worn
	var active := worn and relics.worn.find(item) == relics.focus
	var relic_id: String = item.definition()["relic"]
	var data: Dictionary = RelicDB.RELICS[relic_id]
	_icon.texture = item.icon()
	_icon.modulate = item.icon_tint()
	_icon_frame.add_theme_stylebox_override("panel", ItemGrid.frame_style(item, false))
	_name.text = item.display_name()
	_name.add_theme_color_override("font_color", item.color())
	_kind.text = "%s  ·  No level requirement" % ItemDB.RARITIES[item.rarity]["name"]
	if worn:
		_badges.add_child(UITheme.badge("Equipped", "good"))
	if active:
		_badges.add_child(UITheme.badge("Active power", "gold"))
	_lore.text = data["text"]
	# The boon, plainly.
	_boon.add_child(UITheme.label("Always, while worn", 14, UITheme.DIM))
	var mods := RelicDB.mods_at(relic_id, item.rarity)
	for stat: String in mods:
		for kind: String in mods[stat]:
			_boon.add_child(UITheme.strong(ItemDB.describe_modifier({"stat": stat, "kind": kind, "value": mods[stat][kind]}), 17, UITheme.GOOD))
	# The power, with whether it is ready.
	var ability: Dictionary = data["ability"]
	_power_title.text = "Power: %s" % ability["name"]
	var left := relics.cooldown_left(item)
	_power_state.add_child(UITheme.key_cap(_key()))
	_power_state.add_child(UITheme.label("Ready" if left <= 0.0 else "%ds" % ceili(left), 14, UITheme.GOOD if left <= 0.0 else Color("e8a070")))
	_power_state.add_child(UITheme.label("·  %ds" % roundi(ability["cooldown"]), 14, UITheme.DIM))
	_power_text.text = ability["text"]
	# What can be done depends on where the relic is.
	_wear_button.disabled = false
	_wear_button.text = "Unequip" if worn else "Wear"
	if active:
		_focus_button.text = "Active power  ✓"
		_focus_button.disabled = true
		_focus_button.tooltip_text = "%s already calls on this relic." % _key()
	elif worn:
		_focus_button.text = "Make active  (%s)" % _key()
		_focus_button.disabled = false
		_focus_button.tooltip_text = ""
	else:
		_focus_button.text = "Wear to use its power"
		_focus_button.disabled = true
		_focus_button.tooltip_text = "Only a worn relic can be the active one."


func _select(item: Item) -> void:
	_selected = item
	_confirm_discard = false
	_message.text = ""
	refresh()


func _wear_or_remove() -> void:
	if _selected == null:
		return
	var problem := player.relics.take_off(_selected) if _selected in player.relics.worn else player.relics.wear(_selected)
	_message.text = problem
	refresh()


func _focus_selected() -> void:
	var index := player.relics.worn.find(_selected)
	if index >= 0:
		player.relics.set_focus(index)
		refresh()


func _discard_selected() -> void:
	if _selected == null:
		return
	if not _confirm_discard:
		_confirm_discard = true
		_message.text = "Discarding destroys the relic for good. Press again to confirm."
		_show_details()
		return
	player.relics.discard(_selected)
	_selected = null
	_confirm_discard = false
	_message.text = ""
	refresh()


func _worn_item(index: int) -> Item:
	return player.relics.worn[index] if index < player.relics.worn.size() else null


func _on_worn_pressed(index: int) -> void:
	var item := _worn_item(index)
	if item:
		_select(item)


func _on_worn_input(event: InputEvent, index: int) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_RIGHT and _worn_item(index):
		_select(_worn_item(index))
		_wear_or_remove()


func _on_worn_hover(index: int) -> void:
	var item := _worn_item(index)
	if item:
		_tip.show_item(item, player, "[color=#%s]Click to choose it, right-click to take it off[/color]" % UITheme.GOOD.to_html(false))
