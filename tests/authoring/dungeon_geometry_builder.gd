extends Node3D
## Native perspective dungeon; the camera itself travels down the staircase.

const STAIR_X: float = -6.4
const STAIR_START: float = -8.0
const STEP_DEPTH: float = 0.85
const STEP_DROP: float = 0.28
const STEP_COUNT: int = 14
const STAIR_APPROACH_END: float = 0.58
@export_range(2.0, 8.0, 0.25) var arrival_distance: float = 7.0
@export_range(0.0, 0.15, 0.005) var walking_sway: float = 0.065
@export_range(0.0, 0.08, 0.005) var walking_bob: float = 0.025
@export_range(0.0, 30.0, 1.0) var arrival_look_down_degrees: float = 10.0
var camera: Camera3D
var torch_lights: Array[OmniLight3D] = []
var time: float = 0.0
var camera_home := Vector3(STAIR_X, 3.0, 8)
var camera_rotation: Vector3

func _ready() -> void:
	if has_node("Camera"):
		camera = $Camera
		camera_home = camera.position
		camera_rotation = camera.rotation
		if has_node("EntryStairs"):
			$EntryStairs.position = Vector3(camera_home.x, 0, camera_home.z + 2.8)
		for child in get_children():
			if child is OmniLight3D:
				torch_lights.append(child)
		_add_corridor_details()
		return
	_build_room()

func _build_room() -> void:
	var environment := WorldEnvironment.new()
	var sky := Environment.new()
	sky.background_mode = Environment.BG_COLOR
	sky.background_color = Color("090d15")
	sky.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	sky.ambient_light_color = Color("8997b0")
	sky.ambient_light_energy = 0.7
	environment.environment = sky
	add_child(environment)
	camera = Camera3D.new()
	camera.name = "Camera"
	# An off-axis perspective lens keeps the vanishing point in the combat bay.
	# It still renders across the window, underneath the restored character panel.
	camera.set_frustum(0.115, Vector2(0.046, 0), 0.1, 80.0)
	camera.position = camera_home
	add_child(camera)
	camera.look_at(Vector3(STAIR_X, 1.5, STAIR_START))
	camera_rotation = camera.rotation
	camera.current = true
	var stone := _material("374253")
	var mortar := _material("19212e")
	var trim := _material("515c6c")
	var floor_mat := _material("2c3747")
	var quiet := _material("202a3b")
	# A room with perpendicular walls, a real floor, and an open stairwell.
	_box("WestWall", Vector3(-14.6, 4.5, -8.5), Vector3(12.4, 9, 1), mortar)
	_box("EastWall", Vector3(6.8, 4.5, -8.5), Vector3(22.4, 9, 1), quiet)
	_box("AboveStairs", Vector3(STAIR_X, 7.5, -8.5), Vector3(4, 3, 1), mortar)
	_box("WestSideWall", Vector3(-11.2, 4.5, 3.5), Vector3(0.6, 9, 24), mortar)
	_box("EastSideWall", Vector3(-1.6, 4.5, 3.5), Vector3(0.6, 9, 24), quiet)
	_box("Floor", Vector3(0, -0.25, 4.5), Vector3(44, 0.5, 25), floor_mat)
	_box("Ceiling", Vector3(-6.4, 7.4, 3.5), Vector3(10, 0.5, 25), mortar)
	for row in range(12):
		for column in range(22):
			var x: float = -20.0 + column * 0.8 + (0.4 if row % 2 else 0.0)
			var y: float = 0.35 + row * 0.68
			if x > STAIR_X - 2.5 and x < STAIR_X + 2.5 and y < 6.5:
				continue
			var brick := _material(Color("374253").lightened(float((row * 7 + column * 3) % 5) * 0.015))
			_box("BackWallStone", Vector3(x, y, -7.95), Vector3(0.75, 0.62, 0.14), brick)
	# Side-wall courses and receding floor joints make depth legible at rest.
	for row in range(11):
		for column in range(17):
			_box("SideStone", Vector3(-10.86, row * 0.75 + 0.38, -7.6 + column * 1.35 + (0.65 if row % 2 else 0)), Vector3(0.16, 0.69, 1.27), stone)
	for row in range(11):
		for column in range(8):
			_box("Flagstone", Vector3(-14 + column * 1.95 + (0.975 if row % 2 else 0), 0.015, -7 + row * 2.1), Vector3(1.89, 0.03, 2.02), floor_mat)
	for x: float in [-10.3, -2.5]:
		_box("PillarBase", Vector3(x, 0.2, -7.2), Vector3(1, 0.4, 1.1), trim)
		for row in range(10):
			_box("Pillar", Vector3(x, row * 0.8 + 0.8, -7.6), Vector3(0.7, 0.74, 0.8), trim if row % 3 == 0 else stone)
	for side: float in [-1.0, 1.0]:
		for row in range(7):
			_box("StairJamb", Vector3(STAIR_X + side * 2.3, row * 0.8 + 0.4, -7.5), Vector3(0.6, 0.74, 1.1), trim)
		for step in range(3):
			_box("SteppedArch", Vector3(STAIR_X + side * (1.95 - step * 0.65), 5.65 + step * 0.4, -7.5), Vector3(0.8, 0.65, 1.1), trim)
	_box("Keystone", Vector3(STAIR_X, 6.65, -7.5), Vector3(0.7, 0.7, 1.2), trim)
	var stairs := Node3D.new()
	stairs.name = "DescendingStairs"
	add_child(stairs)
	for step in range(STEP_COUNT):
		var top: float = -(step + 1) * STEP_DROP
		var z: float = STAIR_START - (step + 0.5) * STEP_DEPTH
		_box("Tread%02d" % step, Vector3(STAIR_X, top - 0.18, z), Vector3(4, 0.36, STEP_DEPTH), stone if step % 2 == 0 else _material("414c5d"), stairs)
		_box("Nosing%02d" % step, Vector3(STAIR_X, top + 0.015, z + STEP_DEPTH * 0.5 - 0.06), Vector3(4, 0.03, 0.12), trim, stairs)
	_box("StairwellWest", Vector3(STAIR_X - 2.3, 1.0, -14.5), Vector3(0.6, 12, 13), mortar)
	_box("StairwellEast", Vector3(STAIR_X + 2.3, 1.0, -14.5), Vector3(0.6, 12, 13), mortar)
	_box("LowerLanding", Vector3(STAIR_X, -4.15, -22), Vector3(4, 0.5, 4), floor_mat)
	_box("LowerPassage", Vector3(STAIR_X, 0, -24), Vector3(4, 9, 0.4), _material("0b101a"))
	for x: float in [STAIR_X - 3.4, STAIR_X + 3.4]:
		_torch(Vector3(x, 3.6, -6.8))
	_torch(Vector3(STAIR_X - 1.8, 0.4, -14.0))
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

