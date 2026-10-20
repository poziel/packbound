class_name PackStorage
extends Panel
## Physics is presentation only; PackRun.items retains ownership.
signal backpack_requested
signal manipulation_started
signal item_hovered
const BODY = preload("res://scenes/run/inventory/storage_inventory/stash_body.gd")
const TILE: float = BackpackBoard.CELL
var board: BackpackBoard
var bodies: Dictionary = {}
var pile: SubViewportContainer
var world: SubViewport
var pile_visuals: Control
var walls: StaticBody2D
var grabbed: RigidBody2D
var grab_local := Vector2.ZERO
var target := Vector2.ZERO
var _run: PackRun
var hovered_id: int = -1
var _spawn_wait: float = 0.0
var _pointer_velocity := Vector2.ZERO
var _pointer_time: int = 0
var _pointer_usec: int = 0
var held_angle: float = 0.0
const ROTATE_SECONDS: float = 0.16
var _rotation_start: float = 0.0
var _rotation_goal: float = 0.0
var _rotation_time: float = ROTATE_SECONDS
var _contact_position := Vector2.ZERO
var _contact_angle: float = 0.0
var _held_spin: float = 0.0
@onready var drag_overlay: Node2D = $DragOverlay

func _process(delta: float) -> void:
	if board == null:
		return
	$Reorder.disabled = board.run == null or not board.run.can_edit_inventory()
	if grabbed != null and _rotation_time < ROTATE_SECONDS:
		var previous: float = held_angle
		_rotation_time = minf(ROTATE_SECONDS, _rotation_time + delta)
		var t: float = _rotation_time / ROTATE_SECONDS
		held_angle = lerpf(_rotation_start, _rotation_goal, t * t * (3.0 - 2.0 * t))
		_held_spin = (held_angle - previous) / maxf(delta, 0.001)
		_follow_pointer()
	elif grabbed != null:
		_held_spin = 0.0
	for body: RigidBody2D in bodies.values():
		if body.returning:
			_update_return_region(body)
			_try_repack_flight(body)
	drag_overlay.queue_redraw()
	_spawn_wait = maxf(0.0, _spawn_wait - delta)
	if _spawn_wait == 0.0:
		for body: RigidBody2D in bodies.values():
			if body.get_meta("waiting", false):
				body.set_meta("waiting", false)
				body.freeze = false
				body.collision_layer = 1
				body.collision_mask = 3
				body.show()
				_spawn_wait = 0.3
				break
	var item: Dictionary = hovered_item()
	var id: int = int(item.get("id", -1))
	if id != hovered_id:
		for body: RigidBody2D in bodies.values():
			body.hovered = int(body.item.id) == id
			body.queue_redraw()
		hovered_id = id
		if id >= 0:
			item_hovered.emit()

func reset_pile() -> void:
	grabbed = null
	_spawn_wait = 0.0
	hovered_id = -1
	for body: RigidBody2D in bodies.values():
		world.remove_child(body)
		body.queue_free()
	bodies.clear()

func _ready() -> void:
	drag_overlay.storage = self
	$Reorder.pressed.connect(reorder)
	pile = $PhysicsPile
	world = $PhysicsPile/World
	world.world_2d = World2D.new()
	# Keep physics isolated without rasterizing item art into a smaller texture.
	world.render_target_update_mode = SubViewport.UPDATE_DISABLED
	pile_visuals = Control.new()
	pile_visuals.name = "PileVisuals"
	pile_visuals.set_script(preload("res://scenes/run/inventory/storage_inventory/stash_pile_visuals.gd"))
	pile_visuals.storage = self
	add_child(pile_visuals)
	walls = StaticBody2D.new()
	walls.collision_layer = 2
	world.add_child(walls)
	gui_input.connect(_panel_input)
	resized.connect(_layout_pile)
	visibility_changed.connect(_visibility_changed)
	_layout_pile()
	_visibility_changed()
	_mount_overlay.call_deferred()

func _mount_overlay() -> void:
	drag_overlay.reparent(get_viewport(), false)
	drag_overlay.transform = Transform2D.IDENTITY

func _exit_tree() -> void:
	if is_instance_valid(drag_overlay) and not is_ancestor_of(drag_overlay):
		drag_overlay.queue_free()

