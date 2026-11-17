class_name CodexMenu
extends GameMenu
## The Codex: a bestiary of every creature met (a wall of portraits, dark
## until first slain, in plain frames; the Hunter's Mark is a badge of its
## own), achievements and titles, and a record of what has been gathered,
## caught and done. The bestiary and achievements can be searched and
## filtered; the right-hand side always holds the details.

const TILE := Vector2(98, 112)

var _tab := "bestiary"
## A tab another screen asked the Codex to open on (the Wardrobe's looks).
static var requested_tab := ""
var _tabs: Dictionary = {}
var _left: VBoxContainer
var _right: VBoxContainer
var _picked := ""
var _title_pick: OptionButton
var _tip: ItemTooltip
var _filter_row: HBoxContainer
var _search: LineEdit
var _filter := "all"
var _filter_buttons: HBoxContainer
const FILTERS := {
	"bestiary": [["all", "All"], ["known", "Known"], ["unknown", "Unknown"], ["marked", "Marked"]],
	"achievements": [["all", "All"], ["earned", "Earned"], ["progress", "In progress"]],
}


func _build() -> void:
	var title := UITheme.heading("CODEX", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	_tip = ItemTooltip.new()
	add_child(_tip)
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 8)
	content.add_child(tabs)
	for tab: Array in [["bestiary", "Bestiary"], ["factions", "Factions"], ["achievements", "Achievements"], ["collection", "Collection"]]:
		var button := UITheme.button(tab[1], func() -> void:
			_tab = tab[0]
			_picked = ""
			_filter = "all"
			_search.text = ""
			refresh()
		, 160.0)
		button.toggle_mode = true
		tabs.add_child(button)
		_tabs[tab[0]] = button
	_filter_row = HBoxContainer.new()
	_filter_row.add_theme_constant_override("separation", 8)
	content.add_child(_filter_row)
	_search = UITheme.search_box("Search", 240.0, refresh)
	_filter_row.add_child(_search)
	_filter_buttons = HBoxContainer.new()
	_filter_buttons.add_theme_constant_override("separation", 6)
	_filter_row.add_child(_filter_buttons)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	content.add_child(columns)
	var left_panel := UITheme.inset_panel()
	columns.add_child(left_panel)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(540, 410)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_panel.add_child(scroll)
	_left = VBoxContainer.new()
	_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left.add_theme_constant_override("separation", 6)
	scroll.add_child(_left)
	var right_panel := UITheme.inset_panel()
	columns.add_child(right_panel)
	var right_scroll := ScrollContainer.new()
	right_scroll.custom_minimum_size = Vector2(400, 410)
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_panel.add_child(right_scroll)
	_right = VBoxContainer.new()
	_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right.add_theme_constant_override("separation", 6)
	right_scroll.add_child(_right)
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree():
			_tip.hide_tip()
	)


func _codex() -> Codex:
	return player.get_parent().get_node("Codex")


func refresh() -> void:
	var codex := _codex()
	if requested_tab != "":
		_tab = requested_tab
		requested_tab = ""
		_picked = ""
		_filter = "all"
		_search.text = ""
	for id: String in _tabs:
		_tabs[id].set_pressed_no_signal(id == _tab)
	_filter_row.visible = FILTERS.has(_tab)
	for child in _filter_buttons.get_children():
		child.queue_free()
	for entry: Array in FILTERS.get(_tab, []):
		var button := UITheme.button(entry[1], func() -> void:
			_filter = entry[0]
			refresh()
		, 96.0)
		button.toggle_mode = true
		button.set_pressed_no_signal(entry[0] == _filter)
		_filter_buttons.add_child(button)
	for child in _left.get_children() + _right.get_children():
		child.queue_free()
	match _tab:
		"bestiary":
			_bestiary(codex)
		"achievements":
			_achievements(codex)
		"factions":
			_factions(codex)
		_:
			_collection(codex)


