class_name TeacherMenu
extends GameMenu
## A master of a legendary combat style offers to teach it, for a price.

var style := "fist"
var master := ""
var _title: Label
var _text: Label
var _moves: VBoxContainer
var _price: RichTextLabel
var _learn: Button
var _message: Label


func _build() -> void:
	_title = UITheme.heading("", 28)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_title)
	_text = UITheme.label("", 15, UITheme.TEXT)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	_text.custom_minimum_size = Vector2(620, 0)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_text)
	var panel := UITheme.inset_panel()
	content.add_child(panel)
	_moves = VBoxContainer.new()
	_moves.add_theme_constant_override("separation", 6)
	panel.add_child(_moves)
	_price = RichTextLabel.new()
	_price.bbcode_enabled = true
	_price.fit_content = true
	_price.custom_minimum_size = Vector2(620, 40)
	content.add_child(_price)
	_learn = UITheme.button("Learn", _on_learn, 260.0)
	_learn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(_learn)
	_message = UITheme.label("", 14, UITheme.BAD)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_message)


func refresh() -> void:
	var info: Dictionary = CombatStyles.STYLES[style]
	_title.text = info["name"].to_upper()
	_title.add_theme_color_override("font_color", info["color"])
	_text.text = "%s regards you a long while.\n\"%s\"" % [master if master != "" else "The master", info["text"]]
	for child in _moves.get_children():
		child.queue_free()
	_moves.add_child(UITheme.heading("What you would learn", 16))
	for id in AbilityDB.style_moves(style):
		var move: Dictionary = AbilityDB.ABILITIES[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var icon := TextureRect.new()
		icon.texture = AbilityDB.icon(id)
		icon.custom_minimum_size = Vector2(32, 32)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		row.add_child(icon)
		var line := UITheme.label("%s  -  %s" % [move["name"], move.get("text", "")], 13, UITheme.TEXT)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD
		line.custom_minimum_size = Vector2(560, 0)
		row.add_child(line)
		_moves.add_child(row)
	var parts: PackedStringArray = ["[color=#%s]Level %d needed (you are %d)[/color]" % [(UITheme.GOOD if player.leveling.level >= int(info.get("level", 1)) else UITheme.BAD).to_html(false), info.get("level", 1), player.leveling.level]]
	var cost: Dictionary = info.get("cost", {})
	for key: String in cost:
		var have: int = player.inventory.gold if key == "gold" else player.inventory.count_of(key)
		var name: String = "gold" if key == "gold" else ItemDB.ITEMS[key]["name"]
		parts.append("[color=#%s]%d %s (%d)[/color]" % [(UITheme.GOOD if have >= int(cost[key]) else UITheme.BAD).to_html(false), cost[key], name, have])
	_price.text = "[center]%s[/center]" % "   ".join(parts)
	var known: bool = style in player.styles.learned
	_learn.text = "Already learned" if known else "Learn %s" % info["name"]
	_learn.disabled = known
	_message.text = ""


func _on_learn() -> void:
	var problem := player.styles.learn(style)
	refresh()
	_message.text = problem
	if problem == "":
		_message.add_theme_color_override("font_color", UITheme.GOOD)
		_message.text = "Learned. Press 1 to fight with it; change styles in the Abilities screen."
	else:
		_message.add_theme_color_override("font_color", UITheme.BAD)