func _layout_pile() -> void:
	if pile == null:
		return
	pile.position = Vector2(24, 92)
	pile.size = (size - Vector2(48, 116)).max(Vector2(180, 180))
	pile_visuals.position = pile.position
	pile_visuals.size = pile.size
	for child in walls.get_children():
		walls.remove_child(child)
		child.queue_free()
	for rect: Rect2 in [Rect2(-24, -24, pile.size.x + 48, 24), Rect2(-24, pile.size.y, pile.size.x + 48, 24), Rect2(-24, 0, 24, pile.size.y), Rect2(pile.size.x, 0, 24, pile.size.y)]:
		var collider := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		collider.shape = shape
		collider.position = rect.get_center()
		walls.add_child(collider)
	for body: RigidBody2D in bodies.values():
		body.container_size = pile.size
		if body.returning:
			continue
		var half: Vector2 = body.bounds().size * 0.5
		body.teleport(body.position.clamp(half, (pile.size - half).max(half)), body.rotation)
		body.sleeping = false

func _visibility_changed() -> void:
	_release_grab(false)
	for body: RigidBody2D in bodies.values():
		body.freeze = body.get_meta("waiting", false)
		if body.returning:
			_update_return_region(body)
		else:
			var active: bool = not body.get_meta("waiting", false)
			body.collision_layer = 1 if active else 0
			body.collision_mask = 3 if active else 0
			body.linear_damp = 0.35

func refresh() -> void:
	if board == null or board.run == null or world == null:
		return
	if _run != board.run:
		reset_pile()
		_run = board.run
	var items: Array[Dictionary] = board.unpacked()
	var ids: Array[int] = []
	for item in items:
		ids.append(item["id"])
		if bodies.has(item["id"]) and bodies[item["id"]].points != PackRun.offsets(item):
			var old_body: RigidBody2D = bodies[item["id"]]
			world.remove_child(old_body)
			old_body.queue_free()
			bodies.erase(item["id"])
		if not bodies.has(item["id"]):
			_add_body(item)
	for id: int in bodies.keys():
		if not ids.has(id):
			var body: RigidBody2D = bodies[id]
			if grabbed == body:
				grabbed = null
			world.remove_child(body)
			body.queue_free()
			bodies.erase(id)
	$Empty.visible = items.is_empty()
	for id: int in bodies:
		bodies[id].visible = bodies[id] != grabbed and not bodies[id].returning and not bodies[id].get_meta("waiting", false) and not board.item_motions.has(id) and board.dragging != bodies[id].item
		bodies[id].queue_redraw()

func _add_body(item: Dictionary) -> RigidBody2D:
	var body := RigidBody2D.new()
	body.set_script(BODY)
	body.setup(item, TILE)
	body.container_size = pile.size
	var initial: Vector2 = _initial_pile_position(-body.origin * 2.0)
	body.position = initial if initial.is_finite() else Vector2(pile.size.x * 0.5, maxf(80.0, -body.origin.y + 4.0))
	body.rotation = 0.0
	body.linear_velocity = Vector2.ZERO
	body.angular_velocity = 0.0
	if not initial.is_finite():
		body.set_meta("waiting", true)
		body.freeze = true
		body.collision_layer = 0
		body.collision_mask = 0
		body.hide()
	world.add_child(body)
	bodies[item["id"]] = body
	return body

func _initial_pile_position(extent: Vector2) -> Vector2:
	# Populate existing inventory near the floor without overlapping bodies.
	# Opening the panel never starts or respawns the simulation.
	var bottom: float = pile.size.y - extent.y - 8.0
	while bottom >= 4.0:
		var left: float = 8.0
		while left + extent.x <= pile.size.x - 4.0:
			var candidate := Rect2(Vector2(left, bottom), extent)
			var available: bool = true
			for other: RigidBody2D in bodies.values():
				if not other.returning and not other.get_meta("waiting", false) and candidate.grow(2).intersects(other.bounds()):
					available = false
					break
			if available:
				return candidate.get_center()
			left += BackpackBoard.STEP
		bottom -= BackpackBoard.STEP
	return Vector2.INF

