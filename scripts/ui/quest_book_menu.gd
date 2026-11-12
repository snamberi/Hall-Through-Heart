class_name QuestBookMenu
extends GameMenu
## The Quest Book: chapters down the left, every quest as a node on a large
## map in the middle (drag to move, scroll or the buttons to zoom), and the
## chosen quest's story, objectives and rewards on the right.

const STEP := Vector2(66.0, 84.0)
const NODE := 44.0
const BIG := 58.0
const ZOOM_MIN := 0.25
const ZOOM_MAX := 1.6
## Chapters laid out to the right and left of the Main Story, in order.
const RIGHT: Array[String] = ["combat", "magic", "classes", "equipment", "raids", "side"]
const LEFT: Array[String] = ["crafting", "mining", "farming", "fishing", "hunting", "exploration"]
const PURPLE := Color(0.62, 0.42, 0.98)
const LOCKED := Color(0.32, 0.31, 0.38)

static var _layout: Dictionary = {}
static var _roots: Dictionary = {}
static var _bounds: Dictionary = {}

var _book: QuestBook
var _canvas: Control
var _chapter_buttons: Dictionary = {}
var _strip_buttons: Dictionary = {}
var _zoom_label: Label
var _progress_label: Label
var _progress_bar: ProgressBar
var _details: VBoxContainer
var _picture: TextureRect
var _picture_back: PanelContainer
var _title: Label
var _chapter_label: Label
var _text: Label
var _objectives: VBoxContainer
var _rewards: HBoxContainer
var _status: Label
var _track: Button

var _chapter := "main"
var _selected := ""
var _hover := ""
var _zoom := 0.6
var _center := Vector2.ZERO
var _dragging := false
var _drag_moved := 0.0
var _textures: Dictionary = {}


