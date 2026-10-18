extends SceneTree

func _initialize() -> void:
	var saves = preload("res://scripts/run_saves.gd").new()
	saves.directory = "res://.tmp/run-reopen-test"
	if OS.get_cmdline_user_args().has("--write"):
		var run := PackRun.new()
		run.reset(321, "necromancer")
		run.hp = 17
		run.items[0].cell = Vector2i(4, 3)
		run.items[0].priority = 3
		run.stamina = 2
		run.stamina_capacity = 3
		run.item_rewards.append({"offers": ["bandage", "buckler"], "floor": 1})
		assert(saves.write("reopen", saves.capture(run, 812.0)))
		print("REOPEN WRITE: passed")
	else:
		var saved: Dictionary = saves.read("reopen")
		assert(not saved.is_empty())
		var run := PackRun.new()
		saves.restore(run, saved)
		assert(run.class_key == "necromancer" and run.hp == 17)
		assert(run.items[0].cell == Vector2i(4, 3) and run.item_rewards.size() == 1)
		assert(run.items[0].priority == 3 and run.stamina == 2 and run.stamina_capacity == 3)
		assert(saved.elapsed == 812.0)
		var invalid: Dictionary = saved.duplicate(true)
		invalid.state.erase("fight")
		assert(saves.write("invalid", invalid))
		assert(saves.read("invalid").is_empty())
		assert(saves.unfinished().size() == 1)
		print("REOPEN READ: 7 checks passed in a fresh process")
	quit()
