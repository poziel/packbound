extends SceneTree

var game: Control
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

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
		check(button.get_theme_stylebox("normal").get_script() == load("res://components/menu_button/menu_button_style.gd"), "Decorated menu frame inherited")
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
	print("MENU RESULT: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	quit(1 if failures else 0)

func check_background(menu: PackMenuFlow) -> void:
	var background: Control = game.gameplay_background
	check(background.scene_file_path == "res://scenes/gameplay/gameplay_background.tscn", "Menus use the shared 3D dungeon scene")
	check(background.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Background does not intercept menu input")
	check(background.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Background keeps crisp pixels")
	var packing_table: Control = menu.home.get_node("Background")
	check(packing_table.visible and packing_table.is_processing(), "Home restores its special animated packing table")
	var home_time: float = packing_table.elapsed
	await create_timer(0.15).timeout
	check(packing_table.elapsed > home_time, "Restored home background animation advances")
	check(background.world.camera is Camera3D, "Dungeon uses a real 3D camera")
	var previous_time: float = background.world.active_room.time
	menu.show_classes()
	await create_timer(0.15).timeout
	check(not packing_table.is_processing(), "Hidden home background pauses its effects")
	check(background.is_visible_in_tree() and background.world.active_room.time > previous_time, "Class selection keeps the shared room animated")
	var selection_background: ColorRect = menu.selection.get_node("Background")
	check(selection_background.visible and selection_background.get_global_rect() == menu.selection.get_global_rect().grow(-5), "Class selection fits inside the shared solid frame")
	menu.show_options(false)
	await process_frame
	var options_background: ColorRect = menu.options.get_node("Background")
	check(options_background.is_visible_in_tree() and options_background.get_global_rect() == menu.options.get_global_rect().grow(-5), "Options fits inside the same five-pixel solid frame")
	menu.show_home()
	await create_timer(0.15).timeout
	check(packing_table.is_visible_in_tree() and packing_table.is_processing(), "Returning home resumes the special background")

func motion(at: Vector2) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	root.push_input(event, true)

func click(button: Control) -> void:
	var point: Vector2 = button.get_global_rect().get_center()
	motion(point)
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)

func key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		root.push_input(event, true)

func snapshot(filename: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://tests/output")
	var picture: Image = root.get_texture().get_image()
	check(not picture.is_empty(), "Menu framebuffer renders")
	picture.save_png("res://tests/output/%s.png" % filename)
