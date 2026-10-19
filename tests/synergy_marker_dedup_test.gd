extends "res://tests/prototype_test.gd"

func _run() -> void:
	var board := BackpackBoard.new()
	board.run = fixture("mage")
	board.run.items.clear()
	var grimoire: Dictionary = board.run.add_item("ember_tome", Vector2i(2, 2))
	grimoire["mask"] = [Vector2i.DOWN, Vector2i.RIGHT, Vector2i.ZERO]
	grimoire["shape"] = Vector2i(2, 2)
	var idol: Dictionary = board.run.add_item("cursed_idol", Vector2i(3, 3))
	var marks: Array[Dictionary] = board.bonus_markers(grimoire)
	check(marks.size() == 1, "A booster touching two sides of one recipient draws one arrow")
	check(marks[0]["cell"] == Vector2i.RIGHT and marks[0]["direction"] == Vector2i.DOWN, "Displayed top tile wins before the left tile regardless of mask order")
	check(board.run.item_bonus(grimoire) == 3, "Visual deduplication preserves the single actual bonus")
	board.run.add_item("blood_gem", Vector2i(1, 2))
	marks = board.bonus_markers(grimoire)
	check(marks.size() == 2, "Different boosters retain one arrow each")
	check(marks.filter(func(mark: Dictionary) -> bool: return mark["source_id"] == idol["id"]).size() == 1, "Additional sources do not duplicate existing arrows")
	check(board.run.item_bonus(grimoire) == 5, "Separate booster contributions still combine")
	board.free()
	print("Synergy markers: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
