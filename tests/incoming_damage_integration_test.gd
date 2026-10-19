extends "res://tests/automatic_combat_test.gd"

func _run() -> void:
	create_timer(25).timeout.connect(func() -> void: printerr("Incoming feedback timeout"); quit(2))
	test_viewport = SubViewport.new()
	test_viewport.size = Vector2i(1280, 800)
	test_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(test_viewport)
	game = load("res://scenes/main.tscn").instantiate()
	test_viewport.add_child(game)
	await process_frame
	game.run_saves.directory = "res://workspace/logs/incoming-feedback-saves"
	_fixture(1)
	game.run.max_hp = 30
	game.run.hp = 30
	game.run.enemy["hp"] = 100
	game.run.enemy["max_hp"] = 100
	game._refresh()
	game._act()
	check(game.enemy_bar.damage_trail_ratio > game.enemy_bar.ratio, "Enemy lost-health segment is retained at player impact")
	if DisplayServer.get_name() != "headless":
		game.playback.set_paused(true)
		game.enemy_bar.set_glow_paused(false)
		game.enemy_bar.advance_damage(0.12)
		game.enemy_bar.set_glow_paused(true)
		await process_frame
		await RenderingServer.frame_post_draw
		test_viewport.get_texture().get_image().save_png("res://workspace/logs/enemy-health-trail.png")
		game.playback.set_paused(false)
	await game.playback.monster_resolved
	game.playback.set_paused(true)
	check(game.hp_bar.value < 30, "Monster response reduces displayed health")
	check(game.hp_bar.damage_trail_ratio > game.hp_bar.ratio, "Player lost-health segment is retained")
	check(not game.transition_popups.effect_popups.is_empty(), "Actual monster response creates incoming feedback")
	# Advance a little solely for an inspectable frozen render.
	game._combat_pause_changed(false)
	game.transition_popups._process(0.35)
	game.hp_bar.advance_damage(0.12)
	game._combat_pause_changed(true)
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		test_viewport.get_texture().get_image().save_png("res://workspace/logs/incoming-feedback-1280.png")
		test_viewport.size = Vector2i(800, 500)
		await process_frame
		game.transition_popups.clear()
		game.transition_popups.show_player_hit({"taken": 12, "blocked": 8})
		game.transition_popups.paused = false
		game.transition_popups._process(0.35)
		game.transition_popups.paused = true
		await process_frame
		await RenderingServer.frame_post_draw
		test_viewport.get_texture().get_image().save_png("res://workspace/logs/incoming-feedback-800.png")
	game._cancel_combat()
	check(game.transition_popups.effect_popups.is_empty(), "Cancel clears incoming feedback")
	check(game.hp_bar.damage_trail_ratio == game.hp_bar.ratio, "Cancel clears health trail")
	await preload("res://tests/automatic_combat_cleanup.gd").release(self, game, test_viewport)
	print("INCOMING INTEGRATION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
