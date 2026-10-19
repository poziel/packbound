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
const MAX_GLOW_ENERGY: float = 200.0
const DEPTH_STRENGTH_MULTIPLIER: float = 2.0

@export_enum("Entrance", "Exit") var role: int = 1:
	set(value):
		role = value
		_refresh()
@export_range(0.0, 30.0, 1.0) var look_down_degrees: float = 10.0
## Editor-only box showing the stair footprint and rise. Never rendered in gameplay.
@export var show_guides: bool = true:
	set(value):
		show_guides = value
		_refresh()
var width: float:
	get: return WIDTH * absf($Visuals.scale.x) if has_node("Visuals") else WIDTH
var rise: float:
	get: return RISE
var run_length: float:
	get: return RUN
var shadow: ShaderMaterial

@export_group("Appearance")
## Material base color, applied directly without multiplying the original gray.
@export var wall_color: Color = Color(0.22, 0.26, 0.32):
	set(value):
		wall_color = value
		_apply_appearance()
@export var step_color: Color = Color(0.22, 0.26, 0.32):
	set(value):
		step_color = value
		_apply_appearance()
@export var ceiling_color: Color = Color(0.22, 0.26, 0.32):
	set(value):
		ceiling_color = value
		_apply_appearance()
@export var depth_color: Color = Color.BLACK:
	set(value):
		depth_color = value
		_apply_appearance()
@export_range(0.0, 1.0) var depth_strength: float = 1.0:
	set(value):
		depth_strength = clampf(value, 0.0, 1.0)
		_apply_appearance()
@export_group("Interior light")
## Color of the interior light. Does not alter the passage depth color.
@export var glow_color: Color = Color(0.58, 0.76, 1.0):
	set(value):
		glow_color = value
		_apply_appearance()
## Normalized intensity: zero is off, one is 200 light energy (twice the old maximum).
@export_range(0.0, 1.0) var glow_intensity: float = 0.0:
	set(value):
		glow_intensity = clampf(value, 0.0, 1.0)
		_apply_appearance()
var appearance_materials: Array[Dictionary] = []

func _ready() -> void:
	set_notify_transform(true)
	shadow = ShaderMaterial.new()
	shadow.shader = preload("res://components/world/architecture/staircase/stair_shadow.gdshader")
	for mesh: MeshInstance3D in $Visuals.find_children("*", "MeshInstance3D", true, false):
		if mesh.material_override is StandardMaterial3D:
			mesh.material_override = mesh.material_override.duplicate()
			_track_material(mesh.material_override, mesh)
			mesh.material_override.next_pass = shadow
		elif mesh.mesh and not mesh.material_override:
			for surface: int in mesh.mesh.get_surface_count():
				var material: Material = mesh.get_active_material(surface)
				if material is StandardMaterial3D:
					material = material.duplicate()
					_track_material(material, mesh)
					material.next_pass = shadow
					mesh.set_surface_override_material(surface, material)
	for mesh: MeshInstance3D in $EndWall.find_children("*", "MeshInstance3D", true, false) + [$EndWall]:
		mesh.material_override = mesh.material_override.duplicate()
	_refresh()

func _refresh() -> void:
	if not is_inside_tree() or not has_node("Bottom"):
		return
	var offset := Vector3(0, RISE, RUN) if role == 0 else Vector3.ZERO
	$Visuals.position = offset
	# Keep the light at the room-side landing rather than carrying it to the
	# dark upper end along with the entrance's raised geometry.
	if has_node("Visuals/InteriorLight"):
		var landing_light := Vector3(0, 1.8, 3.0 if role == 0 else -3.0)
		$Visuals/InteriorLight.position = landing_light - offset
	$Top.position = offset + Vector3(0, EYE_HEIGHT, 0.8)
	$Bottom.position = offset + Vector3(0, EYE_HEIGHT - RISE, -RUN)
	$Guides.position = offset
	$Guides.visible = Engine.is_editor_hint() and show_guides
	$EndWall.position = Vector3(0, RISE + EYE_HEIGHT, RUN + 1.5) if role == 0 else Vector3(0, EYE_HEIGHT - RISE, -RUN - 1.5)
	$EndWall.rotation.y = PI if role == 0 else 0.0
	_update_shadow()
	_apply_appearance()

func _track_material(material: StandardMaterial3D, mesh: MeshInstance3D) -> void:
	var surface: String = "wall"
	var mesh_name: String = str(mesh.name).to_lower()
	if "ceiling" in mesh_name or "roof" in mesh_name:
		surface = "ceiling"
	elif mesh_name.begins_with("tread") or mesh_name.begins_with("nosing") or "landing" in mesh_name:
		surface = "step"
	surface = str(mesh.get_meta("stair_surface", surface))
	appearance_materials.append({"material": material, "surface": surface})

func _apply_appearance() -> void:
	if not is_inside_tree() or not shadow or not has_node("Visuals/InteriorLight"):
		return
	for entry: Dictionary in appearance_materials:
		match entry.surface:
			"step": entry.material.albedo_color = step_color
			"ceiling": entry.material.albedo_color = ceiling_color
			_: entry.material.albedo_color = wall_color
	var color: Color = depth_color
	shadow.set_shader_parameter("depth_color", color)
	shadow.set_shader_parameter("depth_strength", depth_strength * DEPTH_STRENGTH_MULTIPLIER)
	for mesh: MeshInstance3D in $EndWall.find_children("*", "MeshInstance3D", true, false) + [$EndWall]:
		mesh.material_override.albedo_color = color
	$Visuals/InteriorLight.light_color = glow_color
	$Visuals/InteriorLight.light_energy = glow_intensity * MAX_GLOW_ENERGY

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
	return clampf(smoothstep(0.0, RUN * 0.95, local.z if role == 0 else -local.z) * depth_strength * DEPTH_STRENGTH_MULTIPLIER, 0.0, 1.0)

func preview_pose(progress: float) -> Transform3D:
	var pose: Transform3D = $Top.global_transform
	pose.origin = $Top.global_position.lerp($Bottom.global_position, progress)
	var tilt: float = 1.0 - smoothstep(0.45, 0.82, progress) if role == 0 else smoothstep(0.0, 0.5, progress)
	pose.basis *= Basis(Vector3.RIGHT, -deg_to_rad(look_down_degrees) * tilt)
	var envelope: float = smoothstep(0.0, 0.12, progress) * (1.0 - smoothstep(0.88, 1.0, progress))
	var stride: float = sin(progress * TAU * 2.5) * envelope
	pose.origin += pose.basis.x * stride * 0.065 - Vector3.UP * absf(stride) * 0.025
	return pose
