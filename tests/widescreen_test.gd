extends "res://tests/menu_test.gd"

func _run() -> void:
	create_timer(30).timeout.connect(func() -> void: quit(2))
	check(ProjectSettings.get_setting("display/window/size/viewport_width") == 1280 and ProjectSettings.get_setting("display/window/size/viewport_height") == 720, "Base canvas is 1280 by 720")
	for dimensions: Vector2i in PackMenuFlow.SIZES:
		check(dimensions.x * 9 == dimensions.y * 16, "Every selectable resolution is 16:9")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var canvas := Rect2(Vector2.ZERO, Vector2(1280, 720)).grow(-5)
	for button: Control in [game.front.play_button, game.front.quit_button]:
		check(canvas.encloses(button.get_global_rect()), "Home button fits: " + button.name)
	await snapshot("widescreen/main-menu")
	game.front.show_classes()
	await process_frame
	check(canvas.encloses(game.front.selection.get_node("Back").get_global_rect()), "Class selection Back fits the shorter screen")
	check(game.front.selection.get_node("RosterScroll").get_global_rect().end.y < game.front.selection.get_node("Back").global_position.y, "Roster stays above Back")
	await snapshot("widescreen/class-selection")
	game.front.show_options()
	for index in game.front.option_tabs.get_tab_count():
		game.front.option_tabs.current_tab = index
		await process_frame
		check(canvas.encloses(game.front.back_button.get_global_rect()) and canvas.encloses(game.front.reset_button.get_global_rect()), "Options footer fits in every section")
		await snapshot("widescreen/options-%d" % index)
	for index in PackMenuFlow.SIZES.size():
		check(game.front.resolution.get_item_text(index) == "%d x %d" % [PackMenuFlow.SIZES[index].x, PackMenuFlow.SIZES[index].y], "Resolution label matches its actual window size")
	game.start_run("warrior", 42)
	await process_frame
	await process_frame
	check(canvas.encloses(game.action.get_global_rect()), "Attack button fits inside the game frame")
	for button: Button in [game.storage_button, game.item_reward_button, game.relic_reward_button]:
		check(canvas.encloses(button.get_global_rect()), "Navigation button fits the 16:9 game view: " + button.name)
	var grid: Rect2 = BackpackBoard.GRID_RECT
	grid.position += game.board.global_position
	check(canvas.encloses(grid), "All seven inventory rows fit without shrinking item cells")
	check(BackpackBoard.CELL == 64, "Inventory retains its two-times source-pixel display scale")
	var separator: Control = game.character_tabs.get_parent().get_node_or_null("TabInfoSeparator")
	check(separator != null, "Tab strip and run information have a dedicated separator")
	for index in game.character_tabs.get_tab_count():
		game.character_tabs.current_tab = index
		await process_frame
		if separator != null:
			var bar: TabBar = game.character_tabs.get_tab_bar()
			var last: Rect2 = bar.get_tab_rect(bar.get_tab_count() - 1)
			check(separator.size.x == 5 and separator.size.y == bar.size.y, "Separator is a slim full-height header division")
			check(is_equal_approx(separator.global_position.x, bar.global_position.x + last.end.x), "Separator follows the end of the native tabs (tab %d: %s versus %s)" % [index, separator.global_position.x, bar.global_position.x + last.end.x])
			check(separator.get_global_rect().end.x < game.encounter_label.global_position.x, "Run information stays clear of the separator")
		await snapshot("widescreen/character-%d" % index)
	game.character_tabs.current_tab = 0
	game.storage_button.pressed.emit()
	check(canvas.encloses(game.storage.get_global_rect()), "Unused items fit inside the shorter room")
	await snapshot("widescreen/unused-items")
	game._close_storage()
	game.settings_button.pressed.emit()
	await snapshot("widescreen/pause")
	if DisplayServer.get_name() != "headless":
		for index in PackMenuFlow.SIZES.size():
			game.front._set_option("resolution", index)
			await process_frame
			await process_frame
			check(root.size == PackMenuFlow.SIZES[index], "Resolution option applies its actual window dimensions")
			check(is_equal_approx(game.size.x / game.size.y, 16.0 / 9.0), "Canvas keeps its 16:9 ratio at each window size")
		root.size = Vector2i(1280, 800)
		await process_frame
		await process_frame
		check(is_equal_approx(game.size.x / game.size.y, 16.0 / 9.0), "A differently shaped window letterboxes instead of stretching the game")
		game.front._set_option("resolution", 1)
	await preload("res://tests/automatic_combat_cleanup.gd").release(self, game)
	print("WIDESCREEN RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
