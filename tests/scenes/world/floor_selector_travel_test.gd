extends "res://tests/support/prototype_support.gd"

func _run() -> void:
	create_timer(35).timeout.connect(func() -> void: printerr("TRAVEL TEST TIMEOUT"); quit(2))
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.run_saves.directory = preload("res://tests/support/artifact_paths.gd").path("legacy_logs/selector-travel-saves")
	game.start_run("warrior", 42)
	game.front.settings["combat_speed"] = 4
	game.run.choose_relic(game.run.relic_offers[0])
	game.run.phase = PackRun.Phase.LOOT
	game.run.combat_state = PackRun.CombatState.FINISHED
	game._advance_encounter()
	check(game.busy and game.run.phase == PackRun.Phase.SELECTOR, "Selector is committed before departure")
	var saved: Dictionary = game.run_saves.capture(game.run, 20)
	saved.id = "restored-selector"
	var choices: Array = game.run.door_choices.duplicate(true)
	game.start_run("warrior", -1, saved)
	check(game.run.door_choices == choices and game.run.display_floor() == 1, "Travel save reopens directly in selector")
	await create_timer(1.3).timeout
	check(not game.busy and game.run.phase == PackRun.Phase.SELECTOR, "Old departure cannot mutate reopened selector")
	await process_frame
	var first: Button = game.floor_flow.door_buttons[0]
	var scene: Node3D = game.gameplay_background.world.active_room
	check(scene.scene_file_path.ends_with("dungeon/rooms/floor_selector/floor_selector.tscn"), "Selector loaded on reopen")
	first.grab_focus()
	_key(KEY_TAB)
	await process_frame
	var focused: Control = root.gui_get_focus_owner()
	check(focused in game.floor_flow.door_buttons and focused != first, "Tab moves focus between physical doors")
	_key(KEY_ENTER)
	var release := InputEventKey.new()
	release.keycode = KEY_ENTER
	release.pressed = false
	root.push_input(release, true)
	await process_frame
	check(game.busy and game.run.display_floor() == 2, "Enter activates focused destination")
	var committed_kind: String = game.run.room_kind
	saved = game.run_saves.capture(game.run, 21)
	saved.id = "restored-destination"
	game.start_run("warrior", -1, saved)
	await create_timer(1.3).timeout
	check(game.run.display_floor() == 2 and game.run.room_kind == committed_kind, "Committed destination restores once during stair travel")
	# Return to a generated selector, then click its actual projected hit target.
	game.run.phase = PackRun.Phase.ROOM_COMPLETE
	game.run.enter_selector()
	game.gameplay_background.world.set_room(game.gameplay_background.scene_for_state(game.run))
	game._configure_floor_scene()
	game._refresh()
	await process_frame
	var before: int = game.run.display_floor()
	_click(game.floor_flow.door_buttons[0])
	await process_frame
	check(game.busy and game.run.display_floor() == before + 1, "Mouse selects the projected door")
	game.show_menu()
	game.start_run("mage", 99)
	await create_timer(1.3).timeout
	check(game.run.class_key == "mage" and game.run.display_floor() == 1 and not game.busy, "Cancelled stair travel cannot change a new run")
	# The selector for floor 11 uses the next biome, without consuming depth.
	game.run.floor_index = 9
	game.run.fight = 9
	game.run.phase = PackRun.Phase.LOOT
	game.run.enter_selector()
	check(game.run.display_floor() == 10 and game.gameplay_background.scene_for_state(game.run).resource_path.ends_with("cursed/rooms/floor_selector/floor_selector.tscn"), "Floor 10 selector leads into cursed biome")
	report("SELECTOR TRAVEL")
	await preload("res://tests/support/automatic_combat_cleanup.gd").release(self, game)
	quit(1 if failures else 0)
