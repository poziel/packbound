extends "res://tests/support/storage_ui_support.gd"

func _run() -> void:
	test_viewport = SubViewport.new()
	test_viewport.size = Vector2i(1280, 720)
	test_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(test_viewport)
	test_viewport.notify_mouse_entered()
	game = load("res://scenes/main.tscn").instantiate()
	test_viewport.add_child(game)
	await frames(3)
	game.run_saves.directory = preload("res://tests/support/artifact_paths.gd").path("legacy_tasks/irregular-tooltip-triggers/saves")
	game.start_run("warrior", 42)
	game.waiting_at_entrance = false
	game.run.items.clear()
	game.run.phase = PackRun.Phase.FIGHT
	var item: Dictionary = game.run.add_item("buckler", Vector2i.ZERO)
	item["mask"] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)]
	item["shape"] = Vector2i(2, 2)
	var other: Dictionary = game.run.add_item("buckler", Vector2i(1, 1))
	game._refresh()
	await frames(4)
	game.inspector.set_process(false)
	for rotation in range(4):
		item["rotation"] = rotation
		var offsets: Array[Vector2i] = PackRun.offsets(item)
		var hole := Vector2i.ZERO
		for y in range(2):
			for x in range(2):
				if not Vector2i(x, y) in offsets: hole = Vector2i(x, y)
		other["cell"] = hole
		var occupied: Vector2 = Vector2(offsets[0]) * game.board.STEP + Vector2(24, 24)
		game.board.pointer = occupied
		var data: Dictionary = game._item_inspection()
		game.inspector.clear()
		game.inspector.source = game.board
		game.inspector.source_rect = data["rect"]
		game.inspector._spawn(data, data["rect"], -1)
		game.inspector.pointer = game.board.get_global_transform_with_canvas() * occupied
		check(game.inspector._trigger_held(0, -1), "Occupied cell holds tooltip at rotation %d" % rotation)
		var empty: Vector2 = Vector2(hole) * game.board.STEP + Vector2(24, 24)
		check(int(game.board.hit_item(empty).get("id", -1)) == int(other["id"]), "Hole picks underlying item at rotation %d" % rotation)
		game.inspector.pointer = game.board.get_global_transform_with_canvas() * empty
		check(not game.inspector._trigger_held(0, -1), "Hole releases tooltip at rotation %d" % rotation)
	game.inspector.clear()
	report("TOOLTIP FOOTPRINT")
	await preload("res://tests/support/automatic_combat_cleanup.gd").release(self, game, test_viewport)
	quit(1 if failures else 0)
