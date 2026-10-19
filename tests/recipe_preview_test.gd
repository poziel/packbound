extends SceneTree

var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1160, 760)
	var run := PackRun.new()
	run.reset(42)
	var item: Dictionary = run.add_item("rusty_knife", Vector2i.ZERO)
	var data: Dictionary = PackRun.CRAFTING.recipe_inspection(run, item)
	check(data.has("recipes"), "Recipe previews expose full ingredient sprites and their output")
	check(not data.has("lock_delay"), "Recipes inherit the shared tooltip lock setting")
	check(data.get("body", "").is_empty(), "Recipe footer instructions are omitted")
	if data.has("recipes"):
		check(data["recipes"][0]["ingredients"].size() == 2, "Repeated ingredients display as separate items")
		var inspector := PackInspector.new()
		inspector.lock_delay = 0.6
		root.add_child(inspector)
		inspector.set_process(false)
		inspector.source = inspector
		inspector.source_rect = Rect2(0, 0, 100, 100)
		inspector.pointer = Vector2(20, 20)
		inspector._spawn(data, Rect2(110, 0, 0, 0), -1)
		check(is_equal_approx(inspector.root_lock_delay, 0.6), "Alt recipes use the configured ordinary tooltip delay")
		var window: PackInspectWindow = inspector.windows[0]
		check(window.get("recipe_view") != null, "Inspection window instances the sprite recipe component")
		window.set_locked(true)
		for i in 4:
			await process_frame
		var first_art: Control = window.recipe_view.items[0]
		var second_art: Control = window.recipe_view.items[1]
		var result_art: Control = window.recipe_view.items[2]
		check(first_art.global_position.x == second_art.global_position.x and second_art.global_position.y > first_art.global_position.y, "Short ingredients stack into a compact column")
		check(result_art.global_position.x > first_art.global_position.x, "Recipe result follows ingredients to the right")
		var art: Control = window.recipe_view.items[0]
		check(art.custom_minimum_size == Vector2(64, 64), "Single-cell recipe art keeps the backpack display size")
		art.mouse_entered.emit()
		check(art.material is ShaderMaterial, "Hovered recipe art receives a silhouette outline")
		inspector._process(0.2)
		check(inspector.windows.size() == 2 and inspector.windows[1].key == "recipe_item_rusty_knife", "Hovering recipe art opens item details")
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		art._gui_input(click)
		check(inspector.windows[1].locked, "Clicking an already-open hover detail pins it")
		if inspector.has_method("_open_item_recipe"):
			click.alt_pressed = true
			art._gui_input(click)
			check(inspector.windows.size() == 2 and inspector.windows[1].key == "crafts_rusty_knife", "Alt-click drills into an ingredient's recipes")
		else:
			check(false, "Alt-click can navigate item recipes")
		inspector.clear()
		var ingredients: Array[Dictionary] = []
		for i in 6:
			ingredients.append(PackCatalog.item("battle_axe"))
		var large: Dictionary = {"ingredients": ingredients, "output": PackCatalog.item("healing_herbs")}
		inspector._spawn({"key": "layout_recipes", "title": "Large recipes", "recipes": [large, large, large]}, Rect2(110, 700, 0, 0), -1)
		window = inspector.windows[0]
		for i in 8:
			await process_frame
		check(window.recipe_view.items.size() == 21, "Every ingredient and result is retained across large recipes")
		for sprite in window.recipe_view.items:
			check(sprite.size == sprite.custom_minimum_size, "Recipe wrapping preserves full item dimensions")
		check(window.recipe_scroll.get_h_scroll_bar().visible, "Wide recipes scroll horizontally without shrinking or moving their result below")
		check(window.get_global_rect().end.y <= 748, "Recipe lists stay inside the viewport")
		inspector.clear()
		inspector.queue_free()
		await process_frame
	print("RECIPE PREVIEW: %d failures" % failures)
	quit(1 if failures else 0)