## Words in the right-hand panel.
func _say(bbcode: String) -> void:
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.custom_minimum_size = Vector2(384, 0)
	UITheme.font_size(text, 14, "normal_font_size")
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.text = bbcode
	_right.add_child(text)


func _bestiary(codex: Codex) -> void:
	var known := 0
	for id: String in EnemyDB.ENEMIES:
		if codex.kills_of(id) > 0:
			known += 1
	var marked := 0
	for id: String in EnemyDB.ENEMIES:
		if codex.kills_of(id) >= int(Codex.REVEAL["mark"]):
			marked += 1
	_left.add_child(UITheme.label("%d of %d kinds known  ·  %d with the Hunter's Mark" % [known, EnemyDB.ENEMIES.size(), marked], 15, UITheme.TEXT))
	var words := _search.text.strip_edges().to_lower()
	var shown := 0
	for group: Array in [["Monsters", false], ["Beasts of the wild", true]]:
		var grid := HFlowContainer.new()
		grid.add_theme_constant_override("h_separation", 5)
		grid.add_theme_constant_override("v_separation", 5)
		grid.custom_minimum_size.x = 520.0
		for id: String in EnemyDB.ENEMIES:
			if EnemyDB.ENEMIES[id].has("wild") != group[1]:
				continue
			var kills := codex.kills_of(id)
			match _filter:
				"known":
					if kills == 0:
						continue
				"unknown":
					if kills > 0:
						continue
				"marked":
					if kills < int(Codex.REVEAL["mark"]):
						continue
			# Only known names can be searched for: the unknown stay secret.
			if words != "" and (kills == 0 or not str(EnemyDB.ENEMIES[id]["name"]).to_lower().contains(words)):
				continue
			grid.add_child(_creature_tile(codex, id))
		if grid.get_child_count() > 0:
			_left.add_child(UITheme.heading("%s (%d)" % [group[0], grid.get_child_count()], 16))
			_left.add_child(grid)
			shown += grid.get_child_count()
		else:
			grid.free()
	if shown == 0:
		_left.add_child(UITheme.label("Nothing matches.", 15, UITheme.DIM))
	if _picked == "":
		_right.add_child(UITheme.heading("The hunt", 20))
		_say("Slay a kind of creature to learn of it. Each kill count reveals more:")
		for step: Array in _reveal_steps():
			_right.add_child(_reveal_row(step[1], "%d kill%s" % [step[0], "" if step[0] == 1 else "s"], true, false))
		_say("[color=#%s]The Hunter's Mark: you deal 5%% more damage to that kind.[/color]" % UITheme.GOLD.to_html(false))
		return
	_creature_page(codex, _picked)


## One creature on the wall: its portrait (a shadow until slain) and count.
func _creature_tile(codex: Codex, id: String) -> Button:
	var kills := codex.kills_of(id)
	var marked := kills >= int(Codex.REVEAL["mark"])
	var button := Button.new()
	button.custom_minimum_size = TILE
	# Plain frames for all; the chosen one is lit; the Mark is its own badge.
	var style := UITheme.card("card_selected" if id == _picked else ("card" if kills > 0 else "card_dim"), 4)
	var hover := UITheme.card("card_selected" if id == _picked else "card_hover", 4)
	for state: String in ["normal", "pressed"]:
		button.add_theme_stylebox_override(state, style)
	button.add_theme_stylebox_override("hover", hover)
	var picture := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = EnemyDB.sheet(id)
	atlas.region = Rect2(16, 14, 64, 64)
	picture.texture = atlas
	picture.position = Vector2(7, 4)
	picture.size = Vector2(84, 84)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Unmet creatures are a shape in the dark, with a question over them: a
	# mystery, not a missing picture.
	picture.modulate = Color.WHITE if kills > 0 else Color(0.16, 0.14, 0.3)
	button.add_child(picture)
	if kills == 0:
		var ask := UITheme.label("?", 30, Color(0.85, 0.75, 0.5, 0.55))
		ask.add_theme_font_override("font", UITheme.bold())
		ask.position = Vector2(0, 26)
		ask.size = Vector2(TILE.x, 40)
		ask.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ask.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(ask)
	if marked:
		var mark := Control.new()
		mark.position = Vector2(TILE.x - 26, 4)
		mark.size = Vector2(22, 22)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mark.draw.connect(_draw_mark.bind(mark))
		button.add_child(mark)
	var label := UITheme.label(("%d slain" % kills) if kills > 0 else "unknown", 14, UITheme.TEXT if kills > 0 else UITheme.DIM)
	label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	label.offset_top = -20.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(label)
	button.tooltip_text = (EnemyDB.ENEMIES[id]["name"] + ("  (Hunter's Mark)" if marked else "")) if kills > 0 else "Not yet slain"
	button.pressed.connect(func() -> void:
		_picked = id
		refresh()
	)
	UITheme.sounds(button)
	return button


