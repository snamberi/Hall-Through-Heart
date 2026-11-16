class_name EvolutionMenu
extends GameMenu
## Race evolution. On the left, the race's three paths as short cards: pace,
## what the path is, and its next step. On the right, the chosen path in
## full: its four stages (taken, next, locked or closed), what the next
## stage asks for as a have/need checklist, how the character looks now and
## after, and the Evolve button with what it commits to said right by it.

const CARD := Vector2(360.0, 150.0)
const DETAIL_WIDTH := 790.0

var _selected := -1
var _note: Label
var _cards: VBoxContainer
var _path_name: Label
var _pace: Label
var _stages: VBoxContainer
var _now: LookPreview
var _after: LookPreview
var _after_label: Label
var _needs_title: Label
var _needs: VBoxContainer
var _commit: Label
var _evolve: Button


func _build() -> void:
	var head := UITheme.heading("EVOLUTION", 30)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(head)
	_note = UITheme.label("", 15, UITheme.DIM)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_note)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	content.add_child(row)
	_cards = VBoxContainer.new()
	_cards.add_theme_constant_override("separation", 8)
	row.add_child(_cards)

	var right := PanelContainer.new()
	right.add_theme_stylebox_override("panel", UITheme.card("card", 14))
	right.custom_minimum_size = Vector2(DETAIL_WIDTH, 0.0)
	row.add_child(right)
	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 18)
	right.add_child(split)

	# The path's four stages.
	var ladder := VBoxContainer.new()
	ladder.add_theme_constant_override("separation", 6)
	ladder.custom_minimum_size.x = 410.0
	split.add_child(ladder)
	_path_name = UITheme.heading("", 24)
	ladder.add_child(_path_name)
	_pace = UITheme.label("", 15, UITheme.TEXT)
	_pace.autowrap_mode = TextServer.AUTOWRAP_WORD
	_pace.custom_minimum_size.x = 410.0
	ladder.add_child(_pace)
	_stages = VBoxContainer.new()
	_stages.add_theme_constant_override("separation", 6)
	ladder.add_child(_stages)

	# Now and after; what the next stage needs; the button.
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 6)
	side.custom_minimum_size.x = 330.0
	split.add_child(side)
	var looks := HBoxContainer.new()
	looks.add_theme_constant_override("separation", 6)
	side.add_child(looks)
	_now = _preview()
	looks.add_child(_titled(_now, UITheme.label("Now", 14, UITheme.DIM)))
	var arrow := UITheme.strong(">", 22, UITheme.GOLD)
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	looks.add_child(arrow)
	_after = _preview()
	_after_label = UITheme.label("", 14, UITheme.GOLD)
	looks.add_child(_titled(_after, _after_label))
	_needs_title = UITheme.label("", 16, UITheme.HEADING)
	side.add_child(_needs_title)
	_needs = VBoxContainer.new()
	_needs.add_theme_constant_override("separation", 3)
	side.add_child(_needs)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(fill)
	_commit = UITheme.reason("", 330.0)
	side.add_child(_commit)
	_evolve = UITheme.primary_button("", _on_evolve, 330.0)
	side.add_child(_evolve)
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree():
			_selected = -1
	)


func refresh() -> void:
	var race := player.race()
	var paths := EvolutionDB.paths(race)
	var race_name: String = Appearance.RACES[race]["name"]
	if _selected < 0:
		_selected = maxi(player.evolution_path, 0)
	if player.evolution_path == -1:
		_note.text = "Three paths lie open to every %s. The first step on one closes the other two for good." % race_name.to_lower()
	else:
		var path: Dictionary = paths[player.evolution_path]
		_note.text = "You are a %s: %s path, stage %d of 4." % [path["stages"][player.evolution_stage - 1], path["name"], player.evolution_stage]
	for child in _cards.get_children():
		child.queue_free()
	for index in paths.size():
		_cards.add_child(_card(race, index, paths[index]))
	_show(race, _selected, paths[_selected])


