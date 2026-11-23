class_name PactMenu
extends GameMenu
## The Pact's window (P): four pages in its navy and bronze.
##   Status: name, level, job, the six attributes with points to spend.
##   Road:   the Tenday Road, and the penalty for leaving it.
##   Shadows: your shadow soldiers (a Shade Sovereign's), called or not.
##   Gates:  the open gates, cleared gates, Monarchs fallen, and the Vigil.

const PAGES: Array[Array] = [["status", "Status"], ["rite", "Tenday Road"], ["shadows", "Shadows"], ["gates", "Gates"]]
const ICE := Color("bfe4f0")
const BRONZE := Color("c8904a")

var _page := "status"
var _tabs: Dictionary = {}
var _body: VBoxContainer
var _message: Label


func _build() -> void:
	var title := UITheme.heading("THE PACT", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", ICE)
	content.add_child(title)
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 6)
	content.add_child(tabs)
	for page: Array in PAGES:
		var button := UITheme.button(page[1], func() -> void:
			_page = page[0]
			refresh()
		, 150.0)
		button.toggle_mode = true
		tabs.add_child(button)
		_tabs[page[0]] = button
	var panel := UITheme.inset_panel()
	content.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(760, 380)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 8)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_body)
	_message = UITheme.label("", 14, UITheme.BAD)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_message)


func _pact() -> ThePact:
	return player.get_parent().get_node_or_null("ThePact")


func refresh() -> void:
	for id: String in _tabs:
		_tabs[id].set_pressed_no_signal(id == _page)
	for child in _body.get_children():
		child.queue_free()
	var pact := _pact()
	if pact == null:
		return
	if not pact.awakened:
		_body.add_child(_line("The Pact is not yours.", 18, ICE))
		_body.add_child(UITheme.paragraph("It is offered only to one who survives the Drowned Chapel: a crimson-and-gold gate that opens near you once you reach level %d. Find it, endure its bell, and touch its altar." % ThePact.CHAPEL_LEVEL, 740, 15, UITheme.TEXT))
		return
	match _page:
		"status":
			_status(pact)
		"rite":
			_rite(pact)
		"shadows":
			_shadows()
		"gates":
			_gates(pact)


func _line(text: String, size: int = 15, color: Color = UITheme.TEXT) -> Label:
	var label := UITheme.strong(text, size, color)
	return label


func _status(pact: ThePact) -> void:
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 40)
	_body.add_child(top)
	var left := VBoxContainer.new()
	top.add_child(left)
	left.add_child(_line("BEARER OF THE PACT", 16, BRONZE))
	left.add_child(_line("LEVEL    %d" % player.leveling.level, 16, ICE))
	left.add_child(_line("JOB      %s" % pact.job_name(), 16, ICE))
	left.add_child(_line("RITES    %d finished" % pact.rites_finished, 14, UITheme.DIM))
	var right := VBoxContainer.new()
	top.add_child(right)
	right.add_child(_line("HP   %d / %d" % [roundi(player.health.current), roundi(player.health.max_health)], 15, Color("e0606a")))
	right.add_child(_line("MP   %d / %d" % [roundi(player.mana.current), roundi(player.mana.max_value)], 15, Color("6a9ae0")))
	right.add_child(_line("Damage  %d    Armour  %d" % [roundi(player.stats.get_stat("physical_damage")), roundi(player.stats.get_stat("armor"))], 14, UITheme.TEXT))
	_body.add_child(UITheme.rule(740))
	var attributes := player.attributes
	_body.add_child(_line("Points to spend: %d" % attributes.unspent, 16, UITheme.GOLD if attributes.unspent > 0 else UITheme.DIM))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 30)
	grid.add_theme_constant_override("v_separation", 6)
	_body.add_child(grid)
	for id: String in Attributes.IDS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var name_label := _line("%s" % Attributes.NAMES[id].to_upper(), 15, ICE)
		name_label.custom_minimum_size = Vector2(130, 0)
		row.add_child(name_label)
		var value := _line(str(attributes.points[id]), 15, UITheme.TEXT)
		value.custom_minimum_size = Vector2(40, 0)
		row.add_child(value)
		var plus := UITheme.button("+", func() -> void:
			attributes.spend(id, 1)
			refresh()
		, 40.0)
		plus.disabled = attributes.unspent <= 0
		plus.tooltip_text = Attributes.TEXT[id]
		row.add_child(plus)
		var plus_five := UITheme.button("+5", func() -> void:
			attributes.spend(id, 5)
			refresh()
		, 48.0)
		plus_five.disabled = attributes.unspent <= 0
		row.add_child(plus_five)
		grid.add_child(row)
	if ThePact.JOBS.has(pact.job):
		_body.add_child(UITheme.rule(740))
		_body.add_child(UITheme.paragraph("%s: %s" % [pact.job_name(), ThePact.JOBS[pact.job]["text"]], 740, 14, UITheme.GOOD))


func _rite(pact: ThePact) -> void:
	var left := pact.days_left()
	_body.add_child(_line("TENDAY ROAD  ·  %d day%s left" % [left, "" if left == 1 else "s"], 18, ICE))
	for key: String in ThePact.RITE:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_body.add_child(row)
		var done := pact.progress(key) >= pact.goal(key)
		var label := _line(("✔ " if done else "   ") + str(ThePact.RITE[key][0]), 15, UITheme.GOOD if done else UITheme.TEXT)
		label.custom_minimum_size = Vector2(260, 0)
		row.add_child(label)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(320, 12)
		bar.max_value = pact.goal(key)
		bar.value = pact.progress(key)
		row.add_child(bar)
		row.add_child(_line("%d / %d" % [pact.progress(key), pact.goal(key)], 14, UITheme.DIM))
	_body.add_child(UITheme.rule(740))
	if pact.rite_done:
		_body.add_child(_line("Complete. The Pact is satisfied until a new road begins.", 15, UITheme.GOOD))
	else:
		_body.add_child(UITheme.paragraph("Reward: 3 attribute points, gold, and sometimes a gate key.", 740, 14, UITheme.TEXT))
		_body.add_child(UITheme.paragraph("WARNING: leave the road unfinished when its ten days are out and you will be taken to the Pit of Atonement, to survive there until it lets you go.", 740, 14, Color("e0805a")))
	_body.add_child(UITheme.paragraph("(The road and its messages can be turned off in Settings, Interface.)", 740, 12, UITheme.DIM))


