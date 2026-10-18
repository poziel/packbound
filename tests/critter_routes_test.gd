extends SceneTree

var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _run() -> void:
	var room: Node3D = load("res://scenes/gameplay/rooms/dungeon/dungeon_room.tscn").instantiate()
	root.add_child(room)
	await process_frame
	var life: Node3D = room.get_node("CorridorLife")
	life.set_process(false)
	life.rng.seed = 42
	life._begin_critter("mouse", 1)
	var quick: float = life.critters["mouse"]["duration"]
	check(quick < 3.0, "A rat can peek out and retreat in about two seconds")
	life._begin_critter("mouse", 0)
	var long_visit: float = life.critters["mouse"]["duration"]
	check(long_visit >= 9.0 and long_visit > quick * 3.0, "Wall-side rat spends substantially longer exploring than the peeking rat")
	check(life.mouse.position.z < -8.0, "Exploring rat enters from the dark stair passage")
	life._begin_critter("spider", 0)
	var state: Dictionary = life.critters["spider"]
	state["age"] = state["duration"] * 0.7
	life._pose_critter("spider", state, 0.0)
	check(life.spider.position.y > 6.8 and life.spider.basis.y.normalized().dot(Vector3.DOWN) > 0.8, "Web-visiting spider reaches the ceiling and crawls upside down")
	var floor_entries: Dictionary = {}
	var ceiling_routes: int = 0
	var rats_with_different_exits: int = 0
	for kind: String in ["mouse", "spider"]:
		var distinct_stops: Dictionary = {}
		for index in range(life.critters[kind]["routes"].size()):
			life._begin_critter(kind, index)
			state = life.critters[kind]
			var route: Dictionary = state["routes"][index]
			var points: Array = route["points"]
			var reached_ceiling: bool = false
			var stopped_at: Array[Vector3] = []
			var travel_time: float = 0.0
			for step: Dictionary in state["timeline"]:
				state["age"] = (step["start"] + step["end"]) * 0.5
				life._pose_critter(kind, state, 0.0)
				check(state["node"].position.is_finite() and state["node"].basis.is_finite(), "Every route has a valid position and surface orientation")
				if step["stopped"]:
					var held: Vector3 = state["node"].position
					state["age"] = lerpf(step["start"], step["end"], 0.85)
					life._pose_critter(kind, state, 0.0)
					check(state["node"].position.is_equal_approx(held), "Authored inspection stop holds its actual waypoint")
					stopped_at.append(held)
					if kind == "mouse":
						check(life.mouse_feet.all(func(foot: Node3D) -> bool: return is_zero_approx(foot.rotation.x)), "Sniffing rat stops its running gait")
				else:
					travel_time += step["end"] - step["start"]
					if kind == "spider" and step["normal_from"] == Vector3.DOWN and step["normal_to"] == Vector3.DOWN and is_equal_approx(step["from"].y, step["to"].y):
						reached_ceiling = true
						check(life.spider.basis.y.normalized().dot(Vector3.DOWN) > 0.9, "Ceiling spider stays upside down throughout ceiling travel")
			check(travel_time >= route["travel"].x - 0.001 and travel_time <= route["travel"].y + 0.001, "Travel time follows each route's own pace range")
			distinct_stops[str(stopped_at)] = true
			if kind == "mouse":
				floor_entries[str(points[0])] = true
				if not points[0].is_equal_approx(points.back()):
					rats_with_different_exits += 1
			if reached_ceiling:
				ceiling_routes += 1
		check(distinct_stops.size() >= 4, "Visits do not share one mandatory midpoint pause")
	check(floor_entries.size() >= 4 and rats_with_different_exits >= 3, "Rats use varied hiding places and can leave somewhere other than their entrance")
	check(ceiling_routes >= 3, "Multiple spider behaviors include ceiling travel")
	life._begin_critter("mouse", 3)
	check(life.critters["mouse"]["timeline"].all(func(step: Dictionary) -> bool: return not step["stopped"]), "Dashing rat can cross the room without stopping to sniff")
	room.queue_free()
	await process_frame
	print("CRITTER ROUTES RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
