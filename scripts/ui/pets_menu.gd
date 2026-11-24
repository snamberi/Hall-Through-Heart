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
## The chosen pet's page: "about", or "talents" for talents and gear.
var _pet_tab := "about"
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
	panel.custom_minimum_size = Vector2(width, 500)
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
		atlas.region = Rect2(Critter.KINDS.find(pet["species"]) * Critter.FRAMES * Critter.SIZE, 0, Critter.SIZE, Critter.SIZE)
	else:
		atlas.atlas = EnemyDB.sheet(pet["species"])
		atlas.region = EnemyDB.cell_region(atlas.atlas, Rect2(20, 22, 56, 56))
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
	atlas.region = Rect2(0, 0, Critter.SIZE, Critter.SIZE)
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
	var title_line := "%s  ·  level %d of %d" % [_species(pet), pet["level"], Pets.MAX_LEVEL]
	if pet.get("named", false):
		title_line = "%s %s  ·  level %d of %d" % [Pets.STAGES[pets.stage(pet)][1], _species(pet), pet["level"], Pets.MAX_LEVEL]
	words.add_child(UITheme.label(title_line, 15, UITheme.GOLD if pet.get("named", false) else UITheme.TEXT))
	words.add_child(UITheme.badge("Following you" if following else "At home", "good" if following else "plain"))
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	_detail.add_child(tabs)
	var points := pets.points_left(pet)
	for tab: Array in [["about", "About"], ["talents", "Talents & gear" + ("  (%d)" % points if points > 0 else "")]]:
		var chosen: bool = _pet_tab == tab[0]
		var tab_button := UITheme.tab(tab[1], func() -> void:
			_pet_tab = tab[0]
			refresh()
		, 172.0)
		tab_button.set_pressed_no_signal(chosen)
		tabs.add_child(tab_button)
	if _pet_tab == "talents":
		_talents_page(index)
		return
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
	# A monster can be given a Name (the one in the box above); a Named one
	# can go to live in your town.
	if pet["kind"] == "monster":
		var bond := HBoxContainer.new()
		bond.add_theme_constant_override("separation", 8)
		_detail.add_child(bond)
		if not pet.get("named", false):
			var naming := UITheme.primary_button("Give it a Name", func() -> void:
				_message.text = pets.give_name(index, name_field.text)
				refresh()
			, 348.0)
			naming.tooltip_text = "Takes all your mana and leaves you weary for two minutes. A Named monster evolves as it grows."
			bond.add_child(naming)
		else:
			var town: MonsterTown = player.get_parent().get_node_or_null("MonsterTown")
			var settle := UITheme.button("Settle in your town", func() -> void:
				_message.text = town.settle(index) if town else ""
				refresh()
			, 348.0)
			settle.tooltip_text = "It will live by your home, work a job, and speak for its kind."
			settle.disabled = town == null
			bond.add_child(settle)


## The chosen pet's talents and gear: a collar and a charm to put on from
## the bag, then a row per talent with its ranks and a button to learn one.
func _talents_page(index: int) -> void:
	var pets := player.pets
	var pet: Dictionary = pets.pets[index]
	var gear_row := HBoxContainer.new()
	gear_row.add_theme_constant_override("separation", 8)
	_detail.add_child(gear_row)
	for slot: String in Pets.GEAR_SLOTS:
		gear_row.add_child(_gear_slot(pets.gear(pet, slot), "No " + slot, slot.capitalize(),
			func() -> void: _pick_from_bag(func(item: Item) -> bool: return str(item.definition().get("pet_gear", "")) == slot,
				func(item: Item) -> void: _message.text = pets.put_on(index, item),
				"No pet %ss in your bag. %s" % [slot, "Make a Leather Collar (Building 3) or buy one from a general store." if slot == "collar" else "Charms are made at an enchanting table (Enchanting 10)."]),
			func() -> void: _message.text = pets.take_off(index, slot), 172.0))
	var points := pets.points_left(pet)
	var head := HBoxContainer.new()
	_detail.add_child(head)
	var title := UITheme.label("Talents", 16, UITheme.HEADING)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(UITheme.label("%d point%s to spend  ·  one every %d levels" % [points, "" if points == 1 else "s", Pets.LEVELS_PER_POINT], 14, UITheme.GOLD if points > 0 else UITheme.DIM))
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 0)
	_detail.add_child(list)
	for talent: String in pets.talents_for(pet):
		var data: Dictionary = Pets.TALENTS[talent]
		var have := pets.rank(pet, talent)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		list.add_child(row)
		var name_label := UITheme.strong(data["name"], 15, UITheme.GOLD if have > 0 else UITheme.TEXT)
		name_label.custom_minimum_size.x = 92.0
		row.add_child(name_label)
		var ranks := UITheme.label("%d/%d" % [have, data["ranks"]], 14, UITheme.GOOD if have >= int(data["ranks"]) else UITheme.DIM)
		ranks.custom_minimum_size.x = 30.0
		row.add_child(ranks)
		var text := UITheme.label(data["text"] + " a rank", 13, UITheme.DIM)
		text.clip_text = true
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.tooltip_text = data["text"] + " a rank"
		text.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(text)
		var learn := UITheme.button("+", func() -> void:
			_message.text = pets.learn(index, talent)
			refresh()
		, 34.0)
		learn.custom_minimum_size.y = 28.0
		learn.disabled = points <= 0 or have >= int(data["ranks"])
		learn.tooltip_text = "Learn a rank of %s" % data["name"]
		row.add_child(learn)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail.add_child(fill)
	var reset := UITheme.button("Forget talents", func() -> void:
		pets.unlearn(index)
		refresh()
	, DETAIL_WIDTH - 30.0)
	reset.disabled = pets.points_left(pet) == pets.talent_points(pet)
	_detail.add_child(reset)


