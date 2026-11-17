class_name AbilitiesMenu
extends GameMenu
## Three columns. Left: the combat styles (use the ones you know, see who
## teaches the rest). Middle: the three sets the ability keys work, each
## with its four keys shown: what is in hand (a weapon's, a style's or a
## school's own four moves), the universal set and the class set that Tab
## switches to, with the library of universal and class abilities under
## them. Right: an inspector for whatever is chosen, with one clear action.
##
## Choose an ability, choose a slot in its set, press Assign.

const SLOT := 58.0
const KEYS: Array[String] = ["ability_1", "ability_2", "ability_3", "ability_4"]
const FILTERS: Array[Array] = [["all", "All"], ["known", "Known"], ["locked", "Locked"]]

var _styles: VBoxContainer
var _hand_title: Label
var _hand_badge: HBoxContainer
var _hand_slots: Array[Button] = []
var _hand_names: Array[Label] = []
var _universal_badge: HBoxContainer
var _slots: Array[Button] = []
var _slot_names: Array[Label] = []
var _class_badge: HBoxContainer
var _class_title: Label
var _class_slots: Array[Button] = []
var _class_names: Array[Label] = []
## The class slot Assign fills for a class ability.
var _class_slot := 0
var _library: VBoxContainer
var _search: LineEdit
var _filter := "all"
var _filter_buttons: Dictionary = {}
var _icon: TextureRect
var _name: Label
var _needs: HBoxContainer
var _text: Label
var _facts: VBoxContainer
var _assign: Button
var _remove: Button
var _reason: Label
## The ability (or "style:<id>") shown in the inspector.
var _selected := ""
## The universal slot Assign fills.
var _slot := 0


