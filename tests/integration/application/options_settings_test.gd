extends "res://tests/support/menu_support.gd"

func _run() -> void:
	var legacy := ConfigFile.new()
	check_equal(legacy.load("res://tests/fixtures/legacy_settings.cfg"), OK, "Legacy settings fixture loads")
	check_equal(legacy.save("user://packbound_settings.cfg"), OK, "Legacy fixture copies into the isolated profile")
	var fresh := PackMenuFlow.new()
	fresh._load_settings()
	check(fresh.settings["window_mode"] == 1 and fresh.settings["music"] == 31, "Legacy fullscreen migrates without losing other preferences")
	fresh.free()
	legacy.set_value("options", "fullscreen", false)
	legacy.save("user://packbound_settings.cfg")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var menu: PackMenuFlow = game.front
	menu.show_options()
	check(menu.options.theme == load("res://themes/gameplay/theme.tres"), "Options inherits the gameplay theme")
	check(menu.options.get_node("Background").color == game.pause_screen.get_node("Background").color, "Options matches the pause background exactly")
	for control: Control in menu.options.find_children("*", "Control", true, false):
		if control is CheckButton or control is HSlider or control is OptionButton or control is LineEdit:
			check(control.theme == null and not control.has_theme_stylebox_override("normal"), "Input inherits its shared skin: " + control.name)
		if control is OptionButton:
			check(control.get_theme_stylebox("hover_pressed") == menu.options.theme.get_stylebox("pressed", "OptionButton"), "Open select keeps its gameplay skin: " + control.name)
			check(control.get_theme_color("font_hover_pressed_color") == menu.options.theme.get_color("font_color", "OptionButton"), "Open select keeps its gameplay text color: " + control.name)
	check(menu.tips_toggle.get_theme_stylebox("normal") is StyleBoxEmpty, "Switch has no button surface behind it")
	check(menu.tips_toggle.get_theme_icon("checked").get_width() == 48, "Switch skin has its intended native dimensions")
	menu.option_tabs.current_tab = 1
	menu._set_option("brightness", 120)
	menu._set_option("contrast", 85)
	check(menu.adjustment.visible and menu.adjustment.material.get_shader_parameter("brightness") == 1.2, "Brightness reaches the full-screen shader")
	check(is_equal_approx(menu.adjustment.material.get_shader_parameter("contrast"), 0.85), "Contrast reaches the shader")
	menu.vsync_toggle.button_pressed = false
	check(not menu.settings["vsync"], "V-sync switch updates its saved preference")
	for mode in range(3):
		menu.window_mode.item_selected.emit(mode)
		check(menu.settings["window_mode"] == mode and menu.resolution.disabled == (mode != 0), "Window mode updates and only windowed mode enables size")
		if DisplayServer.get_name() != "headless":
			await create_timer(0.15).timeout
			check(root.mode == [Window.MODE_WINDOWED, Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN][mode], "Native window applies selected mode")
	menu._set_option("window_mode", 0)
	if DisplayServer.get_name() != "headless":
		check(DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_DISABLED, "Native V-sync mode updates")
	menu.option_tabs.current_tab = 0
	menu.name_display.item_selected.emit(1)
	menu.character_name.text = "Rowan"
	menu.character_name.text_changed.emit("Rowan")
	check(menu.character_name.editable and menu.player_name("warrior") == "Rowan", "Character naming uses the text input")
	menu._set_option("name_display", 0)
	check(not menu.character_name.editable and menu.player_name("warrior") == "Warrior", "Class naming retains the entered name for later")
	menu._set_option("name_display", 1)
	menu.option_tabs.current_tab = 3
	await process_frame
	click(menu.options.get_node("%pause"))
	key(KEY_P)
	check(menu.keybindings["pause"] == KEY_P and menu.capturing_action.is_empty(), "Pointer begins capture and a key binds pause")
	click(menu.options.get_node("%rotate_left"))
	key(KEY_P)
	check(menu.keybindings["rotate_left"] == KEY_Q and not menu.capturing_action.is_empty(), "Duplicate bindings are rejected without losing the old binding")
	key(KEY_ESCAPE)
	check(menu.options.visible and menu.capturing_action.is_empty(), "Escape cancels capture without leaving options")
	click(menu.options.get_node("%rotate_left"))
	key(KEY_Z)
	check(menu.keybindings["rotate_left"] == KEY_Z, "Rotation can be rebound")
	menu._begin_keybind("inspect")
	menu.option_tabs.current_tab = 0
	check(menu.capturing_action.is_empty(), "Changing section cancels capture")
	menu._begin_keybind("inspect")
	key(KEY_J)
	fresh = PackMenuFlow.new()
	fresh._load_settings()
	check(fresh.keybindings == menu.keybindings and fresh.settings == menu.settings, "Every preference and binding survives reload")
	fresh.free()
	game.start_run("warrior", 42)
	await process_frame
	check(game._character_inspection()["title"].begins_with("Rowan /"), "Character inspection displays the selected name")
	key(KEY_P)
	check(game.modal_kind == "pause" and game.modal.visible, "Rebound pause key opens the real gameplay pause menu")
	key(KEY_P)
	check(not game.modal.visible, "Rebound pause key resumes gameplay")
	await process_frame
	game.character_portrait.grab_focus()
	key(KEY_J)
	check(not game.inspector.windows.is_empty(), "Rebound inspection key opens focused character details")
	key(KEY_ESCAPE)
	check(game.inspector.windows.is_empty() and not game.modal.visible, "Escape closes inspection before pausing")
	game.board.begin_drag(game.run.items[0], Vector2(20, 20))
	var rotation: int = game.board.drag_rotation
	key(KEY_Z)
	check(not game.board.dragging.is_empty() and game.board.drag_rotation != rotation, "Rebound rotation key rotates a held inventory item")
	key(KEY_ESCAPE)
	check(game.board.dragging.is_empty(), "Fixed Escape still cancels dragging")
	# A rebound UI key must work even when a focused button would normally consume it.
	menu.keybindings["pause"] = KEY_SPACE
	menu.BINDINGS.apply(menu.keybindings)
	game.action.grab_focus()
	key(KEY_SPACE)
	check(game.modal.visible and game.modal_kind == "pause", "Rebound pause takes precedence over GUI activation")
	key(KEY_SPACE)
	check(not game.modal.visible, "Rebound pause resumes from focused menu controls")
	menu._reset_options()
	check(menu.settings == PackMenuFlow.DEFAULT_SETTINGS and menu.keybindings == menu.BINDINGS.DEFAULTS, "Reset restores both settings and bindings")
	check(not menu.adjustment.visible, "Neutral brightness and contrast bypass the shader")
	game.show_menu()
	menu.show_options()
	root.content_scale_size = Vector2i.ZERO
	DirAccess.make_dir_recursive_absolute(preload("res://tests/support/artifact_paths.gd").path("options-refresh"))
	for dimensions: Vector2i in [Vector2i(800, 450), Vector2i(1280, 720)]:
		root.size = dimensions
		await create_timer(0.1).timeout
		for index in range(4):
			menu.option_tabs.current_tab = index
			await process_frame
			await process_frame
			for control: Control in menu.options.find_children("*", "Control", true, false):
				if control.is_visible_in_tree() and not menu.option_tabs.get_current_tab_control().is_ancestor_of(control):
					check(menu.options.get_global_rect().grow(1).encloses(control.get_global_rect()), "Input fits at %s: %s" % [dimensions, control.name])
			await snapshot("options-refresh/%s-%dx%d" % [menu.option_tabs.get_tab_title(index).to_lower(), dimensions.x, dimensions.y])
	if DisplayServer.get_name() != "headless":
		menu.option_tabs.current_tab = 1
		await process_frame
		await RenderingServer.frame_post_draw
		var neutral: Color = root.get_texture().get_image().get_pixel(1000, 500)
		menu._set_option("brightness", 140)
		await process_frame
		await RenderingServer.frame_post_draw
		var brighter: Color = root.get_texture().get_image().get_pixel(1000, 500)
		check(brighter.r > neutral.r + 0.01, "Brightness changes actual rendered pixels")
		menu._set_option("brightness", 100)
		menu._set_option("contrast", 80)
		await process_frame
		await RenderingServer.frame_post_draw
		var lower_contrast: Color = root.get_texture().get_image().get_pixel(1000, 500)
		check(lower_contrast.r > neutral.r + 0.04, "Contrast changes actual rendered pixels")
		game.start_run("warrior", 42)
		await process_frame
		check(menu.adjustment.is_visible_in_tree(), "Display adjustment remains active when gameplay hides menu flow")
		menu._reset_options()
	await preload("res://tests/support/automatic_combat_cleanup.gd").release(self, game)
	report("OPTIONS SETTINGS RESULT")
	quit(1 if failures else 0)
