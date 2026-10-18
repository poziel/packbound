extends SceneTree

var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _gray(picture: Image, at: Vector2i) -> bool:
	var pixel: Color = picture.get_pixelv(at)
	var gray := Color(0.333, 0.365, 0.424, 1)
	return absf(pixel.r - gray.r) + absf(pixel.g - gray.g) + absf(pixel.b - gray.b) < 0.01

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("This pixel regression requires a graphics display")
		quit(2)
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(128, 128)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.color = Color.BLACK
	background.size = Vector2(128, 128)
	viewport.add_child(background)
	var frame: Control = load("res://scenes/shared/application_frame.tscn").instantiate()
	viewport.add_child(frame)
	frame.get_node("SettingsDock").show()
	frame.get_node("SettingsDock/SettingsButton").hide()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var picture: Image = viewport.get_texture().get_image()
	check(_gray(picture, Vector2i(63, 6)), "Top border rounds into the dock's left edge")
	check(picture.get_pixel(63, 18) == Color.BLACK, "Top join returns to the straight edge after the curve")
	check(picture.get_pixel(65, 63) == Color.BLACK, "Dock's bottom-left corner is rounded away from the page")
	check(_gray(picture, Vector2i(77, 63)), "Dock retains its gray surface beyond the rounded corner")
	check(_gray(picture, Vector2i(122, 65)), "Dock's bottom edge rounds into the right border")
	check(picture.get_pixel(110, 65) == Color.BLACK, "Right join preserves the open page area")
	picture.save_png("res://tests/output/rounded-settings-dock/corner-detail.png")
	frame.get_node("SettingsDock").hide()
	await process_frame
	await RenderingServer.frame_post_draw
	picture = viewport.get_texture().get_image()
	check(picture.get_pixel(63, 6) == Color.BLACK and picture.get_pixel(65, 63) == Color.BLACK, "Hiding settings restores the ordinary page opening")
	check(_gray(picture, Vector2i(122, 6)), "Ordinary page corner rounding remains intact")
	var sibling: Control = load("res://scenes/shared/application_frame.tscn").instantiate()
	sibling.hide()
	viewport.add_child(sibling)
	frame.get_node("SettingsDock").show()
	check(frame.get_node("Border").get_theme_stylebox("panel") != sibling.get_node("Border").get_theme_stylebox("panel"), "Each frame owns its dock visibility state")
	check(sibling.get_node("Border").get_theme_stylebox("panel").get("dock_size") == Vector2i.ZERO, "A hidden frame keeps its ordinary outline")
	viewport.queue_free()
	await process_frame
	print("ROUNDED SETTINGS DOCK RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
