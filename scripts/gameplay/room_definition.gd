@tool
extends Node3D
## Rooms own scenery and editor-visible placement markers, never combat actors.

@export_group("Environment")
@export var environment: Environment
@export_range(1, 4, 1) var pixel_downscale: int = 3
@export_group("Camera lens")
@export var camera_size: float = 0.115
@export var camera_frustum_offset := Vector2(0.046, 0)
@export var camera_near: float = 0.1
@export var camera_far: float = 80.0
@export_group("Travel")
@export_range(0.0, 0.15, 0.005) var walking_sway: float = 0.065
@export_range(0.0, 0.08, 0.005) var walking_bob: float = 0.025
@export_range(0.0, 30.0, 1.0) var arrival_look_down_degrees: float = 10.0
@export_range(0.0, 60.0, 1.0) var departure_look_down_degrees: float = 31.51268
@export_range(0.1, 0.9, 0.01) var departure_approach_end: float = 0.58
@export_range(0.1, 0.9, 0.01) var arrival_descent_end: float = 0.72
@export_range(0.1, 10.0, 0.1) var departure_seconds: float = 2.2

@export_group("Staircases")
@export_node_path("Node3D") var entrance_stairs_path: NodePath = NodePath("EntryStairs")
@export_node_path("Node3D") var exit_stairs_path: NodePath = NodePath("ExitStairs")

func staircase(kind: String) -> Node3D:
	var node: Node = get_node_or_null(entrance_stairs_path if kind == "entrance" else exit_stairs_path)
	return node if node is Node3D and bool(node.get_meta("staircase", false)) else null

func travel_marker(point: String) -> Marker3D:
	var entrance: bool = point in ["ArrivalStart", "ArrivalLanding"]
	var stairs: Node3D = staircase("entrance" if entrance else "exit")
	if stairs:
		return stairs.get_node("Top" if point in ["ArrivalStart", "ExitApproach"] else "Bottom")
	return get_node_or_null("Travel/" + point) as Marker3D

func travel_tilt(kind: String) -> float:
	var stairs: Node3D = staircase(kind)
	if stairs:
		return stairs.look_down_degrees
	return arrival_look_down_degrees if kind == "entrance" else departure_look_down_degrees

func enemy_slots() -> Array[Marker3D]:
	var result: Array[Marker3D] = []
	var slots: Node = get_node_or_null("EnemySlots")
	if slots:
		for child: Node in slots.get_children():
			if child is Marker3D:
				result.append(child)
	return result

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if not get_node_or_null("CameraStart") is Marker3D:
		warnings.append("Room requires a CameraStart marker.")
	for point: String in ["ArrivalStart", "ArrivalLanding", "ExitApproach", "ExitEnd"]:
		if not travel_marker(point):
			warnings.append("Room requires a staircase or travel marker for " + point)
	return warnings
