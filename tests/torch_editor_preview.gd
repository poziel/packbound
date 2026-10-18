@tool
extends Node3D
## Runs only in an explicitly launched, isolated editor verification session.

var observed_motion: bool = false
var age: float = 0.0
var previous_scale: Vector3 = Vector3.ONE

func _process(delta: float) -> void:
	if not OS.get_cmdline_user_args().has("--verify-torch-editor"):
		return
	var flame: Node3D = $WarmTorch/Flame
	observed_motion = observed_motion or not flame.scale.is_equal_approx(previous_scale)
	previous_scale = flame.scale
	age += delta
	if age > 1.0:
		var success: bool = Engine.is_editor_hint() and observed_motion
		print("TORCH EDITOR RESULT: editor_hint=", Engine.is_editor_hint(), "; live flame motion=", observed_motion)
		get_tree().quit(0 if success else 1)