func toss(item: Dictionary, canvas_point: Vector2, canvas_velocity: Vector2, angle: float = 0.0) -> void:
	refresh()
	var body: RigidBody2D = bodies[item["id"]]
	body.returning = false
	body.can_sleep = true
	body.set_meta("waiting", false)
	body.freeze = false
	body.collision_layer = 1
	body.collision_mask = 3
	body.show()
	var inverse: Transform2D = pile.get_global_transform_with_canvas().affine_inverse()
	var at: Vector2 = inverse * canvas_point
	var launch_velocity: Vector2 = inverse.basis_xform(canvas_velocity)
	if not is_visible_in_tree():
		launch_velocity = _closed_launch_velocity(launch_velocity)
	body.release_at(at, angle, launch_velocity)
	_start_return_if_outside(body, at)
	body.angular_velocity = randf_range(-4, 4)
	body.sleeping = false

func hold_from_board(item: Dictionary, canvas_point: Vector2, item_grab: Vector2, canvas_velocity: Vector2, visual_angle: float = 0.0, previous_center: Vector2 = Vector2.INF) -> void:
	refresh()
	grabbed = bodies[item["id"]]
	grabbed.set_meta("waiting", false)
	grabbed.collision_layer = 1
	grabbed.collision_mask = 1
	grabbed.show()
	grabbed.returning = false
	grabbed.rotation = visual_angle
	grab_local = grabbed.origin + item_grab
	target = pile.get_global_transform_with_canvas().affine_inverse() * canvas_point
	_begin_hold()
	_rotation_start = visual_angle
	_rotation_goal = 0.0
	_rotation_time = 0.0 if not is_zero_approx(visual_angle) else ROTATE_SECONDS
	_pointer_velocity = pile.get_global_transform_with_canvas().affine_inverse().basis_xform(canvas_velocity)
	_pointer_time = Time.get_ticks_msec()
	_follow_pointer()
	_contact_position = pile.get_global_transform_with_canvas().affine_inverse() * previous_center if previous_center.is_finite() else grabbed.position
	_contact_angle = held_angle
	manipulation_started.emit()

func _begin_hold() -> void:
	_pointer_velocity = Vector2.ZERO
	_pointer_time = 0
	_pointer_usec = Time.get_ticks_usec()
	held_angle = grabbed.rotation
	_rotation_start = held_angle
	_rotation_goal = held_angle
	_rotation_time = ROTATE_SECONDS
	_contact_position = grabbed.position
	_contact_angle = held_angle
	grabbed.returning = false
	grabbed.can_sleep = false
	grabbed.return_scale = 1.0
	grabbed.collision_layer = 1 if is_visible_in_tree() else 0
	grabbed.collision_mask = 1 if is_visible_in_tree() else 0
	grabbed.hide()
	grabbed.hold_at(target - grab_local.rotated(held_angle), held_angle, Vector2.ZERO)

func _follow_pointer() -> void:
	var at: Vector2 = target - grab_local.rotated(held_angle)
	grabbed.hold_at(at, held_angle, _pointer_velocity)
	drag_overlay.queue_redraw()
	_sync_backpack_preview()

func _sync_backpack_preview() -> void:
	if grabbed == null:
		return
	var previous_preview: Array = board.placement_preview_key()
	var canvas_point: Vector2 = pile.get_global_transform_with_canvas() * target
	var local: Vector2 = board.get_global_transform_with_canvas().affine_inverse() * canvas_point
	if board.is_visible_in_tree() and Rect2(Vector2.ZERO, board.size).has_point(local):
		board.dragging = grabbed.item
		board.cursor_held = false
		board.pointer = local
		var quarters: int = roundi(held_angle / (PI * 0.5))
		board.drag_rotation = posmod(int(grabbed.item["rotation"]) + quarters, 4)
		board.drag_shape = PackRun.dimensions(grabbed.item, board.drag_rotation)
		# Preserve the grab location as the mask turns into its grid orientation.
		var exact: Vector2 = grab_local.rotated(quarters * PI * 0.5)
		board.grab = exact + board.footprint(board.drag_shape) * 0.5
	else:
		if board.dragging == grabbed.item:
			board.dragging = {}
	board.queue_redraw()
	if board.placement_preview_key() != previous_preview:
		board.changed.emit()

