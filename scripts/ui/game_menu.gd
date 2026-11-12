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


## The room a screen has: the window in interface units, less a margin.
func available_size() -> Vector2:
	return get_viewport().get_visible_rect().size - Vector2(60.0, 120.0)


## How many cards a row suits the window best: the count (between `least`
## and `most`) that lets `count` cards of `card` size show largest, given
## `extra` room the rest of the screen takes.
func columns_for(card: Vector2, count: int, least: int, most: int, extra: Vector2 = Vector2(40.0, 160.0)) -> int:
	var room := available_size()
	var best := most
	var best_scale := 0.0
	for columns in range(least, most + 1):
		var rows := ceili(float(count) / columns)
		var need := Vector2(columns * card.x, rows * card.y) + extra
		var fit := minf(1.0, minf(room.x / need.x, room.y / need.y))
		if fit > best_scale + 0.001:
			best_scale = fit
			best = columns
	return best


## Call from signal handlers: refreshes only while the menu is on screen.
func refresh_if_open() -> void:
	if is_visible_in_tree():
		refresh()


static func make_label(text: String, font_size: int, color: Color = UITheme.TEXT) -> Label:
	return UITheme.label(text, font_size, color)
