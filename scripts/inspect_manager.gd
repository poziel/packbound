class_name PackInspector
extends Control

const WINDOW: PackedScene = preload("res://scenes/shared/inspect_window.tscn")
@export var lock_delay: float = 1.0
@export var show_delay: float = 0.18
@export var leave_grace: float = 0.4
var enabled: bool = true
var pointer := Vector2(-100, -100)
var sources: Array[Dictionary] = []
var windows: Array[PackInspectWindow] = []
var source: Control
var source_rect: Rect2
var pending: Dictionary = {}
var pending_age: float = 0.0
var away_age: float = 0.0
var active_keyword_link: String = ""
var active_parent: int = -1
var keyword_link_age: float = 0.0
var keyboard_active: bool = false
var root_requires_alt: bool = false
var root_lock_delay: float = 1.0
var _alt_pressed: bool = false

func register(target: Control, provider: Callable) -> void:
	target.tooltip_text = ""
	target.mouse_filter = Control.MOUSE_FILTER_STOP
	if target.focus_mode == Control.FOCUS_NONE:
		target.focus_mode = Control.FOCUS_ALL
	sources.append({"target": target, "provider": provider})

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
			data["rect"] = Rect2(pointer - Vector2(6, 6), Vector2(12, 12))
		return data)

func clear() -> void:
	_trim(0)
	pending.clear()
	pending_age = 0.0
	away_age = 0.0
	active_keyword_link = ""
	active_parent = -1
	keyboard_active = false
	source = null

func _trim(count: int) -> void:
	while windows.size() > count:
		var window: PackInspectWindow = windows.pop_back()
		remove_child(window)
		window.queue_free()

