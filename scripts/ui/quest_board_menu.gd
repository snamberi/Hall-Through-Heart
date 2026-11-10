class_name QuestBoardMenu
extends GameMenu
## The work a warden has on offer.

var _note: Label
var _cards: VBoxContainer
var _message: Label


func _build() -> void:
	var title := UITheme.heading("WARDEN'S BOARD", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	_note = UITheme.label("", 14, UITheme.DIM)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_note)
	_cards = VBoxContainer.new()
	_cards.add_theme_constant_override("separation", 10)
	content.add_child(_cards)
	_message = UITheme.label("", 14, UITheme.BAD)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_message)
	player.quests.changed.connect(refresh_if_open)


func refresh() -> void:
	var quests := player.quests
	quests.refresh_offers()
	_note.text = "You hold %d of %d quests. New work is posted in %d min. Rewards are paid the moment a job is done." % [quests.active.size(), QuestDB.MAX_ACTIVE, ceili(quests.offers_change_in() / 60.0)]
	for child in _cards.get_children():
		child.queue_free()
	if quests.offers.is_empty():
		_cards.add_child(UITheme.label("Nothing left on the board. Come back later.", 16, UITheme.DIM))
	for quest in quests.offers:
		var card := UITheme.inset_panel()
		card.custom_minimum_size = Vector2(640.0, 0.0)
		_cards.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		card.add_child(row)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_theme_constant_override("separation", 3)
		row.add_child(text)
		text.add_child(UITheme.heading(quest["title"], 18))
		text.add_child(UITheme.label(QuestDB.describe_objective(quest["objective"]), 15))
		text.add_child(UITheme.label("Reward: " + ", ".join(QuestDB.describe_rewards(quest["rewards"])), 14, UITheme.GOOD))
		var accept := UITheme.button("Accept", func() -> void:
			_message.text = quests.accept(quest)
			refresh()
		, 110.0)
		accept.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		accept.disabled = not quests.has_room()
		row.add_child(accept)
