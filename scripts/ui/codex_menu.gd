class_name CodexMenu
extends GameMenu
## The Codex: a bestiary of every creature met (a wall of portraits, dark
## until first slain), achievements and titles, and a record of what has
## been gathered, caught and done.

const TILE := Vector2(78, 92)

var _tab := "bestiary"
var _tabs: Dictionary = {}
var _left: VBoxContainer
var _right: VBoxContainer
var _picked := ""
var _title_pick: OptionButton
var _tip: ItemTooltip


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
	for tab: Array in [["bestiary", "Bestiary"], ["achievements", "Achievements"], ["collection", "Collection"]]:
		var button := UITheme.button(tab[1], func() -> void:
			_tab = tab[0]
			_picked = ""
			refresh()
		, 160.0)
		button.toggle_mode = true
		tabs.add_child(button)
		_tabs[tab[0]] = button
	tabs.add_child(UITheme.label("   Title:", 15, UITheme.DIM))
	_title_pick = OptionButton.new()
	_title_pick.custom_minimum_size = Vector2(200, 34)
	_title_pick.focus_mode = Control.FOCUS_NONE
	_title_pick.item_selected.connect(func(index: int) -> void:
		_codex().title = "" if index == 0 else _title_pick.get_item_text(index)
		SaveGame.request_save()
	)
	tabs.add_child(_title_pick)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	content.add_child(columns)
	var left_panel := UITheme.inset_panel()
	columns.add_child(left_panel)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(540, 440)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_panel.add_child(scroll)
	_left = VBoxContainer.new()
	_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left.add_theme_constant_override("separation", 6)
	scroll.add_child(_left)
	var right_panel := UITheme.inset_panel()
	columns.add_child(right_panel)
	var right_scroll := ScrollContainer.new()
	right_scroll.custom_minimum_size = Vector2(400, 440)
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
	for id: String in _tabs:
		_tabs[id].set_pressed_no_signal(id == _tab)
	_title_pick.clear()
	_title_pick.add_item("(none)")
	for title: String in codex.titles():
		_title_pick.add_item(title)
		if title == codex.title:
			_title_pick.select(_title_pick.item_count - 1)
	for child in _left.get_children() + _right.get_children():
		child.queue_free()
	match _tab:
		"bestiary":
			_bestiary(codex)
		"achievements":
			_achievements(codex)
		_:
			_collection(codex)


## Words in the right-hand panel.
func _say(bbcode: String) -> void:
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.custom_minimum_size = Vector2(384, 0)
	text.add_theme_font_size_override("normal_font_size", 14)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.text = bbcode
	_right.add_child(text)


func _bestiary(codex: Codex) -> void:
	var known := 0
	for id: String in EnemyDB.ENEMIES:
		if codex.kills_of(id) > 0:
			known += 1
	_left.add_child(UITheme.label("%d of %d kinds known. Gold frames wear the Hunter's Mark." % [known, EnemyDB.ENEMIES.size()], 14, UITheme.DIM))
	for group: Array in [["Monsters", false], ["Beasts of the wild", true]]:
		_left.add_child(UITheme.heading(group[0], 16))
		var grid := HFlowContainer.new()
		grid.add_theme_constant_override("h_separation", 5)
		grid.add_theme_constant_override("v_separation", 5)
		grid.custom_minimum_size.x = 520.0
		_left.add_child(grid)
		for id: String in EnemyDB.ENEMIES:
			if EnemyDB.ENEMIES[id].has("wild") == group[1]:
				grid.add_child(_creature_tile(codex, id))
	if _picked == "":
		_say("[color=#%s]Slay a kind of creature to learn of it. More is revealed at %d, %d and %d kills; at %d you earn the Hunter's Mark, dealing 5%% more damage to that kind.[/color]" % [
			UITheme.DIM.to_html(false), Codex.REVEAL["weakness"], Codex.REVEAL["drops"], Codex.REVEAL["mark"], Codex.REVEAL["mark"]])
		return
	_creature_page(codex, _picked)


