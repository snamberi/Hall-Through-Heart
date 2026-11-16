class_name PetsMenu
extends GameMenu
## Pets and mounts. On the left, your pets as rows (or, with none, how to
## tame the first). In the middle, the chosen pet: portrait, name, level and
## growth, what it gives, and one clear Follow / Send home action. On the
## right, every mount as a card with its picture, speed, ground it is good
## on, and either Ride or how to get it. H rides and dismounts.

const MOUNT_HOW := {
	"pony": "Sold now and then by village merchants.",
	"horse": "Sold now and then by wandering merchants.",
	"frost_elk": "Sometimes dropped by the Frostwarden, a world boss.",
	"sand_strider": "Sometimes dropped by the Sunless Prophet, a world boss.",
	"nightmare": "Sometimes dropped by the Pale Matron or the Hollow King.",
}
const PETS_WIDTH := 320.0
const DETAIL_WIDTH := 380.0
const MOUNTS_WIDTH := 410.0

var _selected := -1
var _list: VBoxContainer
var _detail: VBoxContainer
var _mounts: VBoxContainer
var _message: Label


func _build() -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(head)
	head.add_child(UITheme.heading("PETS & MOUNTS", 30))
	var ride := UITheme.key_hint("H", "Ride or dismount")
	ride.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(ride)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 12)
	content.add_child(columns)
	_list = _column(columns, PETS_WIDTH)
	_detail = _column(columns, DETAIL_WIDTH)
	_mounts = _column(columns, MOUNTS_WIDTH)
	_message = UITheme.reason("", 0.0)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_message)
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree():
			_selected = -1
			_message.text = ""
	)


func _column(parent: Control, width: float) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.card("card", 10))
	panel.custom_minimum_size = Vector2(width, 470)
	parent.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	scroll.add_child(box)
	return box


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


func _species(pet: Dictionary) -> String:
	return pet["species"].capitalize() if pet["kind"] == "critter" else EnemyDB.ENEMIES[pet["species"]]["name"]


func refresh() -> void:
	var pets := player.pets
	for child in _list.get_children() + _detail.get_children() + _mounts.get_children():
		child.queue_free()
	if _selected < 0 or _selected >= pets.pets.size():
		_selected = pets.active if pets.active >= 0 else (0 if not pets.pets.is_empty() else -1)
	_list.add_child(UITheme.heading("Pets  %d / %d" % [pets.pets.size(), Pets.MAX_PETS], 18))
	for index in pets.pets.size():
		_list.add_child(_pet_row(index))
	if pets.pets.is_empty():
		_list.add_child(UITheme.paragraph("None yet. Pets you tame are listed here.", PETS_WIDTH - 30.0, 15, UITheme.DIM))
		_empty_state()
	else:
		_inspector(_selected)
	_fill_mounts()


func _pet_row(index: int) -> Button:
	var pets := player.pets
	var pet: Dictionary = pets.pets[index]
	var chosen := index == _selected
	var button := Button.new()
	button.custom_minimum_size = Vector2(PETS_WIDTH - 28.0, 58.0)
	for state: String in ["normal", "pressed"]:
		button.add_theme_stylebox_override(state, UITheme.card("card_selected" if chosen else "card", 6))
	button.add_theme_stylebox_override("hover", UITheme.card("card_selected" if chosen else "card_hover", 6))
	button.pressed.connect(func() -> void:
		_selected = index
		refresh()
	)
	UITheme.sounds(button)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
	row.add_theme_constant_override("separation", 8)
	button.add_child(row)
	var picture := TextureRect.new()
	picture.texture = _portrait(pet)
	picture.custom_minimum_size = Vector2(44, 44)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(picture)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(words)
	words.add_child(UITheme.strong(pet["name"], 16, UITheme.GOLD if chosen else UITheme.TEXT))
	words.add_child(UITheme.label("%s  ·  level %d" % [_species(pet), pet["level"]], 14, UITheme.DIM))
	if index == pets.active:
		row.add_child(UITheme.badge("Following", "good"))
	for control: Control in row.find_children("*", "Control", true, false):
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return button


