extends "res://tests/menu_test.gd"

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.start_run("warrior", 42)
	await process_frame
	await process_frame
	check(not game.combat.has_node("CharacterPanel/PauseButton"), "The old pause button is removed from the authored scene")
	check(game.settings_button.theme == null and game.application_frame.theme.resource_path == "res://themes/gameplay/theme.tres", "The gear inherits the actual gameplay theme")
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		check(game.settings_button.get_theme_stylebox(state) is StyleBoxEmpty, "The gear stays transparent and borderless in " + state)
	check(game.pause_screen.theme.resource_path == "res://themes/gameplay/theme.tres", "Full-screen pause uses the gameplay theme")
	var panel: Control = game.combat.get_node("CharacterPanel")
	var bounds: Rect2 = panel.get_global_rect()
	check(bounds.position.y == 5 and bounds.end.x == game.size.x - 5 and bounds.end.y == game.size.y - 5, "Character panel meets the five-pixel top, right, and bottom frame")
	var body_style: StyleBox = panel.get_node("Frame").get_theme_stylebox("panel")
	check(body_style is StyleBoxFlat and body_style.get_border_width(SIDE_LEFT) == 0 and body_style.get_border_width(SIDE_RIGHT) == 0, "Character panel surface has no outline")
	var idle: StyleBox = game.character_tabs.get_theme_stylebox("tab_unselected")
	check(idle.get_script() != null and idle.get("bg_color") == Color(0.333, 0.365, 0.424, 1), "Rounded inactive tabs continue the shared gray frame")
	var frame_style: StyleBox = game.application_frame.get_node("Border").get_theme_stylebox("panel")
	check(frame_style.get_script() != null, "The frame has an editable stepped-corner style")
	check(frame_style.get("corner_radius") == 12 and frame_style.get("pixel_step") == 2, "Inner corners use twelve-pixel rounding resolved into two-pixel steps")
	for tab in range(game.character_tabs.get_tab_count()):
		game.character_tabs.current_tab = tab
		await process_frame
		await process_frame
		check(panel.get_global_rect().encloses(game.character_tabs.get_tab_control(tab).get_global_rect()), "Tab content fits the borderless character panel")
		await snapshot("frame-polish/gameplay-" + game.character_tabs.get_tab_control(tab).name.to_lower())
	click(game.settings_button)
	await process_frame
	await process_frame
	check(game.modal.visible and game.pause_screen.is_visible_in_tree(), "The transparent gear still opens full-screen pause navigation")
	await snapshot("frame-polish/pause")
	click(game.pause_buttons[0])
	await process_frame
	check(not game.modal.visible and game.combat.visible, "Gameplay-themed Resume still returns to the run")
	game.show_menu()
	await snapshot("frame-polish/home")
	game.front.show_classes()
	await snapshot("frame-polish/classes")
	game.front.show_options()
	await snapshot("frame-polish/options")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var picture: Image = root.get_texture().get_image()
		var gray: Color = Color(0.333, 0.365, 0.424, 1)
		for point: Vector2i in [Vector2i(0, 0), Vector2i(5, 5), Vector2i(12, 6), Vector2i(picture.get_width() - 6, picture.get_height() - 6)]:
			var pixel: Color = picture.get_pixelv(point)
			check(absf(pixel.r - gray.r) + absf(pixel.g - gray.g) + absf(pixel.b - gray.b) < 0.01, "Stepped corners continue the opaque gray frame at %s" % point)
		check(picture.get_pixel(13, 5) == Color.BLACK and picture.get_pixel(18, 18) == Color.BLACK, "The rounded opening exposes the page without a rectangular gray corner block")
	await preload("res://tests/automatic_combat_cleanup.gd").release(self, game)
	print("FRAME POLISH RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
