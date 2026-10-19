extends "res://tests/support/test_case.gd"
## Rendered pixel checks: an opaque badge cannot pass these by matching one panel.

const BAR: PackedScene = preload("res://components/ui/indicators/pixel_stat_bar/pixel_stat_bar.tscn")
var OUTPUT: String = preload("res://tests/support/artifact_paths.gd").path("stat-bar-cutout")
var viewport: SubViewport
var bar: PixelStatBar
var background: ColorRect


func _initialize() -> void:
	if not require_isolation():
		return
	call_deferred("_run")




func capture() -> Image:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("This alpha/compositing test requires a real rendering display.")
		quit(2)
		return
	create_timer(30.0).timeout.connect(func() -> void: quit(2))
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	viewport = SubViewport.new()
	viewport.size = Vector2i(360, 140)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	background = ColorRect.new()
	background.size = Vector2(viewport.size)
	background.visible = false
	viewport.add_child(background)
	bar = BAR.instantiate()
	bar.position = Vector2(20, 20)
	viewport.add_child(bar)
	bar.size = Vector2(280, 56)
	bar.badge_color = Color.MAGENTA
	bar.set_amount(8, 8)
	await process_frame
	bar.value_label.visible = false # Expose the actual meter alpha under the number.
	var image: Image = await capture()
	var badge: Rect2 = bar.value_label.get_rect()
	badge.size.y -= bar.pixel_size
	var meter_top: int = int(bar.position.y + bar.size.y - bar._meter_height())
	var inside: Vector2i = Vector2i(bar.position + Vector2(badge.get_center().x, badge.end.y - 1))
	check(inside.y > meter_top + bar.pixel_size * 3, "Test sample overlaps the filled well, not merely empty space above the frame")
	for amount: int in [8, 4, 0]:
		bar.set_amount(amount, 8)
		bar.value_label.visible = false
		image = await capture()
		var clear_pixels: bool = true
		for y: int in range(meter_top, inside.y + 1):
			for x: int in range(inside.x - 10, inside.x + 11):
				clear_pixels = clear_pixels and image.get_pixel(x, y).a < 0.01
		check(clear_pixels, "Entire notch stays transparent at %d / 8" % amount)
		check(image.get_pixel(int(bar.position.x + 8), meter_top + 8).a > 0.99, "Meter remains opaque beside the notch at %d / 8" % amount)
	image.save_png(OUTPUT + "/transparent-notch.png")
	background.visible = true
	for color: Color in [Color.YELLOW, Color.PURPLE]:
		background.color = color
		image = await capture()
		check(image.get_pixelv(inside).is_equal_approx(color), "Notch reveals changed background " + color.to_html())
	image.save_png(OUTPUT + "/purple-background.png")
	background.visible = false
	bar.number_mode = PixelStatBar.NumberMode.HIDDEN
	image = await capture()
	check(image.get_pixelv(inside).a > 0.99, "Hidden number mode restores uninterrupted meter geometry")
	bar.number_mode = PixelStatBar.NumberMode.FRACTION
	bar.set_amount(8, 8)
	bar.badge_icon = PackKeywords.icon("health", true)
	await process_frame
	var reserved: Rect2 = bar.value_label.get_rect()
	bar.set_amount(1, 8)
	check(bar.value_label.get_rect() == reserved, "Keyword badge icon and digit reservation stay stable after depletion")
	bar.value_label.visible = true
	image = await capture()
	image.save_png(OUTPUT + "/icon-badge.png")
	var player: Control = load("res://scenes/run/character/player/player.tscn").instantiate()
	viewport.size = Vector2i(600, 140)
	viewport.add_child(player)
	player.position = Vector2(0, 0)
	bar.visible = false
	for key: String in ["Mana", "Block"]:
		var caption: RichTextLabel = player.get_node(key + "Caption")
		var meter: PixelStatBar = player.get_node(key + "Bar")
		caption.text = PackKeywords.image_markup(key.to_lower()) + key.to_upper()
		meter.set_amount(24, 24)
	image = await capture()
	image.save_png(OUTPUT + "/resource-captions.png")
	for key: String in ["Mana", "Block"]:
		var caption: RichTextLabel = player.get_node(key + "Caption")
		var meter: PixelStatBar = player.get_node(key + "Bar")
		check(caption.autowrap_mode == TextServer.AUTOWRAP_OFF and caption.get_line_count() == 1, key + " keyword caption remains on one line")
		check(caption.get_content_width() <= caption.size.x, key + " caption fits its reserved width")
		check(not caption.get_global_rect().intersects(meter.value_label.get_global_rect()), key + " caption clears fraction badge")
	viewport.queue_free()
	await process_frame
	report("STAT BAR CUTOUT TEST")
	quit(0 if failures == 0 else 1)
