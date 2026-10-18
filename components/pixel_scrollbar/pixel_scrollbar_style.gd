@tool
extends StyleBox
## Shared native ScrollBar skin. Rectangles stay on whole pixels at every length.

enum Part { TRACK, THUMB }
enum State { NORMAL, HOVER, PRESSED, FOCUSED }

@export var part: Part = Part.TRACK:
	set(next):
		part = next
		emit_changed()
@export var state: State = State.NORMAL:
	set(next):
		state = next
		emit_changed()
@export var horizontal: bool = false:
	set(next):
		horizontal = next
		emit_changed()
@export var face_color: Color = Color("77688e"):
	set(next):
		face_color = next
		emit_changed()
@export var accent_color: Color = Color("d7ba7e"):
	set(next):
		accent_color = next
		emit_changed()

@export_range(16, 64, 1) var thickness: int = 24:
	set(next):
		thickness = clampi(next, 16, 64)
		emit_changed()
@export_range(16, 128, 1) var minimum_thumb_length: int = 32:
	set(next):
		minimum_thumb_length = clampi(next, 16, 128)
		emit_changed()
@export var track_outline: Color = Color("484354"):
	set(next):
		track_outline = next
		emit_changed()
@export var thumb_edge: Color = Color("b1a0c6"):
	set(next):
		thumb_edge = next
		emit_changed()
@export var grip_color: Color = Color("ded3e4"):
	set(next):
		grip_color = next
		emit_changed()


func _get_minimum_size() -> Vector2:
	# Native thumb math adds this minimum to its proportional length.
	var length: float = minimum_thumb_length if part == Part.THUMB else 8.0
	return Vector2(length, thickness) if horizontal else Vector2(thickness, length)


func _draw(canvas: RID, area: Rect2) -> void:
	var rect: Rect2 = Rect2(area.position.round(), area.size.floor())
	if part == Part.TRACK:
		_stepped(canvas, rect, Color("070910"))
		_stepped(canvas, rect.grow(-2), accent_color if state == State.FOCUSED else track_outline)
		_stepped(canvas, rect.grow(-4), Color("11121c"))
		return
	# The native grabber spans the track width; inset only across that axis.
	if horizontal:
		rect.position.y += 4
		rect.size.y -= 8
	else:
		rect.position.x += 4
		rect.size.x -= 8
	var face: Color = face_color
	if state == State.HOVER:
		face = face.lightened(0.22)
	elif state == State.PRESSED:
		face = face.darkened(0.24)
	_stepped(canvas, rect, accent_color if state != State.NORMAL else thumb_edge)
	_stepped(canvas, rect.grow(-2), face)
	var inner: Rect2 = rect.grow(-2)
	_box(canvas, Rect2(inner.position + Vector2(2, 0), Vector2(inner.size.x - 4, 2)), face.lightened(0.22))
	_box(canvas, Rect2(inner.position + Vector2(0, inner.size.y - 2), Vector2(inner.size.x, 2)), face.darkened(0.38))
	# Three fixed-size grip marks, never stretched with the thumb.
	var center: Vector2 = rect.get_center().floor()
	for offset: int in [-4, 0, 4]:
		var grip: Rect2 = Rect2(center + Vector2(-3, offset), Vector2(6, 2))
		if horizontal:
			grip = Rect2(center + Vector2(offset, -3), Vector2(2, 6))
		_box(canvas, grip, accent_color if state == State.PRESSED else grip_color)


func _stepped(canvas: RID, rect: Rect2, color: Color) -> void:
	if rect.size.x < 4 or rect.size.y < 4:
		_box(canvas, rect, color)
		return
	_box(canvas, Rect2(rect.position + Vector2(2, 0), rect.size - Vector2(4, 0)), color)
	_box(canvas, Rect2(rect.position + Vector2(0, 2), rect.size - Vector2(0, 4)), color)


func _box(canvas: RID, rect: Rect2, color: Color) -> void:
	if rect.size.x > 0 and rect.size.y > 0:
		RenderingServer.canvas_item_add_rect(canvas, rect, color)
