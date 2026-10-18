extends SceneTree

var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _run() -> void:
	var paths: Array[String] = ["res://components/staircase/entrance_stairs.tscn", "res://components/staircase/exit_stairs.tscn"]
	for path: String in paths:
		check(ResourceLoader.exists(path), "Reusable staircase exists: " + path)
	if failures:
		print("STAIRCASE RESULT: %d checks, %d failures" % [checks, failures])
		quit(1)
		return
	var entrance: Node3D = load(paths[0]).instantiate()
	var exit: Node3D = load(paths[1]).instantiate()
	var surface_material := StandardMaterial3D.new()
	surface_material.albedo_color = Color("664c3b")
	var custom_art := MeshInstance3D.new()
	custom_art.mesh = BoxMesh.new()
	custom_art.mesh.material = surface_material
	exit.get_node("Visuals").add_child(custom_art)
	root.add_child(entrance)
	root.add_child(exit)
	await process_frame
	check(custom_art.get_active_material(0).next_pass == exit.shadow, "Artist-assigned surface materials receive the shared darkness")
	check(surface_material.next_pass == null, "Instance shadows do not modify the artist's shared material resource")
	check(entrance.get_node("Visuals").get_child_count() > 0 and exit.get_node("Visuals").get_child_count() > 0, "Both scenes contain saved editable artwork")
	check(is_equal_approx(entrance.width, exit.width) and is_equal_approx(entrance.rise, exit.rise) and is_equal_approx(entrance.run_length, exit.run_length), "Entrance and exit share physical dimensions")
	var travel: Vector3 = exit.get_node("Bottom").position - exit.get_node("Top").position
	check((entrance.get_node("Bottom").position - entrance.get_node("Top").position).is_equal_approx(travel), "Both roles share the same descent profile")
	check(is_equal_approx(entrance.get_node("Bottom").position.y, 3.0), "Entrance lands at the corridor's eye height")
	exit.position = Vector3(7, 2, -4)
	exit.rotation.y = PI * 0.5
	await process_frame
	var far: Vector3 = exit.to_global(Vector3(0, -exit.rise, -exit.run_length))
	check(exit.shadow_amount(far) > 0.99 and exit.shadow_amount(exit.global_position) < 0.01, "Shadows follow a moved and rotated exit staircase")
	check(exit.shadow.get_shader_parameter("world_to_stairs").is_equal_approx(exit.global_transform.affine_inverse()), "Rendered shadow receives the moved and rotated staircase transform")
	check(entrance.shadow_amount(entrance.to_global(Vector3(0, entrance.rise, entrance.run_length))) > 0.99, "Arrival stairs darken toward the upper passage")
	check(not exit.get_node("Guides").visible, "Design guides stay out of gameplay")
	for stairs: Node3D in [entrance, exit]:
		var wall: MeshInstance3D = stairs.get_node_or_null("EndWall")
		check(wall != null and wall.visible, "Both stair roles have a closed end by default")
		if wall:
			var material: StandardMaterial3D = wall.material_override
			check(material.albedo_color == Color.BLACK and material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED, "End walls remain opaque black regardless of scene lighting")
			check(wall.mesh.size.x >= stairs.width, "End walls cover the full stair width")
	check(entrance.get_node("EndWall").position.z > entrance.get_node("Top").position.z, "Entrance closes behind the arriving camera")
	check(exit.get_node("EndWall").position.z < exit.get_node("Bottom").position.z, "Exit closes beyond the departing camera's final position")
	for path: String in ["res://scenes/gameplay/rooms/dungeon/dungeon_room.tscn", "res://scenes/gameplay/rooms/basement/basement_entrance.tscn"]:
		var room: Node3D = load(path).instantiate()
		root.add_child(room)
		await process_frame
		check(room.get_node_or_null("EntryStairs") != null and room.get_node_or_null("ExitStairs") != null, "Room includes both shared stair roles: " + path)
		check(room.get_node("EntryStairs/EndWall").is_visible_in_tree() and room.get_node("ExitStairs/EndWall").is_visible_in_tree(), "Room-specific artwork keeps both inherited end walls")
		var stair: Node3D = room.get_node("ExitStairs")
		check(room.travel_marker("ExitEnd") == stair.get_node("Bottom"), "Room travel resolves directly to the staircase marker")
		var before: Vector3 = room.travel_marker("ExitEnd").global_position
		stair.position.x += 2.0
		check(room.travel_marker("ExitEnd").global_position.is_equal_approx(before + Vector3(2, 0, 0)), "Moving stairs updates the route without copying room markers")
		room.queue_free()
	var world: Node3D = load("res://scenes/gameplay/gameplay_world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.active_room.walking_sway = 0.0
	world.active_room.walking_bob = 0.0
	var onward: Node3D = world.active_room.get_node("ExitStairs")
	onward.position += Vector3(2, 1, -1)
	onward.rotation.y = 0.6
	world.advance_camera(1.0)
	check(world.camera.global_position.is_equal_approx(onward.get_node("Bottom").global_position), "Departure camera reaches a translated and rotated staircase's lower marker")
	var expected: Basis = onward.get_node("Top").global_basis * Basis(Vector3.RIGHT, -deg_to_rad(onward.look_down_degrees))
	check(world.camera.global_basis.is_equal_approx(expected), "Departure camera faces the rotated stairs with the configured gentle tilt")
	var incoming: Node3D = world.active_room.get_node("EntryStairs")
	incoming.position += Vector3(-2, 1, 1)
	incoming.rotation.y = -0.4
	world.arrive_camera(0.0)
	check(world.camera.global_position.is_equal_approx(incoming.get_node("Top").global_position), "Arrival camera starts on the transformed entrance stairs")
	world.arrive_camera(1.0)
	check(world.camera.global_position.is_equal_approx(world.active_room.get_node("CameraStart").global_position), "Arrival still ends at the room's encounter viewpoint")
	world.queue_free()
	entrance.queue_free()
	exit.queue_free()
	await process_frame
	print("STAIRCASE RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
