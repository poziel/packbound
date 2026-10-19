extends "res://tests/support/menu_support.gd"

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.start_run("warrior", 42)
	await process_frame
	await process_frame
	check(PackRun.GRID == Vector2i(8, 7), "Backpack has eight columns and seven usable rows")
	check(game.board.find_children("Cell*", "Panel", false, false).size() == 56, "Saved slots match the reduced logical grid")
	check(game.character_portrait.size == Vector2(104, 104), "Portrait returns to its normal header size")
	check(game.hp_bar.number_size == 32 and game.hp_bar.bar_height == 28, "Health returns to a full-size readable meter")
	check(game.hp_bar.get_global_rect().end.y + 8 <= game.mana_bar.global_position.y, "Health and secondary meters have separate rows with breathing room")
	for control: Control in [game.character_portrait, game.hp_bar, game.mana_bar, game.block_bar]:
		check(control.get_global_rect().end.y + 8 <= game.board.global_position.y, "Inventory stays clear of " + control.name)
	var grid: Rect2 = BackpackBoard.GRID_RECT
	grid.position += game.board.global_position
	check(game.character_tabs.get_parent_control().get_global_rect().encloses(grid), "The complete seven-row grid stays inside the character sheet")
	game.run.items.clear()
	var item: Dictionary = game.run.add_item("antidote")
	game.board.begin_drag(item, Vector2.ZERO)
	game.board.drop_at(BackpackBoard.ORIGIN + Vector2(7, 6) * BackpackBoard.STEP + game.board.grab)
	check(item["cell"] == Vector2i(7, 6), "Drag and drop reaches the new bottom-right cell")
	check(not game.run.can_place(item, Vector2i(7, 7)), "The removed eighth row rejects placement")
	var tall: Dictionary = game.run.add_item("vampire_fang")
	check(not game.run.can_place(tall, Vector2i(0, 6)), "Multi-cell items cannot spill into the removed row")
	game._refresh()
	var camera: Camera3D = game.gameplay_background.world.camera
	var world: SubViewportContainer = game.gameplay_background.get_node("Render")
	var viewport: SubViewport = world.get_node("Viewport")
	var projected: Vector2 = camera.unproject_position(Vector3(-6.4, 0, -6.0))
	var floor_point: Vector2 = world.global_position + projected * world.size / Vector2(viewport.size)
	var sprite: Image = game.enemy_art.texture.get_image()
	var used: Rect2i = sprite.get_used_rect()
	var feet: Vector2 = game.enemy_art.global_position + Vector2(sprite.get_width() * 0.5, used.end.y)
	print("GROUND REGISTRATION: sprite bottom %s, floor in front of stairs %s" % [feet, floor_point])
	check(absf(feet.x - floor_point.x) < 12 and absf(feet.y - floor_point.y) < 12, "Monster stands on the projected crypt floor in front of the stairs")
	check(game.enemy_art.get_global_rect().end.y + 40 < game.action.global_position.y, "Grounded monster stays clear of combat controls")
	for index in [0, 1, 5]:
		game.run.fight = index
		game.run.prepare_enemy()
		game._refresh()
		var monster: Image = game.enemy_art.texture.get_image()
		var base: Vector2 = game.enemy_art.global_position + Vector2(monster.get_width() * 0.5, monster.get_used_rect().end.y)
		check(base.distance_to(floor_point) < 12, "Different monster silhouettes share the ground baseline")
		await snapshot("seven-row-layout/monster-%d" % index)
	await preload("res://tests/support/automatic_combat_cleanup.gd").release(self, game)
	report("SEVEN ROW LAYOUT RESULT")
	quit(1 if failures else 0)
