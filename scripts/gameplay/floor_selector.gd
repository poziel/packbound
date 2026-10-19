@tool
extends "res://scripts/gameplay/room_definition.gd"
## Each door owns its markers so departure follows the actual chosen opening.

var choices: Array[Dictionary] = []
var selected_door: Node3D
@export var door_center_x: float = -3.6
@export var door_spacing: float = 1.8
@export var opening_half_width: float = 0.82
@export var wall_left: float = -7.25
@export var wall_right: float = 7.25

func _ready() -> void:
	if choices.is_empty():
		configure([{"id": "combat", "kind": "combat"}, {"id": "relic", "kind": "relic"}, {"id": "rest", "kind": "rest"}, {"id": "encounter", "kind": "encounter"}])

func configure(value: Array[Dictionary]) -> void:
	choices = value.duplicate(true)
	selected_door = null
	for index in range(4):
		var door: Node3D = get_node("Doors/Door%d" % index)
		door.visible = index < choices.size()
		if door.visible:
			door.position.x = door_center_x + (index - (choices.size() - 1) * 0.5) * door_spacing
			door.set_meta("choice_id", choices[index].id)
			door.get_node("Sign").text = str(choices[index].kind).to_upper()
	# Fill unused wall spans so hidden doors do not leave apparent extra paths.
	var edge: float = wall_left
	var doors: Array[Node3D] = visible_doors()
	for index in range(5):
		var panel: Node3D = get_node("RearPanels/Panel%d" % index)
		panel.visible = index <= doors.size()
		if not panel.visible:
			continue
		var end: float = doors[index].position.x - opening_half_width if index < doors.size() else wall_right
		if panel.has_method("set_span"):
			panel.position.x = edge
			panel.set_span(maxf(0.01, end - edge))
		else:
			panel.position.x = (edge + end) * 0.5
			panel.scale.x = maxf(0.01, end - edge)
		if index < doors.size():
			edge = doors[index].position.x + opening_half_width

func visible_doors() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for door: Node3D in $Doors.get_children():
		if door.visible:
			result.append(door)
	return result

func door_position(id: String) -> Vector3:
	for door: Node3D in visible_doors():
		if door.get_meta("choice_id", "") == id:
			return door.get_node("Interaction").global_position
	return global_position

func door_half_size(id: String) -> Vector2:
	for door: Node3D in visible_doors():
		if door.get_meta("choice_id", "") == id:
			return door.interaction_half_size
	return Vector2(0.65, 1.0)

func highlight(id: String) -> void:
	for door: Node3D in visible_doors():
		door.set_highlight(door.get_meta("choice_id", "") == id)

func select_exit(id: String) -> bool:
	for door: Node3D in visible_doors():
		if door.get_meta("choice_id", "") == id:
			selected_door = door
			return true
	return false

func travel_marker(point: String) -> Marker3D:
	if selected_door and point in ["ExitApproach", "ExitEnd"]:
		if selected_door.has_node("ExitStairs"):
			return selected_door.get_node("ExitStairs/Top" if point == "ExitApproach" else "ExitStairs/Bottom")
		return selected_door.get_node(point)
	return super.travel_marker(point)

func staircase(kind: String) -> Node3D:
	if kind == "exit" and selected_door and selected_door.has_node("ExitStairs"):
		return selected_door.get_node("ExitStairs")
	return super.staircase(kind)
