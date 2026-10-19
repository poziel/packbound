class_name PackInspector
extends Control

const WINDOW: PackedScene = preload("res://scenes/shared/inspect_window/inspect_window.tscn")
const KEYWORD_GEOMETRY = preload("res://systems/ui/keywords/keyword_hover_effect.gd")
@export var lock_delay: float = 1.2
@export var show_delay: float = 0.15
@export var grace_delay: float = 0.7
@export var closing_delay: float = 0.7
var enabled: bool = true
var pointer := Vector2(-100, -100)
var sources: Array[Dictionary] = []
var windows: Array[PackInspectWindow] = []
var source: Control
var source_rect: Rect2
var source_contains: Callable
var pending: Dictionary = {}
var pending_age: float = 0.0
var active_keyword_link: String = ""
var active_parent: int = -1
var keyword_link_age: float = 0.0
var root_lock_delay: float = 1.2
var active_trigger_id: String = ""
var active_trigger_rect: Rect2
var _last_trigger: String = ""
var _root_anchor_local: Rect2
var _root_full_control: bool = false
var _moving_trigger: bool = false
var _reflow_requested: bool = false
var _reflowing: bool = false

func _ready() -> void:
	get_viewport().size_changed.connect(_request_reflow)

func _request_reflow() -> void:
	if windows.is_empty(): return
	_reflow_requested = true
	if not _reflowing:
		_reflow_tooltips.call_deferred()

func _reflow_tooltips() -> void:
	if _reflowing: return
	_reflowing = true
	await get_tree().process_frame # Let changed text layout refresh its glyph bounds.
	while _reflow_requested and not windows.is_empty():
		_reflow_requested = false
		for index in windows.size():
			if index >= windows.size() or not is_instance_valid(source): break
			var window: PackInspectWindow = windows[index]
			var anchor: Rect2 = source.get_global_rect() if _root_full_control else source.get_global_transform_with_canvas() * _root_anchor_local
			if index > 0:
				anchor = windows[index - 1].trigger_rect(window.trigger_bounds.get_center(), window.trigger_id)
				if not anchor.has_area(): continue
			else:
				if source is RichTextLabel and window.trigger_id != "root":
					anchor = link_rect(source, "", window.trigger_bounds.get_center(), window.trigger_id)
					if not anchor.has_area(): continue
				source_rect = anchor
			await _place_after_layout(window, anchor, index - 1)
			await get_tree().process_frame
	_reflowing = false

func register(target: Control, provider: Callable) -> void:
	target.tooltip_text = ""
	target.mouse_filter = Control.MOUSE_FILTER_STOP
	target.focus_mode = Control.FOCUS_NONE
	for child: Control in target.find_children("*", "Control", true, false):
		child.focus_mode = Control.FOCUS_NONE
	sources.append({"target": target, "provider": provider})
	target.resized.connect(func() -> void:
		if source == target and not _moving_trigger: _request_reflow())

func register_links(target: RichTextLabel) -> void:
	var hovered: Dictionary = {"key": ""}
	target.meta_hover_started.connect(func(meta: Variant) -> void:
		hovered["key"] = str(meta)
		target.set_meta("hovered_link", str(meta)))
	target.meta_hover_ended.connect(func(meta: Variant) -> void:
		if hovered["key"] == str(meta):
			hovered["key"] = ""
			target.set_meta("hovered_link", ""))
	target.mouse_exited.connect(func() -> void:
		hovered["key"] = ""
		target.set_meta("hovered_link", ""))
	register(target, func() -> Dictionary:
		var data: Dictionary = PackKeywordLinks.entry(hovered["key"])
		if not data.is_empty():
			var anchor: Dictionary = link_anchor(target, hovered["key"], pointer)
			if anchor.is_empty(): return {}
			data["rect"] = anchor["rect"]
			data["trigger_occurrence"] = anchor["id"]
		return data)

func set_link_text(target: RichTextLabel, text: String) -> void:
	if not target.has_meta("keyword_geometry"):
		var effect = KEYWORD_GEOMETRY.new()
		target.install_effect(effect)
		target.set_meta("keyword_geometry", effect)
		var invalidate: Callable = func() -> void:
			effect.font_size = target.get_theme_font_size("normal_font_size")
			effect.invalidate_geometry()
			target.queue_redraw()
		target.resized.connect(invalidate)
		target.get_v_scroll_bar().value_changed.connect(func(_value: float) -> void:
			invalidate.call()
			if source == target: _request_reflow())
	var annotated: String = KEYWORD_GEOMETRY.annotate_links(text)
	if target.text != annotated:
		var effect = target.get_meta("keyword_geometry")
		effect.font_size = target.get_theme_font_size("normal_font_size")
		effect.invalidate_geometry()
		target.text = annotated

