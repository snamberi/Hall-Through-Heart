class_name Voices
extends CanvasLayer
## Two voices over the game screen.
##
## The Heart speaks when something rare happens to you (a gift woken, an
## Echo of a great beast, a Name given, a treaty made or broken): a banner
## high in the middle, "THE HEART SPEAKS", gold on a crimson rule, with a
## heartbeat as it comes.
##
## The Still Voice is your own mind, quiet and exact: a pale line or two
## above the hotbar that sizes up monsters the first time you meet them,
## warns when you are near death, and points out what you might miss.
## It can be hushed in the settings. Both go into the Log.

## Seconds the Heart's words stay; seconds a Still Voice line stays.
const HEART_SECONDS := 5.5
const STILL_SECONDS := 6.0
const STILL_COLOR := Color("a8d8e8")
const HEART_GOLD := Color("f2c14e")
const HEART_RED := Color("c83a48")
## What a monster's way of attacking asks of you, by attack kind.
const ATTACK_HINTS := {
	"swipe": "a wide swipe: step back out of it, not to the side",
	"lunge": "it lunges in a line: sidestep as it comes",
	"charge": "it charges: let it pass, then strike its back",
	"thrust": "a long thrust: get to its side",
	"combo": "it strikes three times: wait for the last",
	"pounce": "it pounces where you stand: move as it crouches",
	"spit": "it spits from afar: close in",
	"shoot": "it shoots: close in, or keep cover between you",
	"slam": "it slams the ground: leave the ring before it lands",
	"spin": "it spins: stay out of reach until it stops",
	"burrow": "it burrows: keep moving when the ground stirs",
	"cloud": "it breathes a cloud: step out and wait",
	"explode": "it bursts when close: kill it from afar, or run",
	"swoop": "it swoops from the air: dodge as it dives",
}

## [text, detail, time shown]
var _heart: Array = []
## The Pact's windows: [[title, lines, age], ...] newest last.
var _pact: Array = []
const PACT_SECONDS := 6.0
const PACT_BRONZE := Color("c8904a")
const PACT_TEXT := Color("bfe4f0")
## [[text, age], ...] newest last.
var _still: Array = []
## Keys already said this session (so a voice does not repeat itself).
var _said: Dictionary = {}
var _player: Player
var _canvas: Control
var _low_health_wait := 0.0


func _ready() -> void:
	add_to_group("voices")
	layer = 6


func setup(player: Player) -> void:
	_player = player
	_canvas = Control.new()
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_all)
	add_child(_canvas)


## The Heart speaks.
static func heart(tree: SceneTree, text: String, detail: String = "") -> void:
	var voices: Voices = tree.get_first_node_in_group("voices") if tree else null
	Chronicle.say(tree, "event", "The Heart", text + ("  " + detail if detail != "" else ""))
	if voices:
		voices._heart = [text, detail, 0.0]
		Audio.play_note("heartbeat", 0.85, -2.0)


## The Pact shows a window: a title and a few lines.
static func pact(tree: SceneTree, title: String, lines: Array = []) -> void:
	var voices: Voices = tree.get_first_node_in_group("voices") if tree else null
	Chronicle.say(tree, "event", "The Pact", title + ((": " + " ".join(lines)) if not lines.is_empty() else ""))
	if voices == null or not GameSettings.system_window:
		return
	voices._pact.append([title, lines, 0.0])
	while voices._pact.size() > 2:
		voices._pact.pop_front()
	Audio.play_note("ui_click", 0.6, -6.0)


## The Still Voice says something (once per `key`, if a key is given).
static func inner(tree: SceneTree, text: String, key: String = "") -> void:
	var voices: Voices = tree.get_first_node_in_group("voices") if tree else null
	if voices == null or not GameSettings.inner_voice:
		return
	if key != "":
		if voices._said.has(key):
			return
		voices._said[key] = true
	voices._still.append([text, 0.0])
	while voices._still.size() > 3:
		voices._still.pop_front()
	Chronicle.say(tree, "voice", "Still Voice", text)


