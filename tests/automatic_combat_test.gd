extends "res://tests/battle_ui_test.gd"

func _run() -> void:
	create_timer(55).timeout.connect(func() -> void: printerr("Automatic combat timeout"); quit(2))
	test_viewport = SubViewport.new()
	test_viewport.size = Vector2i(1280, 800)
	root.add_child(test_viewport)
	game = load("res://scenes/main.tscn").instantiate()
	test_viewport.add_child(game)
	await process_frame
	await process_frame
	for speed: int in [1, 2, 3, 4]:
		_fixture(speed)
		game._act()
		game._act()
		check(game.run.total_turns == 1 and game.playback.paused, "Second action pauses without another champion action")
		game._act()
		check(not game.playback.paused and game.run.total_turns == 1, "Third action resumes without another champion action")
		await create_timer(0.04 / speed).timeout
		await _frozen_check("impact", 0.23)
		game.playback.set_paused(false)
		await create_timer(0.20 / speed).timeout
		await _frozen_check("response", 1.65)
		var remaining: float = game.playback.remaining_seconds
		var started: int = Time.get_ticks_msec()
		game.playback.set_paused(false)
		game.playback.set_paused(false)
		while game.run.turn == 1:
			await process_frame
		var duration: float = (Time.get_ticks_msec() - started) / 1000.0
		check(duration >= remaining - 0.04 and duration < remaining + 0.15, "Resume consumes remaining wait at %dx" % speed)
		check(game.run.total_turns == 1 and game.run.turn == 2, "Response commits once before another action")
		await _frozen_check("strike", 0.24)
		game.playback.set_paused(false)
		while game.run.total_turns < 3:
			await process_frame
		check(game.busy and not game.action.disabled, "One click advances three rounds while controls stay locked")
		game.show_pause()
		check(game.playback.paused and game.settings_button.visible and not game.settings_button.disabled and not game.modal.visible, "Combat remains inspectable with the shared gear available")
		game.character_tabs.current_tab = _tab_index("Logs")
		await process_frame
		check(game.inspector.enabled and not paused, "Inspection and UI tree remain live")
		game.settings_button.pressed.emit()
		check(game.modal.visible and game.playback.paused, "The shared gear opens the paused screen")
		game._close_modal()
		check(game.playback.paused and game.run.combat_state == PackRun.CombatState.PAUSED, "Closing menu retains paused model")
		check(game.board.mouse_filter == Control.MOUSE_FILTER_STOP and not game.run.can_edit_inventory(), "Closing paused menu preserves inspection and inventory lock")
		game._open_options()
		game._resume_options()
		check(game.playback.paused and game.combat.visible and not game.modal.visible, "Returning from options keeps inspectable pause")
		game.show_pause()
		check(not game.playback.paused, "Top Resume continues same fight")
		await _reset_check()
	for pause_first: bool in [false, true]:
		for stage: String in ["impact", "response", "strike"]:
			_fixture(4)
			game._act()
			if stage == "response":
				await create_timer(0.1).timeout
			elif stage == "strike":
				while game.run.turn == 1:
					await process_frame
			if pause_first:
				game.playback.set_paused(true)
			await _reset_check()
			await create_timer(0.45).timeout
			check(game.run.total_turns == 0 and not game.playback.active, "Cancel cannot affect fresh run: " + stage)
			_fixture(4)
			game._act()
			if stage == "response":
				await create_timer(0.1).timeout
			elif stage == "strike":
				while game.run.turn == 1:
					await process_frame
			if pause_first:
				game.playback.set_paused(true)
			game.show_menu()
			await _reset_check()
			await create_timer(0.45).timeout
			check(game.run.total_turns == 0 and not game.playback.active, "Exit cannot affect fresh run: " + stage)

	_fixture(4)
	game.run.relics.append("last_thread")
	game.run.hp = 1
	game._act()
	while game.run.turn == 1:
		await process_frame
	check(game.run.last_thread_used and game.run.hp > 0 and game.run.packed().is_empty(), "Last Thread revives and unpacks during locked playback")
	while game.run.total_turns < 2:
		await process_frame
	check(game.playback.active and game.run.total_turns == 2, "Last Thread continues automatically with changed layout")
	_fixture(4)
	game.run.enemy["hp"] = 1
	game._act()
	check(game.run.hp == 30, "Lethal champion hit has no monster response")
	await create_timer(0.1).timeout
	check(game.enemy_card.defeated and not game.gameplay_background.enemy.visible and not game.enemy_card.death_pixels.pieces.is_empty(), "Lethal hit disperses before descent")
	await create_timer(0.12).timeout
	check(not game.playback.active and game.run.fight == 1 and game.run.hp == 30, "Lethal impact settles and descends automatically")
	_fixture(4)
	game.run.hp = 1
	game._act()
	while game.playback.active:
		await process_frame
	check(game.run.total_turns == 1 and game.run.phase == PackRun.Phase.DEFEAT, "Lethal monster response never starts another action")
	_fixture(4)
	game.run.items[0]["damage"] = 0
	game.run.enemy["attacks"] = [0]
	game._act()
	await create_timer(0.9).timeout
	check(game.playback.active and game.run.total_turns >= 2 and game.run.total_turns < 8, "Harmless exchanges yield frames without arbitrary ending")
	game.playback.set_paused(true)
	game.show_menu()
	var old_log: Array = game.run.history.duplicate(true)
	await create_timer(0.5).timeout
	check(not game.playback.active and game.run.history == old_log and not game.combat.visible, "Paused exit cancels callbacks")
	await _freed_scene_checks()
	# Let the audio mixer release playback handles before the process exits.
	game.front.audio.next_track_timer.stop()
	if game.front.audio.transition and game.front.audio.transition.is_valid():
		game.front.audio.transition.kill()
	for player: Node in game.find_children("*", "AudioStreamPlayer", true, false):
		player.stream_paused = false
		player.stop()
	await create_timer(0.1).timeout
	test_viewport.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	print("AUTOMATIC COMBAT RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _fixture(speed: int) -> void:
	game.start_run("ranger", 42)
	game._open_reward(true)
	game._choose(0)
	game.front.settings["combat_speed"] = speed
	game.run.relics.clear()
	game.run.items.clear()
	game.run.hp = 30
	game.run.enemy["hp"] = 1000
	game.run.enemy["max_hp"] = 1000
	game.run.enemy["attacks"] = [3]
	game.run.add_item("rusty_knife", Vector2i.ZERO)["damage"] = 8
	game._refresh()

func _freed_scene_checks() -> void:
	for paused_first: bool in [false, true]:
		var disposable: Control = load("res://scenes/main.tscn").instantiate()
		test_viewport.add_child(disposable)
		await process_frame
		disposable.start_run("warrior", 42)
		disposable.run.enemy["hp"] = 1000
		disposable.run.enemy["max_hp"] = 1000
		disposable.front.settings["combat_speed"] = 4
		disposable._act()
		disposable.playback.set_paused(paused_first)
		var retained_run: PackRun = disposable.run
		var before: Array = [retained_run.hp, retained_run.total_turns, retained_run.history.duplicate(true)]
		# Direct freeing tests _exit_tree cancellation, without show_menu first.
		for player: Node in disposable.find_children("*", "AudioStreamPlayer", true, false):
			player.stop()
		disposable.queue_free()
		await process_frame
		await create_timer(0.55).timeout
		check(not is_instance_valid(disposable), "Active/paused disposable UI is freed")
		check(before == [retained_run.hp, retained_run.total_turns, retained_run.history], "Freeing active/paused UI cancels callbacks without further model commits")

func _frozen_check(label: String, duration: float) -> void:
	game.playback.set_paused(true)
	var state: Array = [game.run.hp, game.run.mana, game.run.block, game.run.turn, game.run.total_turns, game.run.history.duplicate(true)]
	var remaining: float = game.playback.remaining_seconds
	var old_elapsed: float = game.elapsed
	var transform: Array = [game.enemy_art.position, game.enemy_art.scale, game.enemy_art.modulate, game.hp_bar._glow_amount, game.enemy_bar._glow_amount]
	await create_timer(duration).timeout
	check(state == [game.run.hp, game.run.mana, game.run.block, game.run.turn, game.run.total_turns, game.run.history], label + " pause freezes complete checkpoint")
	check(is_equal_approx(remaining, game.playback.remaining_seconds), label + " pause preserves remaining wait")
	check(is_equal_approx(old_elapsed, game.elapsed), label + " pause freezes descent clock")
	check(transform == [game.enemy_art.position, game.enemy_art.scale, game.enemy_art.modulate, game.hp_bar._glow_amount, game.enemy_bar._glow_amount], label + " pause freezes feedback")

func _reset_check() -> void:
	game.start_run("ranger", 8)
	var logs: Array = game.run.history.duplicate(true)
	var hp: int = game.run.hp
	await create_timer(0.1).timeout
	check(not game.playback.active and game.run.total_turns == 0 and game.run.hp == hp and game.run.history == logs, "Reset cannot receive old checkpoints")
	check(game.enemy_art.scale == Vector2.ONE and game.enemy_art.position == game.enemy_card.rest_position, "Reset restores feedback transforms")
