extends CanvasLayer
## On-screen player status: health, experience, stamina, level, and messages.

var _player: Player
var _banner_tween: Tween

@onready var _health_bar: Control = $HealthBar
@onready var _xp_bar: Control = $XPBar
@onready var _stamina_bar: Control = $StaminaBar
@onready var _mana_bar: Control = $ManaBar
@onready var _level_label: Label = $LevelLabel
@onready var _points_label: Label = $PointsLabel
@onready var _banner: Label = $LevelUpBanner
@onready var _banner_detail: Label = $LevelUpBanner/Detail
@onready var _death_message: Label = $DeathMessage
@onready var _death_summary: Label = $DeathMessage/Summary
@onready var _buff_label: Label = $BuffLabel
@onready var _gather: Control = $Gather
@onready var _boss_bar: Control = $BossBar


func setup(player: Player) -> void:
	_player = player
	UITheme.apply(self)
	_bind(_health_bar, Color(0.72, 0.13, 0.17), 35, func() -> float:
		return player.health.current / player.health.max_health, func() -> String:
		return "%d / %d" % [ceili(player.health.current), ceili(player.health.max_health)])
	_bind(_xp_bar, Color(0.95, 0.76, 0.3), -1, func() -> float:
		return float(player.leveling.xp) / player.leveling.xp_to_next())
	_bind(_stamina_bar, Color(0.85, 0.7, 0.25), 37, func() -> float:
		return player.stamina.current / player.stamina.max_value, func() -> String:
		return "%d / %d" % [roundi(player.stamina.current), roundi(player.stamina.max_value)])
	_bind(_mana_bar, Color(0.25, 0.5, 0.95), 36, func() -> float:
		return player.mana.current / player.mana.max_value, func() -> String:
		return "%d / %d" % [roundi(player.mana.current), roundi(player.mana.max_value)])
	$Minimap.setup(player, player.get_parent().get_node("World"))
	player.health.changed.connect(func(_c: float, _m: float) -> void: _health_bar.queue_redraw())
	player.stamina.changed.connect(func(_c: float, _m: float) -> void: _stamina_bar.queue_redraw())
	player.mana.changed.connect(func(_c: float, _m: float) -> void: _mana_bar.queue_redraw())
	player.leveling.xp_changed.connect(func(_x: int, _r: int) -> void: _refresh())
	player.attributes.changed.connect(_refresh)
	player.talents.changed.connect(_refresh)
	player.class_changed.connect(_refresh)
	Events.level_up.connect(_on_level_up)
	Events.profession_level_up.connect(func(id: String, level: int) -> void:
		DamageNumber.spawn_text(player.get_parent(), player.global_position + Vector2(0, -52), "%s %d" % [Professions.NAMES[id], level], UITheme.GOLD, 15)
		Audio.play("level_up", -10.0, 0.0)
	)
	_gather.draw.connect(_draw_gather)
	$QuestTracker.setup(player)
	Events.quest_completed.connect(func(title: String, rewards: String) -> void:
		_show_banner("QUEST COMPLETE", "%s  -  %s" % [title, rewards])
		Audio.play("level_up", -6.0, 0.0)
	)
	Events.announcement.connect(_show_banner)
	_boss_bar.draw.connect(_draw_boss_bar)
	Events.biome_discovered.connect(func(biome: String, xp: int) -> void:
		DamageNumber.spawn_text(player.get_parent(), player.global_position + Vector2(0, -60), "Discovered: %s  (+%d XP)" % [biome, xp], UITheme.INFO, 14)
	)
	$AbilityBar.setup(player)
	var hotbar_ui := HotbarUI.new()
	hotbar_ui.setup(player)
	hotbar_ui.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hotbar_ui.size = hotbar_ui.custom_minimum_size
	hotbar_ui.position = Vector2(-hotbar_ui.size.x / 2.0, -hotbar_ui.size.y - 6.0)
	add_child(hotbar_ui)
	var meter := TransformMeter.new()
	meter.setup(player)
	meter.position = Vector2(14.0, 152.0)
	add_child(meter)
	# Buffs list to the right of the left-hand blocks, clear of them.
	_buff_label.position = Vector2(158.0, 138.0)
	var menu_button := HudMenuButton.new()
	menu_button.setup(player)
	menu_button.position = Vector2(14.0, 110.0)
	add_child(menu_button)
	_death_message.visible = false
	_banner.visible = false
	_refresh()


