extends SceneTree
## Explicit migration preserving the saved room and stand transforms.

func _initialize() -> void:
	_convert.call_deferred()

func _convert() -> void:
	var basement: Node3D = load("res://scenes/gameplay/rooms/basement/basement_entrance.tscn").instantiate()
	basement.set_script(null)
	var candle_scene: PackedScene = load("res://components/torch/candle.tscn")
	for stand_name: String in ["CandelabraLeft", "CandelabraRight"]:
		var stand: Node3D = basement.get_node(stand_name)
		var light: OmniLight3D = stand.get_node_or_null("Candlelight")
		if light == null:
			printerr("Candle stands already converted; refusing to overwrite edits.")
			basement.free()
			quit(1)
			return
		for index in range(5):
			var suffix: String = "" if index == 0 else str(index + 1)
			var old: MeshInstance3D = stand.get_node("Candle" + suffix)
			var source: MeshInstance3D = stand.get_node("CandleFlame" + suffix)
			var fixture: Node3D = candle_scene.instantiate()
			fixture.name = old.name
			fixture.transform = old.transform
			fixture.handle_length = old.mesh.size.y
			fixture.handle_width = old.mesh.size.x
			fixture.position -= fixture.basis.y * fixture.handle_length * 0.5
			fixture.handle_color = old.material_override.albedo_color
			fixture.depth_shadow_material = source.material_override.next_pass
			fixture.light_enabled = index == 2
			fixture.light_color = light.light_color
			fixture.light_energy = light.light_energy
			fixture.light_range = light.omni_range
			if index == 2:
				fixture.light_offset = fixture.transform.affine_inverse() * light.position - Vector3(0, fixture.handle_length, 0)
			old.free()
			source.free()
			stand.add_child(fixture)
			fixture.owner = basement
		light.free()
	var scene := PackedScene.new()
	var error: Error = scene.pack(basement)
	if error == OK:
		error = ResourceSaver.save(scene, "res://tests/output/dungeon/basement-torch-instances.tscn")
	print("Basement candle conversion: ", error_string(error))
	basement.free()
	quit(0 if error == OK else 1)
