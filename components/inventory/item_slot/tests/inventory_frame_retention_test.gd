extends "res://tests/support/prototype_support.gd"

const FRAME = preload("res://components/inventory/item_slot/item_frame.gd")

func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(100, 100)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var slot := PackItemSlot.new()
	slot.size = Vector2(64, 64)
	viewport.add_child(slot)
	await process_frame
	await RenderingServer.frame_post_draw
	var before: Color = viewport.get_texture().get_image().get_pixel(32, 32)
	# Populate distinct shapes without redrawing the original socket. This also
	# happens as combat popups, crafting borders and resized controls share masks.
	for index in range(140):
		FRAME.skin([Vector2i.ZERO] as Array[Vector2i], Vector2(70 + index, 64), 0)
	await process_frame
	await RenderingServer.frame_post_draw
	var after: Color = viewport.get_texture().get_image().get_pixel(32, 32)
	check(before.is_equal_approx(after), "An untouched socket retains its texture after shared cache eviction")
	slot.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	check(before.is_equal_approx(viewport.get_texture().get_image().get_pixel(32, 32)), "Redraw keeps the same socket appearance")
	viewport.queue_free()
	await process_frame
	report("Inventory frame retention")
	quit(1 if failures else 0)
