@tool
extends Button
## Connect confirmed (not pressed) to the protected action.
## Native Button still owns mouse, keyboard, controller and focus handling.

signal confirmed
signal hold_cancelled
signal hold_progress_changed(progress: float)

@export_range(0.2, 5.0, 0.1) var hold_seconds: float = 1.2
@export var click_description: String = "Activate immediately."
var hold_required: bool = true
var _hold_tooltip: String
var _hold_description: String
var hold_progress: float = 0.0
var _holding := false
var _completed := false
const RING_SEGMENTS: Array[Vector2i] = [
	Vector2i(10, 1), Vector2i(15, 2), Vector2i(19, 6), Vector2i(20, 10),
	Vector2i(19, 15), Vector2i(15, 19), Vector2i(10, 20), Vector2i(6, 19),
	Vector2i(2, 15), Vector2i(1, 10), Vector2i(2, 6), Vector2i(6, 2)
]
var _release_ready := false
var _label_before_hold := ""
var _minimum_before_hold := Vector2.ZERO
var _icon_before_hold: Texture2D

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_hold_tooltip = tooltip_text
	_hold_description = accessibility_description
	pressed.connect(_activate_click)
	button_down.connect(_begin_hold)
	button_up.connect(_release_hold)
	mouse_exited.connect(_cancel_hold)
	focus_exited.connect(_cancel_hold)
	visibility_changed.connect(_cancel_hold)
	set_process(false)
	_update_ring()

func set_hold_required(required: bool) -> void:
	if hold_required != required:
		_cancel_hold()
	hold_required = required
	tooltip_text = _hold_tooltip if required else click_description
	accessibility_description = _hold_description if required else click_description
	_update_ring()

func _activate_click() -> void:
	var activate := not disabled and (not hold_required or _release_ready or (_holding and _completed))
	_cancel_hold()
	if activate:
		confirmed.emit()

func _begin_hold() -> void:
	if not hold_required or disabled or not is_visible_in_tree():
		return
	_release_ready = false
	_label_before_hold = text
	_minimum_before_hold = custom_minimum_size
	_icon_before_hold = icon
	custom_minimum_size = get_combined_minimum_size()
	text = ""
	icon = null
	_holding = true
	_completed = false
	hold_progress = 0.0
	set_process(true)
	_update_ring()

func _release_hold() -> void:
	var ready := _holding and _completed and not disabled
	_cancel_hold()
	_release_ready = ready

func _cancel_hold() -> void:
	var cancelled := _holding
	_release_ready = false
	if _holding:
		text = _label_before_hold
		icon = _icon_before_hold
		custom_minimum_size = _minimum_before_hold
	_holding = false
	_completed = false
	hold_progress = 0.0
	set_process(false)
	hold_progress_changed.emit(hold_progress)
	_update_ring()
	queue_redraw()
	if cancelled:
		hold_cancelled.emit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_EXIT_TREE:
		_cancel_hold()

func _process(delta: float) -> void:
	if disabled or not is_visible_in_tree() or not is_pressed():
		_cancel_hold()
		return
	if not _holding or _completed:
		return
	hold_progress = minf(1.0, hold_progress + delta / maxf(0.2, hold_seconds))
	hold_progress_changed.emit(hold_progress)
	_update_ring()
	queue_redraw()
	if hold_progress >= 1.0:
		_completed = true

func _update_ring() -> void:
	queue_redraw()

func _draw() -> void:
	if not hold_required or not _holding:
		return
	var step := clampi(floori(hold_progress * RING_SEGMENTS.size()), 0, RING_SEGMENTS.size())
	var complete := get_theme_color("hold_progress_color", "Button")
	var remaining := get_theme_color("font_color")
	remaining.a = 0.3
	# Native Button centers its label inside the StyleBox content margins.
	# Paired ends have asymmetric padding to compensate for their outer ornament.
	var style := get_theme_stylebox("normal")
	var content_start := Vector2(style.get_margin(SIDE_LEFT), style.get_margin(SIDE_TOP))
	var content_end := size - Vector2(style.get_margin(SIDE_RIGHT), style.get_margin(SIDE_BOTTOM))
	var origin := ((content_start + content_end - Vector2(24, 24)) * 0.5).round()
	for index in RING_SEGMENTS.size():
		draw_rect(Rect2(origin + Vector2(RING_SEGMENTS[index]), Vector2(3, 3)), complete if index < step else remaining)
