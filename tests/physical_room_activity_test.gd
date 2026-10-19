extends "res://tests/prototype_test.gd"

func _run() -> void:
	root.size = Vector2i(1280, 720)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.run_saves.directory = "res://workspace/logs/physical-room-saves"
	game.start_run("warrior", 17)
	game.front.settings["tooltips"] = true
	game.front.settings["combat_speed"] = 4
	game.run.choose_relic(game.run.relic_offers[0])
	game.run.phase = PackRun.Phase.LOOT
	game.run.combat_state = PackRun.CombatState.FINISHED
	game._advance_encounter()
	await _wait_for_action()
	game.run.door_choices.assign([{"id": "relic", "kind": "relic"}])
	game._configure_floor_scene()
	game._door_chosen("relic")
	await _wait_for_action()
	check(not game.floor_flow.activity_panel.visible, "Relic room has no activity panel")
	check(game.floor_flow.door_buttons.size() == 3, "Three physical relic targets")
	check(not game.action.disabled, "Central action can leave without claiming")
	var room: Node3D = game.gameplay_background.world.active_room
	check(room.has_method("activity_position"), "Room exposes physical activity anchors")
	if room.has_method("activity_position"):
		var key: String = game.run.room_relic_offers[0]
		var relic: Sprite3D = room.get_node("Pedestals/Pedestal0/Relic")
		check(relic.texture != null and relic.texture.atlas == PackArt.relic(key).atlas, "Pedestal shows actual offered relic")
		var initial_y: float = relic.position.y
		await create_timer(0.15).timeout
		check(not is_equal_approx(initial_y, relic.position.y), "Relic gently floats")
		for button: Button in game.floor_flow.door_buttons:
			check(button.get_global_rect().position.x >= 16 and button.get_global_rect().end.x <= 640, "Relic target stays within gameplay half")
		game.floor_flow._highlight_activity("relic:" + key)
		await create_timer(0.25).timeout
		check(room.get_node("Pedestals/Pedestal0/Glow").light_energy > 2, "Hover glows on the selected pedestal")
		var first: Button = game.floor_flow.door_buttons[0]
		first.grab_focus()
		var tooltip: Dictionary = game.inspector._candidate(first)
		check(not tooltip.is_empty() and tooltip.data.title == PackCatalog.relic(key).name and tooltip.data.icon.atlas == relic.texture.atlas, "Physical relic uses the actual relic inspection")
		if DisplayServer.get_name() != "headless":
			_motion(first.get_global_rect().get_center())
			await create_timer(0.3).timeout
			check(not game.inspector.windows.is_empty(), "Mouse hover opens the relic tooltip")
		await capture("physical-relic-hover")
		game.inspector.clear()
		_click(first)
		check(game.busy, "Claim animation blocks departure")
		await _wait_for_action()
		check(game.run.relics.has(key), "Physical choice grants selected relic")
		check(not room.get_node("Pedestals").visible, "Pedestals retire before departure")
		check(game.run.phase == PackRun.Phase.ROOM_COMPLETE, "Claim waits for central continue")
		var saved: Dictionary = game.run_saves.capture(game.run, 2)
		var restored: PackRun = PackRun.new()
		game.run_saves.restore(restored, saved)
		check(restored.phase == PackRun.Phase.ROOM_COMPLETE, "Completed physical reward restores")
		var restored_room: Node3D = load("res://scenes/gameplay/rooms/dungeon/relic_room.tscn").instantiate()
		root.add_child(restored_room)
		restored_room.configure_activity(restored)
		check(not restored_room.get_node("Pedestals").visible, "Restoring a claimed reward keeps supports retracted")
		restored_room.queue_free()
		await capture("physical-relic-retired")
	game._act()
	await _wait_for_action()
	check(game.run.phase == PackRun.Phase.SELECTOR, "Central action leaves completed room")
	game.run.door_choices.assign([{"id": "rest", "kind": "rest"}])
	game.run.hp = 12
	game._configure_floor_scene()
	game._door_chosen("rest")
	await _wait_for_action()
	room = game.gameplay_background.world.active_room
	check(absf(room.get_node("FireBowl").position.x) > 2, "Campfire stays beside central travel path")
	check(not game.floor_flow.activity_panel.visible and game.floor_flow.door_ids == ["rest"], "Rest is a physical campfire action")
	await capture("physical-rest")
	game.floor_flow.door_buttons[0].grab_focus()
	_key(KEY_ENTER)
	var release := InputEventKey.new()
	release.keycode = KEY_ENTER
	release.pressed = false
	root.push_input(release, true)
	await _wait_for_action()
	check(game.run.hp == 24 and game.run.phase == PackRun.Phase.ROOM_COMPLETE, "Keyboard activation of fire heals once")
	game._act()
	await _wait_for_action()
	game.run.door_choices.assign([{"id": "encounter", "kind": "encounter"}])
	game._configure_floor_scene()
	game._door_chosen("encounter")
	await _wait_for_action()
	check(not game.floor_flow.activity_panel.visible and game.floor_flow.door_ids == ["encounter"], "Encounter waits for physical interaction")
	game.floor_flow.door_buttons[0].pressed.emit()
	await process_frame
	check(game.floor_flow.activity_panel.visible, "Inspecting encounter reveals its dialogue")
	await capture("physical-encounter")
	game._act()
	await _wait_for_action()
	check(game.run.phase == PackRun.Phase.SELECTOR, "Central action skips encounter")
	game.run.door_choices.assign([{"id": "relic", "kind": "relic"}])
	game._configure_floor_scene()
	game._door_chosen("relic")
	await _wait_for_action()
	var owned: Array = game.run.relics.duplicate()
	game._act()
	check(game.busy, "Skipping relics retires pedestals before departure")
	await _wait_for_action()
	check(game.run.phase == PackRun.Phase.SELECTOR and game.run.relics == owned, "Central skip leaves without granting any relic")
	for kind: String in ["relic", "rest", "encounter"]:
		game.run.floor_index = 10
		game.run.fight = 10
		game.run.room_kind = kind
		game.run.phase = PackRun.Phase.ROOM
		game.run.room_resolved = false
		game.run.room_reward_pending = kind == "relic"
		game.run.room_relic_offers.assign(["blood_pact", "echo_clock", "folded_space"] if kind == "relic" else [])
		game.run.room_event = "interrogation"
		game.gameplay_background.world.set_room(game.gameplay_background.scene_for_state(game.run))
		game._refresh()
		await process_frame
		check(game.floor_flow.door_buttons.size() == (3 if kind == "relic" else 1), "Later biome exposes physical " + kind)
		await capture("physical-later-" + kind)
	game.run.room_event = "blood_offering"
	game._refresh()
	game.floor_flow.door_buttons[0].pressed.emit()
	await process_frame
	game._room_action("offer")
	check(game.run.room_reward_pending and game.floor_flow.door_buttons.size() == 3, "Paying altar reveals physical relic offers")
	check(game.gameplay_background.world.active_room.get_node("Pedestals").visible, "Altar reward pedestals become visible")
	game.floor_flow.door_buttons[0].pressed.emit()
	await _wait_for_action()
	check(game.run.phase == PackRun.Phase.ROOM_COMPLETE and not game.gameplay_background.world.active_room.get_node("Pedestals").visible, "Altar relic claim retracts pedestals too")
	print("PHYSICAL ROOMS: %d checks, %d failures" % [checks, failures])
	await preload("res://tests/automatic_combat_cleanup.gd").release(self, game)
	quit(1 if failures else 0)

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://workspace/logs/%s.png" % label)
