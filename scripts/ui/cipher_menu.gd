class_name CipherMenu
extends GameMenu
## The Benefactor's journal: a page written in a shifted alphabet (every
## letter moved on the same number of places). Turn the dial (two rows of
## letters, the written one over what it stands for) until the page reads,
## then say so.

## Saint Lull's, which knows the key and what reading it unlocks.
var lull: SaintLull
var _shift := 0
var _page: Label
var _reading: Label
var _dial: Label
var _turn: Label
var _verdict: Label


func _build() -> void:
	var title := UITheme.heading("THE BENEFACTOR'S JOURNAL", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var hint := UITheme.label("\"Every letter walks on the same number of steps. Walk them back. It begins as every true story does: THE.\"", 14, UITheme.DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	hint.custom_minimum_size = Vector2(820, 0)
	content.add_child(hint)
	var written := UITheme.inset_panel()
	content.add_child(written)
	_page = UITheme.label("", 16, Color("c8b890"))
	_page.autowrap_mode = TextServer.AUTOWRAP_WORD
	_page.custom_minimum_size = Vector2(820, 96)
	written.add_child(_page)
	# The dial: the written letters over what they stand for at this turn.
	var dial_row := HBoxContainer.new()
	dial_row.alignment = BoxContainer.ALIGNMENT_CENTER
	dial_row.add_theme_constant_override("separation", 12)
	content.add_child(dial_row)
	dial_row.add_child(UITheme.button("<", func() -> void: _turn_by(-1), 48.0))
	var dial_panel := UITheme.inset_panel()
	dial_row.add_child(dial_panel)
	_dial = UITheme.label("", 15, UITheme.TEXT)
	_dial.add_theme_font_override("font", UITheme.body_bold())
	_dial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dial.custom_minimum_size = Vector2(620, 44)
	dial_panel.add_child(_dial)
	dial_row.add_child(UITheme.button(">", func() -> void: _turn_by(1), 48.0))
	_turn = UITheme.label("", 15, UITheme.GOLD)
	_turn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_turn)
	var read := UITheme.inset_panel()
	content.add_child(read)
	_reading = UITheme.label("", 16, UITheme.TEXT)
	_reading.autowrap_mode = TextServer.AUTOWRAP_WORD
	_reading.custom_minimum_size = Vector2(820, 96)
	read.add_child(_reading)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	content.add_child(buttons)
	buttons.add_child(UITheme.primary_button("It reads true", _check, 220.0))
	_verdict = UITheme.label("", 15, UITheme.DIM)
	_verdict.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_verdict)


func _turn_by(step: int) -> void:
	_shift = posmod(_shift + step, 26)
	_verdict.text = ""
	Audio.play_note("ui_click", 1.0 + _shift * 0.02, -10.0)
	refresh()


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event.is_pressed():
		return
	if event.is_action("ui_left"):
		_turn_by(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action("ui_right"):
		_turn_by(1)
		get_viewport().set_input_as_handled()


func refresh() -> void:
	if lull == null:
		return
	var key := lull.journal_key()
	if lull.journal_solved:
		_shift = key
	var written := SaintLull.shift_text(SaintLull.JOURNAL, key)
	_page.text = written
	_reading.text = SaintLull.shift_text(written, -_shift)
	var top := ""
	var bottom := ""
	for i in 26:
		var letter := String.chr(65 + i)
		top += letter + " "
		bottom += SaintLull.shift_text(letter, -_shift) + " "
	_dial.text = top.strip_edges() + "\n" + bottom.strip_edges()
	_turn.text = "Steps back: %d" % _shift
	if lull.journal_solved:
		_verdict.text = "The page reads true. The stash below the desk is open."
		_verdict.add_theme_color_override("font_color", UITheme.GOOD)


func _check() -> void:
	if lull == null:
		return
	if _shift == lull.journal_key():
		lull.journal_read()
		Audio.play("pickup", -2.0)
		refresh()
	else:
		_verdict.text = "Not yet. The words are still nonsense."
		_verdict.add_theme_color_override("font_color", UITheme.BAD)
