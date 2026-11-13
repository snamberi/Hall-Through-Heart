class_name RewardCard
extends PanelContainer
## A card that slides in on the right when a quest or errand pays out: its
## title, and every reward with its picture. Cards queue up and each stays
## a few seconds.

const STAY := 4.5

var _queue: Array[Dictionary] = []
var _showing := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", UITheme.tooltip_box())
	custom_minimum_size = Vector2(262, 0)
	modulate.a = 0.0
	visible = false


## heading: "QUEST COMPLETE"; title: the quest; xp/gold; items: Item list.
func show_reward(heading: String, title: String, xp: int, gold: int, items: Array) -> void:
	_queue.append({"heading": heading, "title": title, "xp": xp, "gold": gold, "items": items})
	if not _showing:
		_next()


func _next() -> void:
	if _queue.is_empty():
		_showing = false
		visible = false
		return
	_showing = true
	var card: Dictionary = _queue.pop_front()
	for child in get_children():
		child.queue_free()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	add_child(column)
	column.add_child(UITheme.label(card["heading"], 12, Color(0.75, 0.6, 1.0)))
	var title := UITheme.heading(card["title"], 17)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD
	title.custom_minimum_size = Vector2(240, 0)
	column.add_child(title)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 4)
	column.add_child(flow)
	if card["xp"] > 0:
		flow.add_child(UITheme.label("+%d XP" % card["xp"], 14, Color(0.8, 0.68, 1.0)))
	if card["gold"] > 0:
		flow.add_child(_chip(ItemDB.icon(17), "+%d" % card["gold"], UITheme.GOLD))
	for item: Item in card["items"]:
		var text := "x%d" % item.count if item.count > 1 or not item.is_equipment() else item.display_name()
		flow.add_child(_chip(item.icon(), text, ItemDB.RARITIES[item.rarity]["color"] if item.is_equipment() else UITheme.TEXT, item.icon_tint()))
	visible = true
	reset_size()
	var tween := create_tween()
	position.x = get_parent_area_size().x + 10.0
	tween.tween_property(self, "modulate:a", 1.0, 0.2)
	tween.parallel().tween_property(self, "position:x", get_parent_area_size().x - size.x - 14.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_interval(STAY)
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(_next)


func _chip(texture: Texture2D, text: String, color: Color, tint: Color = Color.WHITE) -> HBoxContainer:
	var chip := HBoxContainer.new()
	chip.add_theme_constant_override("separation", 3)
	var icon := TextureRect.new()
	icon.texture = texture
	icon.modulate = tint
	icon.custom_minimum_size = Vector2(22, 22)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	chip.add_child(icon)
	chip.add_child(UITheme.label(text, 13, color))
	return chip
