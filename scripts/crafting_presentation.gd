extends RefCounted
## Craft-only presentation; never mutates inventory or advances combat.
const TOOLTIP: PackedScene = preload("res://scenes/shared/inspect_window.tscn")

static func _trail_point(start: Vector2, direction: Vector2, normal: Vector2, length: float, t: float, clock: float) -> Vector2:
	# A slow continuous bend, rather than a rapidly rippling lightning zigzag.
	var bend: float = sin(t * PI) * sin(clock * 1.55) * 4.5
	bend += sin(t * TAU) * sin(clock * 1.1 + 0.8) * 1.5
	return start + direction * length * t + normal * bend

static func wisp(board, start: Vector2, toward: Vector2, tint: Color, strength: float, opacity: float = 1.0) -> void:
	var delta: Vector2 = toward - start
	if delta.length() < 2.0 or opacity <= 0.0:
		return
	var direction: Vector2 = delta.normalized()
	var normal := Vector2(-direction.y, direction.x)
	# Cell-center reach plus the soft halo stays within one cell radius:
	# at most half a tile beyond the occupied cell's edge, including the glow.
	var length: float = minf(board.CELL - 8.0, delta.length() * 0.50)
	var points := PackedVector2Array()
	var envelopes := PackedFloat32Array()
	for index in range(65):
		var t: float = float(index) / 64.0
		points.append(_trail_point(start, direction, normal, length, t, board._crafting_clock))
		# A fixed feather at both ends softens the caps. Only global opacity
		# animates on hover; this spatial profile never grows or travels.
		var taper: float = smoothstep(0.0, 0.22, t) * (1.0 - smoothstep(0.78, 1.0, t))
		envelopes.append(taper * opacity)
	# Antialiased curves and closely layered translucent halos are independent
	# of the inventory's nearest-filtered pixel-art textures.
	for layer in range(9):
		var fraction: float = float(layer) / 8.0
		var width: float = lerpf(24.0, 3.9, fraction)
		var alpha: float = lerpf(0.018, 0.18 + strength * 0.05, fraction * fraction)
		var shade: Color = tint.lerp(Color("f1fff9"), fraction * fraction * 0.82)
		var colors := PackedColorArray()
		for envelope: float in envelopes:
			colors.append(Color(shade, envelope * alpha))
		board.draw_polyline_colors(points, colors, width, true)
	var core := PackedColorArray()
	for envelope: float in envelopes:
		core.append(Color(tint.lerp(Color("f1fff9"), 0.45), envelope * (0.48 + strength * 0.24)))
	board.draw_polyline_colors(points, core, 3.9, true)
	for bead in range(2):
		var travel: float = fposmod(board._crafting_clock * 0.55 + float(bead) * 0.5, 1.0)
		var spark: Vector2 = _trail_point(start, direction, normal, length, travel, board._crafting_clock)
		var alpha: float = opacity * smoothstep(0.0, 0.18, travel) * (1.0 - smoothstep(0.68, 1.0, travel))
		board.draw_circle(spark, 1.15, Color(Color("f1fff9"), alpha * 0.7), true, -1.0, true)
		for layer in range(5):
			var radius: float = 4.5 - float(layer) * 0.65
			var shade: Color = tint.lerp(Color("f1fff9"), float(layer) / 4.0)
			board.draw_circle(spark, radius, Color(shade, alpha * (0.035 + float(layer) * 0.025)), true, -1.0, true)

static func attempt_key(attempt: Dictionary) -> String:
	var parts: Array = [attempt["recipe"], attempt["count"], attempt["total"]]
	for item: Dictionary in attempt["components"]:
		parts.append([item["id"], item["cell"], item["rotation"]])
	return str(parts)

static func label_opacity(board, attempt: Dictionary) -> float:
	var key: String = attempt_key(attempt)
	if not board._crafting_label_times.has(key):
		return 0.0
	var age: float = board._crafting_label_times[key]
	return smoothstep(0.0, 0.18, age) * (1.0 - smoothstep(4.4, 5.0, age))

