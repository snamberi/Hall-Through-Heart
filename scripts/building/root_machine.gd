class_name RootMachine
extends Node2D
## Root-tech: a living stump whose roots do the work. Every so often it
## sends a root creeping across the ground to the nearest tree, ore vein
## or herb (the Tender also waters, harvests and replants farm plots),
## worries at it until it gives, and draws what it yields back home. The
## harvest goes into a Root Hollow nearby if there is one with room, or
## into the machine itself, to be collected by hand.
##
## While the player is away the roots keep working, more slowly: on the
## return, what they gathered meanwhile is waiting.

const KINDS := {
	"cutter": {"name": "Rootling Woodcutter", "targets": ["tree"], "interval": 24.0, "color": Color(0.55, 1.0, 0.45), "sound": "chop"},
	"delver": {"name": "Rootling Delver", "targets": ["ore"], "interval": 30.0, "color": Color(1.0, 0.78, 0.32), "sound": "mine"},
	"tender": {"name": "Rootling Tender", "targets": ["herb"], "interval": 20.0, "color": Color(1.0, 0.55, 0.8), "sound": "pickup"},
}
## How far the roots reach, and the most stacks a machine holds itself.
const REACH := 300.0
const HOLLOW_REACH := 420.0
const CAPACITY := 12
## Unattended, the roots work at this share of their usual pace.
const AWAY_PACE := 0.5
const AWAY_MOST := 40

var kind := "cutter"
var record: Dictionary
var buildings: Buildings
var _time_left := 0.0
var _busy := false
var _sway := 0.0


func _ready() -> void:
	_time_left = randf_range(3.0, 8.0)
	_catch_up()


func data() -> Dictionary:
	return KINDS[kind]


func _process(delta: float) -> void:
	# The stump breathes: a slow sway and its knot of light pulsing.
	_sway += delta
	var prop := get_parent() as Prop
	if prop and prop.sprite():
		prop.sprite().skew = sin(_sway * 1.3) * 0.025
	queue_redraw()
	if _busy:
		return
	_time_left -= delta
	if _time_left > 0.0:
		return
	_time_left = data()["interval"] * randf_range(0.85, 1.15)
	record["last"] = Time.get_unix_time_from_system()
	if _full():
		return
	var target := _find_target()
	if target:
		_work(target)


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_sway * 3.0)
	var color: Color = data()["color"]
	draw_circle(Vector2(0, -16), 9.0 + pulse * 3.0, Color(color, 0.12 + pulse * 0.08))


## Where the harvest goes: a hollow in reach with room, else this machine.
func _store_record() -> Dictionary:
	for node in get_tree().get_nodes_in_group("root_hollows"):
		var hollow := node as Node2D
		if hollow.global_position.distance_to(global_position) < HOLLOW_REACH:
			var store: Dictionary = hollow.get_meta("record")
			if (store["items"] as Array).size() < Buildings.CHEST_SLOTS:
				return store
	return record


func _full() -> bool:
	var store := _store_record()
	return store == record and (record["items"] as Array).size() >= CAPACITY


func _find_target() -> Node2D:
	var best: Node2D = null
	var best_distance := REACH
	for node in get_tree().get_nodes_in_group("resource_nodes"):
		var resource := node as ResourceNode
		if resource == null or resource.has_meta("claimed") or not resource.kind() in data()["targets"]:
			continue
		var distance := resource.global_position.distance_to(global_position)
		if distance < best_distance:
			best = resource
			best_distance = distance
	if kind == "tender" and buildings:
		for plot: Dictionary in buildings.records:
			if plot["kind"] != "plot" or plot["where"] != "world" or plot.get("crop", "") == "":
				continue
			var at := Vector2(plot["x"], plot["y"])
			var distance := at.distance_to(global_position)
			if distance < best_distance and (float(plot.get("growth", 0.0)) >= 1.0 or not plot.get("watered", false)):
				var marker := Node2D.new()
				marker.set_meta("plot", plot)
				marker.position = at
				best = marker
				best_distance = distance
	return best


## Sends a root to the target, works it, and draws the harvest home.
func _work(target: Node2D) -> void:
	_busy = true
	var plot: Dictionary = target.get_meta("plot") if target.has_meta("plot") else {}
	var to := target.global_position if plot.is_empty() else target.position
	if not plot.is_empty():
		target.free()
		target = null
	else:
		target.set_meta("claimed", true)
	var root := RootTendril.new()
	root.color = data()["color"]
	root.from = global_position + Vector2(8, -30)
	root.to = to + Vector2(0, -8)
	get_parent().get_parent().add_child(root)
	await root.grow(1.1)
	var item: Item = null
	if plot.is_empty():
		for blow in 3:
			if not is_instance_valid(target):
				break
			(target as ResourceNode).take_blow(global_position)
			Audio.play(data()["sound"], -14.0, 0.15)
			await get_tree().create_timer(0.45).timeout
		if is_instance_valid(target):
			item = (target as ResourceNode).harvest_by_roots()
	else:
		item = _tend(plot)
	if item:
		root.carry(item.icon(), item.tint())
	await root.retract(0.9)
	if item:
		_keep(item)
		record["yield"] = item.id
	_busy = false


## Waters a dry plot, or harvests a ripe one and plants it again.
func _tend(plot: Dictionary) -> Item:
	var crop: String = plot.get("crop", "")
	if float(plot.get("growth", 0.0)) < 1.0:
		plot["watered"] = true
		Events.splash.emit(Vector2(plot["x"], plot["y"]))
		return null
	var info: Dictionary = Crops.CROPS[crop]
	plot["growth"] = 0.0
	plot["watered"] = true
	Events.codex_event.emit("harvests", 1)
	return Item.create(info["item"], randi_range(info["yield"][0], info["yield"][1]))


func _keep(item: Item) -> void:
	var store := _store_record()
	var items: Array = store["items"]
	for saved: Dictionary in items:
		if saved["id"] == item.id and item.is_stackable():
			saved["count"] = int(saved["count"]) + item.count
			SaveGame.request_save()
			return
	items.append(item.to_dict())
	SaveGame.request_save()


## What the roots gathered while nobody watched.
func _catch_up() -> void:
	var last := float(record.get("last", 0.0))
	var now := Time.get_unix_time_from_system()
	record["last"] = now
	var item_id := str(record.get("yield", ""))
	if last <= 0.0 or item_id == "" or not ItemDB.ITEMS.has(item_id):
		return
	var times := mini(int((now - last) * AWAY_PACE / data()["interval"]), AWAY_MOST)
	if times <= 0:
		return
	await get_tree().process_frame
	_keep(Item.create(item_id, times))
	DamageNumber.spawn_text(get_parent().get_parent(), global_position + Vector2(0, -60), "The roots gathered %d %s" % [times, ItemDB.ITEMS[item_id]["name"]], data()["color"], 13)


## The prompt over the machine.
func prompt() -> String:
	var held := 0
	for saved: Dictionary in record["items"]:
		held += int(saved.get("count", 1))
	return "%s: collect (%d)" % [data()["name"], held] if held > 0 else "%s: working" % data()["name"]
