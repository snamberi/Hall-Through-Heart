class_name Ambience
extends Node
## The sound of the place: wind over open ground, rain, crickets after dark,
## the hollow breath of caves, a fire's crackle when one is near, and now
## and then a bird, a drip, a roll of thunder. Each bed fades up and down
## as the player moves between places.

const BEDS: Array[String] = ["amb_wind", "amb_rain", "amb_night", "amb_cave", "amb_fire"]
## Loudest each bed gets, in decibels.
const LEVELS := {"amb_wind": -17.0, "amb_rain": -9.0, "amb_night": -15.0, "amb_cave": -11.0, "amb_fire": -9.0}

var _player: Player
var _world: World
var _day_night: DayNight
var _players: Dictionary = {}
## How loud each bed should be now, 0 to 1.
var _wanted: Dictionary = {}
var _volume: Dictionary = {}
var _check := 0.0
var _one_shot := 4.0


func setup(player: Player, world: World, day_night: DayNight) -> void:
	_player = player
	_world = world
	_day_night = day_night
	for bed in BEDS:
		var stream: AudioStreamWAV = (load("res://assets/audio/%s.wav" % bed) as AudioStreamWAV).duplicate()
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
		var voice := AudioStreamPlayer.new()
		voice.stream = stream
		voice.bus = "SFX"
		voice.volume_db = -60.0
		add_child(voice)
		_players[bed] = voice
		_wanted[bed] = 0.0
		_volume[bed] = 0.0


func _process(delta: float) -> void:
	if _player == null:
		return
	_check -= delta
	if _check <= 0.0:
		_check = 0.4
		_listen()
	for bed in BEDS:
		_volume[bed] = move_toward(_volume[bed], _wanted[bed], delta * 0.6)
		var voice: AudioStreamPlayer = _players[bed]
		if _volume[bed] > 0.01:
			voice.volume_db = linear_to_db(_volume[bed]) + LEVELS[bed]
			if not voice.playing:
				voice.play(randf() * 2.0)
		elif voice.playing:
			voice.stop()
	_one_shot -= delta
	if _one_shot <= 0.0:
		_one_shot = randf_range(3.0, 9.0)
		_sing()


## Decides how loud each bed should be where the player stands.
func _listen() -> void:
	var inside := _player.indoors
	var cave := inside and _day_night.cave_dark > 0.5
	var T := TerrainTiles.Type
	var tile: int = -1 if inside else _world.tile_type_at_position(_player.global_position)
	var storm := Atmosphere.weather
	var wind := 0.0
	if not inside:
		wind = 0.45
		if tile in [T.PEAK, T.ROCK, T.SNOW, T.SALT, T.SAND]:
			wind = 0.8
		if storm in ["Blizzard", "Sandstorm", "Ash storm", "Thunderstorm"]:
			wind = 1.0
	_wanted["amb_wind"] = wind
	_wanted["amb_rain"] = 0.0 if inside else 1.0 if storm == "Thunderstorm" else 0.7 if storm == "Rain" else 0.0
	var warm_night := not inside and _day_night.is_night() and storm == "" and not tile in [T.SNOW, T.FROSTPINE, T.PEAK, T.SALT, T.VOIDSCAR, T.CINDER, T.ASH]
	_wanted["amb_night"] = 1.0 if warm_night else 0.0
	_wanted["amb_cave"] = 1.0 if cave else 0.0
	# The nearest fire, louder the closer.
	var nearest := 9999.0
	for node in get_tree().get_nodes_in_group("fires"):
		nearest = minf(nearest, (node as Node2D).global_position.distance_to(_player.global_position))
	_wanted["amb_fire"] = clampf(1.0 - nearest / 230.0, 0.0, 1.0)


## A passing sound that suits the place.
func _sing() -> void:
	if _player.is_dead():
		return
	if _player.indoors:
		if _day_night.cave_dark > 0.5:
			Audio.play("drip", randf_range(-18.0, -9.0), 0.25)
		return
	if Atmosphere.weather == "Thunderstorm":
		if randf() < 0.5:
			Audio.play("thunder", randf_range(-12.0, -5.0), 0.15)
		return
	var T := TerrainTiles.Type
	var tile := _world.tile_type_at_position(_player.global_position)
	if Atmosphere.weather == "" and not _day_night.is_night() and tile in [T.DARK_GRASS, T.DEAD_GRASS, T.THORN, T.BOG, T.FROSTPINE, T.MUD, T.FUNGAL]:
		Audio.play("bird", randf_range(-20.0, -12.0), 0.3)
		if randf() < 0.5:
			get_tree().create_timer(randf_range(0.25, 0.6)).timeout.connect(func() -> void: Audio.play("bird", randf_range(-22.0, -14.0), 0.35))
