class_name SystemMenu
extends GameMenu
## Save, start over, quit, and a reminder of the controls.

const CONTROLS: Array[Array] = [
	["Move", "W A S D or arrow keys"],
	["Attack", "Left mouse button (aims at the cursor)"],
	["Dodge", "Space or Shift"],
	["Abilities", "1  2  3  4"],
	["Inventory", "E"],
	["Attributes", "C"],
	["Talents", "K"],
	["Menu", "M or Tab"],
	["Debug screen", "F3"],
]

var _status: Label
var _new_game: Button
var _armed := false


func _build() -> void:
	content.add_child(UITheme.heading("System", 28))
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 56)
	content.add_child(columns)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	columns.add_child(left)
	left.add_child(UITheme.button("Resume", func() -> void: SystemMenu.close_menu(self), 220.0))
	left.add_child(UITheme.button("Save now", _save, 220.0))
	_new_game = UITheme.button("New game", _on_new_game, 220.0)
	left.add_child(_new_game)
	left.add_child(UITheme.button("Quit game", _quit, 220.0))
	_status = UITheme.label("", 14, UITheme.DIM)
	_status.custom_minimum_size = Vector2(220.0, 44.0)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	left.add_child(_status)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	columns.add_child(right)
	right.add_child(UITheme.heading("Controls"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 4)
	right.add_child(grid)
	for row in CONTROLS:
		grid.add_child(UITheme.label(row[0], 15, UITheme.DIM))
		grid.add_child(UITheme.label(row[1], 15))


func refresh() -> void:
	_armed = false
	_new_game.text = "New game"
	_status.text = "The game saves by itself every 30 seconds and when you quit."


func _save() -> void:
	SaveGame.save_now()
	_status.text = "Saved."


func _on_new_game() -> void:
	if not _armed:
		_armed = true
		_new_game.text = "Click again to erase everything"
		_status.text = "This deletes your character and world. It cannot be undone."
		return
	SaveGame.delete_save()
	get_tree().paused = false
	get_tree().reload_current_scene()


func _quit() -> void:
	SaveGame.save_now()
	get_tree().quit()


## Finds the menu manager above a screen and closes it.
static func close_menu(from: Node) -> void:
	var node := from.get_parent()
	while node and not node.has_method("close"):
		node = node.get_parent()
	if node:
		node.close()
