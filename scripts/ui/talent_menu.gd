class_name TalentMenu
extends GameMenu
## The talent tree on a canvas: drag to look around, scroll to zoom, hover a
## talent to read it, click to learn a rank.

const RADIUS := {"minor": 15.0, "major": 20.0, "keystone": 24.0, "milestone": 26.0}

var _points: Label
var _canvas: Control
var _details: RichTextLabel
var _offset := Vector2.ZERO
var _zoom := 0.7
var _dragging := false
var _dragged := 0.0
var _hovered := ""
var _font: Font
var _icons: Dictionary = {}


func _build() -> void:
	_font = UITheme.get_theme().default_font
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 28)
	content.add_child(top)
	top.add_child(UITheme.heading("TALENTS", 30))
	_points = UITheme.label("", 18, UITheme.GOLD)
	_points.size_flags_vertical = Control.SIZE_SHRINK_END
	top.add_child(_points)
	top.add_child(UITheme.label("Drag to look around   Scroll to zoom   Click to learn", 14, UITheme.DIM))
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 12)
	content.add_child(columns)
	var frame := UITheme.inset_panel()
	columns.add_child(frame)
	_canvas = Control.new()
	_canvas.custom_minimum_size = Vector2(840, 540)
	_canvas.clip_contents = true
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.draw.connect(_draw_tree)
	_canvas.gui_input.connect(_on_input)
	frame.add_child(_canvas)
	var side := UITheme.inset_panel()
	columns.add_child(side)
	_details = RichTextLabel.new()
	_details.bbcode_enabled = true
	_details.scroll_active = false
	_details.custom_minimum_size = Vector2(300, 540)
	UITheme.font_size(_details, 15, "normal_font_size")
	_details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side.add_child(_details)
	player.talents.changed.connect(refresh_if_open)


func refresh() -> void:
	_points.text = "Points: %d      Spent: %d" % [player.leveling.talent_points, player.talents.spent_points()]
	_describe(_hovered)
	_canvas.queue_redraw()


func _to_screen(id: String) -> Vector2:
	# The tree is drawn with the Heart a little below the middle.
	return _canvas.size / 2.0 + Vector2(0, 40) + (TalentDB.position(id) + _offset) * _zoom


func _node_at(point: Vector2) -> String:
	for id: String in TalentDB.NODES:
		if _to_screen(id).distance_to(point) < RADIUS[TalentDB.NODES[id]["kind"]] * _zoom + 4.0:
			return id
	return ""


func _on_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_dragging = true
				_dragged = 0.0
			else:
				_dragging = false
				# A click that did not drag learns the talent under the mouse.
				if _dragged < 6.0:
					var id := _node_at(event.position)
					if id != "" and player.talents.learn(id):
						Audio.play("level_up", -12.0, 0.1)
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_zoom = clampf(_zoom * (1.12 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.89), 0.3, 1.6)
			_canvas.queue_redraw()
	elif event is InputEventMouseMotion:
		if _dragging:
			_dragged += event.relative.length()
			_offset += event.relative / _zoom
			_canvas.queue_redraw()
		var id := _node_at(event.position)
		if id != _hovered:
			_hovered = id
			_describe(id)
			_canvas.queue_redraw()


func _draw_tree() -> void:
	_canvas.draw_rect(Rect2(Vector2.ZERO, _canvas.size), Color("0b0d15"))
	var talents := player.talents
	# Faint rings for each distance out.
	for ring in range(1, 10):
		_canvas.draw_arc(_to_screen("awakened_heart"), ring * TalentDB.STEP * _zoom, 0.0, TAU, 96, Color(1, 1, 1, 0.03), 1.0)
	for edge: Array in TalentDB.edges():
		var both: bool = talents.has(edge[0]) and talents.has(edge[1])
		var either: bool = talents.has(edge[0]) or talents.has(edge[1])
		var color := UITheme.GOLD if both else Color(0.55, 0.5, 0.4, 0.8) if either else Color(0.28, 0.28, 0.34)
		_canvas.draw_line(_to_screen(edge[0]), _to_screen(edge[1]), color, (4.0 if both else 2.5) * _zoom)
	for id: String in TalentDB.NODES:
		_draw_node(id)
	# Branch names, near the top of each branch.
	for branch: String in TalentDB.BRANCHES:
		var info: Array = TalentDB.BRANCHES[branch]
		var at := _canvas.size / 2.0 + Vector2(0, 40) + (Vector2.from_angle(info[1]) * TalentDB.STEP * 3.0 + Vector2.from_angle(info[1] + PI / 2.0) * 44.0 + _offset) * _zoom
		_canvas.draw_string_outline(UITheme.bold(), at - Vector2(60, 0), info[0], HORIZONTAL_ALIGNMENT_CENTER, 120, 15, 4, Color.BLACK)
		_canvas.draw_string(UITheme.bold(), at - Vector2(60, 0), info[0], HORIZONTAL_ALIGNMENT_CENTER, 120, 15, info[2])


