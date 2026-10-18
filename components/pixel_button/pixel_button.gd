@tool
class_name PackPixelButton
extends Button
## A native Button with a shared pixel skin and silhouette-aware pointer input.
## Instance components/pixel_button/pixel_button.tscn for the optional Content slot.

enum Silhouette { STEPPED, HEXAGON, DIAMOND, MASK, POLYGON }

@export_group("Pixel Style")
@export var face_color: Color = Color("#536b47"):
	get:
		return _appearance_value("face_color", Color("#536b47"))
	set(value):
		_appearance_overrides["face_color"] = value
		_invalidate()
@export var ink_color: Color = Color("#f0efdb"):
	get:
		return _appearance_value("ink_color", Color("#f0efdb"))
	set(value):
		_appearance_overrides["ink_color"] = value
		_invalidate()
## Size of one source pixel in UI units. Use integer display scaling as well.
@export_range(1, 4, 1) var pixel_size: int = 2:
	get:
		return _appearance_value("pixel_size", 2)
	set(value):
		_appearance_overrides["pixel_size"] = clampi(value, 1, 4)
		_invalidate()
@export_range(0.0, 0.12, 0.01) var texture_strength: float = 0.04:
	get:
		return _appearance_value("texture_strength", 0.04)
	set(value):
		_appearance_overrides["texture_strength"] = clampf(value, 0.0, 0.12)
		_invalidate()

@export_group("Silhouette")
@export var silhouette: Silhouette = Silhouette.STEPPED:
	set(value):
		silhouette = value
		_invalidate()
## Corner cut measured in source pixels; zero gives square corners.
@export_range(0, 16, 1) var corner_cut: int = 4:
	get:
		return _appearance_value("corner_cut", 4)
	set(value):
		_appearance_overrides["corner_cut"] = clampi(value, 0, 16)
		_invalidate()
## Equal-width #/. rows. Occupied cells join without internal borders.
## This is a UI silhouette, independent of inventory item source-art density.
@export var shape_mask: PackedStringArray = PackedStringArray(["#.", "##"]):
	set(value):
		shape_mask = value
		_invalidate()
## Simple polygon in normalized 0..1 coordinates, rasterized onto the pixel grid.
@export var shape_polygon: PackedVector2Array = PackedVector2Array([
	Vector2(0.25, 0), Vector2(0.75, 0), Vector2(1, 0.5),
	Vector2(0.75, 1), Vector2(0.25, 1), Vector2(0, 0.5)]):
	set(value):
		shape_polygon = value
		_invalidate()

@export_group("Content")
## Normalized rectangle for text, icon and Content. Place it inside an irregular face.
@export var content_region: Rect2 = Rect2(0, 0, 1, 1):
	set(value):
		content_region = value
		_invalidate()
@export var content_padding: Vector2i = Vector2i(12, 10):
	get:
		return _appearance_value("content_padding", Vector2i(12, 10))
	set(value):
		_appearance_overrides["content_padding"] = Vector2i(maxi(0, value.x), maxi(0, value.y))
		_invalidate()

var _dirty: bool = false
var _grid: Vector2i = Vector2i.ZERO
var _mask: PackedByteArray = PackedByteArray()
var _content: Control
var _content_rect: Rect2
var _last_content_state: int = -1
var _skin_signature: String = ""

func _enter_tree() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_content = get_node_or_null("Content") as Control
	if _content != null:
		_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_content.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
		_content.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
	if not resized.is_connected(_invalidate):
		resized.connect(_invalidate)
	if not toggled.is_connected(_on_toggled):
		toggled.connect(_on_toggled)
	_invalidate()

func _on_toggled(_pressed: bool) -> void:
	_sync_content()

func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_invalidate()
	if what == NOTIFICATION_DRAW:
		_sync_content()

func _invalidate() -> void:
	if not is_inside_tree() or _dirty:
		return
	_dirty = true
	_rebuild.call_deferred()

func _validate_property(property: Dictionary) -> void:
	if property["name"] in ["face_color", "ink_color", "pixel_size", "texture_strength", "corner_cut", "content_padding"] and not _appearance_overrides.has(property["name"]):
		property["usage"] = int(property["usage"]) & ~PROPERTY_USAGE_STORAGE
	# Generated StyleBoxes exclude cached textures through runtime_pixel_style.gd.

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = PackedStringArray()
	if silhouette == Silhouette.MASK and not _valid_mask():
		warnings.append("Use nonempty, equal-width #/. mask rows with at least one #. Invalid masks use the stepped rectangle.")
	if silhouette == Silhouette.POLYGON and not _valid_polygon():
		warnings.append("Use a simple polygon with at least three points in 0..1. Invalid polygons use the stepped rectangle.")
	if content_region.size.x <= 0 or content_region.size.y <= 0 or not Rect2(0, 0, 1, 1).encloses(content_region):
		warnings.append("Content Region must be a nonempty rectangle within 0..1. Invalid regions use the whole button.")
	return warnings

