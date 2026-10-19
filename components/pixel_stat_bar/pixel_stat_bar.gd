@tool
class_name PixelStatBar
extends Range
## Pixel meter with optional compact health and protection boxes.
## Instance pixel_stat_bar.tscn; use Range.value/max_value or set_amount().

const TILE_FRAME = preload("res://components/item_slot/item_frame.gd")

enum NumberMode { FRACTION, VALUE, PERCENTAGE, HIDDEN }

@export_group("Appearance")
@export var accent_color: Color = Color("e84061"):
	get:
		return _appearance_value("accent_color", Color("e84061"))
	set(next):
		_appearance_overrides["accent_color"] = next
		_refresh()
## Legacy serialized appearance property. The badge now cuts actual transparent
## geometry from the meter, so this color is retained for compatibility only.
@export var badge_color: Color = Color("11141f"):
	get:
		return _appearance_value("badge_color", Color("11141f"))
	set(next):
		_appearance_overrides["badge_color"] = next
		queue_redraw()
@export_range(1, 4, 1) var pixel_size: int = 2:
	get:
		return _appearance_value("pixel_size", 2)
	set(next):
		_appearance_overrides["pixel_size"] = clampi(next, 1, 4)
		_refresh()
@export_range(12, 64, 1) var bar_height: int = 28:
	get:
		return _appearance_value("bar_height", 28)
	set(next):
		_appearance_overrides["bar_height"] = maxi(next, 12)
		_refresh()

## Discrete resource points; empty slots remain visible after spending.
@export var segmented: bool = false:
	set(next):
		segmented = next
		_refresh()
@export var protection_pattern: bool = false:
	set(next):
		protection_pattern = next
		queue_redraw()

@export_range(4, 32, 1) var segment_width: int = 12:
	set(next):
		segment_width = maxi(4, next)
		_refresh()

var protection_amount: float = 0.0

## Protection changes the badge and pattern, never the health fill or maximum.
func set_protected_amount(health: float, maximum: float, protection: float) -> void:
	allow_greater = false
	protection_amount = maxf(0, protection)
	protection_pattern = protection > 0
	set_amount(health, maximum)

func resource_width() -> float:
	if max_value <= 0:
		return pixel_size * 16
	return max_value * (segment_width + pixel_size) - pixel_size + 6

## An empty result at nonzero capacity selects the continuous overflow meter.
func segment_rects(well: Rect2) -> Array[Rect2]:
	var result: Array[Rect2] = []
	var count: int = maxi(0, roundi(max_value))
	if count * (segment_width + pixel_size) - pixel_size > well.size.x:
		return result
	if count == 0:
		return result
	var available: float = well.size.x - pixel_size * (count - 1)
	for index in range(count):
		var start: float = floorf(available * index / count) + pixel_size * index
		var end: float = floorf(available * (index + 1) / count) + pixel_size * index
		result.append(Rect2(well.position + Vector2(start, 0), Vector2(end - start, well.size.y)))
	return result

@export_group("Glow")
## Optional steady highlight. Ordinary bars use the subdued palette.
@export var glow_enabled: bool = false:
	set(next):
		glow_enabled = next
		queue_redraw()
## Duration of an explicitly requested damage pulse.
@export_range(0.05, 2.0, 0.05) var glow_duration: float = 0.4

## Full-width health fill with current value left and optional protection right.
@export var side_boxes: bool = false:
	set(next):
		side_boxes = next
		_refresh()
@export_range(8, 24, 1) var side_number_size: int = 16:
	set(next):
		side_number_size = next
		_refresh()
@export var protection_icon: Texture2D
@export var protection_color: Color = Color("b9c4d2")

func _side_width(amount: float, with_icon: bool = false) -> float:
	var digits: int = maxi(2, str(roundi(amount)).length())
	var width: float = _font().get_string_size("8".repeat(digits), HORIZONTAL_ALIGNMENT_LEFT, -1, side_number_size).x
	return ceilf(width / pixel_size) * pixel_size + pixel_size * 4 + (14 if with_icon and protection_icon != null else 0)

func _side_height() -> float:
	return maxf(_meter_height(), ceilf(_font().get_height(side_number_size)) + pixel_size * 4)

