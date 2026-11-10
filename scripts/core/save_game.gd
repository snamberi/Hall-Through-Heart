extends Node
## Saves and loads progression (autoload "SaveGame").
##
## Each system registers under a stable section name and provides
## save_data() -> Dictionary and load_data(data: Dictionary). Loading must
## tolerate missing keys, so old saves keep working as the game grows.

const VERSION := 1
const AUTOSAVE_SECONDS := 30.0

## Turn off to play without reading or writing a save file.
var enabled := true
var path := "user://save.json"

var _data: Dictionary = {}
var _targets: Dictionary[String, Node] = {}
var _autosave_left := AUTOSAVE_SECONDS
var _dirty := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	reload()


## Reads the save file from disk, replacing what is in memory.
func reload() -> void:
	_data = {}
	if not enabled or not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		_data = parsed
	else:
		push_warning("Save file could not be read; starting fresh.")


func has_save() -> bool:
	return not _data.is_empty()


func get_section(section: String) -> Dictionary:
	var value: Variant = _data.get(section, {})
	return value if value is Dictionary else {}


## Registers a system and immediately hands it any saved data.
func register(section: String, target: Node) -> void:
	_targets[section] = target
	if _data.has(section):
		target.load_data(get_section(section))


## Saves soon. Safe to call many times in a row.
func request_save() -> void:
	_dirty = true


func save_now() -> void:
	_dirty = false
	_autosave_left = AUTOSAVE_SECONDS
	if not enabled:
		return
	_data["version"] = VERSION
	for section in _targets:
		if is_instance_valid(_targets[section]):
			_data[section] = _targets[section].save_data()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write the save file.")
		return
	file.store_string(JSON.stringify(_data, "\t"))


func delete_save() -> void:
	_data = {}
	_targets.clear()
	_dirty = false
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _process(delta: float) -> void:
	_autosave_left -= delta
	if _dirty or _autosave_left <= 0.0:
		save_now()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not _targets.is_empty():
		save_now()
