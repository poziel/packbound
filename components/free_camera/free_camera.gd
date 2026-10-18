extends Camera3D
## Reusable collision-free inspection camera for room and asset demos.

const IDLE_HINT: String = "R reset view · Press Z to fly"
const FLY_HINT: String = "Flying · Space/Ctrl ↑/↓ · Shift boost · R reset · Z/Esc exit"

@export var move_speed: float = 2.5
@export var fast_multiplier: float = 3.0
@export var mouse_sensitivity: float = 0.003
@export var show_hint: bool = true
var flying: bool = false
var home: Transform3D
var previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE

func _ready() -> void:
	home = transform
	_update_hint()

func _unhandled_input(event: InputEvent) -> void:
	if not current:
		return
	if event is InputEventMouseMotion and flying:
		look_camera(event.relative)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Z:
			set_flying(not flying)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and flying:
			set_flying(false)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_R:
			reset_view()
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	_update_hint()
	if not current:
		set_flying(false)
		return
	if not flying:
		return
	var direction := Vector3(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_SPACE)) - float(Input.is_physical_key_pressed(KEY_CTRL)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	)
	move_camera(direction, delta, Input.is_physical_key_pressed(KEY_SHIFT))

func move_camera(direction: Vector3, delta: float, fast: bool = false) -> void:
	var movement: Vector3 = global_basis.x * direction.x + Vector3.UP * direction.y + global_basis.z * direction.z
	global_position += movement.normalized() * move_speed * delta * (fast_multiplier if fast else 1.0)

func look_camera(relative: Vector2) -> void:
	rotation.y -= relative.x * mouse_sensitivity
	rotation.x = clampf(rotation.x - relative.y * mouse_sensitivity, deg_to_rad(-89), deg_to_rad(89))

func reset_view() -> void:
	transform = home

func set_flying(enabled: bool) -> void:
	if enabled == flying:
		return
	if enabled:
		previous_mouse_mode = Input.mouse_mode
	flying = enabled
	_update_hint()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if enabled else previous_mouse_mode

func _update_hint() -> void:
	$Controls/Hint.visible = current and show_hint
	$Controls/Hint.text = FLY_HINT if flying else IDLE_HINT

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		set_flying(false)

func _exit_tree() -> void:
	set_flying(false)
