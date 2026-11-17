class_name TownMenu
extends GameMenu
## Your town of monsters. Left: each citizen (portrait, Name, its stage and
## kind, level) with its job, which can be changed by clicking through the
## jobs, and a button to call it back to follow you. Right: the town's level
## and what it gives, the store, the Festival of Rising, and the treaties
## (one row per faction: at peace, or what a treaty needs).

var _summary: Label
var _list: VBoxContainer
var _side: VBoxContainer
var _message: Label


func _build() -> void:
	var title := UITheme.heading("YOUR TOWN", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	_summary = UITheme.label("", 15, UITheme.DIM)
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_summary)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	content.add_child(body)
	var left := UITheme.inset_panel()
	body.add_child(left)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(500, 380)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	var right := ScrollContainer.new()
	right.custom_minimum_size = Vector2(360, 380)
	right.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(right)
	_side = VBoxContainer.new()
	_side.add_theme_constant_override("separation", 8)
	_side.custom_minimum_size = Vector2(340, 0)
	right.add_child(_side)
	_message = UITheme.label("", 14, UITheme.BAD)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_message)


func _town() -> MonsterTown:
	return player.get_parent().get_node_or_null("MonsterTown")


func refresh() -> void:
	var town := _town()
	for child in _list.get_children() + _side.get_children():
		child.queue_free()
	if town == null:
		return
	_summary.text = "Town level %d  ·  %d citizen%s  ·  %d festival%s held" % [town.level(), town.citizens.size(), "" if town.citizens.size() == 1 else "s", town.festivals, "" if town.festivals == 1 else "s"]
	if town.citizens.is_empty():
		_list.add_child(UITheme.paragraph("No one lives here yet. Tame a monster when it is nearly beaten, give it a Name on the Pets screen (it takes all your mana), and then settle it in your town.", 480, 15, UITheme.DIM))
	for index in town.citizens.size():
		_list.add_child(_row(town, index))
	_fill_side(town)


func _row(town: MonsterTown, index: int) -> Control:
	var citizen: Dictionary = town.citizens[index]
	var job: Dictionary = MonsterTown.JOBS[str(citizen["job"])]
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.card("card", 6))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var picture := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = EnemyDB.sheet(str(citizen["species"]))
	atlas.region = Rect2(20, 22, 56, 56)
	picture.texture = atlas
	picture.custom_minimum_size = Vector2(56, 56)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.modulate = Pets.STAGES[int(citizen.get("stage", 0))][2]
	row.add_child(picture)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(words)
	words.add_child(UITheme.strong(str(citizen["name"]), 16, UITheme.GOLD))
	words.add_child(UITheme.label("%s %s  ·  level %d" % [Pets.STAGES[int(citizen.get("stage", 0))][1], EnemyDB.ENEMIES[citizen["species"]]["name"], int(citizen["level"])], 13, UITheme.TEXT))
	var faction := Factions.of(str(citizen["species"]))
	if faction != "":
		words.add_child(UITheme.label("Speaks for %s" % Factions.LIST[faction]["name"], 12, Factions.LIST[faction]["color"]))
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 4)
	row.add_child(buttons)
	var jobs: Array = MonsterTown.JOBS.keys()
	var job_button := UITheme.button(str(job["title"]), func() -> void:
		town.set_job(index, jobs[(jobs.find(citizen["job"]) + 1) % jobs.size()])
		refresh()
	, 130.0)
	job_button.add_theme_color_override("font_color", job["color"])
	job_button.tooltip_text = "%s\nClick for the next job." % job["text"]
	buttons.add_child(job_button)
	buttons.add_child(UITheme.button("Call to you", func() -> void:
		_message.text = town.call_back(index)
		refresh()
	, 130.0))
	return panel


func _fill_side(town: MonsterTown) -> void:
	_side.add_child(UITheme.heading("The town gives", 18))
	var scholars := town.citizens.filter(func(c: Dictionary) -> bool: return c["job"] == "scholar").size()
	_side.add_child(UITheme.paragraph("+%d%% maximum health from its spirit%s." % [mini(town.level() - 1, 20), ", +%d%% experience from its scholars" % (3 * scholars) if scholars > 0 else ""], 340, 14, UITheme.GOOD))
	var store_count := 0
	for saved: Dictionary in town.store:
		store_count += int(saved.get("count", 1))
	var store := UITheme.button("Open the store (%d things)" % store_count, func() -> void:
		player.get_parent().get_node("Menus").close()
		town.open_store()
	, 340.0)
	store.disabled = town.store.is_empty()
	_side.add_child(store)
	_side.add_child(UITheme.rule(340))
	_side.add_child(UITheme.heading("The Festival of Rising", 18))
	_side.add_child(UITheme.paragraph("Once a week: every citizen grows %d levels (Named ones may evolve on the spot), and you are Risen for ten minutes." % MonsterTown.FESTIVAL_LEVELS, 340, 14, UITheme.TEXT))
	var problem := town.festival_problem()
	var festival := UITheme.primary_button("Hold the festival (%d gold)" % town.festival_cost(), func() -> void:
		_message.text = town.hold_festival()
		refresh()
	, 340.0)
	festival.disabled = problem != ""
	festival.tooltip_text = problem
	_side.add_child(festival)
	if problem != "":
		_side.add_child(UITheme.reason(problem, 340))
	_side.add_child(UITheme.rule(340))
	_side.add_child(UITheme.heading("Treaties", 18))
	var factions: Factions = player.get_parent().get_node_or_null("Factions")
	if factions == null:
		return
	for faction: String in Factions.LIST:
		var data: Dictionary = Factions.LIST[faction]
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 6)
		_side.add_child(line)
		var label := UITheme.label(str(data["name"]), 14, data["color"])
		label.custom_minimum_size = Vector2(170, 0)
		line.add_child(label)
		if factions.at_peace(faction):
			line.add_child(UITheme.badge("At peace", "good"))
			continue
		var why := factions.treaty_problem(faction, town, player)
		var offer := UITheme.button("Offer (%d)" % factions.treaty_cost(), func() -> void:
			factions.sign_treaty(faction, player)
			refresh()
		, 150.0)
		offer.disabled = why != ""
		offer.tooltip_text = why
		line.add_child(offer)
