extends SceneTree
## Capture the actual new-run flow with --fixed-fps 30.

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
	game.front.settings["combat_speed"] = 1
	if "--stairs-only" in OS.get_cmdline_user_args():
		game.start_run("warrior", 42)
	else:
		game._transition_start_run("warrior")
	var directory: String = "res://tests/output/dungeon/basement-frames"
	DirAccess.make_dir_recursive_absolute(directory)
	for frame in range(0 if "--stairs-only" in OS.get_cmdline_user_args() else 270):
		if frame == 60:
			game.action.pressed.emit()
		await process_frame
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(directory + "/%04d.png" % frame)
		if frame == 40:
			viewport.get_texture().get_image().save_png("res://tests/output/dungeon/basement-start.png")
	game.gameplay_background.prepare_entrance()
	game.enemy_card.hide()
	game.gameplay_background._advance_passage(0.74)
	game.gameplay_background.fade.hide()
	await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("res://tests/output/dungeon/basement-stairs.png")
	var icon: Image = load("res://assets/ui/icons/enter-dungeon/enter-dungeon.png").get_image()
	print("Entrance icon native size: ", icon.get_size(), "; alpha bounds: ", icon.get_used_rect())
	var review := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	review.fill(Color("111820"))
	review.blend_rect(icon, Rect2i(0, 0, 32, 32), Vector2i.ZERO)
	review.resize(128, 128, Image.INTERPOLATE_NEAREST)
	review.save_png("res://tests/output/dungeon/enter-dungeon-icon-4x.png")
	await preload("res://tests/automatic_combat_cleanup.gd").release(self, game, viewport)
	print("Rendered basement entrance preview: 270 frames")
	quit()
