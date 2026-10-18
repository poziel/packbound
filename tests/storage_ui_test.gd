extends "res://tests/battle_ui_test.gd"

func frames(count: int) -> void:
	for i in count:
		await physics_frame
	await process_frame

func body_point(body: RigidBody2D) -> Vector2:
	return game.storage.pile.get_global_transform_with_canvas() * body.to_global(body.origin + Vector2.ONE * PackStorage.TILE * 0.5)

func place(body: RigidBody2D, at: Vector2) -> void:
	body.freeze = true
	body.release_at(at, 0.0, Vector2.ZERO)
	await frames(3)
	body.freeze = false
	body.sleeping = false
	await frames(2)

func _run() -> void:
	create_timer(40).timeout.connect(func() -> void: quit(2))
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
	var item: Dictionary = game.run.add_item("rusty_knife", Vector2i.ZERO)
	game._refresh()
	var board: BackpackBoard = game.board
	var storage: PackStorage = game.storage
	await frames(3)
	var at: Vector2 = board.get_global_transform_with_canvas() * board.item_rect(item).get_center()
	_motion(at)
	_mouse(at, true)
	check(board.dragging == item, "Packed item starts dragging")
	at = game.storage_button.get_global_rect().get_center()
	_motion(at)
	_mouse(at, false)
	check(item["cell"] == null and board.dragging.is_empty(), "Closed stash button accepts items")
	await frames(30)
	game._toggle_storage()
	await frames(3)
	check(storage.visible and storage.bodies.has(item["id"]), "Opening stash exposes physics body")
	var body: RigidBody2D = storage.bodies[item["id"]]
	check((-body.origin * 2.0).is_equal_approx(board.footprint(item["shape"])), "Stash and backpack use identical item dimensions")
	await place(body, Vector2(160, 100))
	var start_y: float = body.position.y
	await frames(30)
	check(body.position.y > start_y + 20, "Gentle gravity makes items fall")
	await frames(230)
	check(body.bounds().end.y <= storage.pile.size.y + 3, "Floor contains falling items")
	check(absf(body.linear_velocity.y) < 40, "Dropped item settles")
	_motion(body_point(body))
	await create_timer(0.5).timeout
	check(game.inspector.windows.size() == 1, "Physics item hover opens inspection")
	game.inspector.clear()
	# Pick, pull and release using actual viewport pointer events.
	_mouse(body_point(body), true)
	check(storage.grabbed == body and board.dragging.is_empty(), "Grabbing inside stash keeps a physical item")
	check(not body.freeze, "Held item remains a live physics body")
	check(body.gravity_scale == 0.0 and body.physics_material_override.friction == 0.0, "Held body disables gravity and friction")
	var angle_before: float = body.rotation
	_key(KEY_E)
	await frames(14)
	check(is_equal_approx(body.rotation, angle_before + PI * 0.5), "E rotates held stash item clockwise")
	_key(KEY_Q)
	await frames(14)
	check(is_equal_approx(body.rotation, angle_before), "Q reverses held stash rotation")
	var target: Vector2 = storage.pile.get_global_transform_with_canvas() * Vector2(280, 110)
	_motion(target)
	check((storage.pile.get_global_transform_with_canvas() * body.to_global(storage.grab_local)).distance_to(target) < 0.1, "Held item follows a fast pointer move immediately")
	await frames(18)
	check((storage.pile.get_global_transform_with_canvas() * body.to_global(storage.grab_local)).distance_to(target) < 0.1, "Gravity cannot pull a held item away from the cursor")
	_motion(target + Vector2(40, 0))
	await frames(2)
	var fling := InputEventMouseMotion.new()
	fling.position = target + Vector2(100, 0)
	fling.velocity = Vector2.ZERO # Platform speed sampling can lag behind the pointer.
	test_viewport.push_input(fling, true)
	_mouse(fling.position, false)
	check(storage.grabbed == null and body.linear_velocity.length() > 20, "Release retains throwing momentum")
	var release_x: float = body.position.x
	await frames(2)
	check(body.position.x > release_x + 5, "Throw moves on the next physics steps even when platform velocity is zero")
	check(body.gravity_scale > 0.0 and body.physics_material_override.friction > 0.0, "Release restores normal physics")
	await frames(100)
	# Exact L mask: bottom right is neither clickable nor collidable.
	var elbow: Dictionary = game.run.add_item("healing_herbs")
	elbow["mask"] = [Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1)]
	elbow["rotation"] = 0
	elbow["shape"] = Vector2i(2, 2)
	game._refresh()
	var lbody: RigidBody2D = storage.bodies[elbow["id"]]
	lbody.position = Vector2(100, 100)
	lbody.rotation = 0
	lbody.freeze = true
	await frames(2)
	check(lbody.get_child_count() == 3, "L shape has three occupied-tile colliders")
	check(not lbody.contains_point(lbody.to_global(Vector2(18, 18))), "Missing L corner remains empty for picking")
	var query := PhysicsPointQueryParameters2D.new()
	query.position = lbody.to_global(Vector2(18, 18))
	check(storage.world.world_2d.direct_space_state.intersect_point(query).is_empty(), "Missing L corner remains empty for collisions")
	lbody.freeze = false
	# Stack two bodies, then yank the lower one through the upper one.
	await place(body, Vector2(300, storage.pile.size.y - 32))
	await place(lbody, Vector2(300, storage.pile.size.y - 100))
	await frames(12)
	storage.grabbed = body
	storage.grab_local = Vector2.ZERO
	storage._begin_hold()
	for step in range(8):
		storage.target = Vector2(300, storage.pile.size.y - 32 - step * 12)
		storage._follow_pointer()
		await frames(2)
	check(lbody.linear_velocity.length() > 30, "Pulling bottom item transfers motion to item above")
	storage._release_grab(false)
	# Pull out of pile into the existing backpack drag and commit.
	await place(body, Vector2(130, 160))
	_motion(body_point(body))
	_mouse(body_point(body), true)
	check(storage.grabbed == body, "Item can be grabbed again")
	at = board.get_global_transform_with_canvas() * (BackpackBoard.ORIGIN + Vector2(32, 32))
	_motion(at)
	check(board.dragging == item and storage.grabbed == body, "Crossing panels keeps the same held physics item and previews placement")
	check((storage.pile.get_global_transform_with_canvas() * body.to_global(storage.grab_local)).distance_to(at) < 0.1, "Crossing panels preserves the exact grab point")
	_mouse(at, false)
	check(item["cell"] == Vector2i.ZERO and not storage.bodies.has(item["id"]), "Backpack transfer removes exactly one physics body")
	await frames(18)
	board.begin_drag(item, board.item_rect(item).get_center())
	at = storage.pile.get_global_transform_with_canvas() * Vector2(190, 180)
	_motion(at)
	check(board.dragging.is_empty() and storage.grabbed != null and item["cell"] == null, "Crossing into left panel switches to stash mode before release")
	check((storage.pile.get_global_transform_with_canvas() * storage.grabbed.to_global(storage.grab_local)).distance_to(at) < 0.1, "Panel handoff preserves the exact cursor grab point")
	_mouse(at, false)
	check(storage.grabbed == null and not storage.bodies[item["id"]].freeze, "Releasing after panel crossing enables gravity")
	# Restore a packed item to also exercise direct drop callers.
	item["cell"] = Vector2i.ZERO
	board.refresh()
	board.begin_drag(item, board.item_rect(item).get_center())
	board.throw_velocity = Vector2(220, -250)
	board.throw_time_msec = Time.get_ticks_msec()
	at = board.get_global_transform_with_canvas().affine_inverse() * (storage.pile.get_global_transform_with_canvas() * Vector2(180, 180))
	board.drop_at(at)
	check(item["cell"] == null and storage.bodies[item["id"]].linear_velocity.y < 0, "Open-stash drop preserves upward throwing velocity")
	check(not board.item_motions.has(item["id"]), "Open-stash toss uses physics immediately")
	await frames(80)
	await place(lbody, Vector2(140, 180))
	_motion(body_point(lbody))
	_mouse(body_point(lbody), true)
	check(storage.grabbed == lbody, "Irregular item is picked for rotation transfer")
	var before_elbow_angle: float = storage.held_angle
	_key(KEY_E)
	await frames(14)
	var rotation_target: Vector2 = storage.pile.get_global_transform_with_canvas() * storage.target
	check((storage.pile.get_global_transform_with_canvas() * lbody.to_global(storage.grab_local)).distance_to(rotation_target) < 0.1, "Rotating an irregular item preserves the cursor pivot")
	_motion(Vector2(650, 300))
	await _snapshot("physics-stash-held-seam")
	check(storage.grabbed == lbody and is_equal_approx(storage.held_angle, before_elbow_angle + PI * 0.5), "Crossing the panel seam preserves the held body's angle (before %s, after %s)" % [before_elbow_angle, storage.held_angle])
	at = board.get_global_transform_with_canvas() * (BackpackBoard.ORIGIN + Vector2(3, 2) * BackpackBoard.STEP + Vector2(100, 32))
	_motion(at)
	_mouse(at, false)
	check(elbow["cell"] == Vector2i(3, 2) and elbow["rotation"] == 1, "Rotated L item commits the matching grid orientation (cell %s, rotation %s, grab %s)" % [elbow["cell"], elbow["rotation"], board.grab])
	board.begin_drag(elbow, board.item_rect(elbow).get_center())
	board.drop_at(board.get_global_transform_with_canvas().affine_inverse() * (storage.pile.get_global_transform_with_canvas() * Vector2(140, 180)))
	check(elbow["cell"] == null and storage.bodies[elbow["id"]].points == PackRun.offsets(elbow), "Returning rotated L item keeps its correct stash colliders")
	await frames(90)
	await _snapshot("physics-stash")
	var before: int = game.run.items.size()
	game._close_storage()
	check(storage.grabbed == null, "Closing stash cancels physical grab")
	for candidate: RigidBody2D in storage.bodies.values():
		check(not candidate.freeze, "Hidden stash continues simulating its pile")
	game._toggle_storage()
	check(game.run.items.size() == before, "Reopening preserves item ownership")
	check(storage.has_node("Reorder"), "Stash includes an accessible Reorder button")
	check(storage.has_method("reorder"), "Stash exposes pile recovery")
	if storage.has_method("reorder"):
		var lost: RigidBody2D = storage.bodies[item["id"]]
		lost.freeze = true
		lost.position = Vector2(-800, 1000)
		lost.set_meta("waiting", true)
		lost.hide()
		_click(storage.get_node("Reorder"))
		await frames(4)
		check(Rect2(Vector2.ZERO, storage.pile.size).encloses(lost.bounds()), "Reorder recovers an escaped item")
		check(lost.visible and not lost.freeze, "Reorder recovers hidden or waiting items as well")
		check(game.run.items.size() == before, "Reorder preserves every owned item")
		lost.teleport(Vector2(-800, 1000), 0.7, Vector2(-1800, 1200))
		await frames(4)
		check(Rect2(Vector2.ONE * -1, storage.pile.size + Vector2.ONE * 2).encloses(lost.bounds()), "Automatic containment recovers escaped bodies without clicking Reorder")
	game.start_run("mage", 42)
	check(not storage.visible and storage.grabbed == null, "New run closes stash and clears grab")
	for candidate: RigidBody2D in storage.bodies.values():
		check(game.run.items.has(candidate.item), "New run has no stale physics items")
	print("STORAGE UI RESULT: %d checks, %d failures" % [checks, failures])
	await preload("res://tests/automatic_combat_cleanup.gd").release(self, game, test_viewport)
	quit(1 if failures else 0)
