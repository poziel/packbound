extends "res://tests/support/storage_ui_support.gd"

func _run() -> void:
	create_timer(30).timeout.connect(func() -> void: quit(2))
	test_viewport = SubViewport.new()
	test_viewport.size = Vector2i(1280, 720)
	test_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(test_viewport)
	game = load("res://scenes/main.tscn").instantiate()
	test_viewport.add_child(game)
	await frames(3)
	game.run_saves.directory = preload("res://tests/support/artifact_paths.gd").path("legacy_tasks/progression-regression/saves")
	game.start_run("warrior", 42)
	game.waiting_at_entrance = false
	game.front._set_option("turn_based_combat", true)
	game.front.settings["combat_speed"] = 4
	game.run.items.clear()
	game.run.phase = PackRun.Phase.FIGHT
	var weapon: Dictionary = game.run.add_item("rusty_knife", Vector2i.ZERO)
	weapon.damage = 10000
	game.run.enemy.hp = 1
	game.run.enemy.armor = 0
	game._refresh()
	game._act()
	game.playback.set_process(false)
	game.playback._process(100)
	game.playback._process(100)
	await create_timer(4).timeout
	check(not game.playback.active and not game.busy, "Turn-based victory releases playback and busy state")
	check(game.run.phase == PackRun.Phase.SELECTOR, "Victory reaches floor selection")
	check(game.gameplay_background.world.active_room.has_method("select_exit"), "Floor selector scene is actually entered")
	check(not game.floor_flow.locked and not game.floor_flow.door_buttons.is_empty(), "Next floor doors are usable")
	game.run.door_choices.assign([{"id": "combat", "kind": "combat"}])
	game._configure_floor_scene()
	game._door_chosen("combat")
	await create_timer(4).timeout
	check(game.run.phase == PackRun.Phase.FIGHT and not game.action.disabled, "Choosing next combat enables Attack")
	game.run.enemy.hp = 100000
	game.run.enemy.max_hp = 100000
	game._act()
	check(game.playback.active and game.action.disabled, "Next fight retains disabled Attack during the round")
	game.playback._process(100)
	game.playback._process(100)
	check(game.playback.waiting_for_round and not game.action.disabled, "Next fight still waits for manual Attack between rounds")
	for floor_index in [0, 10]:
		var state := PackRun.new()
		state.floor_index = floor_index
		state.phase = PackRun.Phase.SELECTOR
		check(game.gameplay_background.scene_for_state(state) != null, "Selector resolves in biome at floor %d" % state.display_floor())
		state.phase = PackRun.Phase.ROOM
		for kind: String in ["rest", "relic", "encounter"]:
			state.room_kind = kind
			check(game.gameplay_background.scene_for_state(state) != null, "%s resolves at floor %d" % [kind, state.display_floor()])
	print("TURN-BASED PROGRESSION: %d checks, %d failures; phase=%s" % [checks, failures, game.run.phase])
	await preload("res://tests/support/automatic_combat_cleanup.gd").release(self, game, test_viewport)
	report("turn_based_progression")
	quit(1 if failures else 0)
