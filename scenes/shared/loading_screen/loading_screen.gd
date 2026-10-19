extends CanvasLayer
## "Loading screen" means the pixel-dither animation between screens.
## Call play(destination); the callable runs exactly once under an opaque cover.

signal finished

@export_range(0.0, 1.0) var close_seconds: float = 0.22
@export_range(0.0, 1.0) var hold_seconds: float = 0.25
@export_range(0.0, 1.0) var reveal_seconds: float = 0.28
@export_range(0.0, 0.25, 0.001) var disappear_sound_lead_seconds: float = 0.1
@onready var cover: ColorRect = $Cover
@onready var appear_sound: AudioStreamPlayer = $AppearSound
@onready var disappear_sound: AudioStreamPlayer = $DisappearSound
var active: bool = false
var coverage: float = 0.0:
	set(value):
		coverage = value
		if is_instance_valid(cover):
			cover.material.set_shader_parameter("coverage", value)

func _ready() -> void:
	cover.hide()
	cover.resized.connect(_resize_grid)
	_resize_grid()
	set_process_input(false)

func _resize_grid() -> void:
	cover.material.set_shader_parameter("canvas_size", cover.size)

func play(destination: Callable) -> void:
	if active or not destination.is_valid():
		return
	active = true
	set_process_input(true)
	var focus: Control = get_viewport().gui_get_focus_owner()
	if is_instance_valid(focus):
		focus.release_focus()
	coverage = 0.0
	cover.show()
	# Clear any tail from the previous navigation before starting a fresh pair.
	disappear_sound.stop()
	appear_sound.play()
	var closing: Tween = create_tween()
	closing.tween_property(self, "coverage", 1.0, close_seconds)
	await closing.finished
	destination.call()
	# Give the destination a layout/render frame while it is fully covered.
	await get_tree().process_frame
	var opening: Tween = create_tween()
	var sound_lead: float = clampf(disappear_sound_lead_seconds, 0.0, hold_seconds)
	opening.tween_interval(hold_seconds - sound_lead)
	opening.tween_callback(disappear_sound.play)
	opening.tween_interval(sound_lead)
	opening.tween_property(self, "coverage", 0.0, reveal_seconds)
	await opening.finished
	cover.hide()
	active = false
	set_process_input(false)
	if get_viewport().gui_get_focus_owner() == null and is_instance_valid(focus) and focus.is_visible_in_tree():
		focus.grab_focus()
	finished.emit()

func _input(_event: InputEvent) -> void:
	if active:
		get_viewport().set_input_as_handled()