func _build() -> void:
	content.add_theme_constant_override("separation", 10)
	var title_row := HBoxContainer.new()
	content.add_child(title_row)
	var held := HBoxContainer.new()
	held.custom_minimum_size.x = 320.0
	title_row.add_child(held)
	var title := UITheme.heading("ABILITIES", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	var hint := HBoxContainer.new()
	hint.custom_minimum_size.x = 320.0
	hint.alignment = BoxContainer.ALIGNMENT_END
	title_row.add_child(hint)
	hint.add_child(UITheme.key_hint(_key("ability_swap"), "switches set in play"))

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 12)
	content.add_child(columns)

	# --- combat styles
	var style_panel := UITheme.inset_panel()
	columns.add_child(style_panel)
	var style_box := VBoxContainer.new()
	style_box.add_theme_constant_override("separation", 6)
	style_panel.add_child(style_box)
	style_box.add_child(UITheme.heading("Combat styles", 18))
	style_box.add_child(UITheme.label("Hotbar slot 1 fights with the style in use.", 14, UITheme.DIM))
	var style_scroll := ScrollContainer.new()
	style_scroll.custom_minimum_size = Vector2(312, 440)
	style_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	style_box.add_child(style_scroll)
	_styles = VBoxContainer.new()
	_styles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_styles.add_theme_constant_override("separation", 5)
	style_scroll.add_child(_styles)

	# --- the two sets, and the universal library
	var middle_panel := UITheme.inset_panel()
	columns.add_child(middle_panel)
	var middle := VBoxContainer.new()
	middle.add_theme_constant_override("separation", 6)
	middle_panel.add_child(middle)
	var hand_head := HBoxContainer.new()
	hand_head.add_theme_constant_override("separation", 8)
	middle.add_child(hand_head)
	_hand_title = UITheme.heading("In hand", 17)
	hand_head.add_child(_hand_title)
	_hand_badge = HBoxContainer.new()
	hand_head.add_child(_hand_badge)
	middle.add_child(_slot_row(_hand_slots, _hand_names, "hand"))
	middle.add_child(UITheme.rule())
	var universal_head := HBoxContainer.new()
	universal_head.add_theme_constant_override("separation", 8)
	middle.add_child(universal_head)
	universal_head.add_child(UITheme.heading("Universal set", 17))
	_universal_badge = HBoxContainer.new()
	universal_head.add_child(_universal_badge)
	middle.add_child(_slot_row(_slots, _slot_names, "universal"))
	middle.add_child(UITheme.rule())
	var class_head := HBoxContainer.new()
	class_head.add_theme_constant_override("separation", 8)
	middle.add_child(class_head)
	_class_title = UITheme.heading("Class set", 17)
	class_head.add_child(_class_title)
	_class_badge = HBoxContainer.new()
	class_head.add_child(_class_badge)
	middle.add_child(_slot_row(_class_slots, _class_names, "class"))
	middle.add_child(UITheme.label("Universal and class sets work with anything in hand. Click a slot to choose where Assign puts an ability.", 14, UITheme.DIM))
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 4)
	middle.add_child(tools)
	_search = UITheme.search_box("Search abilities...", 176.0, refresh)
	tools.add_child(_search)
	for entry: Array in FILTERS:
		var id: String = entry[0]
		var button := UITheme.button(entry[1], func() -> void:
			_filter = id
			refresh()
		, 66.0)
		button.toggle_mode = true
		button.custom_minimum_size.y = 32.0
		tools.add_child(button)
		_filter_buttons[id] = button
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(4 * (SLOT + 40.0) + 3 * 6.0, 170)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_child(scroll)
	_library = VBoxContainer.new()
	_library.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_library.add_theme_constant_override("separation", 4)
	scroll.add_child(_library)

	# --- the inspector
	var right_panel := UITheme.inset_panel()
	columns.add_child(right_panel)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.custom_minimum_size.x = 314.0
	right_panel.add_child(right)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	right.add_child(top)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UITheme.slot("slot"))
	frame.custom_minimum_size = Vector2(72, 72)
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(frame)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(60, 60)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.add_child(_icon)
	var naming := VBoxContainer.new()
	naming.add_theme_constant_override("separation", 4)
	naming.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(naming)
	_name = UITheme.heading("", 21)
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name.custom_minimum_size.x = 230.0
	naming.add_child(_name)
	_needs = HBoxContainer.new()
	_needs.add_theme_constant_override("separation", 6)
	naming.add_child(_needs)
	_text = UITheme.paragraph("", 314.0, 16)
	right.add_child(_text)
	right.add_child(UITheme.rule())
	_facts = VBoxContainer.new()
	_facts.add_theme_constant_override("separation", 4)
	right.add_child(_facts)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(spacer)
	_reason = UITheme.reason("", 314.0)
	right.add_child(_reason)
	_assign = UITheme.primary_button("Assign", _on_assign, 314.0)
	right.add_child(_assign)
	_remove = UITheme.button("Remove from slot", _on_remove, 314.0)
	right.add_child(_remove)
	player.abilities.changed.connect(refresh_if_open)
	player.styles.changed.connect(refresh_if_open)
	player.equipment.changed.connect(refresh_if_open)


func _key(action: String) -> String:
	return GameSettings.describe(action).split(" / ")[0]


## Four slots in a row, each with its key on a cap above and its name
## beneath. Universal slots can be chosen as where Assign puts things.
func _slot_row(buttons: Array[Button], names: Array[Label], kind: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for index in AbilityDB.SET_SIZE:
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 3)
		column.custom_minimum_size.x = SLOT + 40.0
		row.add_child(column)
		var cap := UITheme.key_cap(_key(KEYS[index]))
		cap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_child(cap)
		var button := Button.new()
		button.custom_minimum_size = Vector2(SLOT, SLOT)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		UITheme.sounds(button)
		if kind == "universal":
			button.pressed.connect(func() -> void:
				_slot = index
				if player.abilities.loadout[index] != "":
					_selected = player.abilities.loadout[index]
				refresh()
			)
			button.gui_input.connect(func(event: InputEvent) -> void:
				var click := event as InputEventMouseButton
				if click and click.pressed and click.button_index == MOUSE_BUTTON_RIGHT:
					player.abilities.clear_slot(index)
					refresh()
			)
		elif kind == "class":
			button.pressed.connect(func() -> void:
				_class_slot = index
				if player.abilities.class_loadout[index] != "":
					_selected = player.abilities.class_loadout[index]
				refresh()
			)
			button.gui_input.connect(func(event: InputEvent) -> void:
				var click := event as InputEventMouseButton
				if click and click.pressed and click.button_index == MOUSE_BUTTON_RIGHT:
					player.abilities.clear_class_slot(index)
					refresh()
			)
		else:
			button.pressed.connect(func() -> void:
				var ids := player.abilities.arms()
				if index < ids.size():
					_selected = ids[index]
					refresh()
			)
		column.add_child(button)
		var name_label := UITheme.label("", 14, UITheme.DIM)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.clip_text = true
		name_label.custom_minimum_size.x = SLOT + 40.0
		column.add_child(name_label)
		buttons.append(button)
		names.append(name_label)
	return row


