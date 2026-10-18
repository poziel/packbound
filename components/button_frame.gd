@tool
extends RefCounted
## Shared integer-grid frame: one pixel border, one transparent pixel, flat face.
## Both button families render at 2 UI units per pixel.

static func paint(grid: Vector2i, mask: PackedByteArray, face: Color, border: Color, focus: bool = false, shift: int = 0) -> Image:
	var depth := PackedInt32Array()
	depth.resize(mask.size())
	for y in grid.y:
		for x in grid.x:
			var i := y * grid.x + x
			if mask[i]:
				depth[i] = 1 + mini(depth[i - 1] if x > 0 else 0, depth[i - grid.x] if y > 0 else 0)
	for y in range(grid.y - 1, -1, -1):
		for x in range(grid.x - 1, -1, -1):
			var i := y * grid.x + x
			if mask[i]:
				depth[i] = mini(depth[i], 1 + mini(depth[i + 1] if x + 1 < grid.x else 0, depth[i + grid.x] if y + 1 < grid.y else 0))
	var image := Image.create(grid.x, grid.y, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y in grid.y:
		for x in grid.x:
			var d := depth[y * grid.x + x]
			if d == 0 or d == 2 or y + shift >= grid.y:
				continue
			if focus and d != 1:
				continue
			image.set_pixel(x, y + shift, border if d == 1 else face)
	return image
