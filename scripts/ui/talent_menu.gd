class_name TalentMenu
extends GameMenu
## The talent tree on a canvas: drag to look around, scroll to zoom. Click
## a talent to choose it; the panel on the right says what it gives, what
## it needs and what it costs, and only its Learn button spends a point,
## so no drag or stray click can spend one.

const RADIUS := {"minor": 15.0, "major": 20.0, "keystone": 24.0, "milestone": 26.0}

var _points: Label
var _canvas: Control
var _details: RichTextLabel
var _learn: Button
var _reason: Label
var _zoom_label: Label
var _selected := ""
var _offset := Vector2.ZERO
var _zoom := 0.7
var _dragging := false
var _dragged := 0.0
var _hovered := ""
var _font: Font
var _icons: Dictionary = {}


func _build() -> void:
	_font = UITheme.get_theme().default_font
	content.add_theme_constant_override("separation", 8)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 20)
	content.add_child(top)
	top.add_child(UITheme.heading("TALENTS", 28))
	_points = UITheme.strong("", 17, UITheme.GOLD)
	_points.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_points.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_points)
	var fit := UITheme.button("Fit tree", _fit_tree, 96.0)
	fit.tooltip_text = "Pull back until the whole tree is in view."
	top.add_child(fit)
	top.add_child(UITheme.button("Centre heart", func() -> void:
		_offset = Vector2.ZERO
		_zoom = 0.8
		refresh()
	, 120.0))
	top.add_child(UITheme.button("−", func() -> void: _set_zoom(_zoom * 0.85), 36.0))
	_zoom_label = UITheme.label("", 15)
	_zoom_label.custom_minimum_size.x = 50.0
	_zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zoom_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_zoom_label)
	top.add_child(UITheme.button("+", func() -> void: _set_zoom(_zoom * 1.18), 36.0))
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 12)
	content.add_child(columns)
	var frame := UITheme.inset_panel()
	columns.add_child(frame)
	_canvas = Control.new()
	_canvas.custom_minimum_size = Vector2(820, 520)
	_canvas.clip_contents = true
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.draw.connect(_draw_tree)
	_canvas.gui_input.connect(_on_input)
	frame.add_child(_canvas)
	var side := UITheme.inset_panel()
	columns.add_child(side)
	var side_box := VBoxContainer.new()
	side_box.add_theme_constant_override("separation", 8)
	side.add_child(side_box)
	_details = RichTextLabel.new()
	_details.bbcode_enabled = true
	_details.scroll_active = true
	_details.custom_minimum_size = Vector2(300, 400)
	_details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UITheme.font_size(_details, 15, "normal_font_size")
	_details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side_box.add_child(_details)
	_reason = UITheme.reason("", 300.0)
	side_box.add_child(_reason)
	_learn = UITheme.primary_button("Learn", _learn_selected, 300.0)
	side_box.add_child(_learn)
	side_box.add_child(UITheme.label("Drag to look round  ·  scroll to zoom", 14, UITheme.DIM))
	player.talents.changed.connect(refresh_if_open)


func refresh() -> void:
	_points.text = "%d point%s to spend  ·  %d spent" % [player.leveling.talent_points, "" if player.leveling.talent_points == 1 else "s", player.talents.spent_points()]
	_points.add_theme_color_override("font_color", UITheme.GOLD if player.leveling.talent_points > 0 else UITheme.DIM)
	_zoom_label.text = "%d%%" % roundi(_zoom * 100.0)
	_describe(_hovered if _hovered != "" else _selected)
	_refresh_learn()
	_canvas.queue_redraw()


func _set_zoom(value: float) -> void:
	_zoom = clampf(value, 0.18, 1.6)
	refresh()


## Pulls back and centres until every talent is in view.
func _fit_tree() -> void:
	var bounds := Rect2()
	var first := true
	for id: String in TalentDB.NODES:
		var at := TalentDB.position(id)
		bounds = Rect2(at, Vector2.ZERO) if first else bounds.expand(at)
		first = false
	bounds = bounds.grow(40.0)
	var room := _canvas.size if _canvas.size.x > 10.0 else _canvas.custom_minimum_size
	_zoom = clampf(minf(room.x / bounds.size.x, (room.y - 40.0) / bounds.size.y), 0.18, 1.6)
	_offset = -bounds.get_center()
	refresh()


