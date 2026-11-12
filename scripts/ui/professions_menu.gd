class_name ProfessionsMenu
extends GameMenu
## The professions: each one's level on the left. In the middle, the chosen
## profession's level and experience, and its recipes (or, for gathering,
## what it can gather) grouped and marked ready, missing something, or
## locked, with a filter and a search; or what it knows so far. On the right,
## the chosen recipe: a large picture, what it does, every ingredient with
## how many you hold, and how many to make.

const FILTERS: Array[String] = ["All recipes", "Can make now", "Missing materials", "Locked"]
const ROW := 44.0

var _rows: Dictionary[String, Dictionary] = {}
var _selected := "cooking"
var _tab := "recipes"
var _filter := 0
var _search := ""
var _quantity := 1
var _recipe: Dictionary = {}
var _tip: ItemTooltip

# Middle.
var _icon: TextureRect
var _name: Label
var _level: Label
var _xp_bar: Control
var _tabs: Dictionary[String, Button] = {}
var _filter_pick: OptionButton
var _search_field: LineEdit
var _list: VBoxContainer
# Right.
var _picture: TextureRect
var _title: Label
var _kind: Label
var _text: Label
var _effects: VBoxContainer
var _needs: VBoxContainer
var _produce_icon: TextureRect
var _produce_name: Label
var _amount: Label
var _craft: Button
var _craft_all: Button
var _message: Label
var _detail: VBoxContainer
var _empty: Label

## Pictures of what recipes make, by recipe id.
static var _samples: Dictionary = {}


## An item like the one a recipe makes, for its picture and words.
static func sample(recipe: Dictionary) -> Item:
	if not _samples.has(recipe["id"]):
		_samples[recipe["id"]] = LootGenerator.make_equipment(recipe.get("item_level", 1), 0, recipe["equipment"]) if recipe.has("equipment") else Item.create(recipe["item"])
	return _samples[recipe["id"]]


## The group a recipe is listed under.
static func section(recipe: Dictionary) -> String:
	if recipe.has("equipment"):
		return "Arms & armour"
	var item := sample(recipe)
	if item.is_placeable():
		return "Buildings & furniture"
	var use: Dictionary = item.definition().get("use", {})
	if use.get("buff", "") == "food":
		return "Meals"
	if item.is_consumable():
		return "Potions & remedies"
	if item.is_tool() or item.is_backpack():
		return "Tools & packs"
	return "Materials"


## Whether a recipe can be made now: "ready", "missing" or "locked".
func state_of(recipe: Dictionary) -> String:
	if player.professions.level(recipe["profession"]) < recipe["level"]:
		return "locked"
	for item_id: String in recipe["inputs"]:
		if player.inventory.count_of(item_id) < recipe["inputs"][item_id]:
			return "missing"
	return "ready"


