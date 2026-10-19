extends "res://tests/support/battle_ui_support.gd"

func frames(count: int) -> void:
	for i in count:
		await physics_frame
	await process_frame

func body_point(body: RigidBody2D) -> Vector2:
	return game.storage.pile.get_global_transform_with_canvas() * body.to_global(body.origin + Vector2.ONE * PackStorage.TILE * 0.5)

func place(body: RigidBody2D, at: Vector2) -> void:
	body.freeze = true
	body.release_at(at, 0.0, Vector2.ZERO)
	await frames(3)
	body.freeze = false
	body.sleeping = false
	await frames(2)

