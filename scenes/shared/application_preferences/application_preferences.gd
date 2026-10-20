extends CanvasLayer
## Application-wide preferences remain active while menus are hidden or gameplay is paused.
const BACKGROUND_FPS: int = 10
var settings: Dictionary = {}
var focused: bool = true
var _pointer_inside: bool = true
var _fps_age: float = 0.0
@onready var fps: Label = $FPS
@onready var cursor: Node2D = $Cursor

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	focused = get_window().has_focus()
	get_window().focus_entered.connect(set_focused.bind(true))
	get_window().focus_exited.connect(set_focused.bind(false))
	get_window().mouse_entered.connect(_set_pointer_inside.bind(true))
	get_window().mouse_exited.connect(_set_pointer_inside.bind(false))
	RenderingServer.frame_pre_draw.connect(_sync_cursor)

func apply_settings(values: Dictionary) -> void:
	settings = values.duplicate()
	_apply_focus_preferences()
	fps.visible = bool(settings.get("show_fps", false))
	_sync_cursor()

func set_focused(value: bool) -> void:
	focused = value
	_apply_focus_preferences()
	_sync_cursor()

func _apply_focus_preferences() -> void:
	var cap: int = maxi(0, int(settings.get("max_fps", 0)))
	if not focused and bool(settings.get("reduce_unfocused_fps", false)):
		cap = mini(cap, BACKGROUND_FPS) if cap > 0 else BACKGROUND_FPS
	Engine.max_fps = cap
	var muted: bool = float(settings.get("volume", 80)) <= 0.0 or (not focused and bool(settings.get("mute_unfocused", false)))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), muted)

func _set_pointer_inside(value: bool) -> void:
	_pointer_inside = value
	_sync_cursor()

func _sync_cursor() -> void:
	if not is_instance_valid(cursor): return
	var software: bool = bool(settings.get("software_cursor", false)) and focused and _pointer_inside
	cursor.visible = software
	cursor.position = get_viewport().get_mouse_position().round()
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if software else Input.MOUSE_MODE_VISIBLE

func _process(delta: float) -> void:
	_sync_cursor()
	_fps_age += delta
	if fps.visible and _fps_age >= 0.25:
		_fps_age = 0.0
		fps.text = "%d FPS" % Engine.get_frames_per_second()

func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_sync_cursor):
		RenderingServer.frame_pre_draw.disconnect(_sync_cursor)
	Engine.max_fps = 0
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
