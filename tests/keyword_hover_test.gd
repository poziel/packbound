extends SceneTree

var failures: int = 0
var checks: int = 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)

func settle() -> void:
	for frame in 4:
		await process_frame

func motion(viewport: SubViewport, at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	viewport.push_input(event, true)

func snapshot(viewport: SubViewport, name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var folder: String = "res://workspace/docs/art/reviews/keyword-stats/hover"
	DirAccess.make_dir_recursive_absolute(folder)
	viewport.get_texture().get_image().save_png(folder + "/" + name + ".png")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 400)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.notify_mouse_entered()
	var window: PackInspectWindow = load("res://scenes/shared/inspect_window.tscn").instantiate()
	viewport.add_child(window)
	window.setup({"key": "hover_review", "title": "Keyword hover", "body": "Health restores health.", "keyword_stats": PackKeywords.item_stats(PackCatalog.item("vampire_fang"))})
	window.size.x = 580
	window.position = Vector2(20, 20)
	window.set_locked(true)
	await settle()
	var idle_text: String = window.body.text
	var rect: Rect2 = window.body.get_global_rect()
	var original_size: Vector2 = window.size
	await snapshot(viewport, "idle")
	motion(viewport, rect.position + Vector2(10, 12))
	await settle()
	check(window._hovered_keyword == "damage", "Real pointer hover reaches the keyword stat")
	check(window.body.text != idle_text, "Hovered stat gets darker")
	var hovered_text: String = window.body.text
	await settle()
	check(window.body.text == hovered_text and window._hovered_keyword == "damage", "Stationary hover remains stable without flickering")
	motion(viewport, rect.position + Vector2(11, 12))
	await settle()
	check(window._hovered_keyword == "damage" and window.body.text == hovered_text, "Motion within a recolored stat keeps hover active")
	check(window.size == original_size, "Hover does not reflow the tooltip")
	await snapshot(viewport, "stat-hover")
	motion(viewport, Vector2(630, 390))
	await settle()
	check(window._hovered_keyword == "" and window.body.text == idle_text, "Real pointer exit restores normal colors")
	var found: bool = false
	for y in range(45, int(rect.size.y), 6):
		for x in range(8, int(rect.size.x), 6):
			motion(viewport, rect.position + Vector2(x, y))
			if window._hovered_keyword == "health":
				found = true
				break
		if found:
			break
	await settle()
	check(found and window._hovered_keyword == "health", "Real pointer hover reaches the keyword link")
	check(window.body.text != idle_text, "Hovered keyword link gets darker")
	await snapshot(viewport, "link-hover")
	viewport.queue_free()
	await process_frame
	print("KEYWORD HOVER RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
