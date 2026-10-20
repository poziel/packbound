extends "res://tests/support/prototype_support.gd"

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
	check(board.has_method("synergy_cells"), "Board exposes potential and fulfilled synergy cells")
	if board.has_method("synergy_cells"):
		board.hovered_id = int(idol.id)
		var stars: Array = board.call("synergy_cells")
		check(stars.any(func(star: Dictionary) -> bool: return star.cell == Vector2i(4, 3) and not star.fulfilled), "Empty neighboring cells advertise potential synergy")
		check(stars.any(func(star: Dictionary) -> bool: return star.cell == Vector2i(3, 2) and star.fulfilled), "Matching occupied cell has a filled star")
		board.dragging = idol
		board.drag_shape = idol.shape
		board.drag_rotation = int(idol.rotation)
		board.grab = Vector2.ZERO
		board.pointer = board.ORIGIN + Vector2(5, 4) * board.STEP
		var before: String = str(board.run.items)
		stars = board.call("synergy_cells")
		check(stars.any(func(star: Dictionary) -> bool: return star.cell == Vector2i(6, 4)), "Dragged synergy follows the snapped candidate")
		check(str(board.run.items) == before, "Synergy preview never commits candidate placement")
		idol.mask = [Vector2i.ZERO, Vector2i.RIGHT]
		idol.shape = Vector2i(2, 1)
		board.drag_rotation = 1
		board.drag_shape = Vector2i(1, 2)
		board.pointer = board.ORIGIN + Vector2(5, 3) * board.STEP
		stars = board.call("synergy_cells")
		check(stars.any(func(star: Dictionary) -> bool: return star.cell == Vector2i(5, 5)), "Stars follow the rotated footprint")
		check(not stars.any(func(star: Dictionary) -> bool: return star.cell == Vector2i(5, 4)), "Stars never cover the source footprint")
		idol.mask = [Vector2i.ZERO]
		idol.shape = Vector2i.ONE
		board.pointer = Vector2(-1000, -1000)
		check(board.call("synergy_cells").is_empty(), "Leaving the board hides all stars")
		board.dragging = {}
		idol.cell = Vector2i(0, 3)
		board.run.relics.assign(["folded_space", "diagonal_thread"])
		stars = board.call("synergy_cells")
		check(stars.any(func(star: Dictionary) -> bool: return star.cell == Vector2i(7, 3)), "Folded space previews the wrapped cell")
		check(stars.any(func(star: Dictionary) -> bool: return star.cell == Vector2i(1, 2)), "Diagonal thread previews diagonal cells")
		check(stars.all(func(star: Dictionary) -> bool: return star.cell.x >= 0 and star.cell.x < PackRun.GRID.x and star.cell.y >= 0 and star.cell.y < PackRun.GRID.y), "All stars remain on actual board cells")
	board.free()
	report("Synergy markers")
	quit(1 if failures else 0)
