extends "res://tests/menu_test.gd"

func _settle() -> void:
	await process_frame
	await process_frame
	await process_frame

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	var selection: Control = game.get_node("MenuFlow/ClassSelection")
	var grid: GridContainer = selection.get_node("RosterScroll/Margin/Characters")
	check(grid.get_child_count() == PackCatalog.classes().size(), "All existing delvers are authored scene instances")
	check(grid.get_child(0).scene_file_path == "res://scenes/menus/delver_tile.tscn", "Tiles share an editable scene asset")
	root.add_child(game)
	game.run_saves.directory = "res://.tmp/class-selection-saves-" + str(Time.get_ticks_usec())
	await _settle()
	game.front.show_classes()
	motion(Vector2(25, 25))
	await _settle()
	check(selection.inspector.windows.is_empty(), "Details are hidden until inspection")
	await snapshot("delver-grid")
	var previous: Rect2 = Rect2()
	for key_name: String in PackCatalog.classes():
		selection.inspector.clear()
		var button: Button = game.front.class_buttons[key_name]
		check(not previous.intersects(button.get_global_rect()), "Portrait tiles do not overlap")
		previous = button.get_global_rect()
		motion(button.get_global_rect().get_center())
		await create_timer(0.3).timeout
		await _settle()
		check(selection.inspector.windows.size() == 1, "Gameplay inspector opens for " + key_name)
		if selection.inspector.windows.is_empty():
			continue
		var window: PackInspectWindow = selection.inspector.windows[0]
		check(window.key == "class_" + key_name, "Tooltip names the hovered class")
		var readable_stats: String = window.body.get_parsed_text().replace(" \u2060\u00a0", "").replace("\ufffc", "")
		check(readable_stats.contains(str(PackCatalog.classes()[key_name]["hp"]) + " HP"), "Tooltip shows actual starting health")
		var starting: PackRun = PackRun.new()
		starting.reset(0, key_name)
		check(readable_stats.contains(str(starting.starting_resources()["mana"]) + " mana"), "Tooltip shows actual prepared starting mana")
		check(readable_stats.contains(PackCatalog.classes()[key_name]["detail"]), "Ability copy comes from the catalog")
		check(window.body.get_visible_line_count() == window.body.get_line_count(), "Entire ability description is visible")
		for index in range(3):
			var item_key: String = PackCatalog.classes()[key_name]["starters"][index]
			check(readable_stats.contains(PackCatalog.item(item_key)["name"]), "Starting item names match loadout")
		check(Rect2(Vector2.ZERO, selection.size).encloses(window.get_rect()), "Tooltip stays inside the logical canvas")
		check(window.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Unlocked tooltip does not intercept character clicks")
		check(not game.combat.visible, "Hover never starts a game")
		await snapshot("delver-tooltip-" + key_name)
	selection.inspector.windows[0].set_locked(true)
	selection.inspector._open_keyword_link("mana", 0, true)
	await _settle()
	check(selection.inspector.windows.size() == 2 and selection.inspector.windows[1].key == "mana", "Locked tooltip opens linked gameplay explanations")
	selection.inspector.clear()
	motion(Vector2(25, 25))
	await _settle()
	check(selection.inspector.windows.is_empty(), "Leaving the roster hides hover details")
	var warrior: Button = game.front.class_buttons["warrior"]
	warrior.grab_focus()
	key(KEY_F1)
	await _settle()
	check(selection.inspector.windows.size() == 1 and selection.inspector.windows[0].key == "class_warrior", "Keyboard inspection exposes the same details")
	selection.inspector.clear()
	warrior.grab_focus()
	key(KEY_RIGHT)
	await _settle()
	check(root.gui_get_focus_owner() == game.front.class_buttons["ranger"], "Arrow keys browse characters")
	key(KEY_ENTER)
	await game.loading_screen.finished
	await _settle()
	check(game.run.class_key == "ranger" and game.combat.visible, "Keyboard activation starts after loading screen")
	check(selection.inspector.windows.is_empty(), "Starting a run clears the tooltip")
	game.show_menu()
	game.front.show_classes()
	await _settle()
	click(game.front.class_buttons["necromancer"])
	await game.loading_screen.finished
	await _settle()
	check(game.run.class_key == "necromancer" and game.combat.visible, "One pointer click starts the hovered class")
	game.show_menu()
	game.front.show_classes()
	await _settle()
	key(KEY_ESCAPE)
	await game.loading_screen.finished
	check(game.front.runs.visible, "Escape returns to run selection")
	game.queue_free()
	await _settle()
	await _large_roster()
	print("CLASS SELECTION RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _large_roster() -> void:
	# Stress an expanded authored roster without adding fake classes to the game.
	var screen: Control = load("res://scenes/menus/class_selection.tscn").instantiate()
	var grid: GridContainer = screen.get_node("RosterScroll/Margin/Characters")
	var tile_scene: PackedScene = load("res://scenes/menus/delver_tile.tscn")
	for index in range(25):
		var tile: Button = tile_scene.instantiate()
		tile.class_key = "mage"
		grid.add_child(tile)
	root.add_child(screen)
	await _settle()
	check(grid.size.y > screen.scroll.size.y, "Large rosters expand vertically and scroll")
	check(grid.size.x <= screen.scroll.size.x, "Expanded roster requires no horizontal scrolling")
	var last: Button = grid.get_child(grid.get_child_count() - 1)
	last.grab_focus()
	key(KEY_F1)
	await _settle()
	check(screen.scroll.scroll_vertical > 0, "Keyboard focus scrolls to offscreen tiles")
	check(screen.scroll.get_global_rect().encloses(last.get_global_rect()), "Last row can be fully reached")
	check(screen.inspector.windows.size() == 1, "Focused tile in a scrolled row can be inspected")
	if not screen.inspector.windows.is_empty():
		check(Rect2(Vector2.ZERO, screen.size).encloses(screen.inspector.windows[0].get_rect()), "Tooltip near the bottom stays on screen")
	await snapshot("delver-grid-expanded")
	screen.scroll.scroll_vertical = 0
	await _settle()
	check(screen.inspector.windows.is_empty(), "Scrolling a focused tile out of view clears its tooltip")
	screen.queue_free()
	await _settle()
