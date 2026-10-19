@tool
extends RefCounted
## Shared segmented border for inventory masks, storage squares, portraits and relic sockets.

static var _geometry: Dictionary = {}

static func polygons(points: Array[Vector2i], cell_size: Vector2, gap: float, inset: float = 0.0) -> Array[PackedVector2Array]:
	var key: String = str([points, cell_size, gap, inset])
	if _geometry.has(key):
		return _geometry[key]
	var result: Array[PackedVector2Array] = []
	var pitch: Vector2 = cell_size + Vector2.ONE * gap
	var half_gap: float = gap * 0.5
	var edge: float = half_gap + inset
	var cut: float = maxf(0, 4 - inset)
	for point in points:
		var left: bool = points.has(point + Vector2i.LEFT)
		var right: bool = points.has(point + Vector2i.RIGHT)
		var up: bool = points.has(point + Vector2i.UP)
		var down: bool = points.has(point + Vector2i.DOWN)
		var x0: float = 0.0 if left else edge
		var x1: float = pitch.x if right else pitch.x - edge
		var y0: float = 0.0 if up else edge
		var y1: float = pitch.y if down else pitch.y - edge
		var polygon := PackedVector2Array()
		if left and up and not points.has(point + Vector2i(-1, -1)):
			polygon.append_array(PackedVector2Array([Vector2(0, edge), Vector2(edge, edge), Vector2(edge, 0)]))
		elif not left and not up and cut > 0:
			polygon.append_array(PackedVector2Array([Vector2(x0, y0 + cut), Vector2(x0 + cut / 2, y0 + cut), Vector2(x0 + cut / 2, y0 + cut / 2), Vector2(x0 + cut, y0 + cut / 2), Vector2(x0 + cut, y0)]))
		else:
			polygon.append(Vector2(x0, y0))
		if right and up and not points.has(point + Vector2i(1, -1)):
			polygon.append_array(PackedVector2Array([Vector2(pitch.x - edge, 0), Vector2(pitch.x - edge, edge), Vector2(pitch.x, edge)]))
		elif not right and not up and cut > 0:
			polygon.append_array(PackedVector2Array([Vector2(x1 - cut, y0), Vector2(x1 - cut, y0 + cut / 2), Vector2(x1 - cut / 2, y0 + cut / 2), Vector2(x1 - cut / 2, y0 + cut), Vector2(x1, y0 + cut)]))
		else:
			polygon.append(Vector2(x1, y0))
		if right and down and not points.has(point + Vector2i(1, 1)):
			polygon.append_array(PackedVector2Array([Vector2(pitch.x, pitch.y - edge), Vector2(pitch.x - edge, pitch.y - edge), Vector2(pitch.x - edge, pitch.y)]))
		elif not right and not down and cut > 0:
			polygon.append_array(PackedVector2Array([Vector2(x1, y1 - cut), Vector2(x1 - cut / 2, y1 - cut), Vector2(x1 - cut / 2, y1 - cut / 2), Vector2(x1 - cut, y1 - cut / 2), Vector2(x1 - cut, y1)]))
		else:
			polygon.append(Vector2(x1, y1))
		if left and down and not points.has(point + Vector2i(-1, 1)):
			polygon.append_array(PackedVector2Array([Vector2(edge, pitch.y), Vector2(edge, pitch.y - edge), Vector2(0, pitch.y - edge)]))
		elif not left and not down and cut > 0:
			polygon.append_array(PackedVector2Array([Vector2(x0 + cut, y1), Vector2(x0 + cut, y1 - cut / 2), Vector2(x0 + cut / 2, y1 - cut / 2), Vector2(x0 + cut / 2, y1 - cut), Vector2(x0, y1 - cut)]))
		else:
			polygon.append(Vector2(x0, y1))
		result.append(Transform2D(0, Vector2(point) * pitch - Vector2.ONE * half_gap) * polygon)
	# Round re-entrant corners by bridging only the tiny corner of the empty
	# quadrant. Raster insets then give the rim, clear gap and face the same turn.
	if inset == 0:
		for point in points:
			for corner: Vector2i in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1)]:
				if not points.has(point + Vector2i(corner.x, 0)) or not points.has(point + Vector2i(0, corner.y)) or points.has(point + corner): continue
				var vertex := Vector2(point) * pitch - Vector2.ONE * half_gap + Vector2(pitch.x if corner.x > 0 else 0.0, pitch.y if corner.y > 0 else 0.0)
				var anchor := vertex - Vector2(corner) * half_gap
				for patch_size: Vector2 in [Vector2(4, 2), Vector2(2, 4)]:
					var patch := Rect2(anchor, Vector2(corner) * patch_size).abs()
					result.append(PackedVector2Array([patch.position, Vector2(patch.end.x, patch.position.y), patch.end, Vector2(patch.position.x, patch.end.y)]))
	_geometry[key] = result
	return result

