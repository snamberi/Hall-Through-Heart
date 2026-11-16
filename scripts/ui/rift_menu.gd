class_name RiftMenu
extends GameMenu
## The Heart Rift's page, at the Sanctuary: this week's three affixes and
## boss, when they change, your depth and the monster level it means, the
## time to beat and your best this week, what a clear pays, and Enter.

var _body: VBoxContainer


func _build() -> void:
	content.add_theme_constant_override("separation", 10)
	var title := UITheme.heading("THE HEART RIFT", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.card("card", 12))
	panel.custom_minimum_size = Vector2(760, 0)
	content.add_child(panel)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 8)
	panel.add_child(_body)


func _rifts() -> HeartRift:
	return player.get_parent().get_node("HeartRift")


func refresh() -> void:
	for child in _body.get_children():
		child.queue_free()
	var rifts := _rifts()
	var week := HeartRift.week()
	var affixes := HeartRift.affixes(week)
	var boss := HeartRift.boss(week)
	var left := HeartRift.seconds_left_in_week()
	var head := HBoxContainer.new()
	_body.add_child(head)
	var heading := UITheme.heading("This week", 20)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(heading)
	head.add_child(UITheme.label("changes in %dd %dh" % [int(left) / 86400, int(left) % 86400 / 3600], 14, UITheme.DIM))
	for affix in affixes:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_body.add_child(row)
		var on_you := HeartRift.PLAYER_AFFIXES.has(affix)
		var badge := UITheme.badge("On you" if on_you else "Monsters", "bad" if on_you else "info")
		badge.custom_minimum_size.x = 90.0
		row.add_child(badge)
		var name_label := UITheme.strong(HeartRift.affix_name(affix), 16, Color(1.0, 0.6, 0.6) if on_you else UITheme.TEXT)
		name_label.custom_minimum_size.x = 130.0
		row.add_child(name_label)
		row.add_child(UITheme.label(HeartRift.affix_text(affix), 15, UITheme.DIM))
	var boss_row := HBoxContainer.new()
	boss_row.add_theme_constant_override("separation", 10)
	_body.add_child(boss_row)
	var boss_badge := UITheme.badge("Boss", "gold")
	boss_badge.custom_minimum_size.x = 90.0
	boss_row.add_child(boss_badge)
	boss_row.add_child(UITheme.strong(BossDB.BOSSES[boss]["name"], 16, BossDB.BOSSES[boss]["color"]))
	_body.add_child(UITheme.rule())
	var level := rifts.level_for(player)
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 40)
	_body.add_child(stats)
	for pair: Array in [["Depth", str(rifts.depth)], ["Monster level", str(level)], ["Time to beat", "about " + RaceCourse.clock_text(HeartRift.time_limit(5))],
			["Best this week", RaceCourse.clock_text(rifts.best_this_week()) if rifts.best_this_week() >= 0.0 else "-"]]:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 0)
		stats.add_child(cell)
		cell.add_child(UITheme.label(pair[0], 14, UITheme.DIM))
		cell.add_child(UITheme.strong(pair[1], 20, UITheme.GOLD))
	_body.add_child(UITheme.paragraph("Clear every room and the boss before the clock runs out to go a depth deeper; a slow clear, or leaving, drops one. Every clear pays gold, Rift Shards (for binding runes) and a hoard of rare gear, more the deeper you go.", 730.0, 15, UITheme.TEXT))
	var enter := UITheme.primary_button("Enter the rift at depth %d" % rifts.depth, func() -> void:
		var instances: Instances = player.get_parent().get_node("Instances")
		player.get_parent().get_node("Menus").close()
		instances.enter_rift(hash([week, rifts.depth, rifts.clears]), level, boss, affixes, rifts)
	, 730.0)
	enter.disabled = player.is_dead() or player.indoors
	enter.tooltip_text = "" if not enter.disabled else "Come back to the Sanctuary first."
	_body.add_child(enter)
