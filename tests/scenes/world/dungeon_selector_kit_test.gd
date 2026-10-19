extends "res://tests/support/prototype_support.gd"

func _run() -> void:
	var solid_samples: Dictionary = {
		"column": Vector3(0, 1.2, 0),
		"floor_chunk": Vector3(1.95, 0, 1.05),
		"roof_chunk": Vector3(1.6, 0.03, 1.85),
		"wall_chunk": Vector3(2, 1.7, -0.1),
		"door_frame": Vector3(-2.23, 0.8, 0.1),
	}
	for part: String in solid_samples:
		var component: Node3D = load("res://scenes/world/biomes/dungeon/shared/%s/%s.tscn" % [part, part]).instantiate()
		check(_solid_at(component, solid_samples[part]), "Recessed core seals the open seams in " + part)
		if part == "column":
			check(not _solid_at(component, Vector3(0.34, 1.2, 0)), "Column core stays recessed behind the block edges")
		if part == "door_frame":
			check(not _solid_at(component, Vector3(0, 3, 0.1)), "Door cores leave the camera passage open")
			check(_solid_at(component, Vector3(1.95, 2, 0.1)), "Frame bricks inset slightly past the stair wall to avoid flush faces")
			check(not component.has_node("Piece05"), "Duplicated overlapping jamb block is removed")
		component.free()
	for part: String in ["wall_chunk", "floor_chunk", "column", "door_frame", "roof_chunk"]:
		var path: String = "res://scenes/world/biomes/dungeon/shared/%s/%s.tscn" % [part, part]
		check(ResourceLoader.exists(path), "Reusable dungeon component exists: " + part)
		if ResourceLoader.exists(path):
			var node: Node3D = load(path).instantiate()
			check(node.find_children("*", "MeshInstance3D", true, false).size() > 1, "Component preserves separate authored mesh pieces")
			node.free()
	var room: Node3D = load("res://scenes/world/biomes/dungeon/rooms/floor_selector/floor_selector.tscn").instantiate()
	root.add_child(room)
	check(room.staircase("entrance") != null, "Selector uses the shared dungeon entry stairs")
	if room.staircase("entrance"):
		check(room.staircase("entrance").scene_file_path == "res://scenes/world/biomes/dungeon/shared/staircase/staircase.tscn" and room.staircase("entrance").role == 0, "Entry uses the designed dungeon entrance variant")
		check(is_equal_approx(room.staircase("entrance").width, 4.4), "Dungeon entrance uses the wider 4.4-unit stair envelope")
		check(room.travel_marker("ArrivalStart").global_position.y > room.travel_marker("ArrivalLanding").global_position.y + 3.5, "Selector arrival visibly descends the original full stair rise")
	var choices: Array[Dictionary] = [{"id": "combat", "kind": "combat"}, {"id": "relic", "kind": "relic"}, {"id": "rest", "kind": "rest"}, {"id": "encounter", "kind": "encounter"}]
	room.configure(choices)
	for door: Node3D in room.visible_doors():
		room.select_exit(door.get_meta("choice_id"))
		var stairs: Node3D = room.staircase("exit")
		check(stairs != null, "Each selected door resolves its shared exit stairs")
		if stairs:
			check(stairs.scene_file_path == "res://scenes/world/biomes/dungeon/shared/staircase/staircase.tscn" and stairs.role == 1, "Exit uses the designed dungeon exit variant")
			check(is_equal_approx(stairs.width, 4.4) and stairs.scale.is_equal_approx(Vector3.ONE), "Dungeon exit widens its geometry without scaling travel markers")
			check(room.travel_marker("ExitApproach") == stairs.get_node("Top") and room.travel_marker("ExitEnd") == stairs.get_node("Bottom"), "Travel follows chosen stair markers")
	var camera: Marker3D = room.get_node("CameraStart")
	check(absf(camera.rotation.y) < 0.001 and absf(camera.position.x) < 0.001, "Camera faces the door bank front-on")
	check(absf(room.camera_frustum_offset.x) > 0.01, "Off-axis framing leaves space for inventory")
	var source: Node3D = load("res://scenes/world/biomes/dungeon/rooms/dungeon_room/dungeon_room.tscn").instantiate()
	for part: String in ["WallChunk", "FloorChunk", "Column", "DoorFrame", "RoofChunk"]:
		check(source.has_node("Shared" + part), "Combat room instances shared " + part)
	check(source.find_children("KitFloorChunk*", "Node3D", false, false).size() > 1, "Combat floor consistently reuses shared patches")
	check(source.find_children("KitRoofChunk*", "Node3D", false, false).size() > 1, "Combat ceiling consistently reuses shared patches")
	check(source.get_node("EntryStairs").scene_file_path == room.staircase("entrance").scene_file_path, "Combat and selector share the same dungeon entrance design")
	source.free()
	var span: Node3D = load("res://scenes/world/biomes/dungeon/shared/wall_span/wall_span.tscn").instantiate()
	root.add_child(span)
	span.set_span(1.35)
	for chunk: Node3D in span.get_node("Chunks").get_children():
		if not chunk.visible:
			continue
		for brick: MeshInstance3D in chunk.get_children():
			if brick.visible:
				check(brick.position.x + brick.mesh.size.x * 0.5 <= 1.351, "Boundary bricks fit the wall span without stretching")
	span.set_span(13.0)
	check(span.get_node("Chunks/Chunk03").visible, "Wall spans can restore previously hidden chunks")
	span.queue_free()
	room.queue_free()
	await process_frame
	report("DUNGEON SELECTOR KIT")
	quit(1 if failures else 0)

func _solid_at(component: Node3D, point: Vector3) -> bool:
	for mesh: MeshInstance3D in component.find_children("*", "MeshInstance3D", true, false):
		if mesh.visible and mesh.get_aabb().has_point(mesh.transform.affine_inverse() * point):
			return true
	return false
