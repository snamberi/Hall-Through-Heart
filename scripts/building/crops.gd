class_name Crops
extends RefCounted
## What grows in a farm plot. "days" is how many in-game days a crop takes
## unwatered; watering (or rain) makes it grow half again as fast.

const CROPS := {
	"wheat": {"name": "Wheat", "seed": "wheat_seeds", "item": "wheat", "days": 1.0, "yield": [3, 5], "stalk": Color(0.55, 0.7, 0.3), "fruit": Color(0.92, 0.8, 0.4)},
	"carrot": {"name": "Carrots", "seed": "carrot_seeds", "item": "carrot", "days": 0.8, "yield": [2, 4], "stalk": Color(0.4, 0.75, 0.35), "fruit": Color(1.0, 0.55, 0.15)},
	"potato": {"name": "Potatoes", "seed": "potato_seeds", "item": "potato", "days": 1.2, "yield": [3, 5], "stalk": Color(0.35, 0.6, 0.3), "fruit": Color(0.78, 0.62, 0.4)},
	"pumpkin": {"name": "Pumpkins", "seed": "pumpkin_seeds", "item": "pumpkin", "days": 2.0, "yield": [1, 2], "stalk": Color(0.35, 0.6, 0.25), "fruit": Color(1.0, 0.55, 0.1)},
	"frostberry": {"name": "Frostberries", "seed": "frostberry_seeds", "item": "frostberry", "days": 1.5, "yield": [3, 6], "stalk": Color(0.4, 0.6, 0.6), "fruit": Color(0.6, 0.85, 1.0)},
	"sunroot": {"name": "Sunroot", "seed": "sunroot_seeds", "item": "sunroot", "days": 2.5, "yield": [1, 2], "stalk": Color(0.7, 0.65, 0.3), "fruit": Color(1.0, 0.9, 0.35)},
}
const WATERED := 1.5
## A scarecrow this close (in pixels) speeds the crops around it.
const SCARECROW_REACH := 180.0
const SCARECROW := 1.25


static func by_seed(seed_id: String) -> String:
	for id: String in CROPS:
		if CROPS[id]["seed"] == seed_id:
			return id
	return ""


## Growth stage 0 (just sown) to 3 (ripe) from a share of the way grown.
static func stage(growth: float) -> int:
	return 3 if growth >= 1.0 else 2 if growth >= 0.6 else 1 if growth >= 0.25 else 0