func refresh_if_open() -> void:
	if is_visible_in_tree():
		refresh()


func refresh() -> void:
	var abilities := player.abilities
	# Open on something useful: the first move in hand, or the first known
	# universal ability.
	if _selected == "" or (not _selected.begins_with("style:") and not AbilityDB.ABILITIES.has(_selected)):
		var ids := abilities.arms()
		_selected = ids[0] if not ids.is_empty() else ""
		if _selected == "":
			for id: String in abilities.loadout:
				if id != "":
					_selected = id
					break
	_refresh_styles()
	_refresh_sets()
	_refresh_library()
	_refresh_inspector()


func _refresh_styles() -> void:
	for child in _styles.get_children():
		child.queue_free()
	for style: String in CombatStyles.STYLES:
		var info: Dictionary = CombatStyles.STYLES[style]
		var known: bool = style in player.styles.learned
		var worn: bool = player.styles.equipped == style
		var chosen := _selected == "style:" + style
		var card := Button.new()
		card.custom_minimum_size = Vector2(300, 56)
		var kind := "card_selected" if worn else ("card" if known else "card_dim")
		for state: String in ["normal", "pressed"]:
			card.add_theme_stylebox_override(state, UITheme.card(kind, 6))
		card.add_theme_stylebox_override("hover", UITheme.card("card_selected" if worn else "card_hover", 6))
		card.pressed.connect(func() -> void:
			_selected = "style:" + style
			refresh()
		)
		UITheme.sounds(card)
		var row := HBoxContainer.new()
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
		row.add_theme_constant_override("separation", 8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(row)
		var icon := TextureRect.new()
		icon.texture = CombatStyles.icon(style)
		icon.custom_minimum_size = Vector2(40, 40)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.modulate = Color.WHITE if known else Color(0.45, 0.45, 0.5)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		var box := VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 0)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(box)
		var name_label := UITheme.strong(info["name"], 16, info["color"] if known else UITheme.DIM)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(name_label)
		var note := UITheme.label("In use" if worn else ("Known" if known else "Level %d  ·  %s" % [info.get("level", 1), info.get("teacher", "a master")]), 14, UITheme.GOLD if worn else UITheme.DIM)
		note.clip_text = true
		note.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(note)
		if not known:
			var lock := TextureRect.new()
			lock.texture = UITheme.lock_texture()
			lock.custom_minimum_size = Vector2(24, 24)
			lock.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			lock.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(lock)
		if chosen and not worn:
			# Chosen but not in use: a clear outline, not the gold of "in use".
			var outline := ReferenceRect.new()
			outline.border_color = Color.WHITE
			outline.border_width = 2.0
			outline.editor_only = false
			outline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(outline)
		_styles.add_child(card)


func _held_name() -> String:
	var abilities := player.abilities
	if abilities.casting():
		return "%s magic" % MagicDB.SCHOOLS[player.magic_school]["name"]
	if player.fighting_bare():
		return CombatStyles.STYLES[player.styles.equipped]["name"]
	var weapon := player.equipment.weapon()
	return weapon.definition()["name"] if weapon else "Nothing"


