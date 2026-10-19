extends "res://tests/support/test_case.gd"

func _run() -> void:
	var script = load("res://scenes/shared/dev_menu/dev_menu_host.gd") if FileAccess.file_exists("res://scenes/shared/dev_menu/dev_menu_host.gd") else null
	check(script != null, "Developer host exists")
	if script == null:
		report("DEV FLOW")
		quit(1)
		return
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_run("warrior", 1729)
	game.modal.hide()
	game.modal_kind = ""
	var host = game.dev_menu.host
	game._act()
	check(game.playback.active, "Fixture starts live combat")
	check(host.open(), "Open during live combat")
	check(game.playback.paused, "Opening pauses playback")
	var result: Dictionary = host.submit("set_player", {"stat": "hp", "value": 17})
	check(result.ok and host.pending.size() == 1, "Pending response queues edit")
	check(host.finish_exchange_and_apply(), "Explicitly finish current exchange")
	for index in range(20):
		if not host.stepping: break
		game.playback._process(10.0)
	check(not host.stepping and game.playback.paused, "Exchange finishes at paused boundary")
	check_equal(game.run.hp, 17, "Queued health survives enemy response")
	check_equal(host.pending.size(), 0, "Pending queue drained")
	host.close()
	check(not game.playback.paused, "Closing restores originally running playback")
	game.playback.set_paused(true)
	host.open()
	host.close()
	check(game.playback.paused, "Closing preserves preexisting pause")
	host.open()
	var turn: int = game.run.turn
	var previous_mode: bool = game.playback.turn_based
	check(host.step_round(), "Step starts from paused round boundary")
	check_equal(game.playback.turn_based, previous_mode, "One-round step preserves the selected playback mode")
	for index in range(20):
		if not host.stepping: break
		game.playback._process(10.0)
	check_equal(game.run.turn, turn + 1, "Step advances exactly one full exchange")
	check(game.playback.paused, "Step pauses again")
	host.submit("set_player", {"stat": "mana", "value": 9})
	host.cancel_pending()
	check_equal(host.pending.size(), 0, "Cancel clears pending commands")
	result = host.submit("travel", {"floor": 12, "kind": "rest"})
	check(result.ok, "Travel command succeeds")
	check(not game.playback.active and game.run.pending_turn.is_empty(), "Travel cancels playback and pending results")
	check_equal(game.run.display_floor(), 12, "Travel destination applied")
	check_equal(game.run.room_kind, "rest", "Travel room initialized")
	check_equal(game.gameplay_background.world.active_room.scene_file_path, game.gameplay_background.scene_for_state(game.run).resource_path, "World matches run destination")
	# Instant completion must enter normal progression, not strand LOOT.
	game.front.settings["combat_speed"] = 10.0
	game.gameplay_background.arrival_seconds = 0.1
	host.submit("travel", {"floor": 3, "kind": "combat"})
	host.submit("defeat_enemy")
	check_equal(game.run.phase, PackRun.Phase.SELECTOR, "Instant defeat enters the normal floor selector")
	for index in range(120):
		if not game.gameplay_background.transitioning: break
		await create_timer(0.05).timeout
	check(not game.gameplay_background.transitioning, "Instant-kill progression completes within bounded wait")
	await process_frame
	check(not game.dev_menu.get_node("%Travel").disabled, "Panel unlocks after instant-kill travel")
	# Lethal stepping completes queued edits before normal floor progression.
	host.submit("travel", {"floor": 4, "kind": "combat"})
	game.run.enemy.hp = 1
	host.toggle_combat()
	host.submit("set_player", {"stat": "hp", "value": 23})
	host.finish_exchange_and_apply()
	for index in range(20):
		if not host.stepping: break
		game.playback._process(10.0)
	check_equal(game.run.hp, 23, "Lethal boundary applies queued edit before progression")
	for index in range(120):
		if not game.gameplay_background.transitioning: break
		await create_timer(0.05).timeout
	await process_frame
	check(not game.dev_menu.get_node("%Travel").disabled, "Panel unlocks after lethal step travel")
	host.submit("travel", {"floor": 20, "kind": "combat"})
	host.submit("defeat_enemy")
	check_equal(game.run.phase, PackRun.Phase.VICTORY, "Final instant defeat enters normal victory")
	game.run_saves.directory = artifact_path("blocked-file")
	var blocked := FileAccess.open(game.run_saves.directory, FileAccess.WRITE)
	blocked.store_string("not a directory")
	blocked.close()
	result = host.submit("restore_health")
	check(result.ok and not result.saved, "Save failure is reported separately from mutation")
	# A queued edit must not remain armed after closing and changing rooms normally.
	host.submit("travel", {"floor": 2, "kind": "combat"})
	game.modal.hide()
	game.modal_kind = ""
	host.toggle_combat()
	host.submit("set_player", {"stat": "mana", "value": 99})
	check_equal(host.pending.size(), 1, "Fixture queues an edit before close")
	host.close()
	check_equal(host.pending.size(), 0, "Closing cancels unapplied edits so they cannot target a later encounter")
	host.unbind()
	game.run_saves.directory = artifact_path("cleanup_saves")
	await preload("res://tests/support/automatic_combat_cleanup.gd").release(self, game)
	report("DEV FLOW")
	quit(1 if failures else 0)
