extends SceneTree

var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	await process_frame
	game.start_run("mage", 42)
	for index in range(game.character_tabs.get_tab_count()):
		game.character_tabs.current_tab = index
		for i in range(10):
			await process_frame
		var tab: Control = game.character_tabs.get_tab_control(index)
		if tab.name == "Backpack":
			var bounds: Rect2 = BackpackBoard.GRID_RECT
			bounds.position += game.board.position
			check(absf(bounds.position.x - (tab.size.x - bounds.end.x)) <= 1, "Backpack grid has balanced side margins")
		if tab.name == "Statistics":
			var search: Control = tab.get_node("Search")
			var scroll: Control = tab.get_node("Scroll")
			check(search.position.x == 22 and absf(tab.size.x - search.get_rect().end.x - 22) < 1, "Search has equal side padding")
			check(search.position.x == scroll.position.x and search.get_rect().end.x == scroll.get_rect().end.x, "Search and scrollbar viewport align")
		elif tab.name == "Logs":
			var history: Control = tab.get_node("History")
			var footer: Control = tab.get_node("Navigation")
			check(history.position.x == 22 and absf(tab.size.x - history.get_rect().end.x - 22) < 1, "Log has equal side padding")
			check(history.position.x == footer.position.x and history.get_rect().end.x == footer.get_rect().end.x, "Log and footer share side boundaries")
			check(history.get_rect().end.y + 12 == footer.position.y, "Scrollbar clears footer")
		elif tab.name == "Relics":
			var grid: Control = tab.get_node("Grid")
			check(absf(grid.position.x - (tab.size.x - grid.get_rect().end.x)) <= 2, "Relic grid is centered")
			check(grid.position.y == 22, "Relics share top inset")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.tmp/tab-padding-" + str(tab.name) + ".png")
	await preload("res://tests/automatic_combat_cleanup.gd").release(self, game)
	print("Character padding failures: ", failures)
	quit(1 if failures else 0)
