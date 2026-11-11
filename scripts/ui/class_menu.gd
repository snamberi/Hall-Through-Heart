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


func _build() -> void:
	_title = UITheme.heading("", 28)
	content.add_child(_title)
	_note = UITheme.label("", 15, UITheme.DIM)
	content.add_child(_note)
	_choose_box = GridContainer.new()
	_choose_box.columns = 3
	_choose_box.add_theme_constant_override("h_separation", 14)
	_choose_box.add_theme_constant_override("v_separation", 14)
	content.add_child(_choose_box)
	for id in HeroClasses.CHOICES:
		_choose_box.add_child(_card(id))
	_tree_box = HBoxContainer.new()
	_tree_box.add_theme_constant_override("separation", 14)
	content.add_child(_tree_box)
	for column_name: String in ["Abilities", "Passives"]:
		var panel := UITheme.inset_panel()
		panel.custom_minimum_size = Vector2(330, 430)
		_tree_box.add_child(panel)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 6)
		panel.add_child(column)
		column.add_child(UITheme.heading(column_name, 18))
		if column_name == "Abilities":
			_ability_column = column
		else:
			_passive_column = column
	var right := UITheme.inset_panel()
	_tree_box.add_child(right)
	_details = RichTextLabel.new()
	_details.bbcode_enabled = true
	_details.custom_minimum_size = Vector2(300, 430)
	_details.add_theme_font_size_override("normal_font_size", 15)
	_details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(_details)
	_message = UITheme.label("", 14, UITheme.BAD)
	content.add_child(_message)
	player.class_changed.connect(refresh_if_open)


func refresh() -> void:
	var chosen := player.class_id != "adventurer"
	var level := player.leveling.level
	_choose_box.visible = not chosen
	_tree_box.visible = chosen
	_title.text = "Class:  %s" % HeroClasses.CLASSES[player.class_id]["name"]
	if not chosen:
		if level < HeroClasses.CHOICE_LEVEL:
			_note.text = "Reach level %d to choose a class. You are level %d." % [HeroClasses.CHOICE_LEVEL, level]
		else:
			_note.text = "Choose your path. This choice is permanent."
		for card in _choose_box.get_children():
			(card.find_child("Choose", true, false) as Button).disabled = level < HeroClasses.CHOICE_LEVEL
		return
	_note.text = "Class points: %d free of %d. You earn one every %d levels." % [player.class_points_free(), player.class_points_total(), HeroClasses.CLASS_POINT_LEVELS]
	var tree: Dictionary = HeroClasses.TREES[player.class_id]
	var data: Dictionary = HeroClasses.CLASSES[player.class_id]
	_details.text = "[font_size=22][color=#%s]%s[/color][/font_size]\n%s\n\n[color=#%s]%s[/color]\n\n[color=#%s]Spend class points on abilities (left) or passives (right). Each needs the one above it first. Point at a node to read it.[/color]" % [
		UITheme.HEADING.to_html(false), data["name"], data["text"], UITheme.GOOD.to_html(false), ",  ".join(HeroClasses.describe_bonuses(player.class_id)), UITheme.DIM.to_html(false)]
	_fill(_ability_column, tree["abilities"], true)
	_fill(_passive_column, tree["passives"], false)


func _fill(column: VBoxContainer, entries: Array, abilities: bool) -> void:
	for child in column.get_children().slice(1):
		child.queue_free()
	for index in entries.size():
		var entry: Array = entries[index]
		var id: String = entry[0]
		var rank: int = player.class_ranks.get(id, 0)
		var max_rank: int = 1 if abilities else entry[2]
		var name: String = AbilityDB.ABILITIES[id]["name"] if abilities else entry[1]
		var icon: int = AbilityDB.ABILITIES[id]["icon"] if abilities else entry[4]
		if index > 0:
			var link := ColorRect.new()
			link.custom_minimum_size = Vector2(4, 10)
			link.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			link.color = UITheme.GOLD if rank > 0 else Color(0.3, 0.3, 0.35)
			column.add_child(link)
		var button := Button.new()
		button.icon = ItemDB.icon(icon)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(300, 52)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_constant_override("icon_max_width", 30)
		var suffix := "   Lv %d" % entry[1] if abilities else ""
		button.text = "  %s   %d/%d%s" % [name, rank, max_rank, suffix]
		var problem := player.class_node_problem(id)
		button.add_theme_color_override("font_color", UITheme.GOOD if rank >= max_rank else UITheme.TEXT if problem == "" else UITheme.DIM)
		button.pressed.connect(func() -> void:
			_message.text = "" if player.learn_class_node(id) else player.class_node_problem(id)
			refresh()
		)
		button.mouse_entered.connect(_describe.bind(id, abilities, entry))
		column.add_child(button)


func _describe(id: String, ability: bool, entry: Array) -> void:
	var lines: PackedStringArray = []
	if ability:
		var data: Dictionary = AbilityDB.ABILITIES[id]
		lines.append("[font_size=22][color=#%s]%s[/color][/font_size]" % [UITheme.HEADING.to_html(false), data["name"]])
		lines.append("[color=#%s]Class ability  -  level %d[/color]" % [UITheme.DIM.to_html(false), entry[1]])
		lines.append("")
		lines.append(data["text"])
		lines.append("")
		lines.append("Cooldown %ds" % data["cooldown"])
		lines.append("[color=#%s]Once learned, put it on the bar from the Abilities screen.[/color]" % UITheme.DIM.to_html(false))
	else:
		lines.append("[font_size=22][color=#%s]%s[/color][/font_size]" % [UITheme.HEADING.to_html(false), entry[1]])
		lines.append("[color=#%s]Passive  -  %d rank%s[/color]" % [UITheme.DIM.to_html(false), entry[2], "s" if entry[2] > 1 else ""])
		lines.append("")
		for stat: String in entry[3]:
			for kind: String in entry[3][stat]:
				var amount: float = entry[3][stat][kind]
				var text := ItemDB.describe_modifier({"stat": stat, "kind": kind, "value": absf(amount)})
				lines.append(("%s per rank" % (text if amount >= 0.0 else "-" + text.substr(1))))
	var problem := player.class_node_problem(id)
	if problem != "" and problem != "Fully learned.":
		lines.append("")
		lines.append("[color=#%s]%s[/color]" % [UITheme.BAD.to_html(false), problem])
	_details.text = "\n".join(lines)


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
	var text := UITheme.label(data["text"], 13, UITheme.DIM)
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