## Sizes up a monster the first time it comes for you.
static func analyse(enemy: Enemy) -> void:
	if not GameSettings.inner_voice or enemy == null or not enemy.is_inside_tree():
		return
	var data: Dictionary = EnemyDB.ENEMIES.get(enemy.enemy_id, {})
	if data.is_empty() or data.has("wild"):
		return
	var parts: PackedStringArray = []
	var weak: PackedStringArray = []
	var hardy: PackedStringArray = []
	for element: String in Elements.LIST:
		var factor := Elements.multiplier(enemy.enemy_id, element)
		if factor > 1.0:
			weak.append(element)
		elif factor < 1.0:
			hardy.append(element)
	if not weak.is_empty():
		parts.append("weak to " + ", ".join(weak))
	if not hardy.is_empty():
		parts.append("resists " + ", ".join(hardy))
	for id: String in data.get("traits", []):
		parts.append(id)
	var hint: String = ATTACK_HINTS.get(str(data["attack"]["kind"]), "")
	var line := "%s. %s%s" % [data["name"], (_sentence(", ".join(parts)) + ". ") if not parts.is_empty() else "", _sentence(hint) + "." if hint != "" else ""]
	if enemy.has_trait("masked"):
		line = "%s. Its mask faces you, and turns slowly. Strike from behind, or crack it with heavy blows." % data["name"]
	inner(enemy.get_tree(), "Analysis: " + line, "analyse_" + enemy.enemy_id)


static func _sentence(text: String) -> String:
	return text.left(1).to_upper() + text.substr(1)


func _process(delta: float) -> void:
	if _canvas == null:
		return
	if not _heart.is_empty():
		_heart[2] = float(_heart[2]) + delta
		if float(_heart[2]) > HEART_SECONDS:
			_heart = []
	for line: Array in _still:
		line[1] = float(line[1]) + delta
	_still = _still.filter(func(line: Array) -> bool: return float(line[1]) < STILL_SECONDS)
	for window: Array in _pact:
		window[2] = float(window[2]) + delta
	_pact = _pact.filter(func(window: Array) -> bool: return float(window[2]) < PACT_SECONDS)
	# Near death: a word of advice, now and then.
	_low_health_wait = maxf(_low_health_wait - delta, 0.0)
	if _player and not _player.is_dead() and _low_health_wait <= 0.0 and _player.health.current < _player.health.max_health * 0.25:
		_low_health_wait = 45.0
		inner(get_tree(), "Your wounds are grave. Withdraw, or drink something.")
	_canvas.queue_redraw()


func _draw_all() -> void:
	var view := _canvas.size
	if not _heart.is_empty():
		_draw_heart(view)
	if not _still.is_empty():
		_draw_still(view)
	if not _pact.is_empty():
		_draw_pact(view)


