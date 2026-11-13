class_name ActionBar
extends Control
## A framed bar of slots. The HUD uses two: the four abilities the keys use
## now, in a column down the middle of the left side with the other set
## small beside them, and the hotbar along the bottom in labelled groups
## (the quick item, weapons with the off hand beside them, tools,
## supplies) and what is worn. Hover anything for what it is; click a
## hotbar slot to use it.
##
## Abilities show at a glance whether they can be used: bright and edged in
## gold when ready (with a flash the moment a cooldown ends), a clock-hand
## sweep while cooling down, tinted the colour of the mana or stamina they
## lack, and dark with a padlock while locked.

const ABILITY := 54.0
## The ability column on its own: bigger slots, the other set beside them.
const COLUMN_SLOT := 58.0
const COLUMN_GAP := 10.0
const COLUMN_MINI := 26.0
const SLOT := 48.0
const GAP := 5.0
const GROUP := 18.0
const MINI := 24.0
const TITLE := 17.0
const PAD := 12.0
const ARMOUR: Array[String] = ["helmet", "chest", "legs", "boots"]
const ARMOUR_ICONS := {"helmet": 6, "chest": 7, "legs": 8, "boots": 9}

## What this bar holds; set before setup().
var show_abilities := true
var show_items := true

var _player: Player
var _tip: ItemTooltip
var _font: Font
## Every hoverable thing: [rect, kind, index] where kind is "ability",
## "quick", "hotbar", "off", "armour".
var _spots: Array = []
## [title, rect] for each group's plate.
var _groups: Array = []
var _hover := -1
## Per ability slot: whether it was ready last frame, and its flash.
var _was_ready: Array[bool] = [false, false, false, false]
var _ready_flash: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _press_flash: Array[float] = []
## Pixel-art frames (see tools/generate_ui.py).
var _plate_style: StyleBox = UITheme._frame("panel", 20, 0)
var _group_style: StyleBox = UITheme._frame("inset", 6, 0)
var _slot_styles := {"slot": UITheme.slot("slot"), "slot_hover": UITheme.slot("slot_hover"), "slot_active": UITheme.slot("slot_active")}


func setup(player: Player, tip: ItemTooltip) -> void:
	_player = player
	_tip = tip
	_font = UITheme.get_theme().default_font
	mouse_filter = Control.MOUSE_FILTER_STOP
	_layout()
	mouse_exited.connect(func() -> void:
		_hover = -1
		HudMenuButton.hovered = false
		_tip.hide_tip()
	)


