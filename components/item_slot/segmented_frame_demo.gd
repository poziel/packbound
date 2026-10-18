@tool
extends Control
## Run segmented_frame_demo.tscn to review native-size frames and replacements.
const FRAME = preload("res://components/item_slot/item_frame.gd")
var custom_draw_count: int = 0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("27232f"))
	var samples := [["#"], ["##..", ".##.", "..##"], ["###", "#.#", "###"], ["###", ".#."]]
	for index in range(samples.size()):
		var cells: Array[Vector2i] = []
		var rows: Array = samples[index]
		for y in range(rows.size()):
			for x in range(rows[y].length()):
				if rows[y][x] == "#": cells.append(Vector2i(x, y))
		draw_set_transform(Vector2(16 + index * 144, 40))
		FRAME.draw_frame(self, cells, Vector2(32, 32), 0, Color("b4db64"))
	draw_set_transform(Vector2(16, 184))
	var caret: Array[Dictionary] = [{"side": "bottom", "kind": "caret_up", "color": Color("83dafa")}]
	FRAME.draw_frame(self, [Vector2i.ZERO], Vector2(64, 64), 0, Color("83dafa"), true, false, caret)
	draw_set_transform(Vector2(112, 184))
	var custom: Array[Dictionary] = [{"side": "right", "length": 11, "draw": _draw_status, "color": Color("f8ca72")}]
	FRAME.draw_frame(self, [Vector2i.ZERO], Vector2(64, 64), 0, Color("f8ca72"), true, false, custom)
	# Hole-facing edges use the same segment API as the outer perimeter.
	var donut: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(2, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)]
	var donut_markers: Array[Dictionary] = [
		{"cell": Vector2i(1, 2), "side": "top", "kind": "caret_up", "color": Color("f8ca72")},
		{"cell": Vector2i(0, 1), "side": "left", "kind": "caret_up"},
		{"cell": Vector2i(2, 1), "side": "right", "kind": "caret_up"},
	]
	draw_set_transform(Vector2(224, 184))
	FRAME.draw_frame(self, donut, Vector2(48, 48), 0, Color("c6b3ff"), true, false, donut_markers)
	var stairs: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2), Vector2i(3, 2)]
	var stair_markers: Array[Dictionary] = [
		{"cell": Vector2i(1, 1), "side": "bottom", "kind": "caret_up", "color": Color("83dafa")},
		{"cell": Vector2i(3, 2), "side": "right", "length": 11, "draw": _draw_status, "color": Color("f8ca72")},
	]
	draw_set_transform(Vector2(408, 184))
	FRAME.draw_frame(self, stairs, Vector2(40, 40), 0, Color("b4db64"), true, false, stair_markers)
	draw_set_transform(Vector2.ZERO)
	draw_string(ThemeDB.fallback_font, Vector2(16, 24), "32 px cells: square, diagonal, hollow and T masks", HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	draw_string(ThemeDB.fallback_font, Vector2(16, 168), "Carets and custom markers: square / donut / stairs", HORIZONTAL_ALIGNMENT_LEFT, -1, 16)

func _draw_status(canvas: CanvasItem, rect: Rect2, color: Color, _socket: Dictionary) -> void:
	custom_draw_count += 1
	var center := rect.get_center().floor()
	canvas.draw_rect(Rect2(center - Vector2(2, 4), Vector2(4, 8)), color)
	canvas.draw_rect(Rect2(center - Vector2(3, 1), Vector2(6, 2)), color)
