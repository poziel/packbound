extends "res://tests/support/test_case.gd"
func _initialize() -> void:
	if not require_isolation():
		return
	_run.call_deferred()
func fixture(pairs: int = 1) -> PackRun:
	var run := PackRun.new()
	run.reset(42)
	run.items.clear()
	run.relics.assign(["duelist_receipt"])
	for i in pairs:
		run.add_item("rusty_knife", Vector2i(0, i * 2))
		run.add_item("rusty_knife", Vector2i(1, i * 2))
	return run
func bonus(run: PackRun) -> int:
	var enhanced: int = int(run.effects()["physical_damage"])
	run.relics.clear()
	var baseline: int = int(run.effects()["physical_damage"])
	run.relics.assign(["duelist_receipt"])
	return enhanced - baseline
func _run() -> void:
	var run := fixture()
	check(bonus(run) == 0 and run.crafting_events.is_empty(), "Uncommitted recipe preview gives no bonus")
	check(run.start_combat(), "Adjacent knife recipe starts combat")
	check(run.crafting_events.size() == 1 and bonus(run) == 4, "One completed recipe gives four opening damage")
	var events: Array = run.crafting_events.duplicate(true)
	check(bonus(run) == 4 and bonus(run) == 4 and run.crafting_events == events, "Repeated previews preserve committed events")
	var saves := PackRunSaves.new()
	var restored := PackRun.new()
	saves.restore(restored, saves.capture(run, 0))
	check(bonus(restored) == 4 and not restored.start_combat() and bonus(restored) == 4, "Save resume retains bonus without repeating crafts")
	run.turn = 2
	check(bonus(run) == 0, "Second round gives no craft bonus")
	run.prepare_enemy()
	check(run.crafting_events.is_empty() and bonus(run) == 0, "Next fight clears crafting credit")
	run = fixture(4)
	check(PackRun.CRAFTING.plans(run).size() == 4, "Four separated adjacent knife pairs select four connected groups")
	check(run.start_combat() and run.crafting_events.size() == 4, "Four independent recipes complete")
	check(bonus(run) == 12, "Opening bonus caps at three completed recipes")
	report("EXPANSION CRAFTING RELIC")
	quit(1 if failures else 0)
