class_name PauseMenu
extends GameMenu
## The pause menu (Esc): Resume first and largest, then settings and save,
## and, set apart below a rule, saving and leaving for the title. Under
## them, when the game last reached the disk and whether a save worked.

var _status: Label


func _build() -> void:
	var title := UITheme.heading("Paused", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var world := UITheme.label("", 15, UITheme.DIM)
	world.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	world.name = "World"
	content.add_child(world)
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	content.add_child(buttons)
	var resume := UITheme.primary_button("Resume", _close, 320.0)
	resume.name = "Resume"
	buttons.add_child(resume)
	buttons.add_child(UITheme.button("Settings", func() -> void: _manager().open("settings"), 320.0))
	buttons.add_child(UITheme.button("Save now", _save, 320.0))
	var gap := Control.new()
	gap.custom_minimum_size.y = 6.0
	buttons.add_child(gap)
	buttons.add_child(UITheme.rule(320.0))
	buttons.add_child(UITheme.danger_button("Save & Quit to Title", _quit, 320.0))
	_status = UITheme.label("", 15, UITheme.DIM)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_status)


func refresh() -> void:
	var meta := SaveGame.get_section("meta")
	var played := SaveGame.play_seconds()
	var clock := ""
	var day_night := get_tree().root.find_child("DayNight", true, false)
	if day_night:
		var hours := fposmod(float(day_night.time) * 24.0, 24.0)
		clock = "  ·  Day %d, %02d:%02d" % [int(day_night.day), int(hours), int(fmod(hours, 1.0) * 60.0)]
	(content.get_node("World") as Label).text = "%s  ·  %s%s\nPlayed %d h %02d min  ·  Seed %s" % [meta.get("name", "World"), Difficulty.display_name(), clock,
		played / 3600, (played / 60) % 60, str(SaveGame.get_section("world").get("seed", "?"))]
	_show_saved()
	(content.find_child("Resume", true, false) as Button).grab_focus.call_deferred()


## "Last saved 2 minutes ago", or why the last save failed.
func _show_saved(just_now: bool = false) -> void:
	if SaveGame.last_error != "":
		_status.text = "Save failed: %s" % SaveGame.last_error
		_status.add_theme_color_override("font_color", UITheme.BAD)
		return
	_status.add_theme_color_override("font_color", UITheme.GOOD if just_now else UITheme.DIM)
	if not SaveGame.enabled:
		_status.text = "Saving is off in this session."
		return
	if SaveGame.last_saved_at <= 0.0:
		_status.text = "Not saved yet this session. The game saves itself every %d seconds." % roundi(SaveGame.AUTOSAVE_SECONDS)
		return
	var ago := roundi(Time.get_unix_time_from_system() - SaveGame.last_saved_at)
	var when := "just now" if ago < 5 else ("%d seconds ago" % ago if ago < 60 else ("%d minute%s ago" % [ago / 60, "" if ago / 60 == 1 else "s"]))
	_status.text = ("Saved. " if just_now else "") + "Last saved %s. Autosaves every %d seconds." % [when, roundi(SaveGame.AUTOSAVE_SECONDS)]


func _manager() -> Node:
	var node := get_parent()
	while node and not node.has_method("close"):
		node = node.get_parent()
	return node


func _close() -> void:
	close_menus(self)


## Finds the menu manager above a screen and closes it.
static func close_menus(from: Node) -> void:
	var node := from.get_parent()
	while node and not node.has_method("close"):
		node = node.get_parent()
	if node:
		node.close()


func _save() -> void:
	SaveGame.save_now()
	_show_saved(true)


## Saves and goes back to the title screen.
func _quit() -> void:
	SaveGame.save_now()
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
