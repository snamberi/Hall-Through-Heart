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


func _lines() -> Array:
	var result: Array = []
	if _book == null:
		_book = _player.get_parent().get_node_or_null("QuestBook")
	if _book:
		var ids: Array = _book.tracked.duplicate()
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
			var steps: PackedStringArray = []
			for objective: Dictionary in quest["objectives"]:
				var have := _book.progress(objective)
				var need := _book.goal(objective)
				if have < need:
					steps.append("%s  %d/%d" % [_book.describe(objective), have, need])
			result.append([quest["title"], steps.slice(0, 2)])
	for quest in _player.quests.active.slice(0, 2):
		var objective: Dictionary = quest["objective"]
		result.append([quest["title"], ["%s  %d/%d" % [QuestDB.describe_objective(objective), quest["progress"], objective["count"]]]])
	return result


func _draw() -> void:
	if _player == null:
		return
	var font := UITheme.get_theme().default_font
	var bold := UITheme.bold()
	# Sit just under the minimap, or at the top when it is hidden.
	var y := 202.0 if GameSettings.show_minimap else 14.0
	var width := size.x
	for entry: Array in _lines().slice(0, 4):
		draw_string_outline(bold, Vector2(0, y), entry[0], HORIZONTAL_ALIGNMENT_RIGHT, width, 14, 4, Color.BLACK)
		draw_string(bold, Vector2(0, y), entry[0], HORIZONTAL_ALIGNMENT_RIGHT, width, 14, UITheme.HEADING)
		y += 17.0
		for line: String in entry[1]:
			draw_string_outline(font, Vector2(0, y), line, HORIZONTAL_ALIGNMENT_RIGHT, width, 13, 4, Color.BLACK)
			draw_string(font, Vector2(0, y), line, HORIZONTAL_ALIGNMENT_RIGHT, width, 13, UITheme.TEXT)
			y += 16.0
		y += 6.0
