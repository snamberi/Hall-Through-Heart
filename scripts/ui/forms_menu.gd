class_name FormsMenu
extends GameMenu
## The shapes the player can take: one card each, with its face, what it
## is, what it gives, and the level it unlocks at. Click an unlocked form
## to make it the one the transform key calls.

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
		button.custom_minimum_size = Vector2(262.0, 258.0)
		button.pressed.connect(func() -> void:
			var problem := player.transformations.choose(id)
			if problem != "":
				_note.text = problem
			refresh()
		)
		UITheme.sounds(button)
		var face := TextureRect.new()
		face.name = "Face"
		face.texture = TransformMeter.portrait(id)
		face.position = Vector2(12, 12)
		face.size = Vector2(72, 72)
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(face)
		var name_label := UITheme.heading(form["name"], 18)
		name_label.name = "Name"
		name_label.position = Vector2(94, 12)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(name_label)
		var state := UITheme.label("", 13, UITheme.DIM)
		state.name = "State"
		state.position = Vector2(94, 38)
		state.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(state)
		var seconds := UITheme.label("Lasts %d seconds" % roundi(form["seconds"]), 12, UITheme.DIM)
		seconds.position = Vector2(94, 58)
		seconds.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(seconds)
		var text := UITheme.label(form["text"], 12, UITheme.TEXT)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD
		text.custom_minimum_size = Vector2(238, 52)
		text.position = Vector2(12, 88)
		text.size = Vector2(238, 52)
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(text)
		var lines: PackedStringArray = []
		for stat: String in form["mods"]:
			for kind: String in form["mods"][stat]:
				var value: float = form["mods"][stat][kind]
				var words := ItemDB.describe_modifier({"stat": stat, "kind": kind, "value": absf(value)})
				lines.append(words if value >= 0.0 else "-" + words.substr(1))
		var gifts := UITheme.label("\n".join(lines), 12, UITheme.GOOD)
		gifts.add_theme_constant_override("line_spacing", -2)
		gifts.position = Vector2(12, 146)
		gifts.size = Vector2(238, 106)
		gifts.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(gifts)
		grid.add_child(button)
		_cards[id] = button
	player.transformations.changed.connect(refresh_if_open)


func refresh() -> void:
	# As many cards a row as the window has room for.
	(content.get_node("Grid") as GridContainer).columns = columns_for(Vector2(272.0, 268.0), Transformations.FORMS.size(), 2, 4)
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
		style.bg_color = Color("151823") if unlocked else Color("0e1018")
		style.border_color = (form["color"] as Color) if chosen else Color("3a3e50")
		style.set_border_width_all(3 if chosen else 1)
		if chosen:
			style.bg_color = (form["color"] as Color).darkened(0.82)
		var hover := style.duplicate()
		hover.bg_color = style.bg_color.lightened(0.07)
		for state: String in ["normal", "pressed", "disabled"]:
			button.add_theme_stylebox_override(state, style)
		button.add_theme_stylebox_override("hover", hover)
		(button.get_node("Face") as TextureRect).modulate = (form["tint"] as Color) if unlocked else Color(0.12, 0.12, 0.16)
		var state_label := button.get_node("State") as Label
		state_label.text = "Chosen" if chosen else "Click to choose" if unlocked else "Unlocks at level %d" % form["level"]
		state_label.add_theme_color_override("font_color", UITheme.GOLD if chosen else UITheme.DIM if unlocked else UITheme.BAD)
		button.modulate.a = 1.0 if unlocked else 0.75
