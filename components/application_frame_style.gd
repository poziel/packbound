@tool
extends StyleBox
## Opaque perimeter with a stepped, rounded inner opening. Draws integer rectangles.

@export var border_color: Color = Color(0.333, 0.365, 0.424, 1):
	set(value):
		border_color = value
		emit_changed()
@export_range(1, 16, 1) var border_width: int = 5:
	set(value):
		border_width = value
		emit_changed()
@export_range(0, 32, 1) var corner_radius: int = 12:
	set(value):
		corner_radius = value
		emit_changed()
@export_range(1, 4, 1) var pixel_step: int = 2:
	set(value):
		pixel_step = value
		emit_changed()
@export var dock_size: Vector2i = Vector2i.ZERO:
	set(value):
		if dock_size != value:
			dock_size = value
			emit_changed()
var draw_center: bool = false

func _get_minimum_size() -> Vector2:
	return Vector2.ONE * border_width * 2

func _draw(canvas: RID, area: Rect2) -> void:
	var rect := Rect2(area.position.round(), area.size.floor())
	var b: int = mini(border_width, floori(minf(rect.size.x, rect.size.y) / 2))
	_box(canvas, Rect2(rect.position, Vector2(rect.size.x, b)))
	_box(canvas, Rect2(rect.position + Vector2(0, rect.size.y - b), Vector2(rect.size.x, b)))
	_box(canvas, Rect2(rect.position + Vector2(0, b), Vector2(b, rect.size.y - b * 2)))
	_box(canvas, Rect2(rect.position + Vector2(rect.size.x - b, b), Vector2(b, rect.size.y - b * 2)))
	var radius: int = mini(corner_radius, floori(minf(rect.size.x, rect.size.y) / 2) - b)
	for row in range(0, radius, pixel_step):
		var band: int = mini(pixel_step, radius - row)
		var dy: float = radius - row - band * 0.5
		var inset: int = ceili((radius - sqrt(maxf(0, radius * radius - dy * dy))) / pixel_step) * pixel_step
		var top: float = rect.position.y + b + row
		var bottom: float = rect.end.y - b - row - band
		for y: float in [top, bottom]:
			_box(canvas, Rect2(Vector2(rect.position.x + b, y), Vector2(inset, band)))
			_box(canvas, Rect2(Vector2(rect.end.x - b - inset, y), Vector2(inset, band)))
	if dock_size.x > b and dock_size.y > b:
		_draw_dock(canvas, rect, b, radius)

func _draw_dock(canvas: RID, rect: Rect2, b: int, radius: int) -> void:
	var width: int = mini(dock_size.x, int(rect.size.x) - b)
	var height: int = mini(dock_size.y, int(rect.size.y) - b)
	var left: float = rect.end.x - width
	var bottom: float = rect.position.y + height
	var r: int = mini(radius, mini(width - b, height - b))
	# The convex lower-left corner leaves the page beneath it transparent.
	for row in range(0, height, pixel_step):
		var band: int = mini(pixel_step, height - row)
		var distance_from_bottom: int = height - row - band
		var cut: int = _corner_inset(distance_from_bottom, band, r) if distance_from_bottom < r else 0
		_box(canvas, Rect2(Vector2(left + cut, rect.position.y + row), Vector2(width - cut, band)))
	# Concave joins curve continuously from the top border and into the right border.
	var top_radius: int = mini(r, int(left - rect.position.x) - b)
	for row in range(0, top_radius, pixel_step):
		var band: int = mini(pixel_step, top_radius - row)
		var inset: int = _corner_inset(row, band, top_radius)
		_box(canvas, Rect2(Vector2(left - inset, rect.position.y + b + row), Vector2(inset, band)))
	var right_radius: int = mini(r, int(rect.size.y) - b - height)
	for row in range(0, right_radius, pixel_step):
		var band: int = mini(pixel_step, right_radius - row)
		var inset: int = _corner_inset(row, band, right_radius)
		_box(canvas, Rect2(Vector2(rect.end.x - b - inset, bottom + row), Vector2(inset, band)))

func _corner_inset(row: int, band: int, radius: int) -> int:
	var dy: float = radius - row - band * 0.5
	return ceili((radius - sqrt(maxf(0, radius * radius - dy * dy))) / pixel_step) * pixel_step

func _box(canvas: RID, rect: Rect2) -> void:
	if rect.size.x > 0 and rect.size.y > 0:
		RenderingServer.canvas_item_add_rect(canvas, rect, border_color)
