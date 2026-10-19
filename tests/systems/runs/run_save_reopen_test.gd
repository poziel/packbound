extends "res://tests/support/test_case.gd"

func _initialize() -> void:
	if not require_isolation():
		return
	var saves = preload("res://systems/runs/run_saves.gd").new()
	saves.directory = preload("res://tests/support/artifact_paths.gd").path("legacy/run-reopen-test")
	if OS.get_cmdline_user_args().has("--write"):
		var run := PackRun.new()
		run.reset(321, "necromancer")
		run.hp = 17
		run.items[0].cell = Vector2i(4, 3)
		run.items[0].priority = 3
		run.stamina = 2
		run.stamina_capacity = 3
		run.item_rewards.append({"offers": ["bandage", "buckler"], "floor": 1})
		check(saves.write("reopen", saves.capture(run, 812.0)), "Contract: saves.write(\"reopen\", saves.capture(run, 812.0))")
	else:
		var saved: Dictionary = saves.read("reopen")
		check(not saved.is_empty(), "Contract: not saved.is_empty()")
		var run := PackRun.new()
		saves.restore(run, saved)
		check(run.class_key == "necromancer" and run.hp == 17, "Contract: run.class_key == \"necromancer\" and run.hp == 17")
		check(run.items[0].cell == Vector2i(4, 3) and run.item_rewards.size() == 1, "Contract: run.items[0].cell == Vector2i(4, 3) and run.item_rewards.size() == 1")
		check(run.items[0].priority == 3 and run.stamina == 2 and run.stamina_capacity == 3, "Contract: run.items[0].priority == 3 and run.stamina == 2 and run.stamina_capacity == 3")
		check(saved.elapsed == 812.0, "Contract: saved.elapsed == 812.0")
		var invalid: Dictionary = saved.duplicate(true)
		invalid.state.erase("fight")
		check(saves.write("invalid", invalid), "Contract: saves.write(\"invalid\", invalid)")
		check(saves.read("invalid").is_empty(), "Contract: saves.read(\"invalid\").is_empty()")
		check(saves.unfinished().size() == 1, "Contract: saves.unfinished().size() == 1")
	report("run_save_reopen")
	quit()
