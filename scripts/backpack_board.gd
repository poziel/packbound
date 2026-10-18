class_name BackpackBoard
extends Control

signal changed
signal selected(item: Dictionary)
signal item_hovered
signal priority_edit_started
signal feedback(message: String, valid: bool)

const SOURCE_CELL: int = 32
const DISPLAY_SCALE: int = 2
const CELL: float = SOURCE_CELL * DISPLAY_SCALE
const STEP: float = CELL + 4.0
const ORIGIN: Vector2 = Vector2(22, 14)
const GRID_RECT: Rect2 = Rect2(ORIGIN, Vector2(PackRun.GRID) * STEP - Vector2.ONE * (STEP - CELL))
const ITEM_TOOLTIP: PackedScene = preload("res://scenes/shared/item_tooltip.tscn")
const ITEM_FRAME = preload("res://components/item_slot/item_frame.gd")
const BONUS_EDGE = preload("res://assets/ui/icons/adjacency-carets-v3/edge-inward.png")
const BONUS_CORNER = preload("res://assets/ui/icons/adjacency-carets-v3/corner-inward.png")

var run: PackRun
var dragging: Dictionary = {}
var cursor_held: bool = false
var suppress_left_release: bool = false
const SLIDE_SECONDS: float = 0.22
const STASH_FLIGHT_SECONDS: float = 0.38
var item_motions: Dictionary = {}
var _art_scale: float = 1.0
var _art_origin: Vector2 = Vector2.ZERO
var drag_shape: Vector2i = Vector2i.ONE
var drag_rotation: int = 0
var grab: Vector2 = Vector2.ZERO
var pointer: Vector2 = Vector2.ZERO
var throw_velocity: Vector2 = Vector2.ZERO
var throw_time_msec: int = 0
var held_rotation_offset: float = 0.0
var _rotation_anim_from: float = 0.0
var _rotation_anim_time: float = 0.16
var _drawing_held: bool = false
var _rotation_pivot := Vector2.ZERO
var hovered_id: int = -1
var selected_id: int = -1
var storage: Control
var storage_button: Control
var icons: Dictionary = {}
var tooltips_enabled: bool = true
var managed_inspection: bool = false
var draw_effects: Dictionary = {}
var _bonus_related: Array[int] = []
const FAILED_ACTIVATION_SECONDS: float = 0.65
var failed_activations: Dictionary = {}
var activation_feedback_paused: bool = false
var effect_popups: Array[Dictionary] = []
const EFFECT_POPUP = preload("res://scripts/combat_effect_popup.gd")
var _popup_rng := RandomNumberGenerator.new()

func show_item_effects(result: Dictionary, speed: float = 1.0, response: bool = false) -> void:
	var lanes: Dictionary = {}
	for effect: Dictionary in result.get("response_item_effects" if response else "item_effects", []):
		var key: String = effect["key"]
		if response and not result.get("playback_strikes", false):
			continue
		for item: Dictionary in run.packed():
			if item["id"] != effect["id"] or not PackKeywords.has_icon(key):
				continue
			var lane: int = lanes.get(item["id"], 0)
			lanes[item["id"]] = lane + 1
			var sample: Callable = func() -> Vector2:
				var cells: Array[Vector2i] = PackRun.offsets(item)
				var center: Vector2 = footprint(item["shape"]) * 0.5
				var weights := PackedFloat32Array()
				for cell: Vector2i in cells:
					weights.append(1.0 / (1.0 + (Vector2(cell) * STEP + Vector2.ONE * CELL * 0.5).distance_to(center) / CELL))
				var cell: Vector2i = cells[_popup_rng.rand_weighted(weights)]
				var jitter := Vector2(_popup_rng.randf() + _popup_rng.randf() - 1, _popup_rng.randf() + _popup_rng.randf() - 1) * CELL * 0.38
				return item_rect(item).position + Vector2(cell) * STEP + Vector2.ONE * CELL * 0.5 + jitter
			EFFECT_POPUP.append(effect_popups, key, int(effect["amount"]), sample, GRID_RECT.grow(-18), _popup_rng, speed, lane)
	queue_redraw()

func _draw_effect_popups() -> void:
	EFFECT_POPUP.draw(self, effect_popups)

