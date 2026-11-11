extends Control
## The ability bar, down the left side of the screen: the four abilities the
## keys use now, large, and the other set of four small beside them.

const SLOT := 58.0
const GAP := 10.0
const SMALL := 26.0

var _player: Player
var _font: Font


func setup(player: Player) -> void:
	_player = player
	_font = UITheme.get_theme().default_font
	custom_minimum_size = Vector2(SLOT + SMALL + 24.0, AbilityDB.SET_SIZE * (SLOT + GAP) + 30.0)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if _player == null:
		return
	var abilities := _player.abilities
	var other := (abilities.active_set + 1) % AbilityDB.SETS
	# A plate behind the bar.
	var plate := Rect2(-6, -8, SLOT + SMALL + 26.0, AbilityDB.SET_SIZE * (SLOT + GAP) + 36.0)
	draw_rect(plate, Color(0.03, 0.04, 0.07, 0.55))
	draw_rect(plate, Color("8a683a"), false, 1.0)
	for index in AbilityDB.SET_SIZE:
		var rect := Rect2(0, index * (SLOT + GAP), SLOT, SLOT)
		var id: String = abilities.loadout[abilities.active_set * AbilityDB.SET_SIZE + index]
		draw_rect(rect, Color(0.05, 0.05, 0.08, 0.92))
		var border := Color(0.4, 0.37, 0.32)
		if id != "":
			border = _draw_ability(id, rect)
		draw_rect(rect, border, false, 2.0)
		# Its key, read from the current bindings.
		var key := GameSettings.describe("ability_%d" % (index + 1)).split(" / ")[0]
		draw_string_outline(_font, rect.position + Vector2(4, 15), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 3, Color.BLACK)
		draw_string(_font, rect.position + Vector2(4, 15), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UITheme.TEXT)
		# The matching slot of the other set, small, to the right.
		var small := Rect2(SLOT + 8.0, index * (SLOT + GAP) + (SLOT - SMALL) / 2.0, SMALL, SMALL)
		draw_rect(small, Color(0.05, 0.05, 0.08, 0.8))
		var other_id: String = abilities.loadout[other * AbilityDB.SET_SIZE + index]
		if other_id != "":
			draw_texture_rect(ItemDB.icon(AbilityDB.ABILITIES[other_id]["icon"]), small.grow(-3.0), false, Color(0.6, 0.6, 0.65))
		draw_rect(small, Color(0.3, 0.28, 0.26), false, 1.0)
	var swap := GameSettings.describe("ability_swap").split(" / ")[0]
	var label := "Set %d   [%s] switch" % [abilities.active_set + 1, swap]
	draw_string_outline(_font, Vector2(0, AbilityDB.SET_SIZE * (SLOT + GAP) + 14.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 3, Color.BLACK)
	draw_string(_font, Vector2(0, AbilityDB.SET_SIZE * (SLOT + GAP) + 14.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UITheme.HEADING)


func _draw_ability(id: String, rect: Rect2) -> Color:
	var ability: Dictionary = AbilityDB.ABILITIES[id]
	var reason := _player.abilities.blocked_reason(id)
	var tint := Color.WHITE if reason in ["", "cooldown"] else Color(0.4, 0.4, 0.45)
	draw_texture_rect(ItemDB.icon(ability["icon"]), rect.grow(-9.0), false, tint)
	match reason:
		"locked", "weapon":
			draw_rect(rect, Color(0.0, 0.0, 0.0, 0.5))
			var note := "Mastery %d" % ability["mastery"] if reason == "locked" and ability.has("mastery") else "Needs %s" % WeaponMastery.NAMES[ability["weapon"]].to_lower() if reason == "weapon" else "Locked"
			draw_string(_font, rect.position + Vector2(0, SLOT - 6.0), note, HORIZONTAL_ALIGNMENT_CENTER, SLOT, 9, Color(0.85, 0.78, 0.6))
			return Color(0.3, 0.28, 0.26)
		"cooldown":
			var left: float = _player.abilities.cooldowns[id]
			var share: float = left / ability["cooldown"]
			draw_rect(Rect2(rect.position, Vector2(SLOT, SLOT * share)), Color(0.0, 0.0, 0.0, 0.65))
			draw_string_outline(_font, rect.position + Vector2(0, 38), "%.1f" % left, HORIZONTAL_ALIGNMENT_CENTER, SLOT, 18, 4, Color.BLACK)
			draw_string(_font, rect.position + Vector2(0, 38), "%.1f" % left, HORIZONTAL_ALIGNMENT_CENTER, SLOT, 18, Color.WHITE)
			return Color(0.4, 0.37, 0.32)
		"stamina":
			return Color(0.85, 0.7, 0.25)
		"mana":
			return Color(0.35, 0.55, 1.0)
	return Color(0.95, 0.85, 0.55)
