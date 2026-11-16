class_name MasteryMenu
extends GameMenu
## Weapon mastery, one track per weapon. On the left, your weapons grouped
## by kind (the ones you own or have fought with; "Show every weapon" lists
## the rest), each with its picture, level and progress, and a badge on the
## one in hand. On the right, the chosen weapon: its next milestone on a card
## of its own, then its own four moves, its kind's passive, the combo and
## the title in order, with what is not in the game yet tagged as such.

const ROW := Vector2(440.0, 54.0)
const DETAIL_WIDTH := 640.0

var _selected := ""
var _show_all := false
var _list: VBoxContainer
var _all_toggle: CheckBox
var _icon: TextureRect
var _name: Label
var _in_hand: Control
var _level: Label
var _bar: ProgressBar
var _bar_text: Label
var _next_card: PanelContainer
var _next_icon: TextureRect
var _next_title: Label
var _next_text: Label
var _steps: VBoxContainer
var _source: Label


func _build() -> void:
	var title := UITheme.heading("WEAPON MASTERY", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var note := UITheme.label("Each weapon has its own mastery, grown by fighting with it, apart from your character level.", 15, UITheme.DIM)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(note)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	content.add_child(columns)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	columns.add_child(left)
	var list_scroll := ScrollContainer.new()
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_scroll.custom_minimum_size = Vector2(ROW.x + 14.0, 470.0)
	left.add_child(list_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 5)
	list_scroll.add_child(_list)
	_all_toggle = CheckBox.new()
	_all_toggle.text = "Show every weapon"
	_all_toggle.toggled.connect(func(on: bool) -> void:
		_show_all = on
		refresh()
	)
	left.add_child(_all_toggle)

	var right := PanelContainer.new()
	right.add_theme_stylebox_override("panel", UITheme.card("card", 14))
	right.custom_minimum_size = Vector2(DETAIL_WIDTH, 0.0)
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_child(right)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	right.add_child(box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	box.add_child(head)
	_icon = _picture(48.0)
	head.add_child(_icon)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(words)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 10)
	words.add_child(name_row)
	_name = UITheme.heading("", 24)
	name_row.add_child(_name)
	_in_hand = UITheme.badge("In hand", "gold")
	_in_hand.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_row.add_child(_in_hand)
	_level = UITheme.label("", 15, UITheme.TEXT)
	words.add_child(_level)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0.0, 14.0)
	box.add_child(_bar)
	_bar_text = UITheme.label("", 14, UITheme.DIM)
	box.add_child(_bar_text)

	# The next thing worth having, on a card of its own.
	_next_card = PanelContainer.new()
	_next_card.add_theme_stylebox_override("panel", UITheme.card("card_selected", 10))
	box.add_child(_next_card)
	var next_row := HBoxContainer.new()
	next_row.add_theme_constant_override("separation", 10)
	_next_card.add_child(next_row)
	_next_icon = _picture(36.0)
	_next_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	next_row.add_child(_next_icon)
	var next_words := VBoxContainer.new()
	next_words.add_theme_constant_override("separation", 0)
	next_row.add_child(next_words)
	next_words.add_child(UITheme.label("NEXT MILESTONE", 14, UITheme.GOLD))
	_next_title = UITheme.strong("", 17)
	next_words.add_child(_next_title)
	_next_text = UITheme.label("", 14, UITheme.DIM)
	_next_text.custom_minimum_size.x = DETAIL_WIDTH - 90.0
	_next_text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_next_text.clip_text = true
	next_words.add_child(_next_text)

	var progression := HBoxContainer.new()
	progression.add_theme_constant_override("separation", 10)
	box.add_child(progression)
	progression.add_child(UITheme.label("Progression", 16, UITheme.HEADING))
	_source = UITheme.label("", 14, UITheme.DIM)
	_source.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	progression.add_child(_source)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0.0, 180.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	_steps = VBoxContainer.new()
	_steps.add_theme_constant_override("separation", 4)
	_steps.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_steps)

	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	box.add_child(foot)
	var hint := UITheme.label("Abilities gain a rank every %d mastery levels." % AbilityDB.RANK_EVERY, 14, UITheme.DIM)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(hint)
	foot.add_child(UITheme.button("Open Abilities", func() -> void: Events.screen_requested.emit("abilities"), 170.0))

	player.mastery.changed.connect(refresh_if_open)
	# Each opening starts on the weapon in hand.
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree():
			_selected = ""
	)


