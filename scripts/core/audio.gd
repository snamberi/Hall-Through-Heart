extends Node
## Music and sound effects (autoload "Audio").
##
## Audio.play("hit") plays assets/audio/hit.wav on the SFX bus. The music
## loop starts by itself and keeps playing through pauses.

const SOUNDS: Array[String] = ["swing", "hit", "pickup", "level_up", "ui_hover", "ui_click", "chop", "mine", "transform", "heartbeat", "step_grass", "step_stone", "step_snow", "step_water", "step_sand", "bird", "drip", "thunder", "buzz", "flutter", "crow", "owl"]
const VOICES := 12
## Voices for sounds that come from a place in the world (creatures).
const PLACED_VOICES := 16
const CREATURE_SOUNDS := "res://assets/audio/creatures/%s_%s.wav"

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _placed: Array[AudioStreamPlayer2D] = []
var _next_placed := 0
## Creature sounds loaded so far: "id_kind" -> stream, or null if it has none.
var _creature_streams: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for sound in SOUNDS:
		_streams[sound] = load("res://assets/audio/%s.wav" % sound)
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_players.append(player)
	for i in PLACED_VOICES:
		var placed := AudioStreamPlayer2D.new()
		placed.bus = "SFX"
		placed.max_distance = 760.0
		placed.attenuation = 1.6
		add_child(placed)
		_placed.append(placed)

	var music: AudioStreamOggVorbis = load("res://assets/audio/music.ogg")
	music.loop = true
	var music_player := AudioStreamPlayer.new()
	music_player.stream = music
	music_player.bus = "Music"
	music_player.volume_db = -4.0
	add_child(music_player)
	music_player.play()


## A creature's own sound ("idle", "hurt", "death" or "step"), or null.
func creature_stream(creature: String, kind: String) -> AudioStream:
	var key := creature + "_" + kind
	if not _creature_streams.has(key):
		var path := CREATURE_SOUNDS % [creature, kind]
		_creature_streams[key] = load(path) if ResourceLoader.exists(path) else null
	return _creature_streams[key]


## Plays a creature's sound where it stands, quieter with distance from the
## listener. `pitch` lowers it for bigger kin (bosses).
func play_creature(creature: String, kind: String, at: Vector2, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var stream := creature_stream(creature, kind)
	if stream == null:
		return
	var player := _placed[_next_placed]
	_next_placed = (_next_placed + 1) % PLACED_VOICES
	player.stream = stream
	player.global_position = at
	player.volume_db = volume_db
	player.pitch_scale = pitch * randf_range(0.94, 1.06)
	player.play()


## Plays a sound effect. `pitch_spread` varies the pitch so repeats differ.
func play(sound: String, volume_db: float = 0.0, pitch_spread: float = 0.08) -> void:
	if not _streams.has(sound):
		return
	var player := _players[_next]
	_next = (_next + 1) % VOICES
	player.stream = _streams[sound]
	player.volume_db = volume_db
	player.pitch_scale = 1.0 + randf_range(-pitch_spread, pitch_spread)
	player.play()
