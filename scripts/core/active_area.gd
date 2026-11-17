class_name ActiveArea
extends Node
## Keeps the world awake only round the player. Creatures, villagers and
## animated props further out than the active radius (set by the view
## distance in the graphics settings) stop thinking and animating until the
## player comes near again: not merely hidden, but not processed at all,
## which saves the CPU most on slower machines and phones. Bosses always
## stay awake. Checked a few times a second, a slice of the world at a time.

const GROUPS: Array[String] = ["enemies", "critters", "livestock", "npcs", "props", "fires", "scenery"]
const INTERVAL := 0.25

var _player: Node2D
var _clock := 0.0
## How many are asleep now (for the debug overlay and tests).
var sleeping := 0


func setup(player: Node2D) -> void:
	_player = player


func _process(delta: float) -> void:
	_clock -= delta
	if _clock > 0.0 or _player == null or not is_instance_valid(_player):
		return
	_clock = INTERVAL
	refresh()


## Wakes what is near and puts to sleep what is far, now.
func refresh() -> void:
	var radius := GameSettings.active_radius()
	var limit := radius * radius
	var here := _player.global_position
	var asleep := 0
	for group in GROUPS:
		for node in get_tree().get_nodes_in_group(group):
			var thing := node as Node2D
			if thing == null or thing.is_in_group("bosses"):
				continue
			var far := thing.global_position.distance_squared_to(here) > limit
			var wanted := Node.PROCESS_MODE_DISABLED if far else Node.PROCESS_MODE_INHERIT
			if thing.process_mode != wanted:
				thing.process_mode = wanted
			if far:
				asleep += 1
	sleeping = asleep
