class_name PauseMenu
extends GameMenu
## The pause menu (Esc): resume, settings, save, and back to the title.

var _status: Label


func _build() -> void:
	var title := UITheme.heading("Paused", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var world := UITheme.label("", 15, UITheme.DIM)
	world.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	world.name = "World"
	content.add_child(world)
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	content.add_child(buttons)
	buttons.add_child(UITheme.button("Resume", _close, 300.0))
	buttons.add_child(UITheme.button("Settings", func() -> void: _manager().open("settings"), 300.0))
	buttons.add_child(UITheme.button("Save", _save, 300.0))
	buttons.add_child(UITheme.button("Save & Quit to Title", _quit, 300.0))
	_status = UITheme.label("", 14, UITheme.DIM)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_status)


func refresh() -> void:
	var meta := SaveGame.get_section("meta")
	(content.get_node("World") as Label).text = "%s  -  %s" % [meta.get("name", "World"), Difficulty.display_name()]
	_status.text = "The game saves by itself every 30 seconds."


func _manager() -> Node:
	var node := get_parent()
	while node and not node.has_method("close"):
		node = node.get_parent()
	return node


func _close() -> void:
	close_menus(self)


## Finds the menu manager above a screen and closes it.
static func close_menus(from: Node) -> void:
	var node := from.get_parent()
	while node and not node.has_method("close"):
		node = node.get_parent()
	if node:
		node.close()


func _save() -> void:
	SaveGame.save_now()
	_status.text = "Saved."


## Saves and goes back to the title screen.
func _quit() -> void:
	SaveGame.save_now()
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