## Consecutive exposed cell edges form one straight segment, including hole edges.
## Any member cell can address the merged segment for replacement.
static func segments(points: Array[Vector2i], cell_size: Vector2, gap: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var directions := {"top": Vector2i.UP, "right": Vector2i.RIGHT, "bottom": Vector2i.DOWN, "left": Vector2i.LEFT}
	for cell in points:
		for side: String in directions:
			var outward: Vector2i = directions[side]
			if points.has(cell + outward): continue
			var horizontal: bool = side == "top" or side == "bottom"
			var along := Vector2i.RIGHT if horizontal else Vector2i.DOWN
			# Only the first cell emits this run, regardless of input ordering.
			if points.has(cell - along) and not points.has(cell - along + outward): continue
			var cells: Array[Vector2i] = [cell]
			var next := cell + along
			while points.has(next) and not points.has(next + outward):
				cells.append(next)
				next += along
			var at := Vector2(cell) * (cell_size + Vector2.ONE * gap)
			var cell_length: float = cell_size.x if horizontal else cell_size.y
			var length: float = cell_length * cells.size() + gap * (cells.size() - 1)
			var trim: float = minf(8, floorf(cell_length / 4))
			var pos := at + (Vector2(trim, 0) if horizontal else Vector2(0, trim))
			if side == "bottom": pos.y += cell_size.y - 2
			if side == "right": pos.x += cell_size.x - 2
			result.append({"cell": cell, "cells": cells, "side": side, "rect": Rect2(pos, Vector2(length - trim * 2, 2) if horizontal else Vector2(2, length - trim * 2))})
	return result

static var _skins: Dictionary = {}

## Rasterize the union before insetting: shared edges disappear, holes remain open.
## White masks are tinted at draw time; the gap contains actual transparent pixels.
static func skin(points: Array[Vector2i], cell_size: Vector2, gap: float, replacements: Array[Dictionary] = [], continuous: bool = false, owner: CanvasItem = null) -> Dictionary:
	var cuts: Array[Rect2] = []
	var sockets: Array[Dictionary] = segments(points, cell_size, gap)
	if not continuous:
		for socket in sockets:
			var rect: Rect2 = socket.rect
			var horizontal: bool = socket.side == "top" or socket.side == "bottom"
			cuts.append(Rect2(rect.position, Vector2(1, 2) if horizontal else Vector2(2, 1)))
			cuts.append(Rect2(rect.end - (Vector2(1, 2) if horizontal else Vector2(2, 1)), Vector2(1, 2) if horizontal else Vector2(2, 1)))
			for replacement in replacements:
				if socket.cells.has(replacement.get("cell", Vector2i.ZERO)) and replacement.get("side", "bottom") == socket.side:
					cuts.append(replacement_rect(socket, replacement))
	var key: String = str([points, cell_size, gap, cuts, continuous])
	if _skins.has(key): return _retain_skin(owner, _skins[key])
	var shapes := polygons(points, cell_size, gap)
	var bounds := Rect2()
	for polygon in shapes:
		for vertex in polygon:
			bounds = bounds.expand(vertex)
	var origin := bounds.position.floor() - Vector2.ONE
	var dimensions := Vector2i(bounds.end.ceil() - origin) + Vector2i.ONE
	var width: int = dimensions.x
	var depth := PackedInt32Array()
	depth.resize(width * dimensions.y)
	for polygon in shapes:
		var local_bounds := Rect2(polygon[0], Vector2.ZERO)
		for vertex in polygon: local_bounds = local_bounds.expand(vertex)
		for y in range(int(local_bounds.position.y - origin.y), int(local_bounds.end.y - origin.y)):
			for x in range(int(local_bounds.position.x - origin.x), int(local_bounds.end.x - origin.x)):
				if Geometry2D.is_point_in_polygon(origin + Vector2(x + 0.5, y + 0.5), polygon):
					depth[y * width + x] = 4
	# Chessboard distance to transparent pixels gives a crisp integer pixel inset.
	for y in range(1, dimensions.y - 1):
		for x in range(1, width - 1):
			var i: int = y * width + x
			if depth[i] > 0:
				depth[i] = mini(depth[i], 1 + mini(mini(depth[i - 1], depth[i - width]), mini(depth[i - width - 1], depth[i - width + 1])))
	for y in range(dimensions.y - 2, 0, -1):
		for x in range(width - 2, 0, -1):
			var i: int = y * width + x
			if depth[i] > 0:
				depth[i] = mini(depth[i], 1 + mini(mini(depth[i + 1], depth[i + width]), mini(depth[i + width - 1], depth[i + width + 1])))
	var border := Image.create(dimensions.x, dimensions.y, false, Image.FORMAT_RGBA8)
	var fill := Image.create(dimensions.x, dimensions.y, false, Image.FORMAT_RGBA8)
	for y in range(dimensions.y):
		for x in range(width):
			var distance: int = depth[y * width + x]
			if distance >= 4: fill.set_pixel(x, y, Color.WHITE)
			elif distance > 0 and distance <= 2: border.set_pixel(x, y, Color.WHITE)
	for cut in cuts:
		for y in range(int(cut.position.y - origin.y), int(cut.end.y - origin.y)):
			for x in range(int(cut.position.x - origin.x), int(cut.end.x - origin.x)):
				if x >= 0 and y >= 0 and x < width and y < dimensions.y:
					border.set_pixel(x, y, Color.TRANSPARENT)
	var result := {"origin": origin, "border": ImageTexture.create_from_image(border), "fill": ImageTexture.create_from_image(fill)}
	if _skins.size() >= 128: _skins.clear()
	_skins[key] = result
	return _retain_skin(owner, result)

static func _retain_skin(owner: CanvasItem, masks: Dictionary) -> Dictionary:
	if owner != null:
		# Canvas draw commands retain texture RIDs, not the ImageTexture resources.
		# Keep the masks from this owner's latest draw alive even after cache eviction.
		var frame: int = Engine.get_process_frames()
		var retained: Dictionary = owner.get_meta("_frame_skin_resources", {})
		if retained.get("frame", -1) != frame:
			retained = {"frame": frame, "masks": []}
		retained["masks"].append(masks)
		owner.set_meta("_frame_skin_resources", retained)
	return masks

static func replacement_rect(socket: Dictionary, replacement: Dictionary) -> Rect2:
	var rect: Rect2 = socket.rect
	var horizontal: bool = socket.side == "top" or socket.side == "bottom"
	var length: float = rect.size.x if horizontal else rect.size.y
	var extent: float = clampf(float(replacement.get("length", 9)), 1, maxf(1, length - 2))
	return Rect2((rect.get_center() - (Vector2(extent, 2) if horizontal else Vector2(2, extent)) / 2).floor(), Vector2(extent, 2) if horizontal else Vector2(2, extent))

## Occupied tile variant: a one-digit compartment joined to the outer corner.
## Shares the tile's stepped corner and rim; it is not an inset floating badge.
static func rim_color(accent: Color, highlighted: bool = false) -> Color:
	return accent.lightened(0.18) if highlighted else Color("65717b").lerp(accent, 0.55)

static func draw_priority_corner(canvas: CanvasItem, at: Vector2, font: Font, priority: int, accent: Color, highlighted: bool = false, opacity: float = 1.0) -> void:
	if priority == 0:
		return
	var rim: Color = rim_color(accent, highlighted)
	var face: Color = Color("162129").lerp(accent, 0.10)
	rim.a *= opacity
	face.a *= opacity
	var outline := PackedVector2Array([Vector2(0, 4), Vector2(2, 4), Vector2(2, 2), Vector2(4, 2), Vector2(4, 0), Vector2(18, 0), Vector2(18, 16), Vector2(16, 16), Vector2(16, 18), Vector2(14, 18), Vector2(14, 20), Vector2(0, 20)])
	var interior := PackedVector2Array([Vector2(2, 6), Vector2(4, 6), Vector2(4, 4), Vector2(6, 4), Vector2(6, 2), Vector2(16, 2), Vector2(16, 14), Vector2(14, 14), Vector2(14, 16), Vector2(12, 16), Vector2(12, 18), Vector2(2, 18)])
	canvas.draw_colored_polygon(Transform2D(0, at) * outline, rim)
	canvas.draw_colored_polygon(Transform2D(0, at) * interior, face)
	var baseline: float = floorf((20.0 - font.get_height(16)) * 0.5 + font.get_ascent(16))
	canvas.draw_string(font, at + Vector2(2, baseline), str(priority), HORIZONTAL_ALIGNMENT_CENTER, 14, 16, Color(0.96, 0.90, 0.81, opacity))

static func draw_frame(canvas: CanvasItem, points: Array[Vector2i], cell_size: Vector2, gap: float, accent: Color, occupied: bool = true, highlighted: bool = false, replacements: Array[Dictionary] = []) -> void:
	var face: Color = Color("162129").lerp(accent, 0.10) if occupied else Color("121b24")
	var rim: Color = rim_color(accent, highlighted) if occupied else Color("46515b")
	if highlighted: rim = accent.lightened(0.18)
	var masks := skin(points, cell_size, gap, replacements, false, canvas)
	canvas.draw_texture(masks.fill, masks.origin, face)
	canvas.draw_texture(masks.border, masks.origin, rim)
	for socket in segments(points, cell_size, gap):
		for replacement in replacements:
			if not socket.cells.has(replacement.get("cell", Vector2i.ZERO)) or replacement.get("side", "bottom") != socket.side: continue
			var rect := replacement_rect(socket, replacement)
			var color: Color = replacement.get("color", rim)
			var painter: Callable = replacement.get("draw", Callable())
			if painter.is_valid():
				painter.call(canvas, rect, color, socket)
			elif replacement.get("texture") is Texture2D:
				var texture: Texture2D = replacement.texture
				canvas.draw_texture(texture, (rect.get_center() - texture.get_size() / 2).floor(), color)
			elif replacement.get("kind", "") == "caret_up":
				var center := rect.get_center().floor()
				for x in range(-3, 4):
					canvas.draw_rect(Rect2(center + Vector2(x, absi(x) - 3), Vector2(1, 2)), color)
