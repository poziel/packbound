extends "res://tests/prototype_test.gd"

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.run_saves.directory = "res://workspace/logs/inventory-inspection-saves"
	game.start_run("warrior", 42)
	game.run.choose_relic(game.run.relic_offers[0])
	game.front.settings["tooltips"] = true
	for phase: int in [PackRun.Phase.RELIC, PackRun.Phase.LOOT, PackRun.Phase.SELECTOR, PackRun.Phase.ROOM, PackRun.Phase.ROOM_COMPLETE]:
		game.run.phase = phase
		game.run.combat_state = PackRun.CombatState.FINISHED
		var item: Dictionary = game.run.items[0]
		var event := InputEventMouseButton.new()
		event.position = game.board.item_rect(item).position + Vector2(16, 16)
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = true
		game.board._gui_input(event)
		check(not game.board.dragging.is_empty(), "Inventory drag begins outside combat, phase %s" % phase)
		game.board.cancel_drag()
	game.run.phase = PackRun.Phase.FIGHT
	game.run.combat_state = PackRun.CombatState.PREPARING
	game.run.enemy.hp = 1000
	game.run.enemy.max_hp = 1000
	game._act()
	game._process(0)
	check(game.playback.active and not game.playback.paused, "Inspection fixture is in a live fight")
	check(game.inspector.enabled, "Tooltips stay enabled during running combat")
	var before: Array = game.run.items.duplicate(true)
	var item: Dictionary = game.run.items[0]
	game.board.begin_drag(item, game.board.item_rect(item).position + Vector2(16, 16))
	check(game.board.dragging.is_empty() and game.run.items == before, "Combat still rejects inventory editing")
	game.inspector.pointer = game.board.get_global_transform_with_canvas() * (game.board.item_rect(item).position + Vector2(16, 16))
	check(not game.inspector._candidate(game.board).is_empty(), "Item hover resolves during combat")
	check(not game._enemy_inspection().is_empty(), "Enemy remains inspectable during combat")
	game.inspector.set_process(false)
	game.inspector._spawn(game._enemy_inspection(), Rect2(300, 200, 30, 30), -1)
	var popup: PackInspectWindow = game.inspector.windows[0]
	game._refresh()
	check(game.inspector.windows.size() == 1 and game.inspector.windows[0] == popup, "Combat refresh preserves an open inspection window")
	game.playback.set_paused(true)
	check(not game.run.can_edit_inventory(), "Pausing a fight does not unlock editing")
	game._process(0)
	check(game.inspector.enabled, "Paused combat keeps inspection")
	game.inspector.clear()
	game._cancel_combat()
	game.run.reset(42)
	print("ROOM INVENTORY INSPECTION: %d checks, %d failures" % [checks, failures])
	await preload("res://tests/automatic_combat_cleanup.gd").release(self, game)
	quit(1 if failures else 0)
