extends "res://tests/support/prototype_support.gd"

func _run() -> void:
	var state: PackRun = fixture()
	state.items.clear()
	var first: Dictionary = state.add_item("longsword", Vector2i(0, 0))
	var preferred: Dictionary = state.add_item("longsword", Vector2i(2, 0))
	check(first["priority"] == 0 and preferred["priority"] == 0, "New items default to no priority")
	first["priority"] = 0
	preferred["priority"] = 9
	check(state.effects()["active_ids"].has(preferred["id"]) and not state.effects()["active_ids"].has(first["id"]), "Even priority nine allocates before an unprioritized item")
	preferred["priority"] = 0
	check(state.effects()["active_ids"].has(first["id"]), "Unprioritized items use backpack reading order")
	first["priority"] = 2
	preferred["priority"] = 1
	first["stamina_cost"] = 2
	preferred["stamina_cost"] = 2
	var free: Dictionary = state.add_item("rusty_knife", Vector2i(3, 0))
	free["priority"] = 3
	free["stamina_cost"] = 0
	var stats: Dictionary = state.effects()
	check(stats.get("stamina", -1) == 3, "Every class has three base stamina")
	check(stats["active_ids"].has(preferred["id"]) and not stats["active_ids"].has(first["id"]), "Priority wins over position when only one attack fits")
	check(stats["active_ids"].has(free["id"]), "Free attacks still activate after unaffordable items")
	preferred["priority"] = 2
	stats = state.effects()
	check(stats["active_ids"].has(first["id"]) and not stats["active_ids"].has(preferred["id"]), "Equal priorities break ties in reading order")
	first["cost"] = 99
	stats = state.effects()
	check(stats["active_ids"].has(preferred["id"]) and stats.get("stamina_after", -1) == 1, "Failed mana payment consumes no stamina")
	first["cost"] = 0
	first["stamina_cost"] = 99
	preferred["cost"] = 1
	stats = state.effects()
	check(stats["active_ids"].has(preferred["id"]) and stats["mana_after"] == 0, "Failed stamina payment consumes no mana")
	var before: Dictionary = PackRunSaves.new().capture(state, 0)
	for index in range(10):
		state.effects()
	check(before == PackRunSaves.new().capture(state, 0), "Resource previews remain pure")
	state.enemy["hp"] = 10000
	state.enemy["max_hp"] = 10000
	state.enemy["attacks"] = [0]
	state.start_combat()
	var round_one: Dictionary = state.begin_turn()
	check(state.get("stamina") == 1 and state.mana == 0, "Player checkpoint shows spent pools")
	state.complete_turn()
	check(state.get("stamina") == 3 and state.mana == 1, "Both pools refill for the next round")
	var round_two: Dictionary = state.begin_turn()
	check(round_two["active_ids"] == round_one["active_ids"], "The same attacks can activate again next round")
	check(not state.has_method("set_item_priority") or not state.call("set_item_priority", first["id"], 1), "Priority changes are locked during combat")
	var restored: PackRun = PackRun.new()
	PackRunSaves.new().restore(restored, PackRunSaves.new().capture(state, 0))
	check(restored.items[0].get("priority") == 2 and restored.get("stamina") == state.get("stamina"), "Save restore retains priorities and spent stamina")
	var old_pending: Dictionary = PackRunSaves.new().capture(state, 0)
	old_pending.state.erase("stamina")
	old_pending.state.erase("stamina_capacity")
	old_pending.state.pending_turn.erase("stamina")
	old_pending.state.pending_turn.erase("stamina_after")
	old_pending.state.pending_turn.player_state.erase("stamina")
	PackRunSaves.new().restore(restored, old_pending)
	check(not restored.complete_turn().is_empty() and restored.stamina == 3, "Legacy mid-round saves finish their committed action and refill safely")
	var legacy: Dictionary = before.duplicate(true)
	for item: Dictionary in legacy.state.items:
		item.erase("priority")
		item.erase("stamina_cost")
	legacy.state.erase("stamina")
	legacy.state.erase("stamina_capacity")
	PackRunSaves.new().restore(restored, legacy)
	check(restored.items[0].get("priority", -1) == 0 and restored.items[0].get("stamina_cost", -1) == 2, "Old saves with no priority field gain the unprioritized default")
	var boosted: PackRun = fixture()
	boosted.items.clear()
	var charm: Dictionary = boosted.add_item("iron_charm", Vector2i.ZERO)
	charm["stamina"] = 2
	charm["mana"] = 2
	check(boosted.starting_resources().get("stamina", -1) == 5 and boosted.starting_resources()["mana"] == 3, "Packed items increase both maximum pools")
	charm["stamina_per_round"] = 1
	check(boosted.effects().get("stamina_after", -1) == 6, "Explicit per-round stamina gains apply")
	boosted.stamina = 99
	boosted.mana = 99
	check(boosted.effects()["stamina_after"] == 6 and boosted.effects()["mana_after"] == 3, "Unused pools never accumulate into a future round")
	check(boosted.has_method("set_item_priority"), "Priority editing has a guarded model API")
	if boosted.has_method("set_item_priority"):
		check(boosted.call("set_item_priority", charm["id"], 3) and charm["priority"] == 3, "Items can share selectable priority levels")
		check(boosted.call("set_item_priority", charm["id"], 0) and charm["priority"] == 0, "Priority zero clears explicit priority")
		check(not boosted.call("set_item_priority", charm["id"], -1), "Negative priorities are rejected")
		check(not boosted.call("set_item_priority", charm["id"], 10), "Priority editing matches the selector range")
	await _ui_checks()
	var numbered_scene: PackedScene = load("res://components/inventory/item_slot/numbered_item_slot.tscn")
	check(numbered_scene != null, "Numbered item tiles have a reusable scene variant")
	if numbered_scene != null:
		var slot: Control = numbered_scene.instantiate()
		root.add_child(slot)
		check(slot.get("corner_number") == 1, "Numbered tile variant exposes its number in the Inspector")
		slot.set("corner_number", 0)
		check(not slot.get_node("CornerNumber").visible, "Clearing a tile number removes the whole compartment")
		slot.set("corner_number", 9)
		check(slot.get_node("CornerNumber").visible, "The tile component supports the full numbered range")
		slot.set("occupied", false)
		check(not slot.get_node("CornerNumber").visible, "Empty tiles hide their numbered compartment")
		slot.free()
	var demo: Control = load("res://components/inventory/item_slot/numbered_tile_demo.tscn").instantiate()
	root.add_child(demo)
	await _resource_snapshot("tile-component")
	demo.free()
	report("ROUND RESOURCES RESULT")
	quit(1 if failures else 0)

