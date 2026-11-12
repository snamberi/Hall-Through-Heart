class_name MagicMenu
extends GameMenu
## The schools of magic: one card each, with its colour, what it is, and
## its four spells with the level each opens at. At the Altar of Magic the
## player takes up a school (or changes to one already learned); elsewhere
## the screen says where the altar lies.

const CARD := Vector2(232.0, 370.0)
## How near the altar counts as standing at it, in pixels.
const ALTAR_REACH := 160.0

var _status: Label
var _cards: Dictionary[String, PanelContainer] = {}


func _build() -> void:
	var title := UITheme.heading("MAGIC", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	_status = UITheme.label("", 15, UITheme.TEXT)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	_status.custom_minimum_size.x = 820.0
	content.add_child(_status)
	var grid := GridContainer.new()
	grid.name = "Grid"
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	content.add_child(grid)
	for school: String in MagicDB.SCHOOLS:
		var data: Dictionary = MagicDB.SCHOOLS[school]
		var card := PanelContainer.new()
		card.custom_minimum_size = CARD
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 5)
		card.add_child(box)
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 8)
		box.add_child(top)
		var icon := TextureRect.new()
		icon.texture = AbilityDB.icon(data["spells"][0])
		icon.custom_minimum_size = Vector2(40, 40)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		top.add_child(icon)
		var names := VBoxContainer.new()
		names.add_theme_constant_override("separation", 0)
		top.add_child(names)
		var heading := UITheme.heading(data["name"], 20)
		heading.add_theme_color_override("font_color", data["color"])
		names.add_child(heading)
		names.add_child(UITheme.label("%s magic" % data["short"], 13, UITheme.DIM))
		var text := UITheme.label(data["text"], 14, UITheme.TEXT)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD
		text.custom_minimum_size = Vector2(CARD.x - 24.0, 40.0)
		box.add_child(text)
		for spell: String in data["spells"]:
			var ability: Dictionary = AbilityDB.ABILITIES[spell]
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			row.tooltip_text = "%s\n%s\nMana %d, cooldown %ss" % [ability["name"], ability["text"], roundi(ability.get("mana", 0.0)), str(ability["cooldown"])]
			var spell_icon := TextureRect.new()
			spell_icon.texture = AbilityDB.icon(spell)
			spell_icon.custom_minimum_size = Vector2(26, 26)
			spell_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			spell_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			row.add_child(spell_icon)
			var words := VBoxContainer.new()
			words.add_theme_constant_override("separation", -2)
			words.add_child(UITheme.label(ability["name"], 14, UITheme.HEADING))
			words.add_child(UITheme.label("Lv %d  -  %d mana  -  %ss" % [ability.get("level", 1), roundi(ability.get("mana", 0.0)), str(ability["cooldown"])], 13, UITheme.DIM))
			row.add_child(words)
			box.add_child(row)
		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_child(spacer)
		var button := UITheme.button("Take up", func() -> void: _take_up(school), CARD.x - 24.0)
		button.name = "Choose"
		box.add_child(button)
		grid.add_child(card)
		_cards[school] = card


func _take_up(school: String) -> void:
	if not _at_altar():
		return
	var gift := ""
	if not player.equipment.equipped.has("weapon_1"):
		# The altar gives a plain staff to one who comes without a magic weapon.
		var staff := LootGenerator.make_equipment(maxi(player.leveling.level, 1), 1, "altar_staff")
		player.inventory.add(staff)
		if player.equipment.equip(staff, "weapon_1") == "":
			gift = "  The altar gives you a staff for your magic slot."
	player.take_up_magic(school)
	RingBurst.spawn(player.get_parent(), player.global_position + Vector2(0, -14), MagicDB.SCHOOLS[school]["color"], 120.0)
	Audio.play("level_up", -6.0, 0.0)
	Events.announcement.emit(str(MagicDB.SCHOOLS[school]["name"]).to_upper(), "Hold your magic (slot 1) and the ability keys cast its spells.%s" % gift)
	refresh()


func _at_altar() -> bool:
	var world: World = player.get_parent().get_node_or_null("World")
	if world == null:
		return false
	return player.global_position.distance_to(world.cell_to_world(world.generator.magic_altar_cell())) < ALTAR_REACH


func refresh() -> void:
	(content.get_node("Grid") as GridContainer).columns = columns_for(CARD + Vector2(10.0, 10.0), MagicDB.SCHOOLS.size(), 2, 5)
	var at_altar := _at_altar()
	var world: World = player.get_parent().get_node_or_null("World")
	if at_altar:
		_status.text = "The altar hums. Choose the magic you will carry." if player.magic_school == "" else "The altar hums. Change to any magic you choose; you can come back at any time."
	elif world:
		var altar := world.cell_to_world(world.generator.magic_altar_cell())
		var offset := altar - player.global_position
		var tiles := roundi(offset.length() / TerrainTiles.TILE_SIZE)
		var where := "The Altar of Magic stands about %d tiles to the %s (it is on your map)." % [tiles, _compass(offset)]
		if player.magic_school == "":
			_status.text = "You have no magic yet. %s Go there to take up a school." % where
		else:
			_status.text = "Your magic: %s. %s Hold a magic weapon in slot 1 to cast its spells with the ability keys." % [MagicDB.SCHOOLS[player.magic_school]["name"], where]
	for school: String in _cards:
		var card := _cards[school]
		var current := school == player.magic_school
		var color: Color = MagicDB.SCHOOLS[school]["color"]
		var style := UITheme.card("card_selected" if current else "card", 12)
		card.add_theme_stylebox_override("panel", style)
		var button := card.find_child("Choose", true, false) as Button
		button.text = "Your magic" if current else ("Take up" if at_altar else "Visit the altar")
		button.disabled = current or not at_altar


static func _compass(offset: Vector2) -> String:
	var names := ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"]
	return names[posmod(roundi(offset.angle() / (PI / 4.0)), 8)]
