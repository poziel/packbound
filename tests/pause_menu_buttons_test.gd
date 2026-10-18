extends "res://tests/menu_test.gd"

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.start_run("mage", 2468)
	game._act()
	game._open_pause_menu()
	await process_frame
	var restart: Button = game.pause_screen.get_node("%RestartButton")
	var resume: Button = game.pause_screen.get_node("%PauseButton1")
	var library: Button = game.pause_screen.get_node("%LibraryButton")
	var recipes: Button = game.pause_screen.get_node("%RecipesButton")
	var options: Button = game.pause_screen.get_node("%PauseButton2")
	check(game.playback.active and game.playback.paused, "Opening menu pauses active combat")
	check(resume.has_focus(), "Resume gets safe initial keyboard focus")
	check(restart.global_position.x < resume.global_position.x and restart.global_position.y == resume.global_position.y, "Restart sits left of Resume in one row")
	check(library.global_position.y < recipes.global_position.y and recipes.global_position.y < options.global_position.y, "Library and Recipes sit between run actions and Options")
	check(resume.get_theme_stylebox("normal").palette.face.g > resume.get_theme_stylebox("normal").palette.face.r, "Resume uses the light-green theme palette")
	check(is_equal_approx(library.global_position.y - resume.get_global_rect().end.y, 6), "Vertical button gap is six pixels")
	await snapshot("pause-menu-buttons/pause-menu")
	if OS.get_cmdline_user_args().has("--preview-only"):
		await preload("res://tests/automatic_combat_cleanup.gd").release(self, game)
		quit(1 if failures else 0)
		return
	var sequence: int = game.combat_sequence
	var turns: int = game.run.total_turns
	click(library)
	click(recipes)
	check(game.modal_kind == "pause" and game.playback.paused and game.run.total_turns == turns, "Placeholder buttons leave the paused run unchanged")
	click(restart)
	check(game.combat_sequence == sequence and game.modal_kind == "pause", "Clicking Restart cannot restart the run")
	_hold_pointer(restart, true)
	await create_timer(0.12).timeout
	_hold_pointer(restart, false)
	check(game.combat_sequence == sequence and restart.hold_progress == 0, "Releasing Restart early cancels")
	click(resume)
	check(not game.modal.visible and game.playback.active and not game.playback.paused, "Resume continues the current combat")
	check(game.combat_sequence == sequence, "Resume never resets the run")
	game._open_pause_menu()
	click(options)
	await process_frame
	await process_frame
	check(game.front.options.visible and game.playback.paused, "Options keeps combat paused")
	click(game.front.back_button)
	check(game.modal.visible and game.modal_kind == "pause" and resume.has_focus(), "Back from Options restores pause menu and Resume focus")
	game.run.hp = 7
	game.run.fight = 3
	game.run.total_turns = 12
	game.elapsed = 180
	game.run.relics.append(PackCatalog.RELICS[0])
	_hold_pointer(restart, true)
	await create_timer(1.35).timeout
	_hold_pointer(restart, false)
	if game.loading_screen.active:
		await game.loading_screen.finished
	check(game.combat_sequence > sequence, "Completed hold starts a new run")
	check(game.run.class_key == "mage", "Restart preserves selected character class")
	check(game.run.fight == 0 and game.run.total_turns == 0 and game.run.hp == game.run.max_hp, "Restart resets floor, turns and health")
	check(game.run.relics.is_empty() and game.run.items.size() == 3, "Restart resets equipment and relic progression to starter loadout")
	check(game.elapsed < 1 and game.log_stage_index == -1 and game.storage.grabbed == null, "Restart resets elapsed time and navigation")
	check(not game.playback.active and game.run.pending_turn.is_empty(), "Restart cancels pending combat response")
	check(game.combat.visible and not game.modal.visible and not game.front.visible, "Restart returns directly to the fresh run")
	sequence = game.combat_sequence
	await create_timer(1.6).timeout
	check(game.run.total_turns == 0 and game.run.hp == game.run.max_hp, "Cancelled old combat cannot damage the new run")
	restart.confirmed.emit()
	check(game.combat_sequence == sequence, "Confirmation outside pause menu is ignored")
	game._open_pause_menu()
	_hold_pointer(restart, true)
	await create_timer(0.08).timeout
	key(KEY_ESCAPE)
	await create_timer(0.3).timeout
	_hold_pointer(restart, false)
	check(game.combat_sequence == sequence and not game.modal.visible, "Escape cancels an in-progress restart hold")
	await preload("res://tests/automatic_combat_cleanup.gd").release(self, game)
	print("PAUSE MENU BUTTONS RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _hold_pointer(button: Button, down: bool) -> void:
	var point := button.get_global_rect().get_center()
	motion(point)
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	root.push_input(event, true)