## No pets yet: the treat, the three steps, and how many treats you hold.
func _empty_state() -> void:
	var treat := Item.create("taming_treat")
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	_detail.add_child(top)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UITheme.slot("slot_hover"))
	top.add_child(frame)
	var icon := TextureRect.new()
	icon.texture = treat.icon()
	icon.modulate = treat.icon_tint()
	icon.custom_minimum_size = Vector2(56, 56)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.add_child(icon)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 0)
	top.add_child(words)
	words.add_child(UITheme.heading("Your first pet", 20))
	var have := player.inventory.count_of("taming_treat")
	words.add_child(UITheme.label("You hold %d Taming Treat%s." % [have, "" if have == 1 else "s"], 15, UITheme.GOOD if have > 0 else UITheme.DIM))
	var steps := [
		"Get a Taming Treat: cook two from 2 Wild Berries and 1 Bone (Cooking 2), or buy them from merchants.",
		"Use it beside a small creature, or a monster beaten to its last legs.",
		"It follows you, fights beside you and grows as you fight and feed it.",
	]
	for index in steps.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_detail.add_child(row)
		var number := UITheme.strong("%d" % (index + 1), 18, UITheme.GOLD)
		number.custom_minimum_size.x = 18.0
		row.add_child(number)
		row.add_child(UITheme.paragraph(steps[index], DETAIL_WIDTH - 60.0, 15, UITheme.TEXT))
	_detail.add_child(UITheme.rule())
	_detail.add_child(UITheme.label("A pet's page will look like this:", 14, UITheme.DIM))
	# A faint sample of a pet card.
	var sample := PanelContainer.new()
	sample.add_theme_stylebox_override("panel", UITheme.card("card_dim", 8))
	sample.modulate = Color(1, 1, 1, 0.55)
	_detail.add_child(sample)
	var sample_row := HBoxContainer.new()
	sample_row.add_theme_constant_override("separation", 10)
	sample.add_child(sample_row)
	var shadow := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = Critter.SHEET
	atlas.region = Rect2(0, 0, 24, 24)
	shadow.texture = atlas
	shadow.custom_minimum_size = Vector2(48, 48)
	shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sample_row.add_child(shadow)
	var sample_words := VBoxContainer.new()
	sample_row.add_child(sample_words)
	sample_words.add_child(UITheme.strong("Your pet's name", 16))
	sample_words.add_child(UITheme.label("Species  ·  level 1  ·  Following", 14, UITheme.DIM))


## The chosen pet: portrait, name, growth, gifts and what to do with it.
func _inspector(index: int) -> void:
	var pets := player.pets
	var pet: Dictionary = pets.pets[index]
	var following := index == pets.active
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	_detail.add_child(top)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UITheme.slot("slot_active" if following else "slot"))
	top.add_child(frame)
	var picture := TextureRect.new()
	picture.texture = _portrait(pet)
	picture.custom_minimum_size = Vector2(96, 96)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.add_child(picture)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 4)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(words)
	var name_field := LineEdit.new()
	name_field.text = pet["name"]
	name_field.custom_minimum_size = Vector2(0, 32)
	name_field.tooltip_text = "Type a new name and press Enter"
	name_field.text_submitted.connect(func(text: String) -> void:
		pets.rename(index, text)
		refresh()
	)
	name_field.focus_exited.connect(func() -> void: pets.rename(index, name_field.text))
	words.add_child(name_field)
	words.add_child(UITheme.label("%s  ·  level %d of %d" % [_species(pet), pet["level"], Pets.MAX_LEVEL], 15, UITheme.TEXT))
	words.add_child(UITheme.badge("Following you" if following else "At home", "good" if following else "plain"))
	# Growth.
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(DETAIL_WIDTH - 30.0, 10)
	bar.max_value = pets.xp_to_next(pet)
	bar.value = int(pet["xp"]) if int(pet["level"]) < Pets.MAX_LEVEL else bar.max_value
	_detail.add_child(bar)
	_detail.add_child(UITheme.label("Fully grown" if int(pet["level"]) >= Pets.MAX_LEVEL else "%d / %d growth to level %d  ·  grows as you fight and when fed" % [int(pet["xp"]), pets.xp_to_next(pet), int(pet["level"]) + 1], 14, UITheme.DIM))
	_detail.add_child(UITheme.label("Gives", 16, UITheme.HEADING))
	_detail.add_child(UITheme.paragraph(pets.describe(pet), DETAIL_WIDTH - 30.0, 15, UITheme.GOOD))
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail.add_child(fill)
	_detail.add_child(UITheme.primary_button("Send home" if following else "Call to follow", func() -> void:
		pets.set_active(index if not following else -1)
		refresh()
	, DETAIL_WIDTH - 30.0))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_detail.add_child(row)
	row.add_child(UITheme.button("Feed", func() -> void:
		_message.text = pets.feed(index)
		refresh()
	, 170.0))
	row.add_child(UITheme.danger_button("Release", func() -> void: _confirm_release(index), 170.0))


