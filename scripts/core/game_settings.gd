extends Node
## Player preferences (autoload "GameSettings"): sound, display, gameplay
## options, and key bindings. Kept in their own file so they are shared by
## every save.

signal changed
## The look of the world changed (a preset, shaders, fog...): redraw it.
signal graphics_changed

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
	"sprint_mode": "toggle",
	"controls_version": 0,
	"graphics_preset": "high",
	"world_detail": 2,
	"particles": 1.0,
	"shaders": "full",
	"lighting": 2,
	"weather_fx": 2,
	"grass_density": 1.0,
	"view_distance": 2,
	"bloom": false,
	"fog": true,
	"fps_limit": 0,
	"wing_display": "flight",
	"auto_junk": false,
	"pickup_radius": 1.0,
	"loot_filter": 0,
	"dps_meter": false,
	"quest_arrows": true,
	"colorblind": "off",
	"pause_unfocused": true,
	"enemy_info": true,
	"inner_voice": true,
	"remnants": true,
	"system_window": true,
	"touch_controls": "auto",
	"player_name": "",
}

## The four graphics presets. Each sets these; changing any one alone makes
## the preset "custom".
const PRESETS := {
	"low": {"world_detail": 0, "particles": 0.25, "shaders": "off", "lighting": 0, "weather_fx": 0, "grass_density": 0.25, "view_distance": 0},
	"normal": {"world_detail": 1, "particles": 0.5, "shaders": "basic", "lighting": 1, "weather_fx": 1, "grass_density": 0.5, "view_distance": 1},
	"high": {"world_detail": 2, "particles": 1.0, "shaders": "full", "lighting": 2, "weather_fx": 2, "grass_density": 1.0, "view_distance": 2},
	"ultra": {"world_detail": 3, "particles": 1.5, "shaders": "full", "lighting": 3, "weather_fx": 2, "grass_density": 1.5, "view_distance": 3},
}
const PRESET_KEYS: Array[String] = ["world_detail", "particles", "shaders", "lighting", "weather_fx", "grass_density", "view_distance"]
## Chunks loaded round the player, by view distance (Short .. Maximum).
const LOAD_RADIUS: Array[int] = [1, 2, 3, 4]
## How far out (world pixels) creatures and things keep moving, by view
## distance; past it they sleep until the player comes near.
const ACTIVE_RADIUS: Array[float] = [900.0, 1250.0, 1650.0, 2100.0]
## Raised whenever the default keys change, so old saved bindings are dropped
## once and everyone starts from the new layout.
const CONTROLS_VERSION := 2
## Actions players may rebind, in the order the Controls tab lists them.
const REBINDABLE: Array[Array] = [
	["move_up", "Move up"], ["move_down", "Move down"], ["move_left", "Move left"], ["move_right", "Move right"],
	["attack", "Attack / break / gather"], ["interact", "Interact / open / talk"], ["parry", "Parry"], ["dodge", "Dash"],
	["sprint", "Sprint"],
	["ability_1", "Ability 1"], ["ability_2", "Ability 2"], ["ability_3", "Ability 3"], ["ability_4", "Ability 4"],
	["ability_swap", "Switch ability set"], ["quick_use", "Quick-use potion or food"],
	["hotbar_1", "Hotbar 1"], ["hotbar_2", "Hotbar 2"], ["hotbar_3", "Hotbar 3"], ["hotbar_4", "Hotbar 4"], ["hotbar_5", "Hotbar 5"],
	["hotbar_6", "Hotbar 6"], ["hotbar_7", "Hotbar 7"], ["hotbar_8", "Hotbar 8"], ["hotbar_9", "Hotbar 9"], ["hotbar_10", "Hotbar 10"],
	["toggle_menu", "Menu wheel"], ["build_mode", "Build mode"], ["mount", "Mount / dismount"], ["recall_home", "Recall home"],
	["relic_ability", "Relic power"], ["toggle_flight", "Fly / land (once flight is won)"],
	["open_inventory", "Open inventory"], ["open_quests", "Open quest book"], ["open_map", "Open map"],
	["loadout_next", "Wear next saved set"],
	["photo_mode", "Photo mode (hide the interface)"], ["mark_junk", "Mark hovered item as junk"], ["lock_item", "Lock hovered item"],
	["release_aura", "Release your aura (scares weaker monsters)"], ["open_system", "Open the System window"], ["shadow_swap", "Swap places with a shadow"], ["raise_shadow", "Raise a fallen foe as a shadow"],
	["open_chat", "Chat (in a shared game)"],
	["auto_run", "Auto-run (walk on until you steer or stop)"], ["craft_again", "Craft the last recipe again"],
	["hotbar_back", "Back to the hotbar slot used before"],
]
## Actions the game adds itself when it starts (not in the project file):
## action -> default physical key (KEY_NONE for pad-only actions).
const EXTRA_ACTIONS := {"toggle_flight": KEY_T, "open_inventory": KEY_I, "open_quests": KEY_J, "open_map": KEY_N, "hotbar_prev": KEY_NONE, "hotbar_next": KEY_NONE, "loadout_next": KEY_L, "photo_mode": KEY_F10, "mark_junk": KEY_DELETE, "lock_item": KEY_K, "release_aura": KEY_U, "open_system": KEY_P, "shadow_swap": KEY_Y, "raise_shadow": KEY_E, "open_chat": KEY_ENTER, "auto_run": KEY_O, "craft_again": KEY_PERIOD, "hotbar_back": KEY_COMMA}
## Gamepad layout, kept alongside whatever keys are bound: action ->
## [JOY_BUTTON_*] or ["axis", JOY_AXIS_*, direction].
const PAD := {
	"move_left": ["axis", JOY_AXIS_LEFT_X, -1.0], "move_right": ["axis", JOY_AXIS_LEFT_X, 1.0],
	"move_up": ["axis", JOY_AXIS_LEFT_Y, -1.0], "move_down": ["axis", JOY_AXIS_LEFT_Y, 1.0],
	"attack": ["axis", JOY_AXIS_TRIGGER_RIGHT, 1.0], "parry": ["axis", JOY_AXIS_TRIGGER_LEFT, 1.0],
	"interact": [JOY_BUTTON_A], "dodge": [JOY_BUTTON_B], "sprint": [JOY_BUTTON_LEFT_STICK],
	"ability_1": [JOY_BUTTON_X], "ability_2": [JOY_BUTTON_Y], "ability_3": [JOY_BUTTON_LEFT_SHOULDER], "ability_4": [JOY_BUTTON_RIGHT_SHOULDER],
	"ability_swap": [JOY_BUTTON_RIGHT_STICK], "quick_use": [JOY_BUTTON_DPAD_DOWN], "open_inventory": [JOY_BUTTON_DPAD_UP],
	"hotbar_prev": [JOY_BUTTON_DPAD_LEFT], "hotbar_next": [JOY_BUTTON_DPAD_RIGHT],
	"toggle_menu": [JOY_BUTTON_START], "open_map": [JOY_BUTTON_BACK],
}
const PAD_NAMES := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y", JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3", JOY_BUTTON_START: "Start", JOY_BUTTON_BACK: "Back",
	JOY_BUTTON_DPAD_UP: "D-pad up", JOY_BUTTON_DPAD_DOWN: "D-pad down", JOY_BUTTON_DPAD_LEFT: "D-pad left", JOY_BUTTON_DPAD_RIGHT: "D-pad right",
}

