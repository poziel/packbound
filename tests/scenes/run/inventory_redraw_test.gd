extends "res://tests/support/test_case.gd"

var draws: int = 0

func _run() -> void:
	var board := BackpackBoard.new()
	board.run = PackRun.new()
	board.run.reset(42, "warrior")
	board.run.items.clear()
	var item: Dictionary = board.run.add_item("bandage", Vector2i.ZERO)
	board.size = Vector2(800, 700)
	root.add_child(board)
	board.draw.connect(func() -> void: draws += 1)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	draws = 0
	for i in 5:
		await RenderingServer.frame_post_draw
	check_equal(draws, 0, "Settled inventory retains its drawing without per-frame redraws")
	board.refresh()
	await RenderingServer.frame_post_draw
	check(draws > 0, "Explicit inventory refresh redraws settled contents")
	board.flash_failed_activations([item.id])
	await RenderingServer.frame_post_draw
	draws = 0
	board.set_process(false)
	board._process(2.0)
	await RenderingServer.frame_post_draw
	check(board.failed_activations.is_empty(), "Expired failed activation is removed")
	check(draws > 0, "Animation expiry redraws the final cleared frame")
	board.set_process(true)
	draws = 0
	for i in 5:
		await RenderingServer.frame_post_draw
	check_equal(draws, 0, "Finished feedback returns to idle redraw behavior")
	board.run.add_item("bandage", Vector2i.RIGHT)
	board.refresh()
	await RenderingServer.frame_post_draw
	draws = 0
	for i in 5:
		await RenderingServer.frame_post_draw
	check(not board._crafting_hover.is_empty(), "Adjacent bandages retain their live crafting trail")
	check(draws > 0, "Active crafting feedback continues redrawing")
	board.queue_free()
	await process_frame
	report("INVENTORY REDRAW")
	quit(1 if failures else 0)
