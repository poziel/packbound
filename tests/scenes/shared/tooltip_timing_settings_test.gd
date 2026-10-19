extends "res://tests/support/test_case.gd"

func _initialize() -> void:
	if not require_isolation():
		return
	_run.call_deferred()

func _run() -> void:
	create_timer(30).timeout.connect(func() -> void: quit(2))
	var legacy := ConfigFile.new()
	legacy.set_value("options", "music", 37)
	legacy.set_value("options", "tooltip_lock_delay", 1.7)
	legacy.save("user://packbound_settings.cfg")
	var game: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var menu: PackMenuFlow = game.front
	check(is_equal_approx(menu.settings.tooltip_lock_delay, 1.7) and menu.settings.music == 37, "Existing lock preference and unrelated audio setting survive migration")
	for key: String in PackMenuFlow.TOOLTIP_TIMINGS:
		var specification: Array = PackMenuFlow.TOOLTIP_TIMINGS[key]
		var slider: HSlider = menu.tooltip_sliders[key]
		check(slider.min_value == 0 and slider.max_value == specification[0] and slider.step == specification[1], "Slider limits and step: " + key)
		if key != "tooltip_lock_delay":
			check(is_equal_approx(menu.settings[key], specification[2]), "Missing preference gets approved default: " + key)
		for value: float in [0.0, specification[1], specification[0]]:
			slider.value = value
			check(is_equal_approx(menu.settings[key], value), "Slider saves selected value: " + key)
		menu._set_option(key, -1)
		check(menu.settings[key] == 0, "Lower bound supports immediate transition: " + key)
		menu._set_option(key, 99)
		check(menu.settings[key] == specification[0], "Upper bound clamps: " + key)
		menu._set_option(key, specification[1] * 1.2)
		check(is_equal_approx(menu.settings[key], specification[1]), "Values snap to configured step: " + key)
	menu._set_option("tooltip_opening_delay", 0.25)
	menu._set_option("tooltip_lock_delay", 0.4)
	menu._set_option("tooltip_grace_delay", 0.9)
	menu._set_option("tooltip_closing_delay", 1.3)
	check(game.inspector.show_delay == 0.25 and is_equal_approx(game.inspector.lock_delay, 0.4), "Opening and lock settings apply live")
	check(is_equal_approx(game.inspector.grace_delay, 0.9) and is_equal_approx(game.inspector.closing_delay, 1.3), "Grace and closing settings apply independently")
	check(menu.tooltip_labels.tooltip_opening_delay.text == "0.25 s", "Opening label preserves hundredths")
	var loaded := PackMenuFlow.new()
	loaded._load_settings()
	for key: String in PackMenuFlow.TOOLTIP_TIMINGS:
		check(is_equal_approx(loaded.settings[key], menu.settings[key]), "Timing persists across reload: " + key)
	loaded.free()
	menu._set_option("tooltips", false)
	for slider: HSlider in menu.tooltip_sliders.values():
		check(not slider.editable, "Tooltip toggle disables each timing slider")
	menu._reset_options()
	for key: String in PackMenuFlow.TOOLTIP_TIMINGS:
		check(is_equal_approx(menu.settings[key], PackMenuFlow.TOOLTIP_TIMINGS[key][2]) and menu.tooltip_sliders[key].editable, "Reset restores approved timing default: " + key)
	menu.show_options()
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(preload("res://tests/support/artifact_paths.gd").path("legacy_tasks/tooltip-behavior/options.png"))
	report("TOOLTIP SETTINGS")
	await preload("res://tests/support/automatic_combat_cleanup.gd").release(self, game)
	quit(1 if failures else 0)
