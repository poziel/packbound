extends "res://tests/support/test_case.gd"

var viewport: SubViewport
var game: Control

func _initialize() -> void:
	if not require_isolation():
		return
	_run.call_deferred()

func draw_frame() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Monster presentation checks require a rendered viewport")
		quit(2)
		return
	create_timer(25).timeout.connect(func() -> void: printerr("Presentation test timed out"); quit(2))
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	game = load("res://scenes/main.tscn").instantiate()
	viewport.add_child(game)
	await draw_frame()
	game.start_run("warrior", 42)
	var dungeon: Control = game.gameplay_background
	var card: PackEnemyCard = game.enemy_card
	var world: SubViewportContainer = dungeon.get_node("Render")
	check(world.stretch_shrink == 3 and not dungeon.has_node("EnemyRender"), "Room and monsters share one pixel viewport")
	check(world.material is ShaderMaterial and dungeon.find_children("*", "Camera3D", true, false).size() == 1, "One post-process styles the shared camera image")
	check(card.presentation_library.monsters.size() == PackArt.ENEMY_KEYS.size(), "Every monster has an editable presentation profile")
	DirAccess.make_dir_recursive_absolute(preload("res://tests/support/artifact_paths.gd").path("monster-presentation"))
	var rat_y := 0.0
	var rat_width := 0.0
	for index in range(20):
		game.run.fight = index
		game.run.prepare_enemy()
		game._refresh()
		card.set_feedback_paused(true)
		await draw_frame()
		var key: String = game.run.enemy["key"]
		var body: Rect2 = dungeon.enemy_screen_bounds()
		var bars: Rect2 = game.enemy_vitals.get_global_rect()
		check(game.enemy_vitals.is_visible_in_tree(), key + " shows encounter bars")
		check(bars.end.y <= body.position.y - 10 and bars.end.y >= body.position.y - 14, key + " keeps whole stack just above silhouette")
		check(absf(bars.get_center().x - body.get_center().x) <= 1, key + " centers bars over body")
		check(game.enemy_vitals.get_child(0) == game.enemy_bar, key + " keeps health first")
		check(game.enemy_shield_bar.visible == (game.run.shield() > 0), key + " only shows existing protection")
		var profile: Resource = card.presentation_library.profile_for(key)
		check(profile != null and card.presentation == profile, key + " selects own profile")
		check(card.shadow.mesh.size.is_equal_approx(profile.shadow_size * dungeon.enemy.pixel_size), key + " uses authored footprint")
		var expected: Vector3 = card.world_rest + Vector3(profile.shadow_offset.x * dungeon.enemy.pixel_size, 0, profile.shadow_offset.y * dungeon.enemy.pixel_size)
		expected.y = 0.055
		check(card.shadow.position.is_equal_approx(expected), key + " uses authored floor offset")
		check(is_equal_approx(card.shadow.material_override.albedo_color.a, profile.shadow_opacity), key + " uses authored opacity")
		check(dungeon.enemy.get_viewport() == dungeon.world.camera.get_viewport(), key + " renders on the same resolution grid")
		if index == 0:
			rat_y = bars.position.y
			rat_width = bars.size.x
		if index == 8:
			check(bars.position.y < rat_y - 100 and bars.size.x > rat_width, "Tall knight has higher and wider bars than rat")
		if key in ["ash_rat", "rust_knight", "zippered_maw", "mirror_wisp", "oathbreaker"]:
			viewport.get_texture().get_image().save_png(preload("res://tests/support/artifact_paths.gd").path("monster-presentation/%s.png") % key)
	# Exercise custom values rather than merely checking the shipped defaults.
	card.presentation = card.presentation.duplicate()
	card.presentation.shadow_offset = Vector2(12, 18)
	card.presentation.shadow_size = Vector2(84, 26)
	card.presentation.shadow_opacity = 0.2
	card.presentation.shadow_enabled = false
	card._apply_pose()
	card._sync_world_visibility()
	check(not card.shadow.visible and dungeon.enemy.visible, "Shadow can be disabled independently")
	check(is_equal_approx(card.shadow.position.z, card.world_rest.z + 18 * dungeon.enemy.pixel_size), "Depth offset moves shadow toward camera")
	check(card.shadow.mesh.size.is_equal_approx(Vector2(84, 26) * dungeon.enemy.pixel_size), "Custom footprint takes effect")
	# Resize the real viewport and use the same projected silhouette contract.
	viewport.size = Vector2i(1600, 900)
	game._refresh()
	await draw_frame()
	check(absf(game.enemy_vitals.get_global_rect().end.y - dungeon.enemy_screen_bounds().position.y + 12) <= 1, "Bars follow projection after viewport resize")
	game.run.phase = PackRun.Phase.LOOT
	game.run.fight = 0
	game.front.settings["combat_speed"] = 4
	game._advance_encounter()
	check(not game.enemy_vitals.is_visible_in_tree(), "Bars hide immediately on departure")
	var saw_walking_monster := false
	var saw_walking_bars := false
	while dungeon.transitioning:
		await draw_frame()
		if dungeon.transitioning:
			saw_walking_monster = saw_walking_monster or dungeon.enemy.visible
			saw_walking_bars = saw_walking_bars or game.enemy_vitals.is_visible_in_tree()
	await draw_frame()
	check(saw_walking_monster and not saw_walking_bars, "Visible approach never shows combat bars")
	check(game.enemy_vitals.is_visible_in_tree(), "Bars return when walking completes")
	game.show_menu()
	await draw_frame()
	check(not game.enemy_vitals.is_visible_in_tree() and not card.shadow.visible, "Menu hides bars and shadow")
	report("MONSTER PRESENTATION RESULT")
	await preload("res://tests/support/automatic_combat_cleanup.gd").release(self, game, viewport)
	quit(1 if failures else 0)