func _process(delta: float) -> void:
	var alt: bool = Input.is_key_pressed(KEY_ALT)
	if alt != _alt_pressed:
		_alt_pressed = alt
		if not windows.is_empty():
			if (alt and windows[0].key.begins_with("item_")) or (not alt and root_requires_alt and not windows[0].locked):
				clear()
	if not enabled:
		if not windows.is_empty() or not pending.is_empty():
			clear()
		return
	var point: Vector2 = pointer
	var inside: int = -1
	for i in range(windows.size() - 1, -1, -1):
		if windows[i].get_global_rect().has_point(point):
			inside = i
			break
	if not windows.is_empty():
		if not is_instance_valid(source) or not source.is_visible_in_tree():
			clear()
			return
		var on_source: bool = source_rect.has_point(point)
		var holding_root: bool = on_source or (inside >= 0 and windows[0].locked)
		# Keyboard focus also keeps the inspected chain available.
		var focus: Control = get_viewport().gui_get_focus_owner()
		var focused_window: bool = keyboard_active and focus != null and is_ancestor_of(focus)
		if holding_root or focused_window:
			away_age = 0.0
		else:
			away_age += delta
			if not windows[0].locked or away_age >= leave_grace:
				clear()
				return
		for i in range(windows.size()):
			var window: PackInspectWindow = windows[i]
			if not window.locked:
				var held: bool = on_source if i == 0 else active_parent == i - 1 and active_keyword_link == window.key
				if held:
					window.away_age = 0.0
					window.age += delta
					window.progress(window.age / (root_lock_delay if i == 0 else lock_delay))
				elif i > 0:
					window.away_age += delta
					if window.away_age > 0.15:
						_trim(i)
						break
		if not active_keyword_link.is_empty() and active_parent < windows.size() and windows[active_parent].locked:
			keyword_link_age += delta
			if keyword_link_age >= show_delay:
				_open_keyword_link(active_keyword_link, active_parent)
		if windows[0].locked:
			return
	var candidate: Dictionary = _candidate(get_viewport().gui_get_hovered_control())
	if candidate.is_empty():
		pending.clear()
		pending_age = 0.0
		return
	if candidate["data"]["key"] != pending.get("data", {}).get("key", ""):
		if not windows.is_empty():
			clear()
		pending = candidate
		pending_age = 0.0
	pending_age += delta
	if windows.is_empty() and pending_age >= show_delay:
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
		root_requires_alt = data.get("requires_alt", false)
		root_lock_delay = float(data.get("lock_delay", lock_delay))
	var window: PackInspectWindow = WINDOW.instantiate()
	add_child(window)
	windows.append(window)
	window.setup(data)
	var index: int = windows.size() - 1
	window.keyword_link_entered.connect(func(key: String) -> void:
		active_keyword_link = key
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

func _place_after_layout(window: PackInspectWindow, anchor: Rect2, parent_index: int) -> void:
	# Containers settle their minimum sizes over two frames. Hide until placed.
	window.modulate.a = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(window) or not window.is_inside_tree():
		return
	var bounds: Vector2 = get_viewport_rect().size
	var at := Vector2(anchor.end.x + 12, anchor.position.y)
	if at.x + window.size.x > bounds.x - 12:
		at.x = anchor.position.x - window.size.x - 12
	if at.x < 12:
		at.x = clampf(anchor.position.x, 12, bounds.x - window.size.x - 12)
		at.y = anchor.end.y + 12
		if at.y + window.size.y > bounds.y - 12:
			at.y = anchor.position.y - window.size.y - 12
	if parent_index >= 0:
		at.y += 28
	window.place_at(Vector2(clampf(at.x, 12, maxf(12, bounds.x - window.size.x - 12)), clampf(at.y, 12, maxf(12, bounds.y - window.size.y - 12 - window.lock_drop))).round())
	window.modulate.a = 1.0

func _open_keyword_link(key: String, parent_index: int, keyboard: bool = false) -> void:
	if parent_index < 0 or parent_index >= 7 or parent_index >= windows.size() or not windows[parent_index].locked:
		return
	var data: Dictionary = windows[parent_index].bonus_definitions.get(key, PackKeywordLinks.entry(key))
	_open_definition(data, parent_index, keyboard)

func _open_item_recipe(item_key: String, parent_index: int) -> void:
	var data: Dictionary = PackRun.CRAFTING.recipe_inspection(null, PackCatalog.item(item_key))
	if data.is_empty():
		data = {"key": "crafts_" + item_key, "title": "Possible crafts", "body": "No recipes use %s as an ingredient." % PackCatalog.item(item_key)["name"]}
	_open_definition(data, parent_index, true)

func _open_definition(data: Dictionary, parent_index: int, keyboard: bool = false) -> void:
	if data.is_empty() or parent_index < 0 or parent_index >= 7 or parent_index >= windows.size() or not windows[parent_index].locked:
		return
	var key: String = data["key"]
	# A keyword link already in this branch is reused, preventing cyclic popup chains.
	for i in range(parent_index + 1):
		if windows[i].key == key:
			_trim(i + 1)
			active_keyword_link = ""
			if keyboard:
				keyboard_active = true
				windows[i].set_locked(true)
				windows[i].focus_body()
			return
	if windows.size() > parent_index + 1 and windows[parent_index + 1].key == key:
		if keyboard:
			keyboard_active = true
			windows[parent_index + 1].set_locked(true)
			windows[parent_index + 1].focus_body()
		return
	_trim(parent_index + 1)
	_spawn(data, windows[parent_index].get_global_rect(), parent_index)
	if keyboard:
		keyboard_active = true
		windows.back().set_locked(true)
		windows.back().focus_body()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		pointer = event.position
		if event is InputEventMouseMotion:
			keyboard_active = false
	if not enabled:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE and not windows.is_empty():
			clear()
			get_viewport().set_input_as_handled()
		elif preload("res://scripts/keybindings.gd").matches(event, "inspect"):
			keyboard_active = true
			if windows.is_empty():
				var candidate: Dictionary = _candidate(get_viewport().gui_get_focus_owner())
				if not candidate.is_empty():
					source = candidate["target"]
					source_rect = source.get_global_rect()
					_spawn(candidate["data"], source_rect, -1)
			if not windows.is_empty():
				windows.back().set_locked(true)
				windows.back().focus_body()
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for window in windows:
			if window.get_global_rect().has_point(pointer):
				return
		clear()
