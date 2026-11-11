class_name AbilitiesMenu
extends GameMenu
## Choosing which eight abilities sit on the bar. Click an ability on the
## left, then a slot on the right; right-click a slot to empty it.

var _list: VBoxContainer
var _slots: Array[Button] = []
var _details: RichTextLabel
var _picked := ""


func _build() -> void:
	var title := UITheme.heading("ABILITIES", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	content.add_child(columns)

	var left := UITheme.inset_panel()
	columns.add_child(left)
	var left_box := VBoxContainer.new()
	left.add_child(left_box)
	left_box.add_child(UITheme.heading("Known abilities", 18))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(360, 440)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_list)

	var middle := UITheme.inset_panel()
	columns.add_child(middle)
	var middle_box := VBoxContainer.new()
	middle_box.add_theme_constant_override("separation", 10)
	middle.add_child(middle_box)
	for set_index in AbilityDB.SETS:
		middle_box.add_child(UITheme.heading("Set %d" % (set_index + 1), 18))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		middle_box.add_child(row)
		for index in AbilityDB.SET_SIZE:
			var slot := set_index * AbilityDB.SET_SIZE + index
			var button := Button.new()
			button.custom_minimum_size = Vector2(70, 70)
			button.focus_mode = Control.FOCUS_NONE
			button.expand_icon = true
			button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			button.pressed.connect(func() -> void:
				if _picked != "":
					player.abilities.assign(slot, _picked)
					_picked = ""
				refresh()
			)
			button.gui_input.connect(func(event: InputEvent) -> void:
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
					player.abilities.clear_slot(slot)
					refresh()
			)
			button.mouse_entered.connect(func() -> void: _describe(player.abilities.loadout[slot]))
			row.add_child(button)
			_slots.append(button)
	var keys := UITheme.label("", 14, UITheme.DIM)
	keys.name = "Keys"
	keys.autowrap_mode = TextServer.AUTOWRAP_WORD
	keys.custom_minimum_size = Vector2(320, 60)
	middle_box.add_child(keys)

	var right := UITheme.inset_panel()
	columns.add_child(right)
	_details = RichTextLabel.new()
	_details.bbcode_enabled = true
	_details.custom_minimum_size = Vector2(300, 440)
	_details.add_theme_font_size_override("normal_font_size", 15)
	_details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(_details)
	player.abilities.changed.connect(refresh_if_open)


func refresh() -> void:
	if _picked == "":
		_details.text = "[font_size=22][color=#%s]Loadout[/color][/font_size]\n\nYou can carry eight abilities in two sets of four. Only the active set is on your keys; switch sets in a fight to reach the others.\n\n[color=#%s]Weapon abilities come from mastery and work with that weapon in hand. Class abilities come from your class tree.[/color]" % [UITheme.HEADING.to_html(false), UITheme.DIM.to_html(false)]
	for child in _list.get_children():
		child.queue_free()
	var known := player.abilities.known()
	if known.is_empty():
		_list.add_child(UITheme.label("None yet. Train a weapon to mastery 10, or learn abilities in your class tree.", 14, UITheme.DIM))
	for id in known:
		var ability: Dictionary = AbilityDB.ABILITIES[id]
		var button := Button.new()
		var source: String = ("Class" if ability.has("class") else WeaponMastery.NAMES[ability["weapon"]])
		button.text = " %s   (%s)" % [ability["name"], source]
		button.icon = ItemDB.icon(ability["icon"])
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.button_pressed = id == _picked
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_constant_override("icon_max_width", 22)
		button.add_theme_font_size_override("font_size", 14)
		if id in player.abilities.loadout:
			button.add_theme_color_override("font_color", UITheme.GOOD)
		button.pressed.connect(func() -> void:
			_picked = id
			_describe(id)
			refresh()
		)
		button.mouse_entered.connect(_describe.bind(id))
		_list.add_child(button)
	for slot in _slots.size():
		var id: String = player.abilities.loadout[slot]
		_slots[slot].icon = ItemDB.icon(AbilityDB.ABILITIES[id]["icon"]) if id != "" else null
		_slots[slot].text = "" if id != "" else "empty"
	var keys: PackedStringArray = []
	for index in AbilityDB.SET_SIZE:
		keys.append(GameSettings.describe("ability_%d" % (index + 1)).split(" / ")[0])
	(content.find_child("Keys", true, false) as Label).text = "Keys %s use the active set; %s switches set.\n%s" % [
		" ".join(keys), GameSettings.describe("ability_swap"), "Click an ability, then a slot." if _picked == "" else "Now click a slot for %s." % AbilityDB.ABILITIES[_picked]["name"]]


func _describe(id: String) -> void:
	if id == "":
		_details.text = "[color=#%s]An empty slot.[/color]" % UITheme.DIM.to_html(false)
		return
	var ability: Dictionary = AbilityDB.ABILITIES[id]
	var lines: PackedStringArray = []
	lines.append("[font_size=22][color=#%s]%s[/color][/font_size]" % [UITheme.HEADING.to_html(false), ability["name"]])
	var rank := player.abilities.rank(id)
	if ability.has("class"):
		lines.append("[color=#%s]%s ability  -  rank %d[/color]" % [UITheme.DIM.to_html(false), HeroClasses.CLASSES[ability["class"]]["name"], rank])
	else:
		lines.append("[color=#%s]%s ability  -  rank %d[/color]" % [UITheme.DIM.to_html(false), WeaponMastery.NAMES[ability["weapon"]], rank])
	lines.append("")
	lines.append(ability["text"])
	lines.append("")
	if ability.has("damage"):
		lines.append("Damage: x%.1f" % AbilityDB.damage(id, maxi(rank, 1)))
	var costs: PackedStringArray = []
	if ability.has("stamina"):
		costs.append("%d stamina" % ability["stamina"])
	if ability.has("mana"):
		costs.append("%d mana" % ability["mana"])
	lines.append("Cost: %s" % ", ".join(costs))
	lines.append("Cooldown: %ds" % ability["cooldown"])
	if ability.has("weapon"):
		lines.append("[color=#%s]Works with %s in hand.[/color]" % [UITheme.DIM.to_html(false), WeaponMastery.NAMES[ability["weapon"]].to_lower()])
	_details.text = "\n".join(lines)
