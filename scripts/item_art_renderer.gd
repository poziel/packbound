extends RefCounted
## Exact backpack art geometry, shared by inventory and borderless recipe items.
const SOURCE_CELL: int = 32
const DISPLAY_SCALE: int = 2
const CELL: float = SOURCE_CELL * DISPLAY_SCALE
const GAP: float = 4.0
const STEP: float = CELL + GAP
const FRAME = preload("res://components/item_slot/item_frame.gd")

static func footprint(shape: Vector2i) -> Vector2:
	return Vector2(shape) * STEP - Vector2.ONE * GAP

static func draw(canvas: CanvasItem, item: Dictionary, size: Vector2, texture: Texture2D, points: Array[Vector2i], rotation: int, alpha: Color = Color.WHITE) -> void:
	var region: Rect2 = Rect2(Vector2.ZERO, texture.get_size())
	if texture is AtlasTexture:
		region = texture.region
		texture = texture.atlas
	var art_rect: Rect2 = Rect2(Vector2.ZERO, size).grow(-4)
	if region.size == Vector2(32, 32) and item["shape"] == Vector2i.ONE:
		art_rect = Rect2(Vector2.ZERO, size)
	for polygon in FRAME.polygons(points, Vector2.ONE * CELL, GAP, 4.0):
		var uvs := PackedVector2Array()
		for vertex in polygon:
			var uv: Vector2 = (vertex - art_rect.position) / art_rect.size
			for quarter in range(posmod(rotation, 4)):
				uv = Vector2(uv.y, 1.0 - uv.x)
			uvs.append((region.position + uv * region.size) / texture.get_size())
		canvas.draw_polygon(polygon, PackedColorArray([alpha]), uvs, texture)