func _release_grab(throw_item: bool = true) -> void:
	if grabbed == null:
		return
	if throw_item:
		board.item_dropped.emit()
	var at: Vector2 = target - grab_local.rotated(held_angle)
	var velocity := Vector2.ZERO
	if throw_item:
		var age: float = maxf(0, Time.get_ticks_msec() - _pointer_time) / 1000.0
		velocity = _pointer_velocity * exp(-age / 0.12)
		if not is_visible_in_tree():
			velocity = _closed_launch_velocity(velocity)
	grabbed.release_at(at, held_angle, velocity, _held_spin)
	grabbed.can_sleep = true
	grabbed.collision_mask = 3
	grabbed.show()
	if throw_item:
		_start_return_if_outside(grabbed, at)
	if board.dragging == grabbed.item:
		board.dragging = {}
	grabbed = null
	drag_overlay.queue_redraw()
	board.queue_redraw()

func _closed_launch_velocity(velocity: Vector2) -> Vector2:
	var launch: Vector2 = (velocity * 0.75).limit_length(1100.0)
	launch.y = clampf(launch.y, -550.0, 900.0)
	return launch

func _attraction_target(body: RigidBody2D, from: Vector2) -> Vector2:
	var half: Vector2 = body.bounds().size * 0.5 + Vector2.ONE * 34.0
	return from.clamp(half, (pile.size - half).max(half))

func _update_return_region(body: RigidBody2D) -> void:
	var closed: bool = not is_visible_in_tree()
	body.set_return_mode(closed)
	if closed:
		var pane: Control = get_parent() as Control
		var canvas_bounds: Rect2 = pane.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, pane.size)
		canvas_bounds.size.y = get_viewport().get_visible_rect().end.y - canvas_bounds.position.y
		body.closed_fall_bounds = pile.get_global_transform_with_canvas().affine_inverse() * canvas_bounds
		body.closed_right_edge = (pile.get_global_transform_with_canvas().affine_inverse() * get_viewport().get_visible_rect().end).x
	else:
		body.attraction_target = _attraction_target(body, body.position)

func _start_return_if_outside(body: RigidBody2D, from: Vector2) -> void:
	var closed: bool = not is_visible_in_tree()
	if closed or not Rect2(Vector2.ZERO, pile.size).encloses(body.bounds()):
		var canvas_center: Vector2 = pile.get_global_transform_with_canvas() * from
		var grid_center: Vector2 = board.get_global_transform_with_canvas().affine_inverse() * canvas_center
		body.set_meta("grid_reentry_armed", not BackpackBoard.GRID_RECT.has_point(grid_center))
		body.attract_to(_attraction_target(body, from), closed)
		_update_return_region(body)

func _try_repack_flight(body: RigidBody2D) -> bool:
	if not board.is_visible_in_tree() or not board.run.can_edit_inventory() or grabbed != null or not board.dragging.is_empty():
		return false
	var canvas_center: Vector2 = pile.get_global_transform_with_canvas() * body.position
	var center: Vector2 = board.get_global_transform_with_canvas().affine_inverse() * canvas_center
	if not BackpackBoard.GRID_RECT.has_point(center):
		body.set_meta("grid_reentry_armed", true)
		return false
	# A flight originating over the grid (e.g. Shift-click) must leave it first.
	if not body.get_meta("grid_reentry_armed", false):
		return false
	var item: Dictionary = body.item
	var preferred: int = posmod(int(item["rotation"]) + roundi(body.rotation / (PI * 0.5)), 4)
	var chosen := Vector2i(-1, -1)
	var chosen_rotation: int = preferred
	for quarter in range(4):
		var rotation: int = posmod(preferred + quarter, 4)
		var half: Vector2 = board.footprint(PackRun.dimensions(item, rotation)) * 0.5
		var nearest: float = INF
		for y in PackRun.GRID.y:
			for x in PackRun.GRID.x:
				var cell := Vector2i(x, y)
				if not board.run.can_place(item, cell, rotation):
					continue
				var distance: float = center.distance_squared_to(BackpackBoard.ORIGIN + Vector2(cell) * BackpackBoard.STEP + half)
				if distance < nearest:
					nearest = distance
					chosen = cell
					chosen_rotation = rotation
		if chosen.x >= 0:
			break
	if chosen.x < 0:
		return false
	item["cell"] = chosen
	item["rotation"] = chosen_rotation
	item["shape"] = PackRun.dimensions(item, chosen_rotation)
	refresh()
	board._start_motion(item, center - board.footprint(item["shape"]) * 0.5, false)
	board.queue_redraw()
	board.changed.emit()
	board.feedback.emit("%s packed" % item["name"], true)
	return true

