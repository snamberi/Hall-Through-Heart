class_name VillagerMenu
extends GameMenu
## Talking to a villager: who they are, what they say about the hour and the
## places nearby, and the errand they need doing today.

var npc: Npc
var _title: Label
var _friend: Label
var _figure: LookPreview
var _words: Label
var _errand_box: VBoxContainer
var _message: Label


func _build() -> void:
	_title = UITheme.heading("", 26)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_title)
	_friend = UITheme.label("", 14, UITheme.GOOD)
	_friend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_friend)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	content.add_child(row)
	_figure = LookPreview.new()
	_figure.custom_minimum_size = Vector2(230, 270)
	_figure.zoom = 3.0
	row.add_child(_figure)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	right.custom_minimum_size = Vector2(440, 0)
	row.add_child(right)
	var speech := UITheme.inset_panel()
	right.add_child(speech)
	_words = UITheme.label("", 16, UITheme.TEXT)
	_words.autowrap_mode = TextServer.AUTOWRAP_WORD
	_words.custom_minimum_size = Vector2(420, 70)
	speech.add_child(_words)
	var errand_panel := UITheme.inset_panel()
	right.add_child(errand_panel)
	_errand_box = VBoxContainer.new()
	_errand_box.add_theme_constant_override("separation", 6)
	errand_panel.add_child(_errand_box)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	right.add_child(buttons)
	buttons.add_child(UITheme.button("Ask about the area", func() -> void:
		_words.text = "\"%s\"" % _line()
	, 210.0))
	buttons.add_child(UITheme.button("Goodbye", func() -> void:
		player.get_parent().get_node("Menus").close()
	, 140.0))
	_message = UITheme.label("", 14, UITheme.BAD)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD
	_message.custom_minimum_size = Vector2(420, 0)
	right.add_child(_message)


func _errands() -> Errands:
	return player.get_parent().get_node("Errands")


func refresh() -> void:
	if npc == null or not is_instance_valid(npc):
		return
	_title.text = "%s THE %s" % [npc.villager_name.to_upper(), str(VillagerLife.JOBS[npc.job]["title"]).to_upper()]
	var helped := int(_errands().helped.get(npc.villager_key, 0))
	_friend.text = "" if helped == 0 else "%s  Friend: helped %d time%s" % ["♥".repeat(mini(helped, 5)), helped, "" if helped == 1 else "s"]
	_figure.show_look(npc.look)
	_words.text = "\"%s\"" % _line()
	_message.text = ""
	_fill_errand()


func _line() -> String:
	var night: DayNight = player.get_parent().get_node("DayNight")
	var hour := "night" if night.is_night() else "dusk" if night.time > 0.62 else "morning" if night.time < 0.36 else "day"
	var rumours: Array[String] = []
	var structures: Structures = player.get_parent().get_node_or_null("Structures")
	var world: World = player.get_parent().get_node("World")
	if structures:
		var here := world.world_to_cell(npc.global_position)
		for site: Dictionary in structures.nearest_sites(here, 3, 6):
			if VillagerLife.RUMOURS.has(site["kind"]):
				rumours.append(VillagerLife.RUMOURS[site["kind"]] % Structures.compass(Vector2(site["cell"] - here)))
	return VillagerLife.line(npc.job, hour, rumours)


func _fill_errand() -> void:
	for child in _errand_box.get_children():
		child.queue_free()
	var errands := _errands()
	var errand := errands.offer_for(npc)
	if errand.is_empty():
		_errand_box.add_child(UITheme.heading("Nothing today", 16))
		_errand_box.add_child(UITheme.label("%s has no more work for you today. Come back tomorrow." % npc.villager_name, 14, UITheme.DIM))
		return
	var taken := errands.taken.has(npc.villager_key)
	_errand_box.add_child(UITheme.heading(errand["title"], 17))
	var text := UITheme.label(errand["text"], 14, UITheme.TEXT)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD
	text.custom_minimum_size = Vector2(410, 0)
	_errand_box.add_child(text)
	_errand_box.add_child(_rewards_row(errand))
	if not taken:
		_errand_box.add_child(UITheme.button("I'll do it", func() -> void:
			_message.text = errands.accept(npc)
			if _message.text == "":
				npc.say("Thank you!", 2.5)
			_fill_errand()
		, 200.0))
	elif errand["kind"] == "fetch":
		var have := player.inventory.count_of(errand["target"])
		_errand_box.add_child(UITheme.label("You carry %d of %d." % [have, errand["need"]], 14, UITheme.GOOD if have >= int(errand["need"]) else UITheme.DIM))
		var give := UITheme.button("Hand them over", func() -> void:
			_message.text = errands.hand_over(npc)
			if _message.text == "":
				npc.say("Just what I needed!", 3.0)
			refresh()
		, 200.0)
		give.disabled = not errands.can_hand_over(npc)
		_errand_box.add_child(give)
	else:
		_errand_box.add_child(UITheme.label("Done so far: %d of %d. It pays the moment the last one falls." % [errand["have"], errand["need"]], 14, UITheme.DIM))


func _rewards_row(errand: Dictionary) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_child(UITheme.label("Reward:", 14, UITheme.GOOD))
	flow.add_child(_chip(ItemDB.icon(17), "%d" % errand["gold"], UITheme.GOLD))
	for entry: Array in errand["items"]:
		var item := Item.create(entry[0])
		flow.add_child(_chip(item.icon(), "%s x%d" % [item.display_name(), entry[1]], UITheme.TEXT, item.icon_tint()))
	if errand.has("gear"):
		var rarity: Dictionary = ItemDB.RARITIES[int(errand["gear"])]
		flow.add_child(_chip(ItemDB.icon(7), "%s gear" % rarity["name"], rarity["color"], rarity["color"].lightened(0.3)))
	flow.add_child(UITheme.label("+%d XP" % errand["xp"], 14, Color(0.8, 0.68, 1.0)))
	return flow


func _chip(texture: Texture2D, text: String, color: Color, tint: Color = Color.WHITE) -> HBoxContainer:
	var chip := HBoxContainer.new()
	chip.add_theme_constant_override("separation", 3)
	var icon := TextureRect.new()
	icon.texture = texture
	icon.modulate = tint
	icon.custom_minimum_size = Vector2(22, 22)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	chip.add_child(icon)
	chip.add_child(UITheme.label(text, 14, color))
	return chip
