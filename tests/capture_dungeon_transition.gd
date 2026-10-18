extends SceneTree
## Render a deterministic preview with --fixed-fps 30 (no desktop capture).

func _initialize() -> void:
	_capture.call_deferred()

func _capture() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var game: Control = load("res://scenes/main.tscn").instantiate()
	viewport.add_child(game)
	await process_frame
	game.start_run("warrior", 42)
	game.front.settings["combat_speed"] = 1
	var directory: String = "res://tests/output/dungeon/preview-frames"
	DirAccess.make_dir_recursive_absolute(directory)
	for frame in range(240):
		if frame == 15:
			game.run.enemy["hp"] = 0
			game.run.phase = PackRun.Phase.LOOT
			game.run.roll_loot()
			game._show_phase_modal()
		await process_frame
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(directory + "/%04d.png" % frame)
	viewport.queue_free()
	await process_frame
	print("Rendered departure and arrival preview: 240 frames")
	quit()