func advance_camera(progress: float, look_down_radians: float = 0.55) -> void:
	# Move at eye height into the opening, then follow the stair slope downward.
	var approach: float = clampf(progress / STAIR_APPROACH_END, 0.0, 1.0)
	var descent: float = clampf((progress - STAIR_APPROACH_END) / (1.0 - STAIR_APPROACH_END), 0.0, 1.0)
	camera.position = camera_home.lerp(Vector3(STAIR_X, 3.0, STAIR_START + 0.8), approach)
	camera.position += Vector3(0, -3.35 * descent, -10.2 * descent)
	camera.rotation = camera_rotation + Vector3(-look_down_radians * smoothstep(0.48, 0.78, progress), 0, 0)
	_apply_walking_sway(progress, 2.5)

func arrive_camera(progress: float) -> void:
	# Enter from the upper landing, descend the separate rear staircase, then
	# take the final steps into the encounter. These stairs are scenery only.
	var descent: float = clampf(progress / 0.72, 0.0, 1.0)
	var approach: float = clampf((progress - 0.72) / 0.28, 0.0, 1.0)
	camera.position = camera_home + Vector3(0, 3.12 * (1.0 - descent), 2.8 + 7.7 * (1.0 - descent))
	camera.position.z -= 2.8 * approach
	camera.rotation = camera_rotation + Vector3(-deg_to_rad(arrival_look_down_degrees) * (1.0 - smoothstep(0.45, 0.82, progress)), 0, 0)
	_apply_walking_sway(progress, 2.5)

func _apply_walking_sway(progress: float, strides: float) -> void:
	var envelope: float = smoothstep(0.0, 0.12, progress) * (1.0 - smoothstep(0.88, 1.0, progress))
	var side: float = sin(progress * TAU * strides) * envelope
	camera.position.x += side * walking_sway
	camera.position.y -= absf(sin(progress * TAU * strides)) * walking_bob * envelope
	# A tiny heading change accompanies the weight shift without tilting the HUD.
	camera.rotation.y += side * walking_sway * 0.045

func reset_camera() -> void:
	camera.position = camera_home
	camera.rotation = camera_rotation

func reset_room() -> void:
	reset_camera()
