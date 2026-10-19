extends "res://tests/support/test_case.gd"


func _initialize() -> void:
	if not require_isolation():
		return
	_run.call_deferred()


func _run() -> void:
	var room: Node3D = load("res://scenes/world/biomes/dungeon/rooms/dungeon_room/dungeon_room.tscn").instantiate()
	root.add_child(room)
	await process_frame
	var life: Node3D = room.get_node("CorridorLife")
	life.set_process(false)
	life.rng.seed = 42
	check(life.flames.size() == 4, "Room torches and both designed dungeon stair torches retain animated fire")
	for path: String in ["Sconce", "@MeshInstance3D@513", "ExitStairs/Visuals/RoomDesign/@MeshInstance3D@516"]:
		var torch: Node3D = room.get_node(path)
		check(is_equal_approx(rad_to_deg(torch.basis.y.angle_to(Vector3.UP)), 25.0), "Torch leans 25 degrees: " + path)
	var fire: Dictionary = life.flames[0]
	var original: Transform3D = fire["source"].transform
	check(fire["anchor"].global_transform.is_equal_approx(fire["source"].global_transform), "Fire follows the newly tilted torch in world space")
	fire["source"].position.x += 0.2
	life.advance_ambient(0.1)
	check(fire["anchor"].global_transform.is_equal_approx(fire["source"].global_transform), "Fire still follows later manual adjustments")
	fire["source"].transform = original
	check(life.get_node("AirborneDust").emitting and life.get_node("DustHaze").emitting, "Dust effects remain active")
	check(life.spider.scale.is_equal_approx(Vector3.ONE * 0.42), "Wall spider is substantially smaller than the former floor spider")
	for kind: String in ["spider", "mouse"]:
		var state: Dictionary = life.critters[kind]
		check(state["routes"].size() == 5, kind + " has five distinct authored routes")
		var selected: Dictionary = {}
		var previous: int = -1
		var no_repeat: bool = true
		for trial in range(40):
			life._begin_critter(kind)
			var index: int = state["last_path"]
			selected[index] = true
			no_repeat = no_repeat and index != previous
			previous = index
		check(selected.size() == 5 and no_repeat, kind + " random selection visits all routes and avoids immediate repetition")
		var cooldowns: Dictionary = {}
		var intervals_valid: bool = true
		for index in range(5):
			life._begin_critter(kind, index)
			var points: Array = state["routes"][index]["points"]
			var first: Vector3 = life._route_point(points, 0.0)
			var last: Vector3 = life._route_point(points, 1.0)
			check(first.is_equal_approx(points[0]) and last.is_equal_approx(points.back()), kind + " preserves entry and exit for route " + str(index))
			state["age"] = state["duration"] * 0.3
			life._pose_critter(kind, state, 0.1)
			check(state["node"].position.distance_to(first) > 0.5, kind + " moves along route " + str(index))
			if kind == "spider":
				life._pose_critter(kind, state, 0.0)
				var sample: Dictionary = life._sample_critter(state)
				var surface: Vector3 = sample["normal"].slide(sample["heading"].normalized()).normalized()
				check(state["node"].basis.y.normalized().dot(surface) > 0.99, "Spider follows its surface while rounding a corner")
			else:
				var stops: Array = state["timeline"].filter(func(step: Dictionary) -> bool: return step["stopped"])
				if not stops.is_empty():
					var stop: Dictionary = stops[0]
					state["age"] = lerpf(stop["start"], stop["end"], 0.25)
					life._pose_critter(kind, state, 0.1)
					var pause_point: Vector3 = life.mouse.position
					state["age"] = lerpf(stop["start"], stop["end"], 0.75)
					life._pose_critter(kind, state, 0.1)
					check(life.mouse.position.is_equal_approx(pause_point), "Rat pauses at its own authored inspection point")
				else:
					check(state["duration"] < 4.0, "Quick dash has no forced inspection pause")
			state["age"] = state["duration"]
			life.advance_ambient(0.01)
			var low: float = life.spider_interval_min if kind == "spider" else life.mouse_interval_min
			var high: float = life.spider_interval_max if kind == "spider" else life.mouse_interval_max
			intervals_valid = intervals_valid and state["cooldown"] >= low and state["cooldown"] <= high
			cooldowns[snappedf(state["cooldown"], 0.01)] = true
			check(not state["node"].visible and not state["active"], kind + " exits and hides before its next cooldown")
		check(intervals_valid and cooldowns.size() > 1, kind + " gets varied cooldowns after completing its routes")
	check(life.spider_interval_min != life.mouse_interval_min and life.spider_interval_max != life.mouse_interval_max, "Animals have independent spawn timing ranges")
	var spawn_events: Array[Dictionary] = []
	var waits: Dictionary = {"spider": {}, "mouse": {}}
	var scheduler_valid: bool = true
	for tick in range(3000):
		var counts := {"spider": life.critters["spider"]["spawns"], "mouse": life.critters["mouse"]["spawns"]}
		life.advance_ambient(0.1)
		for kind: String in counts:
			var state: Dictionary = life.critters[kind]
			if state["spawns"] != counts[kind]:
				if not spawn_events.is_empty():
					scheduler_valid = scheduler_valid and life.elapsed - spawn_events.back()["time"] >= 2.49
				spawn_events.append({"kind": kind, "time": life.elapsed})
			if not state["active"]:
				waits[kind][snappedf(state["cooldown"], 1.0)] = true
	check(spawn_events.size() > 10 and scheduler_valid, "Automatic scheduler keeps independently timed appearances at least 2.5 seconds apart")
	check(waits["spider"].size() > 3 and waits["mouse"].size() > 3, "Both animals use varying waits during ordinary playback")
	room.queue_free()
	await process_frame
	report("CORRIDOR LIFE RESULT")
	quit(1 if failures else 0)
