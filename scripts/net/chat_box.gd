class_name ChatBox
extends CanvasLayer
## Talking in a shared game: the last few lines at the lower left, fading
## after a while; Enter (or the Chat button by touch) opens a line to type
## in, Enter sends it, Esc puts it away. Joins, leaves and party news show
## here too, in grey.

## True while a message is being typed, so the keys do not also walk.
static var typing := false

const SHOWN := 8
const FADE_AFTER := 12.0

var _lines: Array = []
var _list: VBoxContainer
var _field: LineEdit
var _panel: PanelContainer


func _ready() -> void:
	layer = 17
	process_mode = Node.PROCESS_MODE_ALWAYS
	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.theme = UITheme.get_theme()
	add_child(holder)
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_panel.position = Vector2(12, 0)
	_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	holder.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(box)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 1)
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_list)
	_field = LineEdit.new()
	_field.custom_minimum_size = Vector2(380, 32)
	_field.placeholder_text = "Say something (Enter sends, Esc closes)"
	_field.max_length = 200
	_field.visible = false
	_field.text_submitted.connect(_send)
	_field.focus_exited.connect(func() -> void: _close())
	box.add_child(_field)
	Net.chat_received.connect(add_line)
	get_viewport().size_changed.connect(_place)
	_place()


func _exit_tree() -> void:
	typing = false


func _place() -> void:
	var view := get_viewport().get_visible_rect().size
	_panel.position = Vector2(12.0, roundf(view.y * 0.62 - _panel.size.y))


## Adds a line: "Name: text" in the speaker's colour, or a plain notice.
func add_line(from_name: String, text: String, colour: Color) -> void:
	var line := RichTextLabel.new()
	line.bbcode_enabled = true
	line.fit_content = true
	line.scroll_active = false
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size.x = 380.0
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_font_size_override("normal_font_size", 14)
	line.add_theme_constant_override("outline_size", 4)
	line.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.05, 0.95))
	var safe := text.replace("[", "[lb]")
	if from_name == "":
		line.text = "[color=#%s]%s[/color]" % [colour.to_html(false), safe]
	else:
		line.text = "[color=#%s]%s:[/color] [color=#%s]%s[/color]" % [colour.to_html(false), from_name.replace("[", "[lb]"), UITheme.TEXT.to_html(false), safe]
	_list.add_child(line)
	_lines.append([line, Time.get_ticks_msec() / 1000.0])
	while _lines.size() > SHOWN:
		(_lines.pop_front()[0] as Node).queue_free()
	_place.call_deferred()


func open() -> void:
	if not Net.online():
		return
	_field.visible = true
	_field.text = ""
	_field.grab_focus()
	typing = true
	_show_all()


func _close() -> void:
	_field.visible = false
	_field.release_focus()
	typing = false


func _send(text: String) -> void:
	Net.say(text)
	_close()


func _show_all() -> void:
	for entry: Array in _lines:
		(entry[0] as CanvasItem).modulate.a = 1.0


func _unhandled_input(event: InputEvent) -> void:
	if not Net.online():
		return
	if event.is_action_pressed("open_chat") and not typing:
		open()
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if typing and event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if typing:
		return
	var now := Time.get_ticks_msec() / 1000.0
	for entry: Array in _lines:
		var age := now - float(entry[1])
		(entry[0] as CanvasItem).modulate.a = clampf(1.0 - (age - FADE_AFTER) / 2.0, 0.0, 1.0)
