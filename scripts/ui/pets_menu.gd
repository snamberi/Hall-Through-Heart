class_name PetsMenu
extends GameMenu
## Pets and mounts: who follows you, their names and levels, and the
## steeds you can call.

var _list: VBoxContainer
var _mounts: VBoxContainer
var _message: Label


func _build() -> void:
	var title := UITheme.heading("PETS & MOUNTS", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var note := UITheme.label("Tame pets with a Taming Treat: use it beside a small creature, or a monster beaten to its last legs. Press H to ride a mount.", 14, UITheme.DIM)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD
	note.custom_minimum_size = Vector2(900, 40)
	content.add_child(note)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	content.add_child(columns)
	for heading: String in ["Pets", "Mounts"]:
		var panel := UITheme.inset_panel()
		panel.custom_minimum_size = Vector2(540 if heading == "Pets" else 380, 420)
		columns.add_child(panel)
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		panel.add_child(scroll)
		var box := VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_theme_constant_override("separation", 8)
		scroll.add_child(box)
		if heading == "Pets":
			_list = box
		else:
			_mounts = box
	_message = UITheme.label("", 14, UITheme.BAD)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_message)


func refresh() -> void:
	var pets := player.pets
	for child in _list.get_children() + _mounts.get_children():
		child.queue_free()
	_list.add_child(UITheme.heading("Pets (%d / %d)" % [pets.pets.size(), Pets.MAX_PETS], 18))
	if pets.pets.is_empty():
		_list.add_child(UITheme.label("No pets yet.", 15, UITheme.DIM))
	for index in pets.pets.size():
		var pet: Dictionary = pets.pets[index]
		var card := UITheme.inset_panel()
		var box := VBoxContainer.new()
		card.add_child(box)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 8)
		box.add_child(head)
		var name_field := LineEdit.new()
		name_field.text = pet["name"]
		name_field.custom_minimum_size = Vector2(200, 30)
		name_field.text_submitted.connect(func(text: String) -> void: pets.rename(index, text))
		name_field.focus_exited.connect(func() -> void: pets.rename(index, name_field.text))
		head.add_child(name_field)
		var species: String = pet["species"].capitalize() if pet["kind"] == "critter" else EnemyDB.ENEMIES[pet["species"]]["name"]
		head.add_child(UITheme.label("%s  -  level %d" % [species, pet["level"]], 14, UITheme.DIM))
		box.add_child(UITheme.label(pets.describe(pet), 13, UITheme.GOOD))
		var buttons := HBoxContainer.new()
		buttons.add_theme_constant_override("separation", 6)
		box.add_child(buttons)
		var follow := UITheme.button("Following" if index == pets.active else "Call to follow", func() -> void:
			pets.set_active(index if index != pets.active else -1)
			refresh()
		, 150.0)
		buttons.add_child(follow)
		buttons.add_child(UITheme.button("Release", func() -> void:
			pets.release(index)
			refresh()
		, 100.0))
		_list.add_child(card)
	_mounts.add_child(UITheme.heading("Mounts", 18))
	var owned := {}
	for item in player.inventory.items:
		if item and item.definition().has("mount"):
			owned[item.definition()["mount"]] = true
	for id: String in Mount.MOUNTS:
		var data: Dictionary = Mount.MOUNTS[id]
		_mounts.add_child(UITheme.heading(data["name"] + ("" if owned.has(id) else "  (not owned)"), 15))
		var text := UITheme.label(data["text"], 13, UITheme.TEXT if owned.has(id) else UITheme.DIM)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD
		text.custom_minimum_size = Vector2(340, 0)
		_mounts.add_child(text)
		if owned.has(id):
			_mounts.add_child(UITheme.button("Dismount" if player.mount_id == id else "Ride", func() -> void:
				if player.mount_id == id:
					player.dismount()
				else:
					_message.text = player.ride(id)
				refresh()
			, 120.0))
