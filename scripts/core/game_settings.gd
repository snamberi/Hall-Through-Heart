extends Node
## Player preferences (autoload "GameSettings"): volumes and interface options.
##
## Kept in their own file so they survive starting a new game.

signal changed

const PATH := "user://settings.json"

var music_volume := 0.6
var sfx_volume := 0.8
var show_minimap := true


func _ready() -> void:
	for bus: String in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	if FileAccess.file_exists(PATH):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if data is Dictionary:
			music_volume = clampf(float(data.get("music_volume", music_volume)), 0.0, 1.0)
			sfx_volume = clampf(float(data.get("sfx_volume", sfx_volume)), 0.0, 1.0)
			show_minimap = bool(data.get("show_minimap", show_minimap))
	_apply()


## Changes a setting by name ("music_volume", "sfx_volume", "show_minimap").
func set_value(setting: String, value: Variant) -> void:
	set(setting, value)
	_apply()
	changed.emit()
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"music_volume": music_volume, "sfx_volume": sfx_volume, "show_minimap": show_minimap}))


func _apply() -> void:
	_set_bus("Music", music_volume)
	_set_bus("SFX", sfx_volume)


func _set_bus(bus: String, volume: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	AudioServer.set_bus_mute(index, volume <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.001)))
