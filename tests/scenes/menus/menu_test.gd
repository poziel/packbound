extends "res://tests/support/menu_support.gd"

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var menu: PackMenuFlow = game.front
	if OS.get_cmdline_user_args().has("--quit-check"):
		print("Testing actual Quit button with pointer input")
		click(menu.quit_button)
		await create_timer(1.0).timeout
		printerr("FAIL: Quit button did not exit")
		quit(1)
		return
	await check_background(menu)
	check(menu.home_title.texture.resource_path == "res://assets/branding/packbound-title.png", "Title uses approved logo including subtitle")
	check(menu.home_title.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Logo keeps sharp source pixels")
	check(menu.home_title.size == Vector2(696, 163), "Logo displays at its native source-grid size")
	check(ProjectSettings.get_setting("application/config/icon") == "res://assets/branding/packbound-satchel-simple.png", "Application uses simple skull satchel icon")
	check(FileAccess.file_exists(ProjectSettings.get_setting("application/config/windows_native_icon")), "Windows native icon exists")
	check(menu.home.get_child(0) == menu.home.get_node("Background"), "Preserved legacy background stays behind the logo and controls")
	for button: Button in [menu.play_button, menu.quit_button]:
		check(button.size == Vector2(400, 56), "Menu buttons have identical stable geometry")
		check(button.icon == null, "No old smooth icons on pixel buttons")
		check(button.get_theme_stylebox("normal").get_script() == load("res://components/ui/buttons/menu_button/menu_button_style.gd"), "Decorated menu frame inherited")
		var font: FontFile = button.get_theme_font("font")
		check(font.antialiasing == TextServer.FONT_ANTIALIASING_NONE and font.get_font_name().contains("Pixel Operator"), "Menu uses the fine Pixel Operator font")
	await snapshot("menu-pixel-default")
	motion(menu.play_button.get_global_rect().get_center())
	await snapshot("menu-pixel-hover")
	var hover_picture: Image
	if DisplayServer.get_name() != "headless":
		hover_picture = root.get_texture().get_image()
	motion(Vector2(30, 30))
	await process_frame
	key(KEY_TAB)
	check(menu.play_button.has_focus(), "Tab enters menu at Play")
	key(KEY_DOWN)
	check(menu.home.get_node("LibraryRow/LibraryButton").has_focus(), "Down selects Library")
	key(KEY_DOWN)
	check(menu.quit_button.has_focus(), "Down selects Quit")
	key(KEY_TAB)
	check(game.settings_button.has_focus(), "Tab reaches corner settings")
	await snapshot("menu-pixel-keyboard")
	if hover_picture != null:
		check(hover_picture.get_data() != root.get_texture().get_image().get_data(), "Hover and focus have visible feedback")
	key(KEY_ENTER)
	check(menu.options.visible, "Keyboard activates Options")
	key(KEY_ESCAPE)
	check(menu.home.visible, "Escape returns to title")
	click(menu.play_button)
	await game.loading_screen.finished
	check(menu.selection.visible, "Play retains class selection flow")
	key(KEY_ESCAPE)
	await game.loading_screen.finished
	check(menu.home.visible, "Escape returns from class selection")
	var focus: Control = root.gui_get_focus_owner()
	if focus != null:
		focus.release_focus()
	motion(Vector2(30, 30))
	for dimensions in [Vector2i(960, 600), Vector2i(1280, 800), Vector2i(1600, 900), Vector2i(800, 900)]:
		if DisplayServer.get_name() != "headless":
			root.size = dimensions
			await create_timer(0.1).timeout
		var previous: Rect2 = Rect2()
		for node: Control in [menu.home_title, menu.play_button, menu.quit_button]:
			var rect: Rect2 = node.get_global_rect()
			check(Rect2(0, 0, 1280, 800).encloses(rect), "Menu stays inside canvas at %s" % dimensions)
			check(not previous.intersects(rect), "Menu elements do not overlap at %s: %s then %s" % [dimensions, previous, rect])
			previous = rect
		check(is_equal_approx(menu.home_title.size.x / menu.home_title.size.y, menu.home_title.texture.get_size().x / menu.home_title.texture.get_size().y), "Entire logo fits without distortion or cropping")
		await snapshot("menu-pixel-%dx%d" % [dimensions.x, dimensions.y])
	report("MENU RESULT")
	game.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	quit(1 if failures else 0)

