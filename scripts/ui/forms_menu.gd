class_name FormsMenu
extends GameMenu
## The shapes the player can take: one card each, with its face, what it
## is, what it gives, and the level it unlocks at. Click an unlocked form
## to make it the one the transform key calls.

const CARD := Vector2(296.0, 316.0)

var _cards: Dictionary[String, Button] = {}
var _note: Label


func _build() -> void:
	var title := UITheme.heading("FORMS", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	_note = UITheme.label("", 14, UITheme.DIM)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD
	_note.custom_minimum_size.x = 1000.0
	content.add_child(_note)
	var grid := GridContainer.new()
	grid.name = "Grid"
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	content.add_child(grid)
	for id: String in Transformations.FORMS:
		var form: Dictionary = Transformations.FORMS[id]
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = CARD
		button.pressed.connect(func() -> void:
			var problem := player.transformations.choose(id)
			if problem != "":
				_note.text = problem
			refresh()
		)
		UITheme.sounds(button)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(box)
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 10)
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(top)
		# The creature, large, on a dark round plate.
		var plate := Control.new()
		plate.custom_minimum_size = Vector2(96, 96)
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tint: Color = form["color"]
		plate.draw.connect(func() -> void:
			plate.draw_circle(Vector2(48, 48), 47.0, Color("0b0e17"))
			plate.draw_arc(Vector2(48, 48), 47.0, 0.0, TAU, 40, tint.darkened(0.3), 2.0)
		)
		top.add_child(plate)
		var face := TextureRect.new()
		face.name = "Face"
		face.texture = TransformMeter.portrait(id)
		face.position = Vector2(6, 4)
		face.size = Vector2(84, 84)
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate.add_child(face)
		var words := VBoxContainer.new()
		words.add_theme_constant_override("separation", 4)
		words.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_child(words)
		var name_label := UITheme.heading(form["name"], 20)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		words.add_child(name_label)
		# Whether it can be taken, on a badge that cannot be missed.
		var badge := PanelContainer.new()
		badge.name = "Badge"
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var badge_row := HBoxContainer.new()
		badge_row.add_theme_constant_override("separation", 5)
		badge_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_child(badge_row)
		var mark := StateMark.make("locked", 14.0)
		mark.name = "Mark"
		badge_row.add_child(mark)
		var state := UITheme.label("", 14)
		state.name = "State"
		state.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge_row.add_child(state)
		words.add_child(badge)
		var seconds := UITheme.label("Lasts %d seconds" % roundi(form["seconds"]), 14, UITheme.DIM)
		seconds.mouse_filter = Control.MOUSE_FILTER_IGNORE
		words.add_child(seconds)
		var text := UITheme.label(form["text"], 14, Color("c8bfae"))
		text.autowrap_mode = TextServer.AUTOWRAP_WORD
		text.custom_minimum_size = Vector2(CARD.x - 20.0, 0)
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(text)
		# What changes, each with its picture.
		for stat: String in form["mods"]:
			for kind: String in form["mods"][stat]:
				var value: float = form["mods"][stat][kind]
				var gain := value >= 0.0 if stat != "damage_taken" else value < 0.0
				var line := HBoxContainer.new()
				line.add_theme_constant_override("separation", 5)
				line.mouse_filter = Control.MOUSE_FILTER_IGNORE
				var icon := TextureRect.new()
				icon.texture = ItemText.stat_icon(stat)
				icon.custom_minimum_size = Vector2(16, 16)
				icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
				line.add_child(icon)
				var amount := ItemDB.describe_modifier({"stat": stat, "kind": kind, "value": absf(value)})
				var stat_label := UITheme.label(amount if value >= 0.0 else "-" + amount.substr(1), 14, UITheme.GOOD if gain else UITheme.BAD)
				stat_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
				line.add_child(stat_label)
				box.add_child(line)
		grid.add_child(button)
		_cards[id] = button
	player.transformations.changed.connect(refresh_if_open)


func refresh() -> void:
	# As many cards a row as the window has room for.
	(content.get_node("Grid") as GridContainer).columns = columns_for(CARD + Vector2(10.0, 10.0), Transformations.FORMS.size(), 2, 4)
	var forms := player.transformations
	var key := GameSettings.describe("transform").split(" / ")[0]
	_note.text = "The meter on the left of the screen fills in a minute, or with %d blows landed. When it is full, hold %s for %d seconds to change shape." % [Transformations.CHARGE_HITS, key, roundi(Transformations.HOLD_SECONDS)]
	var current := forms.current()
	for id in _cards:
		var form: Dictionary = Transformations.FORMS[id]
		var button := _cards[id]
		var unlocked := forms.is_unlocked(id)
		var chosen := id == current
		var style := StyleBoxFlat.new()
		style.bg_color = (form["color"] as Color).darkened(0.84) if chosen else Color("151823") if unlocked else Color("0e1018")
		style.border_color = (form["color"] as Color) if chosen else Color("6a6f88") if unlocked else Color("3c4054")
		style.set_border_width_all(3 if chosen else 2)
		var hover := style.duplicate() as StyleBoxFlat
		hover.bg_color = style.bg_color.lightened(0.07)
		if not chosen:
			hover.border_color = Color("8a683a")
		var pressed := style.duplicate() as StyleBoxFlat
		pressed.bg_color = style.bg_color.darkened(0.3)
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", hover)
		button.add_theme_stylebox_override("pressed", pressed)
		(button.find_child("Face", true, false) as TextureRect).modulate = (form["tint"] as Color) if unlocked else Color(0.16, 0.14, 0.3)
		var badge := button.find_child("Badge", true, false) as PanelContainer
		var badge_style := StyleBoxFlat.new()
		badge_style.set_content_margin_all(3)
		badge_style.content_margin_left = 7
		badge_style.content_margin_right = 9
		badge_style.set_corner_radius_all(3)
		badge_style.set_border_width_all(1)
		var color := UITheme.GOLD if chosen else UITheme.GOOD if unlocked else UITheme.BAD
		badge_style.bg_color = color.darkened(0.75)
		badge_style.border_color = color
		badge.add_theme_stylebox_override("panel", badge_style)
		(button.find_child("Mark", true, false) as StateMark).set_kind("ready" if unlocked else "locked")
		var state := button.find_child("State", true, false) as Label
		state.text = "Chosen" if chosen else "Click to choose" if unlocked else "Unlocks at level %d" % form["level"]
		state.add_theme_color_override("font_color", color)
