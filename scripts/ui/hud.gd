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
		return player.health.current / player.health.max_health)
	_bind(_xp_bar, Color(0.95, 0.76, 0.3), -1, func() -> float:
		return float(player.leveling.xp) / player.leveling.xp_to_next())
	_bind(_stamina_bar, Color(0.85, 0.7, 0.25), 37, func() -> float:
		return player.stamina.current / player.stamina.max_value)
	_bind(_mana_bar, Color(0.25, 0.5, 0.95), 36, func() -> float:
		return player.mana.current / player.mana.max_value)
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
	_death_message.visible = false
	_banner.visible = false
	_refresh()


func show_death(xp_lost: int, respawn_name: String) -> void:
	_death_summary.text = "Lost %d XP  -  waking at %s" % [xp_lost, respawn_name]
	_death_message.visible = true


func hide_death() -> void:
	_death_message.visible = false


func _refresh() -> void:
	_level_label.text = "Lv %d" % _player.leveling.level
	var notes: PackedStringArray = []
	if _player.attributes.unspent > 0:
		notes.append("%d attribute points - press C" % _player.attributes.unspent)
	if _player.leveling.talent_points > 0:
		notes.append("%d talent points - press K" % _player.leveling.talent_points)
	if _player.class_id == "adventurer" and _player.leveling.level >= HeroClasses.CHOICE_LEVEL:
		notes.append("Choose a class - press M")
	_points_label.visible = not notes.is_empty()
	_points_label.text = "      ".join(notes)
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
	var npc := _player.nearest_npc()
	if npc:
		var talk := "[F]  %s" % npc.prompt()
		_gather.draw_string_outline(font, Vector2(0, 16), talk, HORIZONTAL_ALIGNMENT_CENTER, width, 16, 4, Color.BLACK)
		_gather.draw_string(font, Vector2(0, 16), talk, HORIZONTAL_ALIGNMENT_CENTER, width, 16, UITheme.GOLD)
		return
	var prop := _player.nearest_prop()
	if prop:
		var action := "[F]  %s" % prop.prompt_text if prop.on_interact.is_valid() else prop.prompt_text
		_gather.draw_string_outline(font, Vector2(0, 16), action, HORIZONTAL_ALIGNMENT_CENTER, width, 16, 4, Color.BLACK)
		_gather.draw_string(font, Vector2(0, 16), action, HORIZONTAL_ALIGNMENT_CENTER, width, 16, UITheme.GOLD if prop.on_interact.is_valid() else UITheme.DIM)
		return
	var node := _player.nearest_resource()
	if node == null:
		return
	var reason := node.blocked_reason(_player)
	var text := "[F]  %s" % node.prompt() if reason == "" else "%s  -  %s" % [GatherDB.display_name(node.resource_id), reason]
	_gather.draw_string_outline(font, Vector2(0, 16), text, HORIZONTAL_ALIGNMENT_CENTER, width, 16, 4, Color.BLACK)
	_gather.draw_string(font, Vector2(0, 16), text, HORIZONTAL_ALIGNMENT_CENTER, width, 16, UITheme.TEXT if reason == "" else UITheme.BAD)


## Draws `bar` as a framed gauge with an optional icon to its left.
func _bind(bar: Control, fill: Color, icon: int, fraction: Callable) -> void:
	bar.draw.connect(func() -> void:
		var size := bar.size
		if icon >= 0:
			bar.draw_texture_rect(ItemDB.icon(icon), Rect2(-26.0, size.y / 2.0 - 11.0, 22.0, 22.0), false)
		bar.draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.05, 0.08, 0.9))
		var width: float = (size.x - 4.0) * clampf(fraction.call(), 0.0, 1.0)
		bar.draw_rect(Rect2(Vector2(2, 2), Vector2(width, size.y - 4.0)), fill)
		bar.draw_rect(Rect2(Vector2(2, 2), Vector2(width, (size.y - 4.0) * 0.35)), fill.lightened(0.25))
		bar.draw_rect(Rect2(Vector2.ZERO, size), Color("402f1c"), false, 2.0)
		bar.draw_rect(Rect2(Vector2.ONE, size - Vector2(2, 2)), Color("8a683a"), false, 1.0)
	)


## A wide health bar at the top of the screen for a mini-boss close by.
func _draw_boss_bar() -> void:
	var boss: Enemy = null
	for node in get_tree().get_nodes_in_group("bosses"):
		if node.global_position.distance_to(_player.global_position) < 700.0:
			boss = node
			break
	if boss == null:
		return
	var font := UITheme.bold()
	var size := _boss_bar.size
	var title := "%s%s" % [Enemy.RANK_DATA[boss.rank]["title"], boss.display_name]
	_boss_bar.draw_string_outline(font, Vector2(0, 18), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, 5, Color.BLACK)
	_boss_bar.draw_string(font, Vector2(0, 18), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, Color(1.0, 0.55, 0.45))
	var bar := Rect2(0, 26, size.x, 14)
	_boss_bar.draw_rect(bar, Color(0.04, 0.05, 0.08, 0.9))
	_boss_bar.draw_rect(Rect2(2, 28, (size.x - 4.0) * boss.health.current / boss.health.max_health, 10), Color(0.8, 0.2, 0.2))
	_boss_bar.draw_rect(bar, Color("402f1c"), false, 2.0)
	_boss_bar.draw_rect(bar.grow(-1.0), Color("8a683a"), false, 1.0)
