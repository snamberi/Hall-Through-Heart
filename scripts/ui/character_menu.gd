class_name CharacterMenu
extends GameMenu
## The character sheet. Points are planned before they are spent: choose an
## amount, press + or - beside an attribute, watch the statistics on the
## right show what would change, then Apply (or Reset the plan). The
## statistics are grouped into combat, defence and utility.

const AMOUNTS: Array[int] = [1, 5, 10]
const ATTRIBUTE_ICONS := {"strength": 38, "vitality": 35, "agility": 39, "luck": 40, "intelligence": 41, "endurance": 5}
## Groups for the statistics, by id.
const GROUPS: Array[Array] = [
	["Combat", ["physical_damage", "magic_power", "critical_chance", "critical_damage", "attack_speed", "life_steal",
		"fire_damage", "frost_damage", "poison_damage", "shadow_damage", "holy_damage"]],
	["Defence", ["max_health", "health_regen", "armor", "damage_taken", "elemental_resistance", "dodge_efficiency",
		"fire_resist", "frost_resist", "poison_resist", "shadow_resist", "holy_resist"]],
	["Utility", ["max_stamina", "max_mana", "move_speed", "magic_find", "gold_find", "mining_efficiency"]],
]

var _title: Label
var _xp: Label
var _points: Label
var _respec: Button
## How near the Sanctuary's middle counts as being at it, in pixels.
const SANCTUARY_REACH := 14 * 44
var _amount := 1
var _amount_buttons: Array[Button] = []
var _values: Dictionary[String, Label] = {}
var _planned: Dictionary[String, Label] = {}
var _minus: Dictionary[String, Button] = {}
var _plus: Dictionary[String, Button] = {}
var _stat_rows: Dictionary = {}
var _apply: Button
var _reset: Button
var _note: Label
## Points planned but not yet spent: attribute -> count.
var _plan: Dictionary = {}


func _build() -> void:
	content.add_theme_constant_override("separation", 10)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	content.add_child(head)
	_title = UITheme.heading("", 26)
	head.add_child(_title)
	_xp = UITheme.label("", 15, Color(0.6, 0.75, 1.0))
	_xp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_xp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_xp)
	# Taking back every spent point costs gold, and only at the Sanctuary.
	_respec = UITheme.button("Reset all points", _respec_points, 170.0)
	head.add_child(_respec)
	_points = UITheme.strong("", 17, UITheme.GOLD)
	_points.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_points)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	content.add_child(columns)

	# --- attributes
	var left_panel := UITheme.inset_panel()
	columns.add_child(left_panel)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	left.custom_minimum_size.x = 450.0
	left_panel.add_child(left)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	left.add_child(top)
	var heading := UITheme.heading("Attributes", 18)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(heading)
	top.add_child(UITheme.label("Amount", 14, UITheme.DIM))
	for amount in AMOUNTS:
		var button := UITheme.button(str(amount), func() -> void:
			_amount = amount
			refresh()
		, 40.0)
		button.toggle_mode = true
		button.custom_minimum_size.y = 30.0
		top.add_child(button)
		_amount_buttons.append(button)
	for id in Attributes.IDS:
		left.add_child(_attribute_row(id))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(spacer)
	_note = UITheme.label("", 14, UITheme.DIM)
	left.add_child(_note)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	left.add_child(actions)
	_apply = UITheme.primary_button("Apply", _apply_plan, 300.0)
	_apply.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(_apply)
	_reset = UITheme.button("Reset", func() -> void:
		_plan.clear()
		refresh()
	, 150.0)
	_reset.custom_minimum_size.y = 40.0
	actions.add_child(_reset)

	# --- statistics, grouped
	var right_panel := UITheme.inset_panel()
	columns.add_child(right_panel)
	var right := HBoxContainer.new()
	right.add_theme_constant_override("separation", 22)
	right_panel.add_child(right)
	var first := VBoxContainer.new()
	first.add_theme_constant_override("separation", 3)
	right.add_child(first)
	var second := VBoxContainer.new()
	second.add_theme_constant_override("separation", 3)
	right.add_child(second)
	for index in GROUPS.size():
		var column: VBoxContainer = first if index == 0 else second
		if index == 2:
			var gap := Control.new()
			gap.custom_minimum_size.y = 10.0
			column.add_child(gap)
		column.add_child(UITheme.heading(GROUPS[index][0], 17))
		for id: String in GROUPS[index][1]:
			var entry := _entry(id)
			if entry.is_empty():
				continue
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			column.add_child(row)
			var name_label := UITheme.label(entry["name"], 15, Color(0.74, 0.72, 0.66))
			name_label.custom_minimum_size.x = 152.0
			row.add_child(name_label)
			var value := UITheme.strong("", 15)
			value.custom_minimum_size.x = 64.0
			value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			row.add_child(value)
			var after := UITheme.label("", 15, UITheme.GOOD)
			after.custom_minimum_size.x = 70.0
			row.add_child(after)
			_stat_rows[id] = {"row": row, "value": value, "after": after, "entry": entry}
	player.stats.changed.connect(refresh_if_open)
	player.attributes.changed.connect(refresh_if_open)
	player.leveling.xp_changed.connect(func(_x: int, _r: int) -> void: refresh_if_open())


func _entry(id: String) -> Dictionary:
	for entry in CharacterStats.DISPLAY:
		if entry["id"] == id:
			return entry
	return {}


