class_name Relics
extends Node
## The relic bag (up to RelicDB.BAG_SIZE relics) and the relics worn: one,
## or more with a good belt. Worn relics' boons go into the player's
## stats; the relic in focus lends its ability to the relic key (G).

signal changed

var bag: Array[Item] = []
var worn: Array[Item] = []
## Which worn relic the relic key uses.
var focus := 0
## ability id -> seconds left.
var cooldowns: Dictionary = {}
var _player: Player


func _ready() -> void:
	_player = get_parent()
	SaveGame.register("relics", self)
	_player.equipment.changed.connect(_fit_to_belt)


func slots() -> int:
	return _player.equipment.relic_slots()


## Puts a relic in the bag. Returns "" or why not.
func store(item: Item) -> String:
	if item == null or not item.is_relic():
		return "That is not a relic."
	if bag.size() >= RelicDB.BAG_SIZE:
		return "The relic bag is full (%d)." % RelicDB.BAG_SIZE
	if item in _player.inventory.items:
		_player.inventory.remove(item)
	bag.append(item)
	_changed()
	return ""


## Wears a relic from the bag, in the first free place (or swapping out
## the one in focus). Returns "" or why not.
func wear(item: Item) -> String:
	if not item in bag:
		return ""
	for other: Item in worn:
		if other.definition()["relic"] == item.definition()["relic"]:
			return "You already wear a %s." % other.display_name()
	if worn.size() >= slots():
		var old := worn[mini(focus, worn.size() - 1)]
		worn.erase(old)
		bag.append(old)
	bag.erase(item)
	worn.append(item)
	focus = worn.size() - 1
	_changed()
	Audio.play("level_up", -12.0, 0.2)
	return ""


func take_off(item: Item) -> String:
	if not item in worn:
		return ""
	if bag.size() >= RelicDB.BAG_SIZE:
		return "The relic bag is full."
	worn.erase(item)
	bag.append(item)
	focus = clampi(focus, 0, maxi(worn.size() - 1, 0))
	_changed()
	return ""


func discard(item: Item) -> void:
	bag.erase(item)
	worn.erase(item)
	_changed()


func set_focus(index: int) -> void:
	focus = clampi(index, 0, maxi(worn.size() - 1, 0))
	changed.emit()


func focused() -> Item:
	return worn[focus] if focus < worn.size() else null


func ability_of(item: Item) -> Dictionary:
	return RelicDB.RELICS[item.definition()["relic"]]["ability"] if item else {}


func cooldown_left(item: Item) -> float:
	return float(cooldowns.get(ability_of(item).get("id", ""), 0.0)) if item else 0.0


func _physics_process(delta: float) -> void:
	for id: String in cooldowns.keys():
		cooldowns[id] = maxf(float(cooldowns[id]) - delta, 0.0)
	if Input.is_action_just_pressed("relic_ability") and not get_tree().paused:
		var problem := use_focused()
		if problem != "":
			DamageNumber.spawn_text(_player.get_parent(), _player.global_position + Vector2(0, -50), problem, UITheme.BAD, 12)


## Uses the focused relic's ability. Returns "" or why not.
func use_focused() -> String:
	var item := focused()
	if item == null:
		return "No relic worn."
	if _player.is_dead():
		return ""
	var ability := ability_of(item)
	if cooldown_left(item) > 0.0:
		return "%s in %ds" % [ability["name"], ceili(cooldown_left(item))]
	var problem := RelicPowers.use(ability["id"], _player, item.rarity)
	if problem == "":
		cooldowns[ability["id"]] = float(ability["cooldown"])
		Events.codex_event.emit("relic_powers", 1)
	return problem


## When a belt comes off, relics beyond the new limit go back in the bag.
func _fit_to_belt() -> void:
	var changed_any := false
	while worn.size() > slots():
		var item: Item = worn.pop_back()
		bag.append(item)
		changed_any = true
	if changed_any:
		focus = clampi(focus, 0, maxi(worn.size() - 1, 0))
		_changed()


func _changed() -> void:
	var total := {}
	for item: Item in worn:
		var mods := RelicDB.mods_at(item.definition()["relic"], item.rarity)
		for stat: String in mods:
			if not total.has(stat):
				total[stat] = {}
			for kind: String in mods[stat]:
				total[stat][kind] = float(total[stat].get(kind, 0.0)) + float(mods[stat][kind])
	_player.stats.set_modifiers("relics", total)
	changed.emit()
	SaveGame.request_save()


func save_data() -> Dictionary:
	return {"bag": bag.map(func(item: Item) -> Dictionary: return item.to_dict()),
		"worn": worn.map(func(item: Item) -> Dictionary: return item.to_dict()), "focus": focus, "cooldowns": cooldowns.duplicate()}


func load_data(data: Dictionary) -> void:
	bag.clear()
	worn.clear()
	for saved: Variant in data.get("bag", []):
		var item := Item.from_dict(saved)
		if item:
			bag.append(item)
	for saved: Variant in data.get("worn", []):
		var item := Item.from_dict(saved)
		if item:
			worn.append(item)
	focus = int(data.get("focus", 0))
	var saved_cooldowns: Variant = data.get("cooldowns", {})
	cooldowns = saved_cooldowns if saved_cooldowns is Dictionary else {}
	_changed()
