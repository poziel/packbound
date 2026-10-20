extends RefCounted
## Board-space inspection only. Copies placement records; never commits a move.

static func cells(board) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if board.dragging.is_empty() and board.storage != null and board.storage.grabbed != null:
		return result
	var source: Dictionary = {}
	for item: Dictionary in board.run.items:
		if int(item.id) == board.hovered_id:
			source = item
	var moves: Array[Dictionary] = []
	if not board.dragging.is_empty():
		moves = board.candidate_plan()
		if moves.is_empty():
			return result
		source = board.dragging
	if source.is_empty() or (source.get("adjacency_bonus", {}).is_empty() and source.get("quiver_bonus", {}).is_empty() and source.get("key", "") not in ["blood_gem", "iron_charm", "quiver", "magnificent_quiver", "cursed_idol"]):
		return result
	var preview: Array[Dictionary] = []
	for item: Dictionary in board.run.items:
		var copy: Dictionary = item.duplicate()
		for move: Dictionary in moves:
			if int(move.item.id) == int(item.id):
				copy.cell = move.cell
				copy.rotation = move.rotation
				copy.shape = move.shape
		preview.append(copy)
		if int(item.id) == int(source.id):
			source = copy
	if source.get("cell") == null or (board.dragging.is_empty() and board.item_motions.has(source.id)):
		return result
	var occupied: Array[Vector2i] = board.run.cells(source)
	for y in range(PackRun.GRID.y):
		for x in range(PackRun.GRID.x):
			var cell := Vector2i(x, y)
			if occupied.has(cell):
				continue
			var probe := {"cell": cell, "mask": [Vector2i.ZERO], "rotation": 0}
			if not board.run.touches(source, probe):
				continue
			var fulfilled := false
			for target: Dictionary in preview:
				if board.run.cells(target).has(cell) and board.run.has_bonus(source, target):
					fulfilled = true
			result.append({"cell": cell, "fulfilled": fulfilled})
	return result

static func draw(board) -> void:
	for star: Dictionary in board.synergy_cells():
		var center: Vector2 = board.ORIGIN + Vector2(star.cell) * board.STEP + Vector2.ONE * board.CELL * 0.5
		var points := PackedVector2Array()
		for index in range(10):
			var angle: float = -PI * 0.5 + index * PI / 5.0
			points.append(center + Vector2(cos(angle), sin(angle)) * (8.0 if index % 2 == 0 else 3.5))
		var color := Color("ffe1a0") if star.fulfilled else Color(0.65, 0.68, 0.72, 0.45)
		points.append(points[0])
		var outline := Color("171e28")
		outline.a = 1.0 if star.fulfilled else 0.3
		board.draw_polyline(points, outline, 4.0)
		if star.fulfilled:
			board.draw_colored_polygon(points, color)
		board.draw_polyline(points, color, 2.0)
