class_name WaystoneMenu
extends GameMenu
## Travelling between waking waystones.

var _list: VBoxContainer
var _message: Label


func _build() -> void:
	var title := UITheme.heading("WAYSTONES", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var note := UITheme.label("Step through to any stone you have woken. The farther, the dearer.", 14, UITheme.DIM)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(note)
	var panel := UITheme.inset_panel()
	panel.custom_minimum_size = Vector2(640, 420)
	content.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)
	_message = UITheme.label("", 14, UITheme.BAD)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_message)


func refresh() -> void:
	var stones: Waystones = player.get_parent().get_node("Waystones")
	for child in _list.get_children():
		child.queue_free()
	var keys: Array = stones.known.keys()
	var here := (player.get_parent().get_node("World") as World).world_to_cell(player.global_position)
	keys.sort_custom(func(a: String, b: String) -> bool: return Vector2(stones.cell_of(a) - here).length() < Vector2(stones.cell_of(b) - here).length())
	for key: String in keys:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(UITheme.heading(stones.known[key]["name"], 17))
		var distance := roundi(Vector2(stones.cell_of(key) - here).length())
		info.add_child(UITheme.label("You are here" if key == stones.current else "%d tiles away" % distance, 13, UITheme.DIM))
		row.add_child(info)
		var button := UITheme.button("Travel  (%d gold)" % stones.fee(key), func() -> void:
			var problem := stones.travel(key)
			if problem == "":
				player.get_parent().get_node("Menus").close()
			else:
				_message.text = problem
		, 170.0)
		button.disabled = key == stones.current
		row.add_child(button)
		_list.add_child(row)
