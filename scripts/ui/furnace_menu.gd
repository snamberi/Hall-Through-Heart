class_name FurnaceMenu
extends GameMenu
## A furnace: the ore inside and the coal burning it, how far the ore in
## the fire has got, and the ingots made. Put in a kind of ore and coal
## from the bag; take the ingots when they are done.

var record: Dictionary
var _ore: Label
var _fuel: Label
var _bar: ProgressBar
var _output: Label
var _choices: VBoxContainer
var _message: Label
var _shown := 0.0


func _build() -> void:
	var title := UITheme.heading("FURNACE", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var note := UITheme.label("One ore makes one ingot of the same rarity. Each lump of coal smelts eight ores. It keeps burning while you are away, at half pace.", 13, UITheme.DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD
	note.custom_minimum_size = Vector2(640, 0)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(note)
	var panel := UITheme.inset_panel()
	content.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	_ore = UITheme.label("", 16, UITheme.TEXT)
	box.add_child(_ore)
	_fuel = UITheme.label("", 15, UITheme.TEXT)
	box.add_child(_fuel)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(620, 14)
	_bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(1.0, 0.55, 0.2)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.06, 0.05, 0.05)
	_bar.add_theme_stylebox_override("fill", fill)
	_bar.add_theme_stylebox_override("background", back)
	box.add_child(_bar)
	_output = UITheme.label("", 16, UITheme.GOLD)
	box.add_child(_output)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(buttons)
	buttons.add_child(UITheme.button("Add all coal", _add_coal, 180.0))
	buttons.add_child(UITheme.button("Take the ingots", _take_ingots, 200.0))
	buttons.add_child(UITheme.button("Take back the ore", _take_ore, 200.0))
	content.add_child(UITheme.heading("Put in ore", 16))
	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 4)
	content.add_child(_choices)
	_message = UITheme.label("", 14, UITheme.BAD)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_message)


func _process(_delta: float) -> void:
	if is_visible_in_tree() and not record.is_empty():
		_show()


func refresh() -> void:
	_message.text = ""
	_show()
	for child in _choices.get_children():
		child.queue_free()
	var seen := {}
	for item in player.inventory.items:
		if item == null or not Furnace.SMELTS.has(item.id):
			continue
		var key := "%s:%d" % [item.id, item.rarity]
		if seen.has(key):
			continue
		seen[key] = true
		var count := 0
		for other in player.inventory.items:
			if other and other.id == item.id and other.rarity == item.rarity:
				count += other.count
		var button := UITheme.button("%s  (%s)  x%d" % [item.display_name(), ItemDB.RARITIES[item.rarity]["name"], count], _put_ore.bind(item.id, item.rarity), 420.0)
		button.icon = item.icon()
		button.add_theme_color_override("font_color", item.color())
		_choices.add_child(button)
	if seen.is_empty():
		_choices.add_child(UITheme.label("No ore in your bag. Mine copper, iron, silver and the rest.", 13, UITheme.DIM))


func _show() -> void:
	var ore := Furnace.ore_in(record)
	if int(ore["count"]) > 0:
		var name: String = ItemDB.ITEMS[ore["id"]]["name"]
		_ore.text = "In the fire: %s x%d  (%s)" % [name, ore["count"], ItemDB.RARITIES[int(ore["rarity"])]["name"]]
		_bar.max_value = Furnace.smelt_seconds(ore["id"])
		_bar.value = float(record.get("progress", 0.0))
	else:
		_ore.text = "The fire is empty."
		_bar.value = 0.0
	var coal := int(record.get("coal", 0))
	var burns := int(record.get("burns", 0))
	_fuel.text = "Coal: %d lump%s waiting%s" % [coal, "" if coal == 1 else "s", ",  %d more ore%s on the one burning" % [burns, "" if burns == 1 else "s"] if burns > 0 else ""]
	if int(ore["count"]) > 0 and coal == 0 and burns == 0:
		_fuel.text += "   -  needs coal to burn"
	var made := 0
	for saved: Dictionary in record.get("items", []):
		made += int(saved.get("count", 1))
	_output.text = "Ingots ready: %d" % made


func _put_ore(ore_id: String, rarity: int) -> void:
	var ore := Furnace.ore_in(record)
	if int(ore["count"]) > 0 and (ore["id"] != ore_id or int(ore["rarity"]) != rarity):
		_message.text = "Finish or take back the ore already in the fire first."
		return
	var count := 0
	for item in player.inventory.items.duplicate():
		if item and item.id == ore_id and item.rarity == rarity:
			count += item.count
			player.inventory.remove(item)
	ore["id"] = ore_id
	ore["rarity"] = rarity
	ore["count"] = int(ore["count"]) + count
	SaveGame.request_save()
	refresh()


func _add_coal() -> void:
	var count := player.inventory.count_of("coal")
	if count == 0:
		_message.text = "You have no coal. Mine a coal seam, or burn wood into coal at a crafting table."
		return
	player.inventory.take("coal", count)
	record["coal"] = int(record.get("coal", 0)) + count
	SaveGame.request_save()
	refresh()


func _take_ingots() -> void:
	var items: Array = record.get("items", [])
	for saved: Dictionary in items.duplicate():
		var item := Item.from_dict(saved)
		if item and player.inventory.add(item):
			items.erase(saved)
		else:
			_message.text = "Your bag is full."
			break
	SaveGame.request_save()
	refresh()


func _take_ore() -> void:
	var ore := Furnace.ore_in(record)
	if int(ore["count"]) <= 0:
		return
	var item := Item.create(ore["id"], int(ore["count"]))
	item.rarity = int(ore["rarity"])
	if player.inventory.add(item):
		ore["count"] = 0
		ore["id"] = ""
		record["progress"] = 0.0
	else:
		_message.text = "Your bag is full."
	SaveGame.request_save()
	refresh()