## Words for the death screen, by what struck the last blow.
const DEATH_LINES := {
	"blow": ["You have fallen", "Struck down", "The Hall claims another", "Your strength fails you", "Darkness closes in", "Beaten, not broken", "The rot takes you", "Your tale pauses here"],
	"fire": ["Burned to cinders", "The flames take you", "Ash to ash"],
	"burn": ["Burned to cinders", "The flames take you", "Ash to ash"],
	"frost": ["Frozen where you stand", "The cold claims you", "Winter keeps you"],
	"poison": ["The venom wins", "Poison stills your heart", "Rot runs in your veins"],
	"bleed": ["Bled dry", "Your wounds would not close", "The last drop falls"],
	"shadow": ["Swallowed by shadow", "The dark drinks you in", "Your light gutters out"],
	"holy": ["Judged and found wanting", "Burned by the light"],
	"storm": ["Struck from the sky", "The storm takes its due", "Thunder has the last word"],
}


func show_death(xp_lost: int, respawn_name: String) -> void:
	var lines: Array = DEATH_LINES.get(_player.last_harm, DEATH_LINES["blow"])
	if DayNight.blood_moon and randf() < 0.5:
		lines = ["The blood moon feeds", "Red night, red end"]
	_death_message.text = lines.pick_random()
	_death_summary.text = "Lost %d XP  -  waking at %s" % [xp_lost, respawn_name]
	_death_message.visible = true


## Death on a Hardcore world: there is no waking.
func show_hardcore_death(day: int) -> void:
	_death_message.text = "Your tale ends here"
	_death_summary.text = "Hardcore  -  level %d, day %d. This world is lost with you." % [_player.leveling.level, day]
	_death_message.visible = true


func hide_death() -> void:
	_death_message.visible = false


func _refresh() -> void:
	_level_label.text = "Lv %d" % _player.leveling.level
	var codex: Node = _player.get_parent().get_node_or_null("Codex")
	if codex and codex.title != "":
		_level_label.text += "   " + codex.title
	# What waits in the menu is said beside the Menu button, which wears the count.
	var notes: PackedStringArray = []
	if _player.attributes.unspent > 0:
		notes.append("%d attribute points" % _player.attributes.unspent)
	if _player.leveling.talent_points > 0:
		notes.append("%d talent points" % _player.leveling.talent_points)
	if _player.class_id == "adventurer" and _player.leveling.level >= HeroClasses.CHOICE_LEVEL:
		notes.append("a class to choose")
	_points_label.visible = not notes.is_empty()
	_points_label.text = "to spend: " + ", ".join(notes)
	_points_label.position = Vector2(158.0, 114.0)
	_xp_bar.queue_redraw()


func _on_level_up(level: int) -> void:
	var detail := "Level %d" % level
	if level % Leveling.MILESTONE_INTERVAL == 0:
		detail += "  -  milestone reached"
	Audio.play("level_up", -4.0, 0.0)
	_show_banner("LEVEL UP!", detail)


## Pops the big banner in the middle of the screen, then fades it.
func _show_banner(title: String, detail: String) -> void:
	_banner.text = title
	_banner_detail.text = detail
	if _banner_tween:
		_banner_tween.kill()
	_banner.visible = true
	_banner.modulate.a = 1.0
	_banner.pivot_offset = _banner.size / 2.0
	_banner.scale = Vector2(0.4, 0.4)
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_interval(1.2)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.6)
	_banner_tween.tween_callback(_banner.hide)


func _process(_delta: float) -> void:
	# Running buffs with their time left, under the bars.
	var lines: PackedStringArray = []
	for id: String in _player.buffs.active:
		lines.append("%s  %ds" % [_player.buffs.active[id]["name"], ceili(_player.buffs.active[id]["time"])])
	_buff_label.text = "\n".join(lines)
	_gather.queue_redraw()
	_boss_bar.queue_redraw()
	_health_bar.queue_redraw()
	_stamina_bar.queue_redraw()
	_mana_bar.queue_redraw()


