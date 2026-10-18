extends "res://tests/storage_ui_test.gd"

func _run() -> void:
	create_timer(25).timeout.connect(func() -> void: quit(2))
	render = DisplayServer.get_name() != "headless"
	test_viewport = SubViewport.new()
	test_viewport.size = Vector2i(1280, 800)
	test_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(test_viewport)
	test_viewport.notify_mouse_entered()
	game = load("res://scenes/main.tscn").instantiate()
	test_viewport.add_child(game)
	await frames(3)
	game.start_run("warrior", 42)
	game.run.items.clear()
	game.run.relics.clear()
	game.run.phase = PackRun.Phase.FIGHT
	# Block automatic grid capture while testing the open right boundary.
	for y in PackRun.GRID.y:
		for x in PackRun.GRID.x:
			game.run.add_item("rusty_knife", Vector2i(x, y))
	var item: Dictionary = game.run.add_item("rusty_knife")
	game._refresh()
	var storage: PackStorage = game.storage
	storage.toss(item, Vector2(530, 300), Vector2(500, 0))
	var body: RigidBody2D = storage.bodies[item["id"]]
	check(is_equal_approx(body.gravity_scale, 0.42) and is_equal_approx(body.linear_damp, 0.35), "Closed fall zone uses the pile's exact gravity and damping")
	await frames(30)
	var canvas_at: Vector2 = storage.pile.get_global_transform_with_canvas() * body.position
	check(canvas_at.x > 660 and body.linear_velocity.x > 250, "Open divider lets falling items enter the right pane")
	check(is_equal_approx(body.return_scale, 1.0), "Falling items retain full size")
	await _snapshot("stash-fall-open-right")
	var inverse: Transform2D = storage.pile.get_global_transform_with_canvas().affine_inverse()
	body.teleport(inverse * Vector2(1250, 100), 0, Vector2(900, -120))
	await frames(5)
	var right_bounds: Rect2 = storage.pile.get_global_transform_with_canvas() * body.bounds()
	check(right_bounds.end.x <= test_viewport.size.x + 1 and body.linear_velocity.x < 0, "Far-right wall bounces throws above the grid back into the game")
	body.teleport(inverse * Vector2(1000, -70), 0, Vector2(0, -200))
	await frames(4)
	var above_right: Rect2 = storage.pile.get_global_transform_with_canvas() * body.bounds()
	check(above_right.position.y >= 0 and body.linear_velocity.y > 0, "Top wall extends across the right pane and bounces throws downward")
	body.teleport(inverse * Vector2(10, 10), 0, Vector2(-900, -900))
	await frames(4)
	var canvas_bounds: Rect2 = storage.pile.get_global_transform_with_canvas() * body.bounds()
	check(canvas_bounds.position.x >= 0 and canvas_bounds.position.y >= 0, "Top and left walls keep the full item inside the screen")
	check(body.linear_velocity.x > 0 and body.linear_velocity.y > 0, "Top and left walls bounce thrown items")
	# An item partly visible below the screen must not be captured early.
	body.teleport(inverse * Vector2(1230, 810), 0, Vector2.ZERO)
	await frames(2)
	check(body.returning, "Partly visible item remains in the fall zone")
	await _snapshot("stash-fall-bottom-exit")
	body.teleport(inverse * Vector2(1230, 850), 0, Vector2.ZERO)
	await frames(2)
	check(not body.returning and body.collision_layer == 1 and body.collision_mask == 3, "Fully offscreen item joins the hidden stash pile")
	await frames(110)
	check(not body.freeze and body.position.y > storage.pile.size.y * 0.5, "Transferred item falls and settles in the background stash")
	game._toggle_storage()
	await frames(3)
	check(storage.bodies.has(item["id"]) and not body.returning, "Opening reveals the already-transferred item")
	print("STASH FALL ZONE RESULT: %d checks, %d failures" % [checks, failures])
	await preload("res://tests/automatic_combat_cleanup.gd").release(self, game, test_viewport)
	quit(1 if failures else 0)
