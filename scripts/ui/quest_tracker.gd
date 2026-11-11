extends Control
## The short list of active quests on the game screen, under the minimap.

var _player: Player


func setup(player: Player) -> void:
	_player = player
	player.quests.changed.connect(queue_redraw)
	GameSettings.changed.connect(queue_redraw)


func _draw() -> void:
	if _player == null:
		return
	var font := UITheme.get_theme().default_font
	var bold := UITheme.bold()
	# Sit just under the minimap, or at the top when it is hidden.
	var y := 190.0 if GameSettings.show_minimap else 14.0
	var width := size.x
	for quest in _player.quests.active.slice(0, 4):
		var objective: Dictionary = quest["objective"]
		var line := "%s  %d/%d" % [QuestDB.describe_objective(objective), quest["progress"], objective["count"]]
		for text: Array in [[quest["title"], bold, 14, UITheme.HEADING], [line, font, 13, UITheme.TEXT]]:
			draw_string_outline(text[1], Vector2(0, y), text[0], HORIZONTAL_ALIGNMENT_RIGHT, width, text[2], 4, Color.BLACK)
			draw_string(text[1], Vector2(0, y), text[0], HORIZONTAL_ALIGNMENT_RIGHT, width, text[2], text[3])
			y += 17.0
		y += 6.0
