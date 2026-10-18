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
	var dungeon: Control = load("res://scenes/gameplay/gameplay_background.tscn").instantiate()
	root.add_child(dungeon)
	await process_frame
	dungeon._reveal_room(0.2)
	var upper_eye: float = dungeon.world.camera.position.y
	check(dungeon.fade.modulate.a < 0.1 and upper_eye > dungeon.world.camera_home.y + 1.5, "Arrival reveals the view from the upper-floor entry stairs")
	dungeon._reveal_room(0.6)
	check(dungeon.world.camera.position.y < upper_eye - 1.0, "Arrival physically descends toward the corridor floor")
	check(dungeon.world.active_room.has_node("EntryStairs") and dungeon.world.active_room.has_node("ExitStairs"), "Room contains separate arrival and onward staircases")
	dungeon.reset()
	var durations: Array[float] = []
	var wall_durations: Array[float] = []
	for speed: float in [1.0, 2.0, 3.0, 4.0]:
		var start: int = Time.get_ticks_msec()
		var duration: float = 0.0
		dungeon.descend(func() -> void: pass, speed)
		while dungeon.transitioning:
			await process_frame
			duration += root.get_process_delta_time()
		wall_durations.append((Time.get_ticks_msec() - start) / 1000.0)
		durations.append(duration)
		var expected: float = (2.2 + dungeon.arrival_seconds) / speed
		check(absf(duration - expected) < 0.22, "Entire travel sequence honors %dx speed: %.3fs vs %.3fs" % [speed, duration, expected])
	check(durations[3] < durations[0] * 0.3, "4x arrival and descent take approximately one quarter of 1x travel time")
	dungeon.queue_free()
	await process_frame
	print("TRAVEL SPEED RESULT: %d checks, %d failures; animation seconds: %s; wall seconds: %s" % [checks, failures, durations, wall_durations])
	quit(1 if failures else 0)
