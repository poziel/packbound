extends "res://tests/battle_ui_test.gd"

func _run() -> void:
	create_timer(40).timeout.connect(func() -> void: printerr("Combat pacing test timed out"); quit(2))
	_model_checks()
	var old_config := ConfigFile.new()
	old_config.set_value("options", "music", 37)
	old_config.save("user://packbound_settings.cfg")
	render = DisplayServer.get_name() != "headless"
	test_viewport = SubViewport.new()
	test_viewport.size = Vector2i(1280, 800)
	test_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(test_viewport)
	test_viewport.notify_mouse_entered()
	game = load("res://scenes/main.tscn").instantiate()
	test_viewport.add_child(game)
	await process_frame
	check(game.front.settings["combat_speed"] == 1 and game.front.settings["music"] == 37, "Older settings default to normal combat speed and keep other preferences")
	game.front.show_options()
	await process_frame
	check(game.front.combat_speed is HSlider, "Combat speed uses a slider")
	if not game.front.combat_speed is HSlider:
		quit(1)
		return
	var selector: HSlider = game.front.combat_speed
	check(selector is HSlider and selector.min_value == 0.5 and selector.max_value == 10.0 and selector.step == 0.5 and selector.value == 1.0, "Options exposes half-step speeds from 0.5x through 10x")
	check(selector.get_global_rect().end.y <= game.front.back_button.global_position.y, "Combat speed fits above Back")
	check(selector.global_position.y >= game.front.tips_toggle.get_global_rect().end.y, "Combat speed does not overlap Hover explanations")
	await _snapshot("combat-pacing-options")
	selector.value = 2.5
	await process_frame
	check(game.front.settings["combat_speed"] == 2.5, "Slider applies fractional speed")
	var saved := ConfigFile.new()
	saved.load("user://packbound_settings.cfg")
	check(saved.get_value("options", "combat_speed", 1) == 2.5 and saved.get_value("options", "music") == 37, "Combat speed persists alongside existing preferences")
	game.front._set_option("combat_speed", 99)
	check(game.front.settings["combat_speed"] == 10.0, "Combat speed cannot exceed 10x")
	game.front._set_option("combat_speed", 0)
	check(game.front.settings["combat_speed"] == 0.5, "Combat speed cannot become instant or negative")
	for key: String in ["player_response_delay", "enemy_response_delay"]:
		var delay_slider: HSlider = game.front.combat_sliders[key]
		check(delay_slider.min_value == 0.2 and delay_slider.max_value == 2.5 and delay_slider.step == 0.1 and is_equal_approx(delay_slider.value, 1.5), "Old settings receive default response delays and slider ranges")
		delay_slider.value = 0.7 if key == "player_response_delay" else 2.3
		check(is_equal_approx(game.front.settings[key], delay_slider.value), "Response slider updates saved option")
	game.front._set_option("combat_speed", 2.5)
	game.front._load_settings()
	check(game.front.settings["combat_speed"] == 2.5 and is_equal_approx(game.front.settings["player_response_delay"], 0.7) and is_equal_approx(game.front.settings["enemy_response_delay"], 2.3), "All three fractional settings reload together")
	for key: String in ["player_response_delay", "enemy_response_delay"]:
		game.front._set_option(key, 99)
		check(is_equal_approx(game.front.settings[key], 2.5), "Response delays clamp at maximum")
		game.front._set_option(key, -1)
		check(is_equal_approx(game.front.settings[key], 0.2), "Response delays stay nonzero")
		game.front._set_option(key, 1.26)
		check(is_equal_approx(game.front.settings[key], 1.3), "Response delays snap to tenths")
	game.front._reset_options()
	check(selector.value == 1.0 and is_equal_approx(game.front.combat_sliders["player_response_delay"].value, 1.5) and is_equal_approx(game.front.combat_sliders["enemy_response_delay"].value, 1.5), "Reset restores all combat sliders")
	var durations: Array[float] = []
	for speed: float in [0.5, 1.0, 2.0, 2.5, 3.0, 4.0, 10.0]:
		_fixture(speed)
		var forecast: Dictionary = game.run.outcome(game.run.effects())
		var started: int = Time.get_ticks_msec()
		game._act()
		check(game.run.hp == 30 and game.run.enemy["hp"] == 92, "Only player damage applies immediately at %.1fx" % speed)
		check(_combat_log_text().contains("I dealt 8 damage") and not _combat_log_text().contains("dealt 3 damage to me"), "Monster log is withheld until its response at %.1fx" % speed)
		check(game.busy and not game.action.disabled and game.board.mouse_filter == Control.MOUSE_FILTER_STOP and not game.run.can_edit_inventory(), "Controls lock edits while retaining inspection during the exchange at %.1fx" % speed)
		game._act()
		game.board.begin_drag(game.run.items[0], Vector2.ZERO)
		check(game.run.total_turns == 1 and game.board.dragging.is_empty() and game.playback.paused, "Second action pauses without another turn and rejects inventory edits")
		game._act()
		check(not game.playback.paused and game.run.total_turns == 1, "Resume keeps the original champion checkpoint")
		await create_timer(0.20 / speed).timeout
		check(game.run.hp == 30 and game.run.turn == 1, "A real delay remains even at the fastest speed")
		while not game.run.pending_turn.is_empty():
			await process_frame
		var response_time: float = (Time.get_ticks_msec() - started) / 1000.0
		durations.append(response_time)
		check(response_time >= 1.5 / speed - 0.04 and response_time < 1.5 / speed + 0.30, "Response timing follows 1.5 seconds / %.1f: %.3fs" % [speed, response_time])
		check(game.run.hp == forecast["hp_after"] and game.run.enemy["hp"] == forecast["enemy_hp_after"], "Delayed state matches the original forecast")
		check(_combat_log_text().contains("dealt 3 damage to me") and not _combat_log_text().contains("turn"), "Response appends only its events, without turn headings")
		await create_timer(0.33 / speed).timeout
		check(game.busy and not game.action.disabled, "Controls stay locked through automatic continuation")
		check(game.enemy_art.position.is_equal_approx(game.enemy_card.rest_position), "Monster's attack motion returns to its authored position")
	print("Response seconds at 0.5x/1x/2x/2.5x/3x/4x/10x: ", durations)
	_fixture(1)
	game.run.enemy["hp"] = 1
	game._act()
	check(game.run.enemy["hp"] == 0 and not game.modal.visible, "Lethal player hit shows before reward")
	await create_timer(0.80).timeout
	check(game.busy and game.gameplay_background.transitioning and not game.modal.visible and game.run.hp == 30, "Dead monster never responds or adds an unnecessary delay")
	_fixture(1)
	game._act()
	await create_timer(0.1).timeout
	game.start_run("ranger", 9)
	game._open_reward(true)
	game._choose(0)
	var fresh_hp: int = game.run.hp
	var fresh_logs: Array = game.run.history.duplicate()
	await create_timer(1.6).timeout
	check(game.run.hp == fresh_hp and game.run.history == fresh_logs and game.run.total_turns == 0, "Reset cancels a pending response without touching the next run")
	check(not game.busy and game.enemy_art.scale == Vector2.ONE, "Reset restores controls and animation state")
	game.front._set_option("combat_speed", 4)
	game.front.settings["combat_speed"] = 1
	game.front._load_settings()
	check(game.front.settings["combat_speed"] == 4, "Saved speed reloads for later sessions")
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
	print("COMBAT PACING RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _fixture(speed: float) -> void:
	game.start_run("ranger", 42)
	game._open_reward(true)
	game._choose(0)
	game.front.settings["combat_speed"] = speed
	game.run.relics.clear()
	game.run.items.clear()
	game.run.hp = 30
	game.run.enemy["hp"] = 100
	game.run.enemy["max_hp"] = 100
	game.run.enemy["attacks"] = [3]
	game.run.add_item("rusty_knife", Vector2i.ZERO)["damage"] = 8
	game.character_tabs.current_tab = _tab_index("Logs")
	game._refresh()

func _model_checks() -> void:
	for character: String in PackCatalog.classes():
		for floor_index in range(20):
			var state: PackRun = fixture(character)
			state.fight = floor_index
			state.prepare_enemy()
			if state.phase == PackRun.Phase.RELIC:
				state.choose_relic(state.relic_offers[0])
			state.hp = 8
			state.player_poison = 2
			state.enemy_poison = 3
			state.start_combat()
			var expected: Dictionary = state.outcome(state.effects())
			var log_size: int = state.history.size()
			var started: Dictionary = state.begin_turn()
			check(started == expected and state.hp == expected["player_state"]["hp"] and state.enemy["hp"] == expected["player_state"]["enemy_hp"], "Staged player state matches pure preview: %s floor %d" % [character, floor_index + 1])
			check(state.history.slice(log_size) == expected["player_events"], "First checkpoint logs only player events")
			check(state.begin_turn().is_empty() and state.end_turn().is_empty(), "An in-progress turn cannot resolve twice")
			var completed: Dictionary = state.complete_turn()
			check(completed == expected and state.hp == expected["hp_after"] and state.enemy["hp"] == expected["enemy_hp_after"] and state.turn == 2, "Staged outcome matches pure preview: %s floor %d" % [character, floor_index + 1])
			check(state.complete_turn().is_empty() and state.total_turns == 1, "Completed response cannot repeat")

func _combat_log_text() -> String:
	# Inline keyword images add spacing; compare the same readable log prose.
	var text: String = game.history_view.get_parsed_text().replace("\u2060", "").replace("\u00a0", " ")
	return " ".join(text.split(" ", false))
