extends SceneTree
## Explicit authoring migration. Produces review candidates, never overwrites rooms.

func _initialize() -> void:
	_migrate.call_deferred()

func own(node: Node, root_node: Node) -> void:
	for child: Node in node.get_children():
		child.owner = root_node
		own(child, root_node)

func save_scene(node: Node, path: String) -> void:
	own(node, node)
	var scene := PackedScene.new()
	assert(scene.pack(node) == OK)
	assert(ResourceSaver.save(scene, path) == OK)

func move_art(node: Node3D, art: Node3D, inverse: Transform3D) -> void:
	var saved: Transform3D = node.transform
	node.owner = null
	node.get_parent().remove_child(node)
	art.add_child(node)
	node.transform = inverse * saved

func _migrate() -> void:
	DirAccess.make_dir_recursive_absolute("res://tests/output/stairs")
	for kind: String in ["dungeon", "basement"]:
		var path: String = "res://scenes/gameplay/rooms/%s/%s.tscn" % [kind, "dungeon_room" if kind == "dungeon" else "basement_entrance"]
		var room: Node3D = load(path).instantiate()
		if room.has_node("ExitStairs"):
			printerr("Already migrated: " + path)
			quit(1)
			return
		var art := Node3D.new()
		art.name = "RoomStairArtwork"
		var exit_origin := Vector3(-6.4, 0, -8)
		var inverse := Transform3D(Basis.IDENTITY, exit_origin).affine_inverse()
		var names: Array = ["DescendingStairs", "StairwellWest", "StairwellEast", "LowerLanding", "LowerPassage", "@MeshInstance3D@516", "@MeshInstance3D@517", "@OmniLight3D@518"] if kind == "dungeon" else []
		for child: Node in room.get_children().duplicate():
			var selected: bool = str(child.name) in names
			if kind == "basement":
				selected = str(child.name).begins_with("DownwardTread") or str(child.name).begins_with("StepEdge") or str(child.name).begins_with("StonePassage") or str(child.name) in ["StoneThreshold", "PassageCeiling", "UnknownDarkness", "ThresholdLight"]
			if selected and child is Node3D:
				move_art(child, art, inverse)
		if kind == "dungeon":
			var details: Node3D = room.get_node("CorridorDetails")
			var details_transform: Transform3D = details.transform
			for child: Node in details.get_children().duplicate():
				if str(child.name).begins_with("StairwellBrick"):
					var before: Transform3D = child.transform
					child.owner = null
					details.remove_child(child)
					art.add_child(child)
					child.transform = inverse * details_transform * before
		save_scene(art, "res://tests/output/stairs/%s_exit_visuals.tscn" % kind)
		art.free()
		if OS.get_cmdline_user_args().has("--extract-only"):
			room.free()
			continue
		var entry_position: Vector3 = room.get_node("CameraStart").position + Vector3(0, -3, 2.8)
		var old_entry: Node3D = room.get_node_or_null("EntryStairs")
		if old_entry:
			entry_position = old_entry.position
			old_entry.free()
		for role: String in ["entrance", "exit"]:
			var rig_path: String = "res://components/staircase/staircase.tscn"
			if kind == "dungeon":
				rig_path = "res://scenes/gameplay/rooms/dungeon/shared/staircase.tscn"
			var rig: Node3D = load(rig_path).instantiate()
			rig.role = 0 if role == "entrance" else 1
			if kind != "dungeon" and (role == "exit" or kind == "basement"):
				rig.get_node("Visuals/DefaultStone").hide()
				var art_path: String = "res://scenes/gameplay/rooms/%s/stairs/%s_visuals.tscn" % [kind, role]
				var design: Node3D = load(art_path).instantiate()
				design.name = "RoomDesign"
				rig.get_node("Visuals").add_child(design)
				design.owner = rig
			rig.name = "EntryStairs" if role == "entrance" else "ExitStairs"
			rig.position = entry_position if role == "entrance" else exit_origin
			room.add_child(rig)
			rig.owner = room
		# Preserve ownership of existing nested scene instances.
		var packed := PackedScene.new()
		assert(packed.pack(room) == OK)
		assert(ResourceSaver.save(packed, "res://tests/output/stairs/%s_room.tscn" % kind) == OK)
		room.free()
	quit()
