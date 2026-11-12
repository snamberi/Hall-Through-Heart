class_name ClassMenu
extends GameMenu
## Before level 10: what the classes are. At level 10: choosing one, for
## good. After that: the class's own tree of abilities and passives.

var _title: Label
var _note: Label
var _choose_box: GridContainer
var _tree_box: HBoxContainer
var _ability_column: VBoxContainer
var _passive_column: VBoxContainer
var _details: RichTextLabel
var _message: Label


## Where each node of a tree sits, as fractions of its panel: a path that
## winds down the panel so the tree reads as a tree, not a list.
const LAYOUT: Array[Vector2] = [Vector2(0.5, 0.13), Vector2(0.25, 0.38), Vector2(0.75, 0.62), Vector2(0.5, 0.87)]
const NODE := 64.0

var _left: VBoxContainer
var _portrait: LookPreview
var _class_name: Label
var _class_text: Label
var _points: Label
var _trees: Dictionary = {}
var _picked := ""
var _picked_ability := false
var _picked_entry: Array = []
var _detail_icon: TextureRect
var _learn: Button


func _build() -> void:
	_title = UITheme.heading("", 28)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_title)
	_note = UITheme.label("", 15, UITheme.DIM)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_note)
	_choose_box = GridContainer.new()
	_choose_box.columns = 3
	_choose_box.add_theme_constant_override("h_separation", 14)
	_choose_box.add_theme_constant_override("v_separation", 14)
	content.add_child(_choose_box)
	for id in HeroClasses.CHOICES:
		_choose_box.add_child(_card(id))
	_tree_box = HBoxContainer.new()
	_tree_box.add_theme_constant_override("separation", 12)
	content.add_child(_tree_box)

	# --- left: the classes, and you in yours
	var left_panel := UITheme.inset_panel()
	_tree_box.add_child(left_panel)
	_left = VBoxContainer.new()
	_left.add_theme_constant_override("separation", 6)
	_left.custom_minimum_size.x = 220.0
	left_panel.add_child(_left)
	_left.add_child(UITheme.heading("Classes", 17))
	for id: String in HeroClasses.CHOICES:
		var data: Dictionary = HeroClasses.CLASSES[id]
		var row := Button.new()
		row.name = id
		row.text = "  " + data["name"]
		row.icon = ItemDB.icon(data["icon"])
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.toggle_mode = true
		row.focus_mode = Control.FOCUS_NONE
		row.custom_minimum_size = Vector2(220.0, 34.0)
		row.add_theme_constant_override("icon_max_width", 22)
		row.add_theme_font_size_override("font_size", 15)
		row.tooltip_text = data["text"]
		_left.add_child(row)
	_portrait = LookPreview.new()
	_portrait.custom_minimum_size = Vector2(220.0, 150.0)
	_portrait.zoom = 2.4
	_portrait.framed = false
	_left.add_child(_portrait)
	_class_name = UITheme.heading("", 20)
	_class_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_left.add_child(_class_name)
	_class_text = UITheme.label("", 14, UITheme.DIM)
	_class_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	_class_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_class_text.custom_minimum_size.x = 220.0
	_left.add_child(_class_text)
	_points = UITheme.label("", 15, UITheme.GOLD)
	_points.autowrap_mode = TextServer.AUTOWRAP_WORD
	_points.custom_minimum_size.x = 220.0
	_left.add_child(_points)

	# --- middle: the two trees
	for column: Array in [["abilities", "Active Abilities", "Skills for the bar, each opening the next."], ["passives", "Passives", "Lasting gifts that shape your build."]]:
		var panel := UITheme.inset_panel()
		_tree_box.add_child(panel)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		panel.add_child(box)
		var head := UITheme.heading(column[1], 19)
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(head)
		var sub := UITheme.label(column[2], 13, UITheme.DIM)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(sub)
		var canvas := Control.new()
		canvas.custom_minimum_size = Vector2(250.0, 390.0)
		canvas.draw.connect(_draw_links.bind(canvas, column[0]))
		box.add_child(canvas)
		_trees[column[0]] = canvas

	# --- right: the chosen node
	var right := UITheme.inset_panel()
	_tree_box.add_child(right)
	var right_box := VBoxContainer.new()
	right_box.add_theme_constant_override("separation", 8)
	right_box.custom_minimum_size.x = 290.0
	right.add_child(right_box)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	right_box.add_child(top)
	_detail_icon = TextureRect.new()
	_detail_icon.custom_minimum_size = Vector2(64, 64)
	_detail_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_detail_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	top.add_child(_detail_icon)
	_details = RichTextLabel.new()
	_details.bbcode_enabled = true
	_details.fit_content = true
	_details.scroll_active = false
	_details.custom_minimum_size = Vector2(216, 0)
	_details.add_theme_font_size_override("normal_font_size", 15)
	_details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_details)
	_ranks = RichTextLabel.new()
	_ranks.bbcode_enabled = true
	_ranks.fit_content = true
	_ranks.scroll_active = false
	_ranks.custom_minimum_size = Vector2(290, 260)
	_ranks.add_theme_font_size_override("normal_font_size", 15)
	_ranks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_box.add_child(_ranks)
	_learn = UITheme.button("Learn", func() -> void:
		if _picked != "":
			_message.text = "" if player.learn_class_node(_picked) else player.class_node_problem(_picked)
			refresh()
	, 290.0)
	_learn.custom_minimum_size.y = 40.0
	right_box.add_child(_learn)
	_message = UITheme.label("", 14, UITheme.BAD)
	right_box.add_child(_message)
	player.class_changed.connect(refresh_if_open)


