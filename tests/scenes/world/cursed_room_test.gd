extends "res://tests/support/test_case.gd"
## Validate a real biome swap and shared travel, not generated mesh counts.

func _initialize() -> void:
	if not require_isolation():
		return
	_run.call_deferred()

func _run() -> void:
	create_timer(15).timeout.connect(func() -> void: printerr("Cursed room test timed out"); quit(2))
	var world: Node3D = load("res://scenes/world/gameplay_world/gameplay_world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var camera_id: int = world.camera.get_instance_id()
	var enemy_id: int = world.enemy.get_instance_id()
	var scene: PackedScene = load("res://scenes/world/biomes/cursed/rooms/cursed_room/cursed_room.tscn")
	check(scene != null and world.set_room(scene), "Cursed depths loads through the existing room interface")
	await process_frame
	var room: Node3D = world.active_room
	check(room.get_node("CameraStart") is Marker3D and room.enemy_slots().size() == 1, "Biome has a resting camera and encounter slot")
	check(world.camera.get_instance_id() == camera_id and world.enemy.get_instance_id() == enemy_id, "Biome swap reuses camera and actor")
	check(world.world_environment.environment == room.environment, "Biome supplies its violet environment")
	check(world.enemy.global_transform.is_equal_approx(room.enemy_slots()[0].global_transform), "Encounter uses the shared actor placement")
	check(room.find_children("*", "Camera3D", true, false).is_empty() and room.find_children("*", "Sprite3D", true, false).is_empty(), "Scenery does not embed cameras or combat sprites")
	for kind: String in ["entrance", "exit"]:
		var stairs: Node3D = room.staircase(kind)
		check(stairs != null and is_equal_approx(stairs.width, 4.0), "Biome uses the shared " + kind + " staircase")
		check(stairs.get_node("EndWall").is_visible_in_tree(), "Biome stairs retain their sealed black end")
	world.arrive_camera(0.0)
	check(world.camera.global_position.is_equal_approx(room.travel_marker("ArrivalStart").global_position), "Arrival begins on the upper stairs")
	world.arrive_camera(1.0)
	check(world.camera.global_transform.is_equal_approx(room.get_node("CameraStart").global_transform), "Arrival ends at the encounter viewpoint")
	world.advance_camera(1.0)
	check(world.camera.global_position.is_equal_approx(room.travel_marker("ExitEnd").global_position), "Departure reaches the onward stairs")
	room.set_process(false)
	var light: OmniLight3D = room.get_node("CurseLights/VioletLight1")
	room._process(1.0)
	check(not is_equal_approx(light.light_energy, room.energies[0]), "Ambient curse lighting pulses over time")
	var stone: Node3D = room.get_node("FallenMasonry/Rubble")
	stone.position += Vector3(0, 0.2, 0)
	var edited: Vector3 = stone.position
	room._process(1.0)
	check(stone.position.is_equal_approx(edited), "Ambient animation preserves manually edited geometry")
	var demo: Node3D = load("res://scenes/world/biomes/cursed/demo/demo.tscn").instantiate()
	root.add_child(demo)
	await process_frame
	check(demo.get_node("Camera").scene_file_path == "res://components/tools/free_camera/free_camera.tscn", "Biome demo uses shared Z-toggle inspection camera")
	demo.queue_free()
	world.queue_free()
	await process_frame
	report("CURSED ROOM RESULT")
	quit(1 if failures else 0)