## Everything known of one creature.
func _creature_page(codex: Codex, id: String) -> void:
	var data: Dictionary = EnemyDB.ENEMIES[id]
	var kills := codex.kills_of(id)
	if kills == 0:
		var shadow := TextureRect.new()
		var atlas := AtlasTexture.new()
		atlas.atlas = EnemyDB.sheet(id)
		atlas.region = Rect2(16, 14, 64, 64)
		shadow.texture = atlas
		shadow.custom_minimum_size = Vector2(384, 140)
		shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		shadow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		shadow.modulate = Color(0.16, 0.14, 0.3)
		_right.add_child(shadow)
		_right.add_child(UITheme.heading("???", 22))
		_say("[color=#%s]Not yet slain. Its shape is all you know.[/color]" % UITheme.DIM.to_html(false))
		for step: Array in _reveal_steps():
			_right.add_child(_reveal_row(step[1], "slay %d" % step[0], false, true))
		return
	# The creature itself, walking on the spot.
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(384, 150)
	stage.draw.connect(func() -> void:
		stage.draw_rect(Rect2(Vector2.ZERO, stage.size), Color("0b0e17"))
		stage.draw_set_transform(Vector2(stage.size.x / 2.0, stage.size.y - 28.0), 0.0, Vector2(1.0, 0.3))
		stage.draw_circle(Vector2.ZERO, 70.0, Color("2a2c36"))
		stage.draw_set_transform(Vector2.ZERO)
		stage.draw_rect(Rect2(Vector2.ZERO, stage.size), Color("403020"), false, 2.0)
	)
	var sprite := AnimatedSprite2D.new()
	sprite.process_mode = Node.PROCESS_MODE_ALWAYS
	sprite.sprite_frames = SheetAnimations.build(EnemyDB.sheet(id), 96, EnemyAnimator.ROWS)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(2.4, 2.4)
	sprite.position = Vector2(192, 150 - 28 - 23.0 * 2.4)
	sprite.play("walk")
	stage.add_child(sprite)
	_right.add_child(stage)
	var lines: PackedStringArray = []
	lines.append("[font_size=22][color=#%s]%s[/color][/font_size]" % [UITheme.HEADING.to_html(false), data["name"]])
	lines.append("[i][color=#%s]%s[/color][/i]" % [UITheme.DIM.to_html(false), Codex.LORE.get(id, "")])
	lines.append("")
	lines.append("Roams %s, from level %d. %s." % [", ".join((data["tiles"] as Array).slice(0, 4).map(func(t: int) -> String: return TerrainTiles.display_name(t))).to_lower(), data["min_level"],
		{"night": "Comes out at night", "day": "Roams by day", "always": "Day and night"}[data.get("active", "night")]])
	_say("\n".join(lines))
	# How far the hunt has gone: one bar, a notch at each thing learned.
	var goal: int = Codex.REVEAL["mark"]
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(384, 34)
	bar.draw.connect(func() -> void:
		var font := UITheme.get_theme().default_font
		var track := Rect2(0, 4, bar.size.x, 12)
		bar.draw_rect(track, Color(0.03, 0.035, 0.06))
		bar.draw_rect(Rect2(track.position, Vector2(track.size.x * minf(float(kills) / goal, 1.0), track.size.y)), UITheme.GOLD if kills >= goal else Color("b0503a"))
		bar.draw_rect(track, Color("8a683a"), false, 1.0)
		for notch: Array in [[Codex.REVEAL["weakness"], "weakness"], [Codex.REVEAL["drops"], "drops"], [Codex.REVEAL["mark"], "mark"]]:
			var x := track.size.x * float(notch[0]) / goal
			bar.draw_line(Vector2(x - 1.0, 2), Vector2(x - 1.0, 18), Color("f0d28a"), 1.5)
			bar.draw_string(font, Vector2(x - 80.0, 31), "%s %d" % [notch[1], notch[0]], HORIZONTAL_ALIGNMENT_RIGHT, 78.0, 13, UITheme.GOOD if kills >= int(notch[0]) else UITheme.DIM)
		bar.draw_string(font, Vector2(4, 14), "%d slain" % kills, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
	)
	_right.add_child(bar)
	for step: Array in _reveal_steps():
		if kills < int(step[0]):
			_right.add_child(UITheme.label("Next: %s at %d kills (%d more)" % [step[1].to_lower(), step[0], int(step[0]) - kills], 15, UITheme.INFO))
			break
	if kills >= int(Codex.REVEAL["weakness"]):
		_right.add_child(_element_row(id))
	else:
		_say("[color=#%s]Weaknesses: slay %d to learn.[/color]" % [UITheme.DIM.to_html(false), Codex.REVEAL["weakness"]])
	_drops(id, kills >= int(Codex.REVEAL["drops"]))
	if kills >= goal:
		_say("[color=#%s]Hunter's Mark: you deal 5%% more damage to this kind.[/color]" % UITheme.GOLD.to_html(false))


## What a creature leaves behind: every material and piece of gear it can
## drop and its gold. The chances show once enough have been slain.
func _drops(id: String, exact: bool) -> void:
	var table: Dictionary = ItemDB.LOOT_TABLES.get(id, {})
	var head := HBoxContainer.new()
	_right.add_child(head)
	var title := UITheme.heading("Drops", 15)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var gold: Array = table.get("gold", [0, 0])
	head.add_child(UITheme.label("%d-%d gold a level" % [gold[0], gold[1]] if int(gold[1]) > 0 else "no gold", 13, UITheme.GOLD))
	var drops := HFlowContainer.new()
	drops.add_theme_constant_override("h_separation", 6)
	drops.add_theme_constant_override("v_separation", 6)
	drops.custom_minimum_size.x = 384.0
	_right.add_child(drops)
	for entry: Dictionary in table.get("materials", []):
		if ItemDB.ITEMS.has(entry["id"]):
			drops.add_child(_item_chip(entry["id"], "%d%%" % roundi(entry["chance"] * 100.0) if exact else "?%"))
	for entry: Array in table.get("gear", []):
		if ItemDB.ITEMS.has(entry[0]):
			drops.add_child(_item_chip(entry[0], ("%.1f%%" % (float(entry[1]) * 100.0)) if exact else "?%"))
	if drops.get_child_count() == 0:
		drops.add_child(UITheme.label("Nothing but what it carries in gold.", 13, UITheme.DIM))
	var wild: bool = EnemyDB.ENEMIES[id].has("wild")
	if not wild:
		_say("[color=#%s]Elites and stronger of its kind drop far more gear, and now and then gems and runes.%s[/color]" % [UITheme.DIM.to_html(false),
			"" if exact else " Exact chances: slay %d." % Codex.REVEAL["drops"]])


## What each kill count reveals: [kills, what].
static func _reveal_steps() -> Array:
	return [[Codex.REVEAL["name"], "Name and lore"], [Codex.REVEAL["weakness"], "Weaknesses"], [Codex.REVEAL["drops"], "What it leaves behind"], [Codex.REVEAL["mark"], "Hunter's Mark"]]


func _reveal_row(what: String, when: String, open: bool, locked: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(StateMark.make("locked" if locked else "ready", 16))
	var name_label := UITheme.label(what, 15, UITheme.DIM if locked else UITheme.TEXT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var when_label := UITheme.label(when, 14, UITheme.DIM if locked else UITheme.GOLD if open else UITheme.TEXT)
	when_label.custom_minimum_size.x = 90.0
	when_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(when_label)
	return row


## The Hunter's Mark badge: a gold crosshair in a dark ring.
func _draw_mark(mark: Control) -> void:
	var middle := mark.size / 2.0
	mark.draw_circle(middle, 10.5, Color(0.05, 0.04, 0.02, 0.9))
	mark.draw_arc(middle, 9.0, 0.0, TAU, 20, UITheme.GOLD, 2.0)
	mark.draw_arc(middle, 4.0, 0.0, TAU, 12, UITheme.GOLD, 1.5)
	for direction: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		mark.draw_line(middle + direction * 5.5, middle + direction * 11.0, UITheme.GOLD, 2.0)


## What the creature fights with, what hurts it and what it shrugs off,
## as coloured chips.
func _element_row(id: String) -> Control:
	var info: Dictionary = Elements.MONSTERS.get(id, {})
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	for group: Array in [["Attacks with", [info["attack"]] if info.has("attack") else []], ["Weak to", info.get("weak", [])], ["Resists", info.get("hardy", [])]]:
		if (group[1] as Array).is_empty():
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var title := UITheme.label(group[0], 14, UITheme.DIM)
		title.custom_minimum_size.x = 96.0
		row.add_child(title)
		for element: String in group[1]:
			var chip := PanelContainer.new()
			var style := StyleBoxFlat.new()
			style.bg_color = Elements.color(element).darkened(0.7)
			style.border_color = Elements.color(element)
			style.set_border_width_all(1)
			style.set_corner_radius_all(3)
			style.set_content_margin_all(3)
			style.content_margin_left = 8
			style.content_margin_right = 8
			chip.add_theme_stylebox_override("panel", style)
			chip.add_child(UITheme.label(Elements.name_of(element), 14, Elements.color(element)))
			row.add_child(chip)
		box.add_child(row)
	if box.get_child_count() == 0:
		box.add_child(UITheme.label("No weakness and no resistance.", 14, UITheme.DIM))
	return box


## An item's picture in a slot with a word beside it; hover for the item.
func _item_chip(item_id: String, words: String, dim: bool = false) -> Control:
	var item := Item.create(item_id)
	var chip := Panel.new()
	chip.custom_minimum_size = Vector2(92, 38)
	chip.add_theme_stylebox_override("panel", ItemGrid.frame_style(null if dim else item, false))
	var picture := TextureRect.new()
	picture.texture = item.icon()
	picture.modulate = Color(0.03, 0.03, 0.06) if dim else item.icon_tint()
	picture.position = Vector2(4, 4)
	picture.size = Vector2(30, 30)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(picture)
	var label := UITheme.label(words, 13, UITheme.DIM if dim else UITheme.TEXT)
	label.position = Vector2(40, 9)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(label)
	if not dim:
		chip.mouse_entered.connect(func() -> void: _tip.show_item(item, player))
		chip.mouse_exited.connect(func() -> void: _tip.hide_tip())
	return chip


func _achievements(codex: Codex) -> void:
	var count := 0
	var gold := 0
	for achievement in Codex.ACHIEVEMENTS:
		if codex.is_done(achievement["id"]):
			count += 1
			gold += int(achievement.get("gold", 0))
	_left.add_child(UITheme.label("%d of %d earned" % [count, Codex.ACHIEVEMENTS.size()], 14, UITheme.DIM))
	# Earned ones first, then the nearest to done.
	var order: Array = Codex.ACHIEVEMENTS.duplicate()
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var done_a := codex.is_done(a["id"])
		var done_b := codex.is_done(b["id"])
		if done_a != done_b:
			return done_a
		return float(codex.progress(a)) / a["goal"] > float(codex.progress(b)) / b["goal"]
	)
	var words := _search.text.strip_edges().to_lower()
	for achievement: Dictionary in order:
		var done := codex.is_done(achievement["id"])
		var progress := codex.progress(achievement)
		var goal: int = achievement["goal"]
		if (_filter == "earned" and not done) or (_filter == "progress" and (done or progress <= 0)):
			continue
		if words != "" and not (str(achievement["name"]) + " " + str(achievement["text"])).to_lower().contains(words):
			continue
		var card := Control.new()
		card.custom_minimum_size = Vector2(516, 58)
		card.draw.connect(func() -> void:
			var font := UITheme.get_theme().default_font
			var rect := Rect2(Vector2.ZERO, card.size)
			card.draw_rect(rect, Color("1c1a12") if done else Color("151823"))
			card.draw_rect(rect, UITheme.GOLD if done else Color("3a3e50"), false, 2.0 if done else 1.0)
			# A medal: bright when earned, a dull blank when not.
			var medal := Vector2(29, 29)
			card.draw_circle(medal, 19.0, Color("403020"))
			card.draw_circle(medal, 16.0, Color("f0cf6a") if done else Color("3a3e50"))
			card.draw_circle(medal, 11.0, Color("c09a3c") if done else Color("2a2c38"))
			if done:
				card.draw_colored_polygon(PackedVector2Array([medal + Vector2(0, -9), medal + Vector2(2.6, -3), medal + Vector2(9, -3), medal + Vector2(4, 1.4), medal + Vector2(6, 8),
					medal + Vector2(0, 4), medal + Vector2(-6, 8), medal + Vector2(-4, 1.4), medal + Vector2(-9, -3), medal + Vector2(-2.6, -3)]), Color("fff4c0"))
			card.draw_string(UITheme.bold(), Vector2(58, 20), achievement["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UITheme.HEADING if done else UITheme.TEXT)
			card.draw_string(font, Vector2(58, 37), achievement["text"], HORIZONTAL_ALIGNMENT_LEFT, 300.0, 13, UITheme.TEXT if done else UITheme.DIM)
			var rewards: PackedStringArray = ["%d gold" % achievement.get("gold", 0)]
			if achievement.has("title"):
				rewards.append("title")
			if achievement.has("skin"):
				rewards.append("look")
			card.draw_string(font, Vector2(card.size.x - 160.0, 20), ", ".join(rewards), HORIZONTAL_ALIGNMENT_RIGHT, 150.0, 12, UITheme.GOLD if done else UITheme.DIM)
			var track := Rect2(58, 44, card.size.x - 190.0, 7)
			card.draw_rect(track, Color(0.03, 0.035, 0.06))
			card.draw_rect(Rect2(track.position, Vector2(track.size.x * minf(float(progress) / goal, 1.0), track.size.y)), UITheme.GOLD if done else Color("5a8ad0"))
			card.draw_string(font, Vector2(card.size.x - 126.0, 52), "%d / %d" % [mini(progress, goal), goal], HORIZONTAL_ALIGNMENT_RIGHT, 116.0, 12, UITheme.GOOD if done else UITheme.TEXT)
		)
		_left.add_child(card)
	_say("[font_size=20][color=#%s]Achievements[/color][/font_size]\n\nEach pays gold when earned: [color=#%s]%d gold[/color] so far.\n\nSome grant a title to wear beside your level (choose it below), and a few unlock a whole new look in the Wardrobe." % [
		UITheme.HEADING.to_html(false), UITheme.GOLD.to_html(false), gold])
	_right.add_child(UITheme.rule())
	_right.add_child(UITheme.heading("Title", 18))
	var titles := codex.titles()
	if titles.is_empty():
		_say("[color=#%s]No titles yet. Achievements marked \"title\" give one.[/color]" % UITheme.DIM.to_html(false))
	else:
		_say("Shown beside your level. %d earned." % titles.size())
		_title_pick = OptionButton.new()
		_title_pick.custom_minimum_size = Vector2(300, 34)
		_title_pick.add_item("(none)")
		for title: String in titles:
			_title_pick.add_item(title)
			if title == codex.title:
				_title_pick.select(_title_pick.item_count - 1)
		_title_pick.item_selected.connect(func(index: int) -> void:
			_codex().title = "" if index == 0 else _title_pick.get_item_text(index)
			SaveGame.request_save()
		)
		_right.add_child(_title_pick)


## The monsters' factions and what each believes about how the player
## fights (see Factions): pick one for what it knows and how it readies.
func _factions(codex: Codex) -> void:
	var factions: Factions = player.get_parent().get_node_or_null("Factions")
	if factions == null:
		return
	_left.add_child(UITheme.label("What the monsters have learned of you", 15, UITheme.TEXT))
	for id: String in Factions.LIST:
		var data: Dictionary = Factions.LIST[id]
		var met := (data["members"] as Array).any(func(kind: String) -> bool: return codex.kills_of(kind) > 0)
		var button := Button.new()
		button.custom_minimum_size = Vector2(520, 58)
		for state: String in ["normal", "pressed"]:
			button.add_theme_stylebox_override(state, UITheme.card("card_selected" if id == _picked else ("card" if met else "card_dim"), 8))
		button.add_theme_stylebox_override("hover", UITheme.card("card_selected" if id == _picked else "card_hover", 8))
		button.add_theme_stylebox_override("focus", UITheme.focus_box())
		button.pressed.connect(func() -> void:
			_picked = id
			refresh()
		)
		var lines := VBoxContainer.new()
		lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lines.add_theme_constant_override("separation", 0)
		lines.position = Vector2(12, 6)
		button.add_child(lines)
		var name := UITheme.strong(data["name"] if met else "An unknown faction", 16, data["color"] if met else UITheme.DIM)
		name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lines.add_child(name)
		var view := UITheme.label(factions.describe(id) if met else "Meet its kind to learn of it.", 13, UITheme.TEXT if met else UITheme.DIM)
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lines.add_child(view)
		_left.add_child(button)
	if not Factions.LIST.has(_picked):
		_right.add_child(UITheme.heading("Word gets around", 20))
		_say("Monsters remember the blows they live through, and warn their kin nearby. Those that [color=#%s]get away alive[/color] tell their faction, and the next ones come ready:" % UITheme.GOLD.to_html(false))
		_say("· Up close: more come [color=#8cc8ff]shielded[/color].\n· From afar: they come [color=#8cc8ff]spread out[/color], weaving.\n· Sorcery or an element: they come [color=#8cc8ff]warded[/color] against it.")
		_say("Hunt down the ones that flee, or let them go on purpose: a faction only knows what it was shown. Ready for an archer, it is [color=#%s]caught off guard[/color] by a blade (and the other way about)." % UITheme.GOLD.to_html(false))
		_say("[color=#%s]Keep away from a faction and it forgets: a quarter of what it knows for every day you do not meet.[/color]" % UITheme.DIM.to_html(false))
		return
	var data: Dictionary = Factions.LIST[_picked]
	_right.add_child(UITheme.heading(data["name"], 20))
	var kinds: PackedStringArray = []
	for kind: String in data["members"]:
		kinds.append(EnemyDB.ENEMIES[kind]["name"] if codex.kills_of(kind) > 0 else "???")
	_say("[color=#%s]%s[/color]" % [UITheme.DIM.to_html(false), ", ".join(kinds)])
	_say(factions.describe(_picked))
	_right.add_child(UITheme.heading("How they think you fight", 16))
	for style: String in Factions.STYLES:
		_knowledge_bar("Fights %s" % Factions.STYLE_NAMES[style], factions.knows(_picked, "styles", style), data["color"])
	var elements: Array = []
	for element: String in Elements.LIST + ["storm"]:
		if factions.knows(_picked, "elements", element) > 0.0:
			elements.append(element)
	if not elements.is_empty():
		_right.add_child(UITheme.heading("What they fear", 16))
		for element: String in elements:
			_knowledge_bar(element.capitalize(), factions.knows(_picked, "elements", element), Elements.color(element))
	var belief := factions.belief(_picked)
	if belief != "":
		var other: Array = Factions.STYLES.filter(func(style: String) -> bool: return style != belief)
		_say("[color=#%s]Fight them %s or %s and the first blow on each catches them off guard.[/color]" % [UITheme.GOLD.to_html(false), Factions.STYLE_NAMES[other[0]], Factions.STYLE_NAMES[other[1]]])


## A labelled bar showing how sure a faction is of something.
func _knowledge_bar(title: String, share: float, tint: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var name := UITheme.label(title, 14, UITheme.TEXT)
	name.custom_minimum_size.x = 150.0
	row.add_child(name)
	var back := ColorRect.new()
	back.color = Color(0.05, 0.06, 0.1)
	back.custom_minimum_size = Vector2(160, 10)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := ColorRect.new()
	fill.color = tint
	fill.size = Vector2(roundf(158.0 * share), 8)
	fill.position = Vector2(1, 1)
	back.add_child(fill)
	row.add_child(back)
	row.add_child(UITheme.label("%d%%" % roundi(share * 100.0), 13, UITheme.DIM))
	_right.add_child(row)


func _collection(codex: Codex) -> void:
	_left.add_child(UITheme.heading("Lands discovered (%d)" % codex.biomes.size(), 16))
	var lands := UITheme.label(", ".join(codex.biomes) if not codex.biomes.is_empty() else "None yet.", 14)
	lands.autowrap_mode = TextServer.AUTOWRAP_WORD
	lands.custom_minimum_size.x = 510.0
	_left.add_child(lands)
	# What has been gathered and caught, as pictures; the unfound stay dark.
	var gathered: Array = []
	for id: String in GatherDB.RESOURCES:
		var data: Dictionary = GatherDB.RESOURCES[id]
		if data["kind"] != "fish":
			gathered.append([data["item"], int(codex.gathered.get(id, 0))])
	_collection_grid("Gathered", gathered)
	var fish: Array = []
	for entry in GatherDB.FISH:
		fish.append([entry[0], int(codex.caught.get(entry[0], 0))])
	_collection_grid("Caught", fish)
	var stats := codex.stats
	var lines: PackedStringArray = ["[font_size=20][color=#%s]Your deeds[/color][/font_size]" % UITheme.HEADING.to_html(false), ""]
	for row: Array in [["Monsters slain", "kills"], ["Elites", "elites"], ["Champions", "champions"], ["World bosses beaten", "bosses"], ["Named monsters slain", "named"], ["Crypts cleared", "dungeons"], ["Void portals closed", "portals"],
			["Bounties collected", "bounties"], ["Raids repelled", "raids"], ["Crops harvested", "harvests"], ["Things crafted", "crafted"], ["Parries", "parries"], ["Finishers", "finishers"],
			["Pets tamed", "pets"], ["Caves explored", "caves"]]:
		lines.append("[color=#%s]%s[/color]   [color=#%s]%d[/color]" % [UITheme.DIM.to_html(false), row[0], UITheme.TEXT.to_html(false), int(stats.get(row[1], 0))])
	_say("\n".join(lines))


## A heading and a wall of item chips with counts: [[item id, count], ...].
func _collection_grid(title: String, entries: Array) -> void:
	var found := 0
	for entry: Array in entries:
		if entry[1] > 0:
			found += 1
	_left.add_child(UITheme.heading("%s (%d of %d)" % [title, found, entries.size()], 16))
	var grid := HFlowContainer.new()
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	grid.custom_minimum_size.x = 520.0
	_left.add_child(grid)
	for entry: Array in entries:
		grid.add_child(_item_chip(entry[0], "x%d" % entry[1] if entry[1] > 0 else "?", entry[1] == 0))