## Emitted when play moves between keyboard and mouse and a gamepad, so
## key prompts can change.
signal device_changed
## True while the last input came from a gamepad.
var using_pad := false

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
## The sprint key: "toggle" (press to switch) or "hold" (sprint while held).
var sprint_mode := "toggle"
var controls_version := 0
var graphics_preset := "high"
## 0 Minimal, 1 Medium, 2 High, 3 Maximum: small things on the ground.
var world_detail := 2
## Share of particles drawn (0.25 .. 1.5).
var particles := 1.0
## "off", "basic" (ground and wind) or "full" (also haze, fog, glows).
var shaders := "full"
## 0 Simple, 1 Normal, 2 Enhanced, 3 Maximum.
var lighting := 2
## 0 Minimal, 1 Medium, 2 Full.
var weather_fx := 2
## Share of grass and flowers (0.25 .. 1.5).
var grass_density := 1.0
## 0 Short, 1 Medium, 2 Long, 3 Maximum.
var view_distance := 2
var bloom := false
var fog := true
## Frames a second at most (0: no limit).
var fps_limit := 0
## The wings of flight: shown "flight" (only while flying), "always" or "never".
var wing_display := "flight"
## Common gear picked up is marked as junk at once (sold with "Sell junk").
var auto_junk := false
## How far loot is drawn in to be picked up (0.5 .. 2 times the usual).
var pickup_radius := 1.0
## The lowest rarity of gear picked up by walking over it (0 = everything);
## lesser gear stays on the ground to be picked by hand.
var loot_filter := 0
## A small meter of damage dealt per second, over the last few seconds.
var dps_meter := false
## Arrows at the edge of the screen toward the tracked quest's goal.
var quest_arrows := true
## Attack warnings in colours told apart with colour blindness:
## "off", "deuteranopia", "protanopia" or "tritanopia".
var colorblind := "off"
## The game pauses when its window loses focus.
var pause_unfocused := true
## Hovering a monster shows its resistances, faction and what it expects.
var enemy_info := true
## The Still Voice: a quiet line now and then sizing up monsters and dangers.
var inner_voice := true
## Fallen monsters leave a remnant to devour (once the gift has woken).
var remnants := true
## The Pact: the Tenday Road and its messages.
var system_window := true
## On-screen controls for a phone or tablet: "auto" (on when the device is
## one), "on" or "off".
var touch_controls := "auto"
## The name other players see in a shared game.
var player_name := ""
## action -> saved events, each {"key": physical keycode} or {"mouse": button}.
var bindings: Dictionary = {}

