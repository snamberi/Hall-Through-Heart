extends Control
## The row of ability slots at the bottom of the screen.
##
## Shows the abilities of the weapon in hand with their key, cooldown, and
## whether they are locked or too costly right now.

const SLOT := 56.0
const GAP := 8.0

var _player: Player
var _font: Font


func setup(player: Player) -> void:
	_player = player
	_font = UITheme.get_theme().default_font
	custom_minimum_size = Vector2(AbilityDB.SLOTS * SLOT + (AbilityDB.SLOTS - 1) * GAP, SLOT + 18.0)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if _player == null:
		return
	var ids := _player.abilities.slots()
	for index in AbilityDB.SLOTS:
		var rect := Rect2(index * (SLOT + GAP), 0, SLOT, SLOT)
		draw_rect(rect, Color(0.05, 0.05, 0.07, 0.8))
		var border := Color(0.4, 0.37, 0.32)
		if index < ids.size():
			border = _draw_ability(ids[index], rect)
		draw_rect(rect, border, false, 2.0)
		draw_string(_font, rect.position + Vector2(5, 15), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.9, 0.87, 0.8))


func _draw_ability(id: String, rect: Rect2) -> Color:
	var ability: Dictionary = AbilityDB.ABILITIES[id]
	var reason := _player.abilities.blocked_reason(id)
	var tint := Color.WHITE if reason == "" else Color(0.4, 0.4, 0.45)
	draw_texture_rect(ItemDB.icon(ability["icon"]), rect.grow(-8.0), false, tint)
	draw_string(_font, Vector2(rect.position.x - 8.0, SLOT + 14.0), ability["name"], HORIZONTAL_ALIGNMENT_CENTER, SLOT + 16.0, 11, Color(0.75, 0.72, 0.66))

	match reason:
		"locked":
			draw_rect(rect, Color(0.0, 0.0, 0.0, 0.55))
			var needs := "Mastery %d" % ability["mastery"] if ability.has("mastery") else "Level %d" % ability["level"]
			draw_string(_font, rect.position + Vector2(0, 36), needs, HORIZONTAL_ALIGNMENT_CENTER, SLOT, 11, Color(0.8, 0.75, 0.6))
			return Color(0.3, 0.28, 0.26)
		"cooldown":
			var left: float = _player.abilities.cooldowns[id]
			var share: float = left / ability["cooldown"]
			draw_rect(Rect2(rect.position, Vector2(SLOT, SLOT * share)), Color(0.0, 0.0, 0.0, 0.65))
			draw_string(_font, rect.position + Vector2(0, 38), "%.1f" % left, HORIZONTAL_ALIGNMENT_CENTER, SLOT, 18, Color.WHITE)
			return Color(0.4, 0.37, 0.32)
		"stamina":
			return Color(0.75, 0.62, 0.22, 0.6)
		"mana":
			return Color(0.45, 0.6, 0.95, 0.6)
	return Color(0.95, 0.85, 0.55)
