extends SceneTree

var checks: int = 0
var failures: int = 0
var game: Control
var viewport: SubViewport
var saw_black: bool = false
var saw_reveal: bool = false
var synchronized: bool = true
var saw_visible_arrival: bool = false
var arrival_bounds: float = 0.0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func snapshot(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://tests/output/dungeon")
	viewport.get_texture().get_image().save_png("res://tests/output/dungeon/%s.png" % label)

func wait_transition() -> void:
	var deadline: int = Time.get_ticks_msec() + 6000
	while game.busy and Time.get_ticks_msec() < deadline:
		if game.enemy_card.visible:
			var darkness: float = game.gameplay_background.fade.modulate.a
			saw_black = saw_black or darkness > 0.999
			saw_reveal = saw_reveal or (darkness > 0.1 and darkness < 0.9)
			synchronized = synchronized and is_equal_approx(game.enemy_card.modulate.a, 1.0 - darkness)
			if darkness < 0.01 and game.gameplay_background.world.camera.position.z > game.gameplay_background.world.camera_home.z + 2.0:
				saw_visible_arrival = true
				arrival_bounds = maxf(arrival_bounds, game.gameplay_background.enemy_screen_bounds().size.y)
		await process_frame
	check(not game.busy, "Transition completes without leaving controls locked")

func offer_loot(floor_index: int) -> void:
	game.run.fight = floor_index
	game.run.prepare_enemy()
	game.run.phase = PackRun.Phase.LOOT
	game.run.roll_loot()
	game._show_phase_modal()

func _run() -> void:
	create_timer(25).timeout.connect(func() -> void: printerr("Dungeon test timed out"); quit(2))
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.notify_mouse_entered()
	game = load("res://scenes/main.tscn").instantiate()
	viewport.add_child(game)
	await process_frame
	check(game.gameplay_background.size == Vector2(1280, 800), "Background covers entire application")
	check(game.gameplay_background.world.camera is Camera3D, "Dungeon renders actual Godot 3D geometry")
	check(game.front.home.get_node("Background").visible, "Home restores the animated packing-table background")
	check(game.gameplay_background.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Room retains nearest-neighbor canvas filtering")
	await snapshot("home")
	game.start_run("warrior", 42)
	game._choose(0)
	await process_frame
	check(not game.combat.get_node("BattleArea") is Panel, "Combat backdrop has no panel border")
	check(not game.combat.get_node("BattleArea").has_node("Dungeon"), "Flat enemy backdrop is removed")
	check(game.combat.get_node("CharacterPanel/Frame").visible, "Character panel retains its protective frame")
	check(game.combat.get_node("ActionFrame").get_class() == "Control", "Action row stays transparent over the dungeon")
	check(game.gameplay_background.world.camera.projection == Camera3D.PROJECTION_FRUSTUM, "Combat uses a perspective lens")
	check(game.gameplay_background.world.active_room.has_node("ExitStairs") and not game.gameplay_background.world.active_room.has_node("Door"), "Native room has descending stairs instead of a door")
	check(game.gameplay_background.world.active_room.find_children("PassageShadow*", "MeshInstance3D", true, false).is_empty(), "Stair shadows have no translucent layers")
	check(not game.gameplay_background.has_node("Fade/FloorLabel"), "Room transition has no floor-number overlay")
	await snapshot("combat")
	var room: Node3D = game.gameplay_background.world
	var authored_home: Vector3 = room.camera_home
	room.arrive_camera(0.0)
	check(room.camera.position.z >= authored_home.z + 6.0, "Arrival begins farther down the existing corridor")
	var arrival_sides: Array[float] = []
	for progress: float in [0.1, 0.3, 0.5]:
		room.arrive_camera(progress)
		arrival_sides.append(room.camera.position.x - room.camera_home.x)
	check(arrival_sides[0] > 0 and arrival_sides[1] < 0 and arrival_sides[2] > 0, "Arrival alternates left-right-left weight shifts")
	var descent_sides: Array[float] = []
	for progress: float in [0.1, 0.3, 0.5]:
		room.advance_camera(progress)
		var base_x: float = lerpf(room.camera_home.x, room.active_room.get_node("Travel/ExitApproach").position.x, clampf(progress / room.active_room.departure_approach_end, 0.0, 1.0))
		descent_sides.append(room.camera.position.x - base_x)
	check(descent_sides[0] > 0 and descent_sides[1] < 0 and descent_sides[2] > 0, "Stair descent uses the same alternating stepping motion")
	room.arrive_camera(1.0)
	check(room.camera.position.is_equal_approx(authored_home) and room.camera.rotation.is_equal_approx(room.camera_rotation), "Arrival settles exactly at the authored combat camera")
	game.front.settings["combat_speed"] = 1
	offer_loot(0)
	var item_count: int = game.run.items.size()
	game._choose(0)
	check(game.busy and game.gameplay_background.transitioning, "Completing combat starts the first-person descent")
	check(not game.enemy_card.visible and not game.gameplay_background.world.active_room.has_node("Delver"), "First-person descent has no walking character sprite")
	check(game.action.disabled and game.settings_button.disabled, "Combat and pause are locked during descent")
	check(game.board.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Inventory dragging is locked during descent")
	game._choose(1)
	game._act()
	check(game.run.items.size() == item_count and game.run.total_turns == 0, "Transition clicks neither claim rewards nor attack the next enemy")
	await create_timer(1.1).timeout
	check(game.gameplay_background.world.camera.position.z < game.gameplay_background.world.camera_home.z - 1, "Camera advances physically into the 3D room")
	await snapshot("approach")
	await create_timer(0.35).timeout
	check(game.gameplay_background.world.camera.position.y < game.gameplay_background.world.camera_home.y, "Camera descends with the stairs")
	await snapshot("stairs")
	await create_timer(0.3).timeout
	check(game.gameplay_background.fade.modulate.a > 0.1, "Stair descent darkens near its end after the treads are visible")
	await snapshot("stair-darkness")
	await wait_transition()
	check(saw_black and saw_reveal and synchronized, "Enemy stays invisible during black and reveals at the exact room opacity")
	check(saw_visible_arrival and game.gameplay_background.enemy_screen_bounds().size.y > arrival_bounds, "Room is visible during the approach and its world enemy grows naturally as we walk closer")
	check(game.run.fight == 1 and game.run.phase == PackRun.Phase.FIGHT, "Sequence returns on floor two")
	check(game.enemy_card.visible and not game.action.disabled and not game.modal.visible, "Next enemy and controls are ready")
	check(game.gameplay_background.world.camera.position.is_equal_approx(game.gameplay_background.world.camera_home), "First-person camera is reset for the next room")
	await snapshot("floor-two")
	game.front.settings["tooltips"] = true
	var item: Dictionary = game.run.items[0]
	var point: Vector2 = game.board.global_position + game.board.item_rect(item).position + Vector2(24, 24)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	viewport.push_input(motion, true)
	await create_timer(0.4).timeout
	check(not game.inspector.windows.is_empty(), "Real item hover opens its tooltip after the room reveal")
	await snapshot("tooltip-after-descent")
	game.front.settings["combat_speed"] = 4
	offer_loot(3)
	game._choose(0)
	await wait_transition()
	check(game.run.phase == PackRun.Phase.FIGHT and not game.modal.visible and not game.run.relic_rewards.is_empty(), "Milestone relic is deferred after the transition")
	game._open_reward(true)
	game._choose(0)
	check(game.run.phase == PackRun.Phase.FIGHT and not game.busy, "Binding a relic does not replay the transition")
	offer_loot(19)
	game._choose(0)
	check(game.run.phase == PackRun.Phase.VICTORY and game.modal.visible and not game.busy, "Final reward ends the run without a nonexistent floor 21")
	game.start_run("ranger", 42)
	game._choose(0)
	offer_loot(0)
	game._choose(0)
	await create_timer(0.1).timeout
	game.start_run("mage", 42)
	await create_timer(1).timeout
	check(not game.busy and not game.gameplay_background.transitioning and not game.gameplay_background.fade.visible, "New run cancels an old transition cleanly")
	check(game.run.class_key == "mage" and game.run.fight == 0 and not game.modal.visible, "Canceled sequence does not alter the new run")
	game.front.settings["combat_speed"] = 1
	offer_loot(0)
	await create_timer(2.5).timeout
	check(game.gameplay_background.transitioning and game.gameplay_background.world.camera.position.z > game.gameplay_background.world.camera_home.z + 1.0, "Arrival remains an active walk rather than an instant room reset")
	game.start_run("warrior", 42)
	await create_timer(0.3).timeout
	check(not game.busy and not game.gameplay_background.transitioning and game.gameplay_background.world.camera.position.is_equal_approx(game.gameplay_background.world.camera_home), "Restarting during arrival cancels sway and restores the authored camera")
	print("DUNGEON RESULT: %d checks, %d failures" % [checks, failures])
	await preload("res://tests/automatic_combat_cleanup.gd").release(self, game, viewport)
	quit(1 if failures else 0)
