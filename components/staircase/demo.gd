extends Node3D

@onready var camera: Camera3D = $Camera
var travel: Tween
var selected: Node3D

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_R, KEY_Z]:
		if travel and travel.is_valid():
			travel.kill()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			preview($EntranceStairs)
		elif event.keycode == KEY_2:
			preview($ExitStairs)

func _process(_delta: float) -> void:
	if camera.flying and travel and travel.is_valid():
		travel.kill()
	$Instructions/Hint.visible = not camera.flying

func preview(stairs: Node3D) -> void:
	camera.set_flying(false)
	if travel and travel.is_valid():
		travel.kill()
	selected = stairs
	travel = create_tween()
	travel.tween_method(_pose, 0.0, 1.0, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _pose(progress: float) -> void:
	camera.global_transform = selected.preview_pose(progress)
