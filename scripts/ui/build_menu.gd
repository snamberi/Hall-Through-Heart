class_name BuildMenu
extends GameMenu
## Everything the player can build, by kind. On the left, the kinds; in the
## middle, each blueprint with its state in a word (Ready to place, Can
## make, Need materials, Needs a crafting table); on the right, the chosen
## blueprint: how it looks, its footprint, where it may go, what it takes,
## and only the action that helps now (Place when one is in the bag, else
## Make). How to place, mirror and take down shows by the preview itself.

const CATEGORIES := [
	["structures", "Structures", ["house", "bed", "table", "chest", "furnace"]],
	["walls", "Walls and fences", ["wall", "fence", "palisade"]],
	["ground", "Ground", ["ground", "floor"]],
	["furniture", "Furniture", ["rug", "bookshelf", "potted_plant", "dining_table", "chair", "wall_banner", "barrel", "crate", "stone_statue",
		"bench", "cupboard", "weapon_rack", "anvil", "trophy_stand", "flower_bed", "stone_planter", "hay_bale", "fountain"]],
	["light", "Light", ["torch", "candles", "brazier", "fireplace", "lantern_post"]],
	["farm", "Farm and defence", ["farmhouse", "plot", "scarecrow", "spikes", "ballista"]],
	["roots", "Root-tech", ["root_cutter", "root_delver", "root_tender", "root_hollow"]],
]
const ROW := Vector2(400.0, 56.0)
const DETAIL_WIDTH := 460.0
## A state's words and badge colour.
const STATES := {
	"ready": ["Ready to place", "good"], "make": ["Can make", "gold"], "table": ["Needs a crafting table", "info"],
	"skill": ["Needs more skill", "bad"], "materials": ["Need materials", "bad"], "found": ["Found, not made", "plain"],
	"full": ["Bag is full", "bad"],
}

var _category := "structures"
var _selected := ""
var _tabs: VBoxContainer
var _list: VBoxContainer
var _note: Label
var _table: Control
var _icon: TextureRect
var _name: Label
var _state_box: HBoxContainer
var _text: Label
var _rules: VBoxContainer
var _needs_title: Label
var _needs: VBoxContainer
var _reason: Label
var _primary: Button
var _secondary: Button


func _build() -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(head)
	head.add_child(UITheme.heading("BUILD", 30))
	_note = UITheme.label("Make things at a crafting table, then place them in the world.", 15, UITheme.DIM)
	_note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_note)
	_table = HBoxContainer.new()
	_table.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_table)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	content.add_child(row)
	_tabs = VBoxContainer.new()
	_tabs.custom_minimum_size.x = 190.0
	_tabs.add_theme_constant_override("separation", 6)
	row.add_child(_tabs)
	for category: Array in CATEGORIES:
		var tab := UITheme.button(category[1], func() -> void:
			_category = category[0]
			_selected = ""
			refresh()
		, 190.0)
		tab.name = category[0]
		tab.toggle_mode = true
		tab.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_tabs.add_child(tab)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(ROW.x + 14.0, 500.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)

	var right := PanelContainer.new()
	right.add_theme_stylebox_override("panel", UITheme.card("card", 14))
	right.custom_minimum_size = Vector2(DETAIL_WIDTH, 0.0)
	row.add_child(right)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	right.add_child(box)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	box.add_child(top)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UITheme.slot("slot"))
	top.add_child(frame)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(72, 72)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.add_child(_icon)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 4)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(words)
	_name = UITheme.heading("", 22)
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD
	words.add_child(_name)
	_state_box = HBoxContainer.new()
	_state_box.add_theme_constant_override("separation", 6)
	words.add_child(_state_box)
	_text = UITheme.paragraph("", DETAIL_WIDTH - 30.0, 15, UITheme.TEXT)
	box.add_child(_text)
	_rules = VBoxContainer.new()
	_rules.add_theme_constant_override("separation", 2)
	box.add_child(_rules)
	box.add_child(UITheme.rule())
	_needs_title = UITheme.label("", 16, UITheme.HEADING)
	box.add_child(_needs_title)
	_needs = VBoxContainer.new()
	_needs.add_theme_constant_override("separation", 3)
	box.add_child(_needs)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(fill)
	_reason = UITheme.reason("", DETAIL_WIDTH - 30.0)
	box.add_child(_reason)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	box.add_child(buttons)
	_primary = UITheme.primary_button("", _on_primary, 250.0)
	buttons.add_child(_primary)
	_secondary = UITheme.button("", _on_secondary, 170.0)
	buttons.add_child(_secondary)


