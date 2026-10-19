extends "res://tests/support/test_case.gd"
var board: BackpackBoard
func _initialize() -> void:
	if not require_isolation():
		return
	_run.call_deferred()
func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(2)
		return
	root.content_scale_size = Vector2i(584, 568)
	var view := SubViewport.new()
	view.size = Vector2i(584, 568)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	board = load("res://scenes/run/inventory/backpack/backpack.tscn").instantiate()
	board.run = PackRun.new()
	board.run.reset(42)
	board.run.items.clear()
	var item: Dictionary = board.run.add_item("cracked_shield", Vector2i(1, 4))
	var partner: Dictionary = board.run.add_item("cracked_shield", Vector2i(1, 0))
	view.add_child(board)
	board.set_process(false)
	var hover := InputEventMouseMotion.new()
	hover.position = board.item_rect(item).get_center()
	board._gui_input(hover)
	board._process(0.1)
	for cycle in range(3):
		board.begin_drag(item, board.pointer)
		board.pointer += Vector2(50 + cycle * 3, -25)
		await _frames(view, item, partner, "held-%d" % cycle, 4)
		board.drop_at(board.ORIGIN + Vector2(2 + cycle, 3 + cycle % 2) * board.STEP + Vector2(40, 30))
		await _frames(view, item, partner, "settling-%d" % cycle, 4)
		await _frames(view, item, partner, "resting-%d" % cycle, 16)
		checks += 1
		if board.hovered_id != item["id"]:
			failures += 1
			printerr("FAIL: stationary hover lost after rendered drop")
	view.queue_free()
	await process_frame
	report("CRAFTING DRAG RENDER")
	quit(1 if failures else 0)
func _frames(view: SubViewport, item: Dictionary, partner: Dictionary, label: String, count: int) -> void:
	var ids: Array = [item["id"], partner["id"]]
	ids.sort()
	for frame in range(count):
		board._process(1.0 / 60.0)
		var flow: Dictionary = board._crafting_hover.get(str(ids), {})
		checks += 1
		if flow.is_empty():
			failures += 1
			printerr("FAIL: active rendered trail disappeared")
		else:
			var a: Vector2 = flow["start"] if int(item["id"]) == int(ids[0]) else flow["finish"]
			var b: Vector2 = flow["finish"] if int(item["id"]) == int(ids[0]) else flow["start"]
			if a.distance_to(board.visual_item_cells(item)[0]) > 0.1 or b.distance_to(board.visual_item_cells(partner)[0]) > 0.1:
				failures += 1
				printerr("FAIL: rendered trail is detached from an item")
		await process_frame
		await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png(preload("res://tests/support/artifact_paths.gd").path("legacy_logs/crafting-attachment-") + label + ".png")
