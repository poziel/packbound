extends SceneTree

var checks := 0
var failures := 0
var view: SubViewport

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func settle() -> void:
	for i in range(8):
		await process_frame

func capture(name: String) -> Image:
	if DisplayServer.get_name() == "headless":
		return null
	await RenderingServer.frame_post_draw
	var image := view.get_texture().get_image()
	image.save_png("res://tests/output/menu-button-refinement/" + name + ".png")
	return image

func _run() -> void:
	view = SubViewport.new()
	view.size = Vector2i(1280, 720)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var home: Control = load("res://scenes/menus/main_menu.tscn").instantiate()
	view.add_child(home)
	await settle()
	var start: Button = home.get_node("PlayButton")
	var library: Button = home.get_node("LibraryRow/LibraryButton")
	var icon: Button = home.get_node("LibraryRow/CollectionButton")
	var quit_button: Button = home.get_node("QuitButton")
	check(start.text == "START THE DESCENT", "Start label")
	check(start.size == Vector2(400, 56), "Compact main button dimensions")
	check(home.get_node("LibraryRow").position.y - start.get_rect().end.y == 18, "Start has a small deliberate separation")
	check(quit_button.position.y - home.get_node("LibraryRow").get_rect().end.y == 6, "Other main-menu rows are close")
	check(icon.icon != null and icon.size.x < library.size.x, "Library has a compact adjacent icon button")
	check(icon.get_theme_stylebox("normal").ends == 1 and library.get_theme_stylebox("normal").ends == 2, "Library row uses mirrored half-buttons")
	check(icon.get_signal_connection_list("pressed").is_empty() and library.get_signal_connection_list("pressed").is_empty(), "Both new main-menu controls are placeholders")
	check(start.get_theme_stylebox("normal").palette.face != quit_button.get_theme_stylebox("normal").palette.face, "Start has its own accent color")
	check(quit_button.get_theme_stylebox("normal").palette.face.v < 0.5, "Default face is darker")
	check(quit_button.get_theme_stylebox("normal").palette.border_matches_face, "Border follows the face by default")
	for node: Button in home.find_children("*", "Button", true, false):
		check(node.text == node.text.to_upper(), "Uppercase main-menu label: " + node.name)
	await capture("main-menu")
	home.queue_free()
	await settle()
	var pause: Control = load("res://scenes/menus/pause_screen.tscn").instantiate()
	view.add_child(pause)
	await settle()
	var restart: Button = pause.get_node("%RestartButton")
	var resume: Button = pause.get_node("%PauseButton1")
	check(restart.text == "RESTART" and restart.hold_seconds == 1.2, "Short Restart label retains hold behavior")
	check(restart.get_theme_stylebox("normal").ends == 1 and resume.get_theme_stylebox("normal").ends == 2, "Restart and Resume have plain adjacent ends")
	check(resume.get_theme_stylebox("normal").palette.face.g > resume.get_theme_stylebox("normal").palette.face.r, "Resume remains light green")
	for node: Button in pause.find_children("*", "Button", true, false):
		check(node.text == node.text.to_upper(), "Uppercase pause label: " + node.name)
	var before := await capture("pause-menu")
	resume.grab_focus()
	await settle()
	var after := await capture("pause-focused")
	if before != null:
		var inside := Rect2i(resume.get_global_rect().grow(-30))
		# Use a 16px inset vertically to test the former dotted-line area too.
		inside.position.y = int(resume.global_position.y) + 8
		inside.size.y = int(resume.size.y) - 16
		check(before.get_region(inside).get_data() == after.get_region(inside).get_data(), "Focus adds no lines or pixels to the button face")
		check(before.get_data() != after.get_data(), "Keyboard focus remains visibly indicated by ornaments")
	pause.queue_free()
	await settle()
	print("MENU BUTTON REFINEMENT RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