func _build() -> void:
	content.add_theme_constant_override("separation", 8)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	content.add_child(row)

	# Chapters.
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 4)
	left.custom_minimum_size = Vector2(192, 0)
	row.add_child(left)
	var title := UITheme.heading("QUEST BOOK", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(title)
	for chapter in QuestBookDB.CHAPTERS:
		var button := Button.new()
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(192, 37)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.icon = QuestBookDB.icon_texture(chapter["icon"])
		button.expand_icon = false
		button.add_theme_constant_override("icon_max_width", 22)
		button.add_theme_font_size_override("font_size", 13)
		var id: String = chapter["id"]
		button.pressed.connect(func() -> void: _focus_chapter(id))
		left.add_child(button)
		_chapter_buttons[id] = button

	# The map.
	var map_frame := UITheme.inset_panel()
	row.add_child(map_frame)
	_canvas = Control.new()
	_canvas.custom_minimum_size = Vector2(660, 540)
	_canvas.clip_contents = true
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_canvas.draw.connect(_draw_map)
	_canvas.gui_input.connect(_on_map_input)
	_canvas.mouse_exited.connect(func() -> void:
		_hover = ""
		_canvas.queue_redraw()
	)
	map_frame.add_child(_canvas)

	# Details.
	var right := UITheme.inset_panel()
	right.custom_minimum_size = Vector2(278, 0)
	row.add_child(right)
	_details = VBoxContainer.new()
	_details.add_theme_constant_override("separation", 6)
	right.add_child(_details)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	_details.add_child(top)
	_picture_back = PanelContainer.new()
	_picture_back.custom_minimum_size = Vector2(84, 84)
	top.add_child(_picture_back)
	_picture = TextureRect.new()
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_picture.custom_minimum_size = Vector2(76, 76)
	_picture_back.add_child(_picture)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(heading)
	_title = UITheme.heading("", 19)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD
	_title.custom_minimum_size = Vector2(160, 0)
	heading.add_child(_title)
	_chapter_label = UITheme.label("", 14, PURPLE.lightened(0.25))
	heading.add_child(_chapter_label)
	_text = UITheme.label("", 14)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	_text.custom_minimum_size = Vector2(256, 0)
	_details.add_child(_text)
	_details.add_child(_rule())
	_details.add_child(_purple_heading("Objectives:"))
	_objectives = VBoxContainer.new()
	_objectives.add_theme_constant_override("separation", 3)
	_details.add_child(_objectives)
	_details.add_child(_rule())
	_details.add_child(_purple_heading("Rewards:"))
	_rewards = HBoxContainer.new()
	_rewards.add_theme_constant_override("separation", 10)
	_details.add_child(_rewards)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_details.add_child(spacer)
	_status = UITheme.label("", 14, UITheme.DIM)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	_status.custom_minimum_size = Vector2(256, 0)
	_details.add_child(_status)
	_track = UITheme.button("Track on screen", func() -> void:
		if _selected != "":
			_book.toggle_track(_selected)
			_show_details()
	, 256.0)
	_details.add_child(_track)

	# The bar along the bottom.
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	content.add_child(bar)
	bar.add_child(_small_button("◎", "Centre on the open quests", _recentre))
	bar.add_child(_small_button("−", "Zoom out", func() -> void: _set_zoom(_zoom / 1.25, _canvas.size / 2.0)))
	_zoom_label = UITheme.label("", 15)
	_zoom_label.custom_minimum_size = Vector2(56, 0)
	_zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(_zoom_label)
	bar.add_child(_small_button("+", "Zoom in", func() -> void: _set_zoom(_zoom * 1.25, _canvas.size / 2.0)))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(24, 0)
	bar.add_child(gap)
	bar.add_child(_small_button("<", "Previous chapter", func() -> void: _step_chapter(-1)))
	for chapter in QuestBookDB.CHAPTERS:
		var button := Button.new()
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(36, 36)
		button.icon = QuestBookDB.icon_texture(chapter["icon"])
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.add_theme_constant_override("icon_max_width", 24)
		button.tooltip_text = chapter["name"]
		var id: String = chapter["id"]
		button.pressed.connect(func() -> void: _focus_chapter(id))
		bar.add_child(button)
		_strip_buttons[id] = button
	bar.add_child(_small_button(">", "Next chapter", func() -> void: _step_chapter(1)))
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(fill)
	var progress_box := VBoxContainer.new()
	progress_box.custom_minimum_size = Vector2(220, 0)
	bar.add_child(progress_box)
	_progress_label = UITheme.label("", 15)
	progress_box.add_child(_progress_label)
	_progress_bar = ProgressBar.new()
	_progress_bar.show_percentage = false
	_progress_bar.custom_minimum_size = Vector2(220, 10)
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = PURPLE
	fill_style.set_corner_radius_all(3)
	_progress_bar.add_theme_stylebox_override("fill", fill_style)
	var back_style := StyleBoxFlat.new()
	back_style.bg_color = Color(0.06, 0.06, 0.1)
	back_style.border_color = Color("8a683a")
	back_style.set_border_width_all(1)
	back_style.set_corner_radius_all(3)
	_progress_bar.add_theme_stylebox_override("background", back_style)
	progress_box.add_child(_progress_bar)


func _rule() -> ColorRect:
	var rule := ColorRect.new()
	rule.color = Color(0.4, 0.3, 0.55, 0.6)
	rule.custom_minimum_size = Vector2(256, 1)
	return rule


func _purple_heading(text: String) -> Label:
	var label := UITheme.heading(text, 16)
	label.add_theme_color_override("font_color", PURPLE.lightened(0.2))
	return label


func _small_button(text: String, tip: String, action: Callable) -> Button:
	var button := UITheme.button(text, action, 38.0)
	button.custom_minimum_size = Vector2(38, 38)
	button.tooltip_text = tip
	return button


func refresh() -> void:
	if _book == null:
		_book = player.get_parent().get_node("QuestBook")
		_book.changed.connect(refresh_if_open)
		_ensure_layout()
		_focus_chapter(_first_open_chapter(), false)
	for chapter in QuestBookDB.CHAPTERS:
		var id: String = chapter["id"]
		var button: Button = _chapter_buttons[id]
		button.text = "  %s   %d/%d" % [chapter["name"], _book.count_done(id), _book.count_all(id)]
		button.set_pressed_no_signal(id == _chapter)
		_strip_buttons[id].set_pressed_no_signal(id == _chapter)
		var has_open := QuestBookDB.all().any(func(q: Dictionary) -> bool: return q["chapter"] == id and _book.is_open(q["id"]))
		button.add_theme_color_override("font_color", UITheme.HEADING if has_open else UITheme.DIM)
	var done := _book.count_done()
	var total := _book.count_all()
	_progress_label.text = "Progress: %d%%        %d / %d" % [roundi(100.0 * done / maxf(total, 1)), done, total]
	_progress_bar.max_value = total
	_progress_bar.value = done
	_zoom_label.text = "%d%%" % roundi(_zoom * 100.0)
	if _selected == "" or QuestBookDB.find(_selected).is_empty():
		_selected = _first_open_in(_chapter)
	_show_details()
	_canvas.queue_redraw()


func _first_open_chapter() -> String:
	for chapter in QuestBookDB.CHAPTERS:
		if _first_open_in(chapter["id"]) != "" and _book.state(_first_open_in(chapter["id"])) == "open":
			return chapter["id"]
	return "main"


func _first_open_in(chapter: String) -> String:
	var fallback := ""
	for quest in QuestBookDB.all():
		if quest["chapter"] != chapter:
			continue
		if fallback == "":
			fallback = quest["id"]
		if _book and _book.is_open(quest["id"]):
			return quest["id"]
	return fallback


# --- layout: every chapter is a tree hanging off a long spine

func _ensure_layout() -> void:
	if not _layout.is_empty():
		return
	var children := {}
	var by_chapter := {}
	for quest in QuestBookDB.all():
		var chapter: String = quest["chapter"]
		if not by_chapter.has(chapter):
			by_chapter[chapter] = []
		by_chapter[chapter].append(quest["id"])
		children[quest["id"]] = []
	for chapter: String in by_chapter:
		var ids: Array = by_chapter[chapter]
		_roots[chapter] = ids[0]
		for id: String in ids.slice(1):
			var parent: String = ids[0]
			for need: String in QuestBookDB.find(id)["requires"]:
				if QuestBookDB.find(need)["chapter"] == chapter:
					parent = need
					break
			children[parent].append(id)
	var widths := {}
	var measure := func(id: String, self_ref: Callable) -> float:
		var total := 0.0
		for child: String in children[id]:
			total += self_ref.call(child, self_ref)
		widths[id] = maxf(total, 1.0)
		return widths[id]
	var place := func(id: String, left: float, depth: int, direction: float, self_ref: Callable) -> void:
		_layout[id] = Vector2((left + widths[id] / 2.0) * STEP.x, direction * depth * STEP.y)
		var cursor := left
		for child: String in children[id]:
			self_ref.call(child, cursor, depth + 1, direction, self_ref)
			cursor += widths[child]
	# Each chapter: its first branches alternate up and down from the spine.
	var spans := {}
	for chapter: String in by_chapter:
		var root: String = _roots[chapter]
		measure.call(root, measure)
		var up := 0.0
		var down := 0.0
		for index in (children[root] as Array).size():
			var child: String = children[root][index]
			if chapter == "main" or index % 2 == 0:
				up += widths[child]
			else:
				down += widths[child]
		spans[chapter] = [up, down, maxf(maxf(up, down), 2.0)]
	var lay_chapter := func(chapter: String, center: float) -> void:
		var root: String = _roots[chapter]
		_layout[root] = Vector2(center * STEP.x, 0.0)
		var up_left: float = center - spans[chapter][0] / 2.0
		var down_left: float = center - spans[chapter][1] / 2.0
		for index in (children[root] as Array).size():
			var child: String = children[root][index]
			if chapter == "main" or index % 2 == 0:
				place.call(child, up_left, 1, -1.0, place)
				up_left += widths[child]
			else:
				place.call(child, down_left, 1, 1.0, place)
				down_left += widths[child]
	lay_chapter.call("main", 0.0)
	var cursor: float = spans["main"][2] / 2.0 + 2.0
	for chapter in RIGHT:
		cursor += spans[chapter][2] / 2.0
		lay_chapter.call(chapter, cursor)
		cursor += spans[chapter][2] / 2.0 + 2.0
	cursor = -spans["main"][2] / 2.0 - 2.0
	for chapter in LEFT:
		cursor -= spans[chapter][2] / 2.0
		lay_chapter.call(chapter, cursor)
		cursor -= spans[chapter][2] / 2.0 + 2.0
	for quest in QuestBookDB.all():
		var chapter: String = quest["chapter"]
		var point: Vector2 = _layout[quest["id"]]
		if not _bounds.has(chapter):
			_bounds[chapter] = Rect2(point, Vector2.ZERO)
		_bounds[chapter] = (_bounds[chapter] as Rect2).expand(point)


# --- moving around

func _to_screen(point: Vector2) -> Vector2:
	return (point - _center) * _zoom + _canvas.size / 2.0


func _to_map(point: Vector2) -> Vector2:
	return (point - _canvas.size / 2.0) / _zoom + _center


func _set_zoom(value: float, around: Vector2) -> void:
	var before := _to_map(around)
	_zoom = clampf(value, ZOOM_MIN, ZOOM_MAX)
	_center += before - _to_map(around)
	_zoom_label.text = "%d%%" % roundi(_zoom * 100.0)
	_canvas.queue_redraw()


func _focus_chapter(chapter: String, select: bool = true) -> void:
	_chapter = chapter
	var bounds: Rect2 = _bounds.get(chapter, Rect2())
	_center = bounds.get_center()
	var fit := minf(_canvas.custom_minimum_size.x / maxf(bounds.size.x + 160.0, 1.0), _canvas.custom_minimum_size.y / maxf(bounds.size.y + 160.0, 1.0))
	_zoom = clampf(fit, 0.5, 0.95)
	if select:
		_selected = _first_open_in(chapter)
	if _book:
		refresh()


func _step_chapter(step: int) -> void:
	var ids: Array = QuestBookDB.CHAPTERS.map(func(c: Dictionary) -> String: return c["id"])
	_focus_chapter(ids[posmod(ids.find(_chapter) + step, ids.size())])


func _recentre() -> void:
	var open := _first_open_in(_chapter)
	if open != "":
		_selected = open
		_center = _layout[open]
		_zoom = maxf(_zoom, 0.7)
		refresh()


func _node_at(point: Vector2) -> String:
	var map_point := _to_map(point)
	var reach := BIG / 2.0 + 4.0
	for quest in QuestBookDB.all():
		var at: Vector2 = _layout[quest["id"]]
		if absf(at.x - map_point.x) < reach and absf(at.y - map_point.y) < reach:
			var size := (BIG if quest["big"] else NODE) / 2.0 + 2.0
			if absf(at.x - map_point.x) < size and absf(at.y - map_point.y) < size:
				return quest["id"]
	return ""


func _on_map_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_WHEEL_UP and button.pressed:
			_set_zoom(_zoom * 1.12, button.position)
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN and button.pressed:
			_set_zoom(_zoom / 1.12, button.position)
		elif button.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			if button.pressed:
				_dragging = true
				_drag_moved = 0.0
			else:
				_dragging = false
				if _drag_moved < 6.0 and button.button_index == MOUSE_BUTTON_LEFT:
					var id := _node_at(button.position)
					if id != "":
						_selected = id
						_chapter = QuestBookDB.find(id)["chapter"]
						refresh()
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _dragging:
			_center -= motion.relative / _zoom
			_drag_moved += motion.relative.length()
			_canvas.queue_redraw()
		else:
			var id := _node_at(motion.position)
			if id != _hover:
				_hover = id
				_canvas.queue_redraw()


# --- drawing

func _texture(spec: Dictionary) -> Texture2D:
	var key := str(spec)
	if not _textures.has(key):
		_textures[key] = QuestBookDB.icon_texture(spec)
	return _textures[key]


func _draw_map() -> void:
	var size := _canvas.size
	_canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.05, 0.09))
	# A faint grid of dots, moving with the map.
	var grid := 32.0 * _zoom
	if grid > 6.0:
		var origin := _to_screen(Vector2.ZERO)
		var start := Vector2(fposmod(origin.x, grid), fposmod(origin.y, grid))
		var y := start.y
		while y < size.y:
			var x := start.x
			while x < size.x:
				_canvas.draw_rect(Rect2(Vector2(x, y), Vector2(1.5, 1.5)), Color(0.35, 0.3, 0.5, 0.18))
				x += grid
			y += grid
	if _layout.is_empty():
		return
	var font := UITheme.get_theme().default_font
	var bold := UITheme.bold()
	# The spine joining every chapter.
	var xs: Array = _roots.values().map(func(id: String) -> float: return _layout[id].x)
	_canvas.draw_line(_to_screen(Vector2(xs.min(), 0)), _to_screen(Vector2(xs.max(), 0)), Color(PURPLE, 0.55), maxf(3.0 * _zoom, 1.5))
	# Lines from each quest to what it needs: elbows down the tree, straight
	# lines for extra needs.
	var line_width := maxf(2.5 * _zoom, 1.2)
	for quest in QuestBookDB.all():
		var to := _to_screen(_layout[quest["id"]])
		var first := true
		for need: String in quest["requires"]:
			var from_quest := QuestBookDB.find(need)
			if from_quest["chapter"] != quest["chapter"]:
				continue
			var from := _to_screen(_layout[need])
			if not _visible_segment(from, to, size):
				first = false
				continue
			var state := _book.state(quest["id"])
			var color := Color(0.95, 0.78, 0.45, 0.95) if state == "done" else Color(PURPLE, 0.9) if state == "open" else Color(0.42, 0.38, 0.55, 0.85)
			if quest["chapter"] != _chapter:
				color.a *= 0.4
			if first and absf(from.x - to.x) > 1.0:
				var mid := from.y + (to.y - from.y) * 0.5
				_canvas.draw_polyline(PackedVector2Array([from, Vector2(from.x, mid), Vector2(to.x, mid), to]), color, line_width)
			else:
				_canvas.draw_line(from, to, color, line_width if first else line_width * 0.6)
			first = false
	# The quests themselves.
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 300.0)
	for quest in QuestBookDB.all():
		var id: String = quest["id"]
		var center := _to_screen(_layout[id])
		var half := (BIG if quest["big"] else NODE) * _zoom / 2.0
		if center.x < -half or center.y < -half or center.x > size.x + half or center.y > size.y + half:
			continue
		var state := _book.state(id)
		var faded: bool = quest["chapter"] != _chapter
		var rect := Rect2(center - Vector2(half, half), Vector2(half, half) * 2.0)
		var border := Color(0.98, 0.8, 0.38) if state == "done" else PURPLE.lerp(Color(0.88, 0.75, 1.0), pulse) if state == "open" else Color(0.44, 0.42, 0.52)
		if faded:
			border.a = 0.5
		if state == "open" and not faded:
			var glow := StyleBoxFlat.new()
			glow.bg_color = Color(PURPLE, 0.0)
			glow.shadow_color = Color(PURPLE, 0.35 + 0.25 * pulse)
			glow.shadow_size = int(8.0 * _zoom + 3.0)
			glow.set_corner_radius_all(int(8.0 * _zoom))
			_canvas.draw_style_box(glow, rect)
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.17, 0.13, 0.26) if state == "open" else Color(0.18, 0.15, 0.1) if state == "done" else Color(0.11, 0.11, 0.15)
		if faded:
			box.bg_color = box.bg_color.darkened(0.4)
		box.border_color = border
		box.set_border_width_all(maxi(roundi(2.5 * _zoom), 1) + (1 if quest["big"] else 0))
		box.set_corner_radius_all(int((10.0 if quest["big"] else 7.0) * _zoom))
		box.anti_aliasing = true
		_canvas.draw_style_box(box, rect)
		# A lighter top half, like a bevel.
		_canvas.draw_rect(Rect2(rect.position + Vector2(3, 3) * _zoom, Vector2(rect.size.x - 6.0 * _zoom, rect.size.y * 0.35)), Color(1, 1, 1, 0.05 if not faded else 0.02))
		var tint := QuestBookDB.icon_tint(quest["icon"])
		if state == "locked":
			tint = tint.darkened(0.35).lerp(Color(0.6, 0.6, 0.65), 0.25)
		if faded:
			tint.a = 0.45
		_canvas.draw_texture_rect(_texture(quest["icon"]), rect.grow(-half * 0.22), false, tint)
		if quest["big"] and not faded:
			var ring := StyleBoxFlat.new()
			ring.draw_center = false
			ring.border_color = Color(border, 0.45)
			ring.set_border_width_all(1)
			ring.set_corner_radius_all(int(12.0 * _zoom))
			_canvas.draw_style_box(ring, rect.grow(4.0 * _zoom + 1.0))
		if state == "done" and _zoom > 0.3:
			var badge := rect.position + Vector2(rect.size.x - 2.0, 2.0)
			_canvas.draw_circle(badge, 7.0 * _zoom + 2.0, Color(0.08, 0.3, 0.1))
			_canvas.draw_arc(badge, 7.0 * _zoom + 2.0, 0.0, TAU, 16, Color(0.6, 0.95, 0.5), 1.0)
			_canvas.draw_polyline(PackedVector2Array([badge + Vector2(-3.5, 0) * _zoom, badge + Vector2(-1, 3) * _zoom, badge + Vector2(4, -3.5) * _zoom]), Color(0.75, 1.0, 0.65), maxf(1.8 * _zoom, 1.0))
		elif state == "locked" and _zoom > 0.45 and not faded:
			# A little padlock in the corner.
			var lock := rect.end - Vector2(9, 9) * _zoom
			_canvas.draw_rect(Rect2(lock - Vector2(4, 2) * _zoom, Vector2(8, 6) * _zoom), Color(0.3, 0.3, 0.36))
			_canvas.draw_arc(lock - Vector2(0, 2) * _zoom, 2.6 * _zoom, PI, TAU, 8, Color(0.4, 0.4, 0.46), maxf(1.2 * _zoom, 1.0))
		if id == _selected:
			var mark := StyleBoxFlat.new()
			mark.draw_center = false
			mark.border_color = Color(1, 1, 1, 0.95)
			mark.set_border_width_all(2)
			mark.set_corner_radius_all(int(9.0 * _zoom) + 2)
			_canvas.draw_style_box(mark, rect.grow(5.0))
		elif id == _hover:
			var mark := StyleBoxFlat.new()
			mark.draw_center = false
			mark.border_color = Color(1, 1, 1, 0.5)
			mark.set_border_width_all(1)
			mark.set_corner_radius_all(int(9.0 * _zoom) + 1)
			_canvas.draw_style_box(mark, rect.grow(3.0))
	# Chapter names on little banners by their roots.
	for chapter in QuestBookDB.CHAPTERS:
		var root: String = _roots.get(chapter["id"], "")
		if root == "":
			continue
		var text: String = chapter["name"]
		var text_width := bold.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 18.0
		var at := _to_screen(_layout[root]) + Vector2(0, (BIG * _zoom / 2.0) + 8.0)
		var pill := Rect2(at - Vector2(text_width / 2.0, 0), Vector2(text_width, 20))
		var current: bool = chapter["id"] == _chapter
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.13, 0.08, 0.22, 0.95) if current else Color(0.08, 0.08, 0.12, 0.9)
		style.border_color = PURPLE if current else Color(0.35, 0.33, 0.42)
		style.set_border_width_all(1)
		style.set_corner_radius_all(9)
		_canvas.draw_style_box(style, pill)
		_canvas.draw_string(bold, pill.position + Vector2(9, 15), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UITheme.HEADING if current else UITheme.DIM)
	# The name of the quest under the mouse.
	if _hover != "":
		var quest := QuestBookDB.find(_hover)
		var at := _to_screen(_layout[_hover]) + Vector2(0, -(NODE * _zoom / 2.0) - 10.0)
		var text: String = quest["title"]
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 16.0
		var box := Rect2(at - Vector2(width / 2.0, 20), Vector2(width, 22))
		_canvas.draw_rect(box, Color(0.06, 0.05, 0.1, 0.95))
		_canvas.draw_rect(box, PURPLE, false, 1.0)
		_canvas.draw_string(font, box.position + Vector2(8, 16), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UITheme.TEXT)
	# A soft dark edge.
	for i in 4:
		_canvas.draw_rect(Rect2(Vector2(i * 3, i * 3), size - Vector2(i * 6, i * 6)), Color(0, 0, 0, 0.12), false, 3.0)