static func advance(board, seconds: float) -> void:
	var active: Dictionary = {}
	for attempt: Dictionary in board.crafting_attempts():
		var key: String = attempt_key(attempt)
		active[key] = true
		if board._crafting_pending_notifications.has(key):
			board._crafting_pending_notifications.erase(key)
			board._crafting_label_times[key] = 0.0
		if board._crafting_label_times.has(key):
			board._crafting_label_times[key] = minf(5.0, float(board._crafting_label_times[key]) + seconds)
	var current_attempts: Dictionary = {}
	for attempt: Dictionary in board._crafting_plans:
		current_attempts[attempt_key(attempt)] = true
	for key: String in board._crafting_pending_notifications.keys():
		if not current_attempts.has(key):
			board._crafting_pending_notifications.erase(key)
	for key: String in board._crafting_label_times.keys():
		if not active.has(key):
			board._crafting_label_times.erase(key)
	# Hover and nearby attempts share one pair identity and one animated trail.
	# Readiness changes tint/brightness, never its geometry or phase.
	var wanted: Dictionary = {}
	var blocked: Dictionary = {}
	if board.run != null:
		for item: Dictionary in board.run.items:
			if item.has("craft_lock"):
				blocked[int(item["id"])] = true
	for target: Dictionary in _hint_targets(board):
		if blocked.has(target["first_id"]) or blocked.has(target["second_id"]):
			continue
		target["tint"] = Color("67dff2")
		target["strength"] = 0.0
		wanted[target["key"]] = target
	if board.run != null and board.run.combat_state == board.run.CombatState.PREPARING:
		for attempt: Dictionary in board._crafting_plans:
			var locked: bool = attempt["components"].any(func(component: Dictionary) -> bool: return component.has("craft_lock"))
			if locked:
				continue
			var ready: bool = attempt["ready"] and not locked
			var held: bool = false
			for component: Dictionary in attempt["components"]:
				if component == board.dragging:
					held = true
			if held:
				continue
			for edge: Dictionary in attempt["links"]:
				var ids: Array = [edge["source_id"], edge["target_id"]]
				ids.sort()
				var pair: Array[Vector2] = _pair_points(board, _find_item(board, int(ids[0])), _find_item(board, int(ids[1])))
				if pair.size() != 2:
					continue
				var key: String = str(ids)
				wanted[key] = {"key": key, "first_id": ids[0], "second_id": ids[1], "start": pair[0], "finish": pair[1], "tint": Color("76ff89") if ready else Color("e3bd77"), "strength": 1.0 if ready else 0.25}
	for key: String in wanted:
		var target: Dictionary = wanted[key]
		if not board._crafting_hover.has(key):
			var fresh: Dictionary = target.duplicate()
			fresh["alpha"] = 0.0
			fresh["strength"] = 0.0
			board._crafting_hover[key] = fresh
		var flow: Dictionary = board._crafting_hover[key]
		flow["first_id"] = target["first_id"]
		flow["second_id"] = target["second_id"]
		flow["start"] = target["start"]
		flow["finish"] = target["finish"]
		var current: Color = flow.get("tint", target["tint"])
		flow["tint"] = current.lerp(target["tint"], 1.0 - exp(-seconds * 12.0))
		flow["strength"] = move_toward(float(flow.get("strength", 0.0)), float(target["strength"]), seconds / 0.20)
	for key: String in board._crafting_hover.keys():
		var flow: Dictionary = board._crafting_hover[key]
		if blocked.has(flow["first_id"]) or blocked.has(flow["second_id"]):
			board._crafting_hover.erase(key)
			continue
		var pair: Array[Vector2] = _pair_points(board, _find_item(board, int(flow["first_id"])), _find_item(board, int(flow["second_id"])))
		if pair.size() != 2:
			board._crafting_hover.erase(key)
			continue
		# Re-anchor even the fading trails; never leave a ghost at old coordinates.
		flow["start"] = pair[0]
		flow["finish"] = pair[1]
		var entering: bool = wanted.has(key)
		flow["alpha"] = move_toward(float(flow["alpha"]), 1.0 if entering else 0.0, seconds / (0.07 if entering else 0.34))
		if not entering and float(flow["alpha"]) <= 0.0:
			board._crafting_hover.erase(key)
	tooltips(board)

static func _find_item(board, id: int) -> Dictionary:
	if board.run != null:
		for item: Dictionary in board.run.items:
			if int(item["id"]) == id:
				return item
	return {}

