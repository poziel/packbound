extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func settle() -> void:
	for i in range(10):
		await process_frame

func _run() -> void:
	root.size = Vector2i(1280, 800)
	for mode in ["gameplay", "menu"]:
		var scene: Control = load("res://themes/" + mode + "/showcase.tscn").instantiate()
		root.add_child(scene)
		scene.size = Vector2(1280, 800)
		await settle()
		var columns: HBoxContainer = scene.get_node("Frame/Padding/Columns")
		check(scene.get_rect().encloses(scene.get_node("Frame").get_rect()), mode + " frame fits viewport")
		for column: Node in columns.get_children():
			if column is VBoxContainer:
				check(scene.get_global_rect().encloses(column.get_global_rect()), mode + " column fits viewport: " + column.name)
		var search: LineEdit = columns.get_node("Browse/Search")
		search.set_query("Iron")
		await settle()
		var rows: Container = columns.get_node("Browse/List/Rows")
		var visible := 0
		for row: Control in rows.get_children():
			visible += int(row.visible)
		check(visible == 1, mode + " showcase list filters")
		search.set_query("")
		await settle()
		check(columns.get_node("Browse/List").get_v_scroll_bar().visible, mode + " vertical overflow visible")
		check(columns.get_node("Browse/Horizontal").get_h_scroll_bar().visible, mode + " horizontal overflow visible")
		var divider: VSeparator = columns.get_node("DividerBrowse")
		check(divider.get_theme_stylebox("separator").thickness == 2, mode + " vertical line uses theme thickness")
		check(divider.size.y > 400, mode + " vertical separator stretches along panel")
		var thin: HSeparator = columns.get_node("Details/Thin")
		var thick: HSeparator = columns.get_node("Details/Thick")
		check(thin.get_theme_stylebox("separator").thickness == 1 and thick.get_theme_stylebox("separator").thickness == 4, mode + " individual line thickness overrides")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://tests/output/two-ui-themes/" + mode + "-preview.png")
		scene.queue_free()
		await settle()
	print("THEME SHOWCASE RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
