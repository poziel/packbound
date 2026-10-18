extends SceneTree
## Run with --fixed-fps 30 to capture the actual shader and navigation timing.

func _initialize() -> void:
	_capture.call_deferred()

func _capture() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var game: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var directory: String = "res://.tmp/loading-screen/frames"
	DirAccess.make_dir_recursive_absolute(directory)
	var covered_frames: int = 0
	var failures: int = 0
	for frame in range(105):
		if frame == 9:
			game.front.play_button.pressed.emit()
		if frame == 42:
			game.front._choose_class("warrior")
		if frame == 75:
			game._transition_to_menu()
		await process_frame
		await RenderingServer.frame_post_draw
		var picture: Image = root.get_texture().get_image()
		picture.save_png(directory + "/%03d.png" % frame)
		if game.loading_screen.coverage == 1.0:
			covered_frames += 1
			var ink: Color = picture.get_pixel(0, 0)
			for y in range(0, picture.get_height(), 43):
				for x in range(0, picture.get_width(), 47):
					if not picture.get_pixel(x, y).is_equal_approx(ink):
						failures += 1
	if covered_frames == 0:
		failures += 1
	print("LOADING SCREEN RENDER: ", covered_frames, " fully covered frames, ", failures, " pixel failures")
	await preload("res://tests/automatic_combat_cleanup.gd").release(self, game)
	quit(1 if failures else 0)
