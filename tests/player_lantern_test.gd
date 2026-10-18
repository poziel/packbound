extends SceneTree
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func _run() -> void:
	create_timer(10).timeout.connect(func() -> void: printerr("Lantern test timed out"); quit(2))
	var world: Node3D = load("res://scenes/gameplay/gameplay_world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var lantern: Node3D = world.get_node_or_null("Camera/PlayerLantern")
	check(lantern != null, "The player's lantern travels with the shared camera")
	if lantern:
		var light: SpotLight3D = lantern.get_node("Light")
		var spill: OmniLight3D = lantern.get_node("Spill")
		check(light.shadow_enabled and light.spot_angle <= 30.0, "Stronger forward beam casts shadows and stays focused")
		check(light.shadow_caster_mask == 1, "Room geometry casts shadows without flat sprite self-shadow artifacts")
		check(spill.omni_range <= 9.0 and spill.light_energy < light.light_energy * 0.25, "Gentle wall spill stays local instead of flooding the room")
		lantern.flicker_amount = 0.0
		check((light.light_cull_mask & 3) == 3, "Lantern lights scenery and monsters together")
		check(lantern.position.y < 0 and light.light_color.r > light.light_color.b, "Lantern is carried below the view with a restrained warm color")
		var full: float = light.light_energy
		lantern.power = 0.25
		check(is_equal_approx(light.light_energy, full * 0.25), "Power can dim the lantern for a future fuel controller")
		lantern.power = 0.0
		lantern.advance_flicker(1.0)
		check(not light.visible and is_zero_approx(light.light_energy), "No power fully extinguishes the lantern, including flicker")
		check(not spill.visible and is_zero_approx(spill.light_energy), "No power extinguishes the nearby wall spill too")
		lantern.power = 1.0
		check(light.visible and is_equal_approx(light.light_energy, full), "Restoring power relights the lantern")
		lantern.power = 2.0
		check(is_equal_approx(lantern.power, 1.0), "Power stays in its normalized range")
		var original: Transform3D = lantern.global_transform
		world.advance_camera(0.4)
		check(not lantern.global_transform.is_equal_approx(original), "Walking carries the light through the room")
		check(lantern.transform.is_equal_approx(Transform3D(Basis.IDENTITY, Vector3(0.65, -0.7, -0.3))), "Walking preserves the lantern's hand-relative position")
		var id: int = lantern.get_instance_id()
		lantern.power = 0.4
		world.set_room(load("res://scenes/gameplay/rooms/cursed/cursed_room.tscn"))
		check(world.lantern.get_instance_id() == id and is_equal_approx(lantern.power, 0.4), "Room swaps reuse the lantern and retain its power")
		lantern.flicker_amount = 0.025
		lantern.advance_flicker(0.5)
		check(absf(light.light_energy - lantern.intensity * lantern.power) <= lantern.intensity * lantern.power * 0.04, "Flicker stays subtle instead of obscuring enemies")
	world.queue_free()
	await process_frame
	print("PLAYER LANTERN RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