## One attribute: its picture, name and what it is for; its value with any
## planned points beside it; and the - and + to plan with.
func _attribute_row(id: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.card("card", 8))
	panel.custom_minimum_size.y = 62.0
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var icon := UITheme.icon(ATTRIBUTE_ICONS[id], 30.0)
	row.add_child(icon)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 0)
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(words)
	words.add_child(UITheme.strong(Attributes.NAMES[id], 17))
	words.add_child(UITheme.label(Attributes.TEXT[id], 14, UITheme.DIM))
	var value := UITheme.strong("0", 20)
	value.custom_minimum_size.x = 40.0
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(value)
	_values[id] = value
	var planned := UITheme.strong("", 16, UITheme.GOLD)
	planned.custom_minimum_size.x = 44.0
	planned.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(planned)
	_planned[id] = planned
	var minus := UITheme.button("−", func() -> void: _change(id, -_amount), 36.0)
	minus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(minus)
	_minus[id] = minus
	var plus := UITheme.button("+", func() -> void: _change(id, _amount), 36.0)
	plus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(plus)
	_plus[id] = plus
	return panel


func _planned_total() -> int:
	var total := 0
	for id: String in _plan:
		total += int(_plan[id])
	return total


func _change(id: String, by: int) -> void:
	var free := player.attributes.unspent - _planned_total()
	var now := int(_plan.get(id, 0))
	var next := clampi(now + clampi(by, -now, free), 0, now + free)
	if next == 0:
		_plan.erase(id)
	else:
		_plan[id] = next
	refresh()


func _apply_plan() -> void:
	# Each point spent refreshes this menu, which drops a plan bigger than
	# the points left: take the plan out first, then spend all of it.
	var plan := _plan.duplicate()
	_plan.clear()
	for id: String in plan:
		player.attributes.spend(id, int(plan[id]))
	Audio.play("level_up", -12.0, 0.1)
	refresh()


func refresh() -> void:
	var leveling := player.leveling
	var attributes := player.attributes
	# A plan cannot outlast the points it was made with.
	if _planned_total() > attributes.unspent:
		_plan.clear()
	_title.text = "%s  ·  Level %d" % [HeroClasses.CLASSES[player.class_id]["name"], leveling.level]
	var spent := 0
	for id: String in attributes.points:
		spent += attributes.points[id]
	var problem := respec_problem()
	_respec.disabled = problem != ""
	_respec.text = "Reset all points  ·  %s gold" % InventoryMenu._thousands(respec_cost())
	_respec.tooltip_text = problem if problem != "" else "Gives back all %d spent points to place again." % spent
	_xp.text = "Maximum level" if leveling.is_max_level() else "%s / %s XP  ·  %d talent point%s" % [InventoryMenu._thousands(leveling.xp), InventoryMenu._thousands(leveling.xp_to_next()), leveling.talent_points, "" if leveling.talent_points == 1 else "s"]
	var free := attributes.unspent - _planned_total()
	if attributes.unspent <= 0:
		_points.text = "No points to spend"
	elif _planned_total() > 0:
		_points.text = "%d of %d points left after this plan" % [free, attributes.unspent]
	else:
		_points.text = "%d point%s to spend" % [free, "" if free == 1 else "s"]
	_points.add_theme_color_override("font_color", UITheme.GOLD if attributes.unspent > 0 else UITheme.DIM)
	for index in AMOUNTS.size():
		_amount_buttons[index].set_pressed_no_signal(AMOUNTS[index] == _amount)
	for id in Attributes.IDS:
		var planned := int(_plan.get(id, 0))
		_values[id].text = str(attributes.points[id])
		_planned[id].text = "+%d" % planned if planned > 0 else ""
		_plus[id].disabled = free <= 0
		_minus[id].disabled = planned <= 0
	var preview := player.stats.preview_plan(_plan)
	for id: String in _stat_rows:
		var row: Dictionary = _stat_rows[id]
		var entry: Dictionary = row["entry"]
		var value := player.stats.get_stat(id)
		var shown: bool = not entry.get("hide_zero", false) or absf(value) > 0.0001
		(row["row"] as Control).visible = shown
		var change: Array = preview[id]
		(row["value"] as Label).text = change[0]
		(row["after"] as Label).text = "→ %s" % change[1] if change[2] else ""
	_apply.disabled = _plan.is_empty()
	_apply.text = "Apply %d point%s" % [_planned_total(), "" if _planned_total() == 1 else "s"] if not _plan.is_empty() else "Apply"
	_reset.disabled = _plan.is_empty()
	_note.text = "Planned points are not spent until you press Apply." if not _plan.is_empty() else ("Choose an amount, then press + beside an attribute." if attributes.unspent > 0 else "You earn attribute points as you level.")


## Gold to take back every spent point: grows with level.
func respec_cost() -> int:
	return 50 + roundi(15.0 * pow(player.leveling.level, 1.3))


## Why the points cannot be reset now, or "".
func respec_problem() -> String:
	var spent := 0
	for id: String in player.attributes.points:
		spent += player.attributes.points[id]
	if spent <= 0:
		return "No points have been spent."
	if player.indoors or player.global_position.length() > SANCTUARY_REACH:
		return "Only at the Sanctuary, where the world began."
	if player.inventory.gold < respec_cost():
		return "Costs %s gold." % InventoryMenu._thousands(respec_cost())
	return ""


func _respec_points() -> void:
	if respec_problem() != "":
		return
	player.inventory.add_gold(-respec_cost())
	player.attributes.reset()
	_plan.clear()
	Audio.play("level_up", -8.0, 0.0)
	refresh()