var _ranks: RichTextLabel


func refresh() -> void:
	var chosen := player.class_id != "adventurer"
	var level := player.leveling.level
	_choose_box.visible = not chosen
	_tree_box.visible = chosen
	_title.text = "CLASS PROGRESSION" if chosen else "CHOOSE YOUR CLASS"
	if not chosen:
		if level < HeroClasses.CHOICE_LEVEL:
			_note.text = "Reach level %d to choose a class. You are level %d." % [HeroClasses.CHOICE_LEVEL, level]
		else:
			_note.text = "Choose your path. This choice is permanent."
		for card in _choose_box.get_children():
			(card.find_child("Choose", true, false) as Button).disabled = level < HeroClasses.CHOICE_LEVEL
		return
	var data: Dictionary = HeroClasses.CLASSES[player.class_id]
	_note.text = ",   ".join(HeroClasses.describe_bonuses(player.class_id))
	for id: String in HeroClasses.CHOICES:
		var row := _left.get_node(id) as Button
		row.set_pressed_no_signal(id == player.class_id)
		row.disabled = id != player.class_id
	_portrait.show_look(player.appearance)
	_portrait.play("attack")
	_class_name.text = data["name"]
	_class_text.text = data["text"]
	var next_point := player.class_chosen_at + (player.class_points_total()) * HeroClasses.CLASS_POINT_LEVELS
	_points.text = "Class points  %d free\n%d earned; next at level %d" % [player.class_points_free(), player.class_points_total(), next_point]
	var tree: Dictionary = HeroClasses.TREES[player.class_id]
	_fill_tree("abilities", tree["abilities"])
	_fill_tree("passives", tree["passives"])
	if _picked == "" or not _picked_entry in (tree["abilities"] + tree["passives"]):
		_pick(tree["abilities"][0][0], true, tree["abilities"][0])
	else:
		_pick(_picked, _picked_ability, _picked_entry)


