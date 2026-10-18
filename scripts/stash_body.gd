extends RigidBody2D

const FRAME = preload("res://components/item_slot/item_frame.gd")
var item: Dictionary
var tile: float
var points: Array[Vector2i]
var origin: Vector2
var container_size := Vector2.ZERO
var held: bool = false
var held_transform := Transform2D.IDENTITY
var held_velocity := Vector2.ZERO
var _pending_transform := Transform2D.IDENTITY
var _pending_velocity := Vector2.ZERO
var _pending_move: bool = false
var returning: bool = false
var return_closed: bool = false
var attraction_target := Vector2.ZERO
var return_scale: float = 1.0
var _pending_spin: float = 0.0
var closed_fall_bounds := Rect2()
var closed_right_edge: float = INF

func hold_at(at: Vector2, angle: float, velocity: Vector2) -> void:
	held = true
	freeze = false
	custom_integrator = true
	gravity_scale = 0.0
	linear_damp = 0.0
	angular_damp = 0.0
	physics_material_override.friction = 0.0
	held_transform = Transform2D(angle, at)
	held_velocity = velocity
	transform = held_transform
	linear_velocity = velocity
	angular_velocity = 0.0
	sleeping = false

func release_at(at: Vector2, angle: float, velocity: Vector2, spin: float = 0.0) -> void:
	held = false
	custom_integrator = false
	gravity_scale = 0.42
	linear_damp = 0.35
	angular_damp = 0.5
	physics_material_override.friction = 0.55
	teleport(at, angle, velocity)
	_pending_spin = spin
	angular_velocity = spin

func attract_to(at: Vector2, closed: bool) -> void:
	returning = true
	set_return_mode(closed)
	attraction_target = at
	return_scale = 1.0
	can_sleep = false
	freeze = false
	hide()

func set_return_mode(closed: bool) -> void:
	return_closed = closed
	# Both sides must be disabled: stored rigid bodies also have collision masks.
	collision_layer = 0 if closed else 1
	collision_mask = 0 if closed else 1
	linear_damp = 0.35
	gravity_scale = 0.42

func teleport(at: Vector2, angle: float = 0.0, velocity: Vector2 = Vector2.ZERO) -> void:
	_pending_transform = Transform2D(angle, at)
	_pending_velocity = velocity
	_pending_move = true
	_pending_spin = 0.0
	transform = _pending_transform
	linear_velocity = velocity
	angular_velocity = 0.0
	sleeping = false

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if held:
		state.transform = held_transform
		state.linear_velocity = held_velocity
		state.angular_velocity = 0.0
		return
	if _pending_move:
		state.transform = _pending_transform
		state.linear_velocity = _pending_velocity
		state.angular_velocity = _pending_spin
		_pending_move = false
	if returning:
		var distance: Vector2 = attraction_target - state.transform.origin
		if return_closed:
			# Open divider; full-width top, outer side walls, and a bottom exit.
			var pose: Transform2D = state.transform
			var bounds: Rect2 = pose * Rect2(origin, -origin * 2.0)
			var velocity: Vector2 = state.linear_velocity
			if bounds.position.x < closed_fall_bounds.position.x:
				pose.origin.x += closed_fall_bounds.position.x - bounds.position.x
				velocity.x = absf(velocity.x) * 0.25
			if bounds.end.x > closed_right_edge:
				pose.origin.x -= bounds.end.x - closed_right_edge
				velocity.x = -absf(velocity.x) * 0.25
			if bounds.position.y < closed_fall_bounds.position.y:
				pose.origin.y += closed_fall_bounds.position.y - bounds.position.y
				velocity.y = absf(velocity.y) * 0.25
			state.transform = pose
			state.linear_velocity = velocity
			return_scale = 1.0
			if (pose * Rect2(origin, -origin * 2.0)).position.y >= closed_fall_bounds.end.y:
				_join_hidden_pile(state)
		else:
			state.linear_velocity += (distance * 22.0 - state.linear_velocity * 7.0) * state.step
			if Rect2(Vector2.ONE * 2, container_size - Vector2.ONE * 4).encloses(state.transform * Rect2(origin, -origin * 2.0)):
				returning = false
				can_sleep = true
				collision_mask = 3
				linear_damp = 0.35
				show()
		return
	if container_size == Vector2.ZERO:
		return
	var current: Transform2D = state.transform
	if not current.is_finite() or not state.linear_velocity.is_finite():
		current = Transform2D(0.0, container_size * 0.5)
		state.linear_velocity = Vector2.ZERO
	var half: Vector2 = (current * Rect2(origin, -origin * 2.0)).size * 0.5
	var safe: Vector2 = current.origin.clamp(half, (container_size - half).max(half))
	var velocity: Vector2 = state.linear_velocity
	if safe.x != current.origin.x:
		velocity.x = absf(velocity.x) * 0.25 * (1.0 if current.origin.x < half.x else -1.0)
	if safe.y != current.origin.y:
		velocity.y = absf(velocity.y) * 0.25 * (1.0 if current.origin.y < half.y else -1.0)
	current.origin = safe
	state.transform = current
	state.linear_velocity = velocity

