extends "res://tests/battle_ui_test.gd"

func _run() -> void:
	render = DisplayServer.get_name() != "headless"
	get_tree_timeout()
	_stage_history_checks()
	game = load("res://scenes/main.tscn").instantiate()
	test_viewport = SubViewport.new()
	test_viewport.size = Vector2i(1280, 800)
	test_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(test_viewport)
	test_viewport.notify_mouse_entered()
	test_viewport.add_child(game)
	await process_frame
	game.start_run("warrior", 42)
	game._open_reward(true)
	game._choose(0)
	game.character_tabs.current_tab = _tab_index("Logs")
	await process_frame
	await process_frame
	check(game.stage_number.text == "Stage 01", "Stage number remains beside the monster label")
	check(game.stage_monster.text == PackRun.enemies()[0]["name"], "First stage displays its monster name")
	check(game.previous_stage.disabled and game.next_stage.disabled, "First stage has no navigation outside visited stages")
	check(game.history_view.get_parsed_text().contains("Relic bound"), "First stage includes its relic reward")
	for index in range(2):
		_win_stage(game.run)
	game._refresh()
	await process_frame
	check(game.combat.get_node("CharacterPanel/Tabs/Logs").find_children("*", "OptionButton", true, false).is_empty(), "Logs has no dropdown")
	check(game.log_stage_index == -1 and game.stage_number.text == "Stage 03", "Following current stage advances automatically")
	check(game.stage_monster.text == PackRun.enemies()[2]["name"], "Current stage shows its monster name")
	check(not game.history_view.get_parsed_text().contains("Relic bound"), "Current stage excludes earlier stages")
	_click(game.previous_stage)
	await process_frame
	check(game.log_stage_index == 1 and game.stage_monster.text == PackRun.enemies()[1]["name"], "Back arrow selects the previous stage")
	check(game.stage_number.text == "Stage 02", "Stage number follows arrow selection")
	check(game.history_view.get_parsed_text().contains(PackRun.enemies()[1]["name"] + " defeated.") and not game.history_view.get_parsed_text().contains("Floor 2:"), "Selected battle events appear without repeating the footer's encounter heading")
	var archived_text: String = game.history_view.text
	game.run.log_line("Current-only event")
	game._refresh()
	check(game.log_stage_index == 1 and game.history_view.text == archived_text, "Refresh preserves an archived stage and its content")
	check(not game.history_view.scroll_following, "Archived stages do not auto-scroll")
	await _snapshot("stage-tabs-previous")
	_click(game.stage_monster)
	await process_frame
	check(game.log_stage_index == 1 and not game.modal.visible, "Monster label has no click action")
	_click(game.previous_stage)
	await process_frame
	check(game.log_stage_index == 0 and game.stage_number.text == "Stage 01", "Back arrow reaches the oldest stage")
	check(game.stage_monster.text == PackRun.enemies()[0]["name"], "Archived stage shows its own monster instead of the current enemy")
	check(game.previous_stage.disabled and not game.next_stage.disabled, "Oldest stage disables only the back arrow")
	check(game.history_view.get_parsed_text().contains("Relic bound"), "Selecting an older stage restores its own entries")
	_click(game.next_stage)
	_click(game.next_stage)
	await process_frame
	check(game.log_stage_index == -1 and game.next_stage.disabled, "Forward arrow returns to current stage and stops at the end")
	check(game.history_view.get_parsed_text().contains("Current-only event"), "Current selection shows the latest entries")
	check(game.history_view.scroll_following, "Returning to current stage resumes following new logs")
	await _snapshot("stage-tabs-current")
	game._select_log_stage(0)
	_win_stage(game.run)
	game._refresh()
	check(game.log_stage_index == 0 and game.stage_monster.text == PackRun.enemies()[0]["name"], "New stages do not displace an archived selection")
	game.start_run("warrior", 42)
	game._open_reward(true)
	game._choose(0)
	check(game.stage_number.text == "Stage 01" and game.stage_monster.text == PackRun.enemies()[0]["name"] and game.log_stage_index == -1, "Starting a new descent clears the previous run's log navigation state")
	game.character_tabs.current_tab = _tab_index("Relics")
	# Use only catalog keys, including Last Thread, for tooltip/icon coverage.
	game.run.relics.clear()
	for key: String in PackCatalog.RELICS:
		game.run.relics.append(key)
		if game.run.relics.size() == 4:
			break
	game.run.relics[0] = "last_thread"
	game.run.last_thread_used = true
	game._refresh()
	await process_frame
	await process_frame
	var relic_page: Control = game.combat.get_node("CharacterPanel/Tabs/Relics")
	check(relic_page.find_children("*", "Label", true, false).is_empty(), "Relic page contains no titles or descriptive text")
	check(relic_page.find_children("*", "BaseButton", true, false).is_empty(), "Relic grid contains no actionable buttons")
	check(relic_page.get_node("Grid").columns == 6 and game.relic_slots.size() >= 6, "Relic grid fills six columns with empty sockets")
	check(game.relic_slots[0].size.x == game.relic_slots[0].size.y and game.relic_slots[0].size.x > BackpackBoard.CELL, "Relic sockets are larger squares")
	check(game.relic_slots[0].get_node("Art").modulate.a < 1, "Consumed relics remain visible with a dimmed icon")
	var saved_relics: Array = game.run.relics.duplicate()
	_click(game.relic_slots[0])
	await process_frame
	check(not game.modal.visible and game.run.relics == saved_relics, "Clicking a relic has no gameplay or dialog action")
	_motion(Vector2(640, 80))
	game.inspector.clear()
	await _snapshot("stage-tabs-relics")
	_motion(game.relic_slots[0].get_global_rect().get_center())
	await create_timer(0.35).timeout
	check(game.inspector.windows.size() == 1 and game.inspector.windows[0].key == "relic_last_thread", "Hover opens the relic tooltip")
	check(game._relic_inspection(0)["body"].contains("Consumed"), "Tooltip explains the consumed relic status")
	await _snapshot("stage-tabs-relic-tooltip")
	print("STAGE TABS RESULT: %d checks, %d failures" % [checks, failures])
	test_viewport.queue_free()
	await process_frame
	quit(1 if failures else 0)

