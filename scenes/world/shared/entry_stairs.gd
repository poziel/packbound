@tool
extends Node3D
## Upper-floor arrival stairs. Decorative, with no navigation/backtracking input.

func _ready() -> void:
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color("384353")
	stone.roughness = 1.0
	var edge := StandardMaterial3D.new()
	edge.albedo_color = Color("515b69")
	edge.roughness = 1.0
	for step in range(13):
		var top: float = (step + 1) * 0.24
		var z: float = (step + 0.5) * 0.55
		_box("Tread%02d" % step, Vector3(0, top - 0.2, z), Vector3(4, 0.4, 0.55), stone)
		_box("Nosing%02d" % step, Vector3(0, top + 0.02, z - 0.225), Vector3(4, 0.04, 0.10), edge)
	for side: float in [-1.0, 1.0]:
		_box("StairWall", Vector3(side * 2.175, 4, 3.9), Vector3(0.35, 8, 8.1), stone)
	_box("UpperLanding", Vector3(0, 2.92, 7.85), Vector3(4, 0.4, 1.5), stone)

func _box(label: String, at: Vector3, size: Vector3, material: Material) -> void:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = material
	node.position = at
	add_child(node, true)