func _layout() -> void:
	_spots.clear()
	_groups.clear()
	var top := PAD + TITLE
	var x := PAD
	var start := x
	if show_abilities and not show_items:
		# A column: four big slots, top to bottom.
		for index in AbilityDB.SET_SIZE:
			_spots.append([Rect2(x, top + index * (COLUMN_SLOT + COLUMN_GAP), COLUMN_SLOT, COLUMN_SLOT), "ability", index])
		var tall := AbilityDB.SET_SIZE * (COLUMN_SLOT + COLUMN_GAP) - COLUMN_GAP
		_groups.append(["Abilities", Rect2(x - 4.0, top - TITLE, COLUMN_SLOT + COLUMN_MINI + 18.0, tall + TITLE + 4.0)])
		custom_minimum_size = Vector2(PAD * 2.0 + COLUMN_SLOT + COLUMN_MINI + 10.0, top + tall + 22.0 + PAD)
		size = custom_minimum_size
		_press_flash.resize(Hotbar.SIZE)
		_press_flash.fill(0.0)
		return
	if show_abilities:
		for index in AbilityDB.SET_SIZE:
			_spots.append([Rect2(x, top, ABILITY, ABILITY), "ability", index])
			x += ABILITY + GAP
		_groups.append(["Abilities", Rect2(start - 4.0, top - TITLE, x - GAP - start + 8.0, ABILITY + TITLE + 4.0)])
		x += GROUP - GAP
	if show_items:
		var y := top + ABILITY - SLOT if show_abilities else top
		# The quick item.
		_spots.append([Rect2(x, y, SLOT, SLOT), "quick", 0])
		_groups.append(["Quick", Rect2(x - 4.0, y - TITLE, SLOT + 8.0, SLOT + TITLE + 4.0)])
		x += SLOT + GROUP
		# Weapons (with the off hand), tools, supplies.
		for group: Array in [["Arms", 0, 4], ["Tools", 4, 7], ["Supplies", 7, 10]]:
			start = x
			for index in range(group[1], group[2]):
				_spots.append([Rect2(x, y, SLOT, SLOT), "hotbar", index])
				x += SLOT + GAP
			if group[0] == "Arms":
				_spots.append([Rect2(x, y + SLOT - MINI, MINI, MINI), "off", 0])
				x += MINI + GAP
			_groups.append([group[0], Rect2(start - 4.0, y - TITLE, x - GAP - start + 8.0, SLOT + TITLE + 4.0)])
			x += GROUP - GAP
		# What is worn.
		start = x
		for index in ARMOUR.size():
			_spots.append([Rect2(x + (index % 2) * (MINI + 2.0), y + (index / 2) * (MINI + 2.0) - 2.0, MINI, MINI), "armour", index])
		x += MINI * 2.0 + 2.0
		_groups.append(["Worn", Rect2(start - 4.0, y - TITLE, x - start + 8.0, SLOT + TITLE + 4.0)])
		x += GROUP
	custom_minimum_size = Vector2(x - GROUP + PAD, top + (ABILITY if show_abilities else SLOT) + PAD)
	size = custom_minimum_size
	_press_flash.resize(Hotbar.SIZE)
	_press_flash.fill(0.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var found := -1
		for index in _spots.size():
			if (_spots[index][0] as Rect2).has_point(event.position):
				found = index
		HudMenuButton.hovered = true
		if found != _hover:
			_hover = found
			_show_tip()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _hover >= 0:
		var spot: Array = _spots[_hover]
		if spot[1] == "hotbar":
			var problem := _player.hotbar.activate(spot[2])
			if problem != "":
				DamageNumber.spawn_text(_player.get_parent(), _player.global_position + Vector2(0, -50), problem, UITheme.BAD, 13)
			_press_flash[spot[2]] = 1.0
		elif spot[1] == "quick":
			_player.hotbar.use_quick()
		accept_event()


func _show_tip() -> void:
	if _hover < 0:
		_tip.hide_tip()
		return
	var spot: Array = _spots[_hover]
	match spot[1]:
		"ability":
			var id := _ability_id(spot[2])
			if id == "":
				_tip.show_text("Empty", "Choose abilities on the Abilities screen.")
			else:
				_tip.show_text(AbilityDB.ABILITIES[id]["name"], _ability_text(id))
		"quick":
			var quick := _player.hotbar.quick_item()
			if quick:
				_tip.show_item(quick, _player, "[color=#%s]Quick-use: %s[/color]" % [UITheme.GOLD.to_html(false), _key("quick_use")])
			else:
				_tip.show_text("Quick-use", "Hover a potion or food in the inventory and press %s to put it here." % _key("quick_use"))
		"hotbar":
			if spot[2] < 2:
				var what := "Fight bare-handed with your combat style. Change styles in the Abilities screen." if spot[2] == 0 else (
					"Cast with your school of magic: the hand glows and fires bolts; the ability keys cast its spells." if _player.magic_school != "" else "Take up a school of magic at an Altar of Magic, then cast from here.")
				_tip.show_text(_player.hotbar.hand_name(spot[2]), "%s\nKey %s" % [what, _key("hotbar_%d" % (spot[2] + 1))])
				return
			var item := _player.hotbar.item_in(spot[2])
			if item:
				_tip.show_item(item, _player, "[color=#%s]Key %s[/color]" % [UITheme.GOLD.to_html(false), _key("hotbar_%d" % (spot[2] + 1))])
			else:
				_tip.show_text(Hotbar.LABELS[spot[2]], "Empty. Hover something in the inventory and press %s." % _key("hotbar_%d" % (spot[2] + 1)))
		"off":
			var off := _player.equipment.get_item("off_hand")
			if off:
				_tip.show_item(off, _player)
			else:
				_tip.show_text("Off hand", "Nothing held in the off hand.")
		"armour":
			var worn := _player.equipment.get_item(ARMOUR[spot[2]])
			if worn:
				_tip.show_item(worn, _player)
			else:
				_tip.show_text(ItemDB.SLOT_NAMES[ARMOUR[spot[2]]], "Nothing worn here.")


func _ability_text(id: String) -> String:
	var ability: Dictionary = AbilityDB.ABILITIES[id]
	var parts: PackedStringArray = [ability.get("text", "")]
	var costs: PackedStringArray = []
	if _player.abilities.stamina_cost(id) > 0.0:
		costs.append("%d stamina" % roundi(_player.abilities.stamina_cost(id)))
	if _player.abilities.mana_cost(id) > 0.0:
		costs.append("%d mana" % roundi(_player.abilities.mana_cost(id)))
	parts.append("Costs %s. Cooldown %ss." % [" and ".join(costs) if not costs.is_empty() else "nothing", str(ability.get("cooldown", 0.0))])
	match _player.abilities.blocked_reason(id):
		"locked":
			parts.append("Locked: needs %s." % ("%s mastery %d" % [WeaponMastery.NAMES.get(ability.get("weapon", ""), "weapon"), ability["mastery"]] if ability.has("mastery") else "level %d" % ability.get("level", 1)))
		"weapon":
			parts.append("Needs %s in hand." % str(WeaponMastery.NAMES[ability["weapon"]]).to_lower())
		"mana":
			parts.append("Not enough mana.")
		"stamina":
			parts.append("Not enough stamina.")
	return "\n".join(parts)


## What the keys use now: the moves in hand, or the universal ones.
func _set_name(abilities: AbilityUser) -> String:
	if abilities.active_set == 1:
		return "Universal"
	if abilities.casting():
		return "%s magic" % MagicDB.SCHOOLS[_player.magic_school]["short"]
	if _player.fighting_bare():
		return CombatStyles.STYLES[_player.styles.equipped]["name"]
	var weapon := _player.equipment.weapon()
	return weapon.definition()["name"] if weapon else "Nothing in hand"


func _ability_id(index: int) -> String:
	var abilities := _player.abilities
	return abilities.slots()[index]


func _key(action: String) -> String:
	return GameSettings.describe(action).split(" / ")[0]


func _process(delta: float) -> void:
	if _player == null:
		return
	for index in AbilityDB.SET_SIZE:
		_ready_flash[index] = maxf(_ready_flash[index] - delta * 2.5, 0.0)
		var id := _ability_id(index)
		var ready := id != "" and _player.abilities.blocked_reason(id) == ""
		if ready and not _was_ready[index]:
			_ready_flash[index] = 1.0
		_was_ready[index] = ready
	for index in _press_flash.size():
		_press_flash[index] = maxf(_press_flash[index] - delta * 3.0, 0.0)
		if Input.is_action_just_pressed("hotbar_%d" % (index + 1)):
			_press_flash[index] = 1.0
	queue_redraw()


func _draw() -> void:
	if _player == null:
		return
	# The frame: a riveted bronze plate, each group sunk into it.
	draw_style_box(_plate_style, Rect2(Vector2(-8, -8), size + Vector2(16, 16)))
	for group: Array in _groups:
		var rect: Rect2 = group[1]
		draw_style_box(_group_style, rect)
		draw_string_outline(_font, rect.position + Vector2(6, 14), group[0], HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 8.0, 13, 3, Color(0, 0, 0, 0.8))
		draw_string(_font, rect.position + Vector2(6, 14), group[0], HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 8.0, 13, Color("c8b07a"))
	# The column: the other set small beside each slot, the set below.
	if show_abilities and not show_items:
		var abilities := _player.abilities
		var others := abilities.other_slots()
		for index in AbilityDB.SET_SIZE:
			var slot: Rect2 = _spots[index][0]
			var mini_rect := Rect2(slot.end.x + 6.0, slot.position.y + (COLUMN_SLOT - COLUMN_MINI) / 2.0, COLUMN_MINI, COLUMN_MINI)
			draw_rect(mini_rect, Color(0.05, 0.05, 0.08, 0.85))
			var other_id: String = others[index] if index < others.size() else ""
			if other_id != "":
				draw_texture_rect(AbilityDB.icon(other_id), mini_rect.grow(-3.0), false, Color(0.62, 0.62, 0.68))
			draw_rect(mini_rect, Color(0.3, 0.28, 0.26), false, 1.0)
		var label := "%s  %s" % [_set_name(abilities), _key("ability_swap")]
		var bottom: Rect2 = _groups[0][1]
		draw_string_outline(_font, Vector2(bottom.position.x + 4.0, bottom.end.y + 15.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 3, Color.BLACK)
		draw_string(_font, Vector2(bottom.position.x + 4.0, bottom.end.y + 15.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UITheme.HEADING)
	elif show_abilities:
		var abilities := _player.abilities
		var others := abilities.other_slots()
		var tab: Rect2 = _groups[0][1]
		var casting := false
		var set_text := "%s  %s" % [_set_name(abilities), _key("ability_swap")]
		var text_width := _font.get_string_size(set_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_string(_font, tab.position + Vector2(tab.size.x - text_width - 4.0 - 4 * 14.0, 13), set_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UITheme.DIM)
		for index in (0 if casting else AbilityDB.SET_SIZE):
			var other_id: String = others[index] if index < others.size() else ""
			var mini_rect := Rect2(tab.end.x - 4.0 * 14.0 - 2.0 + index * 14.0, tab.position.y + 2.0, 12.0, 12.0)
			draw_rect(mini_rect, Color(0.05, 0.05, 0.08))
			if other_id != "":
				draw_texture_rect(AbilityDB.icon(other_id), mini_rect, false, Color(0.7, 0.7, 0.75))
	for index in _spots.size():
		var spot: Array = _spots[index]
		var rect: Rect2 = spot[0]
		var hovered := index == _hover
		match spot[1]:
			"ability":
				_draw_ability(rect, spot[2], hovered)
			"quick":
				var quick := _player.hotbar.quick_item()
				var quick_id := _player.hotbar.quick_id
				_slot(rect, quick if quick else (Item.create(quick_id) if quick_id != "" else null), 44, quick == null, false, hovered, 0.0)
				if quick_id != "":
					_count(rect, _player.inventory.count_of(quick_id))
				_key_badge(rect, _key("quick_use"))
			"hotbar":
				var hotbar := _player.hotbar
				if spot[2] < 2:
					_hand_slot(rect, hotbar.hand_icon(spot[2]), Hotbar.GHOST_ICONS[spot[2]], hotbar.is_active(spot[2]), hovered, _press_flash[spot[2]])
					_key_badge(rect, _key("hotbar_%d" % (spot[2] + 1)))
					continue
				var item := hotbar.item_in(spot[2])
				var id := hotbar.id_in(spot[2])
				var shown: Item = item if item else (Item.create(id) if id != "" else null)
				_slot(rect, shown, Hotbar.GHOST_ICONS[spot[2]], item == null, hotbar.is_active(spot[2]), hovered, _press_flash[spot[2]])
				if id != "":
					_count(rect, hotbar.count_in(spot[2]))
				_key_badge(rect, _key("hotbar_%d" % (spot[2] + 1)))
			"off":
				var off := _player.equipment.get_item("off_hand")
				var weapon := _player.equipment.weapon()
				_mini(rect, off, 5, weapon != null and weapon.definition().get("two_handed", false), hovered)
			"armour":
				_mini(rect, _player.equipment.get_item(ARMOUR[spot[2]]), ARMOUR_ICONS[ARMOUR[spot[2]]], false, hovered)


func _draw_ability(rect: Rect2, index: int, hovered: bool) -> void:
	var id := _ability_id(index)
	draw_style_box(_slot_styles["slot_hover" if hovered else "slot"], rect.grow(3.0))
	if id == "":
		_key_badge(rect, _key("ability_%d" % (index + 1)))
		return
	var ability: Dictionary = AbilityDB.ABILITIES[id]
	var reason := _player.abilities.blocked_reason(id)
	var icon := AbilityDB.icon(id)
	var t := Time.get_ticks_msec() / 1000.0
	var border := Color(0.95, 0.82, 0.48)
	match reason:
		"":
			draw_texture_rect(icon, rect.grow(-7.0), false)
			# Ready: a soft gold edge that breathes, and a flash when it comes back.
			draw_rect(rect.grow(1.0 + 2.0 * _ready_flash[index]), Color(1.0, 0.85, 0.45, 0.25 + 0.6 * _ready_flash[index]), false, 2.0)
		"cooldown":
			draw_texture_rect(icon, rect.grow(-7.0), false, Color(0.55, 0.55, 0.6))
			var left: float = _player.abilities.cooldowns[id]
			var share := clampf(left / float(ability["cooldown"]), 0.0, 1.0)
			# A clock hand sweeping the shadow away.
			var center := rect.get_center()
			var wedge := PackedVector2Array([center])
			var steps := 24
			for step in steps + 1:
				var angle := -PI / 2.0 + TAU * (1.0 - share) + TAU * share * step / steps
				var direction := Vector2.from_angle(angle)
				# Out to the square's edge.
				var reach := minf(rect.size.x / 2.0 / maxf(absf(direction.x), 0.001), rect.size.y / 2.0 / maxf(absf(direction.y), 0.001))
				wedge.append(center + direction * reach)
			draw_colored_polygon(wedge, Color(0.0, 0.0, 0.02, 0.62))
			var seconds := "%.1f" % left if left < 10.0 else "%d" % ceili(left)
			draw_string_outline(UITheme.bold(), rect.position + Vector2(0, 34), seconds, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 17, 4, Color.BLACK)
			draw_string(UITheme.bold(), rect.position + Vector2(0, 34), seconds, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 17, Color.WHITE)
			border = Color(0.4, 0.37, 0.32)
		"mana", "stamina":
			# Short of what it costs: tinted that colour, with the shortfall shown.
			var color := Color(0.35, 0.55, 1.0) if reason == "mana" else Color(0.95, 0.78, 0.25)
			draw_texture_rect(icon, rect.grow(-7.0), false, Color(0.5, 0.5, 0.55))
			draw_rect(rect, Color(color, 0.18))
			var pool: ResourcePool = _player.mana if reason == "mana" else _player.stamina
			var cost := _player.abilities.mana_cost(id) if reason == "mana" else _player.abilities.stamina_cost(id)
			var have := clampf(pool.current / maxf(cost, 1.0), 0.0, 1.0)
			draw_rect(Rect2(rect.position.x + 3.0, rect.end.y - 7.0, rect.size.x - 6.0, 4.0), Color(0, 0, 0, 0.7))
			draw_rect(Rect2(rect.position.x + 3.0, rect.end.y - 7.0, (rect.size.x - 6.0) * have, 4.0), color)
			border = color.lerp(Color.WHITE, 0.15 + 0.15 * sin(t * 5.0))
		_:
			# Locked, or the wrong weapon in hand.
			# The icon stays readable, greyed, with a small padlock in the corner.
			draw_texture_rect(icon, rect.grow(-7.0), false, Color(0.5, 0.5, 0.56))
			draw_rect(rect, Color(0.0, 0.0, 0.0, 0.22))
			var lock := rect.end + Vector2(-11, -rect.size.y + 15)
			draw_rect(Rect2(lock + Vector2(-7, -9), Vector2(14, 17)), Color(0.05, 0.05, 0.08, 0.85))
			draw_arc(lock + Vector2(0, -3), 3.5, PI, TAU, 8, Color(0.85, 0.78, 0.6), 2.0)
			draw_rect(Rect2(lock + Vector2(-5, -3), Vector2(10, 8)), Color(0.85, 0.78, 0.6))
			draw_rect(Rect2(lock + Vector2(-1, -1), Vector2(2, 3)), Color(0.15, 0.12, 0.08))
			# What it waits for, in a word or a number (the tooltip says the rest).
			var note := str(ability["mastery"]) if reason == "locked" and ability.has("mastery") else str(ability.get("level", "")) if reason == "locked" else "weapon"
			draw_string_outline(_font, Vector2(rect.position.x, rect.end.y - 5.0), note, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 14, 3, Color.BLACK)
			draw_string(_font, Vector2(rect.position.x, rect.end.y - 5.0), note, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 14, Color(0.9, 0.82, 0.6))
			border = Color(0.3, 0.28, 0.26)
	if hovered:
		draw_rect(rect, Color(1, 1, 1, 0.08))
	draw_rect(rect, border, false, 2.0)
	_key_badge(rect, _key("ability_%d" % (index + 1)))


func _slot(rect: Rect2, item: Item, ghost: int, missing: bool, active: bool, hovered: bool, flash: float) -> void:
	var lift := Vector2(0, -3) if active else Vector2.ZERO
	rect.position += lift
	var frame: StyleBoxTexture = _slot_styles["slot_active" if active else "slot_hover" if hovered else "slot"]
	frame.modulate_color = Color.WHITE.lerp(item.color().lightened(0.15), 0.5) if item and not missing and not active else Color.WHITE
	draw_style_box(frame, rect.grow(3.0))
	if item:
		draw_texture_rect(item.icon(), rect.grow(-6.0), false, item.icon_tint() if not missing else Color(0.45, 0.45, 0.5, 0.8))
	else:
		draw_texture_rect(ItemDB.icon(ghost), rect.grow(-10.0), false, Color(1, 1, 1, 0.2))
	if hovered:
		draw_rect(rect, Color(1, 1, 1, 0.1))
	if flash > 0.0:
		draw_rect(rect, Color(1, 1, 1, 0.35 * flash))
	if active:
		# In hand: a bright double edge, raised, with a marker above.
		draw_rect(rect.grow(3.0), Color(1.0, 0.85, 0.45, 0.4 + 0.25 * sin(Time.get_ticks_msec() / 200.0)), false, 2.0)
		draw_rect(rect, Color("ffe08a"), false, 3.0)
		var top := Vector2(rect.get_center().x, rect.position.y - 3.0)
		draw_colored_polygon(PackedVector2Array([top + Vector2(-6, -6), top + Vector2(6, -6), top]), Color("ffe08a"))


## The style and magic slots: a picture rather than an item.
func _hand_slot(rect: Rect2, picture: Texture2D, ghost: int, active: bool, hovered: bool, flash: float) -> void:
	if active:
		rect.position += Vector2(0, -3)
	var frame: StyleBoxTexture = _slot_styles["slot_active" if active else "slot_hover" if hovered else "slot"]
	frame.modulate_color = Color.WHITE
	draw_style_box(frame, rect.grow(3.0))
	if picture:
		draw_texture_rect(picture, rect.grow(-5.0), false)
	else:
		draw_texture_rect(ItemDB.icon(ghost), rect.grow(-10.0), false, Color(1, 1, 1, 0.2))
	if hovered:
		draw_rect(rect, Color(1, 1, 1, 0.1))
	if flash > 0.0:
		draw_rect(rect, Color(1, 1, 1, 0.35 * flash))
	if active:
		draw_rect(rect.grow(3.0), Color(1.0, 0.85, 0.45, 0.4 + 0.25 * sin(Time.get_ticks_msec() / 200.0)), false, 2.0)
		draw_rect(rect, Color("ffe08a"), false, 3.0)
		var top := Vector2(rect.get_center().x, rect.position.y - 3.0)
		draw_colored_polygon(PackedVector2Array([top + Vector2(-6, -6), top + Vector2(6, -6), top]), Color("ffe08a"))


func _mini(rect: Rect2, item: Item, ghost: int, dimmed: bool, hovered: bool) -> void:
	draw_style_box(_slot_styles["slot_hover" if hovered else "slot"], rect.grow(2.0))
	if item:
		draw_texture_rect(item.icon(), rect.grow(-2.0), false, Color(item.icon_tint(), 0.45 if dimmed else 1.0))
	else:
		draw_texture_rect(ItemDB.icon(ghost), rect.grow(-4.0), false, Color(1, 1, 1, 0.18))
	if hovered:
		draw_rect(rect, Color(1, 1, 1, 0.08))


func _count(rect: Rect2, count: int) -> void:
	var text := str(count)
	draw_string_outline(_font, rect.position + Vector2(0, rect.size.y - 3.0), text, HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 3.0, 14, 4, Color.BLACK)
	draw_string(_font, rect.position + Vector2(0, rect.size.y - 3.0), text, HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 3.0, 14, Color.WHITE if count > 0 else UITheme.BAD)


## The key on a small dark tab at the slot's top left corner.
func _key_badge(rect: Rect2, key: String) -> void:
	var width := maxf(_font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 6.0, 14.0)
	var badge := Rect2(rect.position + Vector2(-2, -2), Vector2(width, 15))
	draw_rect(badge, Color(0.04, 0.045, 0.07, 0.95))
	draw_rect(badge, Color("8a683a"), false, 1.0)
	draw_string(_font, badge.position + Vector2(3, 12), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UITheme.HEADING)
