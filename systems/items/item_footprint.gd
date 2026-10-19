@tool
extends Control

func _draw() -> void:
	for point: Vector2i in get_meta("cells", []):
		draw_rect(Rect2(Vector2(point) * 12, Vector2(10, 10)), PackUI.GOLD)
