@tool
extends StyleBox
## Resolution-independent UI skin drawn as integer pixel rows, not sprite art.
## Ornaments occupy reserved space inside the control, so containers never clip them.

enum State { NORMAL, HOVER, PRESSED, DISABLED, FOCUS }
enum Ends { BOTH, LEFT, RIGHT, NONE }
## LEFT/RIGHT are paired halves: only the outer edge has a notch and diamond.
@export var ends: Ends = Ends.BOTH:
	set(value):
		ends = value
		emit_changed()
@export var palette: Resource:
	set(value):
		if palette != null and palette.changed.is_connected(emit_changed):
			palette.changed.disconnect(emit_changed)
		palette = value
		if palette != null:
			palette.changed.connect(emit_changed)
		emit_changed()
@export var state: State = State.NORMAL:
	set(value):
		state = value
		emit_changed()
@export var compact: bool = false:
	set(value):
		compact = value
		emit_changed()

var _frame_textures: Dictionary = {}

func _get_minimum_size() -> Vector2:
	# StyleBox minimum is padding; Button adds its text/icon size separately.
	return Vector2(24 if ends == Ends.NONE and not compact else 56 if compact or ends != Ends.BOTH else 80, 16 if ends == Ends.NONE else 24)

func _draw(canvas: RID, area: Rect2) -> void:
	if palette == null:
		return
	var rect := Rect2(area.position.round(), area.size.floor())
	var active := state == State.HOVER
	var inset := 22.0
	var left := inset if _left_decorated() else 2.0
	var right := inset if _right_decorated() else 2.0
	var body := Rect2(rect.position + Vector2(left, 2), rect.size - Vector2(left + right, 4))
	if state == State.PRESSED:
		body.position.y += 2
		body.size.y -= 2
	if state == State.FOCUS:
		_draw_frame(canvas, body, Color.TRANSPARENT, palette.hover_face.lightened(0.22), true)
		_ornaments(canvas, rect, palette.hover_face.lightened(0.22), true)
		return
	var face: Color = palette.face
	if state == State.HOVER:
		face = palette.hover_face
	elif state == State.PRESSED:
		face = palette.pressed_face
	elif state == State.DISABLED:
		face = palette.disabled_face
	var trim: Color = face if palette.border_matches_face else palette.trim
	if state == State.DISABLED and not palette.border_matches_face:
		trim = trim.lerp(palette.disabled_face, 0.65)
	_draw_frame(canvas, body, face, trim)
	_ornaments(canvas, rect, trim, active)

func _draw_frame(canvas: RID, body: Rect2, face: Color, trim: Color, focus: bool = false) -> void:
	var grid := Vector2i(maxi(1, ceili(body.size.x / 2)), maxi(1, ceili(body.size.y / 2)))
	var signature := str([grid, face, trim, ends, compact, focus])
	if not _frame_textures.has(signature):
		var mask := PackedByteArray()
		mask.resize(grid.x * grid.y)
		for y in grid.y:
			var left := _cut(y * 2, grid.y * 2, _left_decorated()) / 2
			var right := _cut(y * 2, grid.y * 2, _right_decorated()) / 2
			for x in grid.x:
				mask[y * grid.x + x] = 1 if x >= left and x < grid.x - right else 0
		var image: Image = preload("res://components/ui/buttons/shared/button_frame.gd").paint(grid, mask, face, trim, focus)
		image.resize(grid.x * 2, grid.y * 2, Image.INTERPOLATE_NEAREST)
		_frame_textures[signature] = ImageTexture.create_from_image(image)
	RenderingServer.canvas_item_add_texture_rect_region(canvas, body, _frame_textures[signature].get_rid(), Rect2(Vector2.ZERO, body.size))

func _left_decorated() -> bool:
	return compact or ends in [Ends.BOTH, Ends.LEFT]

func _right_decorated() -> bool:
	return not compact and ends in [Ends.BOTH, Ends.RIGHT]

func _ornaments(canvas: RID, rect: Rect2, color: Color, filled: bool) -> void:
	var center_y := floorf(rect.get_center().y / 2) * 2
	if _left_decorated():
		_diamond(canvas, Vector2(rect.position.x + 18, center_y), color, filled)
	if _right_decorated():
		_diamond(canvas, Vector2(rect.end.x - 20, center_y), color, filled)

func _cut(y: int, height: int, decorated: bool) -> int:
	var edge := mini(y, height - 1 - y)
	var corner := maxi(0, 8 - edge)
	var notch := maxi(0, 10 - absi(y - height / 2)) if decorated else 0
	return maxi(corner, notch) / 2 * 2

func _shape(canvas: RID, rect: Rect2, color: Color) -> void:
	for y in range(0, int(rect.size.y), 2):
		var cut := _cut(y, int(rect.size.y), _left_decorated())
		var right_cut := _cut(y, int(rect.size.y), _right_decorated())
		_box(canvas, Rect2(rect.position + Vector2(cut, y), Vector2(rect.size.x - cut - right_cut, mini(2.0, rect.size.y - y))), color)

func _diamond(canvas: RID, center: Vector2, color: Color, filled: bool) -> void:
	for y in range(-8, 10, 2):
		var half := 8 - absi(y)
		_box(canvas, Rect2(center + Vector2(-half, y), Vector2(half * 2 + 2, 2)), palette.outline)
	for y in range(-6, 8, 2):
		var half := 6 - absi(y)
		_box(canvas, Rect2(center + Vector2(-half, y), Vector2(half * 2 + 2, 2)), color)
	for y in range(-4, 6, 2):
		var half := 4 - absi(y)
		_box(canvas, Rect2(center + Vector2(-half, y), Vector2(half * 2 + 2, 2)), palette.outline)
	if filled:
		_box(canvas, Rect2(center + Vector2(-1, -2), Vector2(4, 6)), color)

func _box(canvas: RID, rect: Rect2, color: Color) -> void:
	if rect.size.x > 0 and rect.size.y > 0:
		RenderingServer.canvas_item_add_rect(canvas, rect, color)
