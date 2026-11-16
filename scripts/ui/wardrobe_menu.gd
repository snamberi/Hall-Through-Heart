class_name WardrobeMenu
extends GameMenu
## Changing how the character looks: every part of their appearance except
## their race, and whole looks earned through achievements. The figure sits
## in the middle of its niche with Turn and Show helmet beside it; Revert
## puts back how you looked when the screen opened. Each look is a card
## with a picture of you wearing it, and what earns it if it is locked.

var _preview: CharacterPreview
var _editor: AppearanceEditor
var _looks: VBoxContainer
var _note: Label
var _helmet: CheckBox
var _revert: Button
## How the character looked when the screen opened, for Revert.
var _opening: Dictionary = {}


func _build() -> void:
	var title := UITheme.heading("WARDROBE", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 12)
	content.add_child(columns)

	var left := PanelContainer.new()
	left.add_theme_stylebox_override("panel", UITheme.card("card", 10))
	columns.add_child(left)
	var left_box := VBoxContainer.new()
	left_box.add_theme_constant_override("separation", 6)
	left.add_child(left_box)
	_preview = CharacterPreview.new()
	_preview.setup(player)
	_preview.custom_minimum_size = Vector2(270, 360)
	left_box.add_child(_preview)
	var turn_row := HBoxContainer.new()
	turn_row.add_theme_constant_override("separation", 6)
	turn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	left_box.add_child(turn_row)
	turn_row.add_child(UITheme.button("<  Turn", _preview.turn, 110.0))
	turn_row.add_child(UITheme.button("Turn  >", _preview.turn, 110.0))
	_helmet = CheckBox.new()
	_helmet.text = "Show helmet"
	_helmet.toggled.connect(func(on: bool) -> void:
		player.show_helmet = on
		SaveGame.request_save()
	)
	left_box.add_child(_helmet)
	_revert = UITheme.button("Revert to how I looked", func() -> void:
		player.set_appearance(_opening.duplicate())
		refresh()
	, 260.0)
	_revert.tooltip_text = "Puts back your look from when you opened the Wardrobe."
	left_box.add_child(_revert)

	var middle := PanelContainer.new()
	middle.add_theme_stylebox_override("panel", UITheme.card("card", 10))
	columns.add_child(middle)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	middle.add_child(box)
	_editor = AppearanceEditor.new()
	_editor.allow_race = false
	_editor.appearance = player.appearance.duplicate()
	_editor.changed.connect(func(look: Dictionary) -> void:
		var changes := look.duplicate()
		# Race and the achievement look are not the editor's to change.
		changes.erase("race")
		changes.erase("look")
		player.set_appearance(changes)
		refresh()
	)
	box.add_child(_editor)
	_note = UITheme.label("", 14, UITheme.DIM)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD
	_note.custom_minimum_size = Vector2(440, 0)
	box.add_child(_note)

	var right := PanelContainer.new()
	right.add_theme_stylebox_override("panel", UITheme.card("card", 10))
	right.custom_minimum_size = Vector2(320, 0)
	columns.add_child(right)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(300, 460)
	right.add_child(scroll)
	_looks = VBoxContainer.new()
	_looks.add_theme_constant_override("separation", 6)
	_looks.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_looks)
	visibility_changed.connect(func() -> void:
		if is_visible_in_tree():
			_opening = player.appearance.duplicate()
	)


func refresh() -> void:
	if _opening.is_empty():
		_opening = player.appearance.duplicate()
	var codex: Codex = player.get_parent().get_node("Codex")
	var unlocked := codex.skins()
	var current: String = player.appearance.get("look", "wanderer")
	var race: String = Appearance.RACES[Appearance.resolved(player.appearance)["race"]]["name"]
	_note.text = "%s. Colours apply to the Wanderer look; other looks set their own." % race if current != "wanderer" else "%s. Change anything you like; only your race is for life." % race
	_editor.set_appearance(player.appearance)
	_helmet.set_pressed_no_signal(player.show_helmet)
	_revert.disabled = player.appearance == _opening
	for child in _looks.get_children():
		child.queue_free()
	_looks.add_child(UITheme.heading("Looks", 18))
	for id: String in Appearance.LOOKS:
		_looks.add_child(_look_card(id, id == current, id == "wanderer" or id in unlocked))


## A look: you wearing it, its name, and Wear, Worn or what earns it.
func _look_card(id: String, worn: bool, open: bool) -> Control:
	var look: Dictionary = Appearance.LOOKS[id]
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.card("card_selected" if worn else ("card" if open else "card_dim"), 6))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)
	var picture := LookPreview.new()
	picture.custom_minimum_size = Vector2(64, 78)
	picture.framed = false
	picture.zoom = 1.5
	var dressed := player.appearance.duplicate()
	dressed["look"] = id
	picture.show_look(dressed)
	picture.modulate = Color.WHITE if open else Color(0.35, 0.35, 0.42)
	row.add_child(picture)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 2)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(words)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	words.add_child(top)
	top.add_child(UITheme.strong(look["name"], 16, UITheme.GOLD if worn else (UITheme.TEXT if open else UITheme.DIM)))
	if worn:
		top.add_child(UITheme.badge("Worn", "gold"))
	elif not open:
		top.add_child(StateMark.make("locked", 14))
	if open:
		words.add_child(UITheme.paragraph(_short(look["text"]), 200.0, 14, UITheme.DIM))
		if not worn:
			words.add_child(UITheme.button("Wear", func() -> void:
				player.set_appearance({"look": id})
				refresh()
			, 100.0))
	else:
		var achievement := _achievement_for(id)
		words.add_child(UITheme.paragraph("Earn %s: %s" % [achievement.get("name", "an achievement"), achievement.get("text", "")], 200.0, 14, UITheme.DIM))
		words.add_child(UITheme.button("See in Codex", func() -> void:
			CodexMenu.requested_tab = "achievements"
			Events.screen_requested.emit("codex")
		, 130.0))
	return card


static func _achievement_for(look_id: String) -> Dictionary:
	for achievement: Dictionary in Codex.ACHIEVEMENTS:
		if achievement.get("skin", "") == look_id:
			return achievement
	return {}


## A look's text without the "From the achievement ..." part.
static func _short(text: String) -> String:
	var cut := text.find(" From the achievement")
	return text if cut < 0 else text.substr(0, cut)