func _refresh_sets() -> void:
	var abilities := player.abilities
	_hand_title.text = "In hand: %s" % _held_name()
	for box: HBoxContainer in [_hand_badge, _universal_badge, _class_badge]:
		for child in box.get_children():
			child.queue_free()
	([_hand_badge, _universal_badge, _class_badge][abilities.active_set] as HBoxContainer).add_child(UITheme.badge("Active", "gold"))
	var has_class := abilities.has_class_set()
	_class_title.text = "Class set: %s  ·  class level %d" % [HeroClasses.CLASSES[player.class_id]["name"], player.class_level] if has_class else "Class set (choose a class)"
	var ids := abilities.arms()
	for index in AbilityDB.SET_SIZE:
		var id: String = ids[index] if index < ids.size() else ""
		_style_slot(_hand_slots[index], _hand_names[index], id, id != "" and id == _selected, false)
		var stored: String = abilities.loadout[index]
		_style_slot(_slots[index], _slot_names[index], stored, index == _slot, true)
		var class_stored: String = abilities.class_loadout[index]
		_style_slot(_class_slots[index], _class_names[index], class_stored, index == _class_slot and has_class, has_class)


## Dresses one slot: its picture (greyed with a padlock while locked), a
## gold frame when it is the chosen one, and its name beneath.
func _style_slot(button: Button, name_label: Label, id: String, chosen: bool, destination: bool) -> void:
	var kind := "slot_active" if chosen else "slot"
	for state: String in ["normal", "pressed"]:
		button.add_theme_stylebox_override(state, UITheme.slot(kind))
	button.add_theme_stylebox_override("hover", UITheme.slot("slot_active" if chosen else "slot_hover"))
	for child in button.get_children():
		child.queue_free()
	if id == "":
		button.icon = null
		button.text = "+" if destination else ""
		UITheme.font_size(button, 24)
		button.tooltip_text = "Empty. Choose an ability and press Assign." if destination else "No move here."
		name_label.text = "Empty" if destination else "-"
		name_label.add_theme_color_override("font_color", UITheme.DIM)
		return
	button.text = ""
	var ability: Dictionary = AbilityDB.ABILITIES[id]
	var locked := player.abilities.rank(id) == 0
	button.icon = AbilityDB.icon(id)
	var tint := Color(0.42, 0.42, 0.48) if locked else Color.WHITE
	for state: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color"]:
		button.add_theme_color_override(state, tint)
	button.tooltip_text = ability["name"]
	name_label.text = "Locked" if locked else ability["name"]
	name_label.add_theme_color_override("font_color", UITheme.DIM if locked else UITheme.TEXT)
	if locked:
		var lock := TextureRect.new()
		lock.texture = UITheme.lock_texture()
		lock.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		lock.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		lock.offset_left = -26.0
		lock.offset_top = -26.0
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(lock)


func _refresh_library() -> void:
	for id: String in _filter_buttons:
		(_filter_buttons[id] as Button).set_pressed_no_signal(id == _filter)
	for child in _library.get_children():
		child.queue_free()
	var words := _search.text.strip_edges().to_lower()
	var ids: Array = AbilityDB.ABILITIES.keys().filter(func(id: String) -> bool:
		if not AbilityDB.is_universal(id) and not AbilityDB.is_class_ability(id):
			return false
		var ability: Dictionary = AbilityDB.ABILITIES[id]
		if ability.has("class") and ability["class"] != player.class_id:
			return false
		var known := player.abilities.rank(id) > 0
		if (_filter == "known" and not known) or (_filter == "locked" and known):
			return false
		return words == "" or str(ability["name"]).to_lower().contains(words) or str(ability.get("text", "")).to_lower().contains(words)
	)
	# Class abilities first, in the order the class level opens them.
	ids.sort_custom(func(a: String, b: String) -> bool:
		var ca := AbilityDB.is_class_ability(a)
		var cb := AbilityDB.is_class_ability(b)
		if ca != cb:
			return ca
		if ca:
			return HeroClasses.ability_level(player.class_id, a) < HeroClasses.ability_level(player.class_id, b)
		return AbilityDB.unlock_level(a) < AbilityDB.unlock_level(b))
	for id: String in ids:
		_library.add_child(_row(id))
	if ids.is_empty():
		_library.add_child(UITheme.label("Nothing matches.", 14, UITheme.DIM))


