class_name SettingsMenu
extends GameMenu
## The settings screen inside the game (from the pause menu or the wheel).

func _build() -> void:
	var panel := SettingsPanel.new()
	panel.closed.connect(func() -> void:
		var node := get_parent()
		while node and not node.has_method("open"):
			node = node.get_parent()
		if node:
			node.open("pause")
	)
	content.add_child(panel)
