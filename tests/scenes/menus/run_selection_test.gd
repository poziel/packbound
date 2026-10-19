extends "res://tests/support/menu_support.gd"

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.run_saves.directory = preload("res://tests/support/artifact_paths.gd").path("legacy/run-save-test-") + str(Time.get_ticks_usec())
	game.front.runs.saves.directory = game.run_saves.directory
	game.front._transition_to_classes()
	await create_timer(1.2).timeout
	check(game.front.runs.visible and not game.front.selection.visible, "Start the descent opens run selection")
	click(game.front.runs.get_node("Margin/Layout/Actions/NewRun"))
	await game.loading_screen.finished
	check(game.front.selection.visible and not game.front.runs.visible, "New Run button opens Delver selection")
	await process_frame
	var grid: GridContainer = game.front.selection.grid
	check(grid.columns == 6 and grid.get_child_count() == 18, "Six by three roster has room for future Delvers")
	check(game.front.class_buttons.size() == 5, "Only five available Delvers can be selected")
	check(game.front.selection.theme.resource_path == "res://themes/gameplay/theme.tres", "Selection uses gameplay theme")
	check(grid.get_child(0).get_node("Portrait").get_script() == load("res://components/characters/character_preview/character_preview.gd"), "Selection reuses gameplay portrait frame")
	check(grid.size.y <= game.front.selection.scroll.size.y, "All three roster rows fit the viewport")
	await snapshot("new-delver-selection")
	game.start_run("warrior", 123)
	game.elapsed = 125.0
	game.run.items[0]["cell"] = Vector2i(3, 2)
	game.run.hp -= 3
	game._save_run()
	var first: String = game.active_run_id
	var saved: Dictionary = game.run_saves.read(first)
	check(not saved.is_empty(), "Run is saved to disk")
	check(saved.state.items[0].cell == Vector2i(3, 2), "Inventory cells survive Variant serialization")
	check(saved.elapsed == 125.0, "Elapsed playtime persists")
	var restored := PackRun.new()
	game.run_saves.restore(restored, saved)
	check(restored.hp == game.run.hp and restored.items == game.run.items, "Health and full inventory restore")
	check(restored.rng.randi() == game.run.rng.randi(), "Random sequence resumes deterministically")
	game.show_menu()
	game.start_run("warrior", 456)
	game.show_menu()
	check(game.run_saves.unfinished().size() == 2, "Same-class runs remain independent")
	game.front.show_runs()
	await process_frame
	await snapshot("new-run-selection")
	check(game.front.runs.rows.get_child_count() == 2, "Run list renders both saves")
	var runs: Control = game.front.runs
	check(not runs.message.visible and not game.front.selection.has_node("Hint"), "Both selection subtitles are removed")
	check(runs.get_node("Margin/Layout/Title").horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER, "Descent title is centered")
	var padding: int = runs.get_theme_constant("content_padding", "PackSurface")
	check(runs.get_node("Margin").offset_left == padding and runs.get_node("Margin").offset_bottom == -padding, "Run list uses shared padding including footer")
	check(game.front.selection.back.offset_bottom == -padding, "Delver footer uses the same shared padding")
	var heading: HBoxContainer = runs.rows.get_child(0).get_child(0).get_child(1).get_child(0)
	check(heading.get_child_count() == 2 and heading.get_child(1).get_theme_color("font_color") == runs.get_theme_color("header", "PackSurface"), "Name and muted floor/playtime share one row")
	var many: Dictionary = game.run_saves.read(first)
	many.state.relics = PackCatalog.RELICS.duplicate()
	var unused: Dictionary = PackCatalog.item("bandage")
	unused["id"] = many.state.next_id
	unused["cell"] = null
	many.state.items.append(unused)
	many.state.next_id += 1
	var rotated: Dictionary = PackCatalog.item("ember_tome")
	rotated["id"] = many.state.next_id
	rotated["cell"] = Vector2i(5, 3)
	rotated["rotation"] = 1
	rotated["shape"] = PackRun.dimensions(rotated)
	many.state.items.append(rotated)
	many.state.next_id += 1
	game.run_saves.write("preview-many", many)
	game.front.runs.refresh()
	await process_frame
	var preview: HBoxContainer = game.front.runs.rows.get_node("Run_preview-many").get_child(0).get_child(1).get_child(1)
	check(preview.get_child_count() == 9 and preview.get_child(8).text == "+1 more", "Only eight relics are previewed, with overflow count")
	check(preview.get_child(0).custom_minimum_size == Vector2(64, 64), "Relics use larger gameplay frames")
	await snapshot("new-run-selection-overflow")
	var row: Button = runs.rows.get_node("Run_preview-many")
	motion(row.get_global_rect().get_center())
	await process_frame
	await process_frame
	check(row.get_theme_stylebox("hover").bg_color == game.application_frame.border.get_theme_stylebox("panel").border_color, "Hovered descent uses application border color")
	await snapshot("descent-hover")
	var preview_button: Button = row.get_child(0).get_node("Actions/Inventory")
	click(preview_button)
	await process_frame
	await process_frame
	check(runs.inventory_preview.visible and not game.combat.visible, "Inventory button opens modal without resuming run")
	check(runs.inventory_preview.board.run.items == many.state.items, "Preview preserves saved inventory placement and rotation")
	check(runs.inventory_preview.board.run.items.back().rotation == 1, "Preview retains rotated multi-cell items")
	check(runs.inventory_preview.unused.get_child_count() == 1, "Preview includes unused items")
	var before: Array = runs.inventory_preview.run.items.duplicate(true)
	var board: BackpackBoard = runs.inventory_preview.board
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = board.item_rect(board.run.items[0]).get_center()
	board._gui_input(event)
	check(board.dragging.is_empty() and runs.inventory_preview.run.items == before, "Inventory preview is read-only")
	await snapshot("descent-inventory-preview")
	key(KEY_ESCAPE)
	await process_frame
	check(not runs.inventory_preview.visible and runs.visible and not game.loading_screen.active, "Escape closes only the inventory modal")
	check(root.gui_get_focus_owner() == preview_button, "Closing preview restores inventory button focus")
	check(game.run_saves.read("preview-many").state.items == many.state.items, "Preview does not modify the save")
	many.state.phase = PackRun.Phase.DEFEAT
	game.run_saves.write("preview-many", many)
	var data: Dictionary = game.run_saves.read(first)
	data["id"] = first
	click(game.front.runs.rows.get_node("Run_" + first))
	await game.loading_screen.finished
	check(game.active_run_id == first and absf(game.elapsed - 125.0) < 1.0 and game.run.hp == saved.state.hp, "Clicking a saved row restores rather than resets run")
	game.playback.start(game.run, 1.0, 0.18, 0.18)
	game._save_run()
	var midturn: Dictionary = game.run_saves.read(first)
	var pending: Dictionary = game.run.pending_turn.duplicate(true)
	game.show_menu()
	midturn["id"] = first
	game.start_run("warrior", -1, midturn)
	check(game.playback.active and game.playback.paused, "Mid-combat run resumes paused")
	check(game.run.pending_turn == pending, "Pending monster response is preserved")
	var expected := PackRun.new()
	game.run_saves.restore(expected, midturn)
	expected.complete_turn()
	game.playback.set_paused(false)
	game.playback._process(100.0)
	check(game.run.hp == expected.hp and game.run.enemy == expected.enemy, "Saved monster response resolves exactly once")
	game.run.phase = PackRun.Phase.DEFEAT
	game._save_run()
	check(game.run_saves.unfinished().size() == 1, "Finished runs leave unfinished list")
	game.active_run_id = ""
	game.queue_free()
	await process_frame
	report("RUN SELECTION RESULT")
	quit(1 if failures else 0)
