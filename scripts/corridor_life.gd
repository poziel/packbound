extends Node3D
## Decorative animation only. Reads saved torch transforms without rebuilding the room.

const PixelFlame = preload("res://scripts/pixel_flame.gd")

@export var spider_interval_min: float = 9.0
@export var spider_interval_max: float = 22.0
@export var mouse_interval_min: float = 13.0
@export var mouse_interval_max: float = 30.0
@export var cobweb_corner := Vector3(-10.75, 7.04, -7.15)
@export var flame_fps: float = 10.0
@export var dust_amount: int = 48
@export_range(0.0, 1.0) var dust_opacity: float = 0.23
@export_range(0.0, 0.1) var haze_opacity: float = 0.025
var elapsed: float = 0.0
var spider: Node3D
var mouse: Node3D
var mouse_feet: Array[Node3D] = []
var mouse_head: Node3D
var mouse_tail: Node3D
var critters: Dictionary = {}
var last_spawn_time: float = -100.0
var web: Node3D
var legs: Array[Node3D] = []
var flames: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	_build_flames()
	_build_web()
	_build_spider()
	_build_mouse()
	_setup_critters()
	_build_dust()

func _material(color: Color, unshaded: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if unshaded else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	return material

func _cube(parent: Node3D, at: Vector3, dimensions: Vector3, material: Material, label: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	node.mesh = mesh
	node.material_override = material
	node.position = at
	parent.add_child(node, true)
	return node

func _line(parent: Node3D, from: Vector3, to: Vector3, width: float, material: Material) -> void:
	var node: MeshInstance3D = _cube(parent, (from + to) * 0.5, Vector3(width, width, from.distance_to(to)), material, "Thread")
	# Rays in the XY plane need a Z up-vector for the vertical thread.
	node.basis = Basis.looking_at(to - from, Vector3.FORWARD)

func _build_flames() -> void:
	for child in get_parent().find_children("*", "MeshInstance3D", true, false):
		if not child is MeshInstance3D or not child.material_override is StandardMaterial3D:
			continue
		var source_material: StandardMaterial3D = child.material_override
		if not source_material.emission_enabled:
			continue
		var ancestor: Node = child.get_parent()
		var fixture: bool = false
		while ancestor != get_parent():
			if bool(ancestor.get_meta("torch_fixture", false)):
				fixture = true
				break
			ancestor = ancestor.get_parent()
		if fixture:
			continue
		flames.append(PixelFlame.attach(child, self))

func _build_web() -> void:
	web = Node3D.new()
	web.name = "CornerCobweb"
	web.position = cobweb_corner
	add_child(web)
	var silk := _material(Color(0.52, 0.55, 0.57, 0.48))
	for ray in range(7):
		var angle: float = ray * PI / 12.0
		_line(web, Vector3.ZERO, Vector3(cos(angle), -sin(angle), 0) * 1.5, 0.035, silk)
	for ring in range(1, 6):
		var radius: float = ring * 0.29
		for arc in range(6):
			var a: float = arc * PI / 12.0
			var b: float = (arc + 1) * PI / 12.0
			var from := Vector3(cos(a), -sin(a), 0) * radius
			var to := Vector3(cos(b), -sin(b), 0) * radius
			var middle: Vector3 = (from + to) * 0.47
			_line(web, from, middle, 0.028, silk)
			_line(web, middle, to, 0.028, silk)

func _build_spider() -> void:
	spider = Node3D.new()
	spider.name = "WallSpider"
	spider.scale = Vector3.ONE * 0.42
	add_child(spider)
	var shell := _material(Color("15151b"))
	var edge := _material(Color("34313b"))
	_cube(spider, Vector3(0, 0.08, 0.05), Vector3(0.17, 0.13, 0.23), shell, "Abdomen")
	_cube(spider, Vector3(0, 0.07, -0.12), Vector3(0.12, 0.1, 0.12), edge, "Head")
	for side: float in [-1.0, 1.0]:
		for index in range(4):
			var leg := Node3D.new()
			leg.position = Vector3(side * 0.05, 0.07, -0.12 + index * 0.085)
			spider.add_child(leg, true)
			var knee := Vector3(side * 0.19, 0.04, (index - 1.5) * 0.07)
			var toe := Vector3(side * 0.29, -0.065, (index - 1.5) * 0.12)
			_line(leg, Vector3.ZERO, knee, 0.026, edge)
			_line(leg, knee, toe, 0.026, shell)
			legs.append(leg)
	spider.hide()

func _build_mouse() -> void:
	mouse = Node3D.new()
	mouse.name = "FloorMouse"
	mouse.scale = Vector3.ONE * 0.75
	add_child(mouse)
	var fur := _material(Color("6d6258"))
	var shade := _material(Color("4c4542"))
	var skin := _material(Color("9b7b75"))
	_cube(mouse, Vector3(0, 0.13, 0.07), Vector3(0.24, 0.22, 0.38), fur, "Body")
	_cube(mouse, Vector3(0, 0.12, 0.22), Vector3(0.19, 0.17, 0.15), shade, "Haunches")
	mouse_head = Node3D.new()
	mouse_head.name = "Head"
	mouse_head.position = Vector3(0, 0.15, -0.17)
	mouse.add_child(mouse_head)
	_cube(mouse_head, Vector3.ZERO, Vector3(0.17, 0.14, 0.18), fur, "Face")
	_cube(mouse_head, Vector3(0, -0.025, -0.11), Vector3(0.09, 0.07, 0.1), shade, "Muzzle")
	_cube(mouse_head, Vector3(0, -0.015, -0.165), Vector3(0.035, 0.035, 0.025), skin, "Nose")
	for side: float in [-1.0, 1.0]:
		_cube(mouse_head, Vector3(side * 0.09, 0.10, 0.025), Vector3(0.10, 0.13, 0.045), fur, "Ear")
		_cube(mouse_head, Vector3(side * 0.09, 0.105, -0.002), Vector3(0.065, 0.08, 0.012), skin, "InnerEar")
		_cube(mouse_head, Vector3(side * 0.087, 0.025, -0.055), Vector3(0.015, 0.022, 0.022), _material(Color("171719")), "Eye")
		for z: float in [-0.1, 0.19]:
			var foot: Node3D = _cube(mouse, Vector3(side * 0.12, 0.025, z), Vector3(0.055, 0.045, 0.10), skin, "Foot")
			mouse_feet.append(foot)
	mouse_tail = Node3D.new()
	mouse_tail.name = "Tail"
	mouse_tail.position = Vector3(0, 0.045, 0.29)
	mouse.add_child(mouse_tail)
	_line(mouse_tail, Vector3.ZERO, Vector3(0.07, -0.02, 0.18), 0.035, skin)
	_line(mouse_tail, Vector3(0.07, -0.02, 0.18), Vector3(0.01, -0.02, 0.37), 0.026, skin)
	mouse.hide()

func _critter_route(label: String, points: Array, travel: Vector2, holds: Dictionary = {}, surface: Vector3 = Vector3.UP, changes: Dictionary = {}) -> Dictionary:
	var normals: Array[Vector3] = []
	for index in range(points.size()):
		surface = changes.get(index, surface)
		normals.append(surface)
	return {"name": label, "points": points, "travel": travel, "holds": holds, "normals": normals}

func _setup_critters() -> void:
	# Each visit has its own geography, pace, stops and hiding places.
	# The web sits on the back corner; ceiling endpoints hide behind stone ribs.
	var wall_routes: Array = [
		_critter_route("web_to_ceiling", [
			Vector3(-10.35, 4.9, -7.48), Vector3(-9.9, 6.25, -7.12),
			Vector3(-10.15, 6.7, -7.12), Vector3(-9.65, 6.8, -7.12),
			Vector3(-9.5, 6.82, -6.55), Vector3(-9.3, 7.04, -6.45),
			Vector3(-8.7, 7.04, -5.7), Vector3(-7.9, 7.04, -5.3),
			Vector3(-8.1, 7.04, -4.6), Vector3(-8.8, 7.04, -4.9),
			Vector3(-8.7, 7.04, -5.7), Vector3(-7.7, 7.04, -3.35)
		], Vector2(12, 16), {2: Vector2(0.8, 2.0)}, Vector3.BACK, {4: Vector3.DOWN}),
		_critter_route("wall_peek", [
			Vector3(-10.74, 3.7, -8.3), Vector3(-10.74, 3.5, -5.5),
			Vector3(-10.74, 3.8, -8.3)
		], Vector2(1.4, 2.1), {1: Vector2(0.15, 0.5)}, Vector3.RIGHT),
		_critter_route("ceiling_crossing", [
			Vector3(-9.2, 7.04, -6.95), Vector3(-9.0, 7.04, -6.4),
			Vector3(-8.5, 7.04, -5.1), Vector3(-6.8, 7.04, -4.5),
			Vector3(-5.2, 7.04, -5.2), Vector3(-4.5, 7.04, -6.95)
		], Vector2(4.0, 6.0), {}, Vector3.DOWN),
		_critter_route("wall_inspection", [
			Vector3(-10.74, 0.7, -7.65), Vector3(-10.74, 1.1, -5.8),
			Vector3(-10.74, 2.5, -4.9), Vector3(-10.74, 2.2, -3.5),
			Vector3(-10.74, 3.4, -4.6), Vector3(-10.74, 3.8, -2.4),
			Vector3(-10.74, 4.2, 5.5)
		], Vector2(6.0, 9.0), {2: Vector2(0.3, 1.0), 4: Vector2(0.1, 0.6)}, Vector3.RIGHT),
		_critter_route("wall_to_ceiling", [
			Vector3(-10.74, 5.5, -7.65), Vector3(-10.74, 5.8, -5.5),
			Vector3(-10.74, 6.72, -5.4), Vector3(-10.58, 6.76, -5.4),
			Vector3(-9.6, 7.04, -5.4), Vector3(-8.7, 7.04, -5.0),
			Vector3(-8.1, 7.04, -4.7), Vector3(-8.7, 7.04, -4.2),
			Vector3(-8.7, 7.04, -5.0), Vector3(-8.5, 7.04, -3.35)
		], Vector2(8.0, 12.0), {1: Vector2(0.2, 0.6), 6: Vector2(0.5, 1.5)}, Vector3.RIGHT, {4: Vector3.DOWN}),
	]
	var mouse_routes: Array = [
		_critter_route("passage_wall_exploration", [
			Vector3(-7.8, -0.8, -10.0), Vector3(-8.1, 0.05, -7.6),
			Vector3(-9.6, 0.05, -5.8), Vector3(-10.35, 0.05, -2.5),
			Vector3(-10.0, 0.05, -1.2), Vector3(-9.4, 0.05, -0.5),
			Vector3(-9.8, 0.05, -2.0), Vector3(-9.0, 0.05, -6.0),
			Vector3(-8.1, 0.05, -7.6), Vector3(-7.8, -0.8, -10.0)
		], Vector2(8.5, 10.5), {3: Vector2(0.2, 0.7), 5: Vector2(0.4, 1.2)}),
		_critter_route("pillar_peek", [
			Vector3(-10.3, 0.05, -7.55), Vector3(-9.8, 0.05, -6.45),
			Vector3(-10.3, 0.05, -7.55)
		], Vector2(1.2, 1.8), {1: Vector2(0.2, 0.55)}),
		_critter_route("wall_to_pillar", [
			Vector3(-10.35, 0.05, 6.2), Vector3(-10.35, 0.05, 2.2),
			Vector3(-10.1, 0.05, 0.0), Vector3(-10.35, 0.05, -4.0),
			Vector3(-10.3, 0.05, -7.55)
		], Vector2(4.5, 6.5), {2: Vector2(0.3, 1.0)}),
		_critter_route("doorway_dash", [
			Vector3(-10.3, 0.05, -7.55), Vector3(-9.7, 0.05, -6.4),
			Vector3(-7.7, 0.05, -6.0), Vector3(-5.1, 0.05, -6.4),
			Vector3(-3.1, 0.05, -6.6), Vector3(-2.5, 0.05, -7.55)
		], Vector2(2.3, 3.3)),
		_critter_route("hesitant_passage_visit", [
			Vector3(-5.2, -0.8, -10.0), Vector3(-4.8, 0.05, -7.5),
			Vector3(-4.0, 0.05, -5.2), Vector3(-4.8, 0.05, -6.0),
			Vector3(-5.6, 0.05, -4.6), Vector3(-6.3, 0.05, -5.0),
			Vector3(-7.6, 0.05, -7.5), Vector3(-7.8, -0.8, -10.0)
		], Vector2(5.0, 7.0), {2: Vector2(0.6, 1.5), 4: Vector2(1.0, 2.0)}),
	]
	critters = {
		"spider": {"node": spider, "routes": wall_routes, "age": 0.0, "duration": 0.0, "active": false, "last_path": -1, "spawns": 0, "timeline": [], "cooldown": rng.randf_range(spider_interval_min, spider_interval_max)},
		"mouse": {"node": mouse, "routes": mouse_routes, "age": 0.0, "duration": 0.0, "active": false, "last_path": -1, "spawns": 0, "timeline": [], "cooldown": rng.randf_range(mouse_interval_min, mouse_interval_max)},
	}

func _begin_critter(kind: String, path_index: int = -1) -> void:
	var state: Dictionary = critters[kind]
	var route_count: int = state["routes"].size()
	if path_index < 0:
		path_index = rng.randi_range(0, route_count - 1)
		if path_index == state["last_path"]:
			path_index = (path_index + rng.randi_range(1, route_count - 1)) % route_count
	var route: Dictionary = state["routes"][path_index]
	var points: Array = route["points"]
	var travel: float = rng.randf_range(route["travel"].x, route["travel"].y)
	var length: float = 0.0
	for index in range(points.size() - 1):
		length += points[index].distance_to(points[index + 1])
	state["timeline"] = []
	var cursor: float = 0.0
	for index in range(points.size() - 1):
		var from: Vector3 = points[index]
		var to: Vector3 = points[index + 1]
		var seconds: float = travel * from.distance_to(to) / length
		state["timeline"].append({"start": cursor, "end": cursor + seconds, "from": from, "to": to, "normal_from": route["normals"][index], "normal_to": route["normals"][index + 1], "stopped": false})
		cursor += seconds
		if route["holds"].has(index + 1):
			var hold: Vector2 = route["holds"][index + 1]
			seconds = rng.randf_range(hold.x, hold.y)
			state["timeline"].append({"start": cursor, "end": cursor + seconds, "from": to, "to": to, "heading": to - from, "normal_from": route["normals"][index + 1], "normal_to": route["normals"][index + 1], "stopped": true})
			cursor += seconds
	state["last_path"] = path_index
	state["age"] = 0.0
	state["duration"] = cursor
	state["active"] = true
	state["spawns"] += 1
	state["node"].show()
	last_spawn_time = elapsed
	_pose_critter(kind, state, 0.0)

func _route_point(points: Array, progress: float) -> Vector3:
	# Linear segments cannot overshoot through a wall or ceiling at a corner.
	var along: float = clampf(progress, 0.0, 1.0) * (points.size() - 1)
	var segment: int = mini(floori(along), points.size() - 2)
	return points[segment].lerp(points[segment + 1], along - segment)

func _sample_critter(state: Dictionary) -> Dictionary:
	var age: float = clampf(state["age"], 0.0, state["duration"])
	for step: Dictionary in state["timeline"]:
		if age <= step["end"]:
			var t: float = clampf((age - step["start"]) / (step["end"] - step["start"]), 0.0, 1.0)
			return {"position": _route_point([step["from"], step["to"]], t), "normal": step["normal_from"].lerp(step["normal_to"], t).normalized(), "heading": step.get("heading", step["to"] - step["from"]), "stopped": step["stopped"]}
	return {}

func _pose_critter(kind: String, state: Dictionary, delta: float) -> void:
	var sample: Dictionary = _sample_critter(state)
	if sample.is_empty():
		return
	var tangent: Vector3 = sample["heading"]
	var normal: Vector3 = sample["normal"]
	var animal: Node3D = state["node"]
	animal.position = sample["position"]
	if tangent.length_squared() > 0.000001:
		var rotation: Quaternion = Basis.looking_at(tangent.normalized(), normal).get_rotation_quaternion()
		animal.quaternion = animal.quaternion.slerp(rotation, minf(delta * 9.0, 1.0)) if delta > 0.0 else rotation
	if kind == "spider":
		for index in range(legs.size()):
			legs[index].rotation.y = 0.0 if sample["stopped"] else sin(state["age"] * 23.0 + index * PI) * 0.22
	else:
		mouse_head.rotation.y = sin(state["age"] * 7.0) * (0.25 if sample["stopped"] else 0.025)
		mouse_tail.rotation.y = sin(state["age"] * 9.0) * 0.12
		for index in range(mouse_feet.size()):
			mouse_feet[index].rotation.x = 0.0 if sample["stopped"] else sin(state["age"] * 25.0 + index * PI) * 0.3

func _advance_critters(delta: float) -> void:
	for kind: String in critters:
		var state: Dictionary = critters[kind]
		if state["active"]:
			state["age"] += delta
			_pose_critter(kind, state, delta)
			if state["age"] >= state["duration"]:
				state["active"] = false
				state["node"].hide()
				state["cooldown"] = rng.randf_range(spider_interval_min, spider_interval_max) if kind == "spider" else rng.randf_range(mouse_interval_min, mouse_interval_max)
		else:
			state["cooldown"] -= delta
			if state["cooldown"] <= 0.0 and elapsed - last_spawn_time >= 2.5:
				_begin_critter(kind)

func _build_dust() -> void:
	var dust := CPUParticles3D.new()
	dust.name = "AirborneDust"
	dust.amount = dust_amount
	dust.lifetime = 12.0
	dust.preprocess = 12.0
	dust.position = Vector3(-6.4, 3.0, -1.5)
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(4.0, 2.5, 5.0)
	dust.direction = Vector3(0.5, 0.15, 0.1)
	dust.spread = 40.0
	dust.gravity = Vector3.ZERO
	dust.initial_velocity_min = 0.025
	dust.initial_velocity_max = 0.07
	dust.scale_amount_min = 0.65
	dust.scale_amount_max = 1.4
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.035, 0.035)
	var material := _material(Color(0.62, 0.61, 0.57, dust_opacity), true)
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.vertex_color_use_as_albedo = true
	mesh.material = material
	dust.mesh = mesh
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0, 0.2, 0.8, 1])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 0), Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
	dust.color_ramp = gradient
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dust)
	# Very faint, soft drifting dust clouds; no hard-edged smoke planes.
	var haze: CPUParticles3D = dust.duplicate()
	haze.name = "DustHaze"
	haze.amount = 7
	haze.mesh = mesh.duplicate()
	haze.mesh.size = Vector2(1.3, 0.7)
	var haze_material: StandardMaterial3D = material.duplicate()
	var texture := GradientTexture2D.new()
	texture.width = 32
	texture.height = 32
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1, 0.5)
	var softness := Gradient.new()
	softness.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	texture.gradient = softness
	haze_material.albedo_texture = texture
	haze_material.albedo_color.a = haze_opacity
	haze.mesh.material = haze_material
	add_child(haze)

func _process(delta: float) -> void:
	advance_ambient(delta)

func advance_ambient(delta: float) -> void:
	elapsed += delta
	var tick: float = floorf(elapsed * flame_fps)
	for index in range(flames.size()):
		var entry: Dictionary = flames[index]
		PixelFlame.animate(entry, tick, index)
	web.scale.x = 1.0 + sin(elapsed * 0.8) * 0.008
	_advance_critters(delta)