func get_tree_timeout() -> void:
	create_timer(30).timeout.connect(func() -> void: printerr("Stage tabs test timed out"); quit(1))

func _win_stage(state: PackRun) -> void:
	if state.phase == PackRun.Phase.RELIC:
		state.choose_relic(state.relic_offers[0])
	state.enemy["hp"] = 1
	state.enemy["armor"] = 0
	state.enemy["opening_armor"] = 0
	state.enemy["cycle_armor"] = 0
	state.enemy["parry"] = 0
	state.hp = state.max_hp
	state.end_turn()
	check(state.phase == PackRun.Phase.LOOT, "Stage fixture wins through the normal combat rules")
	if state.phase == PackRun.Phase.LOOT:
		state.advance_encounter()
		state.choose_loot(state.offers[0])

func _stage_history_checks() -> void:
	var state: PackRun = fixture()
	check(state.stage_history.size() == 1 and state.stage_history[0]["number"] == 1, "Reset opens the first stage before logging entry and relic choice")
	check(state.stage_history[0]["lines"].size() == state.history.size(), "Initial stage owns the initial log entries")
	var preview_before: Array = state.stage_history.duplicate(true)
	state.outcome(state.effects())
	check(state.stage_history == preview_before, "Damage previews do not mutate stage history")
	_win_stage(state)
	check(state.stage_history.size() == 2 and state.stage_history[1]["lines"].size() == 1 and state.stage_history[1]["lines"][0].begins_with("Claimed"), "Claiming after descent logs in the current stage without an encounter heading")
	var first: String = "\n".join(state.stage_history[0]["lines"])
	check(not first.contains("Claimed") and not first.contains("recovered 0"), "Deferred claims do not rewrite the completed stage and zero recovery stays silent")
	var previous: Array = state.stage_history[0]["lines"].duplicate()
	check(state.stage_history[0]["lines"] == previous, "Starting the next fight does not change archived lines")
	state.log_line("New stage event")
	check(state.stage_history[1]["lines"].back() == "New stage event" and state.stage_history[1]["lines"].size() == 2, "New fight logs belong to the new stage")
	state.begin_stage(3, "Quiet sanctuary")
	state.log_line("Rested at the fountain.")
	check(state.stage_history.back()["name"] == "Quiet sanctuary" and state.stage_history.back()["lines"] == ["Rested at the fountain."], "Stage grouping supports named noncombat encounters")
	state.begin_stage(3, "Quiet sanctuary")
	check(state.stage_history.size() == 3, "Reopening the same stage does not duplicate its history")
	state.reset(42)
	check(state.stage_history.size() == 1 and state.stage_history[0]["lines"].size() == 1, "Reset removes all prior stage records")
