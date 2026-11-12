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
	var note := UITheme.label("Tame pets with a Taming Treat: use it beside a small creature, or a monster beaten to its last legs. Pets grow as you fight and when fed. Press H to ride a mount.", 14, UITheme.DIM)
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


## A pet's face: a frame of its sheet.
func _portrait(pet: Dictionary) -> Texture2D:
	var atlas := AtlasTexture.new()
	if pet["kind"] == "critter":
		atlas.atlas = Critter.SHEET
		atlas.region = Rect2(Critter.KINDS.find(pet["species"]) * Critter.FRAMES * 24, 0, 24, 24)
	else:
		atlas.atlas = EnemyDB.sheet(pet["species"])
		atlas.region = Rect2(20, 22, 56, 56)
	return atlas


func refresh() -> void:
	var pets := player.pets
	for child in _list.get_children() + _mounts.get_children():
		child.queue_free()
	_list.add_child(UITheme.heading("Pets (%d / %d)" % [pets.pets.size(), Pets.MAX_PETS], 18))
	if pets.pets.is_empty():
		_list.add_child(UITheme.label("No pets yet.", 15, UITheme.DIM))
	for index in pets.pets.size():
		var pet: Dictionary = pets.pets[index]
		var following := index == pets.active
		var card := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color("16241a") if following else Color("151823")
		style.border_color = Color("6fd67a") if following else Color("3a3e50")
		style.set_border_width_all(2 if following else 1)
		style.set_content_margin_all(8)
		card.add_theme_stylebox_override("panel", style)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		card.add_child(row)
		# Its picture.
		var frame := Panel.new()
		frame.custom_minimum_size = Vector2(72, 72)
		var frame_style := StyleBoxFlat.new()
		frame_style.bg_color = Color("0b0e17")
		frame_style.border_color = Color("403020")
		frame_style.set_border_width_all(2)
		frame.add_theme_stylebox_override("panel", frame_style)
		var picture := TextureRect.new()
		picture.texture = _portrait(pet)
		picture.position = Vector2(6, 6)
		picture.size = Vector2(60, 60)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		frame.add_child(picture)
		row.add_child(frame)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(box)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 8)
		box.add_child(head)
		var name_field := LineEdit.new()
		name_field.text = pet["name"]
		name_field.custom_minimum_size = Vector2(170, 30)
		name_field.tooltip_text = "Type a new name and press Enter"
		name_field.text_submitted.connect(func(text: String) -> void: pets.rename(index, text))
		name_field.focus_exited.connect(func() -> void: pets.rename(index, name_field.text))
		head.add_child(name_field)
		var species: String = pet["species"].capitalize() if pet["kind"] == "critter" else EnemyDB.ENEMIES[pet["species"]]["name"]
		head.add_child(UITheme.label("%s   level %d" % [species, pet["level"]], 14, UITheme.GOLD))
		# Growth toward the next level.
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(380, 8)
		bar.max_value = pets.xp_to_next(pet)
		bar.value = int(pet["xp"]) if int(pet["level"]) < Pets.MAX_LEVEL else bar.max_value
		var trough := StyleBoxFlat.new()
		trough.bg_color = Color(0.03, 0.035, 0.06)
		trough.border_color = Color("2e4a30")
		trough.set_border_width_all(1)
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color("6fd67a")
		bar.add_theme_stylebox_override("background", trough)
		bar.add_theme_stylebox_override("fill", fill)
		box.add_child(bar)
		var text := UITheme.label(pets.describe(pet), 13, UITheme.GOOD)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD
		text.custom_minimum_size = Vector2(380, 0)
		box.add_child(text)
		var buttons := HBoxContainer.new()
		buttons.add_theme_constant_override("separation", 6)
		box.add_child(buttons)
		buttons.add_child(UITheme.button("Send home" if following else "Call to follow", func() -> void:
			pets.set_active(index if index != pets.active else -1)
			refresh()
		, 140.0))
		buttons.add_child(UITheme.button("Feed", func() -> void:
			_message.text = pets.feed(index)
			refresh()
		, 90.0))
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
