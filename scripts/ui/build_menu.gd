class_name BuildMenu
extends GameMenu
## Everything the player can build, by kind: structures, walls and fences,
## ground, furniture, light, farm and defence. Each shows what it is, how
## many are in the bag and what making one takes; "Make" crafts it (at a
## crafting table, as ever) and "Place" puts it in hand to set down.

const CATEGORIES := [
	["structures", "Structures", ["house", "bed", "table", "chest"]],
	["walls", "Walls and fences", ["wall", "fence", "palisade"]],
	["ground", "Ground", ["ground", "floor"]],
	["furniture", "Furniture", ["rug", "bookshelf", "potted_plant", "dining_table", "chair", "wall_banner", "barrel", "crate", "stone_statue"]],
	["light", "Light", ["torch", "candles", "brazier", "fireplace", "lantern_post"]],
	["farm", "Farm and defence", ["farmhouse", "plot", "scarecrow", "spikes", "ballista"]],
	["roots", "Root-tech", ["root_cutter", "root_delver", "root_tender", "root_hollow"]],
]
const ROW := Vector2(420.0, 64.0)

var _category := "structures"
var _tabs: VBoxContainer
var _list: GridContainer
var _note: Label


func _build() -> void:
	var title := UITheme.heading("BUILD", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	_note = UITheme.label("", 14, UITheme.DIM)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD
	_note.custom_minimum_size.x = 880.0
	content.add_child(_note)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	content.add_child(row)
	_tabs = VBoxContainer.new()
	_tabs.custom_minimum_size.x = 180.0
	_tabs.add_theme_constant_override("separation", 6)
	row.add_child(_tabs)
	for category: Array in CATEGORIES:
		var tab := UITheme.button(category[1], func() -> void:
			_category = category[0]
			refresh()
		, 180.0)
		tab.name = category[0]
		_tabs.add_child(tab)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(ROW.x * 2.0 + 30.0, 470.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(scroll)
	_list = GridContainer.new()
	_list.columns = 2
	_list.add_theme_constant_override("h_separation", 8)
	_list.add_theme_constant_override("v_separation", 8)
	scroll.add_child(_list)


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


func refresh() -> void:
	var near_table := player.near_crafting_table()
	_note.text = "Make things at a crafting table, then place them where you like. Walls join their neighbours; hold the button to lay a run of walls or ground; T mirrors furniture while placing. Left-click your own things to take them down again." + ("" if near_table else "  (You are not at a crafting table: only placing is possible here.)")
	for tab in _tabs.get_children():
		(tab as Button).modulate = Color.WHITE if tab.name == _category else Color(0.7, 0.7, 0.75)
	for child in _list.get_children():
		child.queue_free()
	for id: String in _items_in(_category):
		_list.add_child(_row(id, near_table))


func _row(id: String, near_table: bool) -> Control:
	var item := Item.create(id)
	var data: Dictionary = ItemDB.ITEMS[id]
	var panel := PanelContainer.new()
	panel.custom_minimum_size = ROW
	panel.add_theme_stylebox_override("panel", UITheme.card("card", 8))
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var icon := TextureRect.new()
	icon.texture = item.icon()
	icon.modulate = item.icon_tint() if not data.has("decor") and not data.has("ground") else Color.WHITE
	icon.custom_minimum_size = Vector2(44, 44)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.tooltip_text = str(data.get("text", ""))
	box.add_child(icon)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(words)
	var have := player.inventory.count_of(id)
	words.add_child(UITheme.label("%s   (%d in bag)" % [data["name"], have], 15, UITheme.HEADING if have > 0 else UITheme.TEXT))
	var recipe := RecipeDB.find(id)
	var needs := ""
	if not recipe.is_empty():
		var parts: PackedStringArray = []
		for input: String in recipe["inputs"]:
			parts.append("%d %s (%d)" % [recipe["inputs"][input], ItemDB.ITEMS[input]["name"], player.inventory.count_of(input)])
		needs = "Makes %d from %s" % [recipe["count"], ", ".join(parts)]
	else:
		needs = "Found or bought, not made"
	var needs_label := UITheme.label(needs, 13, UITheme.DIM)
	needs_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	needs_label.custom_minimum_size.x = 200.0
	words.add_child(needs_label)
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 2)
	box.add_child(buttons)
	var make := UITheme.button("Make", func() -> void:
		var problem := Crafting.craft(player, recipe)
		if problem != "":
			_note.text = problem
		refresh()
	, 76.0)
	make.custom_minimum_size.y = 26.0
	make.disabled = recipe.is_empty() or Crafting.blocked_reason(player, recipe) != ""
	make.tooltip_text = "" if recipe.is_empty() else Crafting.blocked_reason(player, recipe)
	buttons.add_child(make)
	var place := UITheme.button("Place", func() -> void:
		for held in player.inventory.items:
			if held and held.id == id:
				var menus := player.get_parent().get_node_or_null("Menus")
				if menus:
					menus.close()
				Events.placement_requested.emit(held)
				return
	, 76.0)
	place.custom_minimum_size.y = 26.0
	place.disabled = have <= 0
	buttons.add_child(place)
	return panel
