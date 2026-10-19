extends "res://tests/support/prototype_support.gd"

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.run_saves.directory = preload("res://tests/support/artifact_paths.gd").path("legacy_logs/floor-flow-saves")
	check(game.get_node_or_null("FloorFlow") != null, "Game contains reusable floor-flow UI")
	if game.get_node_or_null("FloorFlow") == null:
		game.queue_free()
		quit(1)
		return
	game.start_run("warrior", 17)
	game.run.choose_relic(game.run.relic_offers[0])
	game.run.hp = 12
	game.run.phase = PackRun.Phase.LOOT
	game.run.combat_state = PackRun.CombatState.FINISHED
	game._advance_encounter()
	await _wait_for_action()
	check(game.run.phase == PackRun.Phase.SELECTOR and game.run.display_floor() == 1, "Fight exits to unnumbered selector")
	check(game.gameplay_background.world.active_room.has_method("configure"), "Selector corridor actually mounted")
	check(not game.enemy_card.visible and game.action.disabled, "Selector hides combat controls")
	check(game.floor_flow.door_buttons.size() == game.run.door_choices.size(), "UI targets correspond to physical doors")
	var door_index: int = game.floor_flow.door_ids.find("combat")
	var key := InputEventKey.new()
	key.keycode = KEY_1 + door_index
	key.pressed = true
	check(door_index >= 0 and game._game_shortcut(key), "Number shortcut selects the corresponding physical door")
	await _wait_for_action()
	check(game.run.display_floor() == 2 and game.run.phase == PackRun.Phase.FIGHT, "Door enters one new fight floor")
	check(game.enemy_card.visible and game.run.can_edit_inventory(), "Arrival allows combat preparation")
	game.run.phase = PackRun.Phase.LOOT
	game._advance_encounter()
	await _wait_for_action()
	game.run.door_choices.assign([{"id": "rest", "kind": "rest"}])
	game._configure_floor_scene()
	game._door_chosen("rest")
	await _wait_for_action()
	check(game.run.display_floor() == 3 and not game.floor_flow.activity_panel.visible and game.floor_flow.door_ids == ["rest"], "Rest mounts a physical campfire target")
	check(not game.enemy_card.visible and not game.action.disabled, "Rest has a central leave action")
	game._room_action("rest")
	check(game.run.phase == PackRun.Phase.ROOM_COMPLETE and game.run.hp == 24, "Rest action resolves once")
	game._room_action("continue")
	await _wait_for_action()
	check(game.run.display_floor() == 3 and game.run.phase == PackRun.Phase.SELECTOR, "Leaving rest does not increment floor")
	game.run.door_choices.assign([{"id": "encounter", "kind": "encounter"}])
	game._configure_floor_scene()
	game._door_chosen("encounter")
	await _wait_for_action()
	game.run.room_event = "interrogation"
	game._refresh()
	check(not game.gameplay_background.enemy.has_spawn, "Dialogue encounter has no visible enemy")
	game._room_action("refuse")
	check(game.run.phase == PackRun.Phase.FIGHT and game.run.display_floor() == 4, "Encounter fight remains on current floor")
	check(game.gameplay_background.enemy.has_spawn and game.enemy_card.visible and not game.enemy_card.defeated, "Refusal reveals a live enemy in the encounter room")
	report("FLOOR FLOW UI")
	await preload("res://tests/support/automatic_combat_cleanup.gd").release(self, game)
	quit(1 if failures else 0)
