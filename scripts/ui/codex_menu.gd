class_name CodexMenu
extends GameMenu
## The Codex: a bestiary of every monster met, achievements and titles,
## and a record of what has been gathered and where the player has been.

var _tab := "bestiary"
var _tabs: Dictionary = {}
var _left: VBoxContainer
var _details: RichTextLabel
var _portrait: TextureRect
var _picked := ""
var _title_pick: OptionButton


func _build() -> void:
	var title := UITheme.heading("CODEX", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
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
	scroll.custom_minimum_size = Vector2(520, 440)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_panel.add_child(scroll)
	_left = VBoxContainer.new()
	_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left.add_theme_constant_override("separation", 4)
	scroll.add_child(_left)
	var right_panel := UITheme.inset_panel()
	columns.add_child(right_panel)
	var right := VBoxContainer.new()
	right_panel.add_child(right)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(380, 150)
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	right.add_child(_portrait)
	_details = RichTextLabel.new()
	_details.bbcode_enabled = true
	_details.custom_minimum_size = Vector2(380, 290)
	_details.add_theme_font_size_override("normal_font_size", 15)
	right.add_child(_details)


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
	for child in _left.get_children():
		child.queue_free()
	_portrait.texture = null
	match _tab:
		"bestiary":
			_bestiary(codex)
		"achievements":
			_achievements(codex)
		_:
			_collection(codex)


func _bestiary(codex: Codex) -> void:
	var known := 0
	for id: String in EnemyDB.ENEMIES:
		var kills := codex.kills_of(id)
		if kills > 0:
			known += 1
		var name: String = EnemyDB.ENEMIES[id]["name"] if kills > 0 else "???"
		var button := UITheme.button("  %s   -   %d slain" % [name, kills], func() -> void:
			_picked = id
			refresh()
		, 490.0)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if kills >= Codex.REVEAL["mark"]:
			button.add_theme_color_override("font_color", UITheme.GOLD)
		_left.add_child(button)
	_left.move_child(UITheme.label("%d of %d kinds known" % [known, EnemyDB.ENEMIES.size()], 14, UITheme.DIM), 0)
	if _picked == "":
		_details.text = "[color=#%s]Slay a kind of monster to learn of it. More is revealed at 10, 25 and 50 kills; at 50 you earn the Hunter's Mark, dealing 5%% more damage to that kind.[/color]" % UITheme.DIM.to_html(false)
		return
	var data: Dictionary = EnemyDB.ENEMIES[_picked]
	var kills := codex.kills_of(_picked)
	if kills == 0:
		_details.text = "[color=#%s]Not yet slain.[/color]" % UITheme.DIM.to_html(false)
		return
	var atlas := AtlasTexture.new()
	atlas.atlas = EnemyDB.sheet(_picked)
	atlas.region = Rect2(16, 10, 70, 70)
	_portrait.texture = atlas
	var lines: PackedStringArray = []
	lines.append("[font_size=22][color=#%s]%s[/color][/font_size]" % [UITheme.HEADING.to_html(false), data["name"]])
	lines.append("[i]%s[/i]" % Codex.LORE.get(_picked, ""))
	lines.append("")
	lines.append("Slain: %d" % kills)
	lines.append("Roams: %s, from level %d. %s." % [", ".join((data["tiles"] as Array).slice(0, 4).map(func(t: int) -> String: return TerrainTiles.display_name(t))), data["min_level"], {"night": "Comes out at night", "day": "Roams by day", "always": "Day and night"}[data.get("active", "night")]])
	if kills >= Codex.REVEAL["weakness"]:
		lines.append("[color=#%s]%s[/color]" % [UITheme.INFO.to_html(false), Elements.describe_monster(_picked)])
	else:
		lines.append("[color=#%s]Weaknesses: slay %d to learn.[/color]" % [UITheme.DIM.to_html(false), Codex.REVEAL["weakness"]])
	if kills >= Codex.REVEAL["drops"]:
		var table: Dictionary = ItemDB.LOOT_TABLES.get(_picked, {})
		var drops: PackedStringArray = []
		for entry: Dictionary in table.get("materials", []):
			drops.append("%s (%d%%)" % [ItemDB.ITEMS[entry["id"]]["name"], roundi(entry["chance"] * 100.0)])
		lines.append("Drops: " + ", ".join(drops))
	else:
		lines.append("[color=#%s]Drops: slay %d to learn.[/color]" % [UITheme.DIM.to_html(false), Codex.REVEAL["drops"]])
	if kills >= Codex.REVEAL["mark"]:
		lines.append("[color=#%s]Hunter's Mark: +5%% damage to this kind.[/color]" % UITheme.GOLD.to_html(false))
	else:
		lines.append("[color=#%s]Hunter's Mark at %d kills.[/color]" % [UITheme.DIM.to_html(false), Codex.REVEAL["mark"]])
	_details.text = "\n".join(lines)


func _achievements(codex: Codex) -> void:
	var count := 0
	for achievement in Codex.ACHIEVEMENTS:
		var done := codex.is_done(achievement["id"])
		if done:
			count += 1
		var row := VBoxContainer.new()
		var head := UITheme.heading(("[x] " if done else "[ ] ") + achievement["name"], 16)
		if not done:
			head.add_theme_color_override("font_color", UITheme.DIM)
		row.add_child(head)
		var extra := ""
		if achievement.has("title"):
			extra += "   Title: %s" % achievement["title"]
		if achievement.has("skin"):
			extra += "   Look: %s" % Appearance.LOOKS[achievement["skin"]]["name"]
		row.add_child(UITheme.label("%s   (%d / %d)%s" % [achievement["text"], codex.progress(achievement), achievement["goal"], extra], 13, UITheme.GOOD if done else UITheme.TEXT))
		var bar := ProgressBar.new()
		bar.max_value = achievement["goal"]
		bar.value = codex.progress(achievement)
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(480, 6)
		row.add_child(bar)
		_left.add_child(row)
	_left.move_child(UITheme.label("%d of %d achievements" % [count, Codex.ACHIEVEMENTS.size()], 14, UITheme.DIM), 0)
	_details.text = "[font_size=20][color=#%s]Achievements[/color][/font_size]\n\nEach pays gold when earned. Some grant a title to wear (choose it above), and a few unlock a new look in the Wardrobe." % UITheme.HEADING.to_html(false)


func _collection(codex: Codex) -> void:
	_left.add_child(UITheme.heading("Lands discovered (%d)" % codex.biomes.size(), 17))
	_left.add_child(UITheme.label(", ".join(codex.biomes) if not codex.biomes.is_empty() else "None yet.", 14))
	_left.add_child(UITheme.heading("Gathered", 17))
	for id: String in GatherDB.RESOURCES:
		var times: int = codex.gathered.get(id, 0)
		_left.add_child(UITheme.label("%s   %s" % [GatherDB.display_name(id) if times > 0 else "???", "x%d" % times if times > 0 else ""], 14, UITheme.TEXT if times > 0 else UITheme.DIM))
	var stats := codex.stats
	_details.text = "[font_size=20][color=#%s]Your deeds[/color][/font_size]\n\nMonsters slain: %d\nWorld bosses beaten: %d\nCrypts cleared: %d\nBounties collected: %d\nRaids repelled: %d\nCrops harvested: %d\nThings crafted: %d\nParries: %d    Finishers: %d" % [
		UITheme.HEADING.to_html(false), stats.get("kills", 0), stats.get("bosses", 0), stats.get("dungeons", 0), stats.get("bounties", 0), stats.get("raids", 0),
		stats.get("harvests", 0), stats.get("crafted", 0), stats.get("parries", 0), stats.get("finishers", 0)]
