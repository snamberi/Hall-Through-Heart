class_name EvolutionMenu
extends GameMenu
## Race evolution: the character on the left, and on the right their
## race's three paths, each four stages deep, with the pace of each path,
## what every stage asks for (marked ready, missing or locked) and the
## gifts it gives. The first step chooses a path for good.

const COLUMN := Vector2(300.0, 520.0)

var _portrait: LookPreview
var _title: Label
var _subtitle: Label
var _note: Label
var _columns: HBoxContainer


func _build() -> void:
	var head := UITheme.heading("EVOLUTION", 30)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(head)
	_note = UITheme.label("", 14, UITheme.DIM)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD
	_note.custom_minimum_size.x = 960.0
	content.add_child(_note)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	content.add_child(row)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 190.0
	left.add_theme_constant_override("separation", 4)
	row.add_child(left)
	_portrait = LookPreview.new()
	_portrait.custom_minimum_size = Vector2(190.0, 230.0)
	_portrait.framed = false
	_portrait.zoom = 2.8
	left.add_child(_portrait)
	_title = UITheme.heading("", 20)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD
	_title.custom_minimum_size.x = 190.0
	left.add_child(_title)
	_subtitle = UITheme.label("", 14, UITheme.DIM)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD
	_subtitle.custom_minimum_size.x = 190.0
	left.add_child(_subtitle)
	_columns = HBoxContainer.new()
	_columns.add_theme_constant_override("separation", 10)
	row.add_child(_columns)


func refresh() -> void:
	var race := player.race()
	_portrait.show_look(player.appearance)
	var paths := EvolutionDB.paths(race)
	var race_name: String = Appearance.RACES[race]["name"]
	if player.evolution_path == -1:
		_title.text = race_name
		_subtitle.text = "Not yet evolved"
	else:
		var path: Dictionary = paths[player.evolution_path]
		_title.text = path["stages"][player.evolution_stage - 1]
		_subtitle.text = "%s, %s path, stage %d of 4" % [race_name, path["name"], player.evolution_stage]
	_note.text = "Three paths lie open to every %s. The first step on one closes the others for good. Each stage asks for a level, world bosses beaten, and an offering, and changes you for good." % race_name.to_lower()
	for child in _columns.get_children():
		child.queue_free()
	for index in paths.size():
		_columns.add_child(_path_column(race, index, paths[index]))


func _path_column(race: String, index: int, path: Dictionary) -> Control:
	var pace: Dictionary = EvolutionDB.PACES[path["pace"]]
	var chosen := player.evolution_path == index
	var closed := player.evolution_path != -1 and not chosen
	var panel := PanelContainer.new()
	panel.custom_minimum_size = COLUMN
	panel.add_theme_stylebox_override("panel", UITheme.card("card_selected" if chosen else "card_dim" if closed else "card", 12))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var name_label := UITheme.heading(path["name"], 20)
	name_label.modulate = Color.WHITE if not closed else Color(0.6, 0.6, 0.65)
	box.add_child(name_label)
	var pace_label := UITheme.label("%s  -  %s" % [pace["name"], pace["text"]], 13, pace["color"])
	pace_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	pace_label.custom_minimum_size.x = COLUMN.x - 20.0
	box.add_child(pace_label)
	var text := UITheme.label(path["text"], 14, UITheme.DIM)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD
	text.custom_minimum_size.x = COLUMN.x - 20.0
	box.add_child(text)
	for stage in range(1, 5):
		box.add_child(_stage_row(race, index, stage, path, closed))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	var next_stage := (player.evolution_stage + 1) if chosen else 1
	var problem := player.evolution_blocked(index)
	var button := UITheme.button("", func() -> void:
		var why := player.evolve(index)
		if why == "":
			RingBurst.spawn(player.get_parent(), player.global_position + Vector2(0, -14), pace["color"], 140.0)
			Audio.play("level_up", -4.0, 0.0)
			Events.announcement.emit(str(path["stages"][player.evolution_stage - 1]).to_upper(), "Your %s evolution" % path["name"])
		refresh()
	, COLUMN.x - 20.0)
	if closed:
		button.text = "Another path was taken"
		button.disabled = true
	elif chosen and player.evolution_stage >= 4:
		button.text = "Fully evolved"
		button.disabled = true
	else:
		button.text = "Evolve: %s" % path["stages"][next_stage - 1]
		button.disabled = problem != ""
		button.tooltip_text = problem
	box.add_child(button)
	return panel


func _stage_row(race: String, index: int, stage: int, path: Dictionary, closed: bool) -> Control:
	var reached := player.evolution_path == index and player.evolution_stage >= stage
	var next := (player.evolution_path == index and player.evolution_stage + 1 == stage) or (player.evolution_path == -1 and stage == 1)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UITheme.slot("slot_active" if reached else "slot_hover" if next and not closed else "slot"))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	frame.add_child(box)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	box.add_child(top)
	var kind := "ready" if reached else ("missing" if next and not closed else "locked")
	top.add_child(StateMark.make(kind, 16))
	top.add_child(UITheme.label("%d. %s" % [stage, path["stages"][stage - 1]], 15, UITheme.HEADING if reached or next else UITheme.DIM))
	# The gifts.
	var gifts: PackedStringArray = []
	var mods := EvolutionDB.mods(race, index, stage)
	for stat: String in mods:
		for mod_kind: String in mods[stat]:
			gifts.append(ItemDB.describe_modifier({"stat": stat, "kind": mod_kind, "value": float(mods[stat][mod_kind])}))
	var gift_label := UITheme.label(", ".join(gifts), 13, UITheme.GOOD if not closed else UITheme.DIM)
	gift_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	gift_label.custom_minimum_size.x = COLUMN.x - 34.0
	box.add_child(gift_label)
	if not reached:
		var need := EvolutionDB.cost(race, index, stage)
		var parts: PackedStringArray = ["Lv %d" % need["level"]]
		if int(need["bosses"]) > 0:
			parts.append("%d boss%s" % [need["bosses"], "" if int(need["bosses"]) == 1 else "es"])
		for id: String in need["items"]:
			parts.append("%d %s (%d)" % [need["items"][id], ItemDB.ITEMS[id]["name"], player.inventory.count_of(id)])
		var need_label := UITheme.label("Needs: " + ", ".join(parts), 13, UITheme.TEXT if next and not closed else UITheme.DIM)
		need_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		need_label.custom_minimum_size.x = COLUMN.x - 34.0
		box.add_child(need_label)
	return frame
