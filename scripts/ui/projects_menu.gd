class_name ProjectsMenu
extends GameMenu
## A village's project board. On the left, the village (its name, how big
## it has grown) and the projects in the order it wants them, with what each
## has done for it. On the right, the project it is asking for now: every
## good it needs as a row (icon, given / needed, what you hold, and a Give
## button), the gold, and the good it will do.

## The village (its centre cell).
var center := Vector2i.ZERO

var _left: VBoxContainer
var _right: VBoxContainer
var _message: Label


func _build() -> void:
	content.add_theme_constant_override("separation", 10)
	var title := UITheme.heading("VILLAGE PROJECTS", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 12)
	content.add_child(columns)
	_left = _column(columns, 400.0)
	_right = _column(columns, 520.0)
	_message = UITheme.reason("", 0.0)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_message)
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree():
			_message.text = ""
	)


func _column(parent: Control, width: float) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.card("card", 10))
	panel.custom_minimum_size = Vector2(width, 430)
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	return box


func _projects() -> VillageProjects:
	return player.get_parent().get_node("VillageProjects")


func refresh() -> void:
	for child in _left.get_children() + _right.get_children():
		child.queue_free()
	var projects := _projects()
	var done := projects.done(center)
	_left.add_child(UITheme.heading("%s at (%d, %d)" % [projects.tier_name(center), center.x, center.y], 20))
	_left.add_child(UITheme.label("%d of %d projects built" % [done.size(), VillageProjects.ORDER.size()], 15, UITheme.DIM))
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = VillageProjects.ORDER.size()
	bar.value = done.size()
	bar.custom_minimum_size = Vector2(370, 10)
	_left.add_child(bar)
	_left.add_child(UITheme.rule())
	var asking := projects.current(center)
	for project: String in VillageProjects.order_for(center):
		var data: Dictionary = VillageProjects.PROJECTS[project]
		var built := project in done
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_left.add_child(row)
		if project == asking:
			var arrow := UITheme.strong("›", 20, UITheme.GOLD)
			arrow.custom_minimum_size.x = 16.0
			row.add_child(arrow)
		else:
			row.add_child(StateMark.make("ready" if built else "locked", 16))
		var words := VBoxContainer.new()
		words.add_theme_constant_override("separation", -2)
		row.add_child(words)
		words.add_child(UITheme.strong(data["name"], 16, UITheme.GOOD if built else (UITheme.GOLD if project == asking else UITheme.DIM)))
		words.add_child(UITheme.paragraph(data["good"], 340.0, 13, UITheme.TEXT if built else UITheme.DIM))
	_fill_project(asking)


func _fill_project(project: String) -> void:
	var projects := _projects()
	if project == "":
		_right.add_child(UITheme.heading("Everything is built", 20))
		_right.add_child(UITheme.paragraph("This is a market town now, thanks to you. Its people will remember it.", 490.0, 15, UITheme.GOOD))
		return
	var data: Dictionary = VillageProjects.PROJECTS[project]
	_right.add_child(UITheme.heading("Now building: %s" % data["name"], 20))
	_right.add_child(UITheme.paragraph(data["good"], 490.0, 15, UITheme.GOOD))
	_right.add_child(UITheme.rule())
	for item_id: String in data["needs"]:
		var need := int(data["needs"][item_id])
		var have := projects.given(center, item_id)
		var held := player.inventory.count_of(item_id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_right.add_child(row)
		var item := Item.create(item_id)
		var icon := TextureRect.new()
		icon.texture = item.icon()
		icon.modulate = item.icon_tint()
		icon.custom_minimum_size = Vector2(32, 32)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		row.add_child(icon)
		var name_label := UITheme.strong(item.display_name(), 15, UITheme.TEXT)
		name_label.custom_minimum_size.x = 150.0
		row.add_child(name_label)
		var count := UITheme.label("%d / %d" % [have, need], 15, UITheme.GOOD if have >= need else UITheme.GOLD)
		count.custom_minimum_size.x = 70.0
		row.add_child(count)
		var held_label := UITheme.label("you hold %d" % held, 14, UITheme.DIM)
		held_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(held_label)
		var give := UITheme.button("Give", func() -> void:
			var amount := projects.give(center, player, item_id)
			_message.text = "Gave %d %s." % [amount, item.display_name()] if amount > 0 else ""
			refresh()
		, 70.0)
		give.disabled = have >= need or held <= 0
		row.add_child(give)
	var gold_need := int(data["gold"])
	var gold_have := projects.gold_given(center)
	var gold_row := HBoxContainer.new()
	gold_row.add_theme_constant_override("separation", 8)
	_right.add_child(gold_row)
	gold_row.add_child(UITheme.icon(ItemDB.GOLD_ICON, 32.0))
	var gold_name := UITheme.strong("Gold", 15, UITheme.TEXT)
	gold_name.custom_minimum_size.x = 150.0
	gold_row.add_child(gold_name)
	var gold_count := UITheme.label("%d / %d" % [gold_have, gold_need], 15, UITheme.GOOD if gold_have >= gold_need else UITheme.GOLD)
	gold_count.custom_minimum_size.x = 70.0
	gold_row.add_child(gold_count)
	var purse := UITheme.label("you hold %s" % InventoryMenu._thousands(player.inventory.gold), 14, UITheme.DIM)
	purse.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gold_row.add_child(purse)
	var give_gold := UITheme.button("Give", func() -> void:
		var amount := projects.give_gold(center, player)
		_message.text = "Gave %d gold." % amount if amount > 0 else ""
		refresh()
	, 70.0)
	give_gold.disabled = gold_have >= gold_need or player.inventory.gold <= 0
	gold_row.add_child(give_gold)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_right.add_child(fill)
	var all := UITheme.primary_button("Give everything I can", func() -> void:
		var total := 0
		for item_id: String in data["needs"]:
			total += projects.give(center, player, item_id)
		total += projects.give_gold(center, player)
		_message.text = "Given." if total > 0 else "You hold nothing it still needs."
		refresh()
	, 490.0)
	_right.add_child(all)