## One creature on the wall: its portrait (a shadow until slain) and count.
func _creature_tile(codex: Codex, id: String) -> Button:
	var kills := codex.kills_of(id)
	var marked := kills >= int(Codex.REVEAL["mark"])
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = TILE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1c1a12") if marked else Color("151823")
	style.border_color = Color.WHITE if id == _picked else UITheme.GOLD if marked else Color("3a3e50")
	style.set_border_width_all(3 if id == _picked else 2 if marked else 1)
	var hover := style.duplicate()
	hover.bg_color = style.bg_color.lightened(0.08)
	for state: String in ["normal", "pressed"]:
		button.add_theme_stylebox_override(state, style)
	button.add_theme_stylebox_override("hover", hover)
	var picture := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = EnemyDB.sheet(id)
	atlas.region = Rect2(16, 14, 64, 64)
	picture.texture = atlas
	picture.position = Vector2(7, 4)
	picture.size = Vector2(64, 64)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Unmet creatures are only a shape in the dark.
	picture.modulate = Color.WHITE if kills > 0 else Color(0.02, 0.02, 0.05)
	button.add_child(picture)
	var label := UITheme.label(str(kills) if kills > 0 else "?", 12, UITheme.GOLD if marked else UITheme.TEXT if kills > 0 else UITheme.DIM)
	label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	label.offset_top = -20.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(label)
	button.tooltip_text = EnemyDB.ENEMIES[id]["name"] if kills > 0 else "Not yet slain"
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
		_say("[font_size=22][color=#%s]???[/color][/font_size]\n\n[color=#%s]Not yet slain. Its shape is all you know.[/color]" % [UITheme.HEADING.to_html(false), UITheme.DIM.to_html(false)])
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
	if kills >= int(Codex.REVEAL["weakness"]):
		_say("[color=#%s]%s[/color]" % [UITheme.INFO.to_html(false), Elements.describe_monster(id)])
	else:
		_say("[color=#%s]Weaknesses: slay %d to learn.[/color]" % [UITheme.DIM.to_html(false), Codex.REVEAL["weakness"]])
	if kills >= int(Codex.REVEAL["drops"]):
		_right.add_child(UITheme.heading("Leaves behind", 15))
		var drops := HFlowContainer.new()
		drops.add_theme_constant_override("h_separation", 6)
		drops.add_theme_constant_override("v_separation", 6)
		drops.custom_minimum_size.x = 384.0
		_right.add_child(drops)
		for entry: Dictionary in (ItemDB.LOOT_TABLES.get(id, {}) as Dictionary).get("materials", []):
			drops.add_child(_item_chip(entry["id"], "%d%%" % roundi(entry["chance"] * 100.0)))
	else:
		_say("[color=#%s]What it leaves behind: slay %d to learn.[/color]" % [UITheme.DIM.to_html(false), Codex.REVEAL["drops"]])
	if kills >= goal:
		_say("[color=#%s]Hunter's Mark: you deal 5%% more damage to this kind.[/color]" % UITheme.GOLD.to_html(false))


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
	for achievement: Dictionary in order:
		var done := codex.is_done(achievement["id"])
		var progress := codex.progress(achievement)
		var goal: int = achievement["goal"]
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
	_say("[font_size=20][color=#%s]Achievements[/color][/font_size]\n\nEach pays gold when earned: [color=#%s]%d gold[/color] so far.\n\nSome grant a title to wear beside your level (choose it at the top), and a few unlock a whole new look in the Wardrobe." % [
		UITheme.HEADING.to_html(false), UITheme.GOLD.to_html(false), gold])
	var titles := codex.titles()
	if not titles.is_empty():
		_say("[color=#%s]Titles earned[/color]\n%s" % [UITheme.DIM.to_html(false), ", ".join(titles)])


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
	for row: Array in [["Monsters slain", "kills"], ["Elites", "elites"], ["Champions", "champions"], ["World bosses beaten", "bosses"], ["Crypts cleared", "dungeons"], ["Void portals closed", "portals"],
			["Bounties collected", "bounties"], ["Raids repelled", "raids"], ["Crops harvested", "harvests"], ["Things crafted", "crafted"], ["Parries", "parries"], ["Finishers", "finishers"],
			["Pets tamed", "pets"], ["Transformations", "transformations"], ["Caves explored", "caves"]]:
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