func link_anchor(target: RichTextLabel, key: String, point: Vector2, occurrence: String = "") -> Dictionary:
	if not target.has_meta("keyword_geometry"): return {}
	var effect = target.get_meta("keyword_geometry")
	var nearest: Dictionary = {}
	var distance: float = INF
	for id: String in effect.fragments:
		if id != occurrence and (not occurrence.is_empty() or not id.begins_with(key + "#")): continue
		for fragment: Rect2 in effect.trigger_fragments(id):
			var rect: Rect2 = target.get_global_transform_with_canvas() * fragment
			if rect.has_point(point): return {"id": id, "rect": rect}
			var next_distance: float = rect.get_center().distance_squared_to(point)
			if next_distance < distance:
				nearest = {"id": id, "rect": rect}
				distance = next_distance
	return nearest

func link_rect(target: RichTextLabel, key: String, point: Vector2, occurrence: String = "") -> Rect2:
	return link_anchor(target, key, point, occurrence).get("rect", Rect2())

func clear() -> void:
	_trim(0)
	pending.clear()
	pending_age = 0.0
	active_keyword_link = ""
	active_parent = -1
	source = null
	source_contains = Callable()
	_last_trigger = ""
	active_trigger_id = ""
	active_trigger_rect = Rect2()

func _trim(count: int) -> void:
	if active_parent >= count:
		active_keyword_link = ""
		active_parent = -1
	while windows.size() > count:
		var window: PackInspectWindow = windows.pop_back()
		remove_child(window)
		window.queue_free()

func apply_timing(settings: Dictionary) -> void:
	show_delay = float(settings.get("tooltip_opening_delay", 0.15))
	lock_delay = float(settings.get("tooltip_lock_delay", 1.2))
	grace_delay = float(settings.get("tooltip_grace_delay", 0.7))
	closing_delay = float(settings.get("tooltip_closing_delay", 0.7))

func _inside_tooltip() -> int:
	for i in range(windows.size() - 1, -1, -1):
		var window: PackInspectWindow = windows[i]
		if window.locked and window._placed and window.modulate.a > 0.0 and window.get_global_rect().has_point(pointer):
			return i
	return -1

func _trigger_held(index: int, inside: int) -> bool:
	if index == 0:
		if source_contains.is_valid():
			return source_contains.call(pointer)
		# Animated controls can move without resizing or emitting mouse motion.
		var bounds: Rect2 = source.get_global_rect() if _moving_trigger and _root_full_control and is_instance_valid(source) else source_rect
		return bounds.has_point(pointer)
	return inside == index - 1 and active_parent == index - 1 and active_keyword_link == windows[index].key and active_trigger_id == windows[index].trigger_id

