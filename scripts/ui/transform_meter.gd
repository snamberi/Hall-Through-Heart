class_name TransformMeter
extends Control
## The block on the left of the HUD for transformations: the chosen form's
## face, a meter that fills over time and with every blow landed, the key to
## hold when it is full, and the time left once changed.

var _player: Player
static var _portraits: Dictionary = {}


## A form's face, cut from its sheet.
static func portrait(id: String) -> Texture2D:
	if not _portraits.has(id):
		var atlas := AtlasTexture.new()
		atlas.atlas = load("res://assets/sprites/enemies/%s.png" % Transformations.FORMS[id]["sheet"])
		atlas.region = Rect2(22, 22, 52, 52)
		_portraits[id] = atlas
	return _portraits[id]


func setup(player: Player) -> void:
	_player = player
	custom_minimum_size = Vector2(132.0, 50.0)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	if _player == null:
		return
	# Nothing to show until the first form is near.
	visible = _player.leveling.level >= Transformations.first_level() - 5
	if visible:
		queue_redraw()


func _draw() -> void:
	var forms := _player.transformations
	var font := UITheme.get_theme().default_font
	var rect := Rect2(Vector2.ZERO, size)
	var id := forms.active if forms.active != "" else forms.current()
	draw_rect(rect.grow(2.0), Color(0.02, 0.02, 0.04, 0.85))
	draw_rect(rect, Color(0.07, 0.08, 0.13, 0.94))
	draw_rect(rect, Color("8a683a"), false, 1.5)
	var face := Vector2(25.0, 25.0)
	draw_circle(face, 21.0, Color(0.03, 0.035, 0.06))
	if id == "":
		# Not yet unlocked: a promise.
		draw_arc(face, 21.0, 0.0, TAU, 32, Color("5a4a32"), 2.0)
		draw_texture_rect(ItemDB.icon(92), Rect2(face - Vector2(15, 15), Vector2(30, 30)), false, Color(1, 1, 1, 0.25))
		draw_string(font, Vector2(52.0, 21.0), "Forms", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UITheme.DIM)
		draw_string(font, Vector2(52.0, 38.0), "at level %d" % Transformations.first_level(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UITheme.DIM)
		return
	var form: Dictionary = Transformations.FORMS[id]
	var color: Color = form["color"]
	var t := Time.get_ticks_msec() / 1000.0
	draw_texture_rect(portrait(id), Rect2(face - Vector2(19, 19), Vector2(38, 38)), false, form["tint"] if forms.active != "" or forms.charge >= 1.0 else Color(0.55, 0.55, 0.6))
	var bar := Rect2(52.0, 30.0, 72.0, 9.0)
	draw_rect(bar, Color(0.03, 0.035, 0.06))
	if forms.active != "":
		# Changed: the time left drains away.
		var share := clampf(forms.time_left / float(form["seconds"]), 0.0, 1.0)
		draw_arc(face, 21.0, -PI / 2.0, -PI / 2.0 + TAU * share, 40, color, 3.0)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * share, bar.size.y)), color)
		draw_string(font, Vector2(52.0, 22.0), form["name"], HORIZONTAL_ALIGNMENT_LEFT, 76.0, 13, color.lightened(0.3))
		draw_string(font, Vector2(52.0, 49.0), "%d s" % ceili(forms.time_left), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UITheme.TEXT)
	else:
		var ready := forms.charge >= 1.0
		var pulse := 0.5 + 0.5 * sin(t * 5.0)
		draw_arc(face, 21.0, 0.0, TAU, 40, Color("5a4a32"), 2.0)
		draw_arc(face, 21.0, -PI / 2.0, -PI / 2.0 + TAU * forms.charge, 40, color.lerp(Color.WHITE, pulse * 0.5) if ready else color.darkened(0.2), 3.0)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * forms.charge, bar.size.y)), color if ready else color.darkened(0.35))
		if forms.hold > 0.0:
			# Holding the key: a white ring closes as the change gathers.
			var held := clampf(forms.hold / Transformations.HOLD_SECONDS, 0.0, 1.0)
			draw_arc(face, 16.0, -PI / 2.0, -PI / 2.0 + TAU * held, 32, Color.WHITE, 3.0)
			draw_rect(Rect2(bar.position, Vector2(bar.size.x * held, bar.size.y)), Color(1, 1, 1, 0.85))
		var key := GameSettings.describe("transform").split(" / ")[0]
		var words: String = "Hold %s" % key if ready else str(form["name"])
		draw_string(font, Vector2(52.0, 22.0), words, HORIZONTAL_ALIGNMENT_LEFT, 76.0, 13, UITheme.GOLD.lerp(Color.WHITE, pulse) if ready else UITheme.DIM)
		if ready:
			draw_rect(rect.grow(1.0 + pulse * 2.0), Color(color, 0.5 * pulse), false, 1.5)
		else:
			draw_string(font, Vector2(52.0, 49.0), "%d%%" % roundi(forms.charge * 100.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UITheme.DIM)
	draw_rect(bar, Color("8a683a"), false, 1.0)