func _join_hidden_pile(state: PhysicsDirectBodyState2D) -> void:
	returning = false
	can_sleep = true
	return_scale = 1.0
	var half: Vector2 = -origin
	var entry_x: float = randf_range(half.x + 4.0, maxf(half.x + 5.0, container_size.x - half.x - 4.0))
	state.transform = Transform2D(0.0, Vector2(entry_x, half.y + 8.0))
	state.linear_velocity = Vector2.ZERO
	state.angular_velocity = 0.0
	collision_layer = 1
	collision_mask = 3
	linear_damp = 0.35
	gravity_scale = 0.42
	show()

func setup(data: Dictionary, cell_size: float) -> void:
	item = data
	tile = cell_size
	points = PackRun.offsets(item)
	origin = -(Vector2(PackRun.dimensions(item)) * BackpackBoard.STEP - Vector2.ONE * 4.0) * 0.5
	mass = maxf(1.0, points.size() * 0.45)
	gravity_scale = 0.42
	linear_damp = 0.35
	angular_damp = 0.5
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	collision_mask = 3
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 0.55
	physics_material_override.bounce = 0.25
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for point in points:
		var collider := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2.ONE * tile
		collider.shape = shape
		collider.position = origin + Vector2(point) * BackpackBoard.STEP + Vector2.ONE * tile * 0.5
		add_child(collider)

func contains_point(at: Vector2) -> bool:
	var local: Vector2 = to_local(at) - origin
	var cell := Vector2i((local / BackpackBoard.STEP).floor())
	return points.has(cell) and Rect2(Vector2(cell) * BackpackBoard.STEP, Vector2.ONE * tile).has_point(local)

func bounds() -> Rect2:
	return transform * Rect2(origin, -origin * 2.0)

func _draw() -> void:
	draw_art(self)

func draw_art(canvas: CanvasItem, base: Transform2D = Transform2D.IDENTITY) -> void:
	canvas.draw_set_transform_matrix(base * Transform2D(0.0, origin))
	FRAME.draw_frame(canvas, points, Vector2.ONE * tile, 4.0, PackArt.color(item["key"]), true, held)
	var texture: Texture2D = PackArt.item(item["key"])
	var region := Rect2(Vector2.ZERO, texture.get_size())
	if texture is AtlasTexture:
		region = texture.region
		texture = texture.atlas
	var art_rect := Rect2(Vector2.ZERO, -origin * 2.0).grow(-4)
	if region.size == Vector2(32, 32) and item["shape"] == Vector2i.ONE:
		art_rect = Rect2(Vector2.ZERO, -origin * 2.0)
	for polygon in FRAME.polygons(points, Vector2.ONE * tile, 4.0, 4.0):
		var uvs := PackedVector2Array()
		for vertex in polygon:
			var uv: Vector2 = (vertex - art_rect.position) / art_rect.size
			for quarter in range(posmod(int(item["rotation"]), 4)):
				uv = Vector2(uv.y, 1.0 - uv.x)
			uvs.append((region.position + uv * region.size) / texture.get_size())
		canvas.draw_polygon(polygon, PackedColorArray([Color.WHITE]), uvs, texture)
	canvas.draw_set_transform(Vector2.ZERO)
