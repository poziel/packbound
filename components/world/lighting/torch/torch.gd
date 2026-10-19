@tool
extends Node3D
## One movable fixture. Saved nodes, live Inspector parameters and editor animation.

@export_group("Handle")
@export_range(0.05, 5.0, 0.01) var handle_length: float = 1.0:
	set(value):
		handle_length = maxf(value, 0.05)
		_refresh()
@export_range(0.03, 1.0, 0.01) var handle_width: float = 0.16:
	set(value):
		handle_width = maxf(value, 0.03)
		_refresh()
@export var handle_color: Color = Color("5d4028"):
	set(value):
		handle_color = value
		_refresh()
@export var collar_enabled: bool = true:
	set(value):
		collar_enabled = value
		_refresh()
@export var collar_color: Color = Color("99754b"):
	set(value):
		collar_color = value
		_refresh()

@export_group("Flame")
@export var flame_color: Color = Color("ffad45"):
	set(value):
		flame_color = value
		_refresh()
@export var flame_core_color: Color = Color("fff0bb"):
	set(value):
		flame_core_color = value
		_refresh()
@export var flame_size: Vector3 = Vector3(0.25, 0.45, 0.16):
	set(value):
		flame_size = value.max(Vector3.ONE * 0.01)
		_refresh()
@export_range(1.0, 24.0, 1.0) var flame_fps: float = 9.0
@export_range(0.0, 3.0, 0.05) var animation_speed: float = 1.0
@export var animate_in_editor: bool = true
@export var depth_shadow_material: Material:
	set(value):
		depth_shadow_material = value
		_refresh()

@export_group("Light")
@export var light_enabled: bool = true:
	set(value):
		light_enabled = value
		_refresh()
@export var light_color: Color = Color("ffb966"):
	set(value):
		light_color = value
		_refresh()
@export_range(0.0, 8.0, 0.05) var light_energy: float = 1.2:
	set(value):
		light_energy = maxf(value, 0.0)
		_refresh()
@export_range(0.1, 30.0, 0.1) var light_range: float = 7.0:
	set(value):
		light_range = maxf(value, 0.1)
		_refresh()
@export var light_offset: Vector3 = Vector3(0, 0.15, 0.2):
	set(value):
		light_offset = value
		_refresh()
@export_range(0.0, 0.2, 0.01) var flicker_amount: float = 0.06
@export var shadows_enabled: bool = false:
	set(value):
		shadows_enabled = value
		_refresh()

var elapsed: float = 0.0

func _ready() -> void:
	# Node.duplicate() can retain resources even with local-to-scene enabled.
	# Give every fixture its own appearance before applying its parameters.
	for mesh: MeshInstance3D in [$Handle, $Collar, $Flame/Outer, $Flame/Tip, $Flame/Core]:
		mesh.mesh = mesh.mesh.duplicate()
		mesh.mesh.resource_local_to_scene = true
		mesh.material_override = mesh.material_override.duplicate()
		mesh.material_override.resource_local_to_scene = true
	_refresh()

func _refresh() -> void:
	if not is_inside_tree() or not has_node("Flame/Light"):
		return
	var handle: MeshInstance3D = $Handle
	handle.mesh.size = Vector3(handle_width, handle_length, handle_width)
	handle.position.y = handle_length * 0.5
	handle.material_override.albedo_color = handle_color
	handle.material_override.next_pass = depth_shadow_material
	var collar: MeshInstance3D = $Collar
	collar.visible = collar_enabled
	collar.mesh.size = Vector3(handle_width * 1.8, handle_width * 0.8, handle_width * 1.8)
	collar.position.y = handle_length - handle_width * 0.3
	collar.material_override.albedo_color = collar_color
	collar.material_override.next_pass = depth_shadow_material
	$Flame.position.y = handle_length
	$Flame.scale = Vector3.ONE
	var outer: MeshInstance3D = $Flame/Outer
	outer.mesh.size = flame_size * Vector3(1.0, 0.65, 1.0)
	outer.position.y = flame_size.y * 0.325
	var tip: MeshInstance3D = $Flame/Tip
	tip.mesh.size = flame_size * Vector3(0.52, 0.55, 0.72)
	tip.position = Vector3(0, flame_size.y * 0.725, 0)
	var core: MeshInstance3D = $Flame/Core
	core.mesh.size = flame_size * Vector3(0.46, 0.44, 1.05)
	core.position.y = flame_size.y * 0.23
	for mesh: MeshInstance3D in [outer, tip, core]:
		var color: Color = flame_core_color if mesh == core else flame_color
		mesh.material_override.albedo_color = color
		mesh.material_override.emission = color
		mesh.material_override.next_pass = depth_shadow_material
	var light: OmniLight3D = $Flame/Light
	light.visible = light_enabled
	light.position = light_offset
	light.light_color = light_color
	light.light_energy = light_energy
	light.omni_range = light_range
	light.shadow_enabled = shadows_enabled

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	if Engine.is_editor_hint() and not animate_in_editor:
		$Flame.scale = Vector3.ONE
		$Flame/Light.light_energy = light_energy
		return
	advance_flame(delta)

func advance_flame(delta: float) -> void:
	elapsed += delta * animation_speed
	var tick: float = floorf(elapsed * flame_fps)
	var phase: float = float(get_instance_id() % 97)
	var flutter: float = sin(tick * 1.9 + phase)
	$Flame.scale = Vector3(1.0 + flutter * 0.12, 1.0 + flutter * 0.18, 1.0)
	$Flame/Tip.position.x = sin(tick * 0.83 + phase) * flame_size.x * 0.08
	var light_flutter: float = sin(elapsed * 3.3 + phase) + sin(elapsed * 7.1) * 0.35
	$Flame/Light.light_energy = light_energy * (1.0 + light_flutter * flicker_amount)
