extends "res://scenes/world/rooms/shared/room_definition.gd"
## Native editable dungeon scenery; the shared world owns camera and actors.

const STAIR_X: float = -6.4
var torch_lights: Array[OmniLight3D] = []
var time: float = 0.0

func _ready() -> void:
	# The saved actor fill keeps its artist-set intensity instead of torch flicker.
	for child in find_children("*", "OmniLight3D", true, false):
		if child is OmniLight3D and not bool(child.get_meta("monster_fill", false)):
			torch_lights.append(child)
	_add_corridor_details()

func _add_corridor_details() -> void:
	# Extend the saved room without rebuilding existing meshes or camera settings.
	if has_node("CorridorDetails"):
		return
	var details := Node3D.new()
	details.name = "CorridorDetails"
	add_child(details)
	var masonry: Array[StandardMaterial3D] = []
	for color: String in ["354050", "3d4858", "414b5b", "333e4d", "465060"]:
		masonry.append(_material(color))
	var joint := _material("1b2330")
	var edge := _material("454e5c")
	# Contrasting slabs retain broad material shading at the user's 4x shrink.
	for child in get_children():
		if child is MeshInstance3D and child.mesh is BoxMesh and child.mesh.size.is_equal_approx(Vector3(1.89, 0.03, 2.02)):
			var at: Vector3 = child.position
			var index: int = posmod(roundi(at.x * 3.0) + roundi(at.z * 7.0), masonry.size())
			child.material_override = masonry[index]
			if index == 1 or index == 3:
				var crack: Vector3 = at + Vector3(-0.25, 0.019, -0.2)
				_box("FloorCrack", crack, Vector3(0.045, 0.008, 0.55), joint, details)
				_box("FloorCrackStep", crack + Vector3(0.1, 0, 0.3), Vector3(0.24, 0.008, 0.045), joint, details)
	# Masonry continues on the right wall, including the strip beside the menu.
	for row in range(11):
		for column in range(17):
			var z: float = -7.6 + column * 1.35 + (0.65 if row % 2 else 0)
			_box("EastWallBrick", Vector3(-1.94, row * 0.75 + 0.38, z), Vector3(0.16, 0.69, 1.27), masonry[(row + column * 3) % masonry.size()], details)
	# Large ceiling blocks and transverse ribs create visible receding depth.
	for row in range(13):
		for column in range(6):
			_box("CeilingStone", Vector3(-10.4 + column * 1.6, 7.12, -7.4 + row * 1.85), Vector3(1.53, 0.08, 1.77), masonry[(row * 3 + column) % masonry.size()], details)
	for row in range(7):
		_box("CeilingRib", Vector3(STAIR_X, 6.98, -6.8 + row * 3.7), Vector3(9.1, 0.22, 0.22), edge, details)
	for x: float in [-10.75, -2.05]:
		_box("CeilingCornice", Vector3(x, 6.95, 3.5), Vector3(0.24, 0.3, 24), edge, details)
	# The stairwell keeps the same stonework as the room above.
	for side: float in [-1.0, 1.0]:
		for column in range(9):
			for row in range(6):
				var z: float = -8.6 - column * 1.35
				var y: float = row * 0.75 - column * 0.44 + 0.35
				_box("StairwellBrick", Vector3(STAIR_X + side * 1.94, y, z), Vector3(0.12, 0.69, 1.27), masonry[(column + row * 2) % masonry.size()], details)
	_apply_depth_shadow()

func _apply_depth_shadow() -> void:
	# One continuous world-depth field shades the stone surfaces themselves.
	# There are no translucent sheets for the camera to pass through.
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled, fog_disabled;
varying vec3 world_position;
void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
    float depth = smoothstep(7.0, 19.0, -world_position.z);
    ALBEDO = vec3(0.0);
    ALPHA = depth;
}
"""
	var shadow := ShaderMaterial.new()
	shadow.shader = shader
	var materials: Array[Material] = []
	for node in find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node
		var material: Material = mesh.material_override
		if material is StandardMaterial3D and not materials.has(material):
			material.next_pass = shadow
			materials.append(material)

func _material(color: Variant) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color) if color is String else color
	material.roughness = 1.0
	return material

func _box(label: String, at: Vector3, dimensions: Vector3, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = label
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	(parent if parent else self).add_child(instance, true)
	return instance

func _torch(at: Vector3) -> void:
	_box("Sconce", at, Vector3(0.18, 0.75, 0.3), _material("24232a"))
	var flame := _material("e6b575")
	flame.emission_enabled = true
	flame.emission = Color("ffc57e")
	flame.emission_energy_multiplier = 1.4
	_box("Flame", at + Vector3(0, 0.5, 0), Vector3(0.14, 0.35, 0.14), flame)
	var light := OmniLight3D.new()
	light.position = at + Vector3(0, 0.5, 0.9)
	light.light_color = Color("ffca8d")
	light.light_energy = 1.2
	light.omni_range = 7.0
	add_child(light)
	torch_lights.append(light)

func _process(delta: float) -> void:
	time += delta
	for index in range(torch_lights.size()):
		torch_lights[index].light_energy = 1.15 + sin(time * 3.1 + index * 2.0) * 0.06
