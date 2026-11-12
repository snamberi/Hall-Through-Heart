extends Node
## Music and sound effects (autoload "Audio").
##
## Audio.play("hit") plays assets/audio/hit.wav on the SFX bus. The music
## loop starts by itself and keeps playing through pauses.

const SOUNDS: Array[String] = ["swing", "hit", "pickup", "level_up", "ui_hover", "ui_click", "chop", "mine", "transform"]
const VOICES := 8

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for sound in SOUNDS:
		_streams[sound] = load("res://assets/audio/%s.wav" % sound)
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_players.append(player)

	var music: AudioStreamOggVorbis = load("res://assets/audio/music.ogg")
	music.loop = true
	var music_player := AudioStreamPlayer.new()
	music_player.stream = music
	music_player.bus = "Music"
	music_player.volume_db = -4.0
	add_child(music_player)
	music_player.play()


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
