class_name TradeBoardMenu
extends GameMenu
## Village prices: every village you have seen near you, nearest first,
## with the three goods it wants (and how much over the usual it pays) and
## the two it has plenty of. Wants change every two days.

const SEARCH_REGIONS := 3
const MOST := 8

var _list: VBoxContainer


func _build() -> void:
	content.add_theme_constant_override("separation", 10)
	var title := UITheme.heading("VILLAGE PRICES", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var intro := UITheme.label("Carry what one village has plenty of to another that wants it. Selling fills a want, and its price eases.", 15, UITheme.DIM)
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(intro)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(980, 450)
	content.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)


## Seen villages near the player: [[centre, distance in tiles]], nearest first.
func known_villages() -> Array:
	var main := player.get_parent()
	var world: World = main.get_node("World")
	var exploration: Exploration = main.get_node_or_null("Exploration")
	var here := world.world_to_cell(player.global_position)
	var region := Vector2i((Vector2(here) / WorldGenerator.VILLAGE_REGION).floor())
	var found: Array = []
	for ry in range(region.y - SEARCH_REGIONS, region.y + SEARCH_REGIONS + 1):
		for rx in range(region.x - SEARCH_REGIONS, region.x + SEARCH_REGIONS + 1):
			var center: Variant = world.generator.village_center(Vector2i(rx, ry))
			if center == null or (exploration and not exploration.is_tile_seen(center)):
				continue
			found.append([center, roundi(Vector2(center - here).length())])
	found.sort_custom(func(a: Array, b: Array) -> bool: return a[1] < b[1])
	return found.slice(0, MOST)


func refresh() -> void:
	for child in _list.get_children():
		child.queue_free()
	var villages := known_villages()
	if villages.is_empty():
		_list.add_child(UITheme.paragraph("You have not seen a village yet. Their wants show here once you have.", 940.0, 15, UITheme.DIM))
		return
	var days := TradeDemand.PERIOD_DAYS - posmod(TradeDemand.day, TradeDemand.PERIOD_DAYS)
	_list.add_child(UITheme.label("Wants change in %d day%s." % [days, "" if days == 1 else "s"], 14, UITheme.DIM))
	for pair: Array in villages:
		var center: Vector2i = pair[0]
		var demand := TradeDemand.of(center)
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UITheme.card("card", 8))
		_list.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		card.add_child(row)
		var place := VBoxContainer.new()
		place.add_theme_constant_override("separation", -2)
		place.custom_minimum_size.x = 170.0
		row.add_child(place)
		place.add_child(UITheme.strong("Village (%d, %d)" % [center.x, center.y], 16))
		place.add_child(UITheme.label("%d tiles away" % pair[1] if pair[1] > 20 else "Here", 13, UITheme.DIM))
		var goods := HBoxContainer.new()
		goods.add_theme_constant_override("separation", 10)
		row.add_child(goods)
		for id: String in demand["wants"]:
			goods.add_child(_good(id, TradeDemand.factor(center, id)))
		var gap := VSeparator.new()
		goods.add_child(gap)
		for id: String in demand["plenty"]:
			goods.add_child(_good(id, demand["plenty"][id]))


## One good: its icon, name and how its price stands.
func _good(id: String, factor: float) -> HBoxContainer:
	var item := Item.create(id)
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.custom_minimum_size.x = 136.0
	var icon := TextureRect.new()
	icon.texture = item.icon()
	icon.modulate = item.icon_tint()
	icon.custom_minimum_size = Vector2(28, 28)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	box.add_child(icon)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", -3)
	box.add_child(words)
	var name_label := UITheme.label(item.display_name(), 13, UITheme.TEXT)
	name_label.clip_text = true
	name_label.custom_minimum_size.x = 100.0
	words.add_child(name_label)
	words.add_child(UITheme.strong(TradeDemand.percent(factor), 14, UITheme.GOOD if factor > 1.0 else UITheme.BAD))
	return box
