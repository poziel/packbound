extends Control
## Render at the UI's resolution; the SubViewport owns only the isolated physics.
var storage: PackStorage

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true

func _process(_delta: float) -> void:
	if is_visible_in_tree():
		queue_redraw()

func _draw() -> void:
	if not is_instance_valid(storage):
		return
	for body: RigidBody2D in storage.bodies.values():
		if body.visible and body != storage.grabbed and not body.returning:
			body.draw_art(self, body.visual_transform())