func _refresh_learn() -> void:
	if _selected == "":
		_learn.disabled = true
		_learn.text = "Learn"
		_reason.text = "Click a talent to choose it."
		_reason.add_theme_color_override("font_color", UITheme.DIM)
		return
	var node: Dictionary = TalentDB.NODES[_selected]
	var rank := player.talents.rank(_selected)
	var reason := player.talents.blocked_reason(_selected)
	_learn.disabled = reason != ""
	if rank >= int(node["max"]):
		_learn.text = "Learned in full"
	else:
		_learn.text = "Learn rank %d  ·  1 point" % (rank + 1) if node["max"] > 1 else "Learn  ·  1 point"
	_reason.text = reason
	_reason.add_theme_color_override("font_color", Color("e8a070"))


func _learn_selected() -> void:
	if _selected != "" and player.talents.learn(_selected):
		Audio.play("level_up", -12.0, 0.1)
	refresh()


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
				# A click that did not drag chooses the talent; it never spends.
				if _dragged < 6.0:
					var id := _node_at(event.position)
					if id != "":
						_selected = id
						Audio.play("ui_click", -10.0, 0.05)
						refresh()
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_zoom = clampf(_zoom * (1.12 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.89), 0.18, 1.6)
			_zoom_label.text = "%d%%" % roundi(_zoom * 100.0)
			_canvas.queue_redraw()
	elif event is InputEventMouseMotion:
		if _dragging:
			_dragged += event.relative.length()
			_offset += event.relative / _zoom
			_canvas.queue_redraw()
		var id := _node_at(event.position)
		if id != _hovered:
			_hovered = id
			_describe(id if id != "" else _selected)
			_canvas.queue_redraw()


## One link between two talents, tidily: along the ring when both sit at
## the same distance from the heart, bowed outward when the jump is long (so
## it does not cut across the tree), straight otherwise; it stops at each
## node's rim rather than running over its picture.
func _draw_link(a_id: String, b_id: String, color: Color, width: float) -> void:
	var centre := _to_screen("awakened_heart")
	var a := _to_screen(a_id)
	var b := _to_screen(b_id)
	var rim := 15.0 * _zoom
	var ra := (a - centre).length()
	var rb := (b - centre).length()
	var points := PackedVector2Array()
	if ra > rim * 2.0 and absf(ra - rb) < TalentDB.STEP * 0.3 * _zoom:
		# Round the ring.
		var radius := (ra + rb) / 2.0
		var from := (a - centre).angle()
		var turn := wrapf((b - centre).angle() - from, -PI, PI)
		var trim := rim / radius
		var steps := maxi(int(absf(turn) * radius / 6.0), 4)
		for k in steps + 1:
			var angle := from + signf(turn) * trim + (turn - signf(turn) * trim * 2.0) * k / steps
			points.append(centre + Vector2.from_angle(angle) * radius)
	elif a.distance_to(b) > TalentDB.STEP * 1.6 * _zoom:
		# A long jump bows outward, away from the heart.
		var middle := (a + b) / 2.0
		var out := (middle - centre).normalized() if middle.distance_to(centre) > 1.0 else (b - a).orthogonal().normalized()
		var bend := middle + out * a.distance_to(b) * 0.22
		for k in 17:
			var t := k / 16.0
			points.append(a.lerp(bend, t).lerp(bend.lerp(b, t), t))
		points[0] = points[0].move_toward(points[1], rim)
		points[-1] = points[-1].move_toward(points[-2], rim)
	else:
		points.append(a.move_toward(b, rim))
		points.append(b.move_toward(a, rim))
	if points.size() >= 2:
		_canvas.draw_polyline(points, color, width, true)


