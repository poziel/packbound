extends "res://tests/support/prototype_support.gd"

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Rendered enemy checks require a display")
		quit(2)
		return
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_run("warrior", 42)
	var dungeon: Control = game.gameplay_background
	var index: int = 0
	for enemy: Dictionary in preload("res://systems/enemies/enemy_expansion.gd").profiles():
		game.run.fight = int(enemy.encounter_floor) - 1
		game.run.prepare_enemy(enemy)
		game._refresh()
		game.enemy_card.set_feedback_paused(true)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var bounds: Rect2 = dungeon.enemy_screen_bounds()
		check(dungeon.enemy.visible, "Visible in dungeon: " + enemy.key)
		check(bounds.has_area() and Rect2(0, 0, 1280, 720).encloses(bounds), "Full silhouette projects inside viewport: " + enemy.key)
		check(dungeon.enemy.texture.atlas == PackArt.ENEMY_TEXTURES[enemy.key], "Correct runtime texture: " + enemy.key)
		check(game.enemy_vitals.get_global_rect().end.y <= bounds.position.y - 8, "Vitals clear silhouette: " + enemy.key)
		if index % 6 == 0:
			root.get_texture().get_image().save_png(preload("res://tests/support/artifact_paths.gd").path("legacy_logs/expansion-battle-%s.png") % enemy.key)
		game.enemy_card.set_feedback_paused(false)
		index += 1
	report("ENEMY EXPANSION RENDER")
	await preload("res://tests/support/automatic_combat_cleanup.gd").release(self, game)
	quit(1 if failures else 0)
