extends "res://tests/storage_ui_test.gd"

func _run() -> void:
	create_timer(35).timeout.connect(func() -> void: quit(2))
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
	var first: Dictionary = game.run.add_item("rusty_knife")
	var second: Dictionary = game.run.add_item("rusty_knife")
	game._refresh()
	var storage: PackStorage = game.storage
	var board: BackpackBoard = game.board
	await frames(90)
	var hidden_first: RigidBody2D = storage.bodies[first["id"]]
	check(not hidden_first.freeze and hidden_first.collision_layer == 1, "Hidden pile keeps its own physics and item collisions active")
	check(hidden_first.position.y > storage.pile.size.y * 0.6, "Existing items are already in the pile before first opening")
	check(not storage.bodies[second["id"]].get_meta("waiting", false), "Existing items are not queued to rain down on first opening")
	var hidden_position: Vector2 = hidden_first.position
	game._toggle_storage()
	await frames(3)
	check(hidden_first.position.distance_to(hidden_position) < 8, "First opening preserves the background pile position")
	await frames(30)
	var a: RigidBody2D = storage.bodies[first["id"]]
	var b: RigidBody2D = storage.bodies[second["id"]]
	await place(a, Vector2(130, 180))
	await place(b, Vector2(340, 180))
	var corner: Vector2 = storage.pile.get_global_transform_with_canvas() * a.to_global(a.origin + Vector2(5, 5))
	_motion(corner)
	_mouse(corner, true)
	check(storage.grab_local.is_equal_approx(Vector2.ZERO), "Stash grabs snap to nearest occupied tile center")
	var before_angle: float = storage.held_angle
	_key(KEY_E)
	check(is_equal_approx(storage.held_angle, before_angle), "Rotation starts without an instant quarter-turn")
	await frames(4)
	check(storage.held_angle > before_angle and storage.held_angle < before_angle + PI * 0.5, "Rotation visibly advances through intermediate angles")
	await frames(10)
	check(is_equal_approx(storage.held_angle, before_angle + PI * 0.5), "Rotation completes its quarter-turn")
	# A single event crosses the neighbour completely: collision must be swept.
	var across: Vector2 = storage.pile.get_global_transform_with_canvas() * Vector2(480, 180)
	_motion(across)
	await frames(2)
	check(b.linear_velocity.x > 100, "Fast held movement strikes rather than tunnels through another item")
	await place(b, Vector2(450, storage.pile.size.y - 32))
	# Release below the panel, preserving the exact release location.
	var outside: Vector2 = storage.pile.get_global_transform_with_canvas() * Vector2(450, storage.pile.size.y + 110)
	_motion(outside)
	var release_at: Vector2 = a.position
	_mouse(outside, false)
	check(a.position.distance_to(release_at) < 1, "Outside release does not teleport to the stash edge")
	check(a.get("returning") == true, "Outside release starts physical attraction")
	await _snapshot("stash-pull-from-below")
	var upward_speed: float = 0.0
	for tick in 100:
		await frames(1)
		upward_speed = minf(upward_speed, b.linear_velocity.y)
	check(upward_speed < -30, "An item pulled in from below pushes an item on the floor upward")
	await frames(60)
	check(Rect2(Vector2.ONE * -2, storage.pile.size + Vector2.ONE * 4).encloses(a.bounds()), "Physical attraction brings the released item into the stash")
	# A long item's animated sweep can hit a neighbour absent from both end poses.
	var rod: Dictionary = game.run.add_item("rusty_knife")
	rod["mask"] = [Vector2i.ZERO, Vector2i(1, 0), Vector2i(2, 0)]
	rod["shape"] = Vector2i(3, 1)
	storage.refresh()
	var rotating: RigidBody2D = storage.bodies[rod["id"]]
	rotating.set_meta("waiting", false)
	rotating.collision_layer = 1
	rotating.collision_mask = 3
	rotating.show()
	await place(rotating, Vector2(230, 180))
	await place(b, Vector2(300, 280))
	var center: Vector2 = storage.pile.get_global_transform_with_canvas() * rotating.position
	_motion(center)
	_mouse(center, true)
	_key(KEY_E)
	var rotation_speed: float = 0.0
	for tick in 15:
		await frames(1)
		rotation_speed = maxf(rotation_speed, b.linear_velocity.length())
	check(rotation_speed > 100, "Animated rotation transfers tangential momentum to a neighbouring item")
	_mouse(center, false)
	await frames(10)
	# Closed stash: off-grid drops retain a visible moving body until captured.
	game._close_storage()
	first["cell"] = Vector2i.ZERO
	board.refresh()
	await frames(3)
	board.begin_drag(first, board.item_rect(first).get_center())
	board.rotate_held(1)
	check(is_equal_approx(board.held_rotation_offset, -PI * 0.5), "Backpack rotation also starts with an animated visual offset")
	await frames(4)
	check(board.held_rotation_offset > -PI * 0.5 and board.held_rotation_offset < 0, "Backpack rotation advances smoothly")
	await frames(10)
	board.rotate_held(-1)
	await frames(14)
	board.throw_velocity = Vector2(-200, -160)
	board.throw_time_msec = Time.get_ticks_msec()
	var left: Vector2 = Vector2(380, 350)
	board.drop_at(board.get_global_transform_with_canvas().affine_inverse() * left)
	check(first["cell"] == null, "Off-grid throw stores an item while stash is closed")
	var flight: RigidBody2D = storage.bodies[first["id"]] if storage.bodies.has(first["id"]) else null
	check(flight != null and flight.get("returning") == true, "Closed stash uses a physics flight rather than a timed shrinking arc")
	check(flight != null and flight.collision_layer == 0 and flight.collision_mask == 0, "Closed-stash flight is isolated from hidden pile collisions in both directions")
	var launch_at: Vector2 = flight.position
	await frames(12)
	check(flight.linear_velocity.x < -100 and flight.position.x < launch_at.x - 15, "Closed-stash throw retains sideways momentum in the fall zone")
	check(flight.position.y < launch_at.y - 5, "Upward throws get modest visible airtime under normal stash gravity")
	check(storage.drag_overlay.is_visible_in_tree(), "Return-flight overlay remains visible when the stash panel is closed")
	await _snapshot("stash-closed-fall")
	await frames(260)
	check(flight != null and flight.get("returning") == false and not flight.freeze and flight.collision_layer == 1, "Captured item joins active hidden pile physics")
	check(flight.position.y > storage.pile.size.y * 0.5, "Captured item falls inside the stash before reopening")
	game._toggle_storage()
	await frames(3)
	for restored: RigidBody2D in storage.bodies.values():
		check(restored.collision_layer == 1 and restored.collision_mask == 3 and not restored.freeze, "Opening stash restores normal item collisions and motion")
	print("STASH PHYSICS POLISH RESULT: %d checks, %d failures" % [checks, failures])
	await preload("res://tests/automatic_combat_cleanup.gd").release(self, game, test_viewport)
	quit(1 if failures else 0)
