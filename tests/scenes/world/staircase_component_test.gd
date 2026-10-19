extends "res://tests/support/test_case.gd"


func _initialize() -> void:
	if not require_isolation():
		return
	_run.call_deferred()


func _run() -> void:
	var paths: Array[String] = ["res://components/world/architecture/staircase/staircase.tscn", "res://components/world/architecture/staircase/staircase.tscn"]
	for path: String in paths:
		check(ResourceLoader.exists(path), "Reusable staircase exists: " + path)
	if failures:
		report("STAIRCASE RESULT")
		quit(1)
		return
	var entrance: Node3D = load(paths[0]).instantiate()
	entrance.role = 0
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
	exit.wall_color = Color(0.5, 0.8, 1.0)
	exit.step_color = Color(0.8, 0.3, 0.1)
	exit.ceiling_color = Color(0.1, 0.2, 0.7)
	exit.depth_color = Color(0.2, 0.05, 0.1)
	exit.glow_color = Color(1.0, 0.4, 0.1)
	exit.glow_intensity = 0.6
	check(custom_art.get_active_material(0).albedo_color.is_equal_approx(exit.wall_color), "Wall color applies directly without multiplying the source gray")
	check(exit.get_node("Visuals/DefaultStone/Tread00").material_override.albedo_color.is_equal_approx(exit.step_color), "Step color applies directly")
	check(exit.get_node("Visuals/DefaultStone/Ceiling").material_override.albedo_color.is_equal_approx(exit.ceiling_color), "Ceiling has an independent direct color")
	check(entrance.depth_color == Color.BLACK and entrance.get_node("EndWall").material_override.albedo_color == Color.BLACK, "Instance appearance changes do not affect other staircases")
	check(exit.shadow.get_shader_parameter("depth_color").is_equal_approx(exit.depth_color), "Depth shader receives the selected passage color")
	check(exit.get_node("EndWall").material_override.albedo_color.is_equal_approx(exit.depth_color), "End cap matches the selected passage color")
	check(is_equal_approx(exit.get_node("Visuals/InteriorLight").light_energy, 120.0), "Normalized glow maps to the expanded light-energy range")
	exit.glow_intensity = 1.0
	check(is_equal_approx(exit.get_node("Visuals/InteriorLight").light_energy, 200.0), "Maximum glow is twice the former 100-energy maximum")
	exit.depth_strength = 0.5
	check(is_equal_approx(exit.shadow.get_shader_parameter("depth_strength"), 1.0), "Half depth strength matches the former full strength")
	exit.depth_strength = 1.0
	check(is_equal_approx(exit.shadow.get_shader_parameter("depth_strength"), 2.0), "Full depth strength has twice the former shader strength")
	check(is_equal_approx(exit.shadow_amount(exit.to_global(Vector3(0, 0, -exit.run_length * 0.475))), 1.0), "Doubled depth reaches full opacity halfway along the fade")
	check(entrance.to_local(entrance.get_node("Visuals/InteriorLight").global_position).is_equal_approx(Vector3(0, 1.8, 3)), "Entrance light sits near the bottom landing on the room side")
	check(exit.to_local(exit.get_node("Visuals/InteriorLight").global_position).is_equal_approx(Vector3(0, 1.8, -3)), "Exit light sits near the top landing on the room side")
	entrance.role = 1
	check(entrance.to_local(entrance.get_node("Visuals/InteriorLight").global_position).is_equal_approx(Vector3(0, 1.8, -3)), "Switching roles repositions the light to the new room-side landing")
	entrance.role = 0
	var door: Node3D = load("res://scenes/world/biomes/dungeon/shared/selector_door/selector_door.tscn").instantiate()
	root.add_child(door)
	door.hover_glow_color = Color(0.9, 0.2, 0.5)
	door.hover_glow_intensity = 0.025
	var door_stairs: Node3D = door.get_node("ExitStairs")
	var idle_depth: Color = door_stairs.depth_color
	var idle_depth_strength: float = door_stairs.depth_strength
	var idle_text: Color = door.get_node("Sign").modulate
	var idle_outline: Color = door.get_node("Sign").outline_modulate
	check(not door.has_node("Glow") and not door.has_node("InnerGlow"), "Dungeon hover glow comes exclusively from the staircase component")
	check(is_zero_approx(door_stairs.glow_intensity), "Selector stairs have no glow while idle")
	door.set_highlight(true)
	await create_timer(0.3).timeout
	check(is_equal_approx(door_stairs.glow_intensity, 0.025) and is_equal_approx(door_stairs.get_node("Visuals/InteriorLight").light_energy, 5.0) and door_stairs.glow_color == door.hover_glow_color, "Selector uses normalized glow intensity on hover")
	check(door_stairs.depth_strength < idle_depth_strength and door_stairs.depth_strength > 0.0, "Hover softens the depth fade while preserving passage depth")
	check(door_stairs.depth_color.r > idle_depth.r and door_stairs.depth_color.b > idle_depth.b, "Hover gives the passage a subtle hue from its glow")
	check(door_stairs.get_node("EndWall").material_override.albedo_color.is_equal_approx(door_stairs.depth_color), "Passage end cap follows the hover tint")
	check(door.get_node("Sign").modulate.is_equal_approx(door_stairs.glow_color) and door.get_node("Sign").outline_modulate.is_equal_approx(door_stairs.glow_color), "Entire sign including its outline matches the staircase glow color")
	check(not door.get_node("Sign").shaded, "Sign remains uniformly luminous regardless of local lighting")
	door.set_highlight(false)
	await create_timer(0.3).timeout
	check(is_zero_approx(door_stairs.glow_intensity) and is_zero_approx(door_stairs.get_node("Visuals/InteriorLight").light_energy), "Leaving the door switches its glow off")
	check(door.get_node("Sign").modulate.is_equal_approx(idle_text) and door.get_node("Sign").outline_modulate.is_equal_approx(idle_outline), "Hover exit restores the complete original sign appearance")
	check(door_stairs.depth_color.is_equal_approx(idle_depth) and is_equal_approx(door_stairs.depth_strength, idle_depth_strength), "Hover exit restores the configured passage color and darkening")
	door.set_highlight(true)
	await create_timer(0.05).timeout
	door.set_highlight(false)
	await create_timer(0.3).timeout
	check(door_stairs.depth_color.is_equal_approx(idle_depth) and is_equal_approx(door_stairs.depth_strength, idle_depth_strength), "Interrupted hover restores the original depth without accumulating changes")
	door.queue_free()
	exit.depth_color = Color.BLACK
	exit.glow_intensity = 0.0
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
	for path: String in ["res://scenes/world/biomes/dungeon/rooms/dungeon_room/dungeon_room.tscn", "res://scenes/world/biomes/basement/rooms/basement_entrance/basement_entrance.tscn"]:
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
	var world: Node3D = load("res://scenes/world/gameplay_world/gameplay_world.tscn").instantiate()
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
	report("STAIRCASE RESULT")
	quit(1 if failures else 0)
