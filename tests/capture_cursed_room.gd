extends SceneTree
## Render the biome using the actual gameplay viewport, plus its fly-camera demo.
func _initialize() -> void:
	_capture.call_deferred()

func _capture() -> void:
	create_timer(40).timeout.connect(func() -> void: printerr("Cursed capture timed out"); quit(2))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var game: Control = load("res://scenes/main.tscn").instantiate()
	viewport.add_child(game)
	await process_frame
	game.gameplay_background.encounter_room = load("res://scenes/gameplay/rooms/cursed/cursed_room.tscn")
	game.start_run("warrior", 42)
	var directory := "res://tests/output/cursed-depths/review"
	DirAccess.make_dir_recursive_absolute(directory)
	if "--video" in OS.get_cmdline_user_args():
		DirAccess.make_dir_recursive_absolute(directory + "/frames")
		game.gameplay_background.transitioning = true
		game.gameplay_background.fade.show()
		for frame: int in range(180):
			var arrival: float = minf(frame / 89.0, 1.0)
			game.gameplay_background._reveal_room(arrival)
			if frame == 90:
				game.gameplay_background.fade.hide()
				game.gameplay_background.transitioning = false
			await process_frame
			await RenderingServer.frame_post_draw
			viewport.get_texture().get_image().save_png(directory + "/frames/%04d.png" % frame)
		game.gameplay_background.fade.hide()
		game.gameplay_background.transitioning = false
	for index: int in range(6):
		if index > 0:
			game.gameplay_background.world.arrive_camera(index / 5.0)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(directory + "/gameplay-%d.png" % index)
	await preload("res://tests/automatic_combat_cleanup.gd").release(self, game, viewport)
	var demo_view := SubViewport.new()
	demo_view.size = Vector2i(1280, 800)
	demo_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(demo_view)
	var demo: Node3D = load("res://scenes/gameplay/rooms/cursed/demo.tscn").instantiate()
	demo_view.add_child(demo)
	for index: int in range(3):
		if index == 1:
			demo.get_node("Camera").position = Vector3(-4.2, 3.5, 5)
			demo.get_node("Camera").rotation = Vector3(-0.08, 0.33, 0)
		elif index == 2:
			demo.get_node("Camera").position = Vector3(-7, 3.5, 6)
			demo.get_node("Camera").rotation = Vector3(0.3, -0.2, 0)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		demo_view.get_texture().get_image().save_png(directory + "/room-%d.png" % index)
	demo.queue_free()
	demo_view.queue_free()
	await process_frame
	print("Rendered cursed biome in gameplay and inspection demo")
	quit()
