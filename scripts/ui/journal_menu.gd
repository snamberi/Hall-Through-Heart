class_name JournalMenu
extends GameMenu
## The journal (J): active quests with their progress, and what has been done.

var _cards: VBoxContainer
var _summary: Label


func _build() -> void:
	var title := UITheme.heading("JOURNAL", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	_cards = VBoxContainer.new()
	_cards.add_theme_constant_override("separation", 10)
	content.add_child(_cards)
	_summary = UITheme.label("", 14, UITheme.DIM)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD
	_summary.custom_minimum_size = Vector2(680.0, 40.0)
	content.add_child(_summary)
	player.quests.changed.connect(refresh_if_open)


func refresh() -> void:
	var quests := player.quests
	for child in _cards.get_children():
		child.queue_free()
	if quests.active.is_empty():
		_cards.add_child(UITheme.label("No active quests. Wardens at the Sanctuary and at camps have work.", 16, UITheme.DIM))
	for quest in quests.active:
		var card := UITheme.inset_panel()
		card.custom_minimum_size = Vector2(680.0, 0.0)
		_cards.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		card.add_child(row)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_theme_constant_override("separation", 3)
		row.add_child(text)
		var heading := UITheme.heading(quest["title"], 18)
		if quest.get("story", false):
			heading.text += "   (story)"
		text.add_child(heading)
		var body := UITheme.label(quest["text"], 13, UITheme.DIM)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD
		body.custom_minimum_size = Vector2(520.0, 0.0)
		text.add_child(body)
		var objective: Dictionary = quest["objective"]
		text.add_child(UITheme.label("%s   %d / %d" % [QuestDB.describe_objective(objective), quest["progress"], objective["count"]], 15))
		text.add_child(UITheme.label("Reward: " + ", ".join(QuestDB.describe_rewards(quest["rewards"])), 14, UITheme.GOOD))
		if not quest.get("story", false):
			var abandon := UITheme.button("Abandon", quests.abandon.bind(quest), 110.0)
			abandon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(abandon)
	var places: PackedStringArray = []
	for tile in quests.discovered:
		places.append(TerrainTiles.display_name(tile))
	_summary.text = "Story quests completed: %d of %d.      Discovered: %s." % [quests.completed.size(), QuestDB.STORY.size(), ", ".join(places) if not places.is_empty() else "nothing yet"]
