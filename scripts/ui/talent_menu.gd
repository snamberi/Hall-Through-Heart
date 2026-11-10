class_name TalentMenu
extends GameMenu
## The talent trees: pick a tree, then click nodes to spend talent points.

const CELL := Vector2(150.0, 92.0)
const NODE_SIZE := 62.0
const KIND_NAMES := {"minor": "Minor talent", "major": "Major talent", "keystone": "Keystone"}

var _points: Label
var _tree_buttons: Dictionary[String, Button] = {}
var _graph: Control
var _node_buttons: Dictionary[String, Button] = {}
var _rank_labels: Dictionary[String, Label] = {}
var _details: RichTextLabel
var _tree := "offense"
var _shown := ""


func _build() -> void:
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 28)
	content.add_child(top)
	top.add_child(UITheme.heading("Talents", 28))
	_points = UITheme.label("", 18, UITheme.GOLD)
	_points.size_flags_vertical = Control.SIZE_SHRINK_END
	top.add_child(_points)

	var trees := HBoxContainer.new()
	trees.add_theme_constant_override("separation", 8)
	content.add_child(trees)
	for tree in TalentDB.TREES:
		var button := Button.new()
		button.text = " " + tree["name"]
		button.icon = ItemDB.icon(tree["icon"])
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(124.0, 38.0)
		button.add_theme_constant_override("icon_max_width", 22)
		button.pressed.connect(_show_tree.bind(tree["id"]))
		trees.add_child(button)
		_tree_buttons[tree["id"]] = button

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 28)
	content.add_child(columns)
	var frame := UITheme.inset_panel()
	columns.add_child(frame)
	_graph = Control.new()
	_graph.custom_minimum_size = Vector2(CELL.x * 3, CELL.y * 4 + 6.0)
	_graph.draw.connect(_draw_links)
	frame.add_child(_graph)

	for id: String in TalentDB.NODES:
		var node: Dictionary = TalentDB.NODES[id]
		var big: bool = node["kind"] != "minor"
		var size := NODE_SIZE + (10.0 if big else 0.0)
		var button := Button.new()
		button.icon = ItemDB.icon(node["icon"])
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.focus_mode = Control.FOCUS_NONE
		button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		button.custom_minimum_size = Vector2(size, size)
		button.size = Vector2(size, size)
		button.position = _center(id) - Vector2(size, size) / 2.0
		button.pressed.connect(func() -> void:
			player.talents.learn(id)
			_describe(id)
		)
		button.mouse_entered.connect(_describe.bind(id))
		_graph.add_child(button)
		_node_buttons[id] = button
		var rank := UITheme.label("", 13)
		rank.add_theme_color_override("font_outline_color", Color.BLACK)
		rank.add_theme_constant_override("outline_size", 4)
		rank.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rank.position = Vector2(size - 30.0, size - 20.0)
		button.add_child(rank)
		_rank_labels[id] = rank

	var side := UITheme.inset_panel()
	columns.add_child(side)
	_details = RichTextLabel.new()
	_details.bbcode_enabled = true
	_details.fit_content = true
	_details.scroll_active = false
	_details.custom_minimum_size = Vector2(300.0, 300.0)
	_details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side.add_child(_details)

	player.talents.changed.connect(refresh_if_open)


func refresh() -> void:
	_points.text = "Talent points: %d      Spent: %d" % [player.leveling.talent_points, player.talents.spent_points()]
	for tree in _tree_buttons:
		_tree_buttons[tree].set_pressed_no_signal(tree == _tree)
	for id in _node_buttons:
		var node: Dictionary = TalentDB.NODES[id]
		var button := _node_buttons[id]
		button.visible = node["tree"] == _tree
		var rank := player.talents.rank(id)
		_rank_labels[id].text = "%d/%d" % [rank, node["max"]]
		var reason := player.talents.blocked_reason(id)
		var locked := reason.begins_with("Requires")
		button.modulate = Color(0.45, 0.45, 0.5) if locked else Color.WHITE
		_rank_labels[id].add_theme_color_override("font_color", UITheme.GOLD if rank >= node["max"] else UITheme.GOOD if rank > 0 else UITheme.TEXT)
	_graph.queue_redraw()
	_describe(_shown if _shown != "" and TalentDB.NODES[_shown]["tree"] == _tree else "")


func _show_tree(tree: String) -> void:
	_tree = tree
	_shown = ""
	refresh()


func _center(id: String) -> Vector2:
	var pos: Vector2i = TalentDB.NODES[id]["pos"]
	return Vector2((pos.x + 0.5) * CELL.x, (pos.y + 0.5) * CELL.y + 3.0)


func _draw_links() -> void:
	for id in TalentDB.nodes_in(_tree):
		for required: String in TalentDB.NODES[id].get("requires", []):
			var open := player.talents.has(required)
			var color := UITheme.HEADING if open else Color(0.3, 0.3, 0.36)
			_graph.draw_line(_center(required), _center(id), color, 3.0 if open else 2.0)


func _describe(id: String) -> void:
	_shown = id
	if id == "":
		_details.text = "[color=#%s]Hover a talent to see what it does. Click to learn a rank.\n\nYou earn one talent point every two levels.[/color]" % UITheme.DIM.to_html(false)
		return
	var node: Dictionary = TalentDB.NODES[id]
	var rank := player.talents.rank(id)
	var lines: PackedStringArray = []
	lines.append("[font_size=20][color=#%s]%s[/color][/font_size]" % [UITheme.HEADING.to_html(false), node["name"]])
	lines.append("[color=#%s]%s  -  rank %d / %d[/color]" % [UITheme.DIM.to_html(false), KIND_NAMES[node["kind"]], rank, node["max"]])
	if rank > 0:
		lines.append("")
		lines.append("[color=#%s]Now:[/color]" % UITheme.DIM.to_html(false))
		for line in TalentDB.describe(id, rank):
			lines.append("[color=#%s]%s[/color]" % [UITheme.GOOD.to_html(false), line])
	if rank < node["max"]:
		lines.append("")
		lines.append("[color=#%s]Next rank:[/color]" % UITheme.DIM.to_html(false))
		for line in TalentDB.describe(id, rank + 1):
			lines.append(line)
	var reason := player.talents.blocked_reason(id)
	if reason != "" and rank < node["max"]:
		lines.append("")
		lines.append("[color=#%s]%s[/color]" % [UITheme.BAD.to_html(false), reason])
	_details.text = "\n".join(lines)