## Lays out one tree's nodes: framed icons with rank badges.
func _fill_tree(column: String, entries: Array) -> void:
	var canvas: Control = _trees[column]
	for child in canvas.get_children():
		child.queue_free()
	var abilities := column == "abilities"
	for index in entries.size():
		var entry: Array = entries[index]
		var id: String = entry[0]
		var rank: int = player.class_ranks.get(id, 0)
		var max_rank: int = 1 if abilities else entry[2]
		var icon: int = AbilityDB.ABILITIES[id]["icon"] if abilities else entry[4]
		var problem := player.class_node_problem(id)
		var learned := rank > 0
		var open := problem == "" and rank < max_rank
		var at: Vector2 = LAYOUT[mini(index, LAYOUT.size() - 1)] * canvas.custom_minimum_size - Vector2(NODE, NODE) / 2.0
		var node := Button.new()
		node.focus_mode = Control.FOCUS_NONE
		node.position = at
		node.size = Vector2(NODE, NODE)
		node.custom_minimum_size = Vector2(NODE, NODE)
		var style := UITheme.slot("slot_active" if learned or id == _picked else "slot_hover" if open else "slot")
		if id == _picked and not learned:
			style.modulate_color = Color(1.2, 1.2, 1.2)
		var hover := UITheme.slot("slot_active" if learned else "slot_hover")
		node.add_theme_stylebox_override("normal", style)
		node.add_theme_stylebox_override("hover", hover)
		node.add_theme_stylebox_override("pressed", hover)
		var picture := TextureRect.new()
		picture.texture = ItemDB.icon(icon)
		picture.modulate = Color.WHITE if learned or open else Color(0.45, 0.45, 0.5)
		picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.add_child(picture)
		var badge := UITheme.label("%d / %d" % [rank, max_rank], 13, UITheme.GOLD if learned else UITheme.TEXT)
		badge.add_theme_color_override("font_outline_color", Color.BLACK)
		badge.add_theme_constant_override("outline_size", 4)
		badge.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		badge.offset_top = -19.0
		badge.offset_bottom = -3.0
		badge.offset_right = -5.0
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.add_child(badge)
		var title: String = AbilityDB.ABILITIES[id]["name"] if abilities else entry[1]
		var caption := UITheme.label(title, 13, UITheme.TEXT if learned or open else UITheme.DIM)
		caption.position = at + Vector2(-38.0, NODE + 3.0)
		caption.size = Vector2(NODE + 76.0, 16.0)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.add_child(caption)
		node.pressed.connect(func() -> void:
			_pick(id, abilities, entry)
			refresh()
		)
		node.mouse_entered.connect(func() -> void: _pick(id, abilities, entry))
		UITheme.sounds(node)
		canvas.add_child(node)
	canvas.queue_redraw()


## The lines between a tree's nodes: gold where the path is learned.
func _draw_links(canvas: Control, column: String) -> void:
	if player == null or player.class_id == "adventurer":
		return
	var entries: Array = HeroClasses.TREES[player.class_id][column]
	for index in range(1, entries.size()):
		var from: Vector2 = LAYOUT[index - 1] * canvas.custom_minimum_size
		var to: Vector2 = LAYOUT[mini(index, LAYOUT.size() - 1)] * canvas.custom_minimum_size
		var learned: bool = player.class_ranks.get(entries[index][0], 0) > 0
		var color := UITheme.GOLD if learned else Color(0.32, 0.32, 0.4)
		# An elbow: out of the parent's side, across, then down into the
		# child, so it never runs through a caption.
		var side := signf(to.x - from.x) if not is_equal_approx(to.x, from.x) else 0.0
		var start := from + (Vector2(side * NODE / 2.0, 0.0) if side != 0.0 else Vector2(0.0, NODE / 2.0 + 18.0))
		var points := PackedVector2Array([start, Vector2(to.x, start.y), to - Vector2(0, NODE / 2.0)])
		if learned:
			canvas.draw_polyline(points, Color(1.0, 0.8, 0.35, 0.3), 7.0)
		canvas.draw_polyline(points, color, 3.0)
		canvas.draw_colored_polygon(PackedVector2Array([points[2] + Vector2(-5, -7), points[2] + Vector2(5, -7), points[2]]), color)