func _draw_node(id: String) -> void:
	var node: Dictionary = TalentDB.NODES[id]
	var talents := player.talents
	var at := _to_screen(id)
	var radius: float = RADIUS[node["kind"]] * _zoom
	var rank := talents.rank(id)
	var reachable := talents.reachable(id)
	var tint: Color = TalentDB.BRANCHES[node["branch"]][2] if node["branch"] != "" else Color("ff6a7a")
	var face := tint.darkened(0.55) if rank > 0 else Color("1a1c26") if reachable else Color("12131a")
	# Milestones and keystones get a heavier rim.
	var rim := UITheme.GOLD if node["kind"] in ["milestone", "keystone"] else Color("8a683a")
	if rank == 0 and not reachable:
		rim = rim.darkened(0.6)
	if id == _hovered:
		_canvas.draw_circle(at, radius + 7.0 * _zoom, Color(tint, 0.25))
	if node["kind"] == "keystone":
		var diamond := PackedVector2Array([at + Vector2(0, -radius - 4), at + Vector2(radius + 4, 0), at + Vector2(0, radius + 4), at + Vector2(-radius - 4, 0)])
		_canvas.draw_colored_polygon(diamond, rim)
		_canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -radius), at + Vector2(radius, 0), at + Vector2(0, radius), at + Vector2(-radius, 0)]), face)
	else:
		_canvas.draw_circle(at, radius + 3.0 * _zoom, rim)
		_canvas.draw_circle(at, radius, face)
		if node["kind"] == "milestone":
			_canvas.draw_arc(at, radius + 6.0 * _zoom, 0.0, TAU, 32, Color(rim, 0.6), 1.5)
	var icon := ItemDB.icon(node["icon"])
	var size := radius * 1.3
	var shade := Color.WHITE if rank > 0 else Color(0.75, 0.75, 0.8) if reachable else Color(0.35, 0.35, 0.4)
	_canvas.draw_texture_rect(icon, Rect2(at - Vector2(size, size) / 2.0, Vector2(size, size)), false, shade)
	if node["max"] > 1:
		var label := "%d/%d" % [rank, node["max"]]
		_canvas.draw_string_outline(_font, at + Vector2(-20, radius + 14.0 * _zoom), label, HORIZONTAL_ALIGNMENT_CENTER, 40, 13, 4, Color.BLACK)
		_canvas.draw_string(_font, at + Vector2(-20, radius + 14.0 * _zoom), label, HORIZONTAL_ALIGNMENT_CENTER, 40, 13, UITheme.GOLD if rank >= node["max"] else UITheme.TEXT)


func _describe(id: String) -> void:
	if id == "":
		_details.text = "[color=#%s]Every path starts at the Awakened Heart in the middle. Learn a talent and its neighbours open up.\n\nGold-rimmed milestones are big. They open after 10, 20, 30, and 40 points are spent in the tree.\n\nYou earn a talent point every two levels.[/color]" % UITheme.DIM.to_html(false)
		return
	var node: Dictionary = TalentDB.NODES[id]
	var rank := player.talents.rank(id)
	var kinds := {"minor": "Talent", "major": "Major talent", "keystone": "Keystone", "milestone": "Milestone"}
	var lines: PackedStringArray = []
	var tint: Color = TalentDB.BRANCHES[node["branch"]][2] if node["branch"] != "" else Color("ff6a7a")
	lines.append("[font_size=22][color=#%s]%s[/color][/font_size]" % [UITheme.HEADING.to_html(false), node["name"]])
	var branch_name: String = TalentDB.BRANCHES[node["branch"]][0] if node["branch"] != "" else "The Heart"
	lines.append("[color=#%s]%s[/color]  [color=#%s]-  %s  -  rank %d / %d[/color]" % [tint.to_html(false), branch_name, UITheme.DIM.to_html(false), kinds[node["kind"]], rank, node["max"]])
	if rank > 0:
		lines.append("")
		for line in TalentDB.describe(id, rank):
			lines.append("[color=#%s]%s[/color]" % [UITheme.GOOD.to_html(false), line])
	if rank < node["max"]:
		lines.append("")
		lines.append("[color=#%s]%s[/color]" % [UITheme.DIM.to_html(false), "Next rank:" if rank > 0 else "Gives:"])
		for line in TalentDB.describe(id, rank + 1):
			lines.append(line)
		var reason := player.talents.blocked_reason(id)
		if reason != "":
			lines.append("")
			lines.append("[color=#%s]%s[/color]" % [UITheme.BAD.to_html(false), reason])
	_details.text = "\n".join(lines)
