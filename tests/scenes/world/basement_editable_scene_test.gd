extends "res://tests/support/test_case.gd"


func _initialize() -> void:
	if not require_isolation():
		return
	_run.call_deferred()


func _run() -> void:
	var packed: PackedScene = load("res://scenes/world/biomes/basement/rooms/basement_entrance/basement_entrance.tscn")
	check(packed.get_state().get_node_count() > 100, "Basement geometry is saved in the scene rather than generated on opening")
	var basement: Node3D = packed.instantiate()
	var saved_mesh: Node3D = basement.get_node_or_null("Floorboard")
	check(saved_mesh != null, "Editor can select the saved floor before any script runs")
	if saved_mesh == null:
		basement.free()
		report("BASEMENT EDITABLE RESULT")
		quit(1)
		return
	var edited_position: Vector3 = saved_mesh.position + Vector3(0.25, 0.1, 0.5)
	saved_mesh.position = edited_position
	var candle: Node3D = basement.get_node("CandelabraLeft/Candle3")
	candle.light_energy = 0.7
	candle.position += Vector3(0.15, 0.2, 0.1)
	var light: OmniLight3D = candle.get_node("Flame/Light")
	var flame: Node3D = candle.get_node("Flame")
	root.add_child(basement)
	await process_frame
	check(saved_mesh.position.is_equal_approx(edited_position), "Opening the scene preserves an editor-moved mesh")
	check(saved_mesh.owner == basement and candle.owner == basement and light.owner == candle, "Room meshes and reusable candle instances have saved ownership")
	check(basement.find_children("Floorboard*", "MeshInstance3D", true, false).size() == 14, "Ready does not duplicate saved geometry")
	var fixtures: Array = basement.find_children("*", "Node3D", true, false).filter(func(node: Node) -> bool: return bool(node.get_meta("torch_fixture", false)))
	check(fixtures.size() == 10 and flame.visible, "Ten reusable candle fixtures show their fire directly in the scene")
	var expected: Vector3 = candle.to_global(Vector3(0, candle.handle_length, 0))
	check(flame.global_position.is_equal_approx(expected), "Flame sits at the authored candle's upper end")
	candle.position.x += 0.3
	candle.advance_flame(0.1)
	check(flame.global_position.is_equal_approx(candle.to_global(Vector3(0, candle.handle_length, 0))), "Moving the candle keeps its flame attached")
	check(light.light_energy > 0.6 and light.light_energy < 0.8, "Flicker respects the light's saved intensity")
	for fixture: Node in fixtures:
		fixture.set_process(false)
	var repacked := PackedScene.new()
	check(repacked.pack(basement) == OK, "Edited scene can be packed for saving")
	var reopened: Node3D = repacked.instantiate()
	check(reopened.get_node("Floorboard").position.is_equal_approx(edited_position), "Saving and reopening retains the moved mesh")
	root.add_child(reopened)
	await process_frame
	check(reopened.get_node("CandelabraLeft/Candle3").light_energy == 0.7, "Reopening preserves candle parameters")
	reopened.queue_free()
	basement.queue_free()
	await process_frame
	report("BASEMENT EDITABLE RESULT")
	quit(1 if failures else 0)