func _build() -> void:
	var title := UITheme.heading("PROFESSIONS", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	_tip = ItemTooltip.new()
	add_child(_tip)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 12)
	content.add_child(columns)

	# --- left: every profession
	var left_panel := UITheme.inset_panel()
	columns.add_child(left_panel)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 4)
	left_panel.add_child(left)
	for group: Array in [["Gathering", Professions.GATHERING], ["Crafting", Professions.CRAFTING]]:
		left.add_child(UITheme.heading(group[0], 17))
		for id: String in group[1]:
			var button := Button.new()
			button.toggle_mode = true
			button.focus_mode = Control.FOCUS_NONE
			button.custom_minimum_size = Vector2(250.0, 42.0)
			button.pressed.connect(_select.bind(id))
			UITheme.sounds(button)
			left.add_child(button)
			var picture := TextureRect.new()
			picture.texture = ItemDB.icon(Professions.ICONS[id])
			picture.position = Vector2(8, 6)
			picture.size = Vector2(30, 30)
			picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(picture)
			var name_label := UITheme.label(Professions.NAMES[id], 16)
			name_label.position = Vector2(46, 10)
			name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(name_label)
			var level_label := UITheme.label("", 14, UITheme.GOLD)
			level_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
			level_label.offset_left = -86.0
			level_label.offset_right = -10.0
			level_label.offset_top = 11.0
			level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(level_label)
			_rows[id] = {"button": button, "level": level_label}

	# --- middle: the chosen profession
	var middle_panel := UITheme.inset_panel()
	columns.add_child(middle_panel)
	var middle := VBoxContainer.new()
	middle.add_theme_constant_override("separation", 8)
	middle.custom_minimum_size.x = 390.0
	middle_panel.add_child(middle)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	middle.add_child(head)
	_icon = UITheme.icon(48, 40.0)
	head.add_child(_icon)
	_name = UITheme.heading("", 22)
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_name)
	_level = UITheme.label("", 15, UITheme.TEXT)
	head.add_child(_level)
	_xp_bar = Control.new()
	_xp_bar.custom_minimum_size = Vector2(390.0, 20.0)
	_xp_bar.draw.connect(_draw_xp)
	middle.add_child(_xp_bar)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	middle.add_child(tabs)
	for tab: Array in [["recipes", "Recipes"], ["knowledge", "Knowledge"]]:
		var button := Button.new()
		button.text = tab[1]
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(192.0, 34.0)
		button.add_theme_font_size_override("font_size", 16)
		button.pressed.connect(func() -> void:
			_tab = tab[0]
			refresh()
		)
		UITheme.sounds(button)
		tabs.add_child(button)
		_tabs[tab[0]] = button
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 6)
	middle.add_child(filters)
	_filter_pick = OptionButton.new()
	_filter_pick.focus_mode = Control.FOCUS_NONE
	_filter_pick.custom_minimum_size = Vector2(176.0, 32.0)
	for words in FILTERS:
		_filter_pick.add_item(words)
	_filter_pick.item_selected.connect(func(index: int) -> void:
		_filter = index
		refresh()
	)
	filters.add_child(_filter_pick)
	_search_field = LineEdit.new()
	_search_field.placeholder_text = "Search recipes..."
	_search_field.custom_minimum_size = Vector2(208.0, 32.0)
	_search_field.clear_button_enabled = true
	_search_field.text_changed.connect(func(text: String) -> void:
		_search = text.strip_edges().to_lower()
		refresh()
	)
	filters.add_child(_search_field)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(390.0, 318.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	middle.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	# --- right: the chosen recipe
	var right_panel := UITheme.inset_panel()
	columns.add_child(right_panel)
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(372.0, 0.0)
	right_panel.add_child(right)
	_empty = UITheme.label("", 15, UITheme.DIM)
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD
	_empty.custom_minimum_size = Vector2(372.0, 0.0)
	right.add_child(_empty)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 6)
	right.add_child(_detail)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	_detail.add_child(top)
	var plate := Control.new()
	plate.custom_minimum_size = Vector2(108.0, 100.0)
	plate.draw.connect(func() -> void:
		plate.draw_set_transform(Vector2(54, 84), 0.0, Vector2(1.0, 0.32))
		plate.draw_circle(Vector2.ZERO, 46.0, Color("2a2c36"))
		plate.draw_circle(Vector2.ZERO, 38.0, Color("3a3c48"))
		plate.draw_set_transform(Vector2.ZERO)
	)
	top.add_child(plate)
	_picture = TextureRect.new()
	_picture.position = Vector2(14, 0)
	_picture.size = Vector2(80, 80)
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	plate.add_child(_picture)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(words)
	_title = UITheme.heading("", 22)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD
	_title.custom_minimum_size.x = 250.0
	words.add_child(_title)
	_kind = UITheme.label("", 14, UITheme.DIM)
	words.add_child(_kind)
	_text = UITheme.label("", 14, Color("c8bfae"))
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	_text.custom_minimum_size.x = 250.0
	words.add_child(_text)
	_effects = VBoxContainer.new()
	_effects.add_theme_constant_override("separation", 2)
	_detail.add_child(_effects)
	var needs_head := HBoxContainer.new()
	_detail.add_child(needs_head)
	var needs_title := UITheme.heading("Ingredients", 16)
	needs_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	needs_head.add_child(needs_title)
	needs_head.add_child(UITheme.label("Owned / Needed", 14, UITheme.DIM))
	_needs = VBoxContainer.new()
	_needs.add_theme_constant_override("separation", 3)
	_detail.add_child(_needs)
	_detail.add_child(UITheme.heading("Produces", 16))
	var produce := HBoxContainer.new()
	produce.add_theme_constant_override("separation", 8)
	_detail.add_child(produce)
	_produce_icon = UITheme.icon(0, 34.0)
	produce.add_child(_produce_icon)
	_produce_name = UITheme.label("", 15)
	_produce_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_produce_name.clip_text = true
	produce.add_child(_produce_name)
	produce.add_child(UITheme.button("-", func() -> void: _step(-1), 34.0))
	_amount = UITheme.label("1", 17)
	_amount.custom_minimum_size.x = 34.0
	_amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	produce.add_child(_amount)
	produce.add_child(UITheme.button("+", func() -> void: _step(1), 34.0))
	_message = UITheme.label("", 14, UITheme.BAD)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD
	_message.custom_minimum_size = Vector2(372.0, 20.0)
	right.add_child(_message)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(spacer)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	right.add_child(buttons)
	_craft = UITheme.button("Craft", func() -> void: _make(_quantity), 200.0)
	_craft.custom_minimum_size.y = 42.0
	_craft.add_theme_font_size_override("font_size", 18)
	_craft.expand_icon = false
	buttons.add_child(_craft)
	_craft_all = UITheme.button("Craft all", func() -> void: _make(_most()), 164.0)
	_craft_all.custom_minimum_size.y = 42.0
	buttons.add_child(_craft_all)

	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree():
			_tip.hide_tip()
	)
	player.professions.changed.connect(refresh_if_open)
	player.inventory.changed.connect(refresh_if_open)


