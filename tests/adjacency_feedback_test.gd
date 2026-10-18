extends SceneTree

var failures := 0
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var board := BackpackBoard.new()
	board.run = PackRun.new()
	root.add_child(board)
	check(board.has_method("bonus_markers") and board.has_method("bonus_related_ids"), "Backpack exposes directional bonus feedback")
	if failures:
		board.queue_free()
		quit(1)
		return
	var target: Dictionary = board.run.add_item("buckler")
	target.cell = Vector2i(2, 2)
	var left: Dictionary = board.run.add_item("iron_charm")
	left.cell = Vector2i(1, 2)
	var diagonal: Dictionary = board.run.add_item("iron_charm")
	diagonal.cell = Vector2i(1, 1)
	check(board.call("bonus_markers", target).size() == 1, "Only direct bonuses appear without diagonal relic")
	board.run.relics.append("diagonal_thread")
	var marks: Array = board.call("bonus_markers", target)
	check(marks.size() == 2, "Side and diagonal bonuses coexist")
	check(marks.any(func(m: Dictionary) -> bool: return m.direction == Vector2i.LEFT), "Left booster marks left edge")
	check(marks.any(func(m: Dictionary) -> bool: return m.direction == Vector2i(-1, -1)), "Diagonal booster uses one corner")
	board.hovered_id = target.id
	check(board.call("bonus_related_ids").has(left.id) and board.call("bonus_related_ids").has(diagonal.id), "Recipient hover reveals both suppliers")
	board.hovered_id = left.id
	check(board.call("bonus_related_ids").has(target.id) and not board.call("bonus_related_ids").has(diagonal.id), "Booster hover reveals recipients without unrelated suppliers")
	board._clear_hover()
	check(board.call("bonus_related_ids").is_empty(), "Hover exit clears relationship highlights")
	left.cell = Vector2i(7, 2)
	target.cell = Vector2i(0, 2)
	diagonal.cell = null
	check(board.call("bonus_markers", target).is_empty(), "Opposite bag edges do not connect without relic")
	board.run.relics.append("folded_space")
	marks = board.call("bonus_markers", target)
	check(marks.size() == 1 and marks[0].direction == Vector2i.LEFT, "Wrapped bonus enters through left boundary")
	left.cell = Vector2i(7, 1)
	marks = board.call("bonus_markers", target)
	check(marks.size() == 1 and marks[0].direction == Vector2i(-1, -1), "Wrapped diagonal uses boundary corner")
	target.cell = Vector2i(7, 2)
	left.cell = Vector2i(0, 2)
	marks = board.call("bonus_markers", target)
	check(marks.size() == 1 and marks[0].direction == Vector2i.RIGHT, "Wrapped bonus enters through right boundary")
	board.dragging = left
	check(board.call("bonus_markers", target).is_empty(), "Held booster does not leave stale markers")
	board.dragging = {}
	left.cell = null
	check(board.call("bonus_markers", target).is_empty(), "Stashed booster has no marker")
	left.cell = Vector2i(1, 2)
	target.cell = Vector2i(2, 2)
	var incompatible: Dictionary = board.run.add_item("blood_gem")
	incompatible.cell = Vector2i(2, 1)
	marks = board.call("bonus_markers", target)
	check(marks.size() == 1 and marks[0].source_id == left.id, "Touching incompatible boosters do not advertise a bonus")
	board.run.items.clear()
	var large: Dictionary = board.run.add_item("shortbow")
	large.cell = Vector2i(2, 2)
	var tall: Dictionary = board.run.add_item("quiver")
	tall.cell = Vector2i(1, 2)
	marks = board.call("bonus_markers", large)
	check(not marks.is_empty() and marks.all(func(m: Dictionary) -> bool: return m.direction == Vector2i.LEFT), "Long shared edges avoid redundant diagonal contacts")
	check(marks.size() == 1 and int(marks[0].get("span", 1)) == 2, "Two-cell shared edge has one centered marker")
	large.rotation = 1
	large.shape = PackRun.dimensions(large)
	marks = board.call("bonus_markers", large)
	check(not marks.is_empty() and marks[0].cell == Vector2i.ZERO, "Rotated footprints register markers against displayed cells")
	tall.rotation = 1
	tall.shape = PackRun.dimensions(tall)
	tall.cell = Vector2i(2, 1)
	marks = board.call("bonus_markers", large)
	check(marks.size() == 1 and marks[0].direction == Vector2i.UP and int(marks[0].get("span", 1)) == 2, "Horizontal shared edge also has one marker")
	large.rotation = 0
	large.shape = PackRun.dimensions(large)
	large.cell = Vector2i(0, 2)
	tall.rotation = 0
	tall.shape = PackRun.dimensions(tall)
	tall.cell = Vector2i(7, 2)
	marks = board.call("bonus_markers", large)
	check(marks.size() == 1 and marks[0].direction == Vector2i.LEFT and int(marks[0].get("span", 1)) == 2, "Two-cell wrapped contact also collapses to one boundary marker")
	board.run.items.assign([target, left])
	target.cell = Vector2i(3, 3)
	for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN, Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
		left.cell = target.cell + direction
		marks = board.call("bonus_markers", target)
		check(marks.size() == 1 and marks[0].direction == direction, "Independent direction " + str(direction))
	var motion := InputEventMouseMotion.new()
	motion.position = board.item_rect(target).get_center()
	board._gui_input(motion)
	check(board.hovered_id == target.id and board.call("bonus_related_ids").has(left.id), "Pointer hover activates related-item feedback")
	board.item_motions[left.id] = {}
	check(board.call("bonus_markers", target).is_empty(), "Moving booster does not leave a stale contact")
	board.item_motions.clear()
	board._clear_hover()
	if DisplayServer.get_name() != "headless":
		await _render_review(board)
	board.queue_free()
	await process_frame
	print("ADJACENCY FEEDBACK: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _render_review(board: BackpackBoard) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(600, 520)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	board.reparent(viewport)
	board.run.items.clear()
	board.run.relics.assign(["diagonal_thread", "folded_space"])
	for entry in [["iron_charm", Vector2i(1, 2)], ["iron_charm", Vector2i(1, 1)], ["buckler", Vector2i(2, 2)], ["blood_gem", Vector2i(4, 1)], ["longsword", Vector2i(5, 2)], ["iron_charm", Vector2i(7, 4)], ["buckler", Vector2i(0, 4)], ["quiver", Vector2i(2, 4)], ["shortbow", Vector2i(3, 4)]]:
		var item: Dictionary = board.run.add_item(entry[0])
		item.cell = entry[1]
		if item.key == "longsword": item.priority = 2
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.hovered_id = -1
	var resting: Image = await _capture(board, "rest")
	var shared_at := Vector2i(BackpackBoard.ORIGIN + Vector2(3, 4) * BackpackBoard.STEP + Vector2(7, 66))
	var shared_rim := Vector2i(BackpackBoard.ORIGIN + Vector2(3, 4) * BackpackBoard.STEP + Vector2(32, 0))
	var resting_rim: Color = resting.get_pixelv(shared_rim)
	check(resting.get_pixelv(shared_at).is_equal_approx(resting_rim), "Centered caret uses the exact receiving border color")
	check(not resting.get_pixelv(shared_at - Vector2i(0, 34)).is_equal_approx(resting_rim) and not resting.get_pixelv(shared_at + Vector2i(0, 34)).is_equal_approx(resting_rim), "Original per-cell marker positions remain clear")
	board.hovered_id = board.run.items[2].id
	var image: Image = await _capture(board, "recipient-hover")
	var marker_at := Vector2i(BackpackBoard.ORIGIN + Vector2(2, 2) * BackpackBoard.STEP + Vector2(7, 32))
	var target_rim := Vector2i(BackpackBoard.ORIGIN + Vector2(2, 2) * BackpackBoard.STEP + Vector2(32, 0))
	check(image.get_pixelv(marker_at).is_equal_approx(image.get_pixelv(target_rim)), "Hovered caret remains the same color as its border")
	var supplier_rim := Vector2i(BackpackBoard.ORIGIN + Vector2(1, 2) * BackpackBoard.STEP + Vector2(32, 0))
	check(image.get_pixelv(supplier_rim).is_equal_approx(Color("ffd98c")), "Recipient hover paints supplier's actual footprint border")
	board.hovered_id = board.run.items[5].id
	image = await _capture(board, "wrapped-booster-hover")
	var recipient_rim := Vector2i(BackpackBoard.ORIGIN + Vector2(0, 4) * BackpackBoard.STEP + Vector2(32, 0))
	check(image.get_pixelv(recipient_rim).is_equal_approx(Color("ffd98c")), "Wrapped booster hover paints recipient across the bag")
	board._clear_hover()
	var restored: Image = await _capture(board, "hover-cleared")
	check(restored.get_pixelv(marker_at).is_equal_approx(restored.get_pixelv(target_rim)), "Hover exit restores matching border and caret color")
	check(not restored.get_pixelv(recipient_rim).is_equal_approx(Color("ffd98c")), "Hover exit removes the actual relationship border")
	board.reparent(root)
	viewport.queue_free()

func _capture(board: BackpackBoard, label: String) -> Image:
	board.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = board.get_viewport().get_texture().get_image()
	image.save_png("res://tests/output/adjacency-" + label + ".png")
	return image