func flash_failed_activations(ids: Array, speed: float = 1.0) -> void:
	for id: int in ids:
		failed_activations[id] = FAILED_ACTIVATION_SECONDS / clampf(speed, 0.5, 10.0)
	queue_redraw()

func clear_activation_feedback() -> void:
	effect_popups.clear()
	failed_activations.clear()
	activation_feedback_paused = false
	queue_redraw()

func set_activation_feedback_paused(value: bool) -> void:
	activation_feedback_paused = value

func _process(delta: float) -> void:
	if _rotation_anim_time < 0.16:
		_rotation_anim_time = minf(0.16, _rotation_anim_time + delta)
		var t: float = _rotation_anim_time / 0.16
		held_rotation_offset = lerpf(_rotation_anim_from, 0.0, t * t * (3.0 - 2.0 * t))
		queue_redraw()
	if not item_motions.is_empty():
		for id: int in item_motions.keys():
			var motion: Dictionary = item_motions[id]
			motion["elapsed"] += delta
			if motion["elapsed"] >= motion["duration"]:
				item_motions.erase(id)
		if dragging.is_empty() and item_motions.is_empty():
			z_index = 0
		refresh()
	if activation_feedback_paused:
		return
	if not effect_popups.is_empty():
		EFFECT_POPUP.advance(effect_popups, delta)
		queue_redraw()
	for id: int in failed_activations.keys():
		failed_activations[id] = maxf(0.0, float(failed_activations[id]) - delta)
		if is_zero_approx(failed_activations[id]):
			failed_activations.erase(id)
	queue_redraw()

func _ready() -> void:
	mouse_exited.connect(_clear_hover)
	visibility_changed.connect(_clear_hover)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tooltip_text = "Item"

static func has_activation_priority(item: Dictionary) -> bool:
	return item.get("role", "") in ["weapon", "ranged", "spell"] or int(item.get("cost", 0)) > 0 or int(item.get("stamina_cost", 0)) > 0

static func priority_corner(points: Array[Vector2i]) -> Vector2i:
	var corner: Vector2i = points[0]
	for point in points:
		if point.y < corner.y or (point.y == corner.y and point.x < corner.x):
			corner = point
	return corner

func _adjust_priority(item: Dictionary, direction: int) -> void:
	if not run.can_edit_inventory() or not has_activation_priority(item):
		return
	var priority: int = posmod(int(item.get("priority", 0)) + direction, PackRun.MAX_ITEM_PRIORITY + 1)
	priority_edit_started.emit()
	if run.set_item_priority(int(item["id"]), priority):
		feedback.emit("No priority · activates after numbered items" if priority == 0 else "Activation priority %d" % priority, true)
		changed.emit()
		refresh()

func _clear_hover() -> void:
	hovered_id = -1
	queue_redraw()