## The contrast last applied to labels already built.
var _contrast_shown := false
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
			if EXTRA_ACTIONS[action] != KEY_NONE:
				var key := InputEventKey.new()
				key.physical_keycode = EXTRA_ACTIONS[action]
				InputMap.action_add_event(action, key)
	for action: String in PAD:
		_add_pad(action)
	# Menus answer the left stick as well as the D-pad.
	for entry: Array in [["ui_left", JOY_AXIS_LEFT_X, -1.0], ["ui_right", JOY_AXIS_LEFT_X, 1.0], ["ui_up", JOY_AXIS_LEFT_Y, -1.0], ["ui_down", JOY_AXIS_LEFT_Y, 1.0]]:
		var motion := InputEventJoypadMotion.new()
		motion.axis = entry[1]
		motion.axis_value = entry[2]
		if not InputMap.action_has_event(entry[0], motion):
			InputMap.action_add_event(entry[0], motion)
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
	if not touch_controls in ["auto", "on", "off"]:
		touch_controls = "auto"
	if not sprint_mode in ["toggle", "hold"]:
		sprint_mode = "toggle"
	if not shaders in ["off", "basic", "full"]:
		shaders = "full"
	world_detail = clampi(world_detail, 0, 3)
	lighting = clampi(lighting, 0, 3)
	weather_fx = clampi(weather_fx, 0, 2)
	view_distance = clampi(view_distance, 0, 3)
	particles = clampf(particles, 0.25, 1.5)
	grass_density = clampf(grass_density, 0.25, 1.5)
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
	if setting in PRESET_KEYS:
		graphics_preset = _matching_preset()
	_apply()
	_save()
	changed.emit()
	if setting in PRESET_KEYS or setting in ["fog", "bloom"]:
		graphics_changed.emit()


## Sets every graphics value from a preset ("low", "normal", "high", "ultra").
func apply_preset(preset: String) -> void:
	if not PRESETS.has(preset):
		return
	for key: String in PRESETS[preset]:
		set(key, PRESETS[preset][key])
	graphics_preset = preset
	_apply()
	_save()
	changed.emit()
	graphics_changed.emit()


func _matching_preset() -> String:
	for preset: String in PRESETS:
		var same := true
		for key: String in PRESETS[preset]:
			var want: Variant = PRESETS[preset][key]
			var have: Variant = get(key)
			if want is String:
				same = same and have == want
			else:
				same = same and is_equal_approx(float(have), float(want))
		if same:
			return preset
	return "custom"


# --- what the graphics settings mean to the things that draw

## How many of `amount` particles to make.
func particle_amount(amount: int) -> int:
	return maxi(1, roundi(amount * particles))