## The Heart's banner: a crimson rule with a small heart, the words in gold
## under it, fading in and out, the rule beating.
func _draw_heart(view: Vector2) -> void:
	var t := float(_heart[2])
	var fade := clampf(t / 0.4, 0.0, 1.0) * clampf((HEART_SECONDS - t) / 0.8, 0.0, 1.0)
	var top := roundf(view.y * 0.6)
	var beat := 1.0 + 0.6 * maxf(sin(t * 7.0), 0.0) * clampf(1.0 - t / 2.0, 0.0, 1.0)
	var middle := roundf(view.x / 2.0)
	var reach := roundf(minf(view.x * 0.32, 420.0))
	for k in 2:
		var y := top + k * 3.0
		_canvas.draw_rect(Rect2(middle - reach, y, reach * 2.0, 1.0), Color(HEART_RED, 0.75 * fade if k == 0 else 0.35 * fade))
	# The little heart, two pixels per pixel of its shape.
	var shape := ["01100110", "11111111", "11111111", "01111110", "00111100", "00011000"]
	var size := roundf(2.0 * beat)
	for row in shape.size():
		for col in 8:
			if shape[row][col] == "1":
				_canvas.draw_rect(Rect2(middle - 4.0 * size + col * size, top - 7.0 * size + row * size + 4.0, size, size), Color(HEART_RED, fade))
	var font := UITheme.bold()
	var label := "THE HEART SPEAKS"
	var label_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	_canvas.draw_string_outline(font, Vector2(middle - label_width / 2.0, top + 22.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0, 0, 0, 0.8 * fade))
	_canvas.draw_string(font, Vector2(middle - label_width / 2.0, top + 22.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(HEART_RED.lightened(0.25), fade))
	var words: String = _heart[0]
	var words_width := font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	_canvas.draw_string_outline(font, Vector2(middle - words_width / 2.0, top + 52.0), words, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, 6, Color(0, 0, 0, 0.85 * fade))
	_canvas.draw_string(font, Vector2(middle - words_width / 2.0, top + 52.0), words, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(HEART_GOLD, fade))
	var detail: String = _heart[1]
	if detail != "":
		var body := UITheme.body_bold()
		var detail_width := body.get_string_size(detail, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		_canvas.draw_string_outline(body, Vector2(middle - detail_width / 2.0, top + 76.0), detail, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(0, 0, 0, 0.85 * fade))
		_canvas.draw_string(body, Vector2(middle - detail_width / 2.0, top + 76.0), detail, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(UITheme.TEXT, fade))


## The Still Voice: pale lines above the hotbar, each led by a small
## diamond, fading as they age.
func _draw_still(view: Vector2) -> void:
	var font := UITheme.body_bold()
	var y := view.y - 132.0 - (_still.size() - 1) * 20.0
	for line: Array in _still:
		var age := float(line[1])
		var fade := clampf(age / 0.3, 0.0, 1.0) * clampf((STILL_SECONDS - age) / 1.0, 0.0, 1.0)
		var text: String = line[0]
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		var x := roundf(view.x / 2.0 - width / 2.0)
		_canvas.draw_rect(Rect2(x - 22.0, y - 14.0, width + 34.0, 20.0), Color(0.02, 0.04, 0.08, 0.55 * fade))
		var gem := Vector2(x - 12.0, y - 4.0)
		_canvas.draw_colored_polygon(PackedVector2Array([gem + Vector2(0, -4), gem + Vector2(4, 0), gem + Vector2(0, 4), gem + Vector2(-4, 0)]), Color(STILL_COLOR, fade))
		_canvas.draw_string_outline(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 3, Color(0, 0, 0, 0.7 * fade))
		_canvas.draw_string(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(STILL_COLOR, fade))
		y += 20.0


## The Pact's windows: navy panels with a double bronze rule, a small
## header, the title in pale ice, and the lines under it; sliding in from
## the right and fading.
func _draw_pact(view: Vector2) -> void:
	var font := UITheme.body_bold()
	var title_font := UITheme.bold()
	var width := 340.0
	var y := roundf(view.y * 0.5)
	for window: Array in _pact:
		var age := float(window[2])
		var fade := clampf(age / 0.25, 0.0, 1.0) * clampf((PACT_SECONDS - age) / 0.8, 0.0, 1.0)
		var slide := roundf((1.0 - clampf(age / 0.25, 0.0, 1.0)) * 40.0)
		var lines: Array = window[1]
		var height := 52.0 + lines.size() * 18.0
		var box := Rect2(view.x - width - 16.0 + slide, y, width, height)
		_canvas.draw_rect(box, Color(0.04, 0.07, 0.13, 0.92 * fade))
		_canvas.draw_rect(box, Color(PACT_BRONZE, fade), false, 2.0)
		_canvas.draw_rect(box.grow(-4.0), Color(PACT_BRONZE.darkened(0.4), 0.8 * fade), false, 1.0)
		for corner: Vector2 in [box.position, Vector2(box.end.x - 6, box.position.y), Vector2(box.position.x, box.end.y - 6), box.end - Vector2(6, 6)]:
			_canvas.draw_rect(Rect2(corner, Vector2(6, 6)), Color(PACT_BRONZE.lightened(0.2), fade))
		var header := "THE PACT"
		_canvas.draw_string(font, Vector2(box.position.x + 14.0, box.position.y + 18.0), header, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(PACT_BRONZE, fade))
		_canvas.draw_string(title_font, Vector2(box.position.x + 14.0, box.position.y + 38.0), str(window[0]), HORIZONTAL_ALIGNMENT_LEFT, width - 28.0, 17, Color(PACT_TEXT, fade))
		var line_y := box.position.y + 56.0
		for line: Variant in lines:
			_canvas.draw_string(font, Vector2(box.position.x + 14.0, line_y), str(line), HORIZONTAL_ALIGNMENT_LEFT, width - 28.0, 13, Color(UITheme.TEXT, fade))
			line_y += 18.0
		y += height + 8.0
