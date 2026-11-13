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
	"ui_scale": 1.0,
	"text_scale": 1.0,
	"hud_layout": "compact",
	"show_worn": false,
	"tracker_mode": "full",
	"shake_strength": 1.0,
	"damage_number_size": 1.0,
	"high_contrast": false,
	"reduce_flashes": false,
	"controls_version": 0,
}
## Raised whenever the default keys change, so old saved bindings are dropped
## once and everyone starts from the new layout.
const CONTROLS_VERSION := 2
## Actions players may rebind, in the order the Controls tab lists them.
const REBINDABLE: Array[Array] = [
	["move_up", "Move up"], ["move_down", "Move down"], ["move_left", "Move left"], ["move_right", "Move right"],
	["attack", "Attack / break / gather"], ["interact", "Interact / open / talk"], ["parry", "Parry"], ["dodge", "Dash"],
	["sprint", "Sprint on / off"],
	["ability_1", "Ability 1"], ["ability_2", "Ability 2"], ["ability_3", "Ability 3"], ["ability_4", "Ability 4"],
	["ability_swap", "Switch ability set"], ["quick_use", "Quick-use potion or food"],
	["hotbar_1", "Hotbar 1"], ["hotbar_2", "Hotbar 2"], ["hotbar_3", "Hotbar 3"], ["hotbar_4", "Hotbar 4"], ["hotbar_5", "Hotbar 5"],
	["hotbar_6", "Hotbar 6"], ["hotbar_7", "Hotbar 7"], ["hotbar_8", "Hotbar 8"], ["hotbar_9", "Hotbar 9"], ["hotbar_10", "Hotbar 10"],
	["toggle_menu", "Menu wheel"], ["build_mode", "Build mode"], ["mount", "Mount / dismount"], ["recall_home", "Recall home"],
	["relic_ability", "Relic power"],
	["open_inventory", "Open inventory"], ["open_quests", "Open quest book"], ["open_map", "Open map"],
]
## Actions the game adds itself when it starts (not in the project file):
## action -> default physical key.
const EXTRA_ACTIONS := {"open_inventory": KEY_I, "open_quests": KEY_J, "open_map": KEY_N}

var master_volume := 1.0
var music_volume := 0.6
var sfx_volume := 0.8
var show_minimap := true
var fullscreen := false
var vsync := true
var screen_shake := true
var damage_numbers := true
var last_slot := ""
## Size of everything on screen that is not the world itself.
var ui_scale := 1.0
## Size of text alone, on top of the interface size (0.9 to 1.25).
var text_scale := 1.0
## Where the ability slots sit: "compact" (a dock by the hotbar) or
## "classic" (a column on the left).
var hud_layout := "compact"
## Whether the hotbar also shows the armour worn.
var show_worn := false
## The quest tracker: "full" (objectives listed), "compact" (titles with a
## count) or "off".
var tracker_mode := "full"
## Comfort: how hard the camera shakes (0 to 1.5), how large damage numbers
## are, stronger interface contrast, and softer flashes.
var shake_strength := 1.0
var damage_number_size := 1.0
var high_contrast := false
var reduce_flashes := false
var controls_version := 0
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
	for action: String in EXTRA_ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var key := InputEventKey.new()
			key.physical_keycode = EXTRA_ACTIONS[action]
			InputMap.action_add_event(action, key)
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
	ui_scale = clampf(ui_scale, 0.7, 1.3)
	text_scale = clampf(text_scale, 0.9, 1.25)
	shake_strength = clampf(shake_strength, 0.0, 1.5)
	damage_number_size = clampf(damage_number_size, 0.7, 1.6)
	if not hud_layout in ["compact", "classic"]:
		hud_layout = "compact"
	if not tracker_mode in ["full", "compact", "off"]:
		tracker_mode = "full"
	if controls_version < CONTROLS_VERSION:
		# The key layout changed: drop bindings saved for the old one.
		bindings.clear()
		controls_version = CONTROLS_VERSION
		_save()
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
	if is_inside_tree():
		# The world's camera divides this back out, so only the interface changes size.
		get_tree().root.content_scale_factor = ui_scale
		if not is_equal_approx(UITheme.text_scale, text_scale):
			UITheme.set_text_scale(get_tree(), text_scale)
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
