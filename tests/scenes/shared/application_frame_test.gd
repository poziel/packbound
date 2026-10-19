extends "res://tests/support/menu_support.gd"

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var frame: Control = game.get_node_or_null("ApplicationFrame")
	check(frame != null, "Every screen has a reusable solid application frame")
	var pause_screen: Control = game.modal.get_node_or_null("PauseScreen")
	check(pause_screen != null, "Pause navigation has a dedicated full-screen surface")
	var style: StyleBox = frame.get_node("Border").get_theme_stylebox("panel")
	check(not style.draw_center and style.border_color.a == 1.0, "The shared frame has opaque solid edges and a transparent center")
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		check(style.get("border_width") == 5, "Frame edges are consistently five pixels")
	check(game.settings_dock.visible, "Main menu exposes the shared corner settings dock")
	await snapshot("application-frame/home")
	game.front.show_classes()
	await snapshot("application-frame/classes")
	game.front.show_options()
	await snapshot("application-frame/options")
	game.start_run("warrior", 42)
	await process_frame
	await process_frame
	check(game.settings_dock.visible and game.settings_button.is_visible_in_tree(), "Gameplay exposes the frame's settings button")
	check(not game.combat.has_node("CharacterPanel/PauseButton"), "The frame gear replaces the removed header pause control")
	check(game.get_global_rect().encloses(game.settings_button.get_global_rect()), "The complete settings button fits inside the application frame")
	check(game.settings_button.get_global_rect().position.x > game.size.x - 70 and game.settings_button.global_position.y == 5, "Settings sits at the top right inside the frame")
	await snapshot("application-frame/gameplay")
	click(game.settings_button)
	await process_frame
	check(game.modal_kind == "pause" and game.modal.visible and pause_screen.is_visible_in_tree(), "Settings opens the full-screen pause navigation")
	check(pause_screen.get_global_rect() == game.get_global_rect(), "Pause screen fills the entire viewport")
	check(not game.modal.get_node("Dimmer").visible and not game.modal.get_node("DialogFrame").visible and not game.modal_title.visible and not game.close_button.visible, "Pause uses its own full-screen surface without the old floating dialog")
	check(not game.settings_dock.visible, "Settings dock is hidden while its pause screen is open")
	check(game.pause_buttons[0].has_focus(), "Pause screen focuses Resume for keyboard navigation")
	await snapshot("application-frame/pause")
	click(game.pause_buttons[1])
	await process_frame
	check(game.front.options.visible and not game.combat.visible, "Options opens the full-screen tabbed preferences")
	click(game.front.back_button)
	await process_frame
	check(game.modal.visible and pause_screen.is_visible_in_tree(), "Back from Options returns to the full-screen pause navigation")
	click(game.pause_buttons[0])
	await process_frame
	check(game.combat.visible and not game.modal.visible, "Resume returns to the current run")
	# Start a durable, nonlethal combat exchange and freeze it through actual UI input.
	game.run.enemy["hp"] = 10000
	game.run.enemy["max_hp"] = 10000
	game.run.hp = game.run.max_hp
	game._act()
	await process_frame
	check(game.playback.active, "Combat begins before opening the frame menu")
	click(game.settings_button)
	await process_frame
	var remaining: float = game.playback.remaining_seconds
	var turns: int = game.run.total_turns
	check(game.playback.paused and game.modal_kind == "pause", "Frame settings pauses active combat")
	await create_timer(0.25).timeout
	check(is_equal_approx(remaining, game.playback.remaining_seconds) and game.run.total_turns == turns, "Full-screen pause freezes the exchange timing and turn count")
	click(game.pause_buttons[1])
	await process_frame
	check(game.playback.paused and game.front.options.visible, "Combat remains paused in Options")
	key(KEY_ESCAPE)
	await process_frame
	check(game.modal.visible and pause_screen.is_visible_in_tree() and game.playback.paused, "Escape from Options returns to the paused full-screen navigation")
	click(game.pause_buttons[0])
	check(game.playback.active and not game.playback.paused and game.run.total_turns == turns, "Resume continues the same exchange without starting an extra turn")
	key(KEY_ESCAPE)
	await process_frame
	check(game.modal.visible and game.playback.paused, "Escape opens the same full-screen pause during combat")
	key(KEY_ESCAPE)
	check(not game.modal.visible and not game.playback.paused, "Escape returns from the full-screen pause and resumes a running exchange")
	game.playback.set_paused(true)
	await process_frame
	click(game.settings_button)
	await process_frame
	key(KEY_ESCAPE)
	check(game.playback.paused and not game.modal.visible, "Closing the screen preserves an existing inspectable combat pause")
	await process_frame
	click(game.settings_button)
	await process_frame
	click(game.pause_buttons[0])
	check(game.playback.active and not game.playback.paused, "Resume explicitly continues combat even if it was already paused before opening settings")
	# Reward chooser retains its dedicated panel and close behavior.
	game.show_menu()
	game.start_run("warrior", 42)
	game._open_reward(true)
	check(game.modal_kind == "reward" and not pause_screen.visible and game.reward_panel.visible and game.reward_close_button.visible, "Reward dialogs retain their existing presentation")
	game._close_modal()
	game._open_pause_menu()
	click(game.pause_buttons[2])
	check(game.front.home.visible and not game.combat.visible, "Pause navigation returns to the main menu")
	game.start_run("warrior", 42)
	game._open_pause_menu()
	root.content_scale_size = Vector2i.ZERO
	for dimensions: Vector2i in [Vector2i(800, 500), Vector2i(1280, 800), Vector2i(1600, 900)]:
		root.size = dimensions
		await create_timer(0.1).timeout
		check(pause_screen.get_global_rect() == game.get_global_rect() and frame.get_global_rect() == game.get_global_rect(), "Pause and the shared frame track the viewport size")
		for button: Button in game.pause_buttons:
			check(game.get_global_rect().grow(-5).encloses(button.get_global_rect()), "Full-screen pause controls fit at %s" % dimensions)
		await snapshot("application-frame/pause-%dx%d" % [dimensions.x, dimensions.y])
	await preload("res://tests/support/automatic_combat_cleanup.gd").release(self, game)
	report("APPLICATION FRAME RESULT")
	quit(1 if failures else 0)
