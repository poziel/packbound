extends SceneTree
## One-time conversion. Refuses to overwrite a basement with saved geometry.

func _initialize() -> void:
	_bake.call_deferred()

func _bake() -> void:
	var destination: String = "res://scenes/gameplay/rooms/basement/basement_entrance.tscn"
	var existing: PackedScene = load(destination)
	if existing.get_state().get_node_count() > 1:
		printerr("Basement already contains editable nodes; refusing to overwrite manual work.")
		quit(1)
		return
	var original: Node3D = existing.instantiate()
	var basement := Node3D.new()
	basement.name = original.name
	basement.transform = original.transform
	original.free()
	basement.set_script(load("res://tests/authoring/basement_geometry_builder.gd"))
	root.add_child(basement)
	basement.build_geometry()
	basement.set_script(load("res://tests/authoring/basement_ambient_legacy.gd"))
	for child in basement.find_children("*", "", true, false):
		child.owner = basement
	var scene := PackedScene.new()
	var error: Error = scene.pack(basement)
	if error == OK:
		error = ResourceSaver.save(scene, "res://tests/output/dungeon/basement-editable.tscn")
	print("Editable basement bake: ", error_string(error), "; nodes: ", scene.get_state().get_node_count())
	basement.queue_free()
	await process_frame
	quit(0 if error == OK else 1)