func _visible_segment(a: Vector2, b: Vector2, size: Vector2) -> bool:
	return not ((a.x < 0 and b.x < 0) or (a.y < 0 and b.y < 0) or (a.x > size.x and b.x > size.x) or (a.y > size.y and b.y > size.y))


# --- the details panel

func _show_details() -> void:
	var quest := QuestBookDB.find(_selected)
	_details.visible = not quest.is_empty()
	if quest.is_empty():
		return
	var state := _book.state(_selected)
	_picture.texture = _texture(quest["icon"])
	_picture.modulate = QuestBookDB.icon_tint(quest["icon"]) if state != "locked" else Color(0.45, 0.45, 0.5)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.1, 0.26)
	style.border_color = Color(0.95, 0.78, 0.35) if state == "done" else PURPLE
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.shadow_color = Color(PURPLE, 0.3)
	style.shadow_size = 4
	_picture_back.add_theme_stylebox_override("panel", style)
	_title.text = quest["title"]
	_chapter_label.text = QuestBookDB.chapter_name(quest["chapter"])
	_text.text = quest["text"]
	for child in _objectives.get_children() + _rewards.get_children():
		child.queue_free()
	for objective: Dictionary in quest["objectives"]:
		var have := _book.progress(objective)
		var need := _book.goal(objective)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		var tick := Control.new()
		tick.custom_minimum_size = Vector2(16, 16)
		var met := have >= need or state == "done"
		tick.draw.connect(func() -> void:
			tick.draw_rect(Rect2(1, 1, 14, 14), Color(0.06, 0.06, 0.1))
			tick.draw_rect(Rect2(1, 1, 14, 14), UITheme.GOOD if met else Color(0.5, 0.48, 0.55), false, 1.5)
			if met:
				tick.draw_polyline(PackedVector2Array([Vector2(4, 8), Vector2(7, 11), Vector2(12, 4)]), UITheme.GOOD, 2.0)
		)
		line.add_child(tick)
		var text := UITheme.label("%s (%d/%d)" % [_book.describe(objective), need if state == "done" else have, need], 14, UITheme.GOOD if met else UITheme.TEXT)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD
		text.custom_minimum_size = Vector2(228, 0)
		line.add_child(text)
		_objectives.add_child(line)
	var rewards: Dictionary = quest["rewards"]
	_rewards.add_child(_xp_chip(rewards["xp"]))
	_rewards.add_child(_reward_chip(ItemDB.icon(17), "+%d" % rewards["gold"], UITheme.GOLD))
	for entry: Array in rewards.get("items", []):
		_rewards.add_child(_reward_chip(Item.create(entry[0]).icon(), "x%d" % entry[1], UITheme.TEXT, Item.create(entry[0]).icon_tint()))
	match state:
		"done":
			_status.text = "Complete. Rewards received."
			_status.add_theme_color_override("font_color", UITheme.GOOD)
		"open":
			_status.text = "Open: it completes by itself when every objective is met."
			_status.add_theme_color_override("font_color", PURPLE.lightened(0.3))
		_:
			var needs: PackedStringArray = []
			for need: String in quest["requires"]:
				if not _book.is_done(need):
					needs.append(QuestBookDB.find(need)["title"])
			_status.text = "Locked. First finish: " + ", ".join(needs)
			_status.add_theme_color_override("font_color", UITheme.DIM)
	_track.visible = state == "open"
	_track.text = "Stop tracking" if _selected in _book.tracked else "Track on screen"