## One universal ability as a row: its picture and name, and its state in
## words on the right (on which key, known, or what unlocks it).
func _row(id: String) -> Button:
	var ability: Dictionary = AbilityDB.ABILITIES[id]
	var known := player.abilities.rank(id) > 0
	var where := player.abilities.class_loadout.find(id) if AbilityDB.is_class_ability(id) else player.abilities.loadout.find(id)
	var button := Button.new()
	button.custom_minimum_size = Vector2(380, 40)
	var chosen := id == _selected
	var kind := "card_selected" if chosen else ("card" if known else "card_dim")
	for state: String in ["normal", "pressed"]:
		button.add_theme_stylebox_override(state, UITheme.card(kind, 6))
	button.add_theme_stylebox_override("hover", UITheme.card("card_selected" if chosen else "card_hover", 6))
	button.pressed.connect(func() -> void:
		_selected = id
		refresh()
	)
	UITheme.sounds(button)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(row)
	var icon := TextureRect.new()
	icon.texture = AbilityDB.icon(id)
	icon.custom_minimum_size = Vector2(28, 28)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.modulate = Color.WHITE if known else Color(0.45, 0.45, 0.5)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var name_label := UITheme.label(ability["name"], 16, UITheme.TEXT if known else UITheme.DIM)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name_label)
	if where != -1:
		row.add_child(UITheme.badge("On %s" % _key(KEYS[where]), "gold"))
	elif not known:
		row.add_child(UITheme.badge(_unlock_words(id), "plain"))
	return button


## What unlocks an ability, in a few words.
func _unlock_words(id: String) -> String:
	var ability: Dictionary = AbilityDB.ABILITIES[id]
	if ability.has("class"):
		return "Class level %d" % HeroClasses.ability_level(player.class_id, id)
	if ability.get("universal", false):
		return "Level %d" % AbilityDB.unlock_level(id)
	if ability.has("style"):
		return "Learn the style"
	return "Mastery %d" % AbilityDB.unlock_level(id)


func _fact(label: String, value: String, color: Color = UITheme.TEXT) -> void:
	var row := HBoxContainer.new()
	var name_label := UITheme.label(label, 14, UITheme.DIM)
	name_label.custom_minimum_size.x = 110.0
	row.add_child(name_label)
	var value_label := UITheme.strong(value, 16, color)
	value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value_label.custom_minimum_size.x = 200.0
	row.add_child(value_label)
	_facts.add_child(row)