## The prompt for a gatherable node in reach, and the bar while gathering.
func _draw_gather() -> void:
	var font := UITheme.get_theme().default_font
	var width := _gather.size.x
	if _player.state == Player.State.GATHER and _player.gather_seconds > 0.0:
		var share := clampf(_player.gather_progress / _player.gather_seconds, 0.0, 1.0)
		_gather.draw_rect(Rect2(0, 22, width, 12), Color(0.04, 0.05, 0.08, 0.9))
		_gather.draw_rect(Rect2(2, 24, (width - 4.0) * share, 8), UITheme.GOLD)
		_gather.draw_rect(Rect2(0, 22, width, 12), Color("8a683a"), false, 1.0)
		return
	if _player.state != Player.State.MOVE:
		return
	var use_key := "[Right click]"
	var npc := _player.nearest_npc()
	if npc:
		var talk := "%s  %s" % [use_key, npc.prompt()]
		_gather.draw_string_outline(font, Vector2(0, 16), talk, HORIZONTAL_ALIGNMENT_CENTER, width, 16, 4, Color.BLACK)
		_gather.draw_string(font, Vector2(0, 16), talk, HORIZONTAL_ALIGNMENT_CENTER, width, 16, UITheme.GOLD)
		return
	var prop := _player.nearest_prop()
	if prop:
		var action := "%s  %s" % [use_key, prop.prompt_text] if prop.on_interact.is_valid() else prop.prompt_text
		_gather.draw_string_outline(font, Vector2(0, 16), action, HORIZONTAL_ALIGNMENT_CENTER, width, 16, 4, Color.BLACK)
		_gather.draw_string(font, Vector2(0, 16), action, HORIZONTAL_ALIGNMENT_CENTER, width, 16, UITheme.GOLD if prop.on_interact.is_valid() else UITheme.DIM)
		return
	# What a left click would work on: the thing under the mouse first.
	var text := ""
	var good := true
	var node: ResourceNode = _player.hover_node if is_instance_valid(_player.hover_node) else _player.nearest_resource()
	if node:
		var reason := node.blocked_reason(_player)
		good = reason == ""
		var pointed := node == _player.hover_node
		text = ("[Left click]  %s" if pointed else "Point and click:  %s") % node.prompt() if good else "%s  -  %s" % [GatherDB.display_name(node.resource_id), reason]
	elif not _player.hover_record.is_empty():
		text = "[Left click]  Take down the %s" % str(ItemDB.ITEMS[Buildings.KINDS[_player.hover_record["kind"]]["item"]]["name"]).to_lower()
	if text == "":
		return
	_gather.draw_string_outline(font, Vector2(0, 16), text, HORIZONTAL_ALIGNMENT_CENTER, width, 16, 4, Color.BLACK)
	_gather.draw_string(font, Vector2(0, 16), text, HORIZONTAL_ALIGNMENT_CENTER, width, 16, UITheme.TEXT if good else UITheme.BAD)


