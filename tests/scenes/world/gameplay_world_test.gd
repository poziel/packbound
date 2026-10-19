extends "res://tests/support/test_case.gd"
## Exercise real room replacement, transformed slots, actor reuse and depth.

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

func fixture_room() -> PackedScene:
	var room := Node3D.new()
	room.name = "TestRoom"
	room.set_script(preload("res://scenes/world/rooms/shared/room_definition.gd"))
	var source: Node3D = load("res://scenes/world/biomes/dungeon/rooms/dungeon_room/dungeon_room.tscn").instantiate()
	for path: String in ["CameraStart", "Travel", "EnemySlots"]:
		room.add_child(source.get_node(path).duplicate())
	var second := Marker3D.new()
	second.name = "Slot2"
	second.position = Vector3(-5, 1.06, -3)
	room.get_node("EnemySlots").add_child(second)
	for node: Node in room.find_children("*", "", true, false):
		node.owner = room
	var packed := PackedScene.new()
	packed.pack(room)
	room.free()
	source.free()
	return packed

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(2)
		return
	create_timer(20).timeout.connect(func() -> void: printerr("World test timed out"); quit(2))
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	game = load("res://scenes/main.tscn").instantiate()
	viewport.add_child(game)
	await draw_frame()
	game.start_run("warrior", 42)
	var background: Control = game.gameplay_background
	var world: Node3D = background.world
	var camera_id: int = world.camera.get_instance_id()
	var enemy_id: int = world.enemy.get_instance_id()
	var shadow_id: int = game.enemy_card.shadow.get_instance_id()
	check(background.find_children("*", "SubViewport", true, false).size() == 1, "One gameplay viewport")
	check(background.find_children("*", "Camera3D", true, false).size() == 1, "One gameplay camera")
	check(world.enemy.get_parent() == world.actors, "Actor belongs to shared actor collection")
	check(world.active_room.find_children("*", "Sprite3D", true, false).is_empty(), "Dungeon scenery contains no combat sprites")
	check(world.active_room.get_node("EnemySlots/Slot1") is Marker3D, "Dungeon owns an editor-visible enemy slot")
	var unplaced: Sprite3D = load("res://scenes/world/actors/enemy_actor/enemy_actor.tscn").instantiate()
	check(unplaced.transform.is_equal_approx(Transform3D.IDENTITY), "Reusable actor root has no placement transform warning")
	unplaced.free()
	check(world.set_room(background.entrance_room), "Basement loads through RoomSlot")
	await draw_frame()
	check(world.room_slot.get_child_count() == 1 and background.is_at_entrance(), "Only current room remains mounted")
	check(not world.enemy.has_spawn and not world.enemy.visible and not game.enemy_card.shadow.visible, "Room without enemy slots hides actor and shadow")
	check(not game.enemy_vitals.is_visible_in_tree(), "Room without enemy slots hides combat bars")
	check(world.world_environment.environment != null, "Shared lighting survives room replacement")
	check(world.set_room(background.encounter_room), "Dungeon loads through same RoomSlot")
	await draw_frame()
	check(world.enemy.global_transform.is_equal_approx(world.active_room.get_node("EnemySlots/Slot1").global_transform), "Enemy is placed at room's marker")
	var sample: PackedScene = fixture_room()
	world.room_slot.position = Vector3(4, 2, -3)
	world.room_slot.rotation.y = 0.35
	check(world.set_room(sample) and world.place_enemy_at_slot(1), "Custom room selects second enemy slot")
	await draw_frame()
	var marker: Marker3D = world.active_room.get_node("EnemySlots/Slot2")
	check(world.enemy.global_transform.is_equal_approx(marker.global_transform), "Translated and rotated room places shared actor in world space")
	check(game.enemy_card.world_rest.is_equal_approx(world.enemy.position), "Feedback updates its rest anchor when room changes")
	check(is_equal_approx(game.enemy_card.shadow.position.y, world.enemy.position.y - 0.005), "Shadow follows elevated spawn floor")
	world.arrive_camera(1.0)
	check(world.camera.global_transform.is_equal_approx(world.active_room.get_node("CameraStart").global_transform), "Camera settles at transformed room marker")
	check(world.camera.get_instance_id() == camera_id and world.enemy.get_instance_id() == enemy_id and game.enemy_card.shadow.get_instance_id() == shadow_id, "Room swaps reuse camera, enemy and shadow")
	var invalid := PackedScene.new()
	var empty := Node3D.new()
	invalid.pack(empty)
	empty.free()
	var retained: int = world.active_room.get_instance_id()
	check(not world.set_room(invalid) and world.active_room.get_instance_id() == retained, "Invalid room fails without removing active room")
	world.room_slot.transform = Transform3D.IDENTITY
	world.set_room(background.encounter_room)
	game.run.fight = 8
	game.run.prepare_enemy()
	game._refresh()
	game.enemy_card.set_feedback_paused(true)
	await draw_frame()
	var body: Rect2 = background.enemy_screen_bounds()
	var point := Vector2i(body.get_center())
	var before: Color = viewport.get_texture().get_image().get_pixelv(point)
	var blocker := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(6, 7, 0.3)
	blocker.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color.GREEN
	blocker.material_override = material
	world.add_child(blocker)
	blocker.position = world.enemy.position + Vector3(0, 3, 1)
	await draw_frame()
	var image: Image = viewport.get_texture().get_image()
	var after: Color = image.get_pixelv(point)
	check(after.g > 0.5 and after.r < 0.1 and after != before, "Scenery in front of monster actually occludes it")
	var hit: Tween = game.enemy_card.play_hit(true)
	hit.pause()
	hit.custom_step(0.07)
	await draw_frame()
	var flashed: Color = viewport.get_texture().get_image().get_pixelv(point)
	check(flashed.g > 0.5 and flashed.r < 0.1, "Hit flash also respects scenery depth")
	blocker.queue_free()
	game.enemy_card.reset_feedback()
	await draw_frame()
	DirAccess.make_dir_recursive_absolute(preload("res://tests/support/artifact_paths.gd").path("gameplay-world"))
	viewport.get_texture().get_image().save_png(preload("res://tests/support/artifact_paths.gd").path("gameplay-world/dungeon.png"))
	background.prepare_entrance()
	await draw_frame()
	viewport.get_texture().get_image().save_png(preload("res://tests/support/artifact_paths.gd").path("gameplay-world/basement.png"))
	report("GAMEPLAY WORLD RESULT")
	await preload("res://tests/support/automatic_combat_cleanup.gd").release(self, game, viewport)
	quit(1 if failures else 0)
