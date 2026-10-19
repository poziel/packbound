extends "res://tests/support/test_case.gd"


func _initialize() -> void:
	if not require_isolation():
		return
	_run.call_deferred()


func _run() -> void:
	create_timer(15).timeout.connect(func() -> void: printerr("Basement test timed out"); quit(2))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	root.add_child(viewport)
	var game: Control = load("res://scenes/main.tscn").instantiate()
	viewport.add_child(game)
	await process_frame
	game.front.settings["combat_speed"] = 4
	game._transition_start_run("warrior")
	while not game.gameplay_background.is_at_entrance():
		await process_frame
	while game.loading_screen.active:
		await process_frame
	await create_timer(0.4).timeout
	check(not game.busy and not game.gameplay_background.transitioning, "Basement waits for the player's entrance action")
	check(not game.action.disabled and game.action.accessibility_name == "Enter dungeon", "Primary action offers an accessible entrance control")
	check(game.action.icon.resource_path.ends_with("enter-dungeon.svg"), "Entrance has its own icon instead of Attack")
	check(game.gameplay_background.world.camera.position.is_equal_approx(game.gameplay_background.world.camera_home), "Waiting in the basement does not advance the camera")
	check(is_zero_approx(game.elapsed), "Run timer waits for the entrance action")
	check(game.gameplay_background.is_at_entrance() and not game.enemy_card.visible, "First enemy and dungeon are hidden in the basement")
	var basement: Node3D = game.gameplay_background.world.active_room
	check(basement.has_node("Floorboard") and basement.has_node("StoneJamb") and basement.get_node("ExitStairs/Visuals/RoomDesign").has_node("DownwardTread"), "Wooden basement contains an open stone stair entrance")
	game.gameplay_background._advance_passage(0.85)
	check(absf(game.gameplay_background.world.camera.rotation.x - game.gameplay_background.world.camera_rotation.x) <= deg_to_rad(10.0) + 0.001, "Basement descent adds no more than ten degrees of downward tilt")
	game.gameplay_background.prepare_entrance()
	game._act()
	check(game.busy and game.gameplay_background.transitioning and game.board.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Entrance action begins travel and locks inventory")
	game._act()
	check(game.run.total_turns == 0 and not game.playback.active, "Attack cannot start combat during the entrance")
	var enemy_hidden: bool = true
	while game.loading_screen.active or game.busy:
		if game.gameplay_background.is_at_entrance():
			enemy_hidden = enemy_hidden and not game.enemy_card.visible
		await process_frame
	check(enemy_hidden, "Enemy remains hidden throughout the basement walk")
	check(game.gameplay_background.world.active_room.visible and not game.gameplay_background.is_at_entrance(), "Entrance ends in the normal dungeon room")
	check(game.enemy_card.visible and game.run.fight == 0 and game.run.total_turns == 0, "First enemy arrives without advancing floors or spending turns")
	check(not game.gameplay_background.transitioning and game.board.mouse_filter == Control.MOUSE_FILTER_STOP, "Preparation unlocks after arrival")
	check(game.action.accessibility_name == "Attack", "Entrance action returns to Attack in the first room")
	check(game.gameplay_background.world.camera.position.is_equal_approx(game.gameplay_background.world.camera_home), "Arrival settles at the authored camera position")
	game._transition_start_run("warrior")
	while game.loading_screen.active:
		await process_frame
	game.start_run("ranger", 42)
	await create_timer(0.2).timeout
	check(not game.waiting_at_entrance and game.action.accessibility_name == "Attack" and game.run.class_key == "ranger", "Resetting a waiting basement clears the entrance action")
	game._transition_start_run("warrior")
	while game.loading_screen.active:
		await process_frame
	game.action.pressed.emit()
	await create_timer(0.1).timeout
	game.start_run("warrior", 42)
	await create_timer(0.4).timeout
	check(not game.gameplay_background.is_at_entrance() and game.gameplay_background.world.active_room.visible, "Direct fixture/reset restores the dungeon immediately")
	check(not game.busy and not game.gameplay_background.transitioning and not game.waiting_at_entrance and game.run.total_turns == 0, "Reset during basement travel cannot continue into the new run")
	await preload("res://tests/support/automatic_combat_cleanup.gd").release(self, game, viewport)
	report("BASEMENT RESULT")
	quit(1 if failures else 0)