func _confirm_release(index: int) -> void:
	var pet: Dictionary = player.pets.pets[index]
	var popup := ConfirmationDialog.new()
	popup.title = "Release pet"
	popup.dialog_text = "Release %s for good? It will not come back." % pet["name"]
	popup.ok_button_text = "Release"
	popup.confirmed.connect(func() -> void:
		player.pets.release(index)
		_selected = -1
		refresh()
	)
	popup.visibility_changed.connect(func() -> void:
		if not popup.visible:
			popup.queue_free()
	)
	add_child(popup)
	popup.popup_centered()


func _fill_mounts() -> void:
	_mounts.add_child(UITheme.heading("Mounts", 18))
	var owned := {}
	for item in player.inventory.items:
		if item and item.definition().has("mount"):
			owned[item.definition()["mount"]] = true
	for id: String in Mount.MOUNTS:
		_mounts.add_child(_mount_card(id, owned.has(id)))


func _mount_card(id: String, owned: bool) -> Control:
	var data: Dictionary = Mount.MOUNTS[id]
	var riding := player.mount_id == id
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.card("card_selected" if riding else ("card" if owned else "card_dim"), 6))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)
	var picture := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = load("res://assets/sprites/mounts/%s.png" % data["sheet"])
	atlas.region = Rect2(20, 24, 56, 54)
	picture.texture = atlas
	picture.modulate = data["tint"] if owned else Color(0.2, 0.2, 0.28)
	picture.custom_minimum_size = Vector2(60, 56)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(picture)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 1)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(words)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	words.add_child(top)
	top.add_child(UITheme.strong(data["name"], 16, UITheme.TEXT if owned else UITheme.DIM))
	top.add_child(UITheme.badge("+%d%% speed" % roundi((float(data["speed"]) - 1.0) * 100.0), "info" if owned else "plain"))
	var ground := "Snow" if data.get("snow", false) else "Sand" if data.get("sand", false) else "Steady" if data.get("steady", false) else ""
	if ground != "":
		top.add_child(UITheme.badge(ground, "good" if owned else "plain"))
	if owned:
		words.add_child(UITheme.label("Owned" + ("  ·  riding" if riding else ""), 14, UITheme.GOOD))
		words.add_child(UITheme.button("Dismount" if riding else "Ride", func() -> void:
			if riding:
				player.dismount()
			else:
				_message.text = player.ride(id)
			refresh()
		, 110.0))
	else:
		var how := HBoxContainer.new()
		how.add_theme_constant_override("separation", 6)
		how.add_child(StateMark.make("locked", 14))
		how.add_child(UITheme.paragraph(MOUNT_HOW.get(id, "Not yet found."), MOUNTS_WIDTH - 130.0, 14, UITheme.DIM))
		words.add_child(how)
	return card
