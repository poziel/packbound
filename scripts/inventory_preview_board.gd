extends BackpackBoard
## Reuse gameplay rendering and hover inspection, while keeping the snapshot immutable.

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		super._gui_input(event)

func _input(_event: InputEvent) -> void:
	pass
