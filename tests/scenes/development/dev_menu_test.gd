extends "res://tests/support/test_case.gd"

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	check(game.has_node("DevMenu"), "Main scene includes editable developer panel")
	if not game.has_node("DevMenu"):
		await preload("res://tests/support/automatic_combat_cleanup.gd").release(self, game)
		report("DEV PANEL")
		quit(1)
		return
	game.start_run("warrior", 1729)
	var panel = game.get_node("DevMenu")
	check(not panel.host.is_open, "Panel starts closed")
	var event := InputEventKey.new()
	event.keycode = KEY_F8
	event.pressed = true
	check(preload("res://systems/application/keybindings.gd").matches(event, "dev_menu"), "F8 is developer shortcut")
	game._input(event)
	check(panel.host.is_open, "F8 opens panel")
	check(panel.get_node("Overlay").visible, "Panel overlay visible")
	await _review_rendered_layout(game, panel)
	panel.search.text = "rusty_knife"
	panel._filter_catalog()
	check_equal(panel.catalog_list.item_count, 1, "Search matches stable ID")
	panel.catalog_list.select(0)
	var before: int = game.run.items.size()
	panel.quantity.value = 2
	panel._grant_selected()
	check_equal(game.run.items.size(), before + 2, "Grant control uses quantity")
	for flag: String in panel.SESSION.FLAGS: panel.host.session.set_cheat(flag, true)
	panel.host.changed.emit()
	event = InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	game._input(event)
	check(not panel.host.is_open, "Escape closes developer panel")
	check(game.modal_kind != "pause", "Escape does not also open pause menu")
	check(panel.indicator.visible and panel.indicator.text.contains("Infinite mana"), "Active cheat indicator stays visible")
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		check(panel.indicator.get_global_rect().end.x <= root.get_visible_rect().end.x, "All active cheats fit the closed-panel indicator")
		root.get_texture().get_image().save_png(artifact_path("captures/dev_active_cheats.png"))
	game.loading_screen.active = true
	check(not panel.host.open(), "Cannot open during loading")
	game.loading_screen.active = false
	game.dev_menu.host.session.clear_cheats()
	var mage_only_key: String = ""
	var restrictions = preload("res://systems/content/content_restrictions.gd")
	for entry: Dictionary in panel.host.commands.catalog("items"):
		if restrictions.allows(entry, "mage") and not restrictions.allows(entry, "warrior"):
			mage_only_key = str(entry.key)
			break
	check(not mage_only_key.is_empty(), "Catalog has a class-restricted fixture")
	panel.search.text = mage_only_key
	panel._filter_catalog()
	check(panel.catalog_list.get_item_text(0).contains("class restricted"), "Warrior catalog marks mage-only content")
	game.start_run("mage", 1729)
	panel.host.open()
	check(not panel.catalog_list.get_item_text(0).contains("class restricted"), "Opening in another class refreshes eligibility labels")
	await preload("res://tests/support/automatic_combat_cleanup.gd").release(self, game)
	report("DEV PANEL")
	quit(1 if failures else 0)

func _review_rendered_layout(game: Control, panel: CanvasLayer) -> void:
	if DisplayServer.get_name() == "headless":
		print("Rendered developer-panel review skipped: headless renderer.")
		return
	for window_size: Vector2i in [Vector2i(800, 450), Vector2i(1440, 900)]:
		root.size = window_size
		for tab in range(5):
			panel.get_node("%Tabs").current_tab = tab
			for frame in range(4): await process_frame
			await RenderingServer.frame_post_draw
			var overlay: Control = panel.get_node("Overlay")
			var frame: Control = panel.get_node("Overlay/Margin/Panel")
			check(frame.size.x <= overlay.size.x and frame.size.y <= overlay.size.y, "Panel fits viewport at %s tab %d" % [window_size, tab])
			root.get_texture().get_image().save_png(artifact_path("captures/dev_%dx%d_tab_%d.png" % [window_size.x, window_size.y, tab]))
	panel.get_node("%Tabs").current_tab = 0
