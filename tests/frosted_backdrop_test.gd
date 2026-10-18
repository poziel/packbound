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

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(2)
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(128, 128)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var pattern := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y in range(128):
		for x in range(128):
			pattern.set_pixel(x, y, Color.WHITE if (x / 4 + y / 4) % 2 == 0 else Color.BLACK)
	var background := TextureRect.new()
	background.texture = ImageTexture.create_from_image(pattern)
	background.size = Vector2(128, 128)
	viewport.add_child(background)
	var backdrop: Control = load("res://components/frosted_panel/frosted_backdrop.tscn").instantiate()
	viewport.add_child(backdrop)
	backdrop.opacity = 0.0
	backdrop.blur_radius = 0.0
	backdrop.corner_radius = 0
	backdrop.border_width = 0
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var clear: Color = viewport.get_texture().get_image().get_pixel(33, 33)
	backdrop.blur_radius = 4.0
	await process_frame
	await RenderingServer.frame_post_draw
	var blurred: Color = viewport.get_texture().get_image().get_pixel(33, 33)
	check(clear.r > 0.95, "Zero blur preserves sharp background pixels")
	check(blurred.r > 0.35 and blurred.r < 0.65, "Backdrop blur smooths a real rendered high-contrast pattern")
	var foreground := ColorRect.new()
	foreground.position = Vector2(40, 40)
	foreground.size = Vector2(4, 4)
	foreground.color = Color.WHITE
	viewport.add_child(foreground)
	await process_frame
	await RenderingServer.frame_post_draw
	check(viewport.get_texture().get_image().get_pixel(40, 40) == Color.WHITE, "Foreground controls remain sharp and opaque above the blur")
	backdrop.tint = Color.GREEN
	backdrop.opacity = 1.0
	var second: Control = load("res://components/frosted_panel/frosted_backdrop.tscn").instantiate()
	viewport.add_child(second)
	second.opacity = 0.0
	second.blur_radius = 0.0
	second.corner_radius = 0
	second.border_width = 0
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var combined: Color = viewport.get_texture().get_image().get_pixel(80, 80)
	check(combined.g > 0.95 and combined.r < 0.05, "Each backdrop captures the current scene, including panels already drawn")
	check(backdrop.get_node("Surface").material != second.get_node("Surface").material, "Panel opacity and blur settings are independent per instance")
	viewport.queue_free()
	await process_frame
	print("FROSTED BACKDROP RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