func _process(delta: float) -> void:
	if not enabled:
		clear()
		return
	if _reflowing: return
	var quick: bool = preload("res://systems/application/keybindings.gd").held("quick_inspect")
	if quick and not windows.is_empty():
		_trim(1)
		windows[0].set_locked(false)
		windows[0].age = 0.0
		windows[0].progress(0.0)
	var inside: int = _inside_tooltip()
	if not windows.is_empty():
		if not is_instance_valid(source) or not source.is_visible_in_tree():
			clear()
			return
		var trigger_index: int = -1
		for i in windows.size():
			if _trigger_held(i, inside):
				trigger_index = i
		var trigger_token: String = str(trigger_index) + ":" + (windows[trigger_index].trigger_id if trigger_index >= 0 else "")
		if trigger_index >= 0 and trigger_token != _last_trigger:
			for i in range(trigger_index + 1, windows.size()):
				windows[i].dismiss_requested = true
				windows[i].away_age = 0.0
		_last_trigger = trigger_token
		for i in windows.size():
			var window: PackInspectWindow = windows[i]
			var held: bool = _trigger_held(i, inside)
			if not window.locked:
				if not held:
					if i == 0: clear()
					else: _trim(i)
					break
				if not quick:
					window.age += delta
					window.progress(1.0 if lock_delay <= 0.0 else window.age / lock_delay)
			else:
				if inside == i:
					window.entered = true
				var supported: bool = inside >= i or trigger_index >= i
				if supported:
					window.away_age = 0.0
					window.dismiss_requested = false
				else:
					window.away_age += delta
					var limit: float = closing_delay if window.entered or window.dismiss_requested else grace_delay
					if window.away_age >= limit:
						if i == 0: clear()
						else: _trim(i)
						break
		if not windows.is_empty():
			if not quick and active_parent >= 0 and active_parent < windows.size() and inside == active_parent and windows[active_parent].locked and not active_keyword_link.is_empty():
				keyword_link_age += delta
				if keyword_link_age >= show_delay:
					_open_keyword_link(active_keyword_link, active_parent)
			return
	# A root trigger must be hovered continuously for its opening delay.
	var candidate: Dictionary = _candidate(get_viewport().gui_get_hovered_control())
	if candidate.is_empty():
		pending.clear()
		pending_age = 0.0
		return
	if candidate["target"] != pending.get("target") or candidate["data"]["key"] != pending.get("data", {}).get("key", ""):
		pending = candidate
		pending_age = 0.0
	pending_age += delta
	if pending_age >= show_delay:
		source = pending["target"]
		source_rect = pending["data"].get("rect", source.get_global_rect())
		_spawn(pending["data"], source_rect, -1)

func _candidate(hovered: Control) -> Dictionary:
	if hovered == null:
		return {}
	for entry in sources:
		var target: Control = entry["target"]
		if is_instance_valid(target) and target.is_visible_in_tree() and (target == hovered or target.is_ancestor_of(hovered)):
			var data: Dictionary = entry["provider"].call()
			if not data.is_empty():
				return {"target": target, "data": data}
	return {}

func _spawn(data: Dictionary, anchor: Rect2, parent_index: int) -> void:
	if parent_index < 0:
		_moving_trigger = data.get("moving_trigger", false)
		# Placement uses the bounding rectangle; irregular triggers use precise picking.
		source_contains = data.get("contains", Callable())
		root_lock_delay = lock_delay
		if is_instance_valid(source):
			_root_anchor_local = source.get_global_transform_with_canvas().affine_inverse() * anchor
			_root_full_control = source.get_global_rect().is_equal_approx(anchor)
	var window: PackInspectWindow = WINDOW.instantiate()
	add_child(window)
	windows.append(window)
	window.setup(data)
	window.trigger_id = active_trigger_id if parent_index >= 0 else str(data.get("trigger_occurrence", "root"))
	if lock_delay <= 0.0 and not preload("res://systems/application/keybindings.gd").held("quick_inspect"):
		window.progress(1.0)
	var index: int = windows.size() - 1
	window.keyword_link_entered.connect(func(key: String) -> void:
		active_keyword_link = key
		active_trigger_id = window._hover_occurrence
		active_trigger_rect = window.trigger_rect(pointer)
		active_parent = index
		keyword_link_age = 0.0)
	window.keyword_link_exited.connect(func() -> void:
		if active_parent == index:
			active_keyword_link = "")
	window.keyword_link_pressed.connect(func(key: String) -> void:
		_open_keyword_link(key, index, true))
	window.item_recipe_requested.connect(func(item_key: String) -> void:
		_open_item_recipe(item_key, index))
	_place_after_layout(window, anchor, parent_index)

const TOOLTIP_GAP: float = 12.0
const SCREEN_MARGIN: float = 12.0

static func placement_regions(anchor: Rect2, bounds: Vector2, drop: float = 0.0) -> Array[Rect2]:
	var screen := Rect2(Vector2.ONE * SCREEN_MARGIN, bounds - Vector2.ONE * SCREEN_MARGIN * 2 - Vector2(0, drop))
	return [
		Rect2(Vector2(anchor.end.x + TOOLTIP_GAP, screen.position.y), Vector2(maxf(0, screen.end.x - anchor.end.x - TOOLTIP_GAP), screen.size.y)),
		Rect2(screen.position, Vector2(maxf(0, anchor.position.x - TOOLTIP_GAP - screen.position.x), screen.size.y)),
		Rect2(Vector2(screen.position.x, anchor.end.y + TOOLTIP_GAP), Vector2(screen.size.x, maxf(0, screen.end.y - anchor.end.y - TOOLTIP_GAP))),
		Rect2(screen.position, Vector2(screen.size.x, maxf(0, anchor.position.y - TOOLTIP_GAP - screen.position.y - drop))),
	]

