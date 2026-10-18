extends Node3D
## Original construction source. Used only by the explicit one-time bake utility.

func build_geometry() -> void:
	var wood := _material("493528")
	var plank := _material("574032")
	var dark := _material("241d1a")
	var beam := _material("30241d")
	var stone := _material("414957")
	var trim := _material("616775")
	var worn_stone := _material("707483")
	var tread_edge := _material("777887")
	tread_edge.emission_enabled = true
	tread_edge.emission = Color("30333b")
	tread_edge.emission_energy_multiplier = 0.18
	# Wide timber boards, exposed posts and beams; no dungeon masonry in the house.
	_box("FloorUnderlay", Vector3(-6.4, -0.22, 4.3), Vector3(16, 0.4, 24.5), dark)
	for column in range(14):
		_box("Floorboard", Vector3(-13.55 + column * 1.1, 0, 4.3), Vector3(1.06, 0.06, 24.5), plank if column % 3 == 0 else wood)
	for side: float in [-1.0, 1.0]:
		for row in range(11):
			_box("TimberWall", Vector3(-6.4 + side * 6.2, 0.4 + row * 0.7, 3.3), Vector3(0.3, 0.65, 24), wood if row % 3 else plank)
		for z: float in [-7.3, -1.2, 5.0, 11.2]:
			_box("WallPost", Vector3(-6.4 + side * 5.95, 3.7, z), Vector3(0.4, 7.4, 0.4), beam)
	for row in range(11):
		for side: float in [-1.0, 1.0]:
			_box("RearBoards", Vector3(-6.4 + side * 4.3, row * 0.7 + 0.35, -8.4), Vector3(4.5, 0.65, 0.3), wood if row % 2 else plank)
	_box("ArchOverBoards", Vector3(-6.4, 7.0, -8.4), Vector3(4.1, 1.4, 0.3), wood)
	for z: float in [-7, -1, 5, 11]:
		_box("CeilingBeam", Vector3(-6.4, 7.15, z), Vector3(12.5, 0.4, 0.45), beam)
	for column in range(14):
		_box("CeilingBoard", Vector3(-13.55 + column * 1.1, 7.4, 3.3), Vector3(1.06, 0.15, 24), wood)
	# A cold, thick, open stone arch intrudes into the warm wooden wall.
	for side: float in [-1.0, 1.0]:
		for row in range(7):
			_box("StoneJamb", Vector3(-6.4 + side * 2.3, row * 0.8 + 0.4, -7.8), Vector3(0.72, 0.76, 1.0), stone if row % 2 else trim)
		for step in range(3):
			_box("StoneArch", Vector3(-6.4 + side * (1.95 - step * 0.65), 5.7 + step * 0.4, -7.8), Vector3(0.85, 0.7, 1.0), stone)
	_box("Keystone", Vector3(-6.4, 6.7, -7.8), Vector3(0.75, 0.8, 1.1), trim)
	_box("StoneThreshold", Vector3(-6.4, 0.03, -7.7), Vector3(4.2, 0.12, 1.0), stone)
	for step in range(14):
		_box("DownwardTread", Vector3(-6.4, -(step + 1) * 0.28 - 0.18, -8.0 - (step + 0.5) * 0.85), Vector3(4.0, 0.36, 0.85), stone if step % 2 else worn_stone)
		_box("StepEdge", Vector3(-6.4, -(step + 1) * 0.28 + 0.01, -8.0 - step * 0.85), Vector3(4.0, 0.03, 0.16), tread_edge)
	for side: float in [-1.0, 1.0]:
		_box("StonePassage", Vector3(-6.4 + side * 2.25, 1, -14), Vector3(0.5, 11, 12), dark)
	var passage_roof: MeshInstance3D = _box("PassageCeiling", Vector3(-6.4, 3.7, -14), Vector3(5.0, 0.4, 13.0), dark)
	passage_roof.rotation.x = -atan(0.28 / 0.85)
	_box("UnknownDarkness", Vector3(-6.4, 0, -20), Vector3(4.0, 9, 0.3), _material("020305"))
	# Storage remains peripheral, keeping the arch the visual focus.
	for at: Vector3 in [Vector3(-11.5, 0.65, -4), Vector3(-12.2, 0.5, -2.0), Vector3(-1.4, 0.6, -4.6)]:
		_box("StorageCrate", at, Vector3(1.2, at.y * 2, 1.1), wood)
		for y: float in [-0.35, 0.35]:
			_box("CrateRail", at + Vector3(0, y, 0.58), Vector3(1.25, 0.12, 0.08), beam)
	var light := OmniLight3D.new()
	light.name = "BasementWarmLight"
	light.position = Vector3(-9.5, 5, 1)
	light.light_color = Color("ffc589")
	light.light_energy = 1.0
	light.omni_range = 12
	add_child(light)
	# A little borrowed cellar light catches the first treads, then falls away.
	var stair_light := OmniLight3D.new()
	stair_light.name = "ThresholdLight"
	stair_light.position = Vector3(-6.4, 2.0, -9.2)
	stair_light.light_color = Color("9b9fb4")
	stair_light.light_energy = 0.55
	stair_light.omni_range = 6.0
	add_child(stair_light)
	_candelabra("CandelabraLeft", Vector3(-10.0, 0.03, -6.4))
	_candelabra("CandelabraRight", Vector3(-2.8, 0.03, -6.4))
	_apply_depth_shadow()

