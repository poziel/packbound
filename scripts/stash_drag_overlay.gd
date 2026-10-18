extends Node2D
## One unclipped visual follows a stash drag across both panels.
var storage: PackStorage

func _draw() -> void:
	if not is_instance_valid(storage) or storage.pile == null:
		return
	if not storage.get_parent().is_visible_in_tree():
		return
	var to_canvas: Transform2D = get_global_transform_with_canvas().affine_inverse() * storage.pile.get_global_transform_with_canvas()
	for body: RigidBody2D in storage.bodies.values():
		if body == storage.grabbed:
			var held_at: Vector2 = storage.target - storage.grab_local.rotated(storage.held_angle)
			body.draw_art(self, to_canvas * Transform2D(storage.held_angle, held_at))
		elif body.returning:
			var pose := Transform2D(body.rotation, body.position).scaled_local(Vector2.ONE * body.return_scale)
			body.draw_art(self, to_canvas * pose)