static func _pair_points(board, first: Dictionary, second: Dictionary) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if first.is_empty() or second.is_empty():
		return result
	var a: Array[Vector2] = board.visual_item_cells(first)
	var b: Array[Vector2] = board.visual_item_cells(second)
	a.sort_custom(func(x: Vector2, y: Vector2) -> bool: return x.y < y.y or (is_equal_approx(x.y, y.y) and x.x < y.x))
	b.sort_custom(func(x: Vector2, y: Vector2) -> bool: return x.y < y.y or (is_equal_approx(x.y, y.y) and x.x < y.x))
	var best: float = INF
	for start in a:
		for finish in b:
			var distance: float = start.distance_squared_to(finish)
			if distance < best:
				best = distance
				result.assign([start, finish])
	return result

static func _hint_targets(board) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if board.run == null or not board.run.can_edit_inventory():
		return result
	var source: Dictionary = board.dragging
	if source.is_empty():
		source = _find_item(board, board.hovered_id)
	if source.is_empty() and board.storage != null:
		if board.storage.grabbed != null:
			source = board.storage.grabbed.item
		elif board.storage.is_visible_in_tree():
			source = board.storage.hovered_item()
	if source.is_empty():
		return result
	for partner: Dictionary in PackRun.CRAFTING.partners(board.run, source):
		var ids: Array = [source["id"], partner["id"]]
		ids.sort()
		var first: Dictionary = source if int(source["id"]) == int(ids[0]) else partner
		var second: Dictionary = partner if int(source["id"]) == int(ids[0]) else source
		var pair: Array[Vector2] = _pair_points(board, first, second)
		if pair.size() == 2:
			result.append({"key": str(ids), "first_id": ids[0], "second_id": ids[1], "start": pair[0], "finish": pair[1]})
	return result

static func hints(board) -> void:
	for flow: Dictionary in board._crafting_hover.values():
		var alpha: float = clampf(float(flow["alpha"]), 0.0, 1.0)
		var opacity: float = smoothstep(0.0, 1.0, alpha)
		var tint: Color = flow["tint"]
		var strength: float = flow["strength"]
		wisp(board, flow["start"], flow["finish"], tint, strength, opacity)
		wisp(board, flow["finish"], flow["start"], tint, strength, opacity)

static func clear_tooltips(board) -> void:
	for window: PackInspectWindow in board._crafting_tooltips.values():
		if is_instance_valid(window):
			if window.get_parent() != null:
				window.get_parent().remove_child(window)
			window.queue_free()
	board._crafting_tooltips.clear()

static func tooltips(board) -> void:
	if Input.is_key_pressed(KEY_ALT) or board.craft_inspection_active:
		clear_tooltips(board)
		return
	var active: Dictionary = {}
	var placed: Array[Rect2] = []
	for attempt: Dictionary in board.crafting_attempts():
		var key: String = attempt_key(attempt)
		var alpha: float = label_opacity(board, attempt)
		if alpha <= 0.0:
			continue
		active[key] = true
		if not board._crafting_tooltips.has(key):
			var fresh: PackInspectWindow = TOOLTIP.instantiate()
			fresh.name = "CraftingTooltip"
			# Timed craft previews stay above the normal inspection layer (100).
			fresh.z_as_relative = false
			fresh.z_index = 200
			fresh.modulate.a = 0.0
			board.add_child(fresh)
			fresh.setup({"key": "craft_" + key, "title": attempt["output"]["name"], "body": "%d/%d ingredients" % [attempt["count"], attempt["total"]], "icon": PackArt.item(attempt["output"]["key"])})
			# This is a timed notification using the shared inspection window,
			# rather than an interactive hover window with a lock countdown.
			fresh.get_node("Content/Header/TimerSlot").hide()
			fresh.set_meta("layout_frames", 0)
			board._crafting_tooltips[key] = fresh
		var window: PackInspectWindow = board._crafting_tooltips[key]
		var frames: int = int(window.get_meta("layout_frames", 0)) + 1
		window.set_meta("layout_frames", frames)
		if frames < 3:
			continue
		var anchor: Rect2 = board.item_rect(attempt["components"][0])
		for component: Dictionary in attempt["components"]:
			anchor = anchor.merge(board.item_rect(component))
		anchor = board.get_global_transform_with_canvas() * anchor
		var viewport: Vector2 = board.get_viewport_rect().size
		var at := Vector2(anchor.end.x + 12, anchor.position.y)
		if at.x + window.size.x > viewport.x - 12:
			at.x = anchor.position.x - window.size.x - 12
		if at.x < 12:
			at.x = clampf(anchor.position.x, 12, maxf(12, viewport.x - window.size.x - 12))
			at.y = anchor.end.y + 12
		for other in placed:
			if Rect2(at, window.size).intersects(other):
				at.y = other.end.y + 8
		at.x = clampf(at.x, 12, maxf(12, viewport.x - window.size.x - 12))
		at.y = clampf(at.y, 12, maxf(12, viewport.y - window.size.y - 12))
		placed.append(Rect2(at, window.size))
		window.place_at(board.get_global_transform_with_canvas().affine_inverse() * at)
		window.modulate.a = alpha
	for key: String in board._crafting_tooltips.keys():
		if not active.has(key):
			var window: PackInspectWindow = board._crafting_tooltips[key]
			board.remove_child(window)
			window.queue_free()
			board._crafting_tooltips.erase(key)

