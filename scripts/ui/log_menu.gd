class_name LogMenu
extends GameMenu
## The Log: everything said to you and everything that happened, newest
## first, by day and hour, with filters and a search.

var _list: VBoxContainer
var _search: LineEdit
var _filter := "all"
var _filters: Dictionary = {}


func _build() -> void:
	var title := UITheme.heading("LOG", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	content.add_child(row)
	_search = UITheme.search_box("Search the log", 240.0, refresh)
	row.add_child(_search)
	for entry: Array in [["all", "All"]] + Chronicle.KINDS.keys().map(func(key: String) -> Array: return [key, Chronicle.KINDS[key]]):
		var button := UITheme.button(entry[1], func() -> void:
			_filter = entry[0]
			refresh()
		, 100.0)
		button.toggle_mode = true
		row.add_child(button)
		_filters[entry[0]] = button
	var panel := UITheme.inset_panel()
	content.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(900, 440)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_list)


func refresh() -> void:
	for id: String in _filters:
		_filters[id].set_pressed_no_signal(id == _filter)
	for child in _list.get_children():
		child.queue_free()
	var chronicle: Chronicle = player.get_parent().get_node_or_null("Chronicle")
	if chronicle == null:
		return
	var words := _search.text.strip_edges().to_lower()
	var shown := 0
	var last_day := -1
	for index in range(chronicle.entries.size() - 1, -1, -1):
		var entry: Array = chronicle.entries[index]
		if _filter != "all" and entry[2] != _filter:
			continue
		if words != "" and not (str(entry[4]).to_lower().contains(words) or str(entry[3]).to_lower().contains(words)):
			continue
		if int(entry[0]) != last_day:
			last_day = int(entry[0])
			_list.add_child(UITheme.heading("Day %d" % last_day, 16))
		var line := RichTextLabel.new()
		line.bbcode_enabled = true
		line.fit_content = true
		line.scroll_active = false
		line.custom_minimum_size = Vector2(870, 0)
		UITheme.font_size(line, 14, "normal_font_size")
		var colour: Color = {"speech": UITheme.TEXT, "event": UITheme.HEADING, "fight": Color(0.95, 0.55, 0.5), "quest": UITheme.GOOD}.get(entry[2], UITheme.TEXT)
		var who := "[color=#%s]%s:[/color] " % [UITheme.GOLD.to_html(false), entry[3]] if str(entry[3]) != "" else ""
		line.text = "[color=#%s]%s[/color]   %s[color=#%s]%s[/color]" % [UITheme.DIM.to_html(false), entry[1], who, colour.to_html(false), str(entry[4]).replace("[", "(")]
		_list.add_child(line)
		shown += 1
		if shown >= 200:
			break
	if shown == 0:
		_list.add_child(UITheme.label("Nothing here yet." if words == "" else "Nothing matches.", 15, UITheme.DIM))
