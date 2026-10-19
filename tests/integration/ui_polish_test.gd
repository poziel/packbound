extends "res://tests/support/test_case.gd"

var game
var view: SubViewport
var clicks := 0

func _initialize() -> void:
	if not require_isolation():
		return
	_run.call_deferred()

func settle() -> void:
	await process_frame
	await process_frame

func key(code: Key, repeat: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	event.echo = repeat
	view.push_input(event)
	await settle()
	event = event.duplicate()
	event.pressed = false
	event.echo = false
	view.push_input(event)
	await settle()

func capture(label: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		view.get_texture().get_image().save_png(preload("res://tests/support/artifact_paths.gd").path("ui-polish/") + label + ".png")

func hover(point: Vector2) -> void:
	view.notify_mouse_entered()
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	view.push_input(event)
	await create_timer(0.8).timeout

func _run() -> void:
	create_timer(45).timeout.connect(func(): quit(2))
	view = SubViewport.new()
	view.size = Vector2i(1280, 800)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	game = load("res://scenes/main.tscn").instantiate()
	view.add_child(game)
	await settle()
	game.front.audio.click_played.connect(func(): clicks += 1)
	var collection: Button = game.front.home.get_node("LibraryRow/CollectionButton")
	check(collection.size.x >= 112 and collection.icon_alignment == HORIZONTAL_ALIGNMENT_CENTER, "Menu icon has minimum width and centered alignment")
	var old_gear := Image.load_from_file("res://themes/gameplay/controls.svg").get_region(Rect2i(128, 0, 32, 32))
	var gear: Image = game.settings_button.icon.get_image()
	var same_shape := true
	var white := true
	for y in range(32):
		for x in range(32):
			same_shape = same_shape and gear.get_pixel(x, y).a == old_gear.get_pixel(x, y).a
			if gear.get_pixel(x, y).a > 0:
				white = white and gear.get_pixel(x, y) == Color.WHITE
	check(same_shape and white, "Settings retains exact silhouette with a white tint mask")
	await capture("title")
	await key(KEY_ESCAPE)
	check(game.front.options.visible and clicks == 1, "Title Escape opens Options with exactly one click sound")
	await key(KEY_ESCAPE, true)
	check(game.front.options.visible and clicks == 1, "Held Escape ignores repeat")
	var back: Button = game.front.back_button
	var reset: Button = game.front.reset_button
	check(back.get_theme_stylebox("normal").ends == 1 and reset.get_theme_stylebox("normal").ends == 2, "Options footer has left and right menu-button ends")
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		check(reset.get_theme_stylebox(state).palette.face.r > reset.get_theme_stylebox(state).palette.face.g * 1.5, "Reset uses the red palette: " + state)
	check(reset.text == "RESET TO DEFAULT", "Reset label")
	game.front.option_tabs.current_tab = 1
	await settle()
	await capture("options")
	game.front._set_option("window_mode", 0)
	await key(KEY_F11)
	check(game.front.settings["window_mode"] == 1 and game.front.window_mode.selected == 1, "F11 enters borderless fullscreen and syncs option")
	if DisplayServer.get_name() != "headless":
		check(root.mode == Window.MODE_FULLSCREEN, "Native window enters borderless fullscreen")
	await key(KEY_F11, true)
	check(game.front.settings["window_mode"] == 1, "Held F11 ignores repeat")
	await key(KEY_F11)
	check(game.front.settings["window_mode"] == 0 and not game.front.settings["fullscreen"], "F11 returns to windowed")
	if DisplayServer.get_name() != "headless":
		check(root.mode == Window.MODE_WINDOWED, "Native window returns to windowed")
	await key(KEY_ESCAPE)
	check(game.front.home.visible, "Escape returns from Options to title")
	game.start_run("warrior", 42)
	await settle()
	var before: int = clicks
	await key(KEY_ESCAPE)
	check(game.modal.visible and game.modal_kind == "pause" and clicks == before + 1, "Gameplay Escape opens pause with exactly one click sound")
	await key(KEY_ESCAPE)
	check(not game.modal.visible, "Escape closes pause")
	before = clicks
	game.settings_button.pressed.emit()
	check(clicks == before + 1, "Mouse/button activation does not double-play audio")
	game._close_modal()
	for stat: String in game.values:
		check(game._stat_inspection(stat)["body"] == PackKeywordLinks.entry(stat)["body"], "Effect tooltip has definition only: " + stat)
	var description: String = game._describe_item(game.run.items[0], Rect2())["body"]
	check(not description.contains(" / ") and not description.contains("Drag to move") and not description.contains("Inventory locked"), "Item inspection omits footprint and controls")
	var tooltip = load("res://scenes/shared/item_tooltip/item_tooltip.tscn").instantiate()
	view.add_child(tooltip)
	tooltip.set_item(game.run.items[0])
	check(not tooltip.has_node("Footprint") and not tooltip.has_node("Controls"), "Standalone item tooltip also omits footprint and controls")
	tooltip.queue_free()
	var registered := false
	for entry in game.inspector.sources:
		registered = registered or entry["target"] == game.storage_button
	check(not registered and not game.storage_button.tooltip_text.is_empty(), "Unused items uses native tooltip only")
	check(game.item_reward_button.tooltip_text == "Choose an item reward for your inventory.", "Item reward tooltip updated")
	check(game.relic_reward_button.tooltip_text == "Choose a relic reward for this descent.", "Relic reward tooltip updated")
	await settle()
	game._sync_enemy_vitals()
	var bounds: Rect2 = game.gameplay_background.enemy_screen_bounds()
	var head: Vector2 = game.gameplay_background.get_global_transform_with_canvas() * Vector2(bounds.get_center().x, bounds.position.y)
	var center: Vector2 = game.enemy_vitals.get_parent().get_global_transform_with_canvas().affine_inverse() * head
	check(absf(center.y - game.enemy_vitals.position.y - game.enemy_vitals.size.y - 24.0) <= 1, "Enemy vitals leave a 24 px gap above the head")
	await capture("gameplay")
	game.character_tabs.current_tab = game.character_tabs.get_tab_idx_from_control(game.character_tabs.get_node("Statistics"))
	await settle()
	await hover(game.values["damage"].get_parent().get_node("DamageLabel").get_global_rect().get_center())
	check(not game.inspector.windows.is_empty(), "Effect hover opens the streamlined tooltip")
	await capture("effect-tooltip")
	game.inspector.clear()
	game.character_tabs.current_tab = 0
	await settle()
	await hover(game.board.global_position + game.board.item_rect(game.run.items[0]).get_center())
	check(not game.inspector.windows.is_empty(), "Item hover opens the streamlined tooltip")
	await capture("item-tooltip")
	game.inspector.clear()
	await hover(game.storage_button.get_global_rect().get_center())
	check(game.inspector.windows.is_empty(), "Unused items hover does not open an extended tooltip")
	await capture("unused-items-tooltip")
	report("UI POLISH RESULT")
	await preload("res://tests/support/automatic_combat_cleanup.gd").release(self, game, view)
	quit(1 if failures else 0)
