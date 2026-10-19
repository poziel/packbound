extends "res://tests/support/battle_ui_support.gd"

func _run() -> void:
	create_timer(30).timeout.connect(func() -> void: printerr("Item grid style test timed out"); quit(2))
	render = DisplayServer.get_name() != "headless"
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
	game.run.relics.assign(["blood_pact", "returning_guard", "plague_seal", "last_thread"])
	game.run.last_thread_used = true
	game._refresh()
	game.character_tabs.current_tab = _tab_index("Relics")
	await process_frame
	await process_frame
	var page: Control = game.character_tabs.get_node("Relics")
	var grid: GridContainer = page.get_node("Grid")
	check(grid.columns == 6, "Relics have exactly six columns")
	_check_grid_fit(page, grid)
	check(game.relic_slots.size() == 42, "Standard page fits seven complete rows of relic sockets")
	for index in range(game.relic_slots.size()):
		var slot: Panel = game.relic_slots[index]
		check(slot.get_script() == load("res://components/inventory/item_slot/item_slot.gd"), "Relics use the shared socket component")
		if index >= game.run.relics.size():
			check(slot.get_node("Art").texture == null and not slot.occupied and game._relic_inspection(index).is_empty(), "Unfilled relic slot stays visually and interactively empty")
			check(slot.focus_mode == Control.FOCUS_NONE, "Empty relics do not clutter keyboard focus")
	check(is_equal_approx(game.relic_slots[3].get_node("Art").modulate.a, 0.4), "Consumed relic still has its dimmed sprite")
	await _snapshot("item-grid-relics")
	_motion(game.relic_slots[10].get_global_rect().get_center())
	await create_timer(0.3).timeout
	check(game.inspector.windows.is_empty(), "Empty socket hover opens no tooltip")
	_motion(game.relic_slots[0].get_global_rect().get_center())
	await create_timer(0.3).timeout
	check(not game.inspector.windows.is_empty() and game.inspector.windows[0].key == "relic_blood_pact", "Filled relics retain hover inspection")
	game.inspector.clear()
	_motion(Vector2(640, 90))
	game.character_tabs.current_tab = 0
	game.run.items.clear()
	var layout: Dictionary = {"shortbow": Vector2i(0, 0), "frost_wand": Vector2i(2, 0), "hunting_trap": Vector2i(3, 0), "warding_sigil": Vector2i(5, 3), "battle_axe": Vector2i(0, 3), "thorn_mail": Vector2i(0, 5), "hourglass": Vector2i(2, 5)}
	for key in layout:
		var item: Dictionary = game.run.add_item(key)
		check(game.run.can_place(item, layout[key]), "Style review arrangement is valid")
		item["cell"] = layout[key]
	for key in PackCatalog.ROSTER:
		game.run.add_item(key)
	game.run.mana = 12
	game._refresh()
	await process_frame
	check(game.board.get_node("Cell1_1").get_script() == game.relic_slots[0].get_script(), "Backpack sockets share the relic frame")
	await _snapshot("item-grid-backpack")
	game._toggle_storage()
	await process_frame
	await process_frame
	check(not game.storage.has_node("Grid") and game.storage.pile != null, "Stash uses a physics pile instead of sockets")
	await _snapshot("item-grid-storage")
	game._close_storage()
	await _resizing_checks()
	report("ITEM GRID STYLE RESULT")
	test_viewport.queue_free()
	await process_frame
	quit(1 if failures else 0)

func _check_grid_fit(page: Control, grid: GridContainer) -> void:
	var visible_slots: Array[Control] = []
	for child: Control in grid.get_children():
		if child.visible:
			visible_slots.append(child)
	check(visible_slots.size() % 6 == 0 and visible_slots.size() >= 6, "Only complete rows are visible")
	var side: float = visible_slots[0].size.x
	for index in range(visible_slots.size()):
		var slot: Control = visible_slots[index]
		check(slot.size == Vector2.ONE * side, "Every socket is the same square size")
		check(page.get_global_rect().encloses(slot.get_global_rect()), "Every visible socket fits the page")
		if index > 0 and index % 6 != 0:
			check(slot.global_position.x >= visible_slots[index - 1].get_global_rect().end.x + 6, "Columns retain their breathing room")
	check(grid.position.y + grid.size.y + 6 + side > page.size.y - 14, "One more complete row would exceed the available page")

func _resizing_checks() -> void:
	var page := Control.new()
	page.size = Vector2(584, 688)
	var grid := GridContainer.new()
	grid.set_script(load("res://scenes/run/character/tabs/relics/relic_grid.gd"))
	page.add_child(grid)
	test_viewport.add_child(page)
	for dimensions in [Vector2(584, 688), Vector2(584, 960), Vector2(584, 400), Vector2(720, 688)]:
		page.size = dimensions
		await process_frame
		await process_frame
		_check_grid_fit(page, grid)
	page.queue_free()
	await process_frame