## A gear slot: what is worn (icon and name) or that it is empty. Click to
## choose from the bag; right-click to take it off.
func _gear_slot(item: Item, empty_text: String, slot_name: String, pick: Callable, remove: Callable, width: float) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(width, 48.0)
	for state: String in ["normal", "pressed"]:
		button.add_theme_stylebox_override(state, UITheme.card("card" if item else "card_dim", 6))
	button.add_theme_stylebox_override("hover", UITheme.card("card_hover", 6))
	button.tooltip_text = "Click to choose from your bag." + ("\nRight-click to take it off." if item else "")
	button.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT and item:
			remove.call()
			refresh()
	)
	button.pressed.connect(pick)
	UITheme.sounds(button)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(row)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UITheme.slot("slot"))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(frame)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(32, 32)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if item:
		icon.texture = item.icon()
		icon.modulate = item.icon_tint()
	frame.add_child(icon)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", -2)
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(words)
	words.add_child(UITheme.label(slot_name, 13, UITheme.DIM))
	var name_label := UITheme.strong(item.display_name() if item else empty_text, 14, item.color() if item else UITheme.DIM)
	name_label.clip_text = true
	name_label.custom_minimum_size.x = width - 60.0
	words.add_child(name_label)
	for control: Control in words.get_children():
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return button


## A small list of matching things in the bag to choose one from.
func _pick_from_bag(fits: Callable, chosen: Callable, none_text: String) -> void:
	var found: Array[Item] = []
	for item: Item in player.inventory.items:
		if item and fits.call(item):
			found.append(item)
	if found.is_empty():
		_message.text = none_text
		return
	var menu := PopupMenu.new()
	for index in found.size():
		menu.add_icon_item(found[index].icon(), found[index].display_name(), index)
	menu.id_pressed.connect(func(id: int) -> void:
		chosen.call(found[id])
		refresh()
	)
	menu.popup_hide.connect(menu.queue_free)
	add_child(menu)
	menu.popup(Rect2i(Vector2i(get_global_mouse_position()), Vector2i.ZERO))


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
	var stable := player.stable
	var heading_row := HBoxContainer.new()
	_mounts.add_child(heading_row)
	var heading := UITheme.heading("Mounts", 18)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading_row.add_child(heading)
	var races := UITheme.label("Races: %d gold · %d silver · %d bronze" % [
		stable.medal_count(3), stable.medal_count(2) - stable.medal_count(3), stable.medal_count(1) - stable.medal_count(2)], 13, UITheme.DIM)
	races.tooltip_text = "Every village has a race post. Ride its course against the clock for medals and gold."
	races.mouse_filter = Control.MOUSE_FILTER_PASS
	heading_row.add_child(races)
	# Tack, shared by every mount, and race medals.
	var tack := HBoxContainer.new()
	tack.add_theme_constant_override("separation", 8)
	_mounts.add_child(tack)
	for slot: String in Stable.SLOTS:
		tack.add_child(_gear_slot(stable.tack[slot], "No " + slot, slot.capitalize(),
			func() -> void: _pick_from_bag(func(item: Item) -> bool: return Stable.slot_of(item) == slot,
				func(item: Item) -> void: _message.text = stable.put_on(item),
				"No %s in your bag. %s" % [slot, "Make a Riding Saddle (Building 5) or buy one from a general store." if slot == "saddle" else "Make Padded Barding (Building 8) or Iron Barding (Blacksmithing 15)."]),
			func() -> void: _message.text = stable.take_off(slot), 186.0))

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
	atlas.region = Rect2(16, 18, 68, 58)
	picture.texture = atlas
	picture.modulate = Color.WHITE if owned else Color(0.2, 0.2, 0.28)
	picture.custom_minimum_size = Vector2(68, 58)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
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
	top.add_child(UITheme.badge("+%d%% speed" % roundi((float(data["speed"]) * (1.0 + player.stable.speed_bonus()) - 1.0) * 100.0), "info" if owned else "plain"))
	var ground := "Snow" if data.get("snow", false) else "Sand" if data.get("sand", false) else "Steady" if data.get("steady", false) else ""
	if ground != "":
		top.add_child(UITheme.badge(ground, "good" if owned else "plain"))
	if owned:
		words.add_child(UITheme.label("Owned" + ("  ·  riding" if riding else ""), 14, UITheme.GOOD))
		var ride_button := UITheme.button("Dismount" if riding else "Ride", func() -> void:
			if riding:
				player.dismount()
			else:
				_message.text = player.ride(id)
			refresh()
		, 96.0)
		ride_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(ride_button)
	else:
		var how := HBoxContainer.new()
		how.add_theme_constant_override("separation", 6)
		how.add_child(StateMark.make("locked", 14))
		how.add_child(UITheme.paragraph(MOUNT_HOW.get(id, "Not yet found."), MOUNTS_WIDTH - 130.0, 14, UITheme.DIM))
		words.add_child(how)
	return card
