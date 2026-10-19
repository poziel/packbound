@tool
extends Control

@export_range(0.0, 1.0) var progress: float = 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		queue_redraw()
@export var track_color := Color("3c3531")
@export var fill_color := Color("c2a663")

# A small stepped ring keeps the countdown at the same pixel scale as the frame.
const POINTS: Array[Vector2] = [Vector2(0, -8), Vector2(4, -7), Vector2(7, -4), Vector2(8, 0), Vector2(7, 4), Vector2(4, 7), Vector2(0, 8), Vector2(-4, 7), Vector2(-7, 4), Vector2(-8, 0), Vector2(-7, -4), Vector2(-4, -7)]

func _draw() -> void:
	var center: Vector2 = (size * 0.5).floor()
	var filled: int = floori(progress * POINTS.size())
	for index in range(POINTS.size()):
		draw_rect(Rect2(center + POINTS[index] - Vector2.ONE, Vector2(2, 2)), fill_color if index < filled else track_color)
