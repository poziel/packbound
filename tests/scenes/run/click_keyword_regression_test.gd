extends "res://tests/support/storage_ui_support.gd"

func _run() -> void:
	create_timer(30).timeout.connect(func() -> void: quit(2))
	test_viewport = SubViewport.new()
	test_viewport.size = Vector2i(1280, 720)
	test_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(test_viewport)
	test_viewport.notify_mouse_entered()
	game = load("res://scenes/main.tscn").instantiate()
	test_viewport.add_child(game)
	await frames(3)
	game.run_saves.directory = preload("res://tests/support/artifact_paths.gd").path("legacy_tasks/click-keyword/saves")
	game.start_run("warrior", 42)
	game.waiting_at_entrance = false
	game.run.items.clear()
	game.run.phase = PackRun.Phase.FIGHT
	var item: Dictionary = game.run.add_item("cracked_shield", Vector2i.ZERO)
	game._refresh()
	await frames(4)
	game.inspector.show_delay = 0.02
	game.inspector.lock_delay = 0.1
	var point: Vector2 = game.board.get_global_transform_with_canvas() * game.board.item_rect(item).get_center()
	_motion(point)
	_mouse(point, true)
	_mouse(point, false)
	await create_timer(0.3).timeout
	_motion(point + Vector2.ONE)
	await create_timer(0.3).timeout
	check(game.board.dragging.is_empty(), "Click and release returns item to inventory")
	check(game.inspector.windows.size() == 1, "Hover after clicking opens item tooltip")
	if not game.inspector.windows.is_empty():
		var window: PackInspectWindow = game.inspector.windows[0]
		check(window.locked, "Item tooltip locks after clicking item")
		var found: bool = false
		for line in range(window.body.get_line_count()):
			for x in [50, 80, 110, 140]:
				_motion(window.body.global_position + Vector2(x, window.body.get_line_offset(line) + 10))
				await process_frame
				if game.inspector.active_keyword_link == "block": found = true; break
			if found: break
		check(found, "Keyword receives pointer after clicking and releasing item")
		await create_timer(0.18).timeout
		check(game.inspector.windows.size() == 2, "Keyword definition opens after item click without empty-space click")
		if game.inspector.windows.size() == 2:
			var child: PackInspectWindow = game.inspector.windows[1]
			_motion(child.global_position + Vector2(20, 15))
			await create_timer(0.2).timeout
			check(child.locked, "Nested definition locks normally")
			_motion(window.global_position + Vector2(20, 15))
			await create_timer(game.inspector.closing_delay + 0.05).timeout
			check(game.inspector.windows.size() == 1, "Returning to item tooltip closes locked definition")
	report("CLICK KEYWORD")
	await preload("res://tests/support/automatic_combat_cleanup.gd").release(self, game, test_viewport)
	quit(1 if failures else 0)
