@tool
extends Node3D
## Authored bricks retain their dimensions; only a wall's final edge is trimmed.

@export var clip_width: float = 0.0:
	set(value):
		clip_width = value
		_apply_clip()
var original: Dictionary = {}

func _ready() -> void:
	for child: MeshInstance3D in get_children():
		original[child.name] = {"mesh": child.mesh, "position": child.position}
	_apply_clip()

func _apply_clip() -> void:
	if not is_inside_tree() or original.is_empty():
		return
	for child: MeshInstance3D in get_children():
		var source: Dictionary = original[child.name]
		child.mesh = source.mesh
		child.position = source.position
		child.visible = true
		if clip_width <= 0.0:
			continue
		var left: float = child.position.x - child.mesh.size.x * 0.5
		var right: float = minf(clip_width, child.position.x + child.mesh.size.x * 0.5)
		if right <= left:
			child.visible = false
		elif right < child.position.x + child.mesh.size.x * 0.5:
			child.mesh = child.mesh.duplicate()
			child.mesh.size.x = right - left
			child.position.x = (right + left) * 0.5