## A path as a short card: name and pace, what it is, its next step.
func _card(race: String, index: int, path: Dictionary) -> Button:
	var pace: Dictionary = EvolutionDB.PACES[path["pace"]]
	var chosen := player.evolution_path == index
	var closed := player.evolution_path != -1 and not chosen
	var picked := index == _selected
	var button := Button.new()
	button.custom_minimum_size = CARD
	var kind := "card_selected" if picked else ("card_dim" if closed else "card")
	for state: String in ["normal", "pressed"]:
		button.add_theme_stylebox_override(state, UITheme.card(kind, 8))
	button.add_theme_stylebox_override("hover", UITheme.card("card_selected" if picked else "card_hover", 8))
	button.pressed.connect(func() -> void:
		_selected = index
		refresh()
	)
	UITheme.sounds(button)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	box.add_theme_constant_override("separation", 3)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(box)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	box.add_child(top)
	var name_label := UITheme.heading(path["name"], 20)
	name_label.modulate = Color(0.6, 0.6, 0.65) if closed else Color.WHITE
	top.add_child(name_label)
	var pace_tag := UITheme.strong(pace["name"], 14, pace["color"])
	pace_tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(pace_tag)
	var filler := Control.new()
	filler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(filler)
	if chosen:
		top.add_child(UITheme.badge("Your path", "gold"))
	elif closed:
		top.add_child(UITheme.badge("Closed", "plain"))
	var text := UITheme.paragraph(path["text"], CARD.x - 24.0, 15, UITheme.DIM if closed else UITheme.TEXT)
	box.add_child(text)
	var best := _gift_words(EvolutionDB.mods(race, index, 4))
	box.add_child(UITheme.label("At stage 4: %s" % ", ".join(best.slice(0, 2)), 14, UITheme.DIM if closed else UITheme.GOOD))
	var next_words := ""
	if closed:
		next_words = "Another path was taken."
	elif chosen and player.evolution_stage >= 4:
		next_words = "Fully evolved."
	else:
		var stage := player.evolution_stage + 1 if chosen else 1
		next_words = "Next: %s  ·  level %d" % [path["stages"][stage - 1], EvolutionDB.cost(race, index, stage)["level"]]
	box.add_child(UITheme.label(next_words, 14, UITheme.DIM if closed else UITheme.HEADING))
	for control: Control in box.find_children("*", "Control", true, false):
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return button


func _show(race: String, index: int, path: Dictionary) -> void:
	var pace: Dictionary = EvolutionDB.PACES[path["pace"]]
	var chosen := player.evolution_path == index
	var closed := player.evolution_path != -1 and not chosen
	_path_name.text = path["name"]
	_pace.text = "%s pace  ·  %s" % [pace["name"], pace["text"]]
	_pace.add_theme_color_override("font_color", pace["color"])
	for child in _stages.get_children():
		child.queue_free()
	for stage in range(1, 5):
		_stages.add_child(_stage_row(race, index, stage, path, closed))

	var next_stage := player.evolution_stage + 1 if chosen else 1
	var done := chosen and player.evolution_stage >= 4
	# The look now, and after the next stage (paths change it from stage 2).
	_now.show_look(player.appearance)
	var after := player.appearance.duplicate()
	if not done and not closed and next_stage >= 2 and path.has("look"):
		after.merge(path["look"], true)
	_after.show_look(after)
	_after.modulate = Color(0.55, 0.55, 0.6) if closed else Color.WHITE
	if closed or done:
		_after_label.text = "-"
	else:
		_after_label.text = path["stages"][next_stage - 1] + ("" if next_stage >= 2 and path.has("look") else " (same look)")

	for child in _needs.get_children():
		child.queue_free()
	if closed:
		_needs_title.text = "This path is closed"
		_commit.text = "You took the %s path. Evolution paths are for life." % EvolutionDB.paths(race)[player.evolution_path]["name"]
		_evolve.text = "Path closed"
		_evolve.disabled = true
		return
	if done:
		_needs_title.text = "Fully evolved"
		_commit.text = ""
		_evolve.text = "Fully evolved"
		_evolve.disabled = true
		return
	_needs_title.text = "Stage %d needs" % next_stage
	var need := EvolutionDB.cost(race, index, next_stage)
	var codex: Node = player.get_parent().get_node_or_null("Codex")
	var bosses: int = int(codex.stats.get("bosses", 0)) if codex else 0
	_needs.add_child(_need_row("Character level", player.leveling.level, int(need["level"])))
	if int(need["bosses"]) > 0:
		_needs.add_child(_need_row("World bosses beaten", bosses, int(need["bosses"])))
	for id: String in need["items"]:
		_needs.add_child(_need_row(ItemDB.ITEMS[id]["name"], player.inventory.count_of(id), int(need["items"][id])))
	if player.evolution_path == -1:
		_commit.text = "Permanent: taking the %s path closes the other two for good. Offerings are used up." % path["name"]
	else:
		_commit.text = "Each stage changes you for good. Offerings are used up."
	_evolve.text = "Evolve: %s" % path["stages"][next_stage - 1]
	_evolve.disabled = player.evolution_blocked(index) != ""
	_evolve.tooltip_text = player.evolution_blocked(index)


