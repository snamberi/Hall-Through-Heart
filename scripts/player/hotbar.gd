class_name Hotbar
extends Node
## The ten quick slots along the bottom of the screen.
##
##   1        your combat style (chosen in the Abilities screen)
##   2        your school of magic (taken up at an Altar of Magic)
##   3, 4     two weapons (staves too)
##   5, 6, 7  pickaxe, hatchet, fishing rod
##   8, 9     supplies: potions, salves, bandages, scrolls, torches and the
##            like (never food, blocks or furniture)
##   0        food: meals, drinks, treats and anything eaten
##
## Slots 1 to 7 are the belt (see Equipment): pressing the key takes that
## style, magic, weapon or tool in hand. Slots 8 to 10 remember an item id and use
## whichever stack of it is in the bag. Q uses the quick item, chosen by
## hovering something in the inventory and pressing Q.

signal changed

const SIZE := 10
const BELT_SIZE := 7
## What each slot is for, shown in empty slots and in hints.
const LABELS: Array[String] = ["Combat", "Magic", "Weapon", "Weapon", "Pickaxe", "Hatchet", "Rod", "Supply", "Supply", "Food"]
## The slot index that only takes food.
const FOOD_SLOT := 9
## Icon shown faintly in an empty slot.
const GHOST_ICONS: Array[int] = [38, 33, 0, 0, 49, 50, 51, 44, 44, 66]

## Item ids for slots 7, 8 and 9.
var slots: Array[String] = ["", "", ""]
## The item Q uses; "" falls back to the best healing potion.
var quick_id := ""

var _player: Player
## The belt slot held before the one in hand, for the hotbar-back key.
var _previous := -1


func _ready() -> void:
	_player = get_parent()
	SaveGame.register("hotbar", self)
	_player.equipment.changed.connect(func() -> void: changed.emit())
	_player.inventory.changed.connect(func() -> void: changed.emit())


## The belt slot behind a hotbar index, or "" for the item slots.
static func belt_slot(index: int) -> String:
	return Equipment.BELT[index] if index >= 0 and index < BELT_SIZE else ""


## Puts something in a slot: equips a weapon or tool onto the belt, or
## remembers a usable item for slots 7 to 9. Returns "" or why not.
func assign(index: int, item: Item) -> String:
	if index < 0 or index >= SIZE or item == null:
		return ""
	if index < BELT_SIZE:
		var slot := belt_slot(index)
		if index < 2:
			return "Slot %d holds your %s, not items." % [index + 1, "combat style" if index == 0 else "school of magic"]
		if not _player.equipment.fits(item, slot):
			return "Slot %d is for a %s." % [index + 1, LABELS[index].to_lower()]
		if _player.equipment.slot_of(item) == slot:
			return ""
		return _player.equipment.equip(item, slot)
	var problem := slot_problem(index, item.id)
	if problem != "":
		return problem
	# An item sits in one slot only.
	for other in slots.size():
		if slots[other] == item.id:
			slots[other] = ""
	slots[index - BELT_SIZE] = item.id
	changed.emit()
	SaveGame.request_save()
	return ""


## Food: anything eaten or drunk (cooked meals, drinks, treats, berries,
## raw fish and meat).
static func is_food(item_id: String) -> bool:
	if ItemDB.course_of(item_id) != "":
		return true
	var item := Item.create(item_id)
	return item.is_consumable() and ItemText.type_name(item) in ["Food", "Raw food"]


## Supplies: what is used up from the bag that is not food (potions,
## salves, bandages, scrolls, treats for pets, whistles), and whatever is
## set down (torches, crafting tables, chests, walls).
static func is_supply(item_id: String) -> bool:
	if not ItemDB.ITEMS.has(item_id) or is_food(item_id):
		return false
	var item := Item.create(item_id)
	if item.is_placeable():
		# Torches, tables, chests, walls: anything set down from the belt.
		return true
	return item.is_consumable() and Crops.by_seed(item_id) == ""


## Why an item cannot go in an item slot (7..9), or "".
static func slot_problem(index: int, item_id: String) -> String:
	if index == FOOD_SLOT:
		return "" if is_food(item_id) else "Slot 0 is for food: meals, drinks and treats."
	return "" if is_supply(item_id) else ("Food goes in slot 0." if is_food(item_id) else "Slots 8 and 9 are for supplies: potions, bandages, scrolls, torches and things to set down.")


func set_quick(item: Item) -> String:
	if not (item.is_consumable() or item.is_placeable()):
		return "Only things you can use can be the quick item."
	quick_id = item.id
	changed.emit()
	SaveGame.request_save()
	return ""


## The id remembered in a slot ("" for belt slots and empty ones).
func id_in(index: int) -> String:
	return slots[index - BELT_SIZE] if index >= BELT_SIZE and index < SIZE else ""


func item_in(index: int) -> Item:
	if index < BELT_SIZE:
		return _player.equipment.equipped.get(belt_slot(index))
	return _stack(id_in(index))


func count_in(index: int) -> int:
	var id := id_in(index)
	return _player.inventory.count_of(id) if id != "" else 0


func quick_item() -> Item:
	return _stack(quick_id)


## Whether a slot is the one in hand.
func is_active(index: int) -> bool:
	if index < 2:
		return _player.equipment.active_slot == belt_slot(index) and _player.equipment.working_tool == null
	return index < BELT_SIZE and _player.equipment.active_slot == belt_slot(index) and _player.equipment.equipped.has(belt_slot(index))


