class_name Swatches
extends HBoxContainer
## A row of colour buttons for one part of the player's look.

signal picked(index: int)

var _buttons: Array[Button] = []


static func create(colors: Array, selected: int) -> Swatches:
	var row := Swatches.new()
	row.add_theme_constant_override("separation", 6)
	for index in colors.size():
		var button := Button.new()
		button.custom_minimum_size = Vector2(34, 30)
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		var style := StyleBoxFlat.new()
		style.bg_color = Color(colors[index][0])
		style.border_color = Color(colors[index][2])
		style.set_border_width_all(2)
		style.set_corner_radius_all(3)
		var chosen := style.duplicate() as StyleBoxFlat
		chosen.border_color = UITheme.GOLD
		chosen.set_border_width_all(3)
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", chosen)
		button.add_theme_stylebox_override("pressed", chosen)
		button.add_theme_stylebox_override("hover_pressed", chosen)
		button.button_pressed = index == selected
		button.pressed.connect(func() -> void:
			row.select(index)
			row.picked.emit(index)
		)
		row.add_child(button)
		row._buttons.append(button)
	return row


func select(index: int) -> void:
	for other in _buttons.size():
		_buttons[other].set_pressed_no_signal(other == index)
