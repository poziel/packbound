extends Sprite3D
## Registered source pixels become world units; never fit each species separately.

const SOURCE_ANCHOR := Vector2(144, 288)
var source_bounds := Rect2()
signal spawn_changed
var has_spawn: bool = false

func place_at(marker: Marker3D) -> void:
	global_transform = marker.global_transform
	has_spawn = true
	spawn_changed.emit()

func clear_spawn() -> void:
	has_spawn = false
	hide()
	spawn_changed.emit()

func set_art(value: Texture2D) -> void:
	if texture == value:
		return
	texture = value
	source_bounds = Rect2(texture.get_image().get_used_rect())

func projected_bounds(camera: Camera3D, display_size: Vector2) -> Rect2:
	var result := Rect2()
	var first := true
	for corner: Vector2 in [source_bounds.position, Vector2(source_bounds.end.x, source_bounds.position.y), source_bounds.end, Vector2(source_bounds.position.x, source_bounds.end.y)]:
		var relative: Vector2 = corner - SOURCE_ANCHOR
		var point: Vector3 = to_global(Vector3(relative.x, -relative.y, 0) * pixel_size)
		var screen: Vector2 = camera.unproject_position(point) * display_size / Vector2(camera.get_viewport().size)
		if first:
			result = Rect2(screen, Vector2.ZERO)
			first = false
		else:
			result = result.expand(screen)
	return result