## Contacts belong to the receiving footprint. Wrapped contacts retain the
## direction through the seam rather than pointing across the whole backpack.
func bonus_markers(target: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if run == null or target.get("cell") == null or target == dragging or item_motions.has(target["id"]):
		return result
	for source in run.items:
		if source == dragging or item_motions.has(source["id"]) or run.bonus(source, target) <= 0:
			continue
		var contacts: Array[Dictionary] = []
		var has_edge := false
		for receiver in run.cells(target):
			for supplier in run.cells(source):
				var direction: Vector2i = supplier - receiver
				if run.relics.has("folded_space") and absi(direction.x) > PackRun.GRID.x / 2:
					direction.x -= signi(direction.x) * PackRun.GRID.x
				var edge: bool = absi(direction.x) + absi(direction.y) == 1
				var diagonal: bool = absi(direction.x) == 1 and absi(direction.y) == 1
				if not edge and not (diagonal and run.relics.has("diagonal_thread")):
					continue
				has_edge = has_edge or edge
				contacts.append({"cell": receiver - Vector2i(target["cell"]), "direction": direction, "source_id": int(source["id"])})
		# A long shared edge must not also advertise spurious corner contacts
		# from neighboring cells of the same supplier.
		for contact in contacts:
			var direction: Vector2i = contact.direction
			if has_edge and direction.x != 0 and direction.y != 0:
				continue
			if direction.x == 0 or direction.y == 0:
				var along := Vector2i.DOWN if direction.x != 0 else Vector2i.RIGHT
				var cell: Vector2i = contact.cell
				if contacts.any(func(other: Dictionary) -> bool: return other.direction == direction and other.cell == cell - along):
					continue
				var span := 1
				while contacts.any(func(other: Dictionary) -> bool: return other.direction == direction and other.cell == cell + along * span):
					span += 1
				contact["span"] = span
			result.append(contact)
	return result

func bonus_related_ids() -> Array[int]:
	var result: Array[int] = []
	if run == null or hovered_id < 0 or not dragging.is_empty():
		return result
	for target in run.items:
		for marker in bonus_markers(target):
			var related_id: int = -1
			if int(target["id"]) == hovered_id:
				related_id = marker.source_id
			elif int(marker.source_id) == hovered_id:
				related_id = int(target["id"])
			if related_id >= 0 and not result.has(related_id):
				result.append(related_id)
	return result

func _draw_bonus_markers(item: Dictionary, at: Vector2, color: Color, opacity: float) -> void:
	var drawn: Dictionary = {}
	for marker in bonus_markers(item):
		var key: String = str([marker.cell, marker.direction, marker.get("span", 1)])
		if drawn.has(key):
			continue
		drawn[key] = true
		var direction: Vector2i = marker.direction
		var center: Vector2 = Vector2(marker.cell) * STEP + Vector2.ONE * CELL / 2
		color.a = opacity
		var diagonal: bool = direction.x != 0 and direction.y != 0
		var texture: Texture2D = BONUS_CORNER if diagonal else BONUS_EDGE
		var angle: float
		if diagonal:
			center += Vector2(direction) * CELL / 2
			angle = Vector2(-direction).angle() - PI / 4
			if direction == Vector2i(-1, -1) and has_activation_priority(item) and int(item.get("priority", 0)) > 0 and marker.cell == priority_corner(PackRun.offsets(item)):
				# Attach beside the priority compartment instead of covering its numeral.
				center.x += 18
		else:
			var along := Vector2.DOWN if direction.x != 0 else Vector2.RIGHT
			center += along * STEP * (int(marker.get("span", 1)) - 1) / 2.0
			center += Vector2(direction) * CELL / 2
			angle = Vector2(-direction).angle()
		# Only exact quarter-turns and integer 2x pixels; no diagonal resampling.
		var display_center: Vector2 = (_art_origin + (at + center - _art_origin) * _art_scale).round()
		draw_set_transform(display_center, angle, Vector2.ONE * _art_scale)
		var caret_rect := Rect2(Vector2.ZERO if diagonal else Vector2(0, -7), Vector2(14, 14))
		draw_texture_rect(texture, caret_rect, false, color)
	draw_set_transform(Vector2.ZERO)

func _get_tooltip(at_position: Vector2) -> String:
	if managed_inspection or not tooltips_enabled or run == null or not dragging.is_empty() or run.phase != PackRun.Phase.FIGHT:
		return ""
	var item: Dictionary = hit_item(at_position)
	return str(item["id"]) if not item.is_empty() else ""

func _make_custom_tooltip(for_text: String) -> Object:
	var item: Dictionary = {}
	for candidate_item in run.items:
		if str(candidate_item["id"]) == for_text:
			item = candidate_item
			break
	if item.is_empty():
		return null
	var details: Control = ITEM_TOOLTIP.instantiate()
	details.set_item(item, run.item_bonus(item))
	return details

func refresh() -> void:
	if storage != null:
		storage.refresh()
	queue_redraw()

func unpacked() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in run.items:
		if item["cell"] == null and not (cursor_held and item == dragging):
			result.append(item)
	return result

func footprint(shape: Vector2i) -> Vector2:
	return Vector2(shape) * STEP - Vector2.ONE * (STEP - CELL)

func item_rect(item: Dictionary) -> Rect2:
	if item["cell"] != null:
		return Rect2(ORIGIN + Vector2(item["cell"]) * STEP, footprint(item["shape"]))
	if storage != null:
		var rect: Rect2 = storage.item_rect(item)
		rect.position -= global_position
		return rect
	return Rect2()

func icon(key: String) -> Texture2D:
	if not icons.has(key):
		icons[key] = PackArt.item(key)
	return icons[key]

func _footprint_polygons(points: Array[Vector2i], inset: float = 0.0) -> Array[PackedVector2Array]:
	return ITEM_FRAME.polygons(points, Vector2.ONE * CELL, STEP - CELL, inset)

## Presentation-only overrides keyed by item ID; cell/side refer to the displayed rotation.
var item_border_segments: Dictionary = {}

func set_item_border_segments(item_id: int, segments: Array[Dictionary]) -> void:
	item_border_segments[item_id] = segments
	queue_redraw()

var _covered_empty_cells: Dictionary = {}

func _cover_empty_cells(at: Vector2, points: Array[Vector2i], art_scale: float = 1.0) -> void:
	for point in points:
		var occupied_rect := Rect2(at + Vector2(point) * STEP * art_scale, Vector2.ONE * CELL * art_scale)
		var first := Vector2i(((occupied_rect.position - ORIGIN) / STEP).floor()).clamp(Vector2i.ZERO, PackRun.GRID - Vector2i.ONE)
		var last := Vector2i(((occupied_rect.end - ORIGIN) / STEP).floor()).clamp(Vector2i.ZERO, PackRun.GRID - Vector2i.ONE)
		for y in range(first.y, last.y + 1):
			for x in range(first.x, last.x + 1):
				var cell := Vector2i(x, y)
				if occupied_rect.intersects(Rect2(ORIGIN + Vector2(cell) * STEP, Vector2.ONE * CELL)):
					_covered_empty_cells[cell] = true

func _sync_empty_cells() -> void:
	for y in range(PackRun.GRID.y):
		for x in range(PackRun.GRID.x):
			var panel: CanvasItem = get_node_or_null("Cell%d_%d" % [x + 1, y + 1])
			if panel != null:
				# Socket children must render behind the parent's moving item art.
				panel.show_behind_parent = true
				panel.visible = not _covered_empty_cells.has(Vector2i(x, y))

func _draw_footprint(at: Vector2, points: Array[Vector2i], accent: Color, highlighted: bool = false, border_segments: Array[Dictionary] = []) -> void:
	_item_transform(at)
	ITEM_FRAME.draw_frame(self, points, Vector2.ONE * CELL, STEP - CELL, accent, true, highlighted, border_segments)
	draw_set_transform(Vector2.ZERO)

func _draw_item_art(item: Dictionary, rect: Rect2, points: Array[Vector2i], rotation: int, alpha: Color) -> void:
	var texture: Texture2D = icon(item["key"])
	var region: Rect2 = Rect2(Vector2.ZERO, texture.get_size())
	# Polygon UVs refer to the underlying atlas, not the AtlasTexture region.
	if texture is AtlasTexture:
		region = texture.region
		texture = texture.atlas
	var art_rect: Rect2 = Rect2(Vector2.ZERO, rect.size).grow(-4)
	if region.size == Vector2(32, 32) and item["shape"] == Vector2i.ONE:
		# Native sprites already contain padding: map 32 px to the full 64 px cell.
		art_rect = Rect2(Vector2.ZERO, rect.size)
	_item_transform(rect.position)
	for polygon in _footprint_polygons(points, 4.0):
		var uvs: PackedVector2Array = PackedVector2Array()
		for vertex in polygon:
			var uv: Vector2 = (vertex - art_rect.position) / art_rect.size
			for quarter in range(posmod(rotation, 4)):
				uv = Vector2(uv.y, 1.0 - uv.x)
			uvs.append((region.position + uv * region.size) / texture.get_size())
		draw_polygon(polygon, PackedColorArray([alpha]), uvs, texture)
	draw_set_transform(Vector2.ZERO)

func _draw() -> void:
	_covered_empty_cells.clear()
	if run == null:
		_sync_empty_cells()
		return
	var plan: Array[Dictionary] = candidate_plan()
	draw_effects = preview_effects()
	_bonus_related = bonus_related_ids()
	# Empty sockets live in backpack.tscn and use the same shared item frame.
	for item in run.items:
		if item["cell"] != null and item != dragging and not item_motions.has(item["id"]):
			# Only settled items replace the sockets they actually occupy.
			_cover_empty_cells(item_rect(item).position, PackRun.offsets(item))
			_draw_item(item, item_rect(item))
	for motion: Dictionary in item_motions.values():
		var t: float = clampf(motion["elapsed"] / motion["duration"], 0.0, 1.0)
		var eased: float = t * t * (3.0 - 2.0 * t)
		var at: Vector2 = _motion_position(motion)
		var art_scale: float = 1.0
		if motion["stash"]:
			art_scale = lerpf(1.0, 0.25, eased)
		_draw_item(motion["item"], Rect2(at, footprint(motion["item"]["shape"])), false, 1.0, art_scale)
	if not dragging.is_empty():
		var target: Vector2i = candidate()
		var valid: bool = not plan.is_empty()
		if GRID_RECT.grow(12).has_point(pointer):
			# Preview is an outline, not committed occupancy. Keep all empty
			# sockets beneath it visible as the pointer moves between snap cells.
			var masks: Dictionary = ITEM_FRAME.skin(PackRun.offsets(dragging, drag_rotation), Vector2.ONE * CELL, STEP - CELL)
			draw_texture(masks.border, ORIGIN + Vector2(target) * STEP + masks.origin, Color("9cdbaf") if valid else Color("f08086"))
		if storage == null or storage.grabbed == null:
			_drawing_held = true
			var square: bool = drag_shape.x == drag_shape.y and dragging["mask"].size() == drag_shape.x * drag_shape.y
			_rotation_pivot = pointer - grab + footprint(drag_shape) * 0.5 if square else pointer
			_draw_item(dragging, Rect2(pointer - grab, footprint(drag_shape)), true)
			_drawing_held = false
	_sync_empty_cells()
	_draw_effect_popups()

func _item_transform(at: Vector2) -> void:
	var position: Vector2 = (_art_origin + (at - _art_origin) * _art_scale).round()
	if _drawing_held:
		draw_set_transform(_rotation_pivot + (position - _rotation_pivot).rotated(held_rotation_offset), held_rotation_offset, Vector2.ONE * _art_scale)
	else:
		draw_set_transform(position, 0.0, Vector2.ONE * _art_scale)

func _draw_item(item: Dictionary, rect: Rect2, ghost: bool = false, opacity: float = 1.0, art_scale: float = 1.0) -> void:
	_art_origin = rect.position
	_art_scale = art_scale
	var tint: Color = PackArt.color(item["key"])
	var highlighted: bool = int(item["id"]) in [hovered_id, selected_id] or ghost
	var related: bool = not ghost and _bonus_related.has(int(item["id"]))
	var rotation: int = drag_rotation if ghost else int(item["rotation"])
	var points: Array[Vector2i] = PackRun.offsets(item, rotation)
	_draw_footprint(rect.position, points, tint, highlighted, item_border_segments.get(int(item["id"]), [] as Array[Dictionary]))
	var alpha: Color = Color(1, 1, 1, 0.35) if draw_effects.get("dormant_ids", []).has(item["id"]) else Color.WHITE
	alpha.a *= opacity
	_draw_item_art(item, rect, points, rotation, alpha)
	if related:
		_item_transform(rect.position)
		var masks: Dictionary = ITEM_FRAME.skin(points, Vector2.ONE * CELL, STEP - CELL)
		draw_texture(masks.fill, masks.origin, Color(1.0, 0.78, 0.38, 0.10 * opacity))
		draw_texture(masks.border, masks.origin, Color(1.0, 0.85, 0.55, opacity))
		draw_set_transform(Vector2.ZERO)
	if has_activation_priority(item):
		_item_transform(rect.position)
		ITEM_FRAME.draw_priority_corner(self, Vector2(priority_corner(points)) * STEP, get_theme_default_font(), int(item.get("priority", 0)), tint, highlighted, opacity)
		draw_set_transform(Vector2.ZERO)
	if not ghost:
		var marker_color: Color = Color(1.0, 0.85, 0.55) if related else ITEM_FRAME.rim_color(tint, highlighted)
		_draw_bonus_markers(item, rect.position, marker_color, opacity)
	if not ghost and failed_activations.has(item["id"]):
		# Paint the occupied silhouette, including dimmed art, so a failed attempt
		# remains visible without changing activation eligibility or damage.
		var strength: float = clampf(float(failed_activations[item["id"]]) / 0.16, 0.0, 1.0)
		_item_transform(rect.position)
		for polygon in _footprint_polygons(points, 3.0):
			draw_colored_polygon(polygon, Color(1.0, 0.13, 0.16, 0.6 * strength * opacity))
		draw_set_transform(Vector2.ZERO)
	_art_scale = 1.0

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and dragging.is_empty():
		pointer = event.position
		var item: Dictionary = hit_item(pointer)
		var next_id: int = int(item.get("id", -1))
		if next_id != hovered_id:
			hovered_id = next_id
			if hovered_id >= 0:
				item_hovered.emit()
		if not item.is_empty():
			selected.emit(item)
		queue_redraw()
	if event is InputEventMouseButton and event.pressed and dragging.is_empty():
		pointer = event.position
		if event.ctrl_pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			var item: Dictionary = hit_item(pointer)
			if not item.is_empty():
				_adjust_priority(item, 1 if event.button_index == MOUSE_BUTTON_LEFT else -1)
			accept_event()
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			var item: Dictionary = hit_item(pointer)
			if not item.is_empty() and run.phase == PackRun.Phase.FIGHT:
				if event.shift_pressed and storage != null:
					storage.quick_transfer(item)
				else:
					begin_drag(item, pointer)
			accept_event()

func hit_item(at: Vector2) -> Dictionary:
	for item in run.items:
		if item["cell"] == null or item_motions.has(item["id"]):
			continue
		var local: Vector2 = at - item_rect(item).position
		for polygon in _footprint_polygons(PackRun.offsets(item)):
			if Geometry2D.is_point_in_polygon(local, polygon):
				return item
	return {}

func _nearest_grab_center(item: Dictionary, local: Vector2) -> Vector2:
	var nearest: Vector2 = Vector2.ZERO
	var best_distance: float = INF
	for cell in PackRun.offsets(item):
		var center: Vector2 = Vector2(cell) * STEP + Vector2.ONE * CELL * 0.5
		var distance: float = local.distance_squared_to(center)
		if distance < best_distance or (is_equal_approx(distance, best_distance) and (center.y < nearest.y or (center.y == nearest.y and center.x < nearest.x))):
			nearest = center
			best_distance = distance
	return nearest

func begin_drag(item: Dictionary, at: Vector2) -> void:
	held_rotation_offset = 0.0
	_rotation_anim_time = 0.16
	throw_velocity = Vector2.ZERO
	throw_time_msec = 0
	if not run.can_edit_inventory():
		return
	dragging = item
	cursor_held = false
	z_index = 50
	drag_shape = item["shape"]
	drag_rotation = int(item["rotation"])
	pointer = at
	grab = _nearest_grab_center(item, at - item_rect(item).position) if item["cell"] != null else Vector2(PackRun.offsets(item)[0]) * STEP + Vector2.ONE * CELL * 0.5
	selected_id = int(item["id"])
	selected.emit(item)
	changed.emit()
	refresh()

func _input(event: InputEvent) -> void:
	if storage != null and storage.grabbed != null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and suppress_left_release:
		suppress_left_release = false
		get_viewport().set_input_as_handled()
		return
	if dragging.is_empty():
		return
	var previous_pointer: Vector2 = pointer
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		pointer = get_global_transform_with_canvas().affine_inverse() * event.position
	if event is InputEventMouseMotion:
		throw_velocity = event.velocity
		throw_time_msec = Time.get_ticks_msec()
		if storage != null and storage.is_visible_in_tree() and storage.get_global_rect().has_point(global_position + pointer):
			var item: Dictionary = dragging
			item["cell"] = null
			item["rotation"] = drag_rotation
			item["shape"] = drag_shape
			dragging = {}
			cursor_held = false
			suppress_left_release = false
			var previous_center: Vector2 = get_global_transform_with_canvas() * (previous_pointer + (footprint(drag_shape) * 0.5 - grab).rotated(held_rotation_offset))
			storage.hold_from_board(item, event.position, grab, event.velocity, held_rotation_offset, previous_center)
			z_index = 0
			refresh()
			changed.emit()
			return
		changed.emit()
		queue_redraw()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if (cursor_held and event.pressed) or (not cursor_held and not event.pressed):
				suppress_left_release = event.pressed
				drop_at(pointer)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			rotate_held()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if cursor_held:
				stash_held()
			else:
				cancel_drag()
		elif preload("res://scripts/keybindings.gd").matches(event, "rotate_left"):
			rotate_held(-1)
		elif preload("res://scripts/keybindings.gd").matches(event, "rotate_right") or preload("res://scripts/keybindings.gd").matches(event, "rotate_alternate"):
			rotate_held(1)
		get_viewport().set_input_as_handled()

func rotate_held(direction: int = 1) -> void:
	if not run.can_edit_inventory() or dragging.is_empty():
		return
	# A filled square keeps its bounds fixed and turns its sprite in place.
	# Irregular masks (even with square bounds) still pivot around the cursor.
	var is_square: bool = drag_shape.x == drag_shape.y and dragging["mask"].size() == drag_shape.x * drag_shape.y
	if not is_square:
		var grabbed_cell: Vector2i = Vector2i(floori(grab.x / STEP), floori(grab.y / STEP))
		var within: Vector2 = grab - Vector2(grabbed_cell) * STEP
		if direction > 0:
			grabbed_cell = Vector2i(drag_shape.y - 1 - grabbed_cell.y, grabbed_cell.x)
			within = Vector2(CELL - within.y, within.x)
		else:
			grabbed_cell = Vector2i(grabbed_cell.y, drag_shape.x - 1 - grabbed_cell.x)
			within = Vector2(within.y, CELL - within.x)
		grab = Vector2(grabbed_cell) * STEP + within
	drag_rotation = posmod(drag_rotation + direction, 4)
	drag_shape = PackRun.dimensions(dragging, drag_rotation)
	held_rotation_offset -= direction * PI * 0.5
	_rotation_anim_from = held_rotation_offset
	_rotation_anim_time = 0.0
	changed.emit()
	queue_redraw()

func candidate() -> Vector2i:
	var top_left: Vector2 = pointer - grab - ORIGIN
	return Vector2i(roundi(top_left.x / STEP), roundi(top_left.y / STEP))

func candidate_valid() -> bool:
	return not candidate_plan().is_empty()

func candidate_plan() -> Array[Dictionary]:
	if dragging.is_empty() or over_storage(pointer) or not GRID_RECT.grow(12).has_point(pointer):
		return []
	return run.placement_plan(dragging, candidate(), drag_rotation)

func _apply_moves(moves: Array[Dictionary]) -> void:
	for move in moves:
		var item: Dictionary = move["item"]
		item["cell"] = move["cell"]
		item["shape"] = move["shape"]
		item["rotation"] = move["rotation"]

func preview_effects() -> Dictionary:
	return _preview_read(run.effects)

func preview_starting_resources() -> Dictionary:
	return _preview_read(run.round_resources)

func _preview_read(reader: Callable) -> Dictionary:
	if dragging.is_empty() or not run.can_edit_inventory():
		return reader.call()
	var moves: Array[Dictionary] = candidate_plan()
	if over_storage(pointer):
		moves = [{"item": dragging, "cell": null, "shape": dragging["shape"], "rotation": dragging["rotation"]}]
	elif moves.size() > 1:
		# A swap is only proposed until drop. Displaced items still occupy the
		# backpack, so keep their resources and effects in the displayed totals.
		return reader.call()
	var originals: Array[Dictionary] = []
	for move in moves:
		var item: Dictionary = move["item"]
		originals.append({"item": item, "cell": item["cell"], "shape": item["shape"], "rotation": item["rotation"]})
	_apply_moves(moves)
	var result: Dictionary = reader.call()
	_apply_moves(originals)
	return result

func drop_at(at: Vector2) -> void:
	if not run.can_edit_inventory():
		cancel_drag()
		return
	if dragging.is_empty():
		return
	pointer = at
	var moves: Array[Dictionary] = candidate_plan()
	if over_storage(pointer) or (storage != null and not GRID_RECT.grow(12).has_point(pointer)):
		stash_held()
		return
	elif not moves.is_empty():
		var starts: Dictionary = {}
		for move in moves:
			var id: int = move["item"]["id"]
			starts[id] = _motion_position(item_motions[id]) if item_motions.has(id) else item_rect(move["item"]).position
		starts[dragging["id"]] = pointer - grab
		var placed_name: String = dragging["name"]
		_apply_moves(moves)
		dragging = {}
		cursor_held = false
		for move in moves:
			var item: Dictionary = move["item"]
			if move.get("held", false):
				item_motions.erase(item["id"])
				dragging = item
				cursor_held = true
				drag_rotation = int(item["rotation"])
				drag_shape = item["shape"]
				grab = _nearest_grab_center(item, pointer - Vector2(starts[item["id"]]))
				selected_id = int(item["id"])
				selected.emit(item)
			else:
				_start_motion(item, starts[item["id"]], item["cell"] == null)
		feedback.emit("%s packed · place %s or Esc to store" % [placed_name, dragging["name"]] if cursor_held else "%s packed" % placed_name, true)
	else:
		if cursor_held:
			feedback.emit("No room there. Place the held item or press Esc to store it.", false)
			queue_redraw()
			return
		feedback.emit("No room there. Item returned.", false)
		_start_motion(dragging, pointer - grab, dragging["cell"] == null)
		dragging = {}
	z_index = 50 if not dragging.is_empty() or not item_motions.is_empty() else 0
	refresh()
	changed.emit()

func _motion_position(motion: Dictionary) -> Vector2:
	var t: float = clampf(motion["elapsed"] / motion["duration"], 0.0, 1.0)
	var eased: float = t * t * (3.0 - 2.0 * t)
	var at: Vector2 = motion["from"].lerp(motion["to"], eased)
	if motion["stash"]:
		at.y -= sin(t * PI) * 72.0
	return at

func _start_motion(item: Dictionary, from: Vector2, to_stash: bool) -> void:
	if to_stash and storage != null:
		storage.toss(item, get_global_transform_with_canvas() * (from + footprint(item["shape"]) * 0.5), Vector2.ZERO)
		return
	var destination: Vector2 = item_rect(item).position
	if to_stash:
		var target: Control = storage_button if storage_button != null and storage_button.is_visible_in_tree() else storage
		if target == null:
			return
		var center: Vector2 = target.get_global_transform_with_canvas() * (target.size * 0.5)
		destination = get_global_transform_with_canvas().affine_inverse() * center - footprint(item["shape"]) * 0.125
	if from.is_equal_approx(destination):
		return
	item_motions[item["id"]] = {"item": item.duplicate(true), "from": from, "to": destination, "elapsed": 0.0, "duration": STASH_FLIGHT_SECONDS if to_stash else SLIDE_SECONDS, "stash": to_stash}
	z_index = 50

func stash_held() -> void:
	if dragging.is_empty():
		return
	var item: Dictionary = dragging
	item["cell"] = null
	item["rotation"] = drag_rotation
	item["shape"] = drag_shape
	dragging = {}
	cursor_held = false
	if storage != null:
		var velocity: Vector2 = throw_velocity if Time.get_ticks_msec() - throw_time_msec < 150 else Vector2.ZERO
		var center: Vector2 = pointer + (footprint(drag_shape) * 0.5 - grab).rotated(held_rotation_offset)
		storage.toss(item, get_global_transform_with_canvas() * center, velocity, held_rotation_offset)
	else:
		_start_motion(item, pointer - grab, true)
	feedback.emit("%s moved to stash" % item["name"], true)
	z_index = 50 if not item_motions.is_empty() else 0
	refresh()
	changed.emit()

func cancel_drag() -> void:
	# A displaced item already has a null cell, so interruption safely stores it.
	# Also clear presentation when changing runs, scenes, or opening a modal.
	dragging = {}
	cursor_held = false
	item_motions.clear()
	z_index = 0
	refresh()
	changed.emit()

func over_storage(at: Vector2) -> bool:
	var point: Vector2 = global_position + at
	return (storage != null and storage.is_visible_in_tree() and storage.get_global_rect().has_point(point)) or (storage_button != null and storage_button.is_visible_in_tree() and storage_button.get_global_rect().has_point(point))
