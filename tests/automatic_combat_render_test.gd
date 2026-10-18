extends "res://tests/battle_ui_test.gd"

func _run() -> void:
	create_timer(35).timeout.connect(func() -> void: printerr("Rendered QA timeout"); quit(2))
	check(DisplayServer.get_name() != "headless", "QA uses a graphics-enabled renderer")
	test_viewport = SubViewport.new()
	test_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	test_viewport.size_2d_override = Vector2i(1280, 800)
	test_viewport.size_2d_override_stretch = true
	root.add_child(test_viewport)
	game = load("res://scenes/main.tscn").instantiate()
	test_viewport.add_child(game)
	await process_frame
	for dimensions: Vector2i in [Vector2i(1280, 800), Vector2i(800, 500)]:
		test_viewport.size = dimensions
		game.start_run("warrior", 42)
		game.front.settings["combat_speed"] = 4
		game.run.relics.clear()
		game.run.items.clear()
		for index in range(4):
			game.run.add_item("spark_ring", Vector2i(index, 0))["mana"] = 6
		game.run.add_item("rusty_knife", Vector2i(0, 2))["damage"] = 8
		game.run.enemy["hp"] = 1000
		game.run.enemy["max_hp"] = 1000
		game.run.enemy["attacks"] = [0]
		game._refresh()
		await _capture("preparation", dimensions)
		game._act()
		await game.playback.monster_resolved
		await _capture("automatic-round", dimensions)
		game.playback.set_paused(true)
		game.character_tabs.current_tab = _tab_index("Logs")
		await _capture("paused-logs", dimensions)
		check(game.playback.paused and game.run.combat_state == PackRun.CombatState.PAUSED, "Captured pause retains inspectable combat")
		game.character_tabs.current_tab = 0
		game.run.enemy["hp"] = 1
		game.run.items[-1]["damage"] = 10000
		game.playback.set_paused(false)
		while game.playback.active or game.busy or game.gameplay_background.transitioning:
			await process_frame
		check(game.run.fight == 1 and game.run.combat_state == PackRun.CombatState.PREPARING and game.run.total_turns >= 2, "Rendered next room waits in preparation")
		await _capture("next-room-preparation", dimensions)
	await preload("res://tests/automatic_combat_cleanup.gd").release(self, game, test_viewport)
	print("AUTOMATIC RENDER RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _capture(label: String, dimensions: Vector2i) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var picture: Image = test_viewport.get_texture().get_image()
	check(picture.get_size() == dimensions and not picture.is_empty(), "Actual framebuffer size: " + label + str(dimensions))
	picture.save_png("res://tests/output/automatic-combat/task5-%s-%dx%d.png" % [label, dimensions.x, dimensions.y])