func refresh() -> void:
	var professions := player.professions
	for id in _rows:
		var level := professions.level(id)
		(_rows[id]["button"] as Button).set_pressed_no_signal(id == _selected)
		(_rows[id]["level"] as Label).text = "Lv %d / %d" % [level, Professions.MAX_LEVEL]
	_icon.texture = ItemDB.icon(Professions.ICONS[_selected])
	_name.text = Professions.NAMES[_selected]
	_level.text = "Level %d / %d" % [professions.level(_selected), Professions.MAX_LEVEL]
	_xp_bar.queue_redraw()
	var gathering := _selected in Professions.GATHERING
	_tabs["recipes"].text = "Gathers" if gathering else "Recipes"
	for id in _tabs:
		_tabs[id].set_pressed_no_signal(id == _tab)
	_filter_pick.get_parent().visible = _tab == "recipes" and not gathering
	for child in _list.get_children():
		child.queue_free()
	if _recipe.is_empty() or _recipe["profession"] != _selected:
		_recipe = {}
	if _tab == "knowledge":
		_list_knowledge()
	elif gathering:
		_list_resources()
	else:
		_list_recipes()
	_show_recipe()


func _draw_xp() -> void:
	var professions := player.professions
	var level := professions.level(_selected)
	var need := Professions.xp_required(level)
	var have: float = professions.xp[_selected]
	var maxed := level >= Professions.MAX_LEVEL
	var rect := Rect2(Vector2.ZERO, _xp_bar.size)
	_xp_bar.draw_rect(rect, Color(0.03, 0.035, 0.06))
	var share := 1.0 if maxed else clampf(have / maxf(need, 1.0), 0.0, 1.0)
	_xp_bar.draw_rect(Rect2(rect.position + Vector2(2, 2), Vector2((rect.size.x - 4.0) * share, rect.size.y - 4.0)), Color("d9a441"))
	_xp_bar.draw_rect(Rect2(rect.position + Vector2(2, 2), Vector2((rect.size.x - 4.0) * share, (rect.size.y - 4.0) * 0.4)), Color("f0d28a"))
	_xp_bar.draw_rect(rect, Color("8a683a"), false, 1.5)
	var font := UITheme.get_theme().default_font
	var words := "Mastered" if maxed else "%d / %d XP" % [roundi(have), roundi(need)]
	_xp_bar.draw_string_outline(font, Vector2(0, 15), words, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 14, 4, Color.BLACK)
	_xp_bar.draw_string(font, Vector2(0, 15), words, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 14, Color.WHITE)


## A centred section name with rules either side.
func _section(words: String) -> void:
	var line := Control.new()
	line.custom_minimum_size = Vector2(370.0, 24.0)
	line.draw.connect(func() -> void:
		var font := UITheme.get_theme().default_font
		var width := font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		var middle := line.size.x / 2.0
		line.draw_line(Vector2(20, 12), Vector2(middle - width / 2.0 - 10.0, 12), Color("8a683a"), 1.0)
		line.draw_line(Vector2(middle + width / 2.0 + 10.0, 12), Vector2(line.size.x - 20.0, 12), Color("8a683a"), 1.0)
		line.draw_string(font, Vector2(0, 17), words, HORIZONTAL_ALIGNMENT_CENTER, line.size.x, 15, UITheme.HEADING)
	)
	_list.add_child(line)


