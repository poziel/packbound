@tool
extends Node3D
## Reuses saved wall chunks without stretching the individual bricks.

@export_range(0.01, 16.0, 0.01) var span_width: float = 16.0:
	set(value):
		span_width = clampf(value, 0.01, 16.0)
		_apply_span()

func _ready() -> void:
	_apply_span()

func set_span(width: float) -> void:
	span_width = width

func _apply_span() -> void:
	if not is_inside_tree() or not has_node("Chunks"):
		return
	var width: float = span_width
	for child: Node3D in $Chunks.get_children():
		var remaining: float = width - child.position.x
		child.visible = remaining > 0.01
		child.clip_width = maxf(0.001, remaining)