## Draws `bar` as an ornate gauge: a dark trough, the fill with a sheen and
## a slow "chip" trail showing what was just lost, bronze frame with corner
## studs, the icon in a little medallion and the numbers on top.
func _bind(bar: Control, fill: Color, icon: int, fraction: Callable, values: Callable = Callable()) -> void:
	var trail := {"value": 1.0}
	bar.draw.connect(func() -> void:
		var size := bar.size
		var share := clampf(fraction.call(), 0.0, 1.0)
		trail["value"] = maxf(share, move_toward(trail["value"], share, get_process_delta_time() * 0.6))
		var inner := Rect2(Vector2(3, 3), size - Vector2(6, 6))
		bar.draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.04, 0.92))
		bar.draw_rect(inner, fill.darkened(0.82))
		bar.draw_rect(Rect2(inner.position, Vector2(inner.size.x * trail["value"], inner.size.y)), Color(1.0, 0.92, 0.8, 0.55))
		var filled := Rect2(inner.position, Vector2(inner.size.x * share, inner.size.y))
		bar.draw_rect(filled, fill)
		bar.draw_rect(Rect2(filled.position, Vector2(filled.size.x, filled.size.y * 0.35)), fill.lightened(0.3))
		bar.draw_rect(Rect2(filled.position + Vector2(0, filled.size.y * 0.75), Vector2(filled.size.x, filled.size.y * 0.25)), fill.darkened(0.3))
		# A light glint sweeping along the fill.
		var sweep := fmod(Time.get_ticks_msec() / 1400.0, 1.6) - 0.3
		if share > 0.02 and sweep > 0.0 and sweep < 1.0:
			var x := inner.position.x + inner.size.x * share * sweep
			bar.draw_rect(Rect2(x, inner.position.y, 4.0, inner.size.y), Color(1, 1, 1, 0.22))
		# Tick marks every tenth.
		for tick in range(1, 10):
			var tx := inner.position.x + inner.size.x * tick / 10.0
			bar.draw_line(Vector2(tx, inner.end.y - 3.0), Vector2(tx, inner.end.y), Color(0, 0, 0, 0.45), 1.0)
		bar.draw_rect(Rect2(Vector2.ZERO, size), Color("402f1c"), false, 2.0)
		bar.draw_rect(Rect2(Vector2(1.5, 1.5), size - Vector2(3, 3)), Color("b08a4a"), false, 1.0)
		for corner: Vector2 in [Vector2(0, 0), Vector2(size.x, 0), Vector2(0, size.y), Vector2(size.x, size.y)]:
			bar.draw_circle(corner, 3.0, Color("402f1c"))
			bar.draw_circle(corner, 2.0, Color("d9b26a"))
		if icon >= 0:
			var medal := Vector2(-16.0, size.y / 2.0)
			var radius := maxf(size.y / 2.0 + 3.0, 11.0)
			bar.draw_circle(medal, radius + 2.0, Color("402f1c"))
			bar.draw_circle(medal, radius, Color(0.07, 0.08, 0.13))
			bar.draw_arc(medal, radius, 0.0, TAU, 24, Color("b08a4a"), 1.5)
			bar.draw_texture_rect(ItemDB.icon(icon), Rect2(medal - Vector2(radius - 3.0, radius - 3.0), Vector2(radius - 3.0, radius - 3.0) * 2.0), false)
		if values.is_valid() and size.y >= 14.0:
			var font := UITheme.get_theme().default_font
			var text: String = values.call()
			var font_size := int(clampf(size.y - 6.0, 10.0, 15.0))
			var y := size.y / 2.0 + font_size * 0.36
			bar.draw_string_outline(font, Vector2(0, y), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, 3, Color.BLACK)
			bar.draw_string(font, Vector2(0, y), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, Color(1, 0.97, 0.9))
	)


## The boss bar: the boss's face in a framed medallion, its name and title
## on a banner, an ornate bar with a chip trail, and its modifiers below.
var _boss_trail := 1.0
var _boss_seen: Enemy = null
var _portraits: Dictionary = {}