## Shows one node: what it is, and every rank of it.
func _pick(id: String, ability: bool, entry: Array) -> void:
	_picked = id
	_picked_ability = ability
	_picked_entry = entry
	var rank: int = player.class_ranks.get(id, 0)
	var max_rank: int = 1 if ability else entry[2]
	var head: PackedStringArray = []
	var ranks: PackedStringArray = []
	if ability:
		var data: Dictionary = AbilityDB.ABILITIES[id]
		_detail_icon.texture = ItemDB.icon(data["icon"])
		head.append("[font_size=20][color=#%s]%s[/color][/font_size]" % [UITheme.HEADING.to_html(false), data["name"]])
		head.append("[color=#%s]Active ability  -  level %d[/color]" % [UITheme.DIM.to_html(false), entry[1]])
		head.append("Rank: [color=#%s]%d / %d[/color]" % [UITheme.GOLD.to_html(false), rank, max_rank])
		ranks.append(data["text"])
		ranks.append("")
		var costs: PackedStringArray = []
		if data.get("stamina", 0.0) > 0.0:
			costs.append("%d stamina" % roundi(data["stamina"]))
		if data.get("mana", 0.0) > 0.0:
			costs.append("%d mana" % roundi(data["mana"]))
		ranks.append("[color=#%s]Cooldown %ss   Costs %s[/color]" % [UITheme.INFO.to_html(false), str(data["cooldown"]), " and ".join(costs) if not costs.is_empty() else "nothing"])
		ranks.append("")
		ranks.append("[color=#%s]Once learned, put it on the bar from the Abilities screen.[/color]" % UITheme.DIM.to_html(false))
	else:
		_detail_icon.texture = ItemDB.icon(entry[4])
		head.append("[font_size=20][color=#%s]%s[/color][/font_size]" % [UITheme.HEADING.to_html(false), entry[1]])
		head.append("[color=#%s]Passive[/color]" % UITheme.DIM.to_html(false))
		head.append("Rank: [color=#%s]%d / %d[/color]" % [UITheme.GOLD.to_html(false), rank, max_rank])
		for step in range(1, max_rank + 1):
			var parts: PackedStringArray = []
			for stat: String in entry[3]:
				for kind: String in entry[3][stat]:
					var amount: float = entry[3][stat][kind] * step
					var text := ItemDB.describe_modifier({"stat": stat, "kind": kind, "value": absf(amount)})
					parts.append(text if amount >= 0.0 else "-" + text.substr(1))
			var reached := rank >= step
			ranks.append("[color=#%s]Rank %d[/color]   [color=#%s]%s[/color]" % [(UITheme.GOLD if reached else UITheme.DIM).to_html(false), step,
				(UITheme.GOOD if reached else UITheme.TEXT).to_html(false), ", ".join(parts)])
	var problem := player.class_node_problem(id)
	if problem != "" and problem != "Fully learned.":
		ranks.append("")
		ranks.append("[color=#%s]%s[/color]" % [UITheme.BAD.to_html(false), problem])
	_details.text = "\n".join(head)
	_ranks.text = "\n".join(ranks)
	_learn.disabled = problem != ""
	_learn.text = "Fully learned" if rank >= max_rank else "Learn  (1 class point)" if rank == 0 else "Learn rank %d  (1 class point)" % (rank + 1)


func _card(id: String) -> Control:
	var data: Dictionary = HeroClasses.CLASSES[id]
	var card := UITheme.inset_panel()
	card.custom_minimum_size = Vector2(340.0, 0.0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	card.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.add_child(UITheme.icon(data["icon"], 26.0))
	head.add_child(UITheme.heading(data["name"], 20))
	box.add_child(head)
	var text := UITheme.label(data["text"], 14, UITheme.DIM)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD
	text.custom_minimum_size = Vector2(300.0, 36.0)
	box.add_child(text)
	var bonuses := UITheme.label(",  ".join(HeroClasses.describe_bonuses(id)), 13, UITheme.GOOD)
	bonuses.autowrap_mode = TextServer.AUTOWRAP_WORD
	bonuses.custom_minimum_size = Vector2(300.0, 58.0)
	box.add_child(bonuses)
	var names: PackedStringArray = []
	for entry: Array in HeroClasses.TREES[id]["abilities"]:
		names.append(AbilityDB.ABILITIES[entry[0]]["name"])
	var abilities := UITheme.label("Abilities: " + ", ".join(names), 13, UITheme.INFO)
	abilities.autowrap_mode = TextServer.AUTOWRAP_WORD
	abilities.custom_minimum_size = Vector2(300.0, 36.0)
	box.add_child(abilities)
	var button := UITheme.button("Choose", func() -> void:
		_message.text = player.choose_class(id)
		refresh()
	, 120.0)
	button.name = "Choose"
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.add_child(button)
	return card