func _valid_mask() -> bool:
	if shape_mask.is_empty() or shape_mask[0].is_empty():
		return false
	var occupied: bool = false
	for row: String in shape_mask:
		if row.length() != shape_mask[0].length():
			return false
		for mark: String in row:
			if mark != "#" and mark != ".":
				return false
			occupied = occupied or mark == "#"
	return occupied

func _valid_polygon() -> bool:
	if shape_polygon.size() < 3:
		return false
	for point: Vector2 in shape_polygon:
		if not point.is_finite() or point.x < 0 or point.y < 0 or point.x > 1 or point.y > 1:
			return false
	return not Geometry2D.triangulate_polygon(shape_polygon).is_empty()

func _region() -> Rect2:
	if content_region.size.x <= 0 or content_region.size.y <= 0 or not Rect2(0, 0, 1, 1).encloses(content_region):
		return Rect2(0, 0, 1, 1)
	return content_region

func _rebuild() -> void:
	_dirty = false
	if not is_inside_tree():
		return
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if not is_instance_valid(_content):
		_content = get_node_or_null("Content") as Control
	if _content != null:
		_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_content.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
		_content.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
	var signature: String = str([size, face_color, ink_color, pixel_size, texture_strength, silhouette, corner_cut, shape_mask, shape_polygon, content_region, content_padding])
	if signature == _skin_signature:
		return
	_skin_signature = signature
	var target_size: Vector2i = Vector2i(maxi(1, ceili(size.x)), maxi(1, ceili(size.y)))
	var styles: Dictionary = create_styleboxes(target_size)
	for state: String in styles:
		add_theme_stylebox_override(state, styles[state])
	for state: String in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		add_theme_color_override(state, ink_color)
	add_theme_color_override("font_disabled_color", ink_color.lerp(Color("#637079"), 0.64))
	add_theme_color_override("icon_disabled_color", Color(0.48, 0.48, 0.48, 1))
	var region: Rect2 = _region()
	_content_rect = Rect2(
		(region.position * size + Vector2(content_padding)).round(),
		(region.size * size - Vector2(content_padding * 2) - Vector2(0, 2 * pixel_size)).max(Vector2.ZERO).floor())
	_last_content_state = -1
	_sync_content()
	update_configuration_warnings()
	queue_redraw()

## Share the exact skin with native controls such as TabContainer.
## May be called on an off-tree instance; does not add nodes or assign a Theme.
func create_styleboxes(target_size: Vector2i) -> Dictionary:
	_grid = Vector2i(maxi(1, ceili(float(target_size.x) / pixel_size)), maxi(1, ceili(float(target_size.y) / pixel_size)))
	_rasterize()
	var styles: Dictionary = {}
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style: StyleBoxTexture = StyleBoxTexture.new()
		style.set_script(preload("res://components/runtime_pixel_style.gd"))
		style.texture = ImageTexture.create_from_image(_paint(state, target_size))
		if state != "focus":
			_set_margins(style, state == "pressed")
		styles[state] = style
	styles["hover_pressed"] = styles["pressed"]
	return styles

func _set_margins(style: StyleBoxTexture, pushed: bool) -> void:
	var region: Rect2 = _region()
	var shift: int = pixel_size if pushed else 0
	style.content_margin_left = roundf(region.position.x * size.x) + content_padding.x
	style.content_margin_right = roundf((1.0 - region.end.x) * size.x) + content_padding.x
	style.content_margin_top = roundf(region.position.y * size.y) + content_padding.y + shift
	style.content_margin_bottom = roundf((1.0 - region.end.y) * size.y) + content_padding.y + 2 * pixel_size - shift

func _sync_content() -> void:
	if not is_instance_valid(_content):
		return
	var pushed: bool = get_draw_mode() in [BaseButton.DRAW_PRESSED, BaseButton.DRAW_HOVER_PRESSED]
	var state: int = 2 if disabled else (1 if pushed else 0)
	if state == _last_content_state:
		return
	_last_content_state = state
	_content.position = _content_rect.position + Vector2(0, pixel_size if pushed else 0)
	_content.size = _content_rect.size
	_content.modulate = Color(0.48, 0.48, 0.48, 1) if disabled else Color.WHITE

