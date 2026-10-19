extends "res://tests/support/storage_ui_support.gd"

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
	var item: Dictionary = game.run.add_item("rusty_knife")
	game._refresh()
	var storage: PackStorage = game.storage
	storage.toss(item, Vector2(530, 320), Vector2(500, 0))
	await frames(45)
	check(item["cell"] != null and not storage.bodies.has(item["id"]), "A flying item entering the grid snaps into a free cell")
	check(game.run.items.size() == 1, "Automatic grid capture preserves item identity and count")
	await _snapshot("stash-flight-grid-capture")
	# A shortcut starts its flight over the grid; it must not catch itself there.
	if item["cell"] == null:
		item["cell"] = Vector2i.ZERO
		storage.refresh()
	storage.quick_transfer(item)
	await frames(6)
	check(item["cell"] == null and storage.bodies.has(item["id"]), "Shift-click storage flight does not immediately repack itself")
	game.run.items.clear()
	for y in PackRun.GRID.y:
		for x in PackRun.GRID.x:
			game.run.add_item("rusty_knife", Vector2i(x, y))
	var spare: Dictionary = game.run.add_item("rusty_knife")
	game._refresh()
	var packed_before: Array[Dictionary] = game.run.items.duplicate(true)
	storage.toss(spare, Vector2(530, 320), Vector2(500, 0))
	await frames(45)
	check(spare["cell"] == null and storage.bodies.has(spare["id"]), "Full grid leaves the item in gravity mode")
	check(game.run.items == packed_before and game.board.dragging.is_empty(), "Flying item does not swap or displace packed items")
	report("STASH GRID REENTRY RESULT")
	await preload("res://tests/support/automatic_combat_cleanup.gd").release(self, game, test_viewport)
	quit(1 if failures else 0)
