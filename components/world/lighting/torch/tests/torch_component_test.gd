extends "res://tests/support/test_case.gd"


func _initialize() -> void:
	if not require_isolation():
		return
	_run.call_deferred()


func _run() -> void:
	var path: String = "res://components/world/lighting/torch/torch.tscn"
	check(ResourceLoader.exists(path), "Reusable torch scene is available to instance")
	if not ResourceLoader.exists(path):
		report("TORCH RESULT")
		quit(1)
		return
	var scene: PackedScene = load(path)
	var first: Node3D = scene.instantiate()
	var second: Node3D = scene.instantiate()
	root.add_child(first)
	root.add_child(second)
	await process_frame
	first.set_process(false)
	second.set_process(false)
	check(first.get_script().is_tool(), "Torch runs in the editor as well as the game")
	first.handle_length = 1.8
	first.handle_color = Color("3b594a")
	first.flame_color = Color("6abbff")
	first.light_color = Color("84caff")
	first.light_energy = 2.2
	check(is_equal_approx(first.get_node("Handle").mesh.size.y, 1.8) and is_equal_approx(first.get_node("Flame").position.y, 1.8), "Length adjustment keeps flame attached to the handle")
	check(first.get_node("Handle").material_override.albedo_color == Color("3b594a"), "Handle color updates from the Inspector parameter")
	check(first.get_node("Flame/Outer").material_override.albedo_color == Color("6abbff"), "Flame color updates without a texture")
	check(first.get_node("Flame/Light").light_color == Color("84caff"), "Integrated light has its own color parameter")
	check(not is_equal_approx(second.handle_length, first.handle_length) and second.get_node("Handle").material_override.albedo_color != first.handle_color, "Duplicated torches keep independent geometry and colors")
	var rest_scale: Vector3 = first.get_node("Flame").scale
	first.advance_flame(0.4)
	check(not first.get_node("Flame").scale.is_equal_approx(rest_scale), "Flame animation runs without rebuilding its nodes")
	check(first.get_node("Flame/Light").light_energy > 2.0 and first.get_node("Flame/Light").light_energy < 2.4, "Flicker respects configured light power")
	first.position = Vector3(4, 2, -3)
	check(first.get_node("Flame/Light").global_position.distance_to(first.global_position) < 3.0, "Moving the fixture moves its flame and light together")
	var packed := PackedScene.new()
	check(packed.pack(first) == OK, "Torch with custom parameters can be saved")
	var reopened: Node3D = packed.instantiate()
	root.add_child(reopened)
	await process_frame
	check(is_equal_approx(reopened.handle_length, 1.8) and reopened.flame_color == Color("6abbff"), "Reopening preserves per-instance parameters")
	check(is_equal_approx(reopened.get_node("Handle").mesh.size.y, 1.8), "Reopened geometry reflects saved parameters")
	var duplicated: Node3D = first.duplicate()
	root.add_child(duplicated)
	await process_frame
	duplicated.handle_color = Color("8c3838")
	duplicated.handle_length = 0.6
	check(first.get_node("Handle").material_override.albedo_color == Color("3b594a"), "Duplicating and recoloring a fixture preserves the original material")
	check(is_equal_approx(first.get_node("Handle").mesh.size.y, 1.8), "Duplicated fixture dimensions do not alter the original")
	first.queue_free()
	second.queue_free()
	reopened.queue_free()
	duplicated.queue_free()
	await process_frame
	report("TORCH RESULT")
	quit(1 if failures else 0)
