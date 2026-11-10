class_name CharacterMenu
extends GameMenu
## Character sheet: level, attributes to spend points on, and derived stats.

const SPEND_AMOUNTS: Array[int] = [1, 5, 10]
const ATTRIBUTE_ICONS := {"strength": 38, "vitality": 35, "agility": 39, "luck": 40, "intelligence": 41, "endurance": 5}

var _title: Label
var _xp: Label
var _unspent: Label
var _attribute_values: Dictionary[String, Label] = {}
var _attribute_previews: Dictionary[String, Label] = {}
var _buttons: Array[Button] = []
var _stat_values: Dictionary[String, Label] = {}


func _build() -> void:
	_title = UITheme.heading("", 28)
	content.add_child(_title)
	_xp = make_label("", 16, Color(0.55, 0.72, 1.0))
	content.add_child(_xp)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 48)
	content.add_child(columns)

	# Left: attributes
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	columns.add_child(left)
	left.add_child(UITheme.heading("Attributes"))
	_unspent = make_label("", 16, MenuColors.GOLD)
	left.add_child(_unspent)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 8)
	left.add_child(grid)
	for id in Attributes.IDS:
		var name_row := HBoxContainer.new()
		name_row.add_theme_constant_override("separation", 8)
		name_row.add_child(UITheme.icon(ATTRIBUTE_ICONS[id]))
		name_row.add_child(make_label(Attributes.NAMES[id], 18))
		grid.add_child(name_row)
		_attribute_values[id] = make_label("0", 18)
		_attribute_values[id].custom_minimum_size.x = 36.0
		grid.add_child(_attribute_values[id])
		var buttons := HBoxContainer.new()
		for amount in SPEND_AMOUNTS:
			buttons.add_child(_spend_button("+%d" % amount, id, amount))
		buttons.add_child(_spend_button("All", id, 1_000_000))
		grid.add_child(buttons)
		_attribute_previews[id] = make_label("", 14, Color(0.68, 0.66, 0.6))
		_attribute_previews[id].custom_minimum_size.x = 300.0
		grid.add_child(_attribute_previews[id])

	# Right: derived statistics
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	columns.add_child(right)
	right.add_child(UITheme.heading("Statistics"))
	var stat_grid := GridContainer.new()
	stat_grid.columns = 2
	stat_grid.add_theme_constant_override("h_separation", 28)
	stat_grid.add_theme_constant_override("v_separation", 3)
	right.add_child(stat_grid)
	for entry in CharacterStats.DISPLAY:
		stat_grid.add_child(make_label(entry["name"], 15, Color(0.72, 0.7, 0.64)))
		_stat_values[entry["id"]] = make_label("", 15)
		_stat_values[entry["id"]].horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_stat_values[entry["id"]].custom_minimum_size.x = 70.0
		stat_grid.add_child(_stat_values[entry["id"]])

	player.stats.changed.connect(refresh_if_open)
	player.leveling.xp_changed.connect(func(_x: int, _r: int) -> void: refresh_if_open())


func refresh() -> void:
	var leveling := player.leveling
	_title.text = "%s  -  Level %d" % [HeroClasses.CLASSES[player.class_id]["name"], leveling.level]
	if leveling.is_max_level():
		_xp.text = "Maximum level"
	else:
		_xp.text = "%d / %d XP        Talent points: %d" % [leveling.xp, leveling.xp_to_next(), leveling.talent_points]
	_unspent.text = "Points to spend: %d" % player.attributes.unspent
	for id in Attributes.IDS:
		_attribute_values[id].text = str(player.attributes.points[id])
		var parts: PackedStringArray = []
		for change in player.stats.preview_changes(id, 1):
			parts.append("%s %s > %s" % [change["name"], change["from"], change["to"]])
		_attribute_previews[id].text = "+1:  " + ("\n       ".join(parts) if parts else "no change yet")
	for button in _buttons:
		button.disabled = player.attributes.unspent <= 0
	for entry in CharacterStats.DISPLAY:
		var value := player.stats.get_stat(entry["id"])
		_stat_values[entry["id"]].text = CharacterStats.format_value(entry["format"], value)


func _spend_button(text: String, id: String, amount: int) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(44.0, 30.0)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void: player.attributes.spend(id, amount))
	_buttons.append(button)
	return button