## Every placeable item of a category, in a sensible order.
func _items_in(category: String) -> Array[String]:
	var kinds: Array = []
	for entry: Array in CATEGORIES:
		if entry[0] == category:
			kinds = entry[2]
	var result: Array[String] = []
	for kind: String in kinds:
		for id: String in ItemDB.ITEMS:
			if str(ItemDB.ITEMS[id].get("place", "")) == kind:
				result.append(id)
	return result


## What can be done with a blueprint now, as one of STATES.
func state_of(id: String) -> String:
	if player.inventory.count_of(id) > 0:
		return "ready"
	var recipe := RecipeDB.find(id)
	if recipe.is_empty():
		return "found"
	var problem := Crafting.blocked_reason(player, recipe)
	if problem == "":
		return "make"
	if problem.begins_with("Stand next to"):
		return "table"
	if problem.begins_with("Requires"):
		return "skill"
	if problem.begins_with("Inventory is full"):
		return "full"
	return "materials"


func refresh() -> void:
	var near_table := player.near_crafting_table()
	for child in _table.get_children():
		child.queue_free()
	_table.add_child(UITheme.badge("At a crafting table" if near_table else "No crafting table here", "good" if near_table else "info"))
	for tab in _tabs.get_children():
		var button := tab as Button
		button.set_pressed_no_signal(tab.name == _category)
		var ready := 0
		for id in _items_in(tab.name):
			if player.inventory.count_of(id) > 0:
				ready += 1
		for entry: Array in CATEGORIES:
			if entry[0] == tab.name:
				button.text = entry[1] + ("   %d" % ready if ready > 0 else "")
	var ids := _items_in(_category)
	if _selected == "" or not ids.has(_selected):
		_selected = ""
		for id in ids:
			if state_of(id) in ["ready", "make"]:
				_selected = id
				break
		if _selected == "" and not ids.is_empty():
			_selected = ids[0]
	for child in _list.get_children():
		child.queue_free()
	for id in ids:
		_list.add_child(_row(id))
	_show(_selected)


func _row(id: String) -> Button:
	var item := Item.create(id)
	var data: Dictionary = ItemDB.ITEMS[id]
	var state := state_of(id)
	var chosen := id == _selected
	var button := Button.new()
	button.custom_minimum_size = ROW
	var kind := "card_selected" if chosen else ("card" if state in ["ready", "make"] else "card_dim")
	for look: String in ["normal", "pressed"]:
		button.add_theme_stylebox_override(look, UITheme.card(kind, 6))
	button.add_theme_stylebox_override("hover", UITheme.card("card_selected" if chosen else "card_hover", 6))
	button.pressed.connect(func() -> void:
		_selected = id
		refresh()
	)
	UITheme.sounds(button)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 7)
	row.add_theme_constant_override("separation", 10)
	button.add_child(row)
	var icon := TextureRect.new()
	icon.texture = item.icon()
	icon.modulate = item.icon_tint() if not data.has("decor") and not data.has("ground") else Color.WHITE
	icon.custom_minimum_size = Vector2(40, 40)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(words)
	words.add_child(UITheme.strong(data["name"], 16, UITheme.GOLD if chosen else UITheme.TEXT))
	var have := player.inventory.count_of(id)
	words.add_child(UITheme.label("%d in bag" % have if have > 0 else STATES[state][0], 14, UITheme.DIM))
	var badge := UITheme.badge(STATES[state][0] if state in ["ready", "make"] else "", STATES[state][1])
	badge.visible = state in ["ready", "make"]
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(badge)
	for control: Control in row.find_children("*", "Control", true, false):
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return button


