extends RefCounted
## Shared fire treatment: editable emissive source, animated runtime replacement.

static func attach(source: MeshInstance3D, parent: Node3D, size_scale: float = 1.0) -> Dictionary:
	var source_material: StandardMaterial3D = source.material_override
	var anchor := Node3D.new()
	anchor.name = "TorchFire"
	parent.add_child(anchor, true)
	var tongues: Array[MeshInstance3D] = []
	for column in range(5):
		var color: Color = [Color("d87532"), Color("e9a543"), Color("ffe4a1"), Color("f5c264"), Color("d87532")][column]
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 1.0
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.emission_enabled = true
		material.emission = color
		material.next_pass = source_material.next_pass
		var height: float = 0.28 + (0.22 if column == 2 else 0.1 if column % 2 else 0.0)
		var tongue := MeshInstance3D.new()
		tongue.name = "FlameTongue"
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.065, height, 0.10)
		tongue.mesh = mesh
		tongue.material_override = material
		tongue.position = Vector3((column - 2) * 0.055, height * 0.5 - 0.16, 0)
		anchor.add_child(tongue, true)
		tongues.append(tongue)
	var entry: Dictionary = {"source": source, "anchor": anchor, "tongues": tongues, "size_scale": size_scale}
	_sync_transform(entry)
	source.hide()
	return entry

static func _sync_transform(entry: Dictionary) -> void:
	entry["anchor"].global_transform = entry["source"].global_transform
	entry["anchor"].scale *= Vector3.ONE * float(entry["size_scale"])

static func animate(entry: Dictionary, tick: float, phase: int) -> void:
	_sync_transform(entry)
	for column in range(entry["tongues"].size()):
		var tongue: MeshInstance3D = entry["tongues"][column]
		tongue.material_override.next_pass = entry["source"].material_override.next_pass
		tongue.scale.y = 0.82 + 0.3 * absf(sin(tick * 1.73 + column * 2.3 + phase))
		tongue.position.x = (column - 2) * 0.055 + sin(tick * 0.83 + column) * 0.018