func _refresh_inspector() -> void:
	for child in _needs.get_children() + _facts.get_children():
		child.queue_free()
	_reason.text = ""
	_assign.visible = true
	_remove.visible = false
	if _selected.begins_with("style:"):
		_inspect_style(_selected.trim_prefix("style:"))
		return
	if _selected == "":
		_icon.texture = null
		_name.text = "Nothing chosen"
		_text.text = "Choose a move, a universal ability or a combat style to see what it does."
		_assign.visible = false
		return
	var id := _selected
	var ability: Dictionary = AbilityDB.ABILITIES[id]
	var abilities := player.abilities
	var rank := abilities.rank(id)
	_icon.texture = AbilityDB.icon(id)
	_icon.modulate = Color.WHITE if rank > 0 else Color(0.5, 0.5, 0.56)
	_name.text = ability["name"]
	_text.text = ability.get("text", "")
	# What it needs in hand, as a badge.
	if ability.has("style"):
		_needs.add_child(UITheme.badge("Style: %s" % CombatStyles.STYLES[ability["style"]]["name"], "info"))
	elif ability.has("weapon_item"):
		_needs.add_child(UITheme.badge("Requires: %s" % ItemDB.ITEMS[ability["weapon_item"]]["name"], "info"))
	elif ability.has("school"):
		_needs.add_child(UITheme.badge("Requires: %s magic" % MagicDB.SCHOOLS[ability["school"]]["short"], "info"))
	elif AbilityDB.is_class_ability(id):
		_needs.add_child(UITheme.badge("Class ability", "gold"))
	elif AbilityDB.is_universal(id):
		_needs.add_child(UITheme.badge("Works with anything", "good"))
	var costs: PackedStringArray = []
	if abilities.stamina_cost(id) > 0.0:
		costs.append("%d stamina" % roundi(abilities.stamina_cost(id)))
	if abilities.mana_cost(id) > 0.0:
		costs.append("%d mana" % roundi(abilities.mana_cost(id)))
	_fact("Cost", ", ".join(costs) if not costs.is_empty() else "Nothing")
	_fact("Cooldown", "%ss" % str(ability.get("cooldown", 0.0)))
	if ability.get("damage", 0.0) > 0.0:
		_fact("Damage", "x%.1f of your hit" % AbilityDB.damage(id, maxi(rank, 1)))
	_fact("Rank", str(rank) if rank > 0 else "Locked", UITheme.TEXT if rank > 0 else UITheme.BAD)
	if rank == 0:
		_fact("Unlocks at", _unlock_words(id), Color("e8a070"))
	# The one action that fits.
	var is_class := AbilityDB.is_class_ability(id)
	var where := abilities.class_loadout.find(id) if is_class else abilities.loadout.find(id)
	var target := _class_slot if is_class else _slot
	if not AbilityDB.is_universal(id) and not is_class:
		_assign.visible = false
		_reason.text = "This move belongs to what is in hand: it is on its key whenever you hold it." if rank > 0 else "Locked: %s." % _unlock_words(id).to_lower()
		_reason.add_theme_color_override("font_color", UITheme.DIM if rank > 0 else Color("e8a070"))
		return
	_reason.add_theme_color_override("font_color", Color("e8a070"))
	_remove.visible = where != -1
	var set_word := "class " if is_class else ""
	if rank == 0:
		_assign.text = "Assign to %s%s" % [set_word, _key(KEYS[target])]
		_assign.disabled = true
		_reason.text = "Locked: %s." % _unlock_words(id).to_lower()
	elif where == target:
		_assign.text = "On %s%s" % [set_word, _key(KEYS[target])]
		_assign.disabled = true
	else:
		_assign.text = "%s to %s%s" % ["Move" if where != -1 else "Assign", set_word, _key(KEYS[target])]
		_assign.disabled = false


func _inspect_style(style: String) -> void:
	var info: Dictionary = CombatStyles.STYLES[style]
	var known: bool = style in player.styles.learned
	var worn: bool = player.styles.equipped == style
	_icon.texture = CombatStyles.icon(style)
	_icon.modulate = Color.WHITE if known else Color(0.5, 0.5, 0.56)
	_name.text = info["name"]
	_text.text = info["text"]
	_needs.add_child(UITheme.badge("In use" if worn else ("Known" if known else "Not learned"), "gold" if worn else ("good" if known else "plain")))
	var moves: PackedStringArray = []
	for id in AbilityDB.style_moves(style):
		moves.append(AbilityDB.ABILITIES[id]["name"])
	_fact("Moves", ", ".join(moves))
	if not known:
		_fact("Teacher", str(info.get("teacher", "a master")))
		_fact("Needs", "Level %d" % int(info.get("level", 1)), UITheme.TEXT if player.leveling.level >= int(info.get("level", 1)) else UITheme.BAD)
		_fact("Price", CombatStyles.cost_text(style))
	_assign.text = "In use" if worn else "Use this style"
	_assign.disabled = worn or not known
	if not known:
		_reason.text = "Find %s in a dojo out in the wilds to learn it." % str(info.get("teacher", "its master"))


func _on_assign() -> void:
	if _selected.begins_with("style:"):
		_reason.text = player.styles.equip(_selected.trim_prefix("style:"))
		refresh()
		return
	if _selected != "" and AbilityDB.is_class_ability(_selected) and player.abilities.rank(_selected) > 0:
		player.abilities.assign_class(_class_slot, _selected)
		refresh()
	elif _selected != "" and AbilityDB.is_universal(_selected) and player.abilities.rank(_selected) > 0:
		player.abilities.assign(_slot, _selected)
		refresh()


func _on_remove() -> void:
	if AbilityDB.is_class_ability(_selected):
		var spot := player.abilities.class_loadout.find(_selected)
		if spot != -1:
			player.abilities.clear_class_slot(spot)
			refresh()
		return
	var where := player.abilities.loadout.find(_selected)
	if where != -1:
		player.abilities.clear_slot(where)
		refresh()
