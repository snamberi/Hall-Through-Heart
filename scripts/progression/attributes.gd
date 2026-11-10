class_name Attributes
extends Node
## The six primary attributes and the points spent on them.

signal changed

const IDS: Array[String] = [
	"strength", "vitality", "agility", "luck", "intelligence", "endurance",
]
const NAMES := {
	"strength": "Strength",
	"vitality": "Vitality",
	"agility": "Agility",
	"luck": "Luck",
	"intelligence": "Intelligence",
	"endurance": "Endurance",
}

var unspent := 0
var points: Dictionary[String, int] = {}


func _init() -> void:
	for id in IDS:
		points[id] = 0


func _ready() -> void:
	SaveGame.register("attributes", self)


func grant_points(amount: int) -> void:
	unspent += amount
	changed.emit()


## Spends up to `amount` points on an attribute. Returns how many were spent.
func spend(id: String, amount: int = 1) -> int:
	if not points.has(id):
		return 0
	var spent := clampi(amount, 0, unspent)
	if spent == 0:
		return 0
	unspent -= spent
	points[id] += spent
	changed.emit()
	SaveGame.request_save()
	return spent


## Returns every spent point to the unspent pool (for Attribute Reset items).
func reset() -> void:
	for id in IDS:
		unspent += points[id]
		points[id] = 0
	changed.emit()
	SaveGame.request_save()


func save_data() -> Dictionary:
	return {"unspent": unspent, "points": points.duplicate()}


func load_data(data: Dictionary) -> void:
	unspent = maxi(int(data.get("unspent", 0)), 0)
	var saved: Variant = data.get("points", {})
	if saved is Dictionary:
		for id in IDS:
			points[id] = maxi(int(saved.get(id, 0)), 0)
