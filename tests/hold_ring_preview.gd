extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(940, 290)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var background := ColorRect.new()
	background.color = Color("101722")
	background.size = Vector2(940, 290)
	view.add_child(background)
	var layout := VBoxContainer.new()
	layout.position = Vector2(20, 20)
	layout.size = Vector2(900, 250)
	layout.theme = load("res://themes/menu/theme.tres")
	layout.add_theme_constant_override("separation", 12)
	view.add_child(layout)
	for progress: float in [0.25, 0.5, 0.75]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		layout.add_child(row)
		var index := 0
		for variant: String in ["LeftMenuButton", "PlainMenuButton", "DangerRightMenuButton"]:
			var button = load("res://components/menu_button/hold_menu_button.tscn").instantiate()
			button.theme_type_variation = variant
			button.custom_minimum_size = Vector2(290, 64)
			button.text = ["RESTART", "DELETE", "RESET TO DEFAULT"][index]
			button.add_theme_font_size_override("font_size", 24)
			row.add_child(button)
			button._begin_hold()
			button.set_process(false)
			button.hold_progress = progress
			button._update_ring()
			index += 1
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png("res://tests/output/ui-polish/hold-rings.png")
	quit()