## A round purple "XP" badge and the amount.
func _xp_chip(amount: int) -> HBoxContainer:
	var chip := HBoxContainer.new()
	chip.add_theme_constant_override("separation", 3)
	var badge := Control.new()
	badge.custom_minimum_size = Vector2(22, 22)
	badge.draw.connect(func() -> void:
		badge.draw_circle(Vector2(11, 11), 10.5, Color(0.2, 0.1, 0.35))
		badge.draw_circle(Vector2(11, 11), 9.0, PURPLE)
		badge.draw_arc(Vector2(11, 11), 10.5, 0.0, TAU, 20, Color(0.85, 0.75, 1.0), 1.0)
		badge.draw_string(UITheme.bold(), Vector2(0, 15), "XP", HORIZONTAL_ALIGNMENT_CENTER, 22, 10, Color.WHITE)
	)
	chip.add_child(badge)
	chip.add_child(UITheme.label("+%d XP" % amount, 14, Color(0.8, 0.68, 1.0)))
	return chip


func _reward_chip(texture: Texture2D, text: String, color: Color, tint: Color = Color.WHITE) -> HBoxContainer:
	var chip := HBoxContainer.new()
	chip.add_theme_constant_override("separation", 3)
	var icon := TextureRect.new()
	icon.texture = texture
	icon.modulate = tint
	icon.custom_minimum_size = Vector2(20, 20)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	chip.add_child(icon)
	chip.add_child(UITheme.label(text, 14, color))
	return chip


func _process(_delta: float) -> void:
	# The open quests glow; keep them breathing while the book is open.
	if is_visible_in_tree():
		_canvas.queue_redraw()