static func placement_rect(anchor: Rect2, size_hint: Vector2, bounds: Vector2, drop: float = 0.0) -> Rect2:
	var regions: Array[Rect2] = placement_regions(anchor, bounds, drop)
	var chosen: Rect2
	var best_area: float = -1.0
	for region: Rect2 in regions:
		if region.size.x >= size_hint.x and region.size.y >= size_hint.y:
			chosen = region
			break
		if region.size.x >= minf(240, size_hint.x) and region.size.y >= 80 and region.get_area() > best_area:
			chosen = region
			best_area = region.get_area()
	if not chosen.has_area():
		# Very small viewports: choose the largest non-overlapping region.
		for region: Rect2 in regions:
			if region.get_area() > best_area:
				chosen = region
				best_area = region.get_area()
	var fitted := Vector2(minf(size_hint.x, chosen.size.x), minf(size_hint.y, chosen.size.y))
	var at := Vector2(clampf(anchor.position.x, chosen.position.x, maxf(chosen.position.x, chosen.end.x - fitted.x)), clampf(anchor.position.y, chosen.position.y, maxf(chosen.position.y, chosen.end.y - fitted.y)))
	return Rect2(at.round(), fitted.floor())

func _place_after_layout(window: PackInspectWindow, anchor: Rect2, _parent_index: int) -> void:
	window.modulate.a = 0.0
	window.trigger_bounds = anchor
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(window) or not window.is_inside_tree():
		return
	var bounds: Vector2 = get_viewport_rect().size
	window.fit_within(bounds - Vector2.ONE * SCREEN_MARGIN * 2 - Vector2(0, window.lock_drop))
	await get_tree().process_frame
	if not is_instance_valid(window) or not window.is_inside_tree():
		return
	var target: Rect2 = placement_rect(anchor, window.size, bounds, window.lock_drop)
	window.fit_within(target.size)
	await get_tree().process_frame
	if not is_instance_valid(window) or not window.is_inside_tree():
		return
	target = placement_rect(anchor, window.size, bounds, window.lock_drop)
	window.place_at(target.position)
	window.modulate.a = 1.0

func _open_keyword_link(key: String, parent_index: int, from_click: bool = false) -> void:
	if parent_index < 0 or parent_index >= windows.size() or not windows[parent_index].locked:
		return
	if active_parent == parent_index and not active_trigger_id.is_empty():
		var measured: Rect2 = windows[parent_index].trigger_rect(pointer, active_trigger_id)
		if not measured.has_area():
			return # Wait for the first shaped-text draw, including zero opening delay.
		active_trigger_rect = measured
	var data: Dictionary = windows[parent_index].bonus_definitions.get(key, PackKeywordLinks.entry(key))
	_open_definition(data, parent_index, from_click)

func _open_item_recipe(item_key: String, parent_index: int) -> void:
	var data: Dictionary = PackRun.CRAFTING.recipe_inspection(null, PackCatalog.item(item_key))
	if data.is_empty():
		data = {"key": "crafts_" + item_key, "title": "Possible crafts", "body": "No recipes use %s as an ingredient." % PackCatalog.item(item_key)["name"]}
	_open_definition(data, parent_index, true)

func _open_definition(data: Dictionary, parent_index: int, _from_click: bool = false) -> void:
	if data.is_empty() or parent_index < 0 or parent_index >= windows.size() or not windows[parent_index].locked:
		return
	var key: String = data["key"]
	# Subject identity does not collapse ancestors. Only this exact occurrence
	# can reuse its already open descendant; repeated subjects may nest freely.
	if windows.size() > parent_index + 1 and windows[parent_index + 1].key == key and windows[parent_index + 1].trigger_id == active_trigger_id:
		return
	_trim(parent_index + 1)
	_spawn(data, active_trigger_rect if active_trigger_rect.has_area() else windows[parent_index].get_global_rect(), parent_index)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		pointer = event.position
	if not enabled:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE and not windows.is_empty():
			clear()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for window in windows:
			if window.get_global_rect().has_point(pointer):
				return
		clear()
