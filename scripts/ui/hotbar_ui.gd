class_name HotbarUI
extends Control
## The item hotbar along the bottom of the screen.

const SLOT := 50.0
const GAP := 8.0

var _player: Player


func setup(player: Player) -> void:
	_player = player
	custom_minimum_size = Vector2(Hotbar.SIZE * (SLOT + GAP) - GAP, SLOT + 18.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if _player == null:
		return
	var font := UITheme.get_theme().default_font
	var hotbar := _player.hotbar
	var holding := ""
	var builder := get_tree().get_first_node_in_group("builder") as Builder
	if builder and builder.is_active():
		holding = builder._item_id
	for index in Hotbar.SIZE:
		var rect := Rect2(index * (SLOT + GAP), 0, SLOT, SLOT)
		var id: String = hotbar.slots[index]
		var active := id != "" and id == holding
		draw_rect(rect.grow(2.0), Color(0.02, 0.02, 0.04, 0.85))
		draw_rect(rect, Color(0.07, 0.08, 0.13, 0.92))
		if id != "":
			var count := hotbar.count_in(index)
			var definition: Dictionary = ItemDB.ITEMS[id]
			var item := Item.create(id) if count == 0 else hotbar.item_in(index)
			draw_texture_rect(item.icon(), rect.grow(-8.0), false, Color.WHITE if count > 0 else Color(0.4, 0.4, 0.45, 0.8))
			if count > 1 or definition.has("place") or definition.has("use"):
				var text := str(count)
				draw_string_outline(font, rect.position + Vector2(0, SLOT - 4.0), text, HORIZONTAL_ALIGNMENT_RIGHT, SLOT - 4.0, 13, 3, Color.BLACK)
				draw_string(font, rect.position + Vector2(0, SLOT - 4.0), text, HORIZONTAL_ALIGNMENT_RIGHT, SLOT - 4.0, 13, Color.WHITE if count > 0 else UITheme.BAD)
		var border := Color("d9b26a") if active else Color("8a683a")
		draw_rect(rect, border, false, 3.0 if active else 1.5)
		if active:
			draw_rect(rect.grow(3.0), Color(0.95, 0.8, 0.45, 0.35 + 0.25 * sin(Time.get_ticks_msec() / 200.0)), false, 1.0)
		var key := GameSettings.describe("hotbar_%d" % (index + 1)).split(" / ")[0]
		draw_string_outline(font, rect.position + Vector2(4, 14), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 3, Color.BLACK)
		draw_string(font, rect.position + Vector2(4, 14), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UITheme.HEADING)
