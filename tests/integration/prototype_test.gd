extends "res://tests/support/prototype_support.gd"

func _run() -> void:
	render = DisplayServer.get_name() != "headless"
	_catalog_checks()
	_mechanics_checks()
	_progression_checks()
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	check(game.front.home.visible and not game.combat.visible, "Game starts at main menu")
	await _snapshot("v2-01-menu")
	_click(game.settings_button)
	check(game.front.options.visible, "Options opens from main menu")
	game.front.option_tabs.current_tab = 1
	await process_frame
	await process_frame
	var old_flash: bool = game.front.settings["flash"]
	_click(game.front.flash_toggle)
	check(game.front.settings["flash"] != old_flash, "Combat flash option changes actual setting")
	_click(game.front.flash_toggle)
	await _snapshot("v2-02-options")
	_click(game.front.back_button)
	_click(game.front.play_button)
	await game.loading_screen.finished
	check(game.front.selection.visible, "Play opens class selection")
	await _snapshot("v2-03-classes")
	for button in game.front.class_buttons.values():
		for child in button.get_children():
			if child is Label:
				check(Rect2(Vector2.ZERO, button.size).encloses(child.get_rect()), "Class label stays inside card: %s %s in %s" % [child.text, child.get_rect(), button.size])
	for character in PackCatalog.classes():
		# Containers arrange newly shown screens on the next frame.
		await process_frame
		await process_frame
		_click(game.front.class_buttons[character])
		await game.loading_screen.finished
		check(game.run.class_key == character and game.run.phase == PackRun.Phase.FIGHT, "Class selection starts " + character)
		check(not game.modal.visible, "Floor1 relic deferred for " + character)
		await _snapshot("v2-04-relic-" + character)
		game._open_reward(true)
		_click(game.choice_buttons[0])
		check(game.run.phase == PackRun.Phase.FIGHT and not game.modal.visible, "Relic choice makes the first attack available")
		_layout_checks()
		await _snapshot("v2-05-pack-" + character)
		check(game.action.text.is_empty() and game.action.accessibility_name == "Attack" and game.run.phase == PackRun.Phase.FIGHT, "Attack is available without a start step")
		var preview: Dictionary = game.run.outcome(game.run.effects())
		_click(game.action)
		await game.playback.monster_resolved
		game.playback.set_paused(true)
		check(game.run.hp == preview["hp_after"] and game.run.enemy["hp"] == preview["enemy_hp_after"], "Live preview matches turn for " + character)
		game.show_record()
		check(game.character_tabs.current_tab == _tab_index("Logs") and not game.history_view.text.is_empty(), "Battle record opens with events")
		await _snapshot("v2-06-record")
		# Return to preparation for the existing pause-menu and inventory checks.
		game.start_run(character, 42)
		game.character_tabs.current_tab = 0
		_click(game.settings_button)
		check(game.modal_kind == "pause", "Pause opens")
		await process_frame
		await process_frame
		_click(game.pause_buttons[1])
		check(game.front.options.visible and not game.combat.visible, "Options reachable from pause")
		_click(game.front.back_button)
		check(game.combat.visible and game.modal_kind == "pause", "Options returns to pause")
		await process_frame
		await process_frame
		_click(game.pause_buttons[0])
		check(not game.modal.visible and game.board.mouse_filter == Control.MOUSE_FILTER_STOP, "Resume restores inventory input")
		game.show_menu()
		_click(game.front.play_button)
		await game.loading_screen.finished
	await _drag_checks()
	await _ui_reward_checks()
	await _all_copy_checks()
	await _resolution_checks()
	report("RESULT")
	await preload("res://tests/support/automatic_combat_cleanup.gd").release(self, game)
	quit(1 if failures else 0)