static func _sprite(board, item: Dictionary, center: Vector2, scale: float, opacity: float = 1.0) -> void:
	var size: Vector2 = board.footprint(item["shape"])
	var rect := Rect2(center - size * scale * 0.5, size)
	board._art_origin = rect.position
	board._art_scale = scale
	board._draw_item_art(item, rect, PackRun.offsets(item), int(item["rotation"]), Color(1, 1, 1, opacity))
	board._art_scale = 1.0

static func destination(board, burst: Dictionary) -> Vector2:
	if burst["output"]["cell"] != null:
		return board.item_rect(burst["output"]).get_center()
	var control: Control = board.storage_button if board.storage_button != null else board.storage
	if control != null:
		var canvas_point: Vector2 = control.get_global_transform_with_canvas() * (control.size * 0.5)
		return board.get_global_transform_with_canvas().affine_inverse() * canvas_point
	return board.GRID_RECT.end - Vector2(24, 24)

static func merges(board) -> void:
	for burst: Dictionary in board._crafting_bursts:
		var elapsed: float = burst["elapsed"]
		var center: Vector2 = burst["center"]
		if elapsed < 0.66:
			var t: float = clampf(elapsed / 0.66, 0.0, 1.0)
			var eased: float = t * t * (3.0 - 2.0 * t)
			for index in burst["components"].size():
				var start: Vector2 = burst["starts"][index]
				var at: Vector2 = start.lerp(center, eased)
				wisp(board, at, center, Color("b0efcc"), 1.0)
				_sprite(board, burst["components"][index], at, lerpf(1.0, 0.06, eased), 1.0 - t * 0.35)
		if elapsed >= 0.52 and elapsed < 1.05:
			var t: float = (elapsed - 0.52) / 0.53
			board.draw_circle(center, 8.0 + 28.0 * t, Color(0.8, 1.0, 0.72, (1.0 - t) * 0.32))
			board.draw_arc(center, 8.0 + 42.0 * t, 0.0, TAU, 32, Color(0.9, 1.0, 0.72, 1.0 - t), 2.0)
			for ray in range(10):
				var direction: Vector2 = Vector2.RIGHT.rotated(TAU * ray / 10.0)
				board.draw_line(center + direction * (10.0 + t * 18.0), center + direction * (16.0 + t * 34.0), Color(0.85, 1.0, 0.6, 1.0 - t), 2.0)
		if elapsed >= 0.66:
			var t: float = clampf((elapsed - 0.66) / (PackRun.CRAFTING.ANIMATION_SECONDS - 0.66), 0.0, 1.0)
			var movement: float = smoothstep(0.25, 1.0, t)
			var at: Vector2 = center.lerp(destination(board, burst), movement)
			var pop: float = lerpf(0.1, 1.0, minf(1.0, t * 3.5)) + sin(minf(t * 3.5, 1.0) * PI) * 0.12
			if burst["output"]["cell"] == null:
				pop *= lerpf(1.0, 0.3, movement)
			_sprite(board, burst["output"], at, pop)

static func draw(board) -> void:
	hints(board)
	merges(board)
