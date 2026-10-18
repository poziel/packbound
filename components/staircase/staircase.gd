@tool
extends Node3D
## Shared stair envelope and camera markers; artwork stays in saved child scenes.

const WIDTH: float = 4.0
const STEP_COUNT: int = 14
const STEP_HEIGHT: float = 0.28
const STEP_DEPTH: float = 0.85
const EYE_HEIGHT: float = 3.0
const RISE: float = STEP_COUNT * STEP_HEIGHT
const RUN: float = STEP_COUNT * STEP_DEPTH

@export_enum("Entrance", "Exit") var role: int = 1:
	set(value):
		role = value
		_refresh()
@export_range(0.0, 30.0, 1.0) var look_down_degrees: float = 10.0
@export var show_guides: bool = true:
	set(value):
		show_guides = value
		_refresh()
var width: float:
	get: return WIDTH
var rise: float:
	get: return RISE
var run_length: float:
	get: return RUN
var shadow: ShaderMaterial

func _ready() -> void:
	set_notify_transform(true)
	shadow = ShaderMaterial.new()
	shadow.shader = preload("res://components/staircase/stair_shadow.gdshader")
	for mesh: MeshInstance3D in $Visuals.find_children("*", "MeshInstance3D", true, false):
		if mesh.material_override is StandardMaterial3D:
			mesh.material_override = mesh.material_override.duplicate()
			mesh.material_override.next_pass = shadow
		elif mesh.mesh and not mesh.material_override:
			for surface: int in mesh.mesh.get_surface_count():
				var material: Material = mesh.get_active_material(surface)
				if material is StandardMaterial3D:
					material = material.duplicate()
					material.next_pass = shadow
					mesh.set_surface_override_material(surface, material)
	_refresh()

func _refresh() -> void:
	if not is_inside_tree() or not has_node("Bottom"):
		return
	var offset := Vector3(0, RISE, RUN) if role == 0 else Vector3.ZERO
	$Visuals.position = offset
	$Top.position = offset + Vector3(0, EYE_HEIGHT, 0.8)
	$Bottom.position = offset + Vector3(0, EYE_HEIGHT - RISE, -RUN)
	$Guides.position = offset
	$Guides.visible = Engine.is_editor_hint() and show_guides
	$EndWall.position = Vector3(0, RISE + EYE_HEIGHT, RUN + 1.5) if role == 0 else Vector3(0, EYE_HEIGHT - RISE, -RUN - 1.5)
	$EndWall.rotation.y = PI if role == 0 else 0.0
	_update_shadow()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		_update_shadow()

func _update_shadow() -> void:
	if shadow and is_inside_tree():
		shadow.set_shader_parameter("world_to_stairs", global_transform.affine_inverse())
		shadow.set_shader_parameter("entrance", role == 0)
		shadow.set_shader_parameter("run_length", RUN)

func shadow_amount(world_point: Vector3) -> float:
	var local: Vector3 = to_local(world_point)
	return smoothstep(0.0, RUN * 0.95, local.z if role == 0 else -local.z)

func preview_pose(progress: float) -> Transform3D:
	var pose: Transform3D = $Top.global_transform
	pose.origin = $Top.global_position.lerp($Bottom.global_position, progress)
	var tilt: float = 1.0 - smoothstep(0.45, 0.82, progress) if role == 0 else smoothstep(0.0, 0.5, progress)
	pose.basis *= Basis(Vector3.RIGHT, -deg_to_rad(look_down_degrees) * tilt)
	var envelope: float = smoothstep(0.0, 0.12, progress) * (1.0 - smoothstep(0.88, 1.0, progress))
	var stride: float = sin(progress * TAU * 2.5) * envelope
	pose.origin += pose.basis.x * stride * 0.065 - Vector3.UP * absf(stride) * 0.025
	return pose
