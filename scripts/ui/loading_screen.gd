extends Control
## Shown while a world loads: a pixel heart beating in the dark, drops of
## blood falling from it, a bronze bar filling as the game loads in the
## background, and a tip that changes now and then. (Loaded by path.)
##
## Use LoadingScreen.go(tree, "res://scenes/main.tscn") in place of
## change_scene_to_file.

const BACK := Color("0b0d15")
const NAVY := Color("161b2e")
const BRONZE := Color("c8904a")
const GOLD := Color("e8bc4a")
const BLOOD := Color("b8303c")
const BLOOD_DARK := Color("6e1a2a")
const BLOOD_LIGHT := Color("e86070")
## The heart, one character a pixel: # body, + highlight, - shade.
const HEART: Array[String] = [
	"..##...##..",
	".#++#.###-.",
	"#+++######-",
	"#++#######-",
	"##########-",
	".########-.",
	"..######-..",
	"...####-...",
	"....##-....",
	".....#.....",
]
const TIPS: Array[String] = [
	"Trinkets grow by doing what they are about. Gold will not raise them.",
	"Monsters give up a long chase. Strike them and they come back for more.",
	"The Tenday Road asks less of you each day than the old rite did.",
	"At level 75 you may take up a second class.",
	"An Orb of Awakening is found in one chest in a hundred.",
	"Deep water slows you, but monsters swim no better than you do.",
	"Standing stones bless the traveller who lays a hand on them.",
	"Waystones remember you once touched. Use them to travel far.",
	"A Woodwright's Apron, fully grown, makes every wooden thing cheaper.",
	"Parry just before a blow lands to turn it aside.",
]

var target := ""
## A Hardcore world loads under the evil heart.
var hardcore := false
var _time := 0.0
var _progress := 0.0
var _tip := 0
var _tip_left := 4.0
var _drops: Array = []
var _building := false


static func go(tree: SceneTree, path: String) -> void:
	var screen: Control = load("res://scripts/ui/loading_screen.gd").new()
	screen.target = path
	screen.hardcore = bool(SaveGame.get_section("meta").get("hardcore", false))
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var old := tree.current_scene
	tree.root.add_child(screen)
	tree.current_scene = screen
	if old:
		old.queue_free()


func _ready() -> void:
	_tip = randi() % TIPS.size()
	ResourceLoader.load_threaded_request(target)


func _process(delta: float) -> void:
	_time += delta
	_tip_left -= delta
	if _tip_left <= 0.0:
		_tip_left = 4.0
		_tip = (_tip + 1) % TIPS.size()
	# A drop falls from the heart's tip now and then.
	if randf() < delta * 2.2:
		_drops.append([randf_range(-6.0, 6.0), 0.0])
	for drop: Array in _drops:
		drop[1] += delta * 90.0
	_drops = _drops.filter(func(d: Array) -> bool: return d[1] < 140.0)
	if not _building:
		var progress := []
		var status := ResourceLoader.load_threaded_get_status(target, progress)
		if not progress.is_empty():
			_progress = maxf(_progress, float(progress[0]) * 0.8)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			_building = true
			_progress = 0.85
			_build.call_deferred()
		elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			get_tree().change_scene_to_file(target)
	queue_redraw()


## The scene is in memory: draw "building the world" once more, then make it.
func _build() -> void:
	queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	var scene: PackedScene = ResourceLoader.load_threaded_get(target)
	var made := scene.instantiate()
	get_tree().root.add_child(made)
	get_tree().current_scene = made
	queue_free()


func _draw() -> void:
	var view := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, view), BACK)
	var centre := (view / 2.0 - Vector2(0, 50)).round()
	# The beat: two thumps, then a rest; the heart swells a whole pixel step.
	var beat := fmod(_time, 1.2)
	var thump := 1 if beat < 0.12 or (beat > 0.26 and beat < 0.36) else 0
	var px := 8 + thump
	var size := Vector2(HEART[0].length(), HEART.size()) * px
	var origin := (centre - size / 2.0).round()
	# A dark glow behind, pulsing with the beat.
	for ring in 4:
		draw_circle(centre, 70.0 + ring * 14.0 + thump * 6.0, Color(BLOOD_DARK, 0.06))
	if hardcore:
		load("res://scripts/ui/evil_heart.gd").draw(self, centre, px, _time)
	else:
		for y in HEART.size():
			for x in HEART[y].length():
				var mark := HEART[y][x]
				if mark == ".":
					continue
				var colour := BLOOD_LIGHT if mark == "+" else BLOOD_DARK if mark == "-" else BLOOD
				draw_rect(Rect2(origin + Vector2(x, y) * px, Vector2(px, px)), colour)
	# Drops from the tip.
	var tip := origin + Vector2(5.5 * px, size.y)
	for drop: Array in _drops:
		var at := (tip + Vector2(drop[0], drop[1])).round()
		draw_rect(Rect2(at, Vector2(4, 6)), Color(BLOOD, 1.0 - drop[1] / 140.0))
	# A ring of bronze motes turning slowly round it.
	for k in 12:
		var angle := _time * 0.8 + k * TAU / 12.0
		var spot := (centre + Vector2.from_angle(angle) * 118.0).round()
		var bright := 0.35 + 0.65 * fposmod(1.0 - (k / 12.0) + _time * 0.4, 1.0)
		draw_rect(Rect2(spot - Vector2(2, 2), Vector2(4, 4)), Color(GOLD, bright))
	# The bar and its words.
	var font := UITheme.bold()
	var bar := Rect2(Vector2(view.x / 2.0 - 220.0, centre.y + 170.0).round(), Vector2(440, 14))
	draw_rect(bar.grow(3.0), Color(0.03, 0.03, 0.05))
	draw_rect(bar, NAVY)
	draw_rect(Rect2(bar.position, Vector2(roundf(bar.size.x * _progress), bar.size.y)), BRONZE)
	draw_rect(Rect2(bar.position, Vector2(roundf(bar.size.x * _progress), 3)), GOLD)
	var words := "Building the world..." if _building else "Loading..."
	draw_string(font, Vector2(bar.position.x, bar.position.y - 12.0), words, HORIZONTAL_ALIGNMENT_CENTER, bar.size.x, 18, GOLD)
	draw_string(UITheme.get_theme().default_font, Vector2(view.x / 2.0 - 360.0, bar.end.y + 42.0), TIPS[_tip], HORIZONTAL_ALIGNMENT_CENTER, 720.0, 16, Color(0.78, 0.76, 0.84))
