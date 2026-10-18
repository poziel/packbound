extends SceneTree
## Legacy geometry constructor; writes a separate review candidate.
## Do not run over manual scene edits without preserving them first.

func _initialize() -> void:
	_bake.call_deferred()

func _bake() -> void:
	var room: Node3D
	if OS.get_cmdline_user_args().has("--preserve-existing"):
		room = load("res://scenes/gameplay/rooms/dungeon/dungeon_room.tscn").instantiate()
		var details: Node = room.get_node_or_null("CorridorDetails")
		if details:
			details.free()
	else:
		room = Node3D.new()
		room.name = "Room"
		room.set_script(load("res://tests/authoring/dungeon_geometry_builder.gd"))
	root.add_child(room)
	await process_frame
	for child in room.find_children("*", "", true, false):
		child.owner = room
	var scene := PackedScene.new()
	var error: Error = scene.pack(room)
	if error == OK:
		error = ResourceSaver.save(scene, "res://tests/output/dungeon/geometry-builder-candidate.tscn")
	room.queue_free()
	await process_frame
	print("Room bake: ", error_string(error))
	quit(0 if error == OK else 1)
