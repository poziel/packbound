extends "res://tests/support/test_case.gd"

var game: Control

func _initialize() -> void:
	if not require_isolation():
		return
	_run.call_deferred()

func _run() -> void:
	create_timer(20).timeout.connect(func() -> void: printerr("Monster world test timed out"); quit(2))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.notify_mouse_entered()
	game = load("res://scenes/main.tscn").instantiate()
	viewport.add_child(game)
	await process_frame
	var dungeon: Control = game.gameplay_background
	var enemy: Sprite3D = dungeon.enemy
	check(not enemy.visible, "Title has no combat enemy")
	game.start_run("warrior", 42)
	await process_frame
	check(game.enemy_vitals.is_visible_in_tree(), "Vitals appear face-to-face")
	check(game.enemy_vitals.get_parent() == game.combat.get_node("BattleArea"), "Vitals use an independent projected HUD")
	check(game.enemy_vitals.get_child(0) == game.enemy_bar, "Health is topmost")
	check(not game.enemy_shield_bar.visible, "Unshielded enemies have no extra bar")
	check(enemy.visible and not game.enemy_art.visible, "Only the 3D actor draws during combat")
	check(enemy.get_parent() == dungeon.world.actors, "Shared actor is separate from room scenery")
	check(enemy.get_world_3d() == dungeon.world.camera.get_world_3d(), "Actor and camera share the same world")
	check(enemy.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST, "Enemy uses nearest-neighbor sampling")
	check(dungeon.world.camera.get_cull_mask_value(2) and not dungeon.has_node("EnemyRender"), "One camera renders scenery and actors")
	var rat_height := 0.0
	for index in range(20):
		game.run.fight = index
		game.run.prepare_enemy()
		game._refresh()
		await process_frame
		var rect: Rect2 = dungeon.enemy_screen_bounds()
		check(game.enemy_shield_bar.visible == (game.run.shield() > 0), "Shield row follows protection")
		check(enemy.texture.atlas == PackArt.ENEMY_TEXTURES[game.run.enemy["key"]], "Correct world texture: " + game.run.enemy["key"])
		check(rect.position.x > 190 and rect.end.x < 510 and rect.position.y > 210 and rect.end.y < 495, "Enemy stays inside foreground combat bay: " + game.run.enemy["key"])
		check(dungeon.enemy_hover.get_rect().is_equal_approx(rect), "Hover bounds follow visible pixels: " + game.run.enemy["key"])
		if index == 0:
			rat_height = rect.size.y
			check(rect.end.y > 475 and rect.end.y < 490, "Ground contact matches the requested forward position")
			check(rect.size.y > 36, "Rat is larger than its previous 32 px display height")
		if index == 8:
			check(rect.size.y > rat_height * 4 and rect.size.y > 190, "Humanoid is enlarged while species sizes stay distinct")
	game.front.settings["tooltips"] = true
	var motion := InputEventMouseMotion.new()
	motion.position = dungeon.enemy_screen_bounds().get_center()
	motion.global_position = motion.position
	viewport.push_input(motion, true)
	await create_timer(0.3).timeout
	check(not game.inspector.windows.is_empty() and game.inspector.source == dungeon.enemy_hover, "Hovering the world monster opens its details")
	game.inspector.clear()
	game.enemy_card.play_hit(true)
	await create_timer(0.035).timeout
	check(enemy.scale.x > 1.0, "Hit animates the world sprite")
	game.enemy_card.set_feedback_paused(true)
	var frozen: Vector3 = enemy.scale
	await create_timer(0.1).timeout
	check(enemy.scale == frozen, "Pause freezes world feedback")
	game.enemy_card.set_feedback_paused(false)
	await game.enemy_card.hit_tween.finished
	check(enemy.scale.is_equal_approx(Vector3.ONE), "Resume settles feedback")
	game.enemy_card.play_strike()
	await create_timer(0.03).timeout
	check(enemy.position != game.enemy_card.world_rest, "Enemy strike moves in world space")
	game.enemy_card.reset_feedback()
	check(enemy.position == game.enemy_card.world_rest and enemy.modulate == Color.WHITE, "Reset restores world feedback")
	var at_rest: Rect2 = dungeon.enemy_screen_bounds()
	dungeon._reveal_room(0.3)
	var arriving: Rect2 = dungeon.enemy_screen_bounds()
	check(arriving.size.y < at_rest.size.y and arriving.end.y < at_rest.end.y, "Approaching camera moves and enlarges the grounded enemy with the room")
	check(dungeon.find_children("*", "Camera3D", true, false).size() == 1, "Exactly one gameplay camera exists")
	dungeon.reset()
	game.run.fight = 0
	game.run.prepare_enemy()
	game.run.phase = PackRun.Phase.LOOT
	game.front.settings["combat_speed"] = 4
	game._advance_encounter()
	check(game.busy and dungeon.transitioning and not enemy.visible, "Descent hides the old world enemy and locks actions")
	check(not game.enemy_vitals.is_visible_in_tree(), "Vitals hide on departure")
	var vitals_during_walk := false
	var saw_arrival := false
	var saw_visible_step := false
	while dungeon.transitioning:
		vitals_during_walk = vitals_during_walk or game.enemy_vitals.is_visible_in_tree()
		if enemy.visible:
			saw_arrival = true
			saw_visible_step = saw_visible_step or (dungeon.fade.modulate.a < 0.1 and dungeon.world.camera.position.z > dungeon.world.camera_home.z + 0.1)
		await process_frame
	check(not vitals_during_walk and game.enemy_vitals.is_visible_in_tree(), "Vitals hidden throughout walk and return on arrival")
	check(saw_arrival and saw_visible_step, "New enemy and room share a visible arrival step, even at 4x combat speed")
	check(game.run.fight == 1 and not game.busy and enemy.visible, "Next floor completes with the new enemy ready")
	game.run.phase = PackRun.Phase.LOOT
	game._advance_encounter()
	await create_timer(0.05).timeout
	game.start_run("mage", 42)
	await create_timer(0.8).timeout
	check(not dungeon.transitioning and game.run.fight == 0 and enemy.texture.atlas == PackArt.ENEMY_TEXTURES["ash_rat"], "Restart cancels the old floor transition")
	game.show_menu()
	check(not enemy.visible and not dungeon.transitioning, "Leaving combat hides the world actor and cancels camera motion")
	report("MONSTER WORLD RESULT")
	await preload("res://tests/support/automatic_combat_cleanup.gd").release(self, game, viewport)
	quit(1 if failures else 0)
