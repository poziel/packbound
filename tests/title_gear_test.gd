extends "res://tests/menu_test.gd"

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	check(not game.front.home.has_node("OptionsButton"), "Title screen has no separate Options button")
	check(game.settings_button.is_visible_in_tree() and not game.settings_button.disabled, "The corner settings gear is available on the title screen")
	check(game.front.quit_button.position.y >= game.front.play_button.get_rect().end.y + 12, "Play and Quit retain a clear gap with the current button theme")
	if game.front.home.has_node("OptionsButton") or not game.settings_button.is_visible_in_tree():
		await preload("res://tests/automatic_combat_cleanup.gd").release(self, game)
		quit(1)
		return
	await snapshot("title-gear/home")
	click(game.settings_button)
	await process_frame
	check(game.front.options.visible and not game.front.from_game and not game.modal.visible, "Title gear opens options directly")
	check(not game.settings_dock.visible, "Options does not show a redundant gear")
	key(KEY_ESCAPE)
	check(game.front.home.visible and game.settings_button.has_focus(), "Escape returns to the title and restores gear focus")
	game.front.play_button.grab_focus()
	key(KEY_DOWN)
	check(game.front.quit_button.has_focus(), "Down moves from Play to Quit")
	key(KEY_TAB)
	check(game.settings_button.has_focus(), "Keyboard navigation reaches the corner settings button")
	key(KEY_ENTER)
	check(game.front.options.visible, "Keyboard activates the title gear")
	click(game.front.back_button)
	check(game.front.home.visible and game.settings_button.has_focus(), "Back returns to the title gear")
	game.front.show_classes()
	await process_frame
	check(not game.settings_dock.visible, "The title gear stays scoped to the main menu")
	game.start_run("warrior", 42)
	await process_frame
	click(game.settings_button)
	check(game.modal.visible and game.modal_kind == "pause", "Gameplay gear retains the full-screen pause flow")
	game.show_menu()
	await process_frame
	check(game.settings_button.is_visible_in_tree() and not game.settings_button.disabled, "Returning from a run restores the title gear")
	await preload("res://tests/automatic_combat_cleanup.gd").release(self, game)
	print("TITLE GEAR RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