func _draw_side_box(rect: Rect2, amount: float, color: Color, icon: Texture2D = null, caption: String = "") -> void:
	var span: float = 14 if icon != null else 0
	var text: String = caption if not caption.is_empty() else _number(amount)
	var width: float = _font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, side_number_size).x
	var x: float = floorf(rect.position.x + (rect.size.x - width - span) * 0.5)
	if icon != null:
		var icon_rect: Rect2 = Rect2(Vector2(x, floorf(rect.position.y + (rect.size.y - 12) * 0.5)), Vector2(12, 12))
		for offset: Vector2 in [Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 1), Vector2(0, 1), Vector2(1, 1)]:
			draw_texture_rect(icon, Rect2(icon_rect.position + offset, icon_rect.size), false, Color.BLACK)
		draw_texture_rect(icon, icon_rect, false, color)
	var baseline: float = floorf(rect.position.y + (rect.size.y - _font().get_height(side_number_size)) * 0.5 + _font().get_ascent(side_number_size))
	draw_string_outline(_font(), Vector2(x + span, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, side_number_size, 1, Color.BLACK)
	draw_string(_font(), Vector2(x + span, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, side_number_size, color)

func _plaque_health_width() -> float:
	var text: String = _number(max_value) + " / " + _number(max_value)
	return ceilf(_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, side_number_size).x) + pixel_size * 16

func _plaque_width() -> float:
	return _plaque_health_width() + (_side_width(protection_amount, true) + pixel_size * 6 if protection_amount > 0 else 0.0)

func _plaque_height() -> float:
	return ceilf(_font().get_height(side_number_size)) + pixel_size * 8

@export_group("Numbers")
## Optional semantic glyph before the numeric badge. The caller owns meaning
## and tint, keeping this reusable component independent of the game's registry.
@export var badge_icon: Texture2D:
	set(next):
		badge_icon = next
		_refresh()
@export var badge_icon_color: Color = Color.WHITE:
	set(next):
		badge_icon_color = next
		queue_redraw()
@export var number_mode: NumberMode = NumberMode.FRACTION:
	set(next):
		number_mode = next
		_refresh()
@export var number_font: Font = preload("pixel_font.tres"):
	get:
		return _appearance_value("number_font", preload("pixel_font.tres"))
	set(next):
		_appearance_overrides["number_font"] = next
		_refresh()
@export_range(8, 64, 1) var number_size: int = 32:
	get:
		return _appearance_value("number_size", 32)
	set(next):
		_appearance_overrides["number_size"] = maxi(next, 8)
		_refresh()
@export_range(0, 3, 1) var decimal_places: int = 0:
	set(next):
		decimal_places = clampi(next, 0, 3)
		_refresh()

var value_label: Label:
	get:
		return get_node_or_null("ValueLabel") as Label

var _glow_tween: Tween
var _glow_amount: float = 0.0:
	set(next):
		_glow_amount = clampf(next, 0.0, 1.0)
		queue_redraw()


func _ready() -> void:
	# Range supplies clamping, ratios, and the standard value_changed signal.
	if not value_changed.is_connected(_on_value_changed):
		value_changed.connect(_on_value_changed)
	if not changed.is_connected(_refresh):
		changed.connect(_refresh)
	if not resized.is_connected(_refresh):
		resized.connect(_refresh)
	if not visibility_changed.is_connected(_on_visibility_changed):
		visibility_changed.connect(_on_visibility_changed)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_refresh()

func _exit_tree() -> void:
	clear_glow()


## Flash once, then return to the configured appearance. Repeated hits restart
## the same pulse; changing values, healing, and resizing never trigger it.
func flash_glow(speed: float = 1.0) -> void:
	if not is_inside_tree() or not is_visible_in_tree() or Engine.is_editor_hint():
		return
	clear_glow()
	_glow_amount = 1.0
	_glow_tween = create_tween().set_speed_scale(clampf(speed, 0.5, 10.0))
	_glow_tween.tween_property(self, "_glow_amount", 0.0, maxf(0.05, glow_duration)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Cancel transient feedback without changing the optional steady highlight.
func clear_glow() -> void:
	_glow_was_paused = false
	if _glow_tween != null and _glow_tween.is_valid():
		_glow_tween.kill()
	_glow_tween = null
	_glow_amount = 0.0


func is_glowing() -> bool:
	return glow_enabled or _glow_amount > 0.0


func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		clear_glow()


## Convenience for health/mana/etc. A zero capacity displays 0 / 0, empty.
func set_amount(current: float, maximum: float) -> void:
	min_value = 0.0
	max_value = maxf(0.0, maximum)
	value = current
	_refresh()


func get_value_text() -> String:
	match number_mode:
		NumberMode.VALUE:
			return _number(value)
		NumberMode.PERCENTAGE:
			return "%d%%" % roundi(_fill_ratio() * 100.0)
		NumberMode.HIDDEN:
			return ""
		_:
			var text: String = "%s / %s" % [_number(value), _number(max_value)]
			return text + (" +" + _number(protection_amount) if protection_amount > 0 else "")


func _number(amount: float) -> String:
	return ("%." + str(decimal_places) + "f") % amount


func _font() -> Font:
	return number_font if number_font != null else get_theme_default_font()


func _label_height() -> float:
	return ceilf(_font().get_height(number_size) / pixel_size) * pixel_size


func _meter_height() -> float:
	return maxf(bar_height, pixel_size * 10)


func _badge_width() -> float:
	# Reserve enough width for any digit, so damage never makes the notch jump.
	var template: String = get_value_text()
	if number_mode == NumberMode.FRACTION:
		template = _number(min_value if absf(min_value) > absf(max_value) else max_value) + " / " + _number(max_value)
		if protection_amount > 0:
			template += " +" + _number(protection_amount)
	elif number_mode == NumberMode.VALUE:
		template = _number(min_value if absf(min_value) > absf(max_value) else max_value)
	elif number_mode == NumberMode.PERCENTAGE:
		template = "100%"
	var widest_digit: String = "0"
	var digit_width: float = 0.0
	for digit in "0123456789":
		var glyph_width: float = _font().get_string_size(digit, HORIZONTAL_ALIGNMENT_LEFT, -1, number_size).x
		if glyph_width > digit_width:
			digit_width = glyph_width
			widest_digit = digit
	var reserved: String = ""
	for character in template:
		reserved += widest_digit if character in "0123456789" else character
	var width: float = maxf(
		_font().get_string_size(reserved, HORIZONTAL_ALIGNMENT_LEFT, -1, number_size).x,
		_font().get_string_size(get_value_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, number_size).x
	)
	return ceilf(width / pixel_size) * pixel_size + pixel_size * 8 + _icon_span()

func _icon_span() -> float:
	return 22.0 if badge_icon != null and number_mode != NumberMode.HIDDEN else 0.0


func _get_minimum_size() -> Vector2:
	if side_boxes:
		return Vector2(_plaque_width() + pixel_size * 8, _plaque_height() + ceilf(_meter_height() * 0.5))
	if number_mode == NumberMode.HIDDEN:
		return Vector2(minf(pixel_size * 16, resource_width()) if segmented else pixel_size * 16, _meter_height())
	return Vector2(_badge_width() + pixel_size * 16, _label_height() - _overlap() + _meter_height())


func _overlap() -> float:
	return minf(pixel_size * 6, _label_height() * 0.5)


func _fill_ratio() -> float:
	if max_value <= min_value:
		return 0.0
	return clampf(ratio, 0.0, 1.0)


func _on_value_changed(_amount: float) -> void:
	_refresh()


func _refresh() -> void:
	if not is_inside_tree():
		return
	var label: Label = value_label
	if label != null:
		label.visible = number_mode != NumberMode.HIDDEN and not side_boxes
		label.text = get_value_text()
		label.add_theme_font_override("font", _font())
		label.add_theme_font_size_override("font_size", number_size)
		label.add_theme_color_override("font_color", accent_color)
		var width: float = _badge_width()
		label.position = Vector2(floorf((size.x - width) * 0.5 / pixel_size) * pixel_size + _icon_span(), maxf(0.0, floorf(size.y - _meter_height() - _label_height() + _overlap())))
		label.size = Vector2(width - _icon_span(), _label_height())
	update_minimum_size()
	queue_redraw()


func _draw() -> void:
	var p: float = pixel_size
	var meter: Rect2 = Rect2(0, floorf(size.y - _meter_height()), floorf(size.x), _meter_height())
	var badge: Rect2
	var cutouts: Array[Rect2] = []
	if not side_boxes and number_mode != NumberMode.HIDDEN and value_label != null:
		badge = value_label.get_rect()
		badge.position.x -= _icon_span()
		badge.size.x += _icon_span()
		badge.size.y -= p
		# Subtract the same two rectangles that form a stepped badge. Leaving
		# these pixels undrawn exposes any surface behind the component.
		cutouts.append(Rect2(badge.position + Vector2(p, 0), badge.size - Vector2(p * 2, 0)))
		cutouts.append(Rect2(badge.position + Vector2(0, p), badge.size - Vector2(0, p * 2)))
	var glow: float = 1.0 if glow_enabled else _glow_amount
	# Tile corner shape with a continuous 2px rim and a 1px transparent inner gap.
	var frame_masks: Dictionary = TILE_FRAME.skin([Vector2i.ZERO], meter.size, 0.0, [], true, self)
	var frame_origin: Vector2 = meter.position + frame_masks.origin
	var face_color: Color = accent_color.darkened(0.84)
	var border_color: Color = TILE_FRAME.rim_color(accent_color).lerp(TILE_FRAME.rim_color(accent_color).darkened(0.55), glow)
	draw_texture(frame_masks.fill, frame_origin, face_color)
	draw_texture(frame_masks.border, frame_origin, border_color)
	var well: Rect2 = meter.grow(-3)
	# Clip the resource fill to the exact inset mask, including stepped corners.
	for hole: Rect2 in _fill_holes(frame_masks, meter.size):
		cutouts.append(Rect2(hole.position + meter.position, hole.size))
	var fill_width: float = floorf(well.size.x * _fill_ratio() / p) * p
	if _fill_ratio() >= 1.0:
		fill_width = well.size.x
	elif _fill_ratio() > 0.0:
		fill_width = maxf(p, fill_width)
	var segments: Array[Rect2] = []
	if segmented:
		segments = segment_rects(well)
	if segmented and not segments.is_empty():
		for index in range(segments.size()):
			var cell: Rect2 = segments[index]
			_meter_rect(cell, accent_color.darkened(0.78), cutouts)
			if index < roundi(value):
				_meter_rect(cell, accent_color.darkened(0.36), cutouts)
				_meter_rect(Rect2(cell.position, Vector2(cell.size.x, p)), accent_color.darkened(0.3), cutouts)
	elif fill_width > 0.0:
		_meter_rect(Rect2(well.position, Vector2(fill_width, well.size.y)), accent_color.darkened(0.36).lerp(accent_color.darkened(0.22), glow), cutouts)
		_meter_rect(Rect2(well.position, Vector2(fill_width, p)), accent_color.darkened(0.3).lerp(accent_color.lightened(0.12), glow), cutouts)
		_meter_rect(Rect2(well.position + Vector2(0, well.size.y - p), Vector2(fill_width, p)), accent_color.darkened(0.48).lerp(accent_color.darkened(0.4), glow), cutouts)
	if protection_pattern and fill_width > 0.0:
		# Staggered mortar joints read as a protective brick wall.
		var filled: Rect2 = Rect2(well.position, Vector2(fill_width, well.size.y))
		for y in range(int(well.position.y), int(well.end.y), int(p * 4)):
			if y > well.position.y:
				_meter_rect(Rect2(well.position.x, y, fill_width, p), accent_color.darkened(0.58), cutouts)
			var stagger: int = int(p * 4) if int((y - well.position.y) / (p * 4)) % 2 else 0
			for x in range(int(well.position.x) + stagger, int(well.position.x + fill_width), int(p * 8)):
				_meter_rect(Rect2(x, y, p, p * 4).intersection(filled), accent_color.darkened(0.58), cutouts)
	if side_boxes:
		var plaque: Rect2 = Rect2(floorf((size.x - _plaque_width()) * 0.5), meter.position.y - _plaque_height() + floorf(meter.size.y * 0.5), _plaque_width(), _plaque_height())
		# The plaque is an opaque foreground panel: its inset gap must not
		# reveal the health fill through the lower half of the panel.
		for outline: PackedVector2Array in TILE_FRAME.polygons([Vector2i.ZERO], plaque.size, 0.0):
			var positioned: PackedVector2Array = PackedVector2Array()
			for point: Vector2 in outline:
				positioned.append(point + plaque.position)
			draw_colored_polygon(positioned, Color("141514"))
		var plaque_masks: Dictionary = TILE_FRAME.skin([Vector2i.ZERO], plaque.size, 0.0, [], true, self)
		var plaque_origin: Vector2 = plaque.position + plaque_masks.origin
		draw_texture(plaque_masks.fill, plaque_origin, Color("242622"))
		draw_texture(plaque_masks.border, plaque_origin, Color("74766b"))
		var health_width: float = _plaque_health_width()
		_draw_side_box(Rect2(plaque.position, Vector2(health_width, plaque.size.y)), value, badge_icon_color, null, _number(value) + " / " + _number(max_value))
		if protection_amount > 0:
			draw_rect(Rect2(plaque.position.x + health_width, plaque.position.y + p * 3, 1, plaque.size.y - p * 6), Color("505249"))
			_draw_side_box(Rect2(plaque.position.x + health_width, plaque.position.y, plaque.size.x - health_width, plaque.size.y), protection_amount, protection_color, protection_icon)
	if not side_boxes and number_mode != NumberMode.HIDDEN and badge_icon != null:
		var at: Vector2 = (badge.position + Vector2(p * 4, (badge.size.y - 16) * 0.5)).floor()
		draw_texture_rect(badge_icon, Rect2(at, Vector2(16, 16)), false, badge_icon_color)


var _fill_hole_cache: Dictionary = {}

func _fill_holes(masks: Dictionary, dimensions: Vector2) -> Array[Rect2]:
	if _fill_hole_cache.has(dimensions):
		return _fill_hole_cache[dimensions]
	var holes: Array[Rect2] = []
	var mask: Image = masks.fill.get_image()
	var origin: Vector2 = masks.origin
	for y in range(3, int(dimensions.y) - 3):
		var start: int = -1
		for x in range(3, int(dimensions.x) - 2):
			var empty: bool = x < int(dimensions.x) - 3 and mask.get_pixel(int(x - origin.x), int(y - origin.y)).a == 0.0
			if empty and start < 0:
				start = x
			elif not empty and start >= 0:
				holes.append(Rect2(start, y, x - start, 1))
				start = -1
	if _fill_hole_cache.size() >= 16:
		_fill_hole_cache.clear()
	_fill_hole_cache[dimensions] = holes
	return holes

func _stepped_rect(rect: Rect2, color: Color, cutouts: Array[Rect2] = []) -> void:
	# Filled integer rectangles, no rounded/antialiased edges or stretched art.
	var cut: float = pixel_size
	_meter_rect(Rect2(rect.position + Vector2(cut, 0), rect.size - Vector2(cut * 2, 0)), color, cutouts)
	_meter_rect(Rect2(rect.position + Vector2(0, cut), rect.size - Vector2(0, cut * 2)), color, cutouts)


func _meter_rect(rect: Rect2, color: Color, cutouts: Array[Rect2]) -> void:
	var fragments: Array[Rect2] = [rect]
	for cutout: Rect2 in cutouts:
		var remaining: Array[Rect2] = []
		for fragment: Rect2 in fragments:
			var overlap: Rect2 = fragment.intersection(cutout)
			if not overlap.has_area():
				remaining.append(fragment)
				continue
			# Nonoverlapping strips retain the original shading outside the hole.
			remaining.append(Rect2(fragment.position, Vector2(fragment.size.x, overlap.position.y - fragment.position.y)))
			remaining.append(Rect2(Vector2(fragment.position.x, overlap.end.y), Vector2(fragment.size.x, fragment.end.y - overlap.end.y)))
			remaining.append(Rect2(Vector2(fragment.position.x, overlap.position.y), Vector2(overlap.position.x - fragment.position.x, overlap.size.y)))
			remaining.append(Rect2(Vector2(overlap.end.x, overlap.position.y), Vector2(fragment.end.x - overlap.end.x, overlap.size.y)))
		fragments = remaining
	for fragment: Rect2 in fragments:
		if fragment.has_area():
			draw_rect(fragment, color)


# Shared appearance comes from the surrounding Theme. Setting an exported
# appearance property explicitly opts only that property out of inheritance.
# Stored separately so even an explicit value equal to the script default survives saving.
@export_storage var _appearance_overrides: Dictionary = {}

func _appearance_value(item: String, fallback: Variant) -> Variant:
	if _appearance_overrides.has(item):
		return _appearance_overrides[item]
	var kind: StringName = theme_type_variation if not theme_type_variation.is_empty() else &"PixelStatBar"
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
	_refresh()

func _validate_property(property: Dictionary) -> void:
	if property["name"] in ["accent_color", "badge_color", "pixel_size", "bar_height", "number_font", "number_size"] and not _appearance_overrides.has(property["name"]):
		property["usage"] = int(property["usage"]) & ~PROPERTY_USAGE_STORAGE
	pass

func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_refresh.call_deferred()

var _glow_was_paused: bool = false

func set_glow_paused(value: bool) -> void:
	if _glow_tween == null or not _glow_tween.is_valid():
		_glow_was_paused = false
		return
	if value and _glow_tween.is_running():
		_glow_tween.pause()
		_glow_was_paused = true
	elif not value and _glow_was_paused:
		_glow_was_paused = false
		_glow_tween.play()