func _draw_boss_bar() -> void:
	var boss: Enemy = null
	for node in get_tree().get_nodes_in_group("bosses"):
		if node.global_position.distance_to(_player.global_position) < 700.0 and not node.health.is_dead():
			boss = node
			break
	if boss == null:
		_boss_seen = null
		return
	if boss != _boss_seen:
		_boss_seen = boss
		_boss_trail = 1.0
	var font := UITheme.bold()
	var size := _boss_bar.size
	var share := clampf(boss.health.current / boss.health.max_health, 0.0, 1.0)
	_boss_trail = maxf(share, move_toward(_boss_trail, share, get_process_delta_time() * 0.35))
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 260.0)
	var bar := Rect2(54, 28, size.x - 62.0, 18)
	# Banner behind the name.
	var banner := Rect2(bar.position.x + 40.0, 2, bar.size.x - 80.0, 24)
	_boss_bar.draw_rect(banner, Color(0.12, 0.03, 0.04, 0.85))
	_boss_bar.draw_rect(banner, Color("8a683a"), false, 1.0)
	var title := "%s%s   Lv %d" % [Enemy.RANK_DATA[boss.rank]["title"], boss.display_name, boss.level]
	_boss_bar.draw_string_outline(font, Vector2(banner.position.x, 20), title, HORIZONTAL_ALIGNMENT_CENTER, banner.size.x, 19, 5, Color.BLACK)
	_boss_bar.draw_string(font, Vector2(banner.position.x, 20), title, HORIZONTAL_ALIGNMENT_CENTER, banner.size.x, 19, Color(1.0, 0.6, 0.48))
	# The bar.
	_boss_bar.draw_rect(bar.grow(3.0), Color(0.02, 0.02, 0.04, 0.95))
	_boss_bar.draw_rect(bar, Color(0.18, 0.03, 0.04))
	_boss_bar.draw_rect(Rect2(bar.position, Vector2(bar.size.x * _boss_trail, bar.size.y)), Color(1.0, 0.85, 0.6, 0.6))
	var fill := Color(0.78, 0.1, 0.12).lerp(Color(0.95, 0.25, 0.15), pulse * (1.0 - share))
	_boss_bar.draw_rect(Rect2(bar.position, Vector2(bar.size.x * share, bar.size.y)), fill)
	_boss_bar.draw_rect(Rect2(bar.position, Vector2(bar.size.x * share, bar.size.y * 0.35)), fill.lightened(0.3))
	if boss.shield > 0.0:
		_boss_bar.draw_rect(Rect2(bar.position + Vector2(0, bar.size.y - 5.0), Vector2(bar.size.x * boss.shield / boss.shield_max, 5.0)), Color(0.55, 0.8, 1.0))
	for quarter in [0.25, 0.5, 0.75]:
		var x: float = bar.position.x + bar.size.x * quarter
		_boss_bar.draw_line(Vector2(x, bar.position.y), Vector2(x, bar.end.y), Color(0, 0, 0, 0.6), 2.0)
	_boss_bar.draw_rect(bar.grow(3.0), Color("402f1c"), false, 3.0)
	_boss_bar.draw_rect(bar.grow(1.0), Color("d9b26a"), false, 1.0)
	# Spikes on the right end.
	var tip := Vector2(bar.end.x + 3.0, bar.get_center().y)
	_boss_bar.draw_colored_polygon(PackedVector2Array([tip + Vector2(0, -9), tip + Vector2(14, 0), tip + Vector2(0, 9)]), Color("402f1c"))
	_boss_bar.draw_colored_polygon(PackedVector2Array([tip + Vector2(0, -5), tip + Vector2(9, 0), tip + Vector2(0, 5)]), Color("d9b26a"))
	var numbers := "%d / %d" % [ceili(boss.health.current), ceili(boss.health.max_health)]
	_boss_bar.draw_string_outline(UITheme.get_theme().default_font, Vector2(bar.position.x, bar.position.y + 14), numbers, HORIZONTAL_ALIGNMENT_CENTER, bar.size.x, 13, 3, Color.BLACK)
	_boss_bar.draw_string(UITheme.get_theme().default_font, Vector2(bar.position.x, bar.position.y + 14), numbers, HORIZONTAL_ALIGNMENT_CENTER, bar.size.x, 13, Color.WHITE)
	# The face, in a medallion overlapping the bar's left end.
	var center := Vector2(30, 34)
	_boss_bar.draw_circle(center, 31.0, Color("402f1c"))
	_boss_bar.draw_circle(center, 28.0, Color(0.1, 0.04, 0.06))
	_boss_bar.draw_circle(center, 28.0, Color(0.9, 0.2, 0.15, 0.15 + 0.2 * pulse))
	var face := _portrait(boss.enemy_id)
	if face:
		_boss_bar.draw_texture_rect(face, Rect2(center - Vector2(25, 25), Vector2(50, 50)), false)
	_boss_bar.draw_arc(center, 28.0, 0.0, TAU, 40, Color("d9b26a"), 2.0)
	_boss_bar.draw_arc(center, 31.0, 0.0, TAU, 40, Color("8a683a"), 1.0)
	# Modifiers in their colours under the bar.
	var names: PackedStringArray = []
	for id in boss.modifiers:
		names.append(Enemy.MODIFIERS[id]["name"])
	if not names.is_empty():
		var text := "  -  ".join(names)
		_boss_bar.draw_string_outline(UITheme.get_theme().default_font, Vector2(bar.position.x, bar.end.y + 18), text, HORIZONTAL_ALIGNMENT_CENTER, bar.size.x, 13, 3, Color.BLACK)
		_boss_bar.draw_string(UITheme.get_theme().default_font, Vector2(bar.position.x, bar.end.y + 18), text, HORIZONTAL_ALIGNMENT_CENTER, bar.size.x, 13, Color(0.95, 0.8, 0.6))


## The upper part of the first idle frame of an enemy's sheet.
func _portrait(id: String) -> Texture2D:
	if _portraits.has(id):
		return _portraits[id]
	var sheet := EnemyDB.sheet(id)
	var face: Texture2D = null
	if sheet:
		# Find the creature inside the first frame and frame its upper part.
		var frame := Rect2i(0, 0, 96, 96)
		var image := sheet.get_image()
		if image:
			var used := image.get_region(frame).get_used_rect()
			var side := maxi(mini(used.size.x, used.size.y), 16)
			side = mini(side, maxi(used.size.x, 16))
			frame = Rect2i(used.position.x + (used.size.x - side) / 2, used.position.y, side, side)
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(frame)
		face = atlas
	_portraits[id] = face
	return face
