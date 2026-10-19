@tool
extends StyleBox
## Slim visible rail inside a comfortable native scrollbar hit target.
@export var track: bool = false
@export var color: Color = Color("d7ba7e")
@export var line_width: int = 6
@export var horizontal: bool = false

func _get_minimum_size() -> Vector2:
	var length: int = 4 if track else 32
	return Vector2(length, 16) if horizontal else Vector2(16, length)

func _draw(canvas: RID, area: Rect2) -> void:
	var width: int = 2 if track else line_width
	var rect := Rect2(Vector2(floorf(area.get_center().x - width * 0.5), roundf(area.position.y)), Vector2(width, floorf(area.size.y)))
	if horizontal:
		rect = Rect2(Vector2(roundf(area.position.x), floorf(area.get_center().y - width * 0.5)), Vector2(floorf(area.size.x), width))
	RenderingServer.canvas_item_add_rect(canvas, rect, color)
