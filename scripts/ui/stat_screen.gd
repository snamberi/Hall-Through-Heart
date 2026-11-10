extends CanvasLayer
## The character sheet. Opens with C or Tab and pauses the game while open.

const TITLES := {
	"strength": "Strength",
	"vitality": "Vitality",
	"agility": "Agility",
	"luck": "Luck",
}

var _player: Player
var _title: Label
var _unspent: Label
var _value_labels: Dictionary[String, Label] = {}
var _effect_labels: Dictionary[String, Label] = {}
var _buttons: Dictionary[String, Button] = {}


func _ready() -> void:
	# Keep handling input while the rest of the game is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func setup(player: Player) -> void:
	_player = player
	_build()
	player.stats.stats_changed.connect(_refresh)
	player.stats.xp_changed.connect(func(_xp: int, _next: int) -> void: _refresh())
	_refresh()


func is_open() -> bool:
	return visible


func set_open(open: bool) -> void:
	if open and _player.is_dead():
		return
	visible = open
	get_tree().paused = open
	if open:
		_refresh()


func _input(event: InputEvent) -> void:
	if _player == null:
		return
	if event.is_action_pressed("toggle_stats") or (visible and event.is_action_pressed("ui_cancel")):
		set_open(not visible)
		get_viewport().set_input_as_handled()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)

	_title = _label("", 28)
	box.add_child(_title)
	_unspent = _label("", 18)
	_unspent.add_theme_color_override("font_color", Color(1.0, 0.8, 0.25))
	box.add_child(_unspent)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(grid)

	for stat in PlayerStats.STATS:
		grid.add_child(_label(TITLES[stat], 20))
		_value_labels[stat] = _label("0", 20)
		grid.add_child(_value_labels[stat])
		_effect_labels[stat] = _label("", 16)
		_effect_labels[stat].custom_minimum_size.x = 250.0
		_effect_labels[stat].add_theme_color_override("font_color", Color(0.7, 0.68, 0.62))
		grid.add_child(_effect_labels[stat])
		var button := Button.new()
		button.text = "+"
		button.custom_minimum_size = Vector2(40.0, 34.0)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_player.stats.spend_point.bind(stat))
		_buttons[stat] = button
		grid.add_child(button)

	var hint := _label("C / Tab / Esc to close", 14)
	hint.add_theme_color_override("font_color", Color(0.55, 0.53, 0.5))
	box.add_child(hint)


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _refresh() -> void:
	var stats := _player.stats
	_title.text = "Level %d      %d / %d XP" % [stats.level, stats.xp, stats.xp_to_next()]
	_unspent.text = "Points to spend: %d" % stats.unspent_points
	_effect_labels["strength"].text = "Damage %d" % roundi(stats.attack_damage(_player.attack_damage))
	_effect_labels["vitality"].text = "Max health %d" % roundi(stats.max_health())
	_effect_labels["agility"].text = "Speed %d, dodge every %.2fs" % [
		roundi(stats.move_speed(_player.move_speed)),
		stats.dodge_cooldown(_player.dodge_cooldown),
	]
	_effect_labels["luck"].text = "Critical hit chance %d%%" % roundi(stats.critical_chance() * 100.0)
	for stat in PlayerStats.STATS:
		_value_labels[stat].text = str(stats.points[stat])
		_buttons[stat].disabled = stats.unspent_points <= 0
