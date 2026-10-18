extends SceneTree
## Render --fixed-fps 30 to inspect a representative wall-spider and mouse route.

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
	game._choose(0)
	var directory: String = "res://tests/output/dungeon/life-frames"
	DirAccess.make_dir_recursive_absolute(directory)
	var life: Node3D = game.gameplay_background.world.active_room.get_node("CorridorLife")
	life.critters["spider"]["cooldown"] = 100.0
	life.critters["mouse"]["cooldown"] = 100.0
	for frame in range(420):
		if frame == 10:
			life._begin_critter("spider", 0)
		if frame == 130:
			life._begin_critter("mouse", 0)
		await process_frame
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(directory + "/%04d.png" % frame)
	viewport.queue_free()
	await process_frame
	print("Rendered corridor life: 420 frames")
	quit()