func reorder() -> void:
	if board == null or board.run == null or not board.run.can_edit_inventory():
		return
	_release_grab(false)
	refresh()
	var x: float = 8.0
	var bottom: float = pile.size.y - 8.0
	var row_height: float = 0.0
	for body: RigidBody2D in bodies.values():
		body.returning = false
		body.return_scale = 1.0
		body.can_sleep = true
		var extent: Vector2 = -body.origin * 2.0
		if x + extent.x > pile.size.x - 8.0:
			x = 8.0
			bottom -= row_height + 8.0
			row_height = 0.0
		body.set_meta("waiting", false)
		body.freeze = false
		body.collision_layer = 1
		body.collision_mask = 3
		body.show()
		var at := Vector2(x + extent.x * 0.5, bottom - extent.y * 0.5)
		body.release_at(at.clamp(extent * 0.5, (pile.size - extent * 0.5).max(extent * 0.5)), 0.0, Vector2.ZERO)
		body.freeze = false
		x += extent.x + 8.0
		row_height = maxf(row_height, extent.y)
	_spawn_wait = 0.0
	manipulation_started.emit()

func rotate_held(direction: int) -> void:
	if grabbed == null:
		return
	_rotation_start = held_angle
	_rotation_goal += direction * PI * 0.5
	_rotation_time = 0.0

func hit_body(at: Vector2) -> RigidBody2D:
	var values: Array = bodies.values()
	values.reverse()
	for body: RigidBody2D in values:
		if body.visible and body.contains_visual_point(at):
			return body
	return null

func hovered_item() -> Dictionary:
	if grabbed != null or not is_visible_in_tree() or not board.dragging.is_empty():
		return {}
	var body := hit_body(pile.get_local_mouse_position())
	return body.item if body != null else {}

func item_rect(item: Dictionary) -> Rect2:
	if not bodies.has(item["id"]):
		return Rect2()
	var body: RigidBody2D = bodies[item["id"]]
	var rect: Rect2 = body.visual_transform() * Rect2(body.origin, -body.origin * 2.0)
	return pile.get_global_transform() * rect

func _panel_input(event: InputEvent) -> void:
	if board == null or not board.dragging.is_empty() or not board.run.can_edit_inventory():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and grabbed == null:
		var picked: RigidBody2D = hit_body(event.position - pile.position)
		if picked != null and PackRun.CRAFTING.toggle_lock(board.run, picked.item):
			picked.queue_redraw()
			board.changed.emit()
		accept_event()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var at: Vector2 = event.position - pile.position
		var picked: RigidBody2D = hit_body(at)
		if picked != null and event.shift_pressed:
			quick_transfer(picked.item)
			accept_event()
			return
		grabbed = picked
		if grabbed != null:
			var pose: Transform2D = grabbed.visual_transform()
			grabbed.teleport(pose.origin, pose.get_rotation())
			grab_local = grabbed.origin + board._nearest_grab_center(grabbed.item, grabbed.to_local(at) - grabbed.origin)
			target = at
			_begin_hold()
			board.item_picked_up.emit()
			_follow_pointer()
			board.selected.emit(grabbed.item)
			manipulation_started.emit()
			accept_event()

