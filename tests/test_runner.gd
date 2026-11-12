extends Node
## Runs every test in res://tests/: each file named test_*.gd holds
## functions named test_* that take a TestContext. Prints a line per test
## and a summary, then quits with exit code 1 if anything failed.
##
## Run it from the editor by opening tests/run_tests.tscn and pressing F6,
## or from a terminal in the project folder:
##     godot --headless --path . res://tests/run_tests.tscn
##
## Tests that need the running game ask for it with `await t.game()`: the
## main scene is loaded once, on a throwaway save file, so a real save is
## never touched.

const FOLDER := "res://tests/"
const TEST_SAVE := "user://tests_save.json"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var t := TestContext.new()
	t.tree = get_tree()
	var files := Array(DirAccess.get_files_at(FOLDER)).filter(func(f: String) -> bool:
		return f.begins_with("test_") and f.ends_with(".gd") and f != "test_runner.gd" and f != "test_context.gd")
	files.sort()
	var passed := 0
	var failed := 0
	var started := Time.get_ticks_msec()
	for file: String in files:
		var script: GDScript = load(FOLDER + file)
		if script == null:
			print("FAIL  %s  (did not load)" % file)
			failed += 1
			continue
		var suite: Object = script.new()
		for method in script.get_script_method_list():
			var test_name: String = method["name"]
			if not test_name.begins_with("test_"):
				continue
			t.begin()
			await suite.call(test_name, t)
			var label := "%s.%s" % [file.get_basename(), test_name]
			if t.failures.is_empty():
				passed += 1
				print("pass  %s  (%d checks)" % [label, t.checks])
			else:
				failed += 1
				print("FAIL  %s" % label)
				for message: String in t.failures:
					print("        - " + message)
	t.close_game()
	print("")
	print("%d passed, %d failed in %.1fs" % [passed, failed, (Time.get_ticks_msec() - started) / 1000.0])
	get_tree().quit(1 if failed > 0 else 0)