func _on_evolve() -> void:
	var paths := EvolutionDB.paths(player.race())
	var path: Dictionary = paths[_selected]
	var pace: Dictionary = EvolutionDB.PACES[path["pace"]]
	var why := player.evolve(_selected)
	if why == "":
		RingBurst.spawn(player.get_parent(), player.global_position + Vector2(0, -14), pace["color"], 140.0)
		Audio.play("level_up", -4.0, 0.0)
		Events.announcement.emit(str(path["stages"][player.evolution_stage - 1]).to_upper(), "Your %s evolution" % path["name"])
	else:
		_commit.text = why
	refresh()


## One stage: taken (tick, gold), next (lit), locked, or closed (dim).
func _stage_row(race: String, index: int, stage: int, path: Dictionary, closed: bool) -> Control:
	var reached := player.evolution_path == index and player.evolution_stage >= stage
	var next := not closed and ((player.evolution_path == index and player.evolution_stage + 1 == stage) or (player.evolution_path == -1 and stage == 1))
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UITheme.slot("slot_active" if reached else "slot_hover" if next else "slot"))
	frame.modulate = Color(0.7, 0.7, 0.75) if closed else Color.WHITE
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	frame.add_child(box)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	box.add_child(top)
	if reached or not next:
		top.add_child(StateMark.make("ready" if reached else "locked", 16))
	else:
		var arrow := UITheme.strong(">", 16, UITheme.INFO)
		arrow.custom_minimum_size.x = 16.0
		top.add_child(arrow)
	var title := UITheme.strong("%d. %s" % [stage, path["stages"][stage - 1]], 16, UITheme.GOLD if reached else (UITheme.HEADING if next else UITheme.DIM))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	if reached:
		top.add_child(UITheme.badge("Taken", "good"))
	elif next:
		top.add_child(UITheme.badge("Next", "info"))
	var gifts := UITheme.paragraph(", ".join(_gift_words(EvolutionDB.mods(race, index, stage))), 380.0, 14, UITheme.GOOD if reached or next else UITheme.DIM)
	box.add_child(gifts)
	return frame


## A have/need row: tick when met, lock when not.
func _need_row(what: String, have: int, need: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var met := have >= need
	row.add_child(StateMark.make("ready" if met else "missing", 16))
	var name_label := UITheme.label(what, 15, UITheme.TEXT if met else UITheme.DIM)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var amount := UITheme.strong("%d / %d" % [have, need], 15, UITheme.GOOD if met else UITheme.BAD)
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	amount.custom_minimum_size.x = 84.0
	row.add_child(amount)
	return row


static func _gift_words(mods: Dictionary) -> Array:
	var words: Array = []
	for stat: String in mods:
		for kind: String in mods[stat]:
			words.append(ItemDB.describe_modifier({"stat": stat, "kind": kind, "value": float(mods[stat][kind])}))
	return words


static func _preview() -> LookPreview:
	var preview := LookPreview.new()
	preview.custom_minimum_size = Vector2(150.0, 170.0)
	preview.framed = false
	preview.zoom = 2.4
	return preview


static func _titled(control: Control, title: Label) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.add_child(control)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size.x = 150.0
	title.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(title)
	return box