func _input(event: InputEvent) -> void:
	if grabbed == null:
		if board != null and board.run != null and board.run.can_edit_inventory() and board.dragging.is_empty() and get_parent().is_visible_in_tree() and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var at: Vector2 = pile.get_global_transform_with_canvas().affine_inverse() * event.position
			var values: Array = bodies.values()
			values.reverse()
			for flight: RigidBody2D in values:
				if not flight.returning:
					continue
				var pose: Transform2D = flight.visual_transform()
				var local: Vector2 = pose.affine_inverse() * at / maxf(0.12, flight.return_scale)
				if flight.contains_point(flight.to_global(local)):
					if event.shift_pressed:
						quick_transfer(flight.item)
					else:
						flight.teleport(pose.origin, pose.get_rotation())
						grabbed = flight
						grab_local = flight.origin + board._nearest_grab_center(flight.item, local - flight.origin)
						target = at
						_begin_hold()
						board.item_picked_up.emit()
						_follow_pointer()
						board.selected.emit(flight.item)
						manipulation_started.emit()
					get_viewport().set_input_as_handled()
					break
		return
	if event is InputEventMouseMotion:
		var inverse: Transform2D = pile.get_global_transform_with_canvas().affine_inverse()
		var next_target: Vector2 = inverse * event.position
		var now: int = Time.get_ticks_usec()
		var elapsed: float = maxf(1.0 / 240.0, float(now - _pointer_usec) / 1000000.0)
		var measured: Vector2 = (next_target - target) / elapsed
		# Position deltas avoid the platform's delayed mouse-speed samples.
		if next_target.is_equal_approx(target):
			measured = inverse.basis_xform(event.velocity)
		_pointer_velocity = _pointer_velocity.lerp(measured.limit_length(3000.0), 0.65)
		_pointer_usec = now
		target = next_target
		_pointer_time = Time.get_ticks_msec()
		_follow_pointer()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_sync_backpack_preview()
		if board.dragging == grabbed.item and board.candidate_valid():
			var item: Dictionary = grabbed.item
			var at: Vector2 = board.pointer
			_release_grab(false)
			board.dragging = item
			board.drop_at(at)
		else:
			_release_grab()
		# The release must also reach the GUI that captured the pickup press.
	elif (event is InputEventKey or event is InputEventMouseButton) and event.pressed:
		var bindings = preload("res://systems/application/keybindings.gd")
		if bindings.matches(event, "rotate_left"):
			rotate_held(-1)
		elif bindings.matches(event, "rotate_right"):
			rotate_held(1)
		get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	if grabbed == null:
		return
	if not board.run.can_edit_inventory():
		_release_grab(false)
		return
	if is_visible_in_tree():
		_sweep_held_contacts(delta)
	_follow_pointer()

func quick_transfer(item: Dictionary) -> bool:
	if board == null or not board.run.can_edit_inventory() or not board.dragging.is_empty() or grabbed != null:
		return false
	if board.run.is_permanent(item):
		board.feedback.emit("The Bowmaster's quiver must stay in the backpack.", false)
		return false
	var from: Rect2 = board.item_rect(item)
	if item["cell"] != null:
		var center: Vector2 = board.get_global_transform_with_canvas() * from.get_center()
		item["cell"] = null
		toss(item, center, Vector2.ZERO)
		board.feedback.emit("%s moved to stash" % item["name"], true)
	else:
		var before_crafts: Array[String] = board.crafting_opportunity_keys()
		if not board.run.auto_place(item):
			board.feedback.emit("No room in your backpack.", false)
			return false
		board.notify_craft_placement(before_crafts, [int(item["id"])])
		refresh()
		board._start_motion(item, from.get_center() - board.footprint(item["shape"]) * 0.5, false)
		board.feedback.emit("%s packed" % item["name"], true)
	board.selected_id = int(item["id"])
	board.selected.emit(item)
	board.refresh()
	board.changed.emit()
	manipulation_started.emit()
	return true

func _sweep_held_contacts(delta: float) -> void:
	var at: Vector2 = target - grab_local.rotated(held_angle)
	var movement: Vector2 = at - _contact_position
	var turn: float = held_angle - _contact_angle
	var radius: float = (-grabbed.origin * 2.0).length() * 0.5
	var steps: int = clampi(ceili(maxf(movement.length(), absf(turn) * radius) / 8.0), 1, 256)
	var struck: Dictionary = {}
	var speed: Vector2 = movement / maxf(delta, 0.001)
	var spin: float = turn / maxf(delta, 0.001)
	for step in range(1, steps + 1):
		var t: float = float(step) / steps
		var pose := Transform2D(lerpf(_contact_angle, held_angle, t), _contact_position.lerp(at, t))
		for collider: CollisionShape2D in grabbed.get_children():
			var query := PhysicsShapeQueryParameters2D.new()
			query.shape = collider.shape
			query.transform = pose * collider.transform
			query.collision_mask = 1
			query.exclude = [grabbed.get_rid()]
			for hit: Dictionary in world.world_2d.direct_space_state.intersect_shape(query, 64):
				var other: RigidBody2D = hit["collider"] as RigidBody2D
				if other == null or other == grabbed or struck.has(other.get_instance_id()):
					continue
				var arm: Vector2 = other.position - pose.origin
				var impact: Vector2 = speed + Vector2(-arm.y, arm.x) * spin
				if impact.length() < 8.0:
					continue
				other.sleeping = false
				other.apply_impulse(impact.limit_length(2500.0) * other.mass * 0.85, -arm.normalized() * 12.0)
				struck[other.get_instance_id()] = true
	_contact_position = at
	_contact_angle = held_angle
