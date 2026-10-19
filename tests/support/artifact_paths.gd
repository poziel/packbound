extends RefCounted
## One artifact owner per test process, supplied by the runner.
## Captures and manual runs use a script-specific folder beneath manual/.

static func path(relative: String = "") -> String:
	var directory: String = OS.get_environment("PACKBOUND_TEST_ARTIFACT_DIR")
	if directory.is_empty():
		var script_name: String = "manual"
		var arguments: PackedStringArray = OS.get_cmdline_args()
		for index: int in range(arguments.size() - 1):
			if arguments[index] in ["--script", "-s"]:
				script_name = arguments[index + 1].get_file().get_basename()
				break
		directory = ProjectSettings.globalize_path("res://workspace/tasks/test-runs/manual").path_join(script_name)
	DirAccess.make_dir_recursive_absolute(directory)
	var result: String = directory.path_join(relative)
	if not relative.is_empty():
		DirAccess.make_dir_recursive_absolute(result.get_base_dir())
	return result