func _list_recipes() -> void:
	var level := player.professions.level(_selected)
	var groups := {}
	for recipe in RecipeDB.for_profession(_selected):
		# Far above the player's skill stays hidden, to keep the list short.
		if recipe["level"] > level + 15:
			continue
		if _search != "" and not RecipeDB.display_name(recipe).to_lower().contains(_search):
			continue
		var state := state_of(recipe)
		if (_filter == 1 and state != "ready") or (_filter == 2 and state != "missing") or (_filter == 3 and state != "locked"):
			continue
		var group := section(recipe)
		if not groups.has(group):
			groups[group] = []
		groups[group].append(recipe)
	if groups.is_empty():
		_list.add_child(UITheme.label("Nothing matches.", 15, UITheme.DIM))
		return
	for group: String in ["Meals", "Potions & remedies", "Arms & armour", "Tools & packs", "Buildings & furniture", "Materials"]:
		if not groups.has(group):
			continue
		if groups.size() > 1:
			_section(group)
		for recipe: Dictionary in groups[group]:
			_list.add_child(_recipe_row(recipe))


## One recipe: picture, name, level, and a mark for whether it can be made.
func _recipe_row(recipe: Dictionary) -> Button:
	var made := sample(recipe)
	var state := state_of(recipe)
	var chosen: bool = not _recipe.is_empty() and recipe["id"] == _recipe["id"]
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(370.0, ROW)
	var style := UITheme.card("card_selected" if chosen else "card_dim" if state == "locked" else "card", 4)
	var hover := UITheme.card("card_selected" if chosen else "card_hover", 4)
	var pressed := UITheme.card("card_selected", 4)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	var picture := TextureRect.new()
	picture.texture = made.icon()
	picture.modulate = made.icon_tint() if state != "locked" else Color(made.icon_tint(), 0.4)
	picture.position = Vector2(6, 5)
	picture.size = Vector2(34, 34)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(picture)
	var color := UITheme.TEXT if state == "ready" else Color("c8a8a0") if state == "missing" else UITheme.DIM
	var name_label := UITheme.label(RecipeDB.display_name(recipe), 16, color)
	name_label.position = Vector2(48, 11)
	name_label.size = Vector2(230, 22)
	name_label.clip_text = true
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(name_label)
	var level_label := UITheme.label("Lv %d" % recipe["level"], 14, UITheme.DIM if state != "locked" else UITheme.BAD)
	level_label.position = Vector2(286, 12)
	level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(level_label)
	var mark := StateMark.make(state, 18.0)
	mark.position = Vector2(340, 13)
	button.add_child(mark)
	button.pressed.connect(func() -> void:
		_recipe = recipe
		_quantity = 1
		_message.text = ""
		refresh()
	)
	button.mouse_entered.connect(func() -> void: _tip.show_recipe(recipe, player))
	button.mouse_exited.connect(func() -> void: _tip.hide_tip())
	UITheme.sounds(button)
	return button


## What a gathering profession can gather, with pictures of what each gives.
func _list_resources() -> void:
	var level := player.professions.level(_selected)
	var entries: Array = []
	for id: String in GatherDB.RESOURCES:
		var data: Dictionary = GatherDB.RESOURCES[id]
		if GatherDB.KINDS[data["kind"]]["profession"] != _selected or data["kind"] == "fish":
			continue
		entries.append([data["level"], GatherDB.display_name(id), data["item"], "" if data["tier"] <= 1 else "tier %d tool" % data["tier"]])
	if _selected == "fishing":
		for fish in GatherDB.FISH:
			entries.append([fish[1], ItemDB.ITEMS[fish[0]]["name"], fish[0], ""])
	entries.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for entry: Array in entries:
		var known: bool = level >= entry[0]
		var given := Item.create(entry[2])
		var row := Panel.new()
		row.custom_minimum_size = Vector2(370.0, ROW)
		row.add_theme_stylebox_override("panel", UITheme.card("card" if known else "card_dim", 4))
		var picture := TextureRect.new()
		picture.texture = given.icon()
		picture.modulate = Color(given.icon_tint(), 1.0 if known else 0.35)
		picture.position = Vector2(6, 5)
		picture.size = Vector2(34, 34)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		row.add_child(picture)
		var name_label := UITheme.label(entry[1], 15, UITheme.TEXT if known else UITheme.DIM)
		name_label.position = Vector2(48, 2)
		row.add_child(name_label)
		var detail := UITheme.label("gives %s%s" % [given.display_name(), "  -  " + entry[3] if entry[3] != "" else ""], 13, UITheme.DIM)
		detail.position = Vector2(48, 22)
		row.add_child(detail)
		var level_label := UITheme.label("Lv %d" % entry[0], 14, UITheme.DIM if known else UITheme.BAD)
		level_label.position = Vector2(286, 12)
		row.add_child(level_label)
		var mark := StateMark.make("ready" if known else "locked", 18.0)
		mark.position = Vector2(340, 13)
		row.add_child(mark)
		row.mouse_entered.connect(func() -> void: _tip.show_item(given, player))
		row.mouse_exited.connect(func() -> void: _tip.hide_tip())
		_list.add_child(row)


