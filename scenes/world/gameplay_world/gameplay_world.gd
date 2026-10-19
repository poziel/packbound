extends Node3D
## One world, camera and actor collection shared by replaceable scenery rooms.

signal room_changed
@onready var camera: Camera3D = $Camera
@onready var lantern: Node3D = $Camera/PlayerLantern
@onready var room_slot: Node3D = $RoomSlot
@onready var actors: Node3D = $Actors
@onready var enemy: Sprite3D = $Actors/Enemy
@onready var world_environment: WorldEnvironment = $Environment
@onready var default_environment: Environment = world_environment.environment
var active_room: Node3D
var selected_enemy_slot: int = 0
var camera_home: Vector3:
	get:
		return to_local(active_room.get_node("CameraStart").global_position)
var camera_rotation: Vector3:
	get:
		return (global_transform.affine_inverse() * active_room.get_node("CameraStart").global_transform).basis.get_euler()

func _ready() -> void:
	active_room = room_slot.get_child(0)
	_configure_environment()
	reset_camera()
	place_enemy_at_slot()

func set_room(scene: PackedScene) -> bool:
	if active_room and active_room.scene_file_path == scene.resource_path and not scene.resource_path.is_empty():
		reset_camera()
		place_enemy_at_slot()
		return true
	var candidate: Node = scene.instantiate()
	if not candidate is Node3D:
		push_warning("Room was not loaded: the root must be Node3D")
		candidate.free()
		return false
	if not candidate.has_method("enemy_slots") or not candidate.has_method("travel_marker"):
		push_warning("Room was not loaded: use room_definition.gd or a derived script")
		candidate.free()
		return false
	if not candidate.get_node_or_null("CameraStart") is Marker3D:
		candidate.free()
		return false
	for point: String in ["ArrivalStart", "ArrivalLanding", "ExitApproach", "ExitEnd"]:
		if not candidate.travel_marker(point) is Marker3D:
			push_warning("Room was not loaded: missing staircase marker " + point)
			candidate.free()
			return false
	if active_room:
		room_slot.remove_child(active_room)
		active_room.queue_free()
	active_room = candidate
	active_room.name = "CurrentRoom"
	room_slot.add_child(active_room)
	_configure_environment()
	selected_enemy_slot = 0
	reset_camera()
	place_enemy_at_slot()
	room_changed.emit()
	return true

func _configure_environment() -> void:
	world_environment.environment = active_room.environment if active_room.environment else default_environment

func place_enemy_at_slot(index: int = 0) -> bool:
	var slots: Array[Marker3D] = active_room.enemy_slots()
	if index < 0 or index >= slots.size():
		enemy.clear_spawn()
		return false
	selected_enemy_slot = index
	enemy.place_at(slots[index])
	return true

func reset_camera() -> void:
	camera.transform = global_transform.affine_inverse() * active_room.get_node("CameraStart").global_transform
	camera.set_frustum(active_room.camera_size, active_room.camera_frustum_offset, active_room.camera_near, active_room.camera_far)
	camera.make_current()

func advance_camera(progress: float) -> void:
	var split: float = active_room.departure_approach_end
	var approach: float = clampf(progress / split, 0.0, 1.0)
	var descent: float = clampf((progress - split) / (1.0 - split), 0.0, 1.0)
	var edge: Vector3 = _marker_position("Travel/ExitApproach")
	var end: Vector3 = _marker_position("Travel/ExitEnd")
	camera.position = camera_home.lerp(edge, approach) + (end - edge) * descent
	var home_basis: Basis = Basis.from_euler(camera_rotation)
	var stair_basis: Basis = _marker_transform("ExitApproach").basis if active_room.staircase("exit") else home_basis
	var facing: Quaternion = home_basis.get_rotation_quaternion().slerp(stair_basis.orthonormalized().get_rotation_quaternion(), approach)
	camera.basis = Basis(facing) * Basis(Vector3.RIGHT, -deg_to_rad(active_room.travel_tilt("exit")) * smoothstep(0.48, 0.78, progress))
	_apply_walking_sway(progress)

func arrive_camera(progress: float) -> void:
	var split: float = active_room.arrival_descent_end
	var descent: float = clampf(progress / split, 0.0, 1.0)
	var approach: float = clampf((progress - split) / (1.0 - split), 0.0, 1.0)
	var start: Vector3 = _marker_position("Travel/ArrivalStart")
	var landing: Vector3 = _marker_position("Travel/ArrivalLanding")
	camera.position = start.lerp(landing, descent) + (camera_home - landing) * approach
	var home_basis: Basis = Basis.from_euler(camera_rotation)
	var stair_basis: Basis = _marker_transform("ArrivalLanding").basis if active_room.staircase("entrance") else home_basis
	var facing: Quaternion = stair_basis.orthonormalized().get_rotation_quaternion().slerp(home_basis.get_rotation_quaternion(), approach)
	camera.basis = Basis(facing) * Basis(Vector3.RIGHT, -deg_to_rad(active_room.travel_tilt("entrance")) * (1.0 - smoothstep(0.45, 0.82, progress)))
	_apply_walking_sway(progress)

func _marker_position(path: String) -> Vector3:
	return to_local(active_room.travel_marker(path.get_file()).global_position)

func _marker_transform(point: String) -> Transform3D:
	return global_transform.affine_inverse() * active_room.travel_marker(point).global_transform

func _apply_walking_sway(progress: float) -> void:
	var envelope: float = smoothstep(0.0, 0.12, progress) * (1.0 - smoothstep(0.88, 1.0, progress))
	var step: float = sin(progress * TAU * 2.5) * envelope
	var right: Vector3 = camera.basis.x.normalized()
	camera.position += right * step * active_room.walking_sway
	camera.position.y -= absf(sin(progress * TAU * 2.5)) * active_room.walking_bob * envelope
	camera.rotation.y += step * active_room.walking_sway * 0.045
