extends "res://tests/support/test_case.gd"

class MarkerBoard extends BackpackBoard:
	var target: Dictionary
	func _draw() -> void:
		if not target.is_empty():
			_draw_bonus_markers(target, Vector2.ZERO, Color.WHITE, 1.0)


func _initialize() -> void:
	if not require_isolation():
		return
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("This test requires the real renderer")
		quit(2)
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(84, 84)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var board := MarkerBoard.new()
	board.position = Vector2(10, 10)
	board.run = PackRun.new()
	board.run.relics.append("diagonal_thread")
	board.target = board.run.add_item("buckler", Vector2i(3, 3))
	var supplier: Dictionary = board.run.add_item("iron_charm")
	viewport.add_child(board)
	var directions: Array[Vector2i] = [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1), Vector2i.LEFT]
	for index in directions.size():
		supplier["cell"] = Vector2i(board.target["cell"]) + directions[index]
		board.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = viewport.get_texture().get_image()
		image.save_png(preload("res://tests/support/artifact_paths.gd").path("legacy_logs/diagonal-caret-%d.png") % index)
		var first := Vector2i(999, 999)
		var last := Vector2i(-1, -1)
		var outside: int = 0
		for y in image.get_height():
			for x in image.get_width():
				if image.get_pixel(x, y).a < 0.5:
					continue
				var local := Vector2i(x - 10, y - 10)
				first = first.min(local)
				last = last.max(local)
				if local.x < 0 or local.y < 0 or local.x >= 64 or local.y >= 64:
					outside += 1
		var size: Vector2i = last - first + Vector2i.ONE
		check(last.x >= 0, "Marker actually renders in direction %s" % directions[index])
		if index < 4:
			check(size == Vector2i(8, 8), "Enlarged diagonal retains its interior size after trimming outward tips in direction %s" % directions[index])
			check(outside == 0, "Diagonal marker has no pixels outside its tile in direction %s" % directions[index])
			check((first.x == 0 if directions[index].x < 0 else last.x == 63) and (first.y == 0 if directions[index].y < 0 else last.y == 63), "Diagonal marker hugs its actual corner %s" % directions[index])
		else:
			check(size.x > 7 and size.y > 7 and size.x <= 14 and size.y <= 14, "Ordinary edge marker keeps its existing size")
	board.target["role"] = "weapon"
	board.target["priority"] = 2
	supplier["key"] = "blood_gem"
	supplier["cell"] = Vector2i(board.target["cell"]) + Vector2i(-1, -1)
	board.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var priority_bounds: Rect2i = viewport.get_texture().get_image().get_used_rect()
	check(priority_bounds.position.x >= 27 and priority_bounds.end.x <= 74 and priority_bounds.position.y >= 10 and priority_bounds.end.y <= 74, "Priority-corner marker stays beside the number and inside its tile")
	viewport.queue_free()
	await _context_review()
	await process_frame
	report("DIAGONAL CARET RENDER")
	quit(1 if failures else 0)

func _context_review() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(172, 168)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var board: BackpackBoard = load("res://scenes/run/inventory/backpack/backpack.tscn").instantiate()
	board.run = PackRun.new()
	board.run.relics.append("diagonal_thread")
	board.run.add_item("cracked_shield", Vector2i(1, 0))
	board.run.add_item("iron_charm", Vector2i(0, 1))
	viewport.add_child(board)
	await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(preload("res://tests/support/artifact_paths.gd").path("legacy_logs/diagonal-caret-context.png"))
	viewport.queue_free()
	await process_frame