func _show(id: String) -> void:
	if id == "":
		return
	var item := Item.create(id)
	var data: Dictionary = ItemDB.ITEMS[id]
	var state := state_of(id)
	var have := player.inventory.count_of(id)
	_icon.texture = item.icon()
	_icon.modulate = item.icon_tint() if not data.has("decor") and not data.has("ground") else Color.WHITE
	_name.text = data["name"]
	for child in _state_box.get_children():
		child.queue_free()
	_state_box.add_child(UITheme.badge(STATES[state][0], STATES[state][1]))
	if have > 0:
		_state_box.add_child(UITheme.badge("%d in bag" % have, "plain"))
	_text.text = str(data.get("text", ""))
	_text.visible = _text.text != ""
	for child in _rules.get_children():
		child.queue_free()
	for line in rules_for(id):
		var rule := UITheme.label("·  " + line, 14, UITheme.DIM)
		rule.autowrap_mode = TextServer.AUTOWRAP_WORD
		rule.custom_minimum_size.x = DETAIL_WIDTH - 30.0
		_rules.add_child(rule)

	for child in _needs.get_children():
		child.queue_free()
	var recipe := RecipeDB.find(id)
	if recipe.is_empty():
		_needs_title.text = "Not made by hand: found or bought."
	else:
		_needs_title.text = "Making %s takes" % ("one" if int(recipe["count"]) == 1 else "%d" % recipe["count"])
		for input: String in recipe["inputs"]:
			_needs.add_child(_need_row(ItemDB.ITEMS[input]["name"], player.inventory.count_of(input), int(recipe["inputs"][input])))
		if recipe["level"] > 1:
			_needs.add_child(_need_row("%s skill" % Professions.NAMES[recipe["profession"]], player.professions.level(recipe["profession"]), int(recipe["level"])))
		var table: bool = player.near_crafting_table() or recipe["id"] in RecipeDB.NO_TABLE
		_needs.add_child(_need_row("At a crafting table", 1 if table else 0, 1, false))

	# Promote only what helps now: Place if there is one, else Make.
	var problem := "" if recipe.is_empty() else Crafting.blocked_reason(player, recipe)
	_reason.text = ""
	_secondary.visible = false
	if state == "ready":
		_primary.text = "Place  (%d left)" % have
		_primary.disabled = false
		if not recipe.is_empty():
			_secondary.visible = true
			_secondary.text = "Make another"
			_secondary.disabled = problem != ""
			_secondary.tooltip_text = problem
	elif recipe.is_empty():
		_primary.text = "Place"
		_primary.disabled = true
		_reason.text = "You have none. Look for one in the world or at a merchant."
	else:
		_primary.text = "Make %s" % data["name"]
		_primary.disabled = problem != ""
		_reason.text = problem


func _on_primary() -> void:
	if state_of(_selected) == "ready":
		_place(_selected)
	else:
		_make(_selected)


func _on_secondary() -> void:
	_make(_selected)


func _make(id: String) -> void:
	var problem := Crafting.craft(player, RecipeDB.find(id))
	refresh()
	if problem != "":
		_reason.text = problem


func _place(id: String) -> void:
	for held in player.inventory.items:
		if held and held.id == id:
			var menus := player.get_parent().get_node_or_null("Menus")
			if menus:
				menus.close()
			Events.placement_requested.emit(held)
			return


## Where a blueprint may go and how it behaves, in short lines.
static func rules_for(id: String) -> Array[String]:
	var data: Dictionary = ItemDB.ITEMS[id]
	var kind_id := str(data.get("place", ""))
	var kind: Dictionary = Buildings.KINDS.get(kind_id, {})
	var lines: Array[String] = []
	lines.append("Footprint: %s" % ("3 by 3 tiles" if kind_id in ["house", "farmhouse"] else "1 tile"))
	match kind_id:
		"house":
			lines.append("Enter it to build floors and furniture inside.")
		"wall", "fence", "palisade":
			lines.append("Joins the walls beside it. Hold and drag to lay a run.")
		"ground":
			lines.append("Lays new ground outdoors. Hold and drag to lay a run.")
		"floor":
			lines.append("Inside a house only. Hold and drag to lay a run.")
		"table":
			lines.append("Lets you make things while standing beside it.")
		"bed":
			lines.append("Sleep in it to make that place your home.")
		"chest":
			lines.append("Keeps things safe; opens to its own grid.")
		"furnace":
			lines.append("Smelts ore into ingots over time, burning coal.")
	if kind.get("machine", "") != "":
		lines.append("Works on its own; keep a Root Hollow near to store the harvest.")
	if kind.get("outdoors", false) and kind_id != "ground":
		lines.append("Outdoors only.")
	if kind.get("light", false):
		lines.append("Gives light after dark.")
	if kind.has("decor") and not kind_id in ["fence", "palisade", "plot", "spikes"]:
		lines.append("T mirrors it while placing.")
	if kind.get("flat", false) and kind_id not in ["ground", "floor"]:
		lines.append("Lies flat; you can walk over it.")
	return lines


func _need_row(what: String, have: int, need: int, show_numbers: bool = true) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var met := have >= need
	row.add_child(StateMark.make("ready" if met else "missing", 16))
	var name_label := UITheme.label(what, 15, UITheme.TEXT if met else UITheme.DIM)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	if show_numbers:
		var amount := UITheme.strong("%d / %d" % [have, need], 15, UITheme.GOOD if met else UITheme.BAD)
		amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		amount.custom_minimum_size.x = 84.0
		row.add_child(amount)
	return row
