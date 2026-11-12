class_name WardrobeMenu
extends GameMenu
## Changing how the character looks: every part of their appearance except
## their race, and whole looks earned through achievements.

var _preview: CharacterPreview
var _editor: AppearanceEditor
var _looks: VBoxContainer
var _note: Label


func _build() -> void:
	var title := UITheme.heading("WARDROBE", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	content.add_child(columns)
	var left := UITheme.inset_panel()
	left.custom_minimum_size = Vector2(300, 440)
	columns.add_child(left)
	_preview = CharacterPreview.new()
	_preview.setup(player)
	_preview.custom_minimum_size = Vector2(280, 420)
	left.add_child(_preview)
	var middle := UITheme.inset_panel()
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
	_note = UITheme.label("", 13, UITheme.DIM)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD
	_note.custom_minimum_size = Vector2(440, 36)
	box.add_child(_note)
	var right := UITheme.inset_panel()
	right.custom_minimum_size = Vector2(300, 440)
	columns.add_child(right)
	_looks = VBoxContainer.new()
	_looks.add_theme_constant_override("separation", 6)
	right.add_child(_looks)


func refresh() -> void:
	var codex: Codex = player.get_parent().get_node("Codex")
	var unlocked := codex.skins()
	var current: String = player.appearance.get("look", "wanderer")
	var race: String = Appearance.RACES[Appearance.resolved(player.appearance)["race"]]["name"]
	_note.text = "%s. Colours apply to the Wanderer look; other looks set their own." % race if current != "wanderer" else "%s. Change anything you like; only your race is for life." % race
	_editor.set_appearance(player.appearance)
	for child in _looks.get_children():
		child.queue_free()
	_looks.add_child(UITheme.heading("Looks", 17))
	for id: String in Appearance.LOOKS:
		var look: Dictionary = Appearance.LOOKS[id]
		var open := id in unlocked
		var button := UITheme.button(("> " if id == current else "") + look["name"] + ("" if open else "  (locked)"), func() -> void:
			player.set_appearance({"look": id})
			refresh()
		, 270.0)
		button.disabled = not open
		_looks.add_child(button)
		var text := UITheme.label(look["text"], 12, UITheme.DIM)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD
		text.custom_minimum_size = Vector2(270, 0)
		_looks.add_child(text)
