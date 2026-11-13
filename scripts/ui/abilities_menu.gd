class_name AbilitiesMenu
extends GameMenu
## Three columns: the combat styles (equip the ones you know, see who
## teaches the rest), the four moves of whatever is in hand, and the
## universal abilities with the four slots Tab switches to. Click a
## universal ability, then a slot; right-click a slot to empty it.

var _styles: VBoxContainer
var _arms_title: Label
var _arms: VBoxContainer
var _universal: VBoxContainer
var _slots: Array[Button] = []
var _details: RichTextLabel
var _message: Label
var _picked := ""


func _build() -> void:
	var title := UITheme.heading("ABILITIES", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var hint := UITheme.label("Slot 1 fights with your combat style, slot 2 with your magic, 3 and 4 with weapons. Every weapon and style has its own four moves; Tab switches to your universal abilities.", 13, UITheme.DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	hint.custom_minimum_size = Vector2(1000, 0)
	content.add_child(hint)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 12)
	content.add_child(columns)
	_styles = _column(columns, "Combat styles", 360)
	var middle := _column(columns, "", 330)
	_arms_title = UITheme.heading("In hand", 18)
	middle.add_child(_arms_title)
	_arms = VBoxContainer.new()
	_arms.add_theme_constant_override("separation", 6)
	middle.add_child(_arms)
	var right := _column(columns, "Universal abilities", 330)
	var slot_row := HBoxContainer.new()
	slot_row.add_theme_constant_override("separation", 6)
	right.add_child(slot_row)
	for index in AbilityDB.SET_SIZE:
		var button := Button.new()
		button.custom_minimum_size = Vector2(60, 60)
		button.expand_icon = true
		button.pressed.connect(_on_slot.bind(index))
		button.gui_input.connect(func(event: InputEvent) -> void:
			var click := event as InputEventMouseButton
			if click and click.pressed and click.button_index == MOUSE_BUTTON_RIGHT:
				player.abilities.clear_slot(index)
				refresh()
		)
		button.mouse_entered.connect(func() -> void: _describe(player.abilities.loadout[index]))
		slot_row.add_child(button)
		_slots.append(button)
	right.add_child(UITheme.label("Pick one below, then a slot. Right-click a slot to empty it.", 12, UITheme.DIM))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(320, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	_universal = VBoxContainer.new()
	_universal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_universal.add_theme_constant_override("separation", 4)
	scroll.add_child(_universal)
	_message = UITheme.label("", 14, UITheme.BAD)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_message)
	_details = RichTextLabel.new()
	_details.bbcode_enabled = true
	_details.fit_content = true
	_details.custom_minimum_size = Vector2(1000, 60)
	content.add_child(_details)
	player.abilities.changed.connect(refresh_if_open)
	player.styles.changed.connect(refresh_if_open)


func _column(parent: Control, heading: String, width: float) -> VBoxContainer:
	var panel := UITheme.inset_panel()
	panel.custom_minimum_size = Vector2(width, 470)
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	if heading != "":
		box.add_child(UITheme.heading(heading, 18))
	return box


func refresh_if_open() -> void:
	if is_visible_in_tree():
		refresh()


func refresh() -> void:
	_refresh_styles()
	_refresh_arms()
	_refresh_universal()


func _refresh_styles() -> void:
	for child in _styles.get_children().slice(1):
		child.queue_free()
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(350, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_styles.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	for style: String in CombatStyles.STYLES:
		var info: Dictionary = CombatStyles.STYLES[style]
		var known: bool = style in player.styles.learned
		var worn: bool = player.styles.equipped == style
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UITheme.card("card_selected" if worn else "card", 6))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		card.add_child(row)
		var icon := TextureRect.new()
		icon.texture = CombatStyles.icon(style)
		icon.custom_minimum_size = Vector2(40, 40)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.modulate = Color.WHITE if known else Color(0.45, 0.45, 0.5)
		row.add_child(icon)
		var box := VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(box)
		box.add_child(UITheme.label(info["name"] + ("   (in use)" if worn else ""), 15, info["color"] if known else UITheme.DIM))
		var note: String = info["text"] if known else "Taught by %s, at a hidden shrine. Level %d.  %s" % [info.get("teacher", "a master"), info.get("level", 1), CombatStyles.cost_text(style)]
		var text := UITheme.label(note, 11, UITheme.DIM)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD
		text.custom_minimum_size = Vector2(230, 0)
		box.add_child(text)
		if known and not worn:
			row.add_child(UITheme.button("Use", func() -> void:
				_message.text = player.styles.equip(style)
				refresh()
			, 60.0))
		card.mouse_entered.connect(func() -> void: _describe_style(style))
		list.add_child(card)


func _refresh_arms() -> void:
	for child in _arms.get_children():
		child.queue_free()
	var abilities := player.abilities
	var held := "your hands"
	if abilities.casting():
		held = MagicDB.SCHOOLS[player.magic_school]["name"]
	elif player.fighting_bare():
		held = CombatStyles.STYLES[player.styles.equipped]["name"]
	elif player.equipment.weapon():
		held = player.equipment.weapon().display_name()
	_arms_title.text = "In hand: %s" % held
	var ids := abilities.arms()
	if ids.is_empty():
		_arms.add_child(UITheme.label("Nothing with moves in hand. Take up a style (1), magic (2) or a weapon (3, 4).", 13, UITheme.DIM))
	for id in ids:
		_arms.add_child(_row(id, false))


func _refresh_universal() -> void:
	var abilities := player.abilities
	for index in _slots.size():
		var id: String = abilities.loadout[index]
		_slots[index].icon = AbilityDB.icon(id) if id != "" else null
		_slots[index].tooltip_text = AbilityDB.ABILITIES[id]["name"] if id != "" else "Empty"
	for child in _universal.get_children():
		child.queue_free()
	var ids: Array = AbilityDB.ABILITIES.keys().filter(func(id: String) -> bool:
		return AbilityDB.is_universal(id) and (not AbilityDB.ABILITIES[id].has("class") or AbilityDB.ABILITIES[id]["class"] == player.class_id))
	ids.sort_custom(func(a: String, b: String) -> bool: return AbilityDB.unlock_level(a) < AbilityDB.unlock_level(b))
	for id: String in ids:
		_universal.add_child(_row(id, true))


## One ability as a row: icon, name, whether it is ready to use.
func _row(id: String, pickable: bool) -> Control:
	var ability: Dictionary = AbilityDB.ABILITIES[id]
	var rank := player.abilities.rank(id)
	var button := Button.new()
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.icon = AbilityDB.icon(id)
	button.expand_icon = false
	button.custom_minimum_size = Vector2(300, 44)
	var state := ""
	if rank == 0:
		if ability.get("universal", false) or ability.has("class"):
			state = "  -  level %d" % AbilityDB.unlock_level(id) if ability.get("universal", false) else "  -  learn it in the class tree"
		else:
			state = "  -  mastery %d" % AbilityDB.unlock_level(id)
	elif pickable and id in player.abilities.loadout:
		state = "  -  on the bar"
	button.text = "%s%s%s" % [ability["name"], "  (rank %d)" % rank if rank > 0 else "", state]
	button.modulate = Color.WHITE if rank > 0 else Color(0.6, 0.6, 0.65)
	if id == _picked:
		button.add_theme_color_override("font_color", UITheme.GOLD)
	button.mouse_entered.connect(func() -> void: _describe(id))
	if pickable:
		button.pressed.connect(func() -> void:
			if rank == 0:
				_message.text = "Not yet: %s" % state.trim_prefix("  -  ")
				return
			_picked = id
			var free := player.abilities.loadout.find("")
			if free != -1:
				player.abilities.assign(free, id)
				_picked = ""
			_message.text = "" if _picked == "" else "Now click a slot above."
			refresh()
		)
	return button


func _on_slot(index: int) -> void:
	if _picked != "":
		player.abilities.assign(index, _picked)
		_picked = ""
		_message.text = ""
		refresh()


func _describe(id: String) -> void:
	if id == "" or not AbilityDB.ABILITIES.has(id):
		_details.text = ""
		return
	var ability: Dictionary = AbilityDB.ABILITIES[id]
	var costs: PackedStringArray = []
	if ability.get("stamina", 0.0) > 0.0:
		costs.append("%d stamina" % roundi(ability["stamina"]))
	if ability.get("mana", 0.0) > 0.0:
		costs.append("%d mana" % roundi(ability["mana"]))
	costs.append("%.0fs cooldown" % ability["cooldown"])
	_details.text = "[color=#%s]%s[/color]   [color=#%s]%s[/color]\n%s" % [UITheme.GOLD.to_html(false), ability["name"], UITheme.DIM.to_html(false), ",  ".join(costs), ability.get("text", "")]


func _describe_style(style: String) -> void:
	var info: Dictionary = CombatStyles.STYLES[style]
	var moves: PackedStringArray = []
	for id in AbilityDB.style_moves(style):
		moves.append(AbilityDB.ABILITIES[id]["name"])
	_details.text = "[color=#%s]%s[/color]  -  %s\n[color=#%s]Moves: %s[/color]" % [(info["color"] as Color).to_html(false), info["name"], info["text"], UITheme.DIM.to_html(false), ", ".join(moves)]
