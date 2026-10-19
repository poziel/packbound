extends "res://tests/support/menu_support.gd"

func _run() -> void:
	var legacy := ConfigFile.new()
	legacy.set_value("options", "music", 37)
	check(legacy.save("user://packbound_settings.cfg") == OK, "Isolated settings storage is writable")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var menu: PackMenuFlow = game.front
	click(game.settings_button)
	await process_frame
	var background: ColorRect = menu.options.get_node("Background")
	check(background.is_visible_in_tree() and background.get_global_rect() == menu.options.get_global_rect().grow(-5), "Options fits within the shared five-pixel solid frame")
	var tabs: Array[Node] = menu.options.find_children("*", "TabContainer", true, false)
	check(tabs.size() == 1, "Options has section tabs")
	check(menu.settings.has("tooltip_lock_delay"), "Tooltip lock delay is a saved option")
	check(menu.settings["music"] == 37 and menu.settings["tooltip_lock_delay"] == 1.2, "Old preferences retain their values and get the approved 1.2-second tooltip default")
	check(game.inspector.lock_delay == 1.2, "Loaded lock time reaches the inspector on startup")
	check(menu.option_tabs.get_tab_count() == 4, "Four sections expose settings and keybinds")
	for index in range(4):
		check(menu.option_tabs.get_tab_title(index) == ["Gameplay", "Display", "Audio", "Keybinds"][index], "Tab has a descriptive section name")
	check(menu.option_tabs.get_tab_bar().has_focus(), "Opening options focuses the section tabs")
	key(KEY_RIGHT)
	check(menu.option_tabs.current_tab == 1 and menu.flash_toggle.is_visible_in_tree() and not menu.tips_toggle.is_visible_in_tree(), "Arrow keys switch to Display and hide Gameplay")
	key(KEY_RIGHT)
	check(menu.option_tabs.current_tab == 2 and menu.volume_sliders["music"].is_visible_in_tree(), "Arrow keys reach Audio")
	menu.option_tabs.current_tab = 0
	await process_frame
	menu.combat_speed.grab_focus()
	key(KEY_RIGHT)
	check(menu.settings["combat_speed"] == 1.5, "Keyboard increases combat speed by half a step")
	for option: String in ["player_response_delay", "enemy_response_delay"]:
		menu.combat_sliders[option].grab_focus()
		key(KEY_RIGHT)
		check(is_equal_approx(menu.settings[option], 1.6), "Keyboard increases response delay by one tenth")
		menu._set_option(option, 1.5)
	menu._set_option("combat_speed", 1.0)
	var slider: HSlider = menu.tooltip_lock_slider
	check(is_equal_approx(slider.min_value, 0.0) and is_equal_approx(slider.max_value, 2.0) and is_equal_approx(slider.step, 0.1), "Lock time offers zero through 2 seconds in tenths")
	slider.value = 0.3
	check(is_equal_approx(game.inspector.lock_delay, 0.3) and menu.tooltip_lock_value.text == "0.3 s", "Minimum lock time updates the real inspector and label")
	slider.grab_focus()
	key(KEY_RIGHT)
	check(is_equal_approx(slider.value, 0.4) and is_equal_approx(menu.settings["tooltip_lock_delay"], 0.4), "Keyboard adjusts the delay by a tenth of a second")
	click(slider)
	check(slider.value > 0.9 and slider.value < 1.4 and is_equal_approx(game.inspector.lock_delay, slider.value), "Pointer track input adjusts the persisted lock time")
	menu._set_option("tooltip_lock_delay", 99)
	check(is_equal_approx(slider.value, 2.0), "Out-of-range lock times clamp to two seconds")
	menu._set_option("tooltip_lock_delay", -1)
	check(is_equal_approx(slider.value, 0.0), "Zero lock time is supported")
	slider.value = 1.7
	var fresh := PackMenuFlow.new()
	fresh._load_settings()
	check(is_equal_approx(fresh.settings["tooltip_lock_delay"], 1.7) and fresh.settings["music"] == 37, "Delay reloads alongside unrelated preferences")
	fresh.free()
	menu.tips_toggle.button_pressed = false
	check(not slider.editable and not game.board.tooltips_enabled, "Disabling explanations disables their timing control")
	menu._set_option("flash", false)
	menu._set_option("combat_speed", 4)
	menu.volume_sliders["volume"].value = 0
	menu.reset_button.confirmed.emit()
	check(menu.settings == PackMenuFlow.DEFAULT_SETTINGS, "Reset restores every preference")
	check(slider.editable and is_equal_approx(slider.value, 1.2) and menu.tooltip_lock_value.text == "1.2 s", "Reset restores tooltip controls and runtime delay")
	check(menu.tips_toggle.button_pressed and menu.flash_toggle.button_pressed and menu.combat_speed.value == 1.0, "Reset synchronizes toggles and speed slider")
	check(menu.volume_sliders["music"].value == 70 and menu.volume_labels["music"].text == "70%", "Reset synchronizes audio controls")
	check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")), "Reset reapplies actual audio bus levels")
	check(game.board.tooltips_enabled and game.inspector.lock_delay == 1.2, "Reset immediately reapplies gameplay preferences")
	fresh = PackMenuFlow.new()
	fresh._load_settings()
	check(fresh.settings == PackMenuFlow.DEFAULT_SETTINGS, "Defaults persist for a later session")
	fresh.free()
	key(KEY_ESCAPE)
	check(menu.home.visible and not menu.options.visible and game.settings_button.has_focus(), "Escape returns to the main menu and restores focus")
	game.start_run("warrior", 42)
	game.show_pause()
	game._open_options()
	await process_frame
	check(menu.from_game and menu.options.visible and not game.combat.visible and not menu.home.visible, "The same options screen opens from gameplay")
	check(background.is_visible_in_tree() and background.get_global_rect() == menu.options.get_global_rect().grow(-5), "Gameplay options keeps the same shared solid frame")
	click(menu.back_button)
	check(game.combat.visible and not menu.visible and game.modal_kind == "pause", "Back returns to the paused run")
	game._open_options()
	key(KEY_ESCAPE)
	check(game.combat.visible and not menu.visible, "Escape also returns to the paused run")
	await _check_lock_timing(menu)
	game.show_menu()
	menu.show_options()
	# Disable window stretching to exercise the authored layout at actual small sizes.
	root.content_scale_size = Vector2i.ZERO
	for dimensions: Vector2i in [Vector2i(800, 500), Vector2i(960, 600), Vector2i(1280, 800), Vector2i(1600, 900), Vector2i(800, 900)]:
		root.size = dimensions
		await create_timer(0.1).timeout
		for index in range(4):
			menu.option_tabs.current_tab = index
			await process_frame
			await process_frame
			await _check_options_layout(menu)
			if dimensions in [Vector2i(800, 500), Vector2i(1280, 800)]:
				await snapshot("options-menu/%s-%dx%d" % [menu.option_tabs.get_tab_title(index).to_lower(), dimensions.x, dimensions.y])
	await preload("res://tests/support/automatic_combat_cleanup.gd").release(self, game)
	report("OPTIONS MENU RESULT")
	quit(1 if failures else 0)

