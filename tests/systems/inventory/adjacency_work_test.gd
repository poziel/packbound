extends "res://tests/support/test_case.gd"

class MeasuredRun extends PackRun:
	var eligibility_checks: int = 0
	func item_enabled(item: Dictionary) -> bool:
		eligibility_checks += 1
		return super.item_enabled(item)

func _run() -> void:
	var run := MeasuredRun.new()
	run.reset(42, "warrior")
	run.items.clear()
	var source := run.add_item("iron_charm", Vector2i.ZERO)
	var target := run.add_item("buckler", Vector2i(7, 6))
	run.eligibility_checks = 0
	check_equal(run.bonus(source, target), 0, "Distant items have no adjacency bonus")
	check(not run.has_bonus(source, target), "Distant items have no bonus marker")
	check_equal(run.eligibility_checks, 0, "Distant pairs avoid expensive content eligibility evaluation")
	target["cell"] = Vector2i(1, 0)
	check(run.has_bonus(source, target), "Moving the shield adjacent restores its bonus immediately")
	check(run.eligibility_checks > 0, "Actual adjacency still evaluates restrictions")
	report("ADJACENCY WORK")
	quit(1 if failures else 0)