## The picture for the style and magic slots (they hold no item).
func hand_icon(index: int) -> Texture2D:
	if index == 0:
		return CombatStyles.icon(_player.styles.equipped if _player.styles else "fist")
	if index == 1 and _player.magic_school != "":
		return ItemDB.icon(MagicDB.SCHOOLS[_player.magic_school]["icon"])
	return null


## What the style and magic slots are called right now.
func hand_name(index: int) -> String:
	if index == 0:
		return CombatStyles.STYLES[_player.styles.equipped]["name"] if _player.styles else "Brawler's Fists"
	if index == 1:
		return MagicDB.SCHOOLS[_player.magic_school]["name"] if _player.magic_school != "" else "No magic yet"
	return ""


## Uses what is in a slot. Returns "" or why not.
func activate(index: int) -> String:
	if index == 1 and _player.magic_school == "":
		return "Take up a school of magic at an Altar of Magic first."
	if index < BELT_SIZE:
		var was := _active_index()
		if not _player.equipment.select(belt_slot(index)):
			return "No %s on your belt." % LABELS[index].to_lower()
		if was >= 0 and was != index:
			_previous = was
		Audio.play("swing", -12.0, 0.2)
		return ""
	var item := item_in(index)
	if item == null:
		return "Nothing in that slot." if id_in(index) == "" else "None left."
	return _player.use_item(item)


## Q: the chosen quick item, or the best healing potion if none is chosen.
func use_quick() -> String:
	if quick_id == "":
		_player.quick_potion()
		return ""
	var item := quick_item()
	if item == null:
		return "No %s left." % ItemDB.ITEMS[quick_id]["name"]
	return _player.use_item(item)


## The slot in hand now, or -1.
func _active_index() -> int:
	for index in BELT_SIZE:
		if is_active(index):
			return index
	return -1


func _stack(id: String) -> Item:
	if id == "":
		return null
	for item in _player.inventory.items:
		if item and item.id == id:
			return item
	return null


func _unhandled_input(event: InputEvent) -> void:
	if _player.is_dead() or get_tree().paused:
		return
	# The D-pad steps through what can be held: arms and tools.
	for step: Array in [["hotbar_prev", -1], ["hotbar_next", 1]]:
		if event.is_action_pressed(step[0]):
			_cycle(step[1])
			get_viewport().set_input_as_handled()
			return
	# The last recipe once more, wherever you are (if it can be made here).
	if InputMap.has_action("craft_again") and event.is_action_pressed("craft_again"):
		var said := "Nothing crafted yet."
		if Crafting.last_recipe != "":
			var recipe := RecipeDB.find(Crafting.last_recipe)
			# With Shift held: up to five at once.
			var times := 5 if Input.is_key_pressed(KEY_SHIFT) else 1
			var made := 0
			if not recipe.is_empty():
				for i in times:
					said = Crafting.craft(_player, recipe)
					if said != "":
						break
					made += 1
			if made > 0:
				said = "Made %d more %s" % [made, RecipeDB.display_name(recipe)] if made > 1 else "Made another %s" % RecipeDB.display_name(recipe)
		DamageNumber.spawn_text(_player.get_parent(), _player.global_position + Vector2(0, -50), said, UITheme.DIM, 13)
		get_viewport().set_input_as_handled()
		return
	# Back to what was in hand before (the hotbar-back key).
	if InputMap.has_action("hotbar_back") and event.is_action_pressed("hotbar_back"):
		if _previous >= 0:
			var problem := activate(_previous)
			if problem != "":
				DamageNumber.spawn_text(_player.get_parent(), _player.global_position + Vector2(0, -50), problem, UITheme.BAD, 13)
		get_viewport().set_input_as_handled()
		return
	for index in SIZE:
		if event.is_action_pressed("hotbar_%d" % (index + 1)):
			var problem := activate(index)
			if problem != "":
				DamageNumber.spawn_text(_player.get_parent(), _player.global_position + Vector2(0, -50), problem, UITheme.BAD, 13)
			get_viewport().set_input_as_handled()
			return


## Takes the next (or previous) slot that holds something to hold.
func _cycle(direction: int) -> void:
	var holdable: Array[int] = []
	for index in range(0, BELT_SIZE):
		if hand_icon(index) != null or item_in(index) != null:
			holdable.append(index)
	if holdable.is_empty():
		return
	var current := -1
	for index in holdable:
		if is_active(index):
			current = holdable.find(index)
	var next: int = holdable[posmod(current + direction, holdable.size())] if current >= 0 else holdable[0]
	var problem := activate(next)
	if problem != "":
		DamageNumber.spawn_text(_player.get_parent(), _player.global_position + Vector2(0, -50), problem, UITheme.BAD, 13)


func save_data() -> Dictionary:
	return {"items": slots.duplicate(), "quick": quick_id}


func load_data(data: Dictionary) -> void:
	slots = ["", "", ""]
	var usable := func(id: String) -> bool:
		return ItemDB.ITEMS.has(id) and not ItemDB.ITEMS[id].has("slot") and not ItemDB.ITEMS[id].has("tool")
	var saved: Variant = data.get("items")
	if saved is Array:
		for index in mini(saved.size(), 3):
			var id := str(saved[index])
			# Anything saved in a slot that no longer takes it is let go.
			slots[index] = id if usable.call(id) and slot_problem(index + BELT_SIZE, id) == "" else ""
	elif data.get("slots") is Array:
		# The old five-slot bar: keep its first three usable things.
		var next := 0
		for entry: Variant in data["slots"]:
			if next < 3 and usable.call(str(entry)):
				slots[next] = str(entry)
				next += 1
	quick_id = str(data.get("quick", ""))
	if not ItemDB.ITEMS.has(quick_id):
		quick_id = ""
	changed.emit()
