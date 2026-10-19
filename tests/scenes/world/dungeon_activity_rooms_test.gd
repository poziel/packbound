extends "res://tests/support/prototype_support.gd"

func _run() -> void:
	var background: Control = preload("res://scenes/world/gameplay_background/gameplay_background.gd").new()
	for kind: String in ["encounter", "relic", "rest"]:
		var state: PackRun = fixture()
		state.phase = PackRun.Phase.ROOM
		state.room_kind = kind
		for depth: int in [1, 10, 11]:
			state.floor_index = depth - 1
			var expected: String = "res://scenes/world/biomes/dungeon/rooms/%s_room/%s_room.tscn" % [kind, kind] if depth <= 10 else "res://scenes/world/rooms/%s/%s_room/%s_room.tscn" % [kind, kind, kind]
			check(background.scene_for_state(state).resource_path == expected, "Activity scenery follows the biome boundary for %s on floor %d" % [kind, depth])
		var room: Node3D = load("res://scenes/world/biomes/dungeon/rooms/%s_room/%s_room.tscn" % [kind, kind]).instantiate()
		root.add_child(room)
		await process_frame
		check(room._get_configuration_warnings().is_empty(), "Dungeon %s room satisfies the room/travel contract" % kind)
		check(room.has_node("FloorTiles") and room.has_node("CeilingTiles") and room.has_node("Masonry"), "Dungeon %s shares the masonry chamber" % kind)
		for role: String in ["entrance", "exit"]:
			var stair: Node3D = room.staircase(role)
			check(stair != null and stair.scene_file_path == "res://scenes/world/biomes/dungeon/shared/staircase/staircase.tscn", "Dungeon %s uses the shared %s staircase" % [kind, role])
			check(stair.role == (0 if role == "entrance" else 1) and is_equal_approx(stair.width, 4.4), "Stair role and full width are correct")
		check(room.travel_marker("ArrivalStart").global_position.y > room.travel_marker("ArrivalLanding").global_position.y + 3.5, "Arrival visibly descends into the room")
		check(room.travel_marker("ExitApproach").global_position.y > room.travel_marker("ExitEnd").global_position.y + 3.5, "Departure uses the full exit staircase")
		check(room.enemy_slots().is_empty() and state.can_edit_inventory(), "Activity allows inventory management without an enemy")
		if kind == "relic":
			check(room.get_node("Pedestals").get_child_count() == 3, "Relic room presents three pedestals")
		elif kind == "rest":
			check(room.has_node("BenchSeat0") and room.has_node("FireBowl"), "Rest area provides seating and a hearth")
		else:
			check(room.get_script() == preload("res://scenes/world/rooms/shared/encounter_room.gd"), "Existing encounter controller remains connected")
			room.combat_active = true
			check(room.enemy_slots().size() == 1, "Encounter can reveal the keeper for a fight")
		room.queue_free()
		await process_frame
	background.free()
	report("DUNGEON ACTIVITIES")
	quit(1 if failures else 0)
