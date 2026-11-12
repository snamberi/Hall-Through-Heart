class_name HotbarUI
extends Control
## The hotbar along the bottom of the screen: the quick item (Q), the belt
## (a magic weapon, two weapons with the off hand tucked beside them, and
## the three tools), three slots for potions and food, and the armour worn.

const SLOT := 48.0
const GAP := 5.0
const GROUP_GAP := 14.0
const MINI := 26.0
const ARMOUR: Array[String] = ["helmet", "chest", "legs", "boots"]
const ARMOUR_ICONS := {"helmet": 6, "chest": 7, "legs": 8, "boots": 9}

var _player: Player
## Slot rects by hotbar index, laid out once.
var _rects: Array[Rect2] = []
var _quick_rect := Rect2()
var _off_rect := Rect2()
var _armour_rects: Array[Rect2] = []
var _flash: Array[float] = []


func setup(player: Player) -> void:
	_player = player
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var x := 0.0
	_quick_rect = Rect2(x, 0, SLOT, SLOT)
	x += SLOT + GROUP_GAP
	for index in Hotbar.SIZE:
		_rects.append(Rect2(x, 0, SLOT, SLOT))
		_flash.append(0.0)
		x += SLOT + GAP
		if index == 2:
			# The off hand rides beside the weapons, small.
			_off_rect = Rect2(x, SLOT - MINI, MINI, MINI)
			x += MINI + GROUP_GAP
		elif index == 5:
			x += GROUP_GAP - GAP
	x += GROUP_GAP - GAP
	for row in 2:
		for column in 2:
			_armour_rects.append(Rect2(x + column * (MINI - 3.0), row * (MINI - 3.0), MINI - 4.0, MINI - 4.0))
	x += (MINI - 3.0) * 2.0
	custom_minimum_size = Vector2(x, SLOT + 18.0)
	player.hotbar.changed.connect(queue_redraw)


func _process(delta: float) -> void:
	for index in _flash.size():
		_flash[index] = maxf(_flash[index] - delta * 3.0, 0.0)
		if _player and Input.is_action_just_pressed("hotbar_%d" % (index + 1)):
			_flash[index] = 1.0
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

	# Q: the quick item.
	var quick := hotbar.quick_item()
	var quick_id := hotbar.quick_id
	_slot(_quick_rect, quick if quick else (Item.create(quick_id) if quick_id != "" else null), 44, quick == null, false)
	if quick_id != "":
		_count(_quick_rect, _player.inventory.count_of(quick_id), font)
	_key(_quick_rect, GameSettings.describe("quick_use").split(" / ")[0], font)

	for index in Hotbar.SIZE:
		var rect := _rects[index]
		var item := hotbar.item_in(index)
		var id := hotbar.id_in(index)
		var active := hotbar.is_active(index) or (id != "" and id == holding)
		var shown: Item = item if item else (Item.create(id) if id != "" else null)
		_slot(rect, shown, Hotbar.GHOST_ICONS[index], item == null, active)
		if id != "":
			_count(rect, hotbar.count_in(index), font)
		if _flash[index] > 0.0:
			draw_rect(rect, Color(1, 1, 1, 0.3 * _flash[index]))
		_key(rect, GameSettings.describe("hotbar_%d" % (index + 1)).split(" / ")[0], font)
		if shown == null:
			draw_string(font, rect.position + Vector2(0, SLOT + 12.0), Hotbar.LABELS[index], HORIZONTAL_ALIGNMENT_CENTER, SLOT, 10, Color(0.6, 0.62, 0.7, 0.75))

	# The off hand, small; dimmed while both hands are on the weapon.
	var off := _player.equipment.get_item("off_hand")
	var weapon := _player.equipment.weapon()
	var two_handed: bool = weapon != null and weapon.definition().get("two_handed", false)
	_mini(_off_rect, off, 5, two_handed)

	# What is worn.
	for index in ARMOUR.size():
		_mini(_armour_rects[index], _player.equipment.get_item(ARMOUR[index]), ARMOUR_ICONS[ARMOUR[index]], false)


func _slot(rect: Rect2, item: Item, ghost: int, missing: bool, active: bool) -> void:
	draw_rect(rect.grow(2.0), Color(0.02, 0.02, 0.04, 0.85))
	var fill := Color(0.07, 0.08, 0.13, 0.92)
	var border := Color("8a683a")
	if item and not missing:
		fill = item.color().darkened(0.84)
		fill.a = 0.94
		border = item.color().darkened(0.15)
	draw_rect(rect, fill)
	if item:
		draw_texture_rect(item.icon(), rect.grow(-7.0), false, item.icon_tint() if not missing else Color(0.4, 0.4, 0.45, 0.8))
	else:
		draw_texture_rect(ItemDB.icon(ghost), rect.grow(-11.0), false, Color(1, 1, 1, 0.13))
	draw_rect(rect, Color("f0d28a") if active else border, false, 3.0 if active else 1.5)
	if active:
		draw_rect(rect.grow(3.0), Color(0.95, 0.8, 0.45, 0.35 + 0.25 * sin(Time.get_ticks_msec() / 200.0)), false, 1.0)
		# A little marker above the slot in hand.
		var top := rect.position + Vector2(rect.size.x / 2.0, -5.0)
		draw_colored_polygon(PackedVector2Array([top + Vector2(-5, -5), top + Vector2(5, -5), top]), Color("f0d28a"))


func _mini(rect: Rect2, item: Item, ghost: int, dimmed: bool) -> void:
	draw_rect(rect.grow(1.5), Color(0.02, 0.02, 0.04, 0.85))
	draw_rect(rect, item.color().darkened(0.84) if item else Color(0.07, 0.08, 0.13, 0.92))
	if item:
		draw_texture_rect(item.icon(), rect.grow(-3.0), false, Color(item.icon_tint(), 0.45 if dimmed else 1.0))
	else:
		draw_texture_rect(ItemDB.icon(ghost), rect.grow(-4.0), false, Color(1, 1, 1, 0.12))
	draw_rect(rect, item.color().darkened(0.15) if item else Color("5a4a32"), false, 1.0)


func _count(rect: Rect2, count: int, font: Font) -> void:
	var text := str(count)
	draw_string_outline(font, rect.position + Vector2(0, SLOT - 4.0), text, HORIZONTAL_ALIGNMENT_RIGHT, SLOT - 4.0, 13, 3, Color.BLACK)
	draw_string(font, rect.position + Vector2(0, SLOT - 4.0), text, HORIZONTAL_ALIGNMENT_RIGHT, SLOT - 4.0, 13, Color.WHITE if count > 0 else UITheme.BAD)


func _key(rect: Rect2, key: String, font: Font) -> void:
	draw_string_outline(font, rect.position + Vector2(4, 13), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color.BLACK)
	draw_string(font, rect.position + Vector2(4, 13), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UITheme.HEADING)
