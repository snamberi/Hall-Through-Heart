extends Node
## Saves and loads progression (autoload "SaveGame").
##
## Every world is its own save slot: a file in user://saves/ named by the
## slot id. Each system registers under a stable section name and provides
## save_data() -> Dictionary and load_data(data: Dictionary). Loading must
## tolerate missing keys, so old saves keep working as the game grows.
## The "meta" section describes the slot for the title screen.

const VERSION := 2
const AUTOSAVE_SECONDS := 30.0
const DIRECTORY := "user://saves"
## Timestamped copies of each world, the newest few kept.
const BACKUPS := "user://saves/backups"
const BACKUP_EVERY := 600.0
const BACKUPS_KEPT := 5
## Where the single save lived before slots existed.
const OLD_PATH := "user://save.json"

## Turn off to play without reading or writing a save file.
var enabled := true
## The file being played. Tests may point this anywhere.
var path := ""
var slot_id := ""

## When the game last reached the disk (Unix seconds; 0 = not this session),
## and why the last try failed ("" when it worked).
var last_saved_at := 0.0
var last_error := ""
var _data: Dictionary = {}
var _targets: Dictionary[String, Node] = {}
var _autosave_left := AUTOSAVE_SECONDS
var _dirty := false
## Seconds of play until the next backup copy (the first save of a session
## makes one at once).
var _backup_left := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(DIRECTORY)
	DirAccess.make_dir_recursive_absolute(BACKUPS)
	_migrate_old_save()


## Every save slot, most recently played first: [{"id", "meta"}].
func list_slots() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	for file in DirAccess.get_files_at(DIRECTORY):
		if not file.ends_with(".json"):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY.path_join(file)))
		if parsed is Dictionary:
			var meta: Variant = parsed.get("meta", {})
			slots.append({"id": file.get_basename(), "meta": meta if meta is Dictionary else {}})
	slots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["meta"].get("played_at", 0)) > float(b["meta"].get("played_at", 0))
	)
	return slots


func has_slot(id: String) -> bool:
	return id != "" and FileAccess.file_exists(_slot_path(id))


## Makes a new, empty world and selects it.
func create_slot(world_name: String, difficulty: String, world_seed: int = 0, appearance: Dictionary = {}, class_id: String = "adventurer", hardcore: bool = false) -> String:
	var id := "world_%d_%d" % [int(Time.get_unix_time_from_system()), randi() % 10000]
	use_slot(id)
	_data = {"meta": {"name": world_name, "difficulty": "insane" if hardcore else difficulty, "hardcore": hardcore, "created_at": Time.get_unix_time_from_system(),
		"played_at": Time.get_unix_time_from_system(), "level": 1, "day": 1, "appearance": appearance.duplicate(), "class_id": class_id}}
	if world_seed != 0:
		_data["world"] = {"seed": world_seed}
	_write()
	return id


## Selects a slot and reads it from disk.
func use_slot(id: String) -> void:
	slot_id = id
	path = _slot_path(id)
	_targets.clear()
	GameSettings.set_value("last_slot", id)
	reload()


func delete_slot(id: String) -> void:
	if FileAccess.file_exists(_slot_path(id)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_slot_path(id)))
	if slot_id == id:
		slot_id = ""
		path = ""
		_data = {}


## Reads the save file from disk, replacing what is in memory.
func reload() -> void:
	_data = {}
	if not enabled or path == "" or not FileAccess.file_exists(path):
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
	if not enabled or path == "":
		return
	_data["version"] = VERSION
	for section in _targets:
		if is_instance_valid(_targets[section]):
			_data[section] = _targets[section].save_data()
	# Keep the slot's summary up to date for the save list.
	var meta := get_section("meta")
	meta["played_at"] = Time.get_unix_time_from_system()
	meta["level"] = int(get_section("leveling").get("level", meta.get("level", 1)))
	meta["day"] = int(get_section("world").get("day", meta.get("day", 1)))
	meta["class"] = str(get_section("character").get("class_id", "adventurer"))
	_data["meta"] = meta
	_write()
	if _backup_left <= 0.0 and slot_id != "" and last_error == "":
		_backup_left = BACKUP_EVERY
		make_backup()


## Copies the world's save to a timestamped backup and keeps only the
## newest BACKUPS_KEPT of them.
func make_backup() -> void:
	if slot_id == "" or not FileAccess.file_exists(path):
		return
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var copy := BACKUPS.path_join("%s__%s.json" % [slot_id, stamp])
	DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(copy))
	var old := backups_for(slot_id)
	for index in range(BACKUPS_KEPT, old.size()):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BACKUPS.path_join(old[index]["file"])))


## A world's backups, newest first: [{"file", "when", "level", "day"}].
func backups_for(id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for file in DirAccess.get_files_at(BACKUPS):
		if not file.begins_with(id + "__") or not file.ends_with(".json"):
			continue
		var when := file.trim_prefix(id + "__").trim_suffix(".json")
		var meta := {}
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BACKUPS.path_join(file)))
		if parsed is Dictionary and parsed.get("meta") is Dictionary:
			meta = parsed["meta"]
		out.append({"file": file, "when": when.replace("_", "  ").replace("-", ":").replace("::", "-"), "stamp": when, "level": int(meta.get("level", 1)), "day": int(meta.get("day", 1))})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["stamp"]) > str(b["stamp"]))
	return out


## Puts a backup back in place of the world's save (the save being
## replaced is itself kept as a backup first).
func restore_backup(id: String, file: String) -> bool:
	var source := BACKUPS.path_join(file)
	if not FileAccess.file_exists(source):
		return false
	var target := _slot_path(id)
	if FileAccess.file_exists(target):
		var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
		DirAccess.copy_absolute(ProjectSettings.globalize_path(target), ProjectSettings.globalize_path(BACKUPS.path_join("%s__%s.json" % [id, stamp + "-before-restore"])))
	DirAccess.copy_absolute(ProjectSettings.globalize_path(source), ProjectSettings.globalize_path(target))
	if slot_id == id:
		reload()
	return true


## Empties the current slot (used by tests and by starting over in place).
func delete_save() -> void:
	_data = {}
	_targets.clear()
	_dirty = false
	if path != "" and FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _process(delta: float) -> void:
	if _targets.is_empty():
		return
	_backup_left -= delta
	_autosave_left -= delta
	if _dirty or _autosave_left <= 0.0:
		save_now()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not _targets.is_empty():
		save_now()


func _write() -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		last_error = "Could not write the save file (%s)." % error_string(FileAccess.get_open_error())
		push_warning(last_error)
		return
	file.store_string(JSON.stringify(_data, "\t"))
	last_error = ""
	last_saved_at = Time.get_unix_time_from_system()


func _slot_path(id: String) -> String:
	return DIRECTORY.path_join(id + ".json")


## Turns the save from before slots existed into the first slot.
func _migrate_old_save() -> void:
	if not FileAccess.file_exists(OLD_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(OLD_PATH))
	if parsed is Dictionary and not parsed.is_empty():
		var data: Dictionary = parsed
		data["meta"] = {"name": "My World", "difficulty": "normal", "played_at": Time.get_unix_time_from_system(),
			"level": int(data.get("leveling", {}).get("level", 1))}
		var file := FileAccess.open(_slot_path("world_migrated"), FileAccess.WRITE)
		if file:
			file.store_string(JSON.stringify(data, "\t"))
			if GameSettings.last_slot == "":
				GameSettings.set_value("last_slot", "world_migrated")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OLD_PATH))
