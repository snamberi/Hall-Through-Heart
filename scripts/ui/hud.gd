extends CanvasLayer
## On-screen player status: health, experience, level, and messages.

var _health_fraction := 1.0
var _xp_fraction := 0.0
var _player: Player
var _banner_tween: Tween

@onready var _health_bar: Control = $HealthBar
@onready var _xp_bar: Control = $XPBar
@onready var _level_label: Label = $LevelLabel
@onready var _points_label: Label = $PointsLabel
@onready var _banner: Label = $LevelUpBanner
@onready var _death_message: Label = $DeathMessage


func setup(player: Player) -> void:
	_player = player
	player.health.changed.connect(_on_health_changed)
	player.stats.xp_changed.connect(_on_xp_changed)
	player.stats.leveled_up.connect(_on_leveled_up)
	player.stats.stats_changed.connect(_refresh_labels)
	_health_bar.draw.connect(_draw_health)
	_xp_bar.draw.connect(_draw_xp)
	_death_message.visible = false
	_refresh_labels()


func show_death_message(shown: bool) -> void:
	_death_message.visible = shown


func _on_health_changed(current: float, maximum: float) -> void:
	_health_fraction = current / maximum
	_health_bar.queue_redraw()


func _on_xp_changed(xp: int, xp_to_next: int) -> void:
	_xp_fraction = float(xp) / xp_to_next
	_xp_bar.queue_redraw()


func _on_leveled_up(_level: int) -> void:
	if _banner_tween:
		_banner_tween.kill()
	_banner.visible = true
	_banner.modulate.a = 1.0
	_banner_tween = create_tween()
	_banner_tween.tween_interval(1.0)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.6)
	_banner_tween.tween_callback(_banner.hide)


func _refresh_labels() -> void:
	var stats := _player.stats
	_level_label.text = "Lv %d" % stats.level
	_points_label.visible = stats.unspent_points > 0
	_points_label.text = "%d stat points to spend - press C" % stats.unspent_points


func _draw_health() -> void:
	_draw_bar(_health_bar, _health_fraction, Color(0.62, 0.1, 0.14))


func _draw_xp() -> void:
	_draw_bar(_xp_bar, _xp_fraction, Color(0.35, 0.6, 0.85))


func _draw_bar(bar: Control, fraction: float, fill: Color) -> void:
	var size := bar.size
	bar.draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.75))
	var inner := Rect2(Vector2(2, 2), Vector2((size.x - 4.0) * fraction, size.y - 4.0))
	bar.draw_rect(inner, fill)
	bar.draw_rect(Rect2(Vector2.ZERO, size), Color(0.55, 0.5, 0.42), false, 1.0)