func refresh() -> void:
	if _selected == "":
		_selected = player.mastery_key()
	_all_toggle.set_pressed_no_signal(_show_all)
	for child in _list.get_children():
		child.queue_free()
	var known := known_weapons()
	for kind: String in WeaponMastery.IDS:
		var keys: Array[String] = []
		for key in WeaponMastery.keys_of_kind(kind):
			if _show_all or key in known:
				keys.append(key)
		if keys.is_empty():
			continue
		var heading := HBoxContainer.new()
		heading.add_theme_constant_override("separation", 8)
		_list.add_child(heading)
		heading.add_child(UITheme.heading(WeaponMastery.NAMES[kind], 16))
		heading.add_child(UITheme.label("best Lv %d" % player.mastery.best_of_kind(kind), 14, UITheme.DIM))
		for key in keys:
			_list.add_child(_row(key, key in known))
	_show(_selected)


## The weapons that count as yours: owned, worn, fought with, plus the bare
## hands and (once you have magic) the magic hand.
func known_weapons() -> Array[String]:
	var keys: Array[String] = ["unarmed"]
	if player.magic_school != "":
		keys.append("magic")
	for key: String in player.mastery.levels:
		if not key in keys:
			keys.append(key)
	var items: Array = player.inventory.items.duplicate()
	items.append_array(player.equipment.equipped.values())
	for item in items:
		if item is Item and item.definition().has("weapon") and not item.definition().has("tool") and not item.id in keys:
			keys.append(item.id)
	if not _selected in keys and _selected != "":
		keys.append(_selected)
	return keys


func _row(id: String, known: bool = true) -> Button:
	var mastery := player.mastery
	var level := mastery.level_of(id)
	var chosen := id == _selected
	var button := Button.new()
	button.custom_minimum_size = ROW
	for state: String in ["normal", "pressed"]:
		button.add_theme_stylebox_override(state, UITheme.card("card_selected" if chosen else "card", 6))
	button.add_theme_stylebox_override("hover", UITheme.card("card_selected" if chosen else "card_hover", 6))
	button.pressed.connect(func() -> void:
		_selected = id
		refresh()
	)
	UITheme.sounds(button)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 7)
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(row)
	var icon := _picture(36.0)
	icon.texture = weapon_icon(id)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 2)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(words)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(top)
	top.add_child(UITheme.strong(WeaponMastery.display_name(id), 16, UITheme.GOLD if chosen else (UITheme.TEXT if known else UITheme.DIM)))
	if id == player.mastery_key():
		top.add_child(UITheme.badge("In hand", "gold"))
	var filler := Control.new()
	filler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(filler)
	top.add_child(UITheme.label("+%.1f%% dmg" % (mastery.damage_bonus(id) * 100.0), 14, UITheme.GOOD))
	var level_label := UITheme.strong("Lv %d" % level, 15, UITheme.TEXT)
	level_label.custom_minimum_size.x = 58.0
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(level_label)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0.0, 8.0)
	bar.max_value = WeaponMastery.xp_required(level) if level < WeaponMastery.MAX_LEVEL else 1.0
	bar.value = mastery.xp_of(id) if level < WeaponMastery.MAX_LEVEL else 1.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(bar)
	for control: Control in top.get_children():
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return button


func _show(id: String) -> void:
	var mastery := player.mastery
	var level := mastery.level_of(id)
	_icon.texture = weapon_icon(id)
	_name.text = WeaponMastery.display_name(id)
	_in_hand.visible = id == player.mastery_key()
	_level.text = "%s  ·  Mastery %d of %d  ·  +%.1f%% damage with it" % [WeaponMastery.NAMES[WeaponMastery.kind_of(id)].trim_suffix("s") if id != "unarmed" else "Unarmed", level, WeaponMastery.MAX_LEVEL, mastery.damage_bonus(id) * 100.0]
	if level >= WeaponMastery.MAX_LEVEL:
		_bar.max_value = 1.0
		_bar.value = 1.0
		_bar_text.text = "Mastered."
	else:
		_bar.max_value = WeaponMastery.xp_required(level)
		_bar.value = mastery.xp_of(id)
		_bar_text.text = "%s / %s mastery XP to level %d  ·  earned mostly from kills with it" % [_whole(mastery.xp_of(id)), _whole(_bar.max_value), level + 1]

	_source.text = "its own four moves" if WeaponMoves.MOVES.has(id) else ("moves of your combat style" if id == "unarmed" else "")
	var steps := milestones(id)
	var next: Dictionary = {}
	for step: Dictionary in steps:
		if level < int(step["level"]) and step["real"]:
			next = step
			break
	_next_card.visible = not next.is_empty()
	if not next.is_empty():
		_next_icon.texture = next["icon"]
		var gap := int(next["level"]) - level
		_next_title.text = "Lv %d   %s     %d level%s to go" % [next["level"], next["title"], gap, "" if gap == 1 else "s"]
		_next_text.text = next["text"]

	for child in _steps.get_children():
		child.queue_free()
	for step: Dictionary in steps:
		_steps.add_child(_step_row(step, level))