## What the profession has given so far, and what comes next.
func _list_knowledge() -> void:
	var professions := player.professions
	var level := professions.level(_selected)
	var lines: PackedStringArray = []
	lines.append("[color=#%s]Level %d of %d[/color]" % [UITheme.HEADING.to_html(false), level, Professions.MAX_LEVEL])
	if _selected in Professions.GATHERING:
		lines.append("Works [color=#%s]%d%%[/color] faster than a beginner." % [UITheme.GOOD.to_html(false), roundi((professions.speed_multiplier(_selected) - 1.0) * 100.0)])
		lines.append("[color=#%s]%d%%[/color] chance of a double yield." % [UITheme.GOOD.to_html(false), roundi(professions.double_chance(_selected) * 100.0)])
		lines.append("")
		lines.append("Point at a %s and left click; the right tool comes to hand." % {"mining": "rock", "woodcutting": "tree", "herbalism": "plant", "fishing": "fishing spot"}.get(_selected, "node"))
	else:
		var recipes := RecipeDB.for_profession(_selected)
		var known := recipes.filter(func(r: Dictionary) -> bool: return r["level"] <= level)
		lines.append("Knows [color=#%s]%d[/color] of %d recipes." % [UITheme.GOOD.to_html(false), known.size(), recipes.size()])
		lines.append("")
		var upcoming := recipes.filter(func(r: Dictionary) -> bool: return r["level"] > level)
		upcoming.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["level"] < b["level"])
		if not upcoming.is_empty():
			lines.append("[color=#%s]Coming next[/color]" % UITheme.HEADING.to_html(false))
			for recipe: Dictionary in upcoming.slice(0, 6):
				lines.append("Lv %d   %s" % [recipe["level"], RecipeDB.display_name(recipe)])
		if not player.near_crafting_table():
			lines.append("")
			lines.append("[color=#%s]Most recipes need a crafting table nearby.[/color]" % UITheme.BAD.to_html(false))
		if _selected in ["blacksmithing", "enchanting", "salvaging"]:
			lines.append("")
			lines.append("[color=#%s]Upgrade, Enchant and Salvage are on the Inventory screen: select a piece of equipment there.[/color]" % UITheme.DIM.to_html(false))
	var title := professions.title(_selected)
	lines.append("")
	lines.append("[color=#%s]Title at level %d: %s%s[/color]" % [UITheme.GOLD.to_html(false), Professions.MAX_LEVEL, Professions.TITLES[_selected], "  (earned)" if title != "" else ""])
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.custom_minimum_size = Vector2(366.0, 0.0)
	text.add_theme_font_size_override("normal_font_size", 15)
	text.text = "\n".join(lines)
	_list.add_child(text)


func _select(id: String) -> void:
	_selected = id
	_recipe = {}
	_quantity = 1
	_message.text = ""
	if id in Professions.GATHERING:
		_tab = "recipes"
	refresh()


## How many of the chosen recipe the bag holds enough for.
func _most() -> int:
	if _recipe.is_empty():
		return 0
	var most := 999
	for item_id: String in _recipe["inputs"]:
		most = mini(most, player.inventory.count_of(item_id) / int(_recipe["inputs"][item_id]))
	return most


func _step(by: int) -> void:
	_quantity = clampi(_quantity + by, 1, maxi(_most(), 1))
	_show_recipe()


