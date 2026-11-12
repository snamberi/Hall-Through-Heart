class_name TestContext
extends RefCounted
## What each test is handed: checks that note failures without stopping
## the test, and the running game when a test needs one.

var tree: SceneTree
var checks := 0
var failures: Array[String] = []
var _main: Node


func begin() -> void:
	checks = 0
	failures.clear()


## Notes a failure (with `message`) unless `condition` holds.
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func equal(actual: Variant, expected: Variant, message: String) -> void:
	check(actual == expected, "%s: expected %s, got %s" % [message, str(expected), str(actual)])


## Waits for some frames.
func frames(count: int) -> void:
	for i in count:
		await tree.process_frame


## The game, loaded once on a fixed world seed and a throwaway save.
func game() -> Node:
	if _main == null:
		var save: Node = tree.root.get_node("SaveGame")
		save.path = "user://tests_save.json"
		save.delete_save()
		_main = load("res://scenes/main.tscn").instantiate()
		_main.world_seed = 12345
		tree.root.add_child(_main)
		await frames(10)
		_main.get_node("Enemies").max_alive = 0
	return _main


func close_game() -> void:
	if _main != null:
		_main.queue_free()
		_main = null
		tree.root.get_node("SaveGame").delete_save()