## A weapon kind's milestones in order: abilities, passives, the combo and
## the title, plus those not in the game yet (marked "real": false).
func milestones(id: String) -> Array[Dictionary]:
	var level := player.mastery.level_of(id)
	var steps: Array[Dictionary] = []
	var moves: Array[String] = AbilityDB.moves_for(id) if WeaponMoves.MOVES.has(id) else []
	if id == "unarmed" and player.styles:
		moves = AbilityDB.style_moves(player.styles.equipped)
	for ability_id in moves:
		var ability: Dictionary = AbilityDB.ABILITIES[ability_id]
		var rank := AbilityDB.rank(ability_id, level)
		var cost := "%d stamina" % roundi(ability.get("stamina", 0.0)) if ability.has("stamina") else "%d mana" % roundi(ability.get("mana", 0.0)) if ability.has("mana") else "no cost"
		var text := "%s  %ss cooldown, %s." % [ability.get("text", ""), str(ability.get("cooldown", 0)), cost]
		if rank > 0 and ability.get("damage", 0.0) > 0.0:
			text += "  Rank %d (x%.1f damage)." % [rank, AbilityDB.damage(ability_id, rank)]
		steps.append({"level": int(ability.get("mastery", 1)), "title": "Move: %s" % ability["name"], "text": text, "icon": AbilityDB.icon(ability_id), "real": true})
	var kind := WeaponMastery.kind_of(id)
	var passive: Array = WeaponMastery.PASSIVES.get(kind, [])
	if not passive.is_empty():
		for index in WeaponMastery.PASSIVE_LEVELS.size():
			var amount: float = passive[2][index]
			var text := ItemDB.describe_modifier({"stat": passive[0], "kind": passive[1], "value": absf(amount)})
			if amount < 0.0:
				text = "-" + text.substr(1)
			steps.append({"level": WeaponMastery.PASSIVE_LEVELS[index], "title": "Passive: %s" % text, "text": "Always on while this weapon is in hand.", "icon": weapon_icon(id), "real": true})
	steps.append({"level": WeaponMastery.COMBO_LEVEL, "title": "Combo finisher", "text": "Every third attack in a row hits %d%% harder." % roundi((WeaponMastery.COMBO_DAMAGE - 1.0) * 100.0), "icon": weapon_icon(id), "real": true})
	steps.append({"level": 400, "title": "Weapon awakening quest", "text": "Planned for a later update.", "icon": weapon_icon(id), "real": false})
	steps.append({"level": 500, "title": "Ultimate technique", "text": "Planned for a later update.", "icon": weapon_icon(id), "real": false})
	steps.append({"level": WeaponMastery.MAX_LEVEL, "title": "Title: %s Master" % WeaponMastery.display_name(id), "text": "Shown under your name.", "icon": weapon_icon(id), "real": true})
	steps.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["level"]) < int(b["level"]))
	return steps


func _step_row(step: Dictionary, level: int) -> Control:
	var reached: bool = level >= int(step["level"]) and bool(step["real"])
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.tooltip_text = step["text"]
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(StateMark.make("ready" if reached else "locked", 16))
	var lv := UITheme.strong("Lv %d" % step["level"], 14, UITheme.GOLD if reached else UITheme.DIM)
	lv.custom_minimum_size.x = 56.0
	row.add_child(lv)
	var icon := _picture(22.0)
	icon.texture = step["icon"]
	icon.modulate = Color.WHITE if reached else Color(0.5, 0.5, 0.55)
	row.add_child(icon)
	var title := UITheme.label(step["title"], 15, UITheme.TEXT if reached else UITheme.DIM)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.clip_text = true
	row.add_child(title)
	if not step["real"]:
		row.add_child(UITheme.badge("Not in game yet", "plain"))
	elif reached:
		row.add_child(UITheme.badge("Unlocked", "good"))
	return row


## The picture for a weapon (or for a kind: its plainest item); a fist for
## the bare hands and a spell for the magic hand.
static func weapon_icon(id: String) -> Texture2D:
	if id == "unarmed":
		return CombatStyles.icon("fist")
	if id == "magic":
		return AbilityDB.icon("spell_fire_bolt")
	if ItemDB.ITEMS.has(id) and ItemDB.ITEMS[id].has("icon"):
		return ItemDB.icon(int(ItemDB.ITEMS[id]["icon"]))
	for item_id: String in ItemDB.ITEMS:
		var data: Dictionary = ItemDB.ITEMS[item_id]
		if data.has("weapon") and data["weapon"].get("type", "") == id and data.has("icon"):
			return ItemDB.icon(int(data["icon"]))
	return ItemDB.icon(0)


static func _picture(side: float) -> TextureRect:
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(side, side)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


static func _whole(value: float) -> String:
	return InventoryMenu._thousands(roundi(value))
