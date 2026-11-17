class_name DialogueMenu
extends GameMenu
## A conversation: who is speaking (their figure, when they have a look),
## what they say one line at a time, and then the choices the player has.
## Every line goes into the Log. Opened with DialogueMenu.talk().

## What is being said: {"who", "look", "lines": [String], "choices": [[label, Callable]]}.
var talk_data: Dictionary = {}
var _index := 0
var _title: Label
var _figure: LookPreview
var _words: Label
var _choices: VBoxContainer
var _next: Button


## Opens a conversation. `choices` are [label, Callable] pairs shown after the
## last line; a choice's Callable runs after the screen closes (unless it
## starts another conversation). With no choices, "Farewell" closes it.
static func talk(player: Player, who: String, lines: Array, choices: Array = [], look: Dictionary = {}) -> void:
	var menus: Node = player.get_parent().get_node("Menus")
	var menu: DialogueMenu = menus.get_menu("dialogue")
	menu.talk_data = {"who": who, "look": look, "lines": lines, "choices": choices}
	menu._index = 0
	if menus.open_id() == "dialogue":
		menu.refresh()
	else:
		menus.open("dialogue")


func _build() -> void:
	_title = UITheme.heading("", 24)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	content.add_child(row)
	_figure = LookPreview.new()
	_figure.custom_minimum_size = Vector2(200, 250)
	_figure.zoom = 3.0
	row.add_child(_figure)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	right.custom_minimum_size = Vector2(500, 0)
	row.add_child(right)
	var speech := UITheme.inset_panel()
	right.add_child(speech)
	_words = UITheme.label("", 17, UITheme.TEXT)
	_words.autowrap_mode = TextServer.AUTOWRAP_WORD
	_words.custom_minimum_size = Vector2(480, 130)
	speech.add_child(_words)
	_next = UITheme.primary_button("Go on", func() -> void:
		_index += 1
		refresh()
	, 180.0)
	right.add_child(_next)
	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 6)
	right.add_child(_choices)


func refresh() -> void:
	if talk_data.is_empty():
		return
	var lines: Array = talk_data["lines"]
	_title.text = str(talk_data["who"]).to_upper()
	var look: Dictionary = talk_data.get("look", {})
	_figure.visible = not look.is_empty()
	if not look.is_empty():
		_figure.show_look(look)
	_index = clampi(_index, 0, maxi(lines.size() - 1, 0))
	var line: String = str(lines[_index]) if not lines.is_empty() else ""
	# Lines in brackets are told, not spoken: no quotation marks.
	_words.text = line.trim_prefix("[").trim_suffix("]") if line.begins_with("[") else "\"%s\"" % line
	Chronicle.say(get_tree(), "speech", str(talk_data["who"]) if not line.begins_with("[") else "", _words.text.trim_prefix("\"").trim_suffix("\""))
	var last := _index >= lines.size() - 1
	_next.visible = not last
	for child in _choices.get_children():
		child.queue_free()
	if not last:
		return
	var choices: Array = talk_data.get("choices", [])
	if choices.is_empty():
		choices = [["Farewell", Callable()]]
	for choice: Array in choices:
		var action: Callable = choice[1]
		var button := UITheme.button(choice[0], func() -> void:
			var before := talk_data
			if action.is_valid():
				action.call()
			# Close unless the choice started another conversation.
			if talk_data == before:
				player.get_parent().get_node("Menus").close()
		, 480.0)
		_choices.add_child(button)
	if _choices.get_child_count() > 0:
		(_choices.get_child(0) as Button).grab_focus.call_deferred()
