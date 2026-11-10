class_name ClassMenu
extends GameMenu
## Shows the player's class and lets them choose one at level 10.

var _title: Label
var _note: Label
var _cards: Dictionary[String, Dictionary] = {}
var _message: Label


func _build() -> void:
	_title = UITheme.heading("", 28)
	content.add_child(_title)
	_note = UITheme.label("", 15, UITheme.DIM)
	content.add_child(_note)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	content.add_child(grid)
	for id in HeroClasses.CHOICES:
		var data: Dictionary = HeroClasses.CLASSES[id]
		var card := UITheme.inset_panel()
		card.custom_minimum_size = Vector2(340.0, 0.0)
		grid.add_child(card)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 5)
		card.add_child(box)

		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 8)
		head.add_child(UITheme.icon(data["icon"], 26.0))
		var name_label := UITheme.heading(data["name"], 20)
		head.add_child(name_label)
		box.add_child(head)
		var text := UITheme.label(data["text"], 13, UITheme.DIM)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD
		text.custom_minimum_size = Vector2(300.0, 36.0)
		box.add_child(text)
		var bonuses := UITheme.label(",  ".join(HeroClasses.describe_bonuses(id)), 13, UITheme.GOOD)
		bonuses.autowrap_mode = TextServer.AUTOWRAP_WORD
		bonuses.custom_minimum_size = Vector2(300.0, 58.0)
		box.add_child(bonuses)
		var abilities: PackedStringArray = []
		for ability_id: String in data["abilities"]:
			var ability: Dictionary = AbilityDB.ABILITIES[ability_id]
			abilities.append("Lv %d %s" % [ability["level"], ability["name"]])
		box.add_child(UITheme.label("     ".join(abilities), 13, UITheme.INFO))
		var button := UITheme.button("Choose", _choose.bind(id), 120.0)
		button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		box.add_child(button)
		_cards[id] = {"card": card, "button": button, "name": name_label}

	_message = UITheme.label("", 14, UITheme.BAD)
	content.add_child(_message)
	player.class_changed.connect(refresh_if_open)


func refresh() -> void:
	var current := player.class_id
	var level := player.leveling.level
	_title.text = "Class:  %s" % HeroClasses.CLASSES[current]["name"]
	if level < HeroClasses.CHOICE_LEVEL:
		_note.text = "Reach level %d to choose a class. You are level %d." % [HeroClasses.CHOICE_LEVEL, level]
	elif current == "adventurer":
		_note.text = "Choose your path. Class abilities fill ability slots 3 and 4."
	else:
		_note.text = "Changing class costs %d gold (you have %d). Later advancements are not in the game yet." % [player.class_change_cost(), player.inventory.gold]
	for id in _cards:
		var button: Button = _cards[id]["button"]
		button.disabled = level < HeroClasses.CHOICE_LEVEL or id == current
		button.text = "Current" if id == current else "Choose" if current == "adventurer" else "Change"
		(_cards[id]["name"] as Label).add_theme_color_override("font_color", UITheme.GOLD if id == current else UITheme.HEADING)


func _choose(id: String) -> void:
	_message.text = player.choose_class(id)
	refresh()
