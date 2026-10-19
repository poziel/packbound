extends "res://tests/support/menu_support.gd"

const GRAY := Color(0.333, 0.365, 0.424, 1)

func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i.ZERO
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	click(game.settings_button)
	await process_frame
	await process_frame
	var tabs: TabContainer = game.front.option_tabs
	check(not game.front.options.has_node("Layout/Content/Options"), "Options heading is removed")
	check(tabs.get_script() == game.character_tabs.get_script(), "Options uses the in-game connected native tab component")
	check(tabs.get_theme_stylebox("tab_unselected").get_script() == game.character_tabs.get_theme_stylebox("tab_unselected").get_script(), "Options uses the in-game pixel tab surfaces")
	for index in tabs.get_tab_count():
		tabs.current_tab = index
		await snapshot("options-border-tabs/section-%d" % index)
		var bar: TabBar = tabs.get_tab_bar()
		check(bar.global_position == Vector2(5, 5), "Options tabs meet the top-left application border")
		if DisplayServer.get_name() != "headless":
			var picture: Image = root.get_texture().get_image()
			for item in tabs.get_tab_count():
				var rect: Rect2 = bar.get_tab_rect(item)
				var left := Vector2i(bar.global_position + rect.position)
				var right := Vector2i(bar.global_position + rect.end) - Vector2i.ONE
				if item != index:
					check(_gray(picture, Vector2i(left.x, right.y)) == not (item > 0 and item - 1 == index), "Gray tabs join on their lower left except next to the selection")
					check(_gray(picture, right) == not (item == tabs.get_tab_count() - 1 or item + 1 == index), "Gray tabs join on their lower right except at exposed ends")
				else:
					check(_gray(picture, left), "Selected tab rounds into the top frame")
			check(_gray(picture, Vector2i(5, bar.get_global_rect().end.y)) == (index != 0), "Left border curves into the content below an inactive first tab")
			check(picture.get_pixelv(Vector2i(game.front.back_button.global_position + Vector2(80, 15))) != Color.BLACK, "Footer button remains visibly rendered")
		check(tabs.get_current_tab_control().global_position.x >= 32 and tabs.get_current_tab_control().global_position.y >= bar.get_global_rect().end.y + 24, "Settings keep comfortable padding below the edge tabs")
		check(is_equal_approx((game.front.back_button.global_position.x + game.front.reset_button.get_global_rect().end.x) / 2.0, root.size.x / 2.0), "Footer actions remain centered")
	key(KEY_LEFT)
	check(tabs.current_tab == tabs.get_tab_count() - 2, "Native keyboard section navigation still works")
	click(game.front.back_button)
	check(game.front.home.visible and game.settings_button.has_focus(), "Back still returns to the title gear")
	await preload("res://tests/support/automatic_combat_cleanup.gd").release(self, game)
	report("OPTIONS BORDER TABS RESULT")
	quit(1 if failures else 0)

func _gray(picture: Image, point: Vector2i) -> bool:
	var color: Color = picture.get_pixelv(point)
	return absf(color.r - GRAY.r) + absf(color.g - GRAY.g) + absf(color.b - GRAY.b) < 0.01
