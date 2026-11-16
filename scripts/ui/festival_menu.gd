class_name FestivalMenu
extends GameMenu
## A festival stall: on the left, the festival (what it is, how long it
## runs) and its contest, each good as a row (how many make a token, what
## you hold, Hand in); on the right, the festival's goods for tokens.

## "harvest", "frost" or "bazaar".
var festival := "harvest"

var _title: Label
var _left: VBoxContainer
var _right: VBoxContainer
var _message: Label


func _build() -> void:
	content.add_theme_constant_override("separation", 10)
	_title = UITheme.heading("", 30)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_title)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 12)
	content.add_child(columns)
	_left = _column(columns, 470.0)
	_right = _column(columns, 470.0)
	_message = UITheme.reason("", 0.0)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_message)
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree():
			_message.text = ""
	)


func _column(parent: Control, width: float) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.card("card", 10))
	panel.custom_minimum_size = Vector2(width, 400)
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	return box


func _festivals() -> Festivals:
	return player.get_parent().get_node("Festivals")


func _icon_of(item: Item, side: float = 32.0) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = item.icon()
	icon.modulate = item.icon_tint()
	icon.custom_minimum_size = Vector2(side, side)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return icon


func refresh() -> void:
	for child in _left.get_children() + _right.get_children():
		child.queue_free()
	var data: Dictionary = Festivals.FESTIVALS[festival]
	var festivals := _festivals()
	_title.text = String(data["name"]).to_upper()
	_title.add_theme_color_override("font_color", data["color"])
	var token := Item.create(data["token"])
	var held := player.inventory.count_of(data["token"])
	_left.add_child(UITheme.paragraph(data["text"], 440.0, 15, UITheme.TEXT))
	if festival != "bazaar":
		var left := festivals.days_left() if festivals.current() == festival else 0
		_left.add_child(UITheme.label(("%d day%s left" % [left, "" if left == 1 else "s"]) if left > 0 else "Held from day %d of each %d-day year" % [int(data["start"]), Festivals.YEAR_DAYS], 14, UITheme.DIM))
	else:
		_left.add_child(UITheme.label("Open until the moon pales", 14, UITheme.DIM))
	_left.add_child(UITheme.rule())
	var contest: Dictionary = data["contest"]
	if contest.is_empty():
		_left.add_child(UITheme.heading("Blood Tokens", 18))
		_left.add_child(UITheme.paragraph("Monsters slain under the red moon drop them now and then; Elites and stronger, often.", 440.0, 15, UITheme.DIM))
	else:
		_left.add_child(UITheme.heading("The contest", 18))
		for item_id: String in contest:
			var item := Item.create(item_id)
			var lot := int(contest[item_id])
			var have := player.inventory.count_of(item_id)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			_left.add_child(row)
			row.add_child(_icon_of(item))
			var words := VBoxContainer.new()
			words.add_theme_constant_override("separation", -2)
			words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(words)
			words.add_child(UITheme.strong(item.display_name(), 15))
			words.add_child(UITheme.label("%d for a token  ·  you hold %d" % [lot, have], 13, UITheme.DIM))
			var give := UITheme.button("Hand in", func() -> void:
				var earned := festivals.hand_in(festival, item_id)
				_message.text = "+%d %s%s" % [earned, token.display_name(), "" if earned == 1 else "s"] if earned > 0 else ""
				refresh()
			, 96.0)
			give.disabled = have < lot
			row.add_child(give)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	_right.add_child(head)
	head.add_child(_icon_of(token, 28.0))
	var heading := UITheme.heading("Festival goods" if festival != "bazaar" else "The Hooded Trader's wares", 18)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(heading)
	head.add_child(UITheme.strong("%d held" % held, 16, data["color"]))
	var shop: Array = data["shop"]
	for index in shop.size():
		var ware := Item.create(shop[index][0])
		var cost := int(shop[index][1])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_right.add_child(row)
		row.add_child(_icon_of(ware))
		var words := VBoxContainer.new()
		words.add_theme_constant_override("separation", -2)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(words)
		words.add_child(UITheme.strong(ware.display_name(), 15, ware.color()))
		words.add_child(UITheme.label(ItemText.type_name(ware), 13, UITheme.DIM))
		var buy := UITheme.button("%d token%s" % [cost, "" if cost == 1 else "s"], func() -> void:
			var problem := festivals.buy(festival, index)
			_message.text = problem if problem != "" else "Bought %s." % ware.display_name()
			refresh()
		, 110.0)
		buy.disabled = held < cost
		buy.tooltip_text = ware.definition().get("text", "")
		row.add_child(buy)
