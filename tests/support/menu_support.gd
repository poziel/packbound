extends "res://tests/support/test_case.gd"

var game: Control

func check_background(menu: PackMenuFlow) -> void:
	var background: Control = game.gameplay_background
	check(background.scene_file_path == "res://scenes/world/gameplay_background/gameplay_background.tscn", "Menus use the shared 3D dungeon scene")
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
	DirAccess.make_dir_recursive_absolute(preload("res://tests/support/artifact_paths.gd").path())
	var picture: Image = root.get_texture().get_image()
	check(not picture.is_empty(), "Menu framebuffer renders")
	picture.save_png(preload("res://tests/support/artifact_paths.gd").path("%s.png") % filename)
