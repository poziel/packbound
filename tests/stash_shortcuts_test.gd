extends "res://tests/storage_ui_test.gd"

func shift_click(at: Vector2) -> void:
	_motion(at)
	var press := InputEventMouseButton.new()
	press.position = at
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.shift_pressed = true
	test_viewport.push_input(press, true)
	_mouse(at, false)

func _run() -> void:
	create_timer(30).timeout.connect(func() -> void: quit(2))
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
	shift_click(board.get_global_transform_with_canvas() * board.item_rect(item).get_center())
	check(item["cell"] == null and board.dragging.is_empty(), "Shift-click transfers a packed item to the stash")
	board.cancel_drag()
	item["cell"] = null
	storage.refresh()
	game._toggle_storage()
	await frames(4)
	var body: RigidBody2D = storage.bodies[item["id"]]
	await place(body, Vector2(180, 180))
	shift_click(body_point(body))
	check(item["cell"] != null and not storage.bodies.has(item["id"]), "Shift-click places a stashed item into available backpack space")
	# Full backpack: no swap, no lost item, no orientation mutation.
	game.run.items.clear()
	for y in PackRun.GRID.y:
		for x in PackRun.GRID.x:
			game.run.add_item("rusty_knife", Vector2i(x, y))
	var spare: Dictionary = game.run.add_item("rusty_knife")
	game._refresh()
	var spare_body: RigidBody2D = storage.bodies[spare["id"]]
	await place(spare_body, Vector2(180, 180))
	var original: Array[Dictionary] = game.run.items.duplicate(true)
	shift_click(body_point(spare_body))
	check(game.run.items == original and spare["cell"] == null and storage.bodies.has(spare["id"]), "Shift-click with a full backpack preserves the entire inventory")
	check(not storage.has_node("Count") and storage.get_node("Reorder").text.is_empty() and storage.get_node("Reorder").icon != null, "Stash header uses an icon-only reload control instead of count and text button")
	check(storage.get_node("Reorder").theme_type_variation == &"IconButton", "Reload control uses the shared yellow menu icon style")
	await _snapshot("stash-reload-header")
	game._close_storage()
	game.run.items.clear()
	var tossed: Dictionary = game.run.add_item("rusty_knife")
	storage.refresh()
	var canvas_at := Vector2(360, 300)
	storage.toss(tossed, canvas_at, Vector2(0, -3000))
	var flight: RigidBody2D = storage.bodies[tossed["id"]]
	check(flight.linear_velocity.y >= -550 and is_equal_approx(flight.gravity_scale, 0.42), "Closed-stash throw caps launch height and uses exact pile gravity")
	await frames(5)
	var catch_at: Vector2 = storage.pile.get_global_transform_with_canvas() * flight.position
	_motion(catch_at)
	_mouse(catch_at, true)
	check(storage.grabbed == flight and not flight.returning, "Returning item can be caught mid-air with the stash closed")
	if storage.grabbed != null:
		_mouse(catch_at, false)
		check(flight.returning and flight.collision_layer == 0, "Releasing a caught flight resumes isolated attraction")
	await frames(200)
	check(not flight.returning, "Released mid-air catch eventually falls below the screen and enters the stash")
	print("STASH SHORTCUTS RESULT: %d checks, %d failures" % [checks, failures])
	await preload("res://tests/automatic_combat_cleanup.gd").release(self, game, test_viewport)
	quit(1 if failures else 0)
