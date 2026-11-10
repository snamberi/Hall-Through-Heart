class_name GameMenu
extends PanelContainer
## Base for the screens inside the main menu (inventory, attributes, ...).
##
## Subclasses build their controls in _build() and update them in refresh().
## The panel frame and fonts come from UITheme.

var player: Player
## Add content to this.
var content: VBoxContainer


func setup(p_player: Player) -> void:
	player = p_player
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


static func make_label(text: String, font_size: int, color: Color = UITheme.TEXT) -> Label:
	return UITheme.label(text, font_size, color)
