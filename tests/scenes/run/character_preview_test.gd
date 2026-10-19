extends "res://tests/support/battle_ui_support.gd"

func _run() -> void:
	create_timer(30).timeout.connect(func() -> void: printerr("Character preview test timed out"); quit(2))
	render = DisplayServer.get_name() != "headless"
	test_viewport = SubViewport.new()
	test_viewport.size = Vector2i(1280, 800)
	test_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(test_viewport)
	test_viewport.notify_mouse_entered()
	game = load("res://scenes/main.tscn").instantiate()
	test_viewport.add_child(game)
	await process_frame
	var player: Control = game.character_portrait.get_parent()
	check(not player.has_node("CharacterName") and not player.has_node("ClassLabel"), "Identity labels are removed from the header")
	check(game.character_portrait.scene_file_path == "res://components/characters/character_preview/character_preview.tscn", "Gameplay instances the reusable head preview")
	for key: String in PackCatalog.classes():
		game.start_run(key, 42)
		game._open_reward(true)
		game._choose(0)
		await process_frame
		await process_frame
		var preview: Control = game.character_portrait
		var art: TextureRect = preview.get_node("Art")
		var head: AtlasTexture = preview.texture
		check(head != null and Rect2(Vector2.ZERO, head.atlas.get_size()).encloses(head.region), "Head crop stays inside its source: " + key)
		check(head.atlas.resource_path == "res://assets/characters/%s/art/portrait.png" % key, "Detailed standalone portrait: " + key)
		check(head.atlas.get_size() == Vector2(64, 64) and head.region == Rect2(0, 0, 64, 64), "Complete 64px portrait: " + key)
		var body: Texture2D = load("res://assets/characters/%s/art/full-body.svg" % key)
		check(body.get_size() == Vector2(384, 320), "Installed 256px-body source cell: " + key)
		check(Rect2(Vector2.ONE * 8, preview.size - Vector2.ONE * 16).encloses(art.get_rect()), "Head stays inside the frame: " + key)
		check(art.get_rect().get_center().distance_to(preview.size * 0.5) <= 1, "Head is centered: " + key)
		var factor: Vector2 = art.size / head.get_size()
		check(factor.x == factor.y and factor.x == floorf(factor.x), "Head uses uniform integer pixel scaling: " + key)
		check(preview.get_global_rect().end.x < game.hp_bar.global_position.x, "Head frame sits left of the bars")
		for control: Control in [preview, game.hp_bar, game.mana_bar, game.block_bar]:
			check(player.get_global_rect().encloses(control.get_global_rect()), "Compact header contains " + control.name)
			check(control.get_global_rect().end.y < game.board.global_position.y, "Backpack stays below " + control.name)
		await _snapshot("character-preview-" + key)
		_motion(preview.get_global_rect().get_center())
		await create_timer(0.3).timeout
		var data: Dictionary = PackCatalog.classes()[key]
		check(not game.inspector.windows.is_empty(), "Hovering the head opens inspection: " + key)
		if not game.inspector.windows.is_empty():
			var window: PackInspectWindow = game.inspector.windows[0]
			check(window.key == "class_" + key, "Portrait inspection belongs to the current class")
			check(window.get_node("Content/Header/Title").text == data["name"] + " / " + data["mechanic"], "Hover exposes the class name and special power")
			check(game._character_inspection()["body"].contains(data["detail"]) and window.body.text.begins_with(PackKeywordLinks.rich(data["detail"], window.key)), "Hover retains the ability description with its keyword link icons")
			if key == "warrior":
				await _snapshot("character-preview-tooltip")
		_motion(Vector2(640, 90))
		game.inspector.clear()
	game.start_run("warrior", 42)
	game._open_reward(true)
	game._choose(0)
	game.run.items.clear()
	check(PackRun.GRID == Vector2i(8, 7), "Backpack uses seven rows")
	for column in range(PackRun.GRID.x):
		var cell := Vector2i(column, 6)
		var item: Dictionary = game.run.add_item("antidote")
		game.board.begin_drag(item, Vector2.ZERO)
		game.board.drop_at(BackpackBoard.ORIGIN + Vector2(cell) * BackpackBoard.STEP + game.board.grab)
		check(item["cell"] == cell, "Can drop into seventh-row column %d" % column)
		var slot: Control = game.board.get_node("Cell%d_7" % (column + 1))
		check(game.board.get_global_rect().encloses(slot.get_global_rect()), "Seventh-row slot stays inside the board")
	check(not game.run.can_place(game.run.items[0], Vector2i(0, 7)), "An eighth row remains out of bounds")
	check(game.board.get_parent().get_global_rect().encloses(game.board.get_global_rect()), "Expanded board fits its tab")
	game._refresh()
	await _snapshot("character-preview-seventh-row")
	game.character_portrait.grab_focus()
	_key(KEY_F1)
	await process_frame
	check(not game.inspector.windows.is_empty(), "Head inspection is also keyboard accessible")
	game.inspector.clear()
	game.character_portrait.release_focus()
	game.hide()
	var demo: Control = load("res://components/characters/character_preview/demo.tscn").instantiate()
	test_viewport.add_child(demo)
	await _snapshot("character-preview-gallery")
	demo.queue_free()
	test_viewport.queue_free()
	await process_frame
	report("CHARACTER PREVIEW RESULT")
	quit(1 if failures else 0)
