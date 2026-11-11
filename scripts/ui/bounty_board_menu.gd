class_name BountyBoardMenu
extends GameMenu
## A village's bounty board: today's marks, and the hunts already taken.

var _offers: VBoxContainer
var _hunting: VBoxContainer
var _message: Label


func _build() -> void:
	var title := UITheme.heading("BOUNTY BOARD", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var note := UITheme.label("Named beasts the village wants dead. Their dens are marked on your map once you take the job.", 14, UITheme.DIM)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(note)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	content.add_child(columns)
	for heading: String in ["Posted today", "Your hunts"]:
		var panel := UITheme.inset_panel()
		panel.custom_minimum_size = Vector2(500, 420)
		columns.add_child(panel)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 8)
		panel.add_child(box)
		box.add_child(UITheme.heading(heading, 18))
		var list := VBoxContainer.new()
		list.add_theme_constant_override("separation", 8)
		box.add_child(list)
		if heading == "Posted today":
			_offers = list
		else:
			_hunting = list
	_message = UITheme.label("", 14, UITheme.BAD)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_message)


func _bounties() -> Bounties:
	return player.get_parent().get_node("Bounties")


func refresh() -> void:
	var bounties := _bounties()
	for child in _offers.get_children() + _hunting.get_children():
		child.queue_free()
	var world: World = player.get_parent().get_node("World")
	var village: Variant = world.generator.village_near(world.world_to_cell(player.global_position))
	if village == null:
		_offers.add_child(UITheme.label("No village board here.", 15, UITheme.DIM))
	else:
		var day: int = (player.get_parent().get_node("DayNight") as DayNight).day
		for bounty: Dictionary in bounties.offers_at(village, day):
			var taken := bounties.is_active(bounty["id"])
			_offers.add_child(_card(bounty, "Taken" if taken else "Hunt", func() -> void:
				_message.text = bounties.accept(bounty)
				refresh()
			, taken))
	if bounties.active.is_empty():
		_hunting.add_child(UITheme.label("No hunts yet.", 15, UITheme.DIM))
	for bounty: Dictionary in bounties.active:
		_hunting.add_child(_card(bounty, "Abandon", func() -> void:
			bounties.abandon(bounty["id"])
			refresh()
		, false, bounties.direction_text(bounty)))


func _card(bounty: Dictionary, action: String, on_press: Callable, disabled: bool, where: String = "") -> Control:
	var card := UITheme.inset_panel()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	text.add_child(UITheme.heading(bounty["name"], 17))
	text.add_child(UITheme.label("Level %d Champion%s" % [bounty["level"], "  -  " + where if where != "" else ""], 13, UITheme.DIM))
	text.add_child(UITheme.label("%d gold, %d XP, and a fine piece of gear" % [bounty["gold"], bounty["xp"]], 13, UITheme.GOOD))
	var button := UITheme.button(action, on_press, 100.0)
	button.disabled = disabled
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(button)
	return card
