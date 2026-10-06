extends SceneTree
## Headless test runner. Usage (from the repo root):
##   godot --headless --path . -s res://tests/run_tests.gd [-- --filter=deck]
## Prefer tools/run_tests.sh, which also imports the project and fails on
## engine-reported script errors. Exit code 0 = all passed.

const TEST_DIRS: Array[String] = ["res://tests/unit", "res://tests/integration"]


func _initialize() -> void:
	_run()


func _run() -> void:
	var filter := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--filter="):
			filter = arg.trim_prefix("--filter=")

	var passed := 0
	var failed: PackedStringArray = []
	var started := Time.get_ticks_msec()

	for path in _find_test_files():
		if not filter.is_empty() and not path.contains(filter):
			continue
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			failed.append("%s: could not load script" % path)
			continue
		for method in script.get_script_method_list():
			var name: String = method["name"]
			if not name.begins_with("test_"):
				continue
			var test: TestCase = script.new()
			test.tree = self
			test.before_each()
			await test.call(name)
			test.after_each()
			var label := "%s::%s" % [path.get_file().get_basename(), name]
			if test.failures.is_empty():
				passed += 1
				print("  PASS  ", label)
			else:
				for message in test.failures:
					failed.append("%s: %s" % [label, message])
				print("  FAIL  ", label)

	print("")
	for line in failed:
		printerr("FAILED ", line)
	print("%d passed, %d failed in %d ms" % [passed, failed.size(), Time.get_ticks_msec() - started])
	quit(0 if failed.is_empty() and passed > 0 else 1)


func _find_test_files() -> Array[String]:
	var files: Array[String] = []
	for dir_path in TEST_DIRS:
		for file in DirAccess.get_files_at(dir_path):
			if file.begins_with("test_") and file.ends_with(".gd"):
				files.append(dir_path.path_join(file))
	files.sort()
	return files
