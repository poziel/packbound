extends SceneTree
## Shared assertion and runner protocol. No test suite is run by this helper.

var checks: int = 0
var failures: int = 0
var failed_checks: Array[Dictionary] = []

func _initialize() -> void:
	if require_isolation():
		call_deferred("_run")

func require_isolation() -> bool:
	if OS.get_environment("PACKBOUND_TEST_ISOLATED") == "1":
		var artifact_root: String = OS.get_environment("PACKBOUND_TEST_ARTIFACT_DIR").replace("\\", "/").simplify_path().trim_suffix("/")
		var user_root: String = OS.get_user_data_dir().replace("\\", "/").simplify_path()
		if OS.get_name() == "Windows":
			artifact_root = artifact_root.to_lower()
			user_root = user_root.to_lower()
		if artifact_root.is_empty() or not artifact_root.is_absolute_path() or not user_root.begins_with(artifact_root + "/"):
			printerr("Test isolation refused: user:// must resolve inside PACKBOUND_TEST_ARTIFACT_DIR before test setup.")
			quit(2)
			return false
		var configured_seed: String = OS.get_environment("PACKBOUND_TEST_SEED")
		if not configured_seed.is_empty():
			seed(int(configured_seed))
		return true
	printerr("Tests require the isolated runner: tests/run_tests.ps1. Direct execution can write production user:// settings and saves.")
	quit(2)
	return false

func check(condition: bool, message: String) -> void:
	_record_check(condition, message, true, condition)

func check_equal(actual: Variant, expected: Variant, message: String) -> void:
	_record_check(actual == expected, message, expected, actual)

func _record_check(condition: bool, message: String, expected: Variant, actual: Variant) -> void:
	checks += 1
	if condition:
		return
	failures += 1
	var detail: Dictionary = {"message": message, "expected": var_to_str(expected), "actual": var_to_str(actual), "runner_seed": _test_seed()}
	failed_checks.append(detail)
	printerr("FAIL: %s | expected=%s actual=%s runner_seed=%s (fixtures may specify their own seed)" % [message, detail.expected, detail.actual, detail.runner_seed])

func _test_seed() -> String:
	var configured: String = OS.get_environment("PACKBOUND_TEST_SEED")
	return configured if not configured.is_empty() else "fixture-defined"

func report(label: String = "RESULT") -> void:
	print("%s: %d checks, %d failures" % [label, checks, failures])
	print("PACKBOUND_TEST_RESULT " + JSON.stringify({"script": get_script().resource_path, "checks": checks, "failures": failures, "runner_seed": _test_seed(), "user_data_dir": OS.get_user_data_dir(), "failed_checks": failed_checks}))

func artifact_path(relative: String = "") -> String:
	return preload("res://tests/support/artifact_paths.gd").path(relative)