func _show_recipe() -> void:
	_detail.visible = not _recipe.is_empty()
	_empty.visible = _recipe.is_empty()
	_craft.visible = not _selected in Professions.GATHERING
	_craft_all.visible = _craft.visible
	if _recipe.is_empty():
		_empty.text = "Pick a recipe to see what it does and what it needs." if not _selected in Professions.GATHERING else "Everything %s can gather is listed in the middle, with the level each needs." % Professions.NAMES[_selected].to_lower()
		_craft.disabled = true
		_craft_all.disabled = true
		return
	var made := sample(_recipe)
	var count: int = _recipe.get("count", 1)
	_picture.texture = made.icon()
	_picture.modulate = made.icon_tint()
	_title.text = RecipeDB.display_name(_recipe).trim_suffix(" x%d" % count)
	_kind.text = "%s   -   %s Lv %d" % [section(_recipe).trim_suffix("s").replace("Arms & armour", "Arms & armour"), Professions.NAMES[_recipe["profession"]], _recipe["level"]]
	if _recipe.has("equipment"):
		_text.text = "Item level %d. Its rarity and bonuses are rolled when it is made; skill improves the odds." % _recipe["item_level"]
	else:
		_text.text = made.definition().get("text", "")
	# What it does when used.
	for child in _effects.get_children():
		child.queue_free()
	for effect: Array in ItemText.effects(made):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.add_child(_small_icon(effect[0]))
		var words := UITheme.label(effect[1], 14, effect[2])
		words.autowrap_mode = TextServer.AUTOWRAP_WORD
		words.custom_minimum_size.x = 330.0
		row.add_child(words)
		_effects.add_child(row)
	# Every ingredient, with how many are held.
	for child in _needs.get_children():
		child.queue_free()
	for item_id: String in _recipe["inputs"]:
		var need: int = int(_recipe["inputs"][item_id]) * _quantity
		var have := player.inventory.count_of(item_id)
		var part := Item.create(item_id)
		var row := Panel.new()
		row.custom_minimum_size = Vector2(372.0, 38.0)
		var style := UITheme.card("card", 4)
		if have < need:
			style.modulate_color = Color(1.0, 0.72, 0.7)
		row.add_theme_stylebox_override("panel", style)
		var picture := TextureRect.new()
		picture.texture = part.icon()
		picture.modulate = part.icon_tint()
		picture.position = Vector2(6, 4)
		picture.size = Vector2(30, 30)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(picture)
		var name_label := UITheme.label(part.display_name(), 15)
		name_label.position = Vector2(44, 9)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(name_label)
		var counts := UITheme.label("%d / %d" % [have, need], 17, UITheme.GOOD if have >= need else UITheme.BAD)
		counts.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		counts.offset_left = -120.0
		counts.offset_right = -36.0
		counts.offset_top = 7.0
		counts.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		counts.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(counts)
		var mark := StateMark.make("ready" if have >= need else "missing", 16.0)
		mark.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
		mark.offset_left = -28.0
		mark.offset_right = -10.0
		mark.offset_top = -8.0
		mark.offset_bottom = 8.0
		row.add_child(mark)
		row.mouse_entered.connect(func() -> void: _tip.show_item(part, player))
		row.mouse_exited.connect(func() -> void: _tip.hide_tip())
		_needs.add_child(row)
	_produce_icon.texture = made.icon()
	_produce_icon.modulate = made.icon_tint()
	_produce_name.text = "%s  x%d" % [_title.text, count * _quantity]
	_amount.text = str(_quantity)
	var problem := Crafting.blocked_reason(player, _recipe)
	_craft.disabled = problem != "" or _most() < _quantity
	_craft.text = "Craft" if _quantity == 1 else "Craft x%d" % _quantity
	_craft_all.disabled = problem != "" or _most() < 2
	_craft_all.text = "Craft all (%d)" % _most() if _most() > 1 else "Craft all"
	if problem != "" and _message.text == "":
		_message.add_theme_color_override("font_color", UITheme.BAD)
		_message.text = problem


func _small_icon(texture: Texture2D) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = Vector2(20, 20)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return icon


func _make(times: int) -> void:
	if _recipe.is_empty() or times <= 0:
		return
	var result := ""
	var made := 0
	for i in times:
		result = Crafting.craft(player, _recipe)
		if result != "":
			break
		made += 1
	_quantity = 1
	if made > 0:
		Audio.play("pickup", -6.0)
		_message.add_theme_color_override("font_color", UITheme.GOOD)
		_message.text = "Made %d." % made if result == "" else "Made %d. %s" % [made, result]
	else:
		_message.add_theme_color_override("font_color", UITheme.BAD)
		_message.text = result
	refresh()
