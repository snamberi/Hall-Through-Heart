class_name MasteryMenu
extends GameMenu
## Weapon mastery: level and progress for each category, plus milestones.

var _rows: Dictionary[String, Dictionary] = {}
var _milestone_title: Label
var _milestone_labels: Array[Label] = []


func _build() -> void:
	content.add_child(make_label("Weapon Mastery", 28))

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 48)
	content.add_child(columns)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 10)
	columns.add_child(grid)
	for id in WeaponMastery.IDS:
		var name_label := make_label(WeaponMastery.NAMES[id], 18)
		name_label.custom_minimum_size.x = 170.0
		var level_label := make_label("", 16)
		level_label.custom_minimum_size.x = 90.0
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(180.0, 16.0)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.show_percentage = false
		var bonus_label := make_label("", 14, MenuColors.GOOD)
		bonus_label.custom_minimum_size.x = 110.0
		for control: Control in [name_label, level_label, bar, bonus_label]:
			grid.add_child(control)
		_rows[id] = {"name": name_label, "level": level_label, "bar": bar, "bonus": bonus_label}

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	columns.add_child(right)
	_milestone_title = make_label("", 20, MenuColors.HEADING)
	right.add_child(_milestone_title)
	for milestone in WeaponMastery.MILESTONES:
		var label := make_label("", 15)
		_milestone_labels.append(label)
		right.add_child(label)
	right.add_child(make_label("Milestone rewards are not in the game yet.", 13, MenuColors.DIM))

	player.mastery.changed.connect(refresh_if_open)


func refresh() -> void:
	var mastery := player.mastery
	for id in WeaponMastery.IDS:
		var row: Dictionary = _rows[id]
		var level := mastery.levels[id]
		var equipped := id == player.weapon_type
		row["name"].text = WeaponMastery.NAMES[id] + ("  (in hand)" if equipped else "")
		row["name"].add_theme_color_override("font_color", MenuColors.GOLD if equipped else Color(0.9, 0.87, 0.8))
		row["level"].text = "%d / %d" % [level, WeaponMastery.MAX_LEVEL]
		row["bar"].max_value = WeaponMastery.xp_required(level)
		row["bar"].value = mastery.xp[id]
		row["bonus"].text = "+%.1f%% damage" % (mastery.damage_bonus(id) * 100.0)

	var current := mastery.levels[player.weapon_type]
	_milestone_title.text = "%s milestones" % WeaponMastery.NAMES[player.weapon_type]
	for i in WeaponMastery.MILESTONES.size():
		var milestone := WeaponMastery.MILESTONES[i]
		var reached: bool = current >= milestone["level"]
		_milestone_labels[i].text = "%s  Lv %d   %s" % ["[x]" if reached else "[  ]", milestone["level"], milestone["reward"]]
		_milestone_labels[i].add_theme_color_override("font_color", MenuColors.GOOD if reached else MenuColors.DIM)