## 0: no decorative shaders, 1: ground and wind, 2: all.
func shader_level() -> int:
	return {"off": 0, "basic": 1, "full": 2}.get(shaders, 2)


func load_radius() -> int:
	return LOAD_RADIUS[view_distance]


func active_radius() -> float:
	return ACTIVE_RADIUS[view_distance]


## Share of weather particles drawn.
func weather_share() -> float:
	return [0.3, 0.65, 1.0][weather_fx] * clampf(particles, 0.5, 1.2)


## Share of small things (decals, critters, pebbles) on the ground.
func detail_share() -> float:
	return [0.3, 0.65, 1.0, 1.3][world_detail]


## Binds an action to a single key or mouse button, replacing what it had.
func rebind(action: String, event: InputEvent) -> void:
	bindings[action] = _events_to_data([event])
	_apply_binding(action)
	_save()
	changed.emit()


## Puts one action back to its default keys.
func reset_action(action: String) -> void:
	bindings.erase(action)
	_apply_binding(action)
	_save()
	changed.emit()


## Other rebindable actions that share a key or button with this one.
static func conflicts(action: String) -> Array[String]:
	var result: Array[String] = []
	if not InputMap.has_action(action):
		return result
	for entry in REBINDABLE:
		var other: String = entry[0]
		if other == action or not InputMap.has_action(other):
			continue
		for mine in InputMap.action_get_events(action):
			for theirs in InputMap.action_get_events(other):
				if _same(mine, theirs) and not result.has(other):
					result.append(other)
	return result


static func _same(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		return (a as InputEventKey).physical_keycode == (b as InputEventKey).physical_keycode
	if a is InputEventMouseButton and b is InputEventMouseButton:
		return (a as InputEventMouseButton).button_index == (b as InputEventMouseButton).button_index
	return false


static func action_name(action: String) -> String:
	for entry in REBINDABLE:
		if entry[0] == action:
			return entry[1]
	return action.capitalize()


func reset_bindings() -> void:
	bindings.clear()
	for action: String in _defaults:
		_apply_binding(action)
	_save()
	changed.emit()


## How an action's binding reads, e.g. "W", "Space", "Left mouse" (or,
## while a gamepad is in use, its button: "RT", "A").
static func describe(action: String) -> String:
	if not InputMap.has_action(action):
		return "-"
	if GameSettings.using_pad and pad_name(action) != "":
		return pad_name(action)
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


## Gives an action its gamepad input (see PAD), once.
func _add_pad(action: String) -> void:
	if not InputMap.has_action(action) or not PAD.has(action):
		return
	var entry: Array = PAD[action]
	var event: InputEvent
	if entry[0] is String:
		var motion := InputEventJoypadMotion.new()
		motion.axis = entry[1]
		motion.axis_value = entry[2]
		event = motion
	else:
		var button := InputEventJoypadButton.new()
		button.button_index = entry[0]
		event = button
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)


## The gamepad's name for an action's input ("RT", "A", "D-pad up"), or "".
static func pad_name(action: String) -> String:
	if not PAD.has(action):
		return ""
	var entry: Array = PAD[action]
	if entry[0] is String:
		match int(entry[1]):
			JOY_AXIS_TRIGGER_RIGHT:
				return "RT"
			JOY_AXIS_TRIGGER_LEFT:
				return "LT"
			_:
				return "Left stick"
	return PAD_NAMES.get(entry[0], "Pad %d" % entry[0])


func _input(event: InputEvent) -> void:
	var pad := event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.4)
	var desk := event is InputEventKey or event is InputEventMouseButton or (event is InputEventMouseMotion and (event as InputEventMouseMotion).relative.length() > 4.0)
	if pad and not using_pad:
		using_pad = true
		device_changed.emit()
	elif desk and using_pad:
		using_pad = false
		device_changed.emit()


func _apply_binding(action: String) -> void:
	if not InputMap.has_action(action):
		return
	var events: Array = bindings.get(action, _defaults.get(action, []))
	InputMap.action_erase_events(action)
	_add_pad(action)
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
		if _contrast_shown != high_contrast:
			_contrast_shown = high_contrast
			UITheme.refresh_contrast(get_tree())
	if not Engine.is_editor_hint() and DisplayServer.get_name() != "headless":
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = fps_limit


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