func _shadows() -> void:
	var shadows: Shadows = player.get_parent().get_node_or_null("Shadows")
	if shadows == null or not shadows.can_raise():
		_body.add_child(_line("No shadows answer you.", 17, ICE))
		_body.add_child(UITheme.paragraph("Only a Shade Sovereign raises the fallen. That job is won in the Vigil of Ashes, a hidden quest the Pact offers at level %d." % ThePact.VIGIL_LEVEL, 740, 15, UITheme.TEXT))
		return
	_body.add_child(_line("SHADOWS  %d / %d" % [shadows.soldiers.size(), shadows.capacity()], 18, ICE))
	_body.add_child(UITheme.paragraph("Raise a fresh-fallen monster with %s (harder the greater it was). Swap places with the shadow nearest the pointer: %s." % [GameSettings.describe("raise_shadow"), GameSettings.describe("shadow_swap")], 740, 14, UITheme.DIM))
	_body.add_child(UITheme.primary_button("Send them into your shadow" if shadows.out else "Call them out", func() -> void:
		shadows.set_out(not shadows.out)
		refresh()
	, 300.0))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_body.add_child(grid)
	for index in shadows.soldiers.size():
		var soldier: Dictionary = shadows.soldiers[index]
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UITheme.card("card", 6))
		card.custom_minimum_size = Vector2(240, 70)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		card.add_child(row)
		var picture := TextureRect.new()
		var atlas := AtlasTexture.new()
		atlas.atlas = EnemyDB.sheet(str(soldier["species"]))
		atlas.region = Rect2(20, 22, 56, 56)
		picture.texture = atlas
		picture.custom_minimum_size = Vector2(52, 52)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		picture.modulate = Color(0.35, 0.28, 0.5)
		row.add_child(picture)
		var words := VBoxContainer.new()
		words.add_theme_constant_override("separation", 0)
		row.add_child(words)
		words.add_child(_line(str(soldier["name"]), 14, Color("c8a8f0")))
		words.add_child(UITheme.label("%s  ·  %d damage" % [["Soldier", "Elite", "Knight", "Commander", "Marshal"][clampi(int(soldier["rank"]), 0, 4)], roundi(shadows.damage_of(soldier))], 12, UITheme.DIM))
		var free := UITheme.button("Release", func() -> void:
			shadows.dismiss(index)
			refresh()
		, 90.0)
		words.add_child(free)
		grid.add_child(card)


func _gates(pact: ThePact) -> void:
	var gates: Gates = player.get_parent().get_node_or_null("Gates")
	if gates == null:
		return
	_body.add_child(_line("GATES  ·  %d cleared" % gates.cleared, 18, ICE))
	var here := (player.get_parent().get_node("World") as World).world_to_cell(player.global_position)
	if gates.gates.is_empty():
		_body.add_child(UITheme.label("No gate is open near you. New ones open with the days.", 14, UITheme.DIM))
	for gate: Dictionary in gates.gates:
		var cell := Vector2i(gate["cell"][0], gate["cell"][1])
		var colour: Color = Gates.RANKS[gate["rank"]]["color"]
		var today: int = (player.get_parent().get_node("DayNight") as DayNight).day
		var days_left: int = int(Gates.RANKS[gate["rank"]]["days"]) - (today - int(gate["day"]))
		var text := "%s-RANK%s  ·  %d tiles %s  ·  %s" % [gate["rank"], " (RED)" if gate["red"] else "", roundi(Vector2(cell - here).length()),
			Structures.compass(Vector2(cell - here)), "BROKEN" if gate["broken"] else "breaks in %d day%s" % [days_left, "" if days_left == 1 else "s"]]
		_body.add_child(_line(text, 15, Color("e0303a") if gate["red"] else colour))
	if not gates.monarchs_fallen.is_empty():
		_body.add_child(UITheme.rule(740))
		_body.add_child(_line("MONARCHS FALLEN", 15, Color("f05a4a")))
		for title: Variant in gates.monarchs_fallen:
			_body.add_child(UITheme.label(str(title), 14, UITheme.TEXT))
	_body.add_child(UITheme.rule(740))
	_body.add_child(_line("HIDDEN QUEST: THE VIGIL OF ASHES", 15, ICE))
	var problem := pact.vigil_problem()
	if pact.job != "":
		_body.add_child(UITheme.label("Done. You are a %s." % pact.job_name(), 14, UITheme.GOOD))
	else:
		_body.add_child(UITheme.paragraph("A job change. Hold the grave-ring through five waves of the dead and their Warden.", 740, 14, UITheme.TEXT))
		var begin := UITheme.primary_button("Begin the Vigil", func() -> void:
			player.get_parent().get_node("Menus").close()
			_message.text = pact.begin_vigil()
		, 260.0)
		begin.disabled = problem != ""
		begin.tooltip_text = problem
		_body.add_child(begin)
		if problem != "":
			_body.add_child(UITheme.reason(problem, 740))
