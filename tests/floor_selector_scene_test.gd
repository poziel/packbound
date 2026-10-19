extends "res://tests/prototype_test.gd"

func _run() -> void:
	for biome: String in ["dungeon", "cursed"]:
		var path: String = "res://scenes/gameplay/rooms/%s/floor_selector.tscn" % biome
		check(ResourceLoader.exists(path), "Selector exists for " + biome)
		if not ResourceLoader.exists(path):
			continue
		var scene: Node3D = load(path).instantiate()
		root.add_child(scene)
		check(scene.has_node("Ceiling"), "Selector has a physical stone ceiling")
		for count in range(1, 5):
			var choices: Array[Dictionary] = []
			for index in range(count):
				choices.append({"id": str(index), "kind": ["combat", "relic", "rest", "encounter"][index]})
			scene.configure(choices)
			check(scene.visible_doors().size() == count, "Physical doors match eligible destinations")
			for door: Node3D in scene.visible_doors():
				check(not door.get_node("Sign").text.is_empty() and door.has_node("Plaque"), "Destination label is mounted on a physical plaque")
			check(scene.select_exit(str(count - 1)), "Selected door supplies travel markers")
		check(scene.enemy_slots().is_empty(), "Selector has no enemy")
		for point: String in ["ArrivalStart", "ArrivalLanding", "ExitApproach", "ExitEnd"]:
			check(scene.travel_marker(point) != null, "Selector provides " + point)
		scene.queue_free()
	for kind: String in ["rest", "relic", "encounter"]:
		var path: String = "res://scenes/gameplay/rooms/%s/%s_room.tscn" % [kind, kind]
		check(ResourceLoader.exists(path), "Activity scene exists: " + kind)
		if ResourceLoader.exists(path):
			var scene: Node3D = load(path).instantiate()
			check(scene.enemy_slots().is_empty(), "Activity does not spawn enemies")
			scene.free()
	print("SELECTOR SCENES: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