func _ui_checks() -> void:
	root.size = Vector2i(1280, 800)
	root.gui_embed_subwindows = true
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.run_saves.directory = preload("res://tests/support/artifact_paths.gd").path("legacy_godot/round-resources-test-saves")
	game.start_run("warrior", 42)
	await process_frame
	var board: BackpackBoard = game.board
	var item: Dictionary = game.run.items[0]
	await _resource_snapshot("preparation")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.ctrl_pressed = true
	click.position = board.item_rect(item).position + Vector2.ONE * 20
	board._gui_input(click)
	check(board.dragging.is_empty(), "Ctrl-click does not begin dragging")
	check(item["priority"] == 1, "Ctrl-left-click assigns highest priority from the default")
	check(board.get_node_or_null("PriorityPicker") == null, "Priority editing opens no popup")
	click.button_index = MOUSE_BUTTON_RIGHT
	board._gui_input(click)
	check(item["priority"] == 0 and board.dragging.is_empty(), "Ctrl-right-click clears priority one without dragging")
	board._gui_input(click)
	check(item["priority"] == 9, "Ctrl-right-click cycles from unprioritized to nine")
	click.button_index = MOUSE_BUTTON_LEFT
	board._gui_input(click)
	check(item["priority"] == 0, "Ctrl-left-click cycles from nine to unprioritized")
	await _resource_snapshot("no-priority")
	for index in range(9):
		board._gui_input(click)
	check(item["priority"] == 9, "Cycling traverses all nine explicit levels")
	await _resource_snapshot("priority-corner")
	check(board.has_method("priority_corner"), "Tile priority corner has explicit geometry")
	if board.has_method("priority_corner"):
		var irregular: Dictionary = PackCatalog.item("ember_tome")
		irregular["rotation"] = 2
		var corner: Vector2i = board.call("priority_corner", PackRun.offsets(irregular, 2))
		check(corner == Vector2i(1, 0), "Rotated irregular items use the leftmost occupied cell in the top row")
	check(game.get("stamina_bar") != null, "Gameplay includes a stamina bar")
	check(game.stamina_bar.value == 4 and game.stamina_bar.max_value == 4 and game.stamina_bar.number_mode == PixelStatBar.NumberMode.HIDDEN, "Stamina bar includes Iron Charm maximum bonus without a visible number")
	game.run.start_combat()
	board._gui_input(click)
	check(item["priority"] == 9, "Combat prevents incrementing priority")
	click.button_index = MOUSE_BUTTON_RIGHT
	board._gui_input(click)
	check(item["priority"] == 9, "Combat prevents decrementing priority")
	game.run.set_combat_paused(true)
	check(not game.run.set_item_priority(item["id"], 1), "Paused combat also locks priorities")
	game._cancel_combat()
	game.queue_free()
	await process_frame

func _resource_snapshot(suffix: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(preload("res://tests/support/artifact_paths.gd").path("legacy_godot/round-resources-%s.png") % suffix)
