extends Node
## Player preferences (autoload "GameSettings"): sound, display, gameplay
## options, and key bindings. Kept in their own file so they are shared by
## every save.

signal changed

const PATH := "user://settings.json"
## Settings saved by name, with their defaults.
const DEFAULTS := {
	"master_volume": 1.0,
	"music_volume": 0.6,
	"sfx_volume": 0.8,
	"show_minimap": true,
	"fullscreen": false,
	"vsync": true,
	"screen_shake": true,
	"damage_numbers": true,
	"last_slot": "",
}
## Actions players may rebind, in the order the Controls tab lists them.
const REBINDABLE: Array[Array] = [
	["move_up", "Move up"], ["move_down", "Move down"], ["move_left", "Move left"], ["move_right", "Move right"],
	["attack", "Attack"], ["dodge", "Dodge"], ["interact", "Gather / talk / use"],
	["ability_1", "Ability 1"], ["ability_2", "Ability 2"], ["ability_3", "Ability 3"], ["ability_4", "Ability 4"],
	["ability_swap", "Switch ability set"], ["quick_potion", "Drink health potion"],
	["hotbar_1", "Hotbar 1"], ["hotbar_2", "Hotbar 2"], ["hotbar_3", "Hotbar 3"], ["hotbar_4", "Hotbar 4"], ["hotbar_5", "Hotbar 5"],
	["toggle_menu", "Menu wheel"], ["toggle_inventory", "Inventory"], ["toggle_character", "Attributes"],
	["toggle_talents", "Talents"], ["toggle_professions", "Professions"], ["toggle_journal", "Journal"],
	["toggle_map", "Map"], ["recall_home", "Recall home"], ["dismantle", "Take down a building"],
]

var master_volume := 1.0
var music_volume := 0.6
var sfx_volume := 0.8
var show_minimap := true
var fullscreen := false
var vsync := true
var screen_shake := true
var damage_numbers := true
var last_slot := ""
## action -> saved events, each {"key": physical keycode} or {"mouse": button}.
var bindings: Dictionary = {}

## The project's own bindings, so "Reset to defaults" can restore them.
var _defaults: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus: String in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	for entry in REBINDABLE:
		if InputMap.has_action(entry[0]):
			_defaults[entry[0]] = _events_to_data(InputMap.action_get_events(entry[0]))
	if FileAccess.file_exists(PATH):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if data is Dictionary:
			for setting: String in DEFAULTS:
				if data.has(setting):
					set(setting, data[setting])
			master_volume = clampf(master_volume, 0.0, 1.0)
			music_volume = clampf(music_volume, 0.0, 1.0)
			sfx_volume = clampf(sfx_volume, 0.0, 1.0)
			var saved: Variant = data.get("bindings", {})
			if saved is Dictionary:
				bindings = saved
	for action: String in bindings:
		_apply_binding(action)
	_apply()


## Changes a setting by name (see DEFAULTS).
func set_value(setting: String, value: Variant) -> void:
	set(setting, value)
	_apply()
	_save()
	changed.emit()


## Binds an action to a single key or mouse button, replacing what it had.
func rebind(action: String, event: InputEvent) -> void:
	bindings[action] = _events_to_data([event])
	_apply_binding(action)
	_save()
	changed.emit()


func reset_bindings() -> void:
	bindings.clear()
	for action: String in _defaults:
		_apply_binding(action)
	_save()
	changed.emit()


## How an action's first binding reads, e.g. "W", "Space", "Left mouse".
static func describe(action: String) -> String:
	if not InputMap.has_action(action):
		return "-"
	var names: PackedStringArray = []
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			# Show the key as labelled on this keyboard layout where possible.
			var code: Key = event.physical_keycode
			if DisplayServer.get_name() != "headless":
				code = DisplayServer.keyboard_get_keycode_from_physical(code)
			names.append(OS.get_keycode_string(code))
		elif event is InputEventMouseButton:
			names.append(["", "Left mouse", "Right mouse", "Middle mouse"][clampi(event.button_index, 0, 3)])
	return " / ".join(names) if not names.is_empty() else "unbound"


func _apply_binding(action: String) -> void:
	if not InputMap.has_action(action):
		return
	var events: Array = bindings.get(action, _defaults.get(action, []))
	InputMap.action_erase_events(action)
	for data: Dictionary in events:
		var event: InputEvent
		if data.has("mouse"):
			event = InputEventMouseButton.new()
			event.button_index = int(data["mouse"])
		else:
			event = InputEventKey.new()
			event.physical_keycode = int(data["key"]) as Key
		InputMap.action_add_event(action, event)


func _events_to_data(events: Array) -> Array:
	var result: Array = []
	for event: InputEvent in events:
		if event is InputEventKey:
			var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			result.append({"key": code})
		elif event is InputEventMouseButton:
			result.append({"mouse": event.button_index})
	return result


func _apply() -> void:
	_set_bus("Master", master_volume)
	_set_bus("Music", music_volume)
	_set_bus("SFX", sfx_volume)
	if not Engine.is_editor_hint() and DisplayServer.get_name() != "headless":
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)


func _save() -> void:
	var data := {"bindings": bindings}
	for setting: String in DEFAULTS:
		data[setting] = get(setting)
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))


func _set_bus(bus: String, volume: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	AudioServer.set_bus_mute(index, volume <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.001)))
