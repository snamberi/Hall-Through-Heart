class_name WardrobeMenu
extends GameMenu
## Changing how the character looks: colours, and looks earned through
## achievements.

var _preview: CharacterPreview
var _rows: Dictionary = {}
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
	for part: Array in [["skin", "Skin", Appearance.SKIN_TONES], ["hair", "Hair", Appearance.HAIR], ["clothes", "Clothes", Appearance.CLOTHES], ["trousers", "Trousers", Appearance.TROUSERS]]:
		box.add_child(UITheme.heading(part[1], 17))
		var row := Swatches.create(part[2], int(player.appearance.get(part[0], 0)))
		var key: String = part[0]
		row.picked.connect(func(index: int) -> void:
			player.set_appearance({key: index})
			refresh()
		)
		box.add_child(row)
		_rows[key] = row
	_note = UITheme.label("", 13, UITheme.DIM)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD
	_note.custom_minimum_size = Vector2(320, 40)
	box.add_child(_note)
	var right := UITheme.inset_panel()
	right.custom_minimum_size = Vector2(320, 440)
	columns.add_child(right)
	_looks = VBoxContainer.new()
	_looks.add_theme_constant_override("separation", 6)
	right.add_child(_looks)


func refresh() -> void:
	var codex: Codex = player.get_parent().get_node("Codex")
	var unlocked := codex.skins()
	var current: String = player.appearance.get("look", "wanderer")
	_note.text = "Colours apply to the Wanderer look. Other looks set their own." if current != "wanderer" else "Pick colours for your wanderer."
	for child in _looks.get_children():
		child.queue_free()
	_looks.add_child(UITheme.heading("Looks", 17))
	for id: String in Appearance.LOOKS:
		var look: Dictionary = Appearance.LOOKS[id]
		var open := id in unlocked
		var button := UITheme.button(("> " if id == current else "") + look["name"] + ("" if open else "  (locked)"), func() -> void:
			player.set_appearance({"look": id})
			refresh()
		, 290.0)
		button.disabled = not open
		_looks.add_child(button)
		var text := UITheme.label(look["text"], 12, UITheme.DIM)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD
		text.custom_minimum_size = Vector2(290, 0)
		_looks.add_child(text)
