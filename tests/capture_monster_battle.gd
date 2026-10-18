extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(2)
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var game: Control = load("res://scenes/main.tscn").instantiate()
	viewport.add_child(game)
	await process_frame
	await process_frame
	game.start_run("warrior", 42)
	for index: int in [0, 8, 19]:
		game.run.fight = index
		game.run.prepare_enemy()
		game._refresh()
		game.modal.hide()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var path: String = "res://workspace/docs/art/concepts/monsters/roster-v1/battle-%s.png" % game.run.enemy["key"]
		var result := viewport.get_texture().get_image().save_png(path)
		if result != OK:
			printerr("Could not save ", path)
			quit(result)
			return
		print("MONSTER BATTLE CAPTURE: ", path)
	await preload("res://tests/automatic_combat_cleanup.gd").release(self, game, viewport)
	quit()
