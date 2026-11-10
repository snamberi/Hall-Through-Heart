class_name GameMenu
extends PanelContainer
## Base for full-screen menus (character, mastery, and later ones).
##
## Subclasses build their controls in _build() and update them in refresh().

var player: Player
## Add content to this.
var content: VBoxContainer


func setup(p_player: Player) -> void:
	player = p_player
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.065, 0.085, 0.96)
	style.border_color = Color(0.45, 0.4, 0.33)
	style.set_border_width_all(2)
	style.set_content_margin_all(28)
	add_theme_stylebox_override("panel", style)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	add_child(content)
	_build()


func _build() -> void:
	pass


func refresh() -> void:
	pass


## Call from signal handlers: refreshes only while the menu is on screen.
func refresh_if_open() -> void:
	if is_visible_in_tree():
		refresh()


static func make_label(text: String, font_size: int, color: Color = Color(0.9, 0.87, 0.8)) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
