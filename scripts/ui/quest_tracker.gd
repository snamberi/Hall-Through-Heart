extends Control
## The short list of quests on the game screen, under the minimap: the
## ones tracked in the Quest Book (or the next story quests), then any
## warden jobs.

var _player: Player
var _book: QuestBook


func setup(player: Player) -> void:
	_player = player
	player.quests.changed.connect(queue_redraw)
	GameSettings.changed.connect(queue_redraw)


func _process(_delta: float) -> void:
	if Engine.get_process_frames() % 30 == 0:
		queue_redraw()


## What to show: [title, [[objective text, have, need], ...], tracked].
func _lines() -> Array:
	var result: Array = []
	if _book == null:
		_book = _player.get_parent().get_node_or_null("QuestBook")
	if _book:
		var ids: Array = _book.tracked.duplicate()
		var chosen := not ids.is_empty()
		if ids.is_empty():
			for quest in QuestBookDB.all():
				if quest["chapter"] == "main" and _book.is_open(quest["id"]):
					ids.append(quest["id"])
				if ids.size() >= 2:
					break
		for id: String in ids:
			var quest := QuestBookDB.find(id)
			if quest.is_empty() or _book.is_done(id):
				continue
			var steps: Array = []
			for objective: Dictionary in quest["objectives"]:
				steps.append([_book.describe(objective), _book.progress(objective), _book.goal(objective)])
			result.append([quest["title"], steps.slice(0, 3), chosen])
	for quest in _player.quests.active.slice(0, 2):
		var objective: Dictionary = quest["objective"]
		result.append([quest["title"], [[QuestDB.describe_objective(objective), quest["progress"], objective["count"]]], false])
	return result


## A panel under the minimap: each quest's title by a diamond (filled gold
## when you chose to track it), and its steps with tick boxes and counts.
func _draw() -> void:
	if _player == null:
		return
	if GameSettings.tracker_mode == "off":
		return
	var entries := _lines().slice(0, 4)
	if entries.is_empty():
		return
	# Compact: each quest is one line, its title and how many steps are done.
	var compact := GameSettings.tracker_mode == "compact"
	var font := UITheme.get_theme().default_font
	var bold := UITheme.bold()
	const WIDTH := 262.0
	const LINE := 19.0
	var height := 10.0
	for entry: Array in entries:
		height += 22.0 + (0.0 if compact else (entry[1] as Array).size() * LINE + 6.0)
	var top := 202.0 if GameSettings.show_minimap else 14.0
	var panel := Rect2(size.x - WIDTH, top, WIDTH, height)
	draw_style_box(UITheme.tooltip_box(), panel)
	var y := top + 8.0
	for entry: Array in entries:
		var marker := Vector2(panel.position.x + 14.0, y + 9.0)
		var diamond := PackedVector2Array([marker + Vector2(0, -6), marker + Vector2(6, 0), marker + Vector2(0, 6), marker + Vector2(-6, 0)])
		draw_colored_polygon(diamond, UITheme.GOLD if entry[2] else Color(0.12, 0.13, 0.18))
		draw_polyline(diamond + PackedVector2Array([diamond[0]]), UITheme.GOLD, 1.5)
		draw_string_outline(bold, Vector2(panel.position.x + 26.0, y + 15.0), entry[0], HORIZONTAL_ALIGNMENT_LEFT, WIDTH - 34.0, 15, 3, Color(0, 0, 0, 0.7))
		draw_string(bold, Vector2(panel.position.x + 26.0, y + 15.0), entry[0], HORIZONTAL_ALIGNMENT_LEFT, WIDTH - (78.0 if compact else 34.0), 15, UITheme.HEADING)
		if compact:
			var met := (entry[1] as Array).filter(func(step: Array) -> bool: return step[1] >= step[2]).size()
			var tally := "%d / %d" % [met, (entry[1] as Array).size()]
			var tally_width := font.get_string_size(tally, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			draw_string(font, Vector2(panel.end.x - 10.0 - tally_width, y + 15.0), tally, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UITheme.GOLD)
			y += 22.0
			continue
		y += 22.0
		for step: Array in entry[1]:
			var done: bool = step[1] >= step[2]
			var box := Rect2(panel.position.x + 14.0, y + 3.0, 11.0, 11.0)
			draw_rect(box, Color(0.05, 0.06, 0.09))
			draw_rect(box, Color("8a683a") if not done else UITheme.GOOD, false, 1.5)
			if done:
				draw_polyline(PackedVector2Array([box.position + Vector2(2, 6), box.position + Vector2(5, 9), box.position + Vector2(10, 1)]), UITheme.GOOD, 2.0)
			var color := UITheme.DIM if done else UITheme.TEXT
			var count := "%d / %d" % [mini(step[1], step[2]), step[2]]
			var count_width := font.get_string_size(count, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			draw_string_outline(font, Vector2(panel.position.x + 32.0, y + 13.0), step[0], HORIZONTAL_ALIGNMENT_LEFT, WIDTH - 50.0 - count_width, 14, 3, Color(0, 0, 0, 0.6))
			draw_string(font, Vector2(panel.position.x + 32.0, y + 13.0), step[0], HORIZONTAL_ALIGNMENT_LEFT, WIDTH - 50.0 - count_width, 14, color)
			draw_string(font, Vector2(panel.end.x - 10.0 - count_width, y + 13.0), count, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UITheme.GOOD if done else UITheme.GOLD)
			y += LINE
		y += 6.0