func _draw_tree() -> void:
	_canvas.draw_rect(Rect2(Vector2.ZERO, _canvas.size), Color("130e0a"))
	var talents := player.talents
	# Faint rings for each distance out.
	for ring in range(1, 10):
		_canvas.draw_arc(_to_screen("awakened_heart"), ring * TalentDB.STEP * _zoom, 0.0, TAU, 96, Color(1, 1, 1, 0.03), 1.0)
	# Locked paths first and faint, then those that open now, then the
	# learned ones in gold on top, so the way taken reads clearly.
	for pass_index in 3:
		for edge: Array in TalentDB.edges():
			var both: bool = talents.has(edge[0]) and talents.has(edge[1])
			var either: bool = talents.has(edge[0]) or talents.has(edge[1])
			var tier := 2 if both else 1 if either else 0
			if tier != pass_index:
				continue
			var color := UITheme.GOLD if both else Color(0.62, 0.55, 0.42, 0.85) if either else Color(0.24, 0.25, 0.31)
			var width := (3.5 if both else 2.0 if either else 1.4) * maxf(_zoom, 0.5)
			if both:
				_draw_link(edge[0], edge[1], Color(0.05, 0.04, 0.02), width + 2.0)
			_draw_link(edge[0], edge[1], color, width)
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
	# Can be learned now: a breathing ring in the branch's colour.
	if rank < int(node["max"]) and reachable and player.leveling.talent_points > 0:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 260.0)
		_canvas.draw_arc(at, radius + 6.0 * _zoom, 0.0, TAU, 32, Color(tint.lightened(0.3), 0.45 + 0.4 * pulse), 2.0)
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
	# Out of reach for now: a small padlock.
	if rank == 0 and not reachable and _zoom >= 0.9:
		var lock_size := 12.0
		_canvas.draw_texture_rect(UITheme.lock_texture(), Rect2(at + Vector2(radius * 0.45, radius * 0.25), Vector2(lock_size, lock_size)), false, Color(0.8, 0.8, 0.86, 0.9))
	# Learned in full: a gold tick.
	if rank >= int(node["max"]):
		_canvas.draw_texture_rect(UITheme.tick_texture(), Rect2(at + Vector2(radius * 0.4, -radius - 4.0), Vector2(14, 14)), false)
	if id == _selected:
		_canvas.draw_arc(at, radius + 10.0 * _zoom + 2.0, 0.0, TAU, 40, Color.WHITE, 2.0)
	if node["max"] > 1:
		var label := "%d/%d" % [rank, node["max"]]
		var ink := UITheme.body_bold()
		_canvas.draw_string_outline(ink, at + Vector2(-22, radius + 16.0 * _zoom + 4.0), label, HORIZONTAL_ALIGNMENT_CENTER, 44, 14, 4, Color.BLACK)
		_canvas.draw_string(ink, at + Vector2(-22, radius + 16.0 * _zoom + 4.0), label, HORIZONTAL_ALIGNMENT_CENTER, 44, 14, UITheme.GOLD if rank >= node["max"] else UITheme.TEXT)


func _describe(id: String) -> void:
	if id == "":
		_details.text = "[color=#%s]Click a talent to choose it, then press Learn.\n\nEvery path starts at the Awakened Heart in the middle. Learn a talent and its neighbours open up. A breathing ring marks what can be learned now; a padlock what is out of reach.\n\nGold-rimmed milestones are big. They open after 10, 20, 30, and 40 points are spent in the tree.\n\nYou earn a talent point every two levels.[/color]" % UITheme.DIM.to_html(false)
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
		var needs: PackedStringArray = []
		for other: String in TalentDB.neighbours(id):
			if player.talents.has(other):
				needs.clear()
				break
			needs.append(TalentDB.NODES[other]["name"])
		if rank == 0 and not needs.is_empty() and not player.talents.reachable(id):
			lines.append("")
			lines.append("[color=#%s]Needs a learned neighbour: %s[/color]" % [UITheme.DIM.to_html(false), " or ".join(needs.slice(0, 3))])
	_details.text = "\n".join(lines)


func _process(_delta: float) -> void:
	# The rings round what can be learned breathe while the tree is open.
	if is_visible_in_tree() and player.leveling.talent_points > 0:
		_canvas.queue_redraw()