func _rasterize() -> void:
	_mask.resize(_grid.x * _grid.y)
	_mask.fill(0)
	var height: int = maxi(1, _grid.y - 2)
	var use_mask: bool = silhouette == Silhouette.MASK and _valid_mask()
	var points: PackedVector2Array = PackedVector2Array()
	match silhouette:
		Silhouette.HEXAGON:
			points = PackedVector2Array([Vector2(0.25, 0), Vector2(0.75, 0), Vector2(1, 0.5), Vector2(0.75, 1), Vector2(0.25, 1), Vector2(0, 0.5)])
		Silhouette.DIAMOND:
			points = PackedVector2Array([Vector2(0.5, 0), Vector2(1, 0.5), Vector2(0.5, 1), Vector2(0, 0.5)])
		Silhouette.POLYGON:
			if _valid_polygon():
				points = shape_polygon
	var cut: int = mini(corner_cut, mini(_grid.x, height) / 2)
	for y: int in range(height):
		for x: int in range(_grid.x):
			var point: Vector2 = Vector2((x + 0.5) / _grid.x, (y + 0.5) / height)
			var inside: bool
			if use_mask:
				var row: int = mini(int(point.y * shape_mask.size()), shape_mask.size() - 1)
				var column: int = mini(int(point.x * shape_mask[0].length()), shape_mask[0].length() - 1)
				inside = shape_mask[row][column] == "#"
			elif not points.is_empty():
				inside = Geometry2D.is_point_in_polygon(point, points)
			else:
				inside = mini(x, _grid.x - 1 - x) + mini(y, height - 1 - y) >= cut
			_mask[y * _grid.x + x] = 1 if inside else 0

func _sample(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= _grid.x or y >= _grid.y:
		return 0
	return _mask[y * _grid.x + x]

func _paint(state: String, target_size: Vector2i) -> Image:
	var face: Color = face_color
	face.a = 1.0
	if state == "hover":
		face = face.lightened(0.12)
	elif state == "pressed":
		face = face.darkened(0.16)
	elif state == "disabled":
		var grey: float = face.get_luminance()
		face = face.lerp(Color(grey, grey, grey), 0.75).darkened(0.40)
	var picture: Image = preload("res://components/button_frame.gd").paint(
		_grid, _mask, face, face.lightened(0.22) if state == "focus" else face,
		state == "focus", 1 if state == "pressed" else 0)
	picture.resize(_grid.x * pixel_size, _grid.y * pixel_size, Image.INTERPOLATE_NEAREST)
	return picture.get_region(Rect2i(Vector2i.ZERO, target_size))

func _has_point(point: Vector2) -> bool:
	if not Rect2(Vector2.ZERO, size).has_point(point):
		return false
	# Flush pending configuration changes before accepting pointer input.
	if _dirty:
		_rebuild()
	if _mask.is_empty():
		return false
	return _sample(floori(point.x / pixel_size), floori(point.y / pixel_size)) != 0


# Shared appearance comes from the surrounding Theme. Setting an exported
# appearance property explicitly opts only that property out of inheritance.
# Stored separately so even an explicit value equal to the script default survives saving.
@export_storage var _appearance_overrides: Dictionary = {}

func _appearance_value(item: String, fallback: Variant) -> Variant:
	if _appearance_overrides.has(item):
		return _appearance_overrides[item]
	var kind: StringName = theme_type_variation if not theme_type_variation.is_empty() else &"PackPixelButton"
	if fallback is Color and has_theme_color(item, kind):
		return get_theme_color(item, kind)
	if fallback is int and has_theme_constant(item, kind):
		return get_theme_constant(item, kind)
	if fallback is float and has_theme_constant(item, kind):
		return get_theme_constant(item, kind) / 100.0
	if fallback is Vector2i and has_theme_constant(item + "_x", kind):
		return Vector2i(get_theme_constant(item + "_x", kind), get_theme_constant(item + "_y", kind))
	if fallback is Font and has_theme_font(item, kind):
		return get_theme_font(item, kind)
	return fallback

@export_tool_button("Reset Appearance to Theme") var reset_appearance: Callable = reset_appearance_overrides

func reset_appearance_overrides() -> void:
	_appearance_overrides.clear()
	notify_property_list_changed()
	_invalidate()
