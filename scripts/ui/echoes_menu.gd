class_name EchoesMenu
extends GameMenu
## Your Echoes: what you have devoured and kept. Across the top, the slots
## you wear (each a card with the Echo's own colour); under them every
## Echo learned, each with a portrait of the kind it came from, its gifts,
## and a click to put it on or take it off. On the right, the fusions open
## to you and the hungers half-fed: kinds devoured that have not yet given
## up their Echo.

const CARD := Vector2(258, 92)

var _summary: Label
var _worn_row: HBoxContainer
var _grid: GridContainer
var _side: VBoxContainer
var _message: Label


func _build() -> void:
	var title := UITheme.heading("ECHOES", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	_summary = UITheme.label("", 15, UITheme.DIM)
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_summary)
	_worn_row = HBoxContainer.new()
	_worn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_worn_row.add_theme_constant_override("separation", 8)
	content.add_child(_worn_row)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	content.add_child(body)
	var left := UITheme.inset_panel()
	body.add_child(left)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(CARD.x * 2 + 30, 330)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(_grid)
	_side = VBoxContainer.new()
	_side.add_theme_constant_override("separation", 8)
	_side.custom_minimum_size = Vector2(330, 0)
	body.add_child(_side)
	_message = UITheme.label("", 14, UITheme.BAD)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_message)


func _echoes() -> Echoes:
	return player.get_parent().get_node_or_null("Echoes")


static func portrait(echo_id: String) -> Texture2D:
	var atlas := AtlasTexture.new()
	var from: Array = Echoes.LIST[echo_id].get("from", [])
	var monster := str(from[0]) if not from.is_empty() else ""
	if monster == "":
		# A fused Echo shows the first of the two it came of.
		for fusion: Array in Echoes.FUSIONS:
			if fusion[2] == echo_id:
				monster = str(Echoes.LIST[fusion[0]]["from"][0])
	atlas.atlas = EnemyDB.sheet(monster)
	atlas.region = EnemyDB.cell_region(atlas.atlas, Rect2(20, 22, 56, 56))
	return atlas


func refresh() -> void:
	var echoes := _echoes()
	for child in _worn_row.get_children() + _grid.get_children() + _side.get_children():
		child.queue_free()
	if echoes == null:
		return
	if not echoes.awake:
		_summary.text = "The gift of devouring wakes at level %d." % Echoes.WAKE_LEVEL
		return
	_summary.text = "%d echoes learned  ·  %d of %d slots worn  ·  %d remnants devoured%s" % [echoes.learned.size(), echoes.worn.size(), echoes.slots(), echoes.devoured,
		"  ·  a slime's hunger: devours better, one slot more" if player.race() == "slime" else ""]
	for index in echoes.slots():
		var id: String = echoes.worn[index] if index < echoes.worn.size() else ""
		_worn_row.add_child(_slot(id))
	if echoes.learned.is_empty():
		_grid.add_child(UITheme.paragraph("Nothing yet. Fell a monster and devour its remnant before it fades (interact with the dark wisp where it fell).", CARD.x * 2, 15, UITheme.DIM))
	for id: String in echoes.learned:
		_grid.add_child(_card(id, id in echoes.worn))
	_fill_side(echoes)


## A worn slot: the Echo's portrait in its colour, or an empty socket.
func _slot(id: String) -> Control:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(72, 72)
	frame.add_theme_stylebox_override("panel", UITheme.slot("slot_active" if id != "" else "slot"))
	if id == "":
		var empty := UITheme.label("empty", 12, UITheme.DIM)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		frame.add_child(empty)
		return frame
	var picture := TextureRect.new()
	picture.texture = portrait(id)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.modulate = (Echoes.LIST[id]["color"] as Color).lightened(0.35)
	frame.add_child(picture)
	frame.tooltip_text = "%s\n%s" % [Echoes.LIST[id]["name"], describe(id)]
	return frame


## An Echo card: portrait, name, tier, gifts; click to wear or take off.
func _card(id: String, worn: bool) -> Button:
	var data: Dictionary = Echoes.LIST[id]
	var card := Button.new()
	card.custom_minimum_size = CARD
	card.add_theme_stylebox_override("normal", UITheme.card("card_selected" if worn else "card", 6))
	card.add_theme_stylebox_override("hover", UITheme.card("card_selected", 6))
	card.pressed.connect(func() -> void:
		_message.text = _echoes().toggle(id)
		refresh()
	)
	UITheme.sounds(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 8
	row.offset_top = 6
	card.add_child(row)
	var picture := TextureRect.new()
	picture.texture = portrait(id)
	picture.custom_minimum_size = Vector2(56, 56)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(picture)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 0)
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(words)
	var name_label := UITheme.strong(str(data["name"]) + ("  (worn)" if worn else ""), 15, data["color"])
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(name_label)
	var gifts := UITheme.paragraph(describe(id), CARD.x - 80.0, 13, UITheme.GOOD if int(data["tier"]) == 1 else UITheme.GOLD)
	gifts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(gifts)
	card.tooltip_text = "%s\n%s\n\nClick to %s." % [data["name"], data["text"], "take it off" if worn else "wear it"]
	return card


## An Echo's gifts in words.
static func describe(id: String) -> String:
	var parts: PackedStringArray = []
	var mods: Dictionary = Echoes.LIST[id]["mods"]
	for stat: String in mods:
		for kind: String in mods[stat]:
			parts.append(ItemDB.describe_modifier({"stat": stat, "kind": kind, "value": mods[stat][kind]}))
	return ", ".join(parts)


func _fill_side(echoes: Echoes) -> void:
	_side.add_child(UITheme.heading("Fusion", 18))
	var ready := echoes.fusions_ready()
	if ready.is_empty():
		_side.add_child(UITheme.paragraph("Some echoes become one stronger echo when fused (both are used up). None you carry will fuse yet.", 320, 14, UITheme.DIM))
	for fusion: Array in ready:
		var made: Dictionary = Echoes.LIST[fusion[2]]
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		_side.add_child(box)
		box.add_child(UITheme.strong("%s + %s" % [Echoes.LIST[fusion[0]]["name"], Echoes.LIST[fusion[1]]["name"]], 14, UITheme.TEXT))
		box.add_child(UITheme.strong("= %s" % made["name"], 15, made["color"]))
		box.add_child(UITheme.paragraph(describe(fusion[2]), 320, 13, UITheme.GOLD))
		box.add_child(UITheme.primary_button("Fuse", func() -> void:
			_message.text = echoes.fuse(fusion[0], fusion[1])
			refresh()
		, 140.0))
	_side.add_child(UITheme.rule(320))
	_side.add_child(UITheme.heading("Hungers", 18))
	if echoes.hunger.is_empty():
		_side.add_child(UITheme.paragraph("Kinds you have devoured without taking their echo are listed here. Each devour brings the echo closer.", 320, 14, UITheme.DIM))
	var sure := Echoes.SURE_AFTER - (1 if player.race() == "slime" else 0)
	for monster: String in echoes.hunger:
		_side.add_child(UITheme.label("%s  %d / %d" % [EnemyDB.ENEMIES.get(monster, {}).get("name", monster), int(echoes.hunger[monster]), sure], 14, UITheme.TEXT))
	var known := 0
	for id: String in Echoes.LIST:
		if int(Echoes.LIST[id]["tier"]) == 1:
			known += 1
	_side.add_child(UITheme.rule(320))
	_side.add_child(UITheme.label("%d kinds of echo walk the world." % known, 13, UITheme.DIM))