func _check_options_layout(menu: PackMenuFlow) -> void:
	var canvas: Rect2 = menu.options.get_global_rect()
	for control: Control in menu.options.find_children("*", "Control", true, false):
		if control.is_visible_in_tree():
			var ancestor: Node = control.get_parent()
			var scroll: ScrollContainer
			while ancestor != menu.options:
				if ancestor is ScrollContainer:
					scroll = ancestor
					break
				ancestor = ancestor.get_parent()
			if scroll:
				var bounds: Rect2 = control.get_global_rect()
				check(bounds.position.x >= canvas.position.x and bounds.end.x <= canvas.end.x, "Scrollable settings fit horizontally: " + str(control.get_path()))
			else:
				check(canvas.grow(1).encloses(control.get_global_rect()), "Options control fits the viewport: " + str(control.get_path()))
	if menu.option_tabs.current_tab == 0:
		var scroll: ScrollContainer = menu.option_tabs.get_node("Gameplay")
		scroll.ensure_control_visible(menu.name_display)
		await process_frame
		check(scroll.get_global_rect().encloses(menu.name_display.get_global_rect()), "Last gameplay setting remains reachable by scrolling")
		scroll.scroll_vertical = 0
		await process_frame
	check(menu.option_tabs.get_global_rect().end.y <= menu.back_button.global_position.y, "Tab contents stay above the persistent footer")
	check(not menu.back_button.get_global_rect().intersects(menu.reset_button.get_global_rect()), "Back and Reset never overlap")
	for button: Button in [menu.back_button, menu.reset_button]:
		check(button.size.x >= button.get_minimum_size().x, "Footer label fits its button")
	for slider: HSlider in [menu.tooltip_lock_slider, menu.volume_sliders["music"], menu.combat_speed, menu.combat_sliders["player_response_delay"], menu.combat_sliders["enemy_response_delay"]]:
		if slider.is_visible_in_tree():
			check(slider.size.x >= 100, "Slider retains a usable track")

func _check_lock_timing(menu: PackMenuFlow) -> void:
	var inspector: PackInspector = game.inspector
	inspector.set_process(false)
	var source := Control.new()
	source.position = Vector2(40, 40)
	source.size = Vector2(32, 32)
	game.add_child(source)
	for delay: float in [0.3, 1.3, 2.0]:
		menu._set_option("tooltip_lock_delay", delay)
		inspector.enabled = true
		inspector.source = source
		inspector.source_rect = source.get_global_rect()
		inspector.pointer = inspector.source_rect.get_center()
		inspector._spawn({"key": "test", "title": "Test", "body": "Health"}, inspector.source_rect, -1)
		var window: PackInspectWindow = inspector.windows[0]
		inspector._process(delay - 0.01)
		check(not window.locked, "Tooltip stays unlocked before %.1f seconds" % delay)
		inspector._process(0.02)
		check(window.locked, "Tooltip locks at the selected %.1f seconds" % delay)
		inspector.clear()
	source.queue_free()
	menu._reset_options()
	await process_frame
	await process_frame
	inspector.set_process(true)
