@tool
extends ColorRect
## A slim frame-colored division, with the status area's rounded upper-left join.

@export_range(0, 24, 1) var corner_radius: int = 8:
	set(value):
		corner_radius = value
		queue_redraw()

func _draw() -> void:
	for row in range(0, corner_radius, 2):
		var band: int = mini(2, corner_radius - row)
		var dy: float = corner_radius - row - band * 0.5
		var inset: int = ceili((corner_radius - sqrt(maxf(0, corner_radius * corner_radius - dy * dy))) / 2) * 2
		draw_rect(Rect2(Vector2(size.x, row), Vector2(inset, band)), color)
