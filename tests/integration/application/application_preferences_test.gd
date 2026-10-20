extends "res://tests/support/test_case.gd"

func _run() -> void:
	var menu = load("res://scenes/menus/menu_flow/menu_flow.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	check(menu.settings.has("max_fps"), "Preferences include a persistent maximum FPS")
	check(menu.settings.has("reduce_unfocused_fps"), "Preferences include background throttling")
	check(menu.settings.has("software_cursor"), "Preferences include cursor selection")
	check(menu.keybindings.has("tooltip_visibility"), "Tooltip visibility shortcut is rebindable")
	check_equal(menu.BINDINGS.normalize(menu.keybindings["tooltip_visibility"]).key, KEY_CTRL, "Tooltip shortcut defaults to Control")
	if not menu.settings.has("max_fps"):
		menu.queue_free()
		report("APPLICATION PREFERENCES")
		quit(1)
		return
	menu._set_option("max_fps", 144)
	menu._set_option("reduce_unfocused_fps", true)
	menu._set_option("mute_unfocused", true)
	menu._set_option("show_fps", true)
	var runtime = menu.get_node("ApplicationPreferences")
	runtime.set_focused(false)
	check_equal(Engine.max_fps, 10, "Unfocused application is capped at 10 FPS")
	if DisplayServer.get_name() != "headless":
		await process_frame
		var started := Time.get_ticks_msec()
		for i in 6:
			await process_frame
		check(Time.get_ticks_msec() - started >= 450, "Rendered background frames actually obey the 10 FPS cap")
	check(AudioServer.is_bus_mute(0), "Unfocused application mutes Master")
	menu._set_option("volume", 42)
	check(AudioServer.is_bus_mute(0), "Changing volume while unfocused preserves focus mute")
	runtime.set_focused(true)
	check_equal(Engine.max_fps, 144, "Refocusing restores selected FPS cap")
	menu.hide()
	check(runtime.fps.is_visible_in_tree(), "FPS overlay stays visible while menu is hidden for gameplay")
	menu.show()
	check(not AudioServer.is_bus_mute(0), "Refocusing restores audible Master")
	check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(0)), 0.42), "Focus mute preserves configured volume")
	menu._set_option("volume", 0)
	runtime.set_focused(false)
	runtime.set_focused(true)
	check(AudioServer.is_bus_mute(0), "Refocusing preserves intentional zero volume")
	menu._set_option("max_fps", 5)
	runtime.set_focused(false)
	check_equal(Engine.max_fps, 5, "Background cap never raises a lower foreground cap")
	runtime.set_focused(true)
	menu._set_option("max_fps", 0)
	check_equal(Engine.max_fps, 0, "Unlimited FPS is restored")
	menu._set_option("invert_tooltip_shortcut", true)
	var inspector := PackInspector.new()
	root.add_child(inspector)
	check(inspector.visibility_shortcut_allows_tooltips(), "Normal shortcut shows tooltips without Control")
	inspector.apply_timing(menu.settings)
	check(not inspector.visibility_shortcut_allows_tooltips(), "Inverted shortcut hides tooltips without Control")
	var control := InputEventKey.new()
	control.keycode = KEY_CTRL
	control.pressed = true
	control.ctrl_pressed = true
	Input.parse_input_event(control)
	Input.flush_buffered_events()
	check(inspector.visibility_shortcut_allows_tooltips(), "Inverted shortcut shows tooltips while Control is held")
	inspector.invert_visibility_shortcut = false
	check(not inspector.visibility_shortcut_allows_tooltips(), "Normal shortcut hides tooltips while Control is held")
	var window: PackInspectWindow = inspector.WINDOW.instantiate()
	inspector.add_child(window)
	inspector.windows.append(window)
	inspector.pending = {"key": "health"}
	inspector._process(0.0)
	check(inspector.windows.is_empty() and inspector.pending.is_empty(), "Hiding tooltips clears both open chain and pending opening")
	control.pressed = false
	control.ctrl_pressed = false
	Input.parse_input_event(control)
	Input.flush_buffered_events()
	inspector.queue_free()
	menu.audio.play_item_hover()
	check(menu.audio.item_hover_fx.pitch_scale >= 0.9 and menu.audio.item_hover_fx.pitch_scale <= 1.1, "Shared item hover uses random-pitch playback")
	menu._set_option("software_cursor", true)
	check(runtime.cursor.visible, "Software mode draws its fallback cursor while focused")
	runtime.set_focused(false)
	check(not runtime.cursor.visible, "Software cursor hides on focus loss")
	runtime.set_focused(true)
	check(runtime.cursor.visible, "Software cursor returns on focus gain")
	runtime._set_pointer_inside(false)
	check(not runtime.cursor.visible, "Software cursor hides when pointer leaves the window")
	runtime._set_pointer_inside(true)
	if DisplayServer.get_name() != "headless":
		check_equal(Input.mouse_mode, Input.MOUSE_MODE_HIDDEN, "Software mode hides the OS pointer")
		menu.show_options()
		for index in 3:
			menu.option_tabs.current_tab = index
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(artifact_path("preferences-tab-%d.png" % index))
		check(runtime.fps.visible and runtime.fps.text.ends_with("FPS"), "FPS overlay remains visible in options")
	var restored := PackMenuFlow.new()
	restored._load_settings()
	for key: String in ["max_fps", "show_fps", "reduce_unfocused_fps", "mute_unfocused", "software_cursor", "invert_tooltip_shortcut"]:
		check_equal(restored.settings[key], menu.settings[key], "Preference survives save/load: " + key)
	restored.free()
	menu._reset_options()
	check_equal(Engine.max_fps, 0, "Reset restores unlimited foreground FPS")
	check(not menu.settings["software_cursor"], "Reset restores system cursor")
	if DisplayServer.get_name() != "headless":
		check_equal(Input.mouse_mode, Input.MOUSE_MODE_VISIBLE, "System mode restores the OS pointer")
	menu.queue_free()
	await process_frame
	report("APPLICATION PREFERENCES")
	quit(1 if failures else 0)