func _candelabra(label: String, at: Vector3) -> void:
	var stand := Node3D.new()
	stand.name = label
	stand.position = at
	add_child(stand)
	var metal := _material("6a4d29")
	var brass := _material("a17c42")
	var wax := _material("e4cca0")
	var flame := _material("ffad45")
	flame.albedo_color = Color(0.9019608, 0.70980394, 0.45882353, 1)
	flame.emission_enabled = true
	flame.emission = Color(1, 0.77254903, 0.49411765, 1)
	flame.emission_energy_multiplier = 1.4
	_box("Foot", Vector3(0, 0.1, 0), Vector3(1.15, 0.2, 0.8), metal, stand)
	_box("FootStep", Vector3(0, 0.27, 0), Vector3(0.72, 0.14, 0.52), brass, stand)
	_box("Stem", Vector3(0, 1.45, 0), Vector3(0.17, 2.3, 0.17), metal, stand)
	for height: float in [0.5, 1.0, 1.8, 2.3]:
		_box("StemCollar", Vector3(0, height, 0), Vector3(0.28, 0.12, 0.28), brass, stand)
	_box("CrownCrossbar", Vector3(0, 2.15, 0), Vector3(1.5, 0.14, 0.18), metal, stand)
	for index in range(5):
		var x: float = (index - 2) * 0.35
		var height: float = 2.7 - absf(index - 2) * 0.23
		_box("Branch", Vector3(x, (2.15 + height) * 0.5, 0), Vector3(0.12, height - 2.15, 0.12), metal, stand)
		_box("CandleCup", Vector3(x, height, 0), Vector3(0.28, 0.1, 0.28), brass, stand)
		_box("Candle", Vector3(x, height + 0.23, 0), Vector3(0.16, 0.36, 0.16), wax, stand)
		var outer: MeshInstance3D = _box("CandleFlame", Vector3(x, height + 0.5, 0), Vector3(0.16, 0.22, 0.12), flame, stand)
		outer.set_meta("pixel_flame", true)
		outer.set_meta("flame_scale", 0.5)
	var light := OmniLight3D.new()
	light.name = "Candlelight"
	light.position = Vector3(0, 2.9, 0.3)
	light.light_color = Color("ffb966")
	light.light_energy = 1.25
	light.omni_range = 8.0
	light.set_meta("candle_light", true)
	stand.add_child(light)

func _apply_depth_shadow() -> void:
	var shadow := ShaderMaterial.new()
	shadow.shader = preload("res://assets/shaders/basement_stair_shadow.gdshader")
	for node: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		if node.material_override is StandardMaterial3D:
			node.material_override.next_pass = shadow

func _material(color: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color)
	material.roughness = 1.0
	return material

func _box(label: String, at: Vector3, size: Vector3, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = material
	node.position = at
	var host: Node3D = parent if parent else self
	host.add_child(node, true)
	return node
