class_name TrophyMenu
extends GameMenu
## Choosing the trophy on a Trophy Stand. Every boss's trophy is a card:
## its trophy drawn large in whole pixels, its name, what it gives, and
## whether it is earned, on this stand or on another. Picking an earned one
## sets it here (moving it from any other stand). The bonuses of everything
## on show are summed along the bottom.

const COLUMNS := 4
const CARD := Vector2(278.0, 78.0)

## The stand being dressed (a Buildings record).
var stand: Dictionary = {}

var _grid: GridContainer
var _summary: Label
var _clear: Button


func _build() -> void:
	content.add_theme_constant_override("separation", 10)
	var title := UITheme.heading("TROPHY HALL", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var intro := UITheme.label("Set a beaten boss's trophy on this stand. Each trophy on show in your houses gives its bonus.", 15, UITheme.DIM)
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(intro)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	content.add_child(_grid)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	content.add_child(bottom)
	_summary = UITheme.label("", 15, UITheme.GOOD)
	_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bottom.add_child(_summary)
	_clear = UITheme.button("Clear this stand", func() -> void:
		_buildings().set_trophy(stand, "")
		refresh()
	, 180.0)
	bottom.add_child(_clear)


func _buildings() -> Buildings:
	return player.get_parent().get_node("Buildings")


func refresh() -> void:
	for child in _grid.get_children():
		child.queue_free()
	var codex: Codex = player.get_parent().get_node_or_null("Codex")
	var earned := Trophies.earned(codex)
	var shown := _buildings().shown_trophies()
	for boss: String in Trophies.TROPHIES:
		_grid.add_child(_card(boss, boss in earned, boss in shown))
	_clear.disabled = stand.get("trophy", "") == ""
	var parts: PackedStringArray = []
	var seen := {}
	for boss: String in shown:
		if not seen.has(boss):
			seen[boss] = true
			parts.append(Trophies.TROPHIES[boss]["text"])
	_summary.text = ("On show (%d): %s" % [parts.size(), ", ".join(parts)]) if not parts.is_empty() else "Nothing on show yet. Beat a world boss to earn its trophy."
	_summary.add_theme_color_override("font_color", UITheme.GOOD if not parts.is_empty() else UITheme.DIM)


func _card(boss: String, earned: bool, shown: bool) -> Button:
	var here: bool = stand.get("trophy", "") == boss
	var data: Dictionary = Trophies.TROPHIES[boss]
	var button := Button.new()
	button.custom_minimum_size = CARD
	var look := "card_selected" if here else ("card" if earned else "card_dim")
	for state: String in ["normal", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, UITheme.card(look, 6))
	button.add_theme_stylebox_override("hover", UITheme.card("card_selected" if here else ("card_hover" if earned else "card_dim"), 6))
	button.disabled = not earned
	button.tooltip_text = "" if earned else "Beat %s to earn it." % BossDB.BOSSES[boss]["name"]
	button.pressed.connect(func() -> void:
		_buildings().set_trophy(stand, boss)
		Audio.play("pickup", -6.0)
		refresh()
	)
	UITheme.sounds(button)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(row)
	var art := Control.new()
	art.custom_minimum_size = Vector2(48, 64)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.draw.connect(func() -> void: Trophies.draw(art, boss, Vector2(24, 50), 3, not earned))
	row.add_child(art)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(words)
	words.add_child(UITheme.strong(data["name"] if earned else "Unknown trophy", 15, UITheme.GOLD if here else (UITheme.TEXT if earned else UITheme.DIM)))
	words.add_child(UITheme.label(data["text"], 14, UITheme.GOOD if earned else UITheme.DIM))
	var status: String = "On this stand" if here else ("On another stand" if shown else ("Earned" if earned else BossDB.BOSSES[boss]["name"]))
	words.add_child(UITheme.label(status, 13, UITheme.INFO if here or shown else UITheme.DIM))
	for control: Control in words.get_children():
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return button
